from __future__ import annotations

from datetime import datetime, timezone
from typing import Any, Literal
from uuid import UUID

from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy.orm import Session

from db.postgres import User
from db.postgres.models import UserRole
from services.audit import record_audit_event
from services.organization.organization_repository import OrganizationRepository
from services.user.user_repository import UserRepository
from utils.logging import AppLogger


logger = AppLogger.get_logger(__name__)


def _model_payload(model: BaseModel, *, exclude_unset: bool) -> dict[str, Any]:
    if hasattr(model, "model_dump"):
        return model.model_dump(exclude_unset=exclude_unset)
    return model.dict(exclude_unset=exclude_unset)


class UserCreateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

    id: UUID
    name: str = Field(min_length=1, max_length=120)
    role: Literal["MANAGER", "EMPLOYEE"]
    phone: str = Field(min_length=8, max_length=16)
    contact: str | None = Field(default=None, max_length=500)
    approval_status: Literal["pending", "approved", "rejected"] = "approved"


class UserUpdateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

    user_id: UUID
    name: str | None = Field(default=None, min_length=1, max_length=120)
    role: Literal["MANAGER", "EMPLOYEE"] | None = None
    contact: str | None = Field(default=None, max_length=500)


class SignupRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

    name: str = Field(min_length=1, max_length=120)
    organization_code: str = Field(min_length=3, max_length=40)
    role: Literal["MANAGER", "EMPLOYEE"] = "EMPLOYEE"
    contact: str | None = Field(default=None, max_length=500)


class UserVerificationRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

    approval_status: Literal["approved", "rejected"]
    rejection_reason: str | None = Field(default=None, max_length=500)


class UserAccessUpdateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    role: Literal["MANAGER", "EMPLOYEE"] | None = None
    is_active: bool | None = None


class UserService:
    def __init__(
        self,
        db_session: Session,
        user_repository: UserRepository,
        organization_repository: OrganizationRepository,
    ) -> None:
        self.db_session = db_session
        self.user_repository = user_repository
        self.organization_repository = organization_repository

    def list_users(
        self,
        organization_id: UUID,
        approval_status: str | None = None,
    ) -> list[dict[str, Any]]:
        return [
            user.to_dict()
            for user in self.user_repository.list_users(
                organization_id, approval_status
            )
        ]

    def get_user(
        self, user_id: UUID, organization_id: UUID | None = None
    ) -> dict[str, Any]:
        user = self._ensure_user_exists(user_id, organization_id)
        return user.to_dict()

    def get_user_profile(self, user_id: UUID) -> dict[str, Any]:
        user = self.user_repository.get_any_by_id(user_id)
        if user is None:
            return {
                "exists": False,
                "approval_status": "not_registered",
                "is_active": False,
            }

        profile = user.to_dict()
        profile["exists"] = True
        return profile

    def list_pending_users(
        self, organization_id: UUID
    ) -> list[dict[str, Any]]:
        return [
            user.to_dict()
            for user in self.user_repository.list_pending_users(organization_id)
        ]

    def list_assignable_users(
        self, organization_id: UUID
    ) -> list[dict[str, Any]]:
        """
        List users who can be assigned to clients.
        Criteria: approved, active, and role is not DEV.
        """
        users = self.user_repository.list_assignable_users(organization_id)
        return [
            {
                "id": str(user.id),
                "name": user.name,
            }
            for user in users
        ]

    def request_signup(
        self,
        payload: SignupRequest,
        *,
        user_id: UUID,
        phone: str,
    ) -> dict[str, Any]:
        existing_user = self.user_repository.get_any_by_id(user_id)
        if existing_user is not None:
            if existing_user.deleted_at is not None:
                raise ValueError(
                    "This account was archived. Contact your organization admin."
                )
            return existing_user.to_dict()

        existing_phone = self.user_repository.get_by_phone(phone)
        if existing_phone is not None:
            raise ValueError("This phone number is already registered")

        organization = self.organization_repository.get_by_join_code(
            payload.organization_code
        )
        if organization is None or not organization.is_active:
            raise ValueError(
                "Organization code not found. Ask your admin for the current code."
            )

        user = User(
            id=user_id,
            organization_id=organization.id,
            name=" ".join(payload.name.strip().split()),
            role=UserRole(payload.role),  # Convert string to enum
            phone=phone,
            contact=payload.contact.strip() if payload.contact else None,
            approval_status="pending",
            is_active=False,
        )
        self.user_repository.add(user)
        record_audit_event(
            self.db_session,
            organization_id=organization.id,
            actor_id=user_id,
            action="user.signup_requested",
            entity_type="user",
            entity_id=user_id,
            metadata={"requested_role": payload.role},
        )
        self.db_session.commit()
        self.db_session.refresh(user)
        logger.info(
            "signup_requested user_id=%s organization_id=%s role=%s",
            user.id,
            user.organization_id,
            user.role.value,
        )
        return user.to_dict()

    def create_user(
        self,
        payload: UserCreateRequest,
        organization_id: UUID,
        acting_user_id: UUID,
    ) -> dict[str, Any]:
        existing_phone = self.user_repository.get_by_phone(payload.phone)
        if existing_phone is not None:
            raise ValueError("This phone number is already registered")

        user_values = _model_payload(payload, exclude_unset=True)
        user_values["name"] = " ".join(payload.name.strip().split())
        user_values["organization_id"] = organization_id
        user_values["is_active"] = user_values.get("approval_status", "approved") == "approved"
        if user_values["is_active"]:
            user_values["verified_by"] = acting_user_id
            user_values["verified_at"] = datetime.now(timezone.utc)
        # Convert role string to enum
        if "role" in user_values:
            user_values["role"] = UserRole(user_values["role"])
        user = User(**user_values)
        self.user_repository.add(user)
        record_audit_event(
            self.db_session,
            organization_id=organization_id,
            actor_id=acting_user_id,
            action="user.created",
            entity_type="user",
            entity_id=user.id,
            metadata={"role": user.role.value},
        )
        self.db_session.commit()
        self.db_session.refresh(user)
        logger.info(
            "user_created user_id=%s organization_id=%s role=%s",
            user.id,
            organization_id,
            user.role.value,
        )
        return user.to_dict()

    def update_user(
        self,
        payload: UserUpdateRequest,
        organization_id: UUID,
        acting_user_id: UUID,
    ) -> dict[str, Any]:
        user = self._ensure_user_exists(payload.user_id, organization_id)

        update_values = _model_payload(payload, exclude_unset=True)
        update_values.pop("user_id", None)

        if not update_values:
            raise ValueError("No user fields provided for update")

        if "name" in update_values and update_values["name"] is not None:
            update_values["name"] = " ".join(update_values["name"].split())

        # Convert role string to enum if present
        if "role" in update_values and update_values["role"] is not None:
            update_values["role"] = UserRole(update_values["role"])

        update_values["updated_at"] = datetime.now(timezone.utc)

        for field_name, field_value in update_values.items():
            setattr(user, field_name, field_value)

        record_audit_event(
            self.db_session,
            organization_id=organization_id,
            actor_id=acting_user_id,
            action="user.profile_updated",
            entity_type="user",
            entity_id=user.id,
            metadata={"fields": sorted(update_values.keys())},
        )
        self.db_session.commit()
        self.db_session.refresh(user)
        logger.info(
            "user_profile_updated user_id=%s organization_id=%s",
            user.id,
            organization_id,
        )
        return user.to_dict()

    def verify_user(
        self,
        user_id: UUID,
        payload: UserVerificationRequest,
        organization_id: UUID,
        verified_by: UUID,
    ) -> dict[str, Any]:
        user = self._ensure_user_exists(user_id, organization_id)
        if (
            user.approval_status == payload.approval_status
            and user.verified_by == verified_by
        ):
            return user.to_dict()
        if user.approval_status != "pending":
            raise ValueError(
                "Only pending signup requests can be approved or rejected"
            )

        if payload.approval_status == "approved":
            user.approval_status = "approved"
            user.is_active = True
            user.rejection_reason = None
        else:
            if not payload.rejection_reason:
                raise ValueError("A rejection reason is required")
            user.approval_status = "rejected"
            user.is_active = False
            user.rejection_reason = payload.rejection_reason

        user.verified_by = verified_by
        user.verified_at = datetime.now(timezone.utc)
        user.updated_at = datetime.now(timezone.utc)

        record_audit_event(
            self.db_session,
            organization_id=organization_id,
            actor_id=verified_by,
            action=f"user.{payload.approval_status}",
            entity_type="user",
            entity_id=user.id,
            metadata={"role": user.role.value},
        )
        self.db_session.commit()
        self.db_session.refresh(user)
        logger.info(
            "user_verification_updated user_id=%s organization_id=%s status=%s verified_by=%s",
            user.id,
            organization_id,
            user.approval_status,
            verified_by,
        )
        return user.to_dict()

    def update_access(
        self,
        user_id: UUID,
        payload: UserAccessUpdateRequest,
        organization_id: UUID,
        acting_user_id: UUID,
    ) -> dict[str, Any]:
        user = self._ensure_user_exists(user_id, organization_id)
        if user.approval_status != "approved":
            raise ValueError("Only approved users can have active access")
        if user.id == acting_user_id and payload.is_active is False:
            raise ValueError("You cannot deactivate your own admin account")
        if user.role == UserRole.ADMIN and payload.role is not None:
            raise ValueError("Admin role cannot be changed from this screen")

        if payload.role is not None:
            user.role = UserRole(payload.role)
        if payload.is_active is not None:
            user.is_active = payload.is_active
        user.updated_at = datetime.now(timezone.utc)
        record_audit_event(
            self.db_session,
            organization_id=organization_id,
            actor_id=acting_user_id,
            action="user.access_updated",
            entity_type="user",
            entity_id=user.id,
            metadata={
                "role": user.role.value,
                "is_active": user.is_active,
            },
        )
        self.db_session.commit()
        self.db_session.refresh(user)
        logger.info(
            "user_access_updated user_id=%s organization_id=%s role=%s active=%s acting_user_id=%s",
            user.id,
            organization_id,
            user.role.value,
            user.is_active,
            acting_user_id,
        )
        return user.to_dict()

    def delete_user(
        self, user_id: UUID, organization_id: UUID, acting_user_id: UUID
    ) -> dict[str, Any]:
        user = self._ensure_user_exists(user_id, organization_id)
        if user.id == acting_user_id:
            raise ValueError("You cannot delete your own admin account")
        if user.role == UserRole.ADMIN:
            raise ValueError("Admin accounts cannot be archived from this screen")

        # Check if user has assigned clients
        from db.postgres import Client
        assigned_clients_count = (
            self.db_session.query(Client)
            .filter(
                Client.assigned_to == user_id,
                Client.organization_id == organization_id,
                Client.deleted_at.is_(None),
            )
            .count()
        )

        if assigned_clients_count > 0:
            raise ValueError(
                f"Cannot delete user '{user.name}' - they have {assigned_clients_count} assigned client(s). "
                "Please reassign these clients first."
            )

        now = datetime.now(timezone.utc)
        user.is_active = False
        user.approval_status = "rejected"
        user.rejection_reason = "Account archived by organization admin"
        user.deleted_at = now
        user.deleted_by = acting_user_id
        user.updated_at = now
        record_audit_event(
            self.db_session,
            organization_id=organization_id,
            actor_id=acting_user_id,
            action="user.archived",
            entity_type="user",
            entity_id=user.id,
        )
        self.db_session.commit()
        return {"ok": True, "archived_count": 1, "user_id": str(user_id)}

    def _ensure_user_exists(
        self, user_id: UUID, organization_id: UUID | None = None
    ) -> User:
        if organization_id is None:
            user = self.user_repository.get_by_id(user_id)
        else:
            user = self.user_repository.get_by_id_in_organization(
                user_id, organization_id
            )
        if user is None:
            raise LookupError(f"User {user_id} not found")
        return user
