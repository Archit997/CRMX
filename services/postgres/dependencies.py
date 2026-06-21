from __future__ import annotations

from collections.abc import Generator

from fastapi import Depends, Request
from sqlalchemy.orm import Session

from services.client.client_repository import ClientRepository
from services.client.client_service import ClientService
from services.client.client_update_repository import ClientUpdateRepository
from services.status.status_repository import StatusRepository
from services.status.status_service import StatusService


def get_db_session(request: Request) -> Generator[Session, None, None]:
    session = request.app.state.postgres_db.create_session()
    try:
        yield session
    except Exception:
        session.rollback()
        raise
    finally:
        session.close()


def get_client_service(db_session: Session = Depends(get_db_session)) -> ClientService:
    return ClientService(
        db_session=db_session,
        client_repository=ClientRepository(db_session),
        client_update_repository=ClientUpdateRepository(db_session),
        status_repository=StatusRepository(db_session),
    )


def get_status_service(db_session: Session = Depends(get_db_session)) -> StatusService:
    return StatusService(
        db_session=db_session,
        status_repository=StatusRepository(db_session),
    )
