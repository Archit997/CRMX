from __future__ import annotations

from typing import Any
from uuid import UUID

from sqlalchemy.orm import Session

from db.postgres import User


class UserRepository:
    def __init__(self, db_session: Session) -> None:
        self.db_session = db_session

    def list_users(self) -> list[User]:
        return self.db_session.query(User).order_by(User.name).all()

    def get_by_id(self, user_id: UUID) -> User | None:
        return self.db_session.query(User).filter(User.id == user_id).first()

    def get_by_name(self, name: str) -> User | None:
        return self.db_session.query(User).filter(User.name == name).first()

    def get_by_phone(self, phone: str) -> User | None:
        return self.db_session.query(User).filter(User.phone == phone).first()

    def list_pending_users(self) -> list[User]:
        return (
            self.db_session.query(User)
            .filter(User.approval_status == "pending")
            .order_by(User.created_at.desc())
            .all()
        )

    def add(self, user: User) -> None:
        self.db_session.add(user)

    def delete(self, user: User) -> None:
        self.db_session.delete(user)
