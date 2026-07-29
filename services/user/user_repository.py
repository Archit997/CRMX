from __future__ import annotations

from typing import Any
from uuid import UUID

from sqlalchemy import func
from sqlalchemy.orm import Session

from db.postgres import User
from db.postgres.models import UserRole


class UserRepository:
    def __init__(self, db_session: Session) -> None:
        self.db_session = db_session

    def list_users(
        self,
        organization_id: UUID,
        approval_status: str | None = None,
    ) -> list[User]:
        query = self.db_session.query(User).filter(
            User.organization_id == organization_id,
            User.deleted_at.is_(None),
        )
        if approval_status is not None:
            query = query.filter(User.approval_status == approval_status)
        return query.order_by(User.name).all()

    def list_assignable_users(self, organization_id: UUID) -> list[User]:
        """List users who can be assigned to clients (approved, active, not DEV role)."""
        query = self.db_session.query(User).filter(
            User.deleted_at.is_(None),
            User.approval_status == "approved",
            User.is_active.is_(True),
            User.role != UserRole.DEV,
            User.organization_id == organization_id,
        )
        return query.order_by(User.name).all()

    def get_by_id(self, user_id: UUID) -> User | None:
        return (
            self.db_session.query(User)
            .filter(User.id == user_id, User.deleted_at.is_(None))
            .first()
        )

    def get_any_by_id(self, user_id: UUID) -> User | None:
        return self.db_session.query(User).filter(User.id == user_id).first()

    def get_by_id_in_organization(
        self, user_id: UUID, organization_id: UUID
    ) -> User | None:
        return (
            self.db_session.query(User)
            .filter(
                User.id == user_id,
                User.organization_id == organization_id,
                User.deleted_at.is_(None),
            )
            .first()
        )

    def get_by_name(self, name: str, organization_id: UUID) -> User | None:
        return self.db_session.query(User).filter(
            func.lower(User.name) == name.strip().lower(),
            User.organization_id == organization_id,
            User.deleted_at.is_(None),
        ).first()

    def get_by_phone(self, phone: str) -> User | None:
        return self.db_session.query(User).filter(User.phone == phone).first()

    def list_pending_users(self, organization_id: UUID) -> list[User]:
        query = self.db_session.query(User).filter(
            User.organization_id == organization_id,
            User.approval_status == "pending",
            User.deleted_at.is_(None),
        )
        return query.order_by(User.created_at.desc()).all()

    def add(self, user: User) -> None:
        self.db_session.add(user)

    def delete(self, user: User) -> None:
        self.db_session.delete(user)
