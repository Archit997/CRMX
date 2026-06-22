from __future__ import annotations

from sqlalchemy import select
from sqlalchemy.orm import Session

from db.postgres import StatusMaster


class StatusRepository:
    def __init__(self, session: Session) -> None:
        self.session = session

    def list_all(self) -> list[StatusMaster]:
        statement = select(StatusMaster).order_by(StatusMaster.status_no.asc())
        return list(self.session.scalars(statement).all())

    def get_by_no(self, status_no: int) -> StatusMaster | None:
        statement = select(StatusMaster).where(StatusMaster.status_no == status_no).limit(1)
        return self.session.scalars(statement).first()

    def add(self, status: StatusMaster) -> None:
        self.session.add(status)
