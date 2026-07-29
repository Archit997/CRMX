from __future__ import annotations

from uuid import UUID

from sqlalchemy import select
from sqlalchemy.orm import Session

from db.postgres import AuditEvent


class AuditRepository:
    def __init__(self, db_session: Session) -> None:
        self.db_session = db_session

    def list_for_organization(
        self,
        organization_id: UUID,
        *,
        limit: int,
        offset: int,
    ) -> list[AuditEvent]:
        statement = (
            select(AuditEvent)
            .where(AuditEvent.organization_id == organization_id)
            .order_by(AuditEvent.created_at.desc(), AuditEvent.event_id.desc())
            .limit(limit)
            .offset(offset)
        )
        return list(self.db_session.scalars(statement).all())
