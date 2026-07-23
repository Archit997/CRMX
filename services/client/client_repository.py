from __future__ import annotations

from uuid import UUID

from sqlalchemy import or_, select
from sqlalchemy.orm import Session, joinedload

from db.postgres import Client


class ClientRepository:
    def __init__(self, session: Session) -> None:
        self.session = session

    def list_clients(self) -> list[Client]:
        statement = select(Client).order_by(Client.last_updated.desc())
        return list(self.session.scalars(statement).all())

    def list_clients_with_relations(self) -> list[Client]:
        """List clients with assigned_user and current_status eagerly loaded."""
        statement = (
            select(Client)
            .options(
                joinedload(Client.assigned_user),
                joinedload(Client.current_status),
            )
            .order_by(Client.last_updated.desc())
        )
        return list(self.session.scalars(statement).unique().all())

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

    def search_with_relations(self, search_term: str) -> list[Client]:
        """Search clients with assigned_user and current_status eagerly loaded."""
        pattern = f"%{search_term}%"
        statement = (
            select(Client)
            .options(
                joinedload(Client.assigned_user),
                joinedload(Client.current_status),
            )
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
        return list(self.session.scalars(statement).unique().all())

    def get_by_id(self, client_id: int) -> Client | None:
        statement = select(Client).where(Client.client_id == client_id).limit(1)
        return self.session.scalars(statement).first()

    def get_by_phone(self, phone: str) -> Client | None:
        statement = select(Client).where(Client.phone == phone).limit(1)
        return self.session.scalars(statement).first()

    def get_by_assigned_user(self, user_id: UUID) -> list[Client]:
        """Get all clients assigned to a specific user."""
        statement = select(Client).where(Client.assigned_to == user_id)
        return list(self.session.scalars(statement).all())

    def add(self, client: Client) -> None:
        self.session.add(client)

    def delete(self, client: Client) -> None:
        self.session.delete(client)
