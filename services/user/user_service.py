from __future__ import annotations

from datetime import datetime, timezone
from typing import Any
from uuid import UUID

from pydantic import BaseModel, Field
from typing import Literal
from sqlalchemy.orm import Session

from db.postgres import User
from db.postgres.models import UserRole
from services.user.user_repository import UserRepository


def _model_payload(model: BaseModel, *, exclude_unset: bool) -> dict[str, Any]:
    if hasattr(model, "model_dump"):
        return model.model_dump(exclude_unset=exclude_unset)
    return model.dict(exclude_unset=exclude_unset)


class UserCreateRequest(BaseModel):
    id: UUID
    name: str = Field(min_length=1)
    role: Literal["ADMIN", "MANAGER", "DEV", "EMPLOYEE"]
    phone: str = Field(min_length=1)
    contact: str | None = None
    approval_status: Literal["pending", "approved", "rejected"] = "approved"


class UserUpdateRequest(BaseModel):
    user_id: UUID
    name: str | None = None
    role: Literal["ADMIN", "MANAGER", "DEV", "EMPLOYEE"] | None = None
    phone: str | None = None
    contact: str | None = None


class SignupRequest(BaseModel):
    user_id: UUID
    name: str = Field(min_length=1)
    phone: str = Field(min_length=1)
    role: Literal["MANAGER", "DEV", "EMPLOYEE"] = "EMPLOYEE"
    contact: str | None = None


class UserVerificationRequest(BaseModel):
    approval_status: Literal["approved", "rejected"]
    verified_by: UUID | None = None
    rejection_reason: str | None = None


class UserService:
    def __init__(
        self,
        db_session: Session,
        user_repository: UserRepository,
    ) -> None:
        self.db_session = db_session
        self.user_repository = user_repository

    def list_users(self) -> list[dict[str, Any]]:
        return [user.to_dict() for user in self.user_repository.list_users()]

    def get_user(self, user_id: UUID) -> dict[str, Any]:
        user = self._ensure_user_exists(user_id)
        return user.to_dict()

    def get_user_profile(self, user_id: UUID) -> dict[str, Any]:
        user = self.user_repository.get_by_id(user_id)
        if user is None:
            return {
                "exists": False,
                "approval_status": "not_registered",
                "is_active": False,
            }

        profile = user.to_dict()
        profile["exists"] = True
        return profile

    def list_pending_users(self) -> list[dict[str, Any]]:
        return [user.to_dict() for user in self.user_repository.list_pending_users()]

    def list_assignable_users(self) -> list[dict[str, Any]]:
        """
        List users who can be assigned to clients.
        Criteria: approved, active, and role is not DEV.
        """
        users = self.user_repository.list_assignable_users()
        return [
            {
                "id": str(user.id),
                "name": user.name,
            }
            for user in users
        ]

    def request_signup(self, payload: SignupRequest) -> dict[str, Any]:
        existing_user = self.user_repository.get_by_id(payload.user_id)
        if existing_user is not None:
            return existing_user.to_dict()

        existing_phone = self.user_repository.get_by_phone(payload.phone)
        if existing_phone is not None:
            raise ValueError(f"Phone '{payload.phone}' is already registered")

        user = User(
            id=payload.user_id,
            name=payload.name.strip(),
            role=UserRole(payload.role),  # Convert string to enum
            phone=payload.phone.strip(),
            contact=payload.contact.strip() if payload.contact else None,
            approval_status="pending",
            is_active=False,
        )
        self.user_repository.add(user)
        self.db_session.commit()
        self.db_session.refresh(user)
        return user.to_dict()

    def create_user(self, payload: UserCreateRequest) -> dict[str, Any]:
        # Check if user with this name already exists
        existing_user = self.user_repository.get_by_name(payload.name)
        if existing_user is not None:
            raise ValueError(f"User with name '{payload.name}' already exists")

        existing_phone = self.user_repository.get_by_phone(payload.phone)
        if existing_phone is not None:
            raise ValueError(f"Phone '{payload.phone}' is already registered")

        user_values = _model_payload(payload, exclude_unset=True)
        user_values["is_active"] = user_values.get("approval_status", "approved") == "approved"
        # Convert role string to enum
        if "role" in user_values:
            user_values["role"] = UserRole(user_values["role"])
        user = User(**user_values)
        self.user_repository.add(user)
        self.db_session.commit()
        self.db_session.refresh(user)
        return user.to_dict()

    def update_user(self, payload: UserUpdateRequest) -> dict[str, Any]:
        user = self._ensure_user_exists(payload.user_id)

        update_values = _model_payload(payload, exclude_unset=True)
        update_values.pop("user_id", None)

        if not update_values:
            raise ValueError("No user fields provided for update")

        # Check if trying to update name to an existing name
        if "name" in update_values and update_values["name"] is not None:
            existing_user = self.user_repository.get_by_name(update_values["name"])
            if existing_user is not None and existing_user.id != user.id:
                raise ValueError(f"User with name '{update_values['name']}' already exists")

        # Convert role string to enum if present
        if "role" in update_values and update_values["role"] is not None:
            update_values["role"] = UserRole(update_values["role"])

        update_values["updated_at"] = datetime.now(timezone.utc)

        for field_name, field_value in update_values.items():
            setattr(user, field_name, field_value)

        self.db_session.commit()
        self.db_session.refresh(user)
        return user.to_dict()

    def verify_user(self, user_id: UUID, payload: UserVerificationRequest) -> dict[str, Any]:
        user = self._ensure_user_exists(user_id)

        if payload.approval_status == "approved":
            user.approval_status = "approved"
            user.is_active = True
            user.rejection_reason = None
        else:
            user.approval_status = "rejected"
            user.is_active = False
            user.rejection_reason = payload.rejection_reason

        user.verified_by = payload.verified_by
        user.verified_at = datetime.now(timezone.utc)
        user.updated_at = datetime.now(timezone.utc)

        self.db_session.commit()
        self.db_session.refresh(user)
        return user.to_dict()

    def delete_user(self, user_id: UUID) -> dict[str, Any]:
        user = self._ensure_user_exists(user_id)
        
        # Check if user has assigned clients
        from db.postgres import Client
        assigned_clients_count = (
            self.db_session.query(Client)
            .filter(Client.assigned_to == user_id)
            .count()
        )
        
        if assigned_clients_count > 0:
            raise ValueError(
                f"Cannot delete user '{user.name}' - they have {assigned_clients_count} assigned client(s). "
                "Please reassign these clients first."
            )

        self.user_repository.delete(user)
        self.db_session.commit()
        return {"ok": True, "deleted_count": 1, "user_id": str(user_id)}

    def _ensure_user_exists(self, user_id: UUID) -> User:
        user = self.user_repository.get_by_id(user_id)
        if user is None:
            raise LookupError(f"User {user_id} not found")
        return user
