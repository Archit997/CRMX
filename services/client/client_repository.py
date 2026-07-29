from __future__ import annotations

from uuid import UUID

from sqlalchemy import or_, select
from sqlalchemy.orm import Session, joinedload

from db.postgres import Client


class ClientRepository:
    def __init__(self, session: Session) -> None:
        self.session = session

    def list_clients(self, organization_id: UUID) -> list[Client]:
        statement = select(Client).where(
            Client.organization_id == organization_id,
            Client.deleted_at.is_(None),
        )
        statement = statement.order_by(Client.last_updated.desc())
        return list(self.session.scalars(statement).all())

    def list_clients_with_relations(
        self, organization_id: UUID
    ) -> list[Client]:
        """List clients with assigned_user and current_status eagerly loaded."""
        statement = (
            select(Client)
            .options(
                joinedload(Client.assigned_user),
                joinedload(Client.current_status),
            )
            .where(
                Client.organization_id == organization_id,
                Client.deleted_at.is_(None),
            )
        )
        statement = statement.order_by(Client.last_updated.desc())
        return list(self.session.scalars(statement).unique().all())

    def search(
        self, search_term: str, organization_id: UUID
    ) -> list[Client]:
        pattern = f"%{search_term}%"
        statement = (
            select(Client)
            .where(
                Client.deleted_at.is_(None),
                Client.organization_id == organization_id,
                or_(
                    Client.client_name.ilike(pattern),
                    Client.company_name.ilike(pattern),
                    Client.phone.ilike(pattern),
                    Client.whatsapp_number.ilike(pattern),
                    Client.email.ilike(pattern),
                )
            )
        )
        statement = statement.order_by(Client.last_updated.desc())
        return list(self.session.scalars(statement).all())

    def search_with_relations(
        self, search_term: str, organization_id: UUID
    ) -> list[Client]:
        """Search clients with assigned_user and current_status eagerly loaded."""
        pattern = f"%{search_term}%"
        statement = (
            select(Client)
            .options(
                joinedload(Client.assigned_user),
                joinedload(Client.current_status),
            )
            .where(
                Client.deleted_at.is_(None),
                Client.organization_id == organization_id,
                or_(
                    Client.client_name.ilike(pattern),
                    Client.company_name.ilike(pattern),
                    Client.phone.ilike(pattern),
                    Client.whatsapp_number.ilike(pattern),
                    Client.email.ilike(pattern),
                )
            )
        )
        statement = statement.order_by(Client.last_updated.desc())
        return list(self.session.scalars(statement).unique().all())

    def get_by_id_in_organization(
        self, client_id: int, organization_id: UUID
    ) -> Client | None:
        statement = (
            select(Client)
            .where(
                Client.client_id == client_id,
                Client.organization_id == organization_id,
                Client.deleted_at.is_(None),
            )
            .limit(1)
        )
        return self.session.scalars(statement).first()

    def get_by_phone(
        self,
        phone: str,
        organization_id: UUID,
    ) -> Client | None:
        statement = select(Client).where(
            Client.phone == phone,
            Client.organization_id == organization_id,
            Client.deleted_at.is_(None),
        )
        statement = statement.limit(1)
        return self.session.scalars(statement).first()

    def get_by_assigned_user(
        self,
        user_id: UUID,
        organization_id: UUID,
    ) -> list[Client]:
        """Get all clients assigned to a specific user."""
        statement = select(Client).where(
            Client.assigned_to == user_id,
            Client.organization_id == organization_id,
            Client.deleted_at.is_(None),
        )
        return list(self.session.scalars(statement).all())

    def add(self, client: Client) -> None:
        self.session.add(client)

    def delete(self, client: Client) -> None:
        self.session.delete(client)
