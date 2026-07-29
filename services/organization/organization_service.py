from __future__ import annotations

import re
import secrets
import string
from datetime import datetime, timezone
from typing import Any
from uuid import UUID, uuid4

from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy.exc import IntegrityError
from sqlalchemy.orm import Session

from db.postgres import Organization, User
from db.postgres.models import UserRole
from services.audit import record_audit_event
from services.organization.organization_repository import OrganizationRepository
from services.user.user_repository import UserRepository
from utils.logging import AppLogger


logger = AppLogger.get_logger(__name__)


class OrganizationBootstrapRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

    organization_name: str = Field(min_length=2, max_length=120)
    admin_name: str = Field(min_length=1, max_length=120)
    contact: str | None = Field(default=None, max_length=500)


class OrganizationService:
    def __init__(
        self,
        db_session: Session,
        organization_repository: OrganizationRepository,
        user_repository: UserRepository,
    ) -> None:
        self.db_session = db_session
        self.organization_repository = organization_repository
        self.user_repository = user_repository

    def bootstrap(
        self,
        payload: OrganizationBootstrapRequest,
        *,
        user_id: UUID,
        phone: str,
    ) -> dict[str, Any]:
        existing_user = self.user_repository.get_by_id(user_id)
        if existing_user and existing_user.organization_id:
            if (
                existing_user.role == UserRole.ADMIN
                and existing_user.approval_status == "approved"
                and existing_user.is_active
            ):
                organization = self.organization_repository.get_by_id(
                    existing_user.organization_id
                )
                if organization is not None:
                    return {
                        "organization": organization.to_dict(
                            include_join_code=True
                        ),
                        "user": existing_user.to_dict(),
                    }
            raise ValueError("Your account already belongs to an organization")
        if existing_user and (
            existing_user.role != UserRole.ADMIN
            or existing_user.approval_status != "approved"
            or not existing_user.is_active
        ):
            raise ValueError("Only an approved admin can set up an organization")

        organization_name = " ".join(payload.organization_name.strip().split())
        admin_name = " ".join(payload.admin_name.strip().split())
        slug = self._generate_slug(organization_name)
        join_code = self._generate_join_code(organization_name)
        organization = Organization(
            id=uuid4(),
            name=organization_name,
            slug=slug,
            join_code=join_code,
            is_active=True,
            created_by=user_id,
        )
        self.organization_repository.add(organization)
        self.db_session.flush()

        if existing_user:
            existing_user.organization_id = organization.id
            existing_user.updated_at = datetime.now(timezone.utc)
            admin_user = existing_user
        else:
            existing_phone = self.user_repository.get_by_phone(phone)
            if existing_phone is not None:
                raise ValueError("This phone number is already registered")
            admin_user = User(
                id=user_id,
                organization_id=organization.id,
                name=admin_name,
                role=UserRole.ADMIN,
                phone=phone,
                contact=payload.contact.strip() if payload.contact else None,
                approval_status="approved",
                is_active=True,
                verified_by=user_id,
                verified_at=datetime.now(timezone.utc),
            )
            self.user_repository.add(admin_user)

        record_audit_event(
            self.db_session,
            organization_id=organization.id,
            actor_id=user_id,
            action="organization.bootstrapped",
            entity_type="organization",
            entity_id=organization.id,
            metadata={"admin_id": str(user_id)},
        )
        try:
            self.db_session.commit()
        except IntegrityError as exc:
            self.db_session.rollback()
            logger.warning(
                "organization_bootstrap_conflict admin_id=%s",
                user_id,
            )
            raise ValueError(
                "Organization setup conflicted with another request. Please retry."
            ) from exc
        self.db_session.refresh(organization)
        self.db_session.refresh(admin_user)
        logger.info(
            "organization_bootstrapped organization_id=%s admin_id=%s",
            organization.id,
            admin_user.id,
        )
        return {
            "organization": organization.to_dict(include_join_code=True),
            "user": admin_user.to_dict(),
        }

    def get_for_user(self, organization_id: UUID) -> dict[str, Any]:
        organization = self.organization_repository.get_by_id(organization_id)
        if organization is None:
            raise LookupError("Organization not found")
        return organization.to_dict(include_join_code=True)

    def rotate_join_code(
        self,
        organization_id: UUID,
        actor_id: UUID,
    ) -> dict[str, Any]:
        organization = self.organization_repository.get_by_id(organization_id)
        if organization is None:
            raise LookupError("Organization not found")
        organization.join_code = self._generate_join_code(organization.name)
        organization.updated_at = datetime.now(timezone.utc)
        record_audit_event(
            self.db_session,
            organization_id=organization_id,
            actor_id=actor_id,
            action="organization.join_code_rotated",
            entity_type="organization",
            entity_id=organization_id,
        )
        try:
            self.db_session.commit()
        except IntegrityError as exc:
            self.db_session.rollback()
            raise ValueError(
                "Could not rotate the company code. Please retry."
            ) from exc
        self.db_session.refresh(organization)
        logger.info(
            "organization_join_code_rotated organization_id=%s actor_id=%s",
            organization_id,
            actor_id,
        )
        return organization.to_dict(include_join_code=True)

    @staticmethod
    def _generate_slug(name: str) -> str:
        base = re.sub(r"[^a-z0-9]+", "-", name.lower()).strip("-") or "company"
        return f"{base}-{uuid4().hex[:10]}"

    @staticmethod
    def _generate_join_code(name: str) -> str:
        prefix = re.sub(r"[^A-Z0-9]", "", name.upper())[:8] or "CRMX"
        alphabet = string.ascii_uppercase + string.digits
        random_part = "".join(secrets.choice(alphabet) for _ in range(10))
        return f"{prefix}-{random_part}"
