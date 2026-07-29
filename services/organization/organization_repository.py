from __future__ import annotations

from uuid import UUID

from sqlalchemy import func
from sqlalchemy.orm import Session

from db.postgres import Organization


class OrganizationRepository:
    def __init__(self, db_session: Session) -> None:
        self.db_session = db_session

    def get_by_id(self, organization_id: UUID) -> Organization | None:
        return (
            self.db_session.query(Organization)
            .filter(Organization.id == organization_id)
            .first()
        )

    def get_by_join_code(self, join_code: str) -> Organization | None:
        normalized = join_code.strip().upper()
        return (
            self.db_session.query(Organization)
            .filter(func.upper(Organization.join_code) == normalized)
            .first()
        )

    def slug_exists(self, slug: str) -> bool:
        return (
            self.db_session.query(Organization.id)
            .filter(Organization.slug == slug)
            .first()
            is not None
        )

    def join_code_exists(self, join_code: str) -> bool:
        return (
            self.db_session.query(Organization.id)
            .filter(Organization.join_code == join_code)
            .first()
            is not None
        )

    def add(self, organization: Organization) -> None:
        self.db_session.add(organization)
