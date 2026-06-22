from __future__ import annotations

from sqlalchemy import or_, select
from sqlalchemy.orm import Session

from db.postgres import Client


class ClientRepository:
    def __init__(self, session: Session) -> None:
        self.session = session

    def list_clients(self) -> list[Client]:
        statement = select(Client).order_by(Client.last_updated.desc())
        return list(self.session.scalars(statement).all())

    def search(self, search_term: str) -> list[Client]:
        pattern = f"%{search_term}%"
        statement = (
            select(Client)
            .where(
                or_(
                    Client.client_name.ilike(pattern),
                    Client.company_name.ilike(pattern),
                    Client.phone.ilike(pattern),
                    Client.whatsapp_number.ilike(pattern),
                    Client.email.ilike(pattern),
                )
            )
            .order_by(Client.last_updated.desc())
        )
        return list(self.session.scalars(statement).all())

    def get_by_id(self, client_id: int) -> Client | None:
        statement = select(Client).where(Client.client_id == client_id).limit(1)
        return self.session.scalars(statement).first()

    def get_by_phone(self, phone: str) -> Client | None:
        statement = select(Client).where(Client.phone == phone).limit(1)
        return self.session.scalars(statement).first()

    def add(self, client: Client) -> None:
        self.session.add(client)

    def delete(self, client: Client) -> None:
        self.session.delete(client)
