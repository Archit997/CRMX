from __future__ import annotations

from typing import Any
from uuid import UUID

from sqlalchemy.orm import Session

from db.postgres import AuditEvent
from utils.request_context import get_request_id


def record_audit_event(
    db_session: Session,
    *,
    organization_id: UUID,
    actor_id: UUID,
    action: str,
    entity_type: str,
    entity_id: str | UUID | int,
    metadata: dict[str, Any] | None = None,
) -> None:
    """Stage a durable audit record in the caller's database transaction."""
    db_session.add(
        AuditEvent(
            organization_id=organization_id,
            actor_id=actor_id,
            action=action,
            entity_type=entity_type,
            entity_id=str(entity_id),
            request_id=get_request_id(),
            event_metadata=metadata or {},
        )
    )
