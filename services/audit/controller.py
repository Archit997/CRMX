from __future__ import annotations

from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from services.audit.audit_repository import AuditRepository
from services.auth.dependencies import require_admin
from services.postgres.dependencies import get_db_session


router = APIRouter(prefix="/api/audit-events", tags=["audit"])


@router.get("")
async def list_audit_events(
    admin: Annotated[dict, Depends(require_admin)],
    db_session: Annotated[Session, Depends(get_db_session)],
    limit: Annotated[int, Query(ge=1, le=200)] = 50,
    offset: Annotated[int, Query(ge=0)] = 0,
) -> list[dict]:
    organization_value = admin.get("organization_id")
    if not organization_value:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Organization setup is required",
        )
    organization_id = UUID(organization_value)
    events = AuditRepository(db_session).list_for_organization(
        organization_id,
        limit=limit,
        offset=offset,
    )
    return [event.to_dict() for event in events]


audit_router = router
