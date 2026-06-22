from __future__ import annotations

from sqlalchemy.orm import Session

from db.postgres import ClientUpdate


class ClientUpdateRepository:
    def __init__(self, session: Session) -> None:
        self.session = session

    def add(self, client_update: ClientUpdate) -> None:
        self.session.add(client_update)
