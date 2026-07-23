from __future__ import annotations

from collections.abc import Generator

from fastapi import Depends, Request
from sqlalchemy.orm import Session

from services.auth.auth_service import AuthService
from services.client.client_repository import ClientRepository
from services.client.client_service import ClientService
from services.client.client_update_repository import ClientUpdateRepository
from services.status.status_repository import StatusRepository
from services.status.status_service import StatusService
from services.user.user_repository import UserRepository
from services.user.user_service import UserService


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
        user_repository=UserRepository(db_session),
    )


def get_status_service(db_session: Session = Depends(get_db_session)) -> StatusService:
    return StatusService(
        db_session=db_session,
        status_repository=StatusRepository(db_session),
    )


def get_user_service(db_session: Session = Depends(get_db_session)) -> UserService:
    return UserService(
        db_session=db_session,
        user_repository=UserRepository(db_session),
    )


def get_auth_service(user_service: UserService = Depends(get_user_service)) -> AuthService:
    """
    Dependency to get AuthService instance.
    """
    return AuthService(user_service)
