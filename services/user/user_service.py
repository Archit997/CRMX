from __future__ import annotations

from datetime import datetime, timezone
from typing import Any
from uuid import UUID

from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from db.postgres import User
from services.user.user_repository import UserRepository


def _model_payload(model: BaseModel, *, exclude_unset: bool) -> dict[str, Any]:
    if hasattr(model, "model_dump"):
        return model.model_dump(exclude_unset=exclude_unset)
    return model.dict(exclude_unset=exclude_unset)


class UserCreateRequest(BaseModel):
    name: str = Field(min_length=1)
    role: str = Field(min_length=1)


class UserUpdateRequest(BaseModel):
    user_id: UUID
    name: str | None = None
    role: str | None = None


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

    def create_user(self, payload: UserCreateRequest) -> dict[str, Any]:
        # Check if user with this name already exists
        existing_user = self.user_repository.get_by_name(payload.name)
        if existing_user is not None:
            raise ValueError(f"User with name '{payload.name}' already exists")

        user_values = _model_payload(payload, exclude_unset=True)
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

        update_values["updated_at"] = datetime.now(timezone.utc)

        for field_name, field_value in update_values.items():
            setattr(user, field_name, field_value)

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
