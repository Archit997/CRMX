from __future__ import annotations

import json
from datetime import date, datetime, timezone
from pathlib import Path
from typing import Any, Literal
from uuid import UUID, uuid4

from pydantic import BaseModel, ConfigDict, Field
from sqlalchemy.orm import Session

from db.postgres import Client, ClientUpdate, User
from db.postgres.models import UserRole
from services.audit import record_audit_event
from services.client.constants import CLIENT_SEED_LOOKUP_FIELD, CLIENT_TEST_SEED_PATH
from services.client.client_repository import ClientRepository
from services.client.client_update_repository import ClientUpdateRepository
from services.status.status_repository import StatusRepository
from services.user.user_repository import UserRepository


class ClientListItemResponse(BaseModel):
    """Response model for a single client in the list."""
    client_id: int
    client_name: str
    company_name: str | None
    phone: str
    whatsapp_number: str | None
    email: str | None
    city: str | None
    assigned_to: str  # UUID as string
    assigned_to_name: str  # User's name
    current_status_no: int
    current_status_name: str  # Status name
    requirement_summary: str | None
    priority: str
    created_date: date
    last_updated: datetime

NON_NULLABLE_CLIENT_FIELDS = {
    "client_name",
    "phone",
    "assigned_to",
    "current_status_no",
    "priority",
    "created_date",
}


def _model_payload(model: BaseModel, *, exclude_unset: bool) -> dict[str, Any]:
    if hasattr(model, "model_dump"):
        return model.model_dump(exclude_unset=exclude_unset)
    return model.dict(exclude_unset=exclude_unset)


class ClientCreateRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

    client_name: str = Field(min_length=1, max_length=120)
    company_name: str | None = Field(default=None, max_length=160)
    phone: str = Field(min_length=8, max_length=16)
    whatsapp_number: str | None = Field(default=None, max_length=16)
    email: str | None = Field(default=None, max_length=254)
    city: str | None = Field(default=None, max_length=120)
    assigned_to: UUID
    current_status_no: int
    requirement_summary: str | None = Field(default=None, max_length=4000)
    priority: Literal["Hot", "Warm", "Cold"]
    created_date: date | None = None


class ClientPatchRequest(BaseModel):
    model_config = ConfigDict(extra="forbid", str_strip_whitespace=True)

    client_id: int
    client_name: str | None = Field(default=None, min_length=1, max_length=120)
    company_name: str | None = Field(default=None, max_length=160)
    phone: str | None = Field(default=None, min_length=8, max_length=16)
    whatsapp_number: str | None = Field(default=None, max_length=16)
    email: str | None = Field(default=None, max_length=254)
    city: str | None = Field(default=None, max_length=120)
    assigned_to: UUID | None = None
    current_status_no: int | None = None
    requirement_summary: str | None = Field(default=None, max_length=4000)
    priority: Literal["Hot", "Warm", "Cold"] | None = None
    created_date: date | None = None


class ClientStatusChangeRequest(BaseModel):
    model_config = ConfigDict(extra="forbid")

    client_id: int
    status_id: int


class ClientService:
    def __init__(
        self,
        db_session: Session,
        client_repository: ClientRepository,
        client_update_repository: ClientUpdateRepository,
        status_repository: StatusRepository,
        user_repository: UserRepository,
    ) -> None:
        self.db_session = db_session
        self.client_repository = client_repository
        self.client_update_repository = client_update_repository
        self.status_repository = status_repository
        self.user_repository = user_repository

    def list_clients(self, organization_id: UUID) -> list[dict[str, Any]]:
        clients = self.client_repository.list_clients_with_relations(
            organization_id
        )
        return [self._build_client_list_response(client) for client in clients]

    def search_clients(
        self, search_term: str, organization_id: UUID
    ) -> list[dict[str, Any]]:
        normalized_term = search_term.strip()
        if not normalized_term:
            return []

        clients = self.client_repository.search_with_relations(
            normalized_term, organization_id
        )
        return [self._build_client_list_response(client) for client in clients]

    def _build_client_list_response(self, client: Client) -> dict[str, Any]:
        """Build a client list response with joined user and status names."""
        return {
            "client_id": client.client_id,
            "client_name": client.client_name,
            "company_name": client.company_name,
            "phone": client.phone,
            "whatsapp_number": client.whatsapp_number,
            "email": client.email,
            "city": client.city,
            "assigned_to": str(client.assigned_to),
            "assigned_to_name": client.assigned_user.name if client.assigned_user else "Unknown",
            "current_status_no": client.current_status_no,
            "current_status_name": client.current_status.status_name if client.current_status else "Unknown",
            "requirement_summary": client.requirement_summary,
            "priority": client.priority,
            "created_date": client.created_date,
            "last_updated": client.last_updated,
        }

    def create_client(
        self,
        payload: ClientCreateRequest,
        organization_id: UUID,
        actor_id: UUID,
    ) -> dict[str, Any]:
        self._ensure_status_exists(payload.current_status_no)
        self._ensure_assignable_user(payload.assigned_to, organization_id)
        if self.client_repository.get_by_phone(payload.phone, organization_id):
            raise ValueError(
                "A client with this phone number already exists"
            )

        client_values = _model_payload(payload, exclude_unset=True)
        client_values["client_name"] = " ".join(
            payload.client_name.strip().split()
        )
        client_values["organization_id"] = organization_id
        if client_values.get("created_date") is None:
            client_values.pop("created_date", None)
        client = Client(**client_values)
        self.client_repository.add(client)
        self.db_session.flush()
        record_audit_event(
            self.db_session,
            organization_id=organization_id,
            actor_id=actor_id,
            action="client.created",
            entity_type="client",
            entity_id=client.client_id,
        )
        self.db_session.commit()
        self.db_session.refresh(client)
        return client.to_dict()

    def patch_client(
        self,
        payload: ClientPatchRequest,
        organization_id: UUID,
        actor_id: UUID,
    ) -> dict[str, Any]:
        client_id = payload.client_id
        client = self._ensure_client_exists(client_id, organization_id)

        update_values = _model_payload(payload, exclude_unset=True)
        update_values.pop("client_id", None)

        if not update_values:
            raise ValueError("No client fields provided for update")

        self._validate_non_nullable_update_fields(update_values)

        if "current_status_no" in update_values and update_values["current_status_no"] is not None:
            self._ensure_status_exists(update_values["current_status_no"])
        if (
            "assigned_to" in update_values
            and update_values["assigned_to"] is not None
        ):
            self._ensure_assignable_user(
                update_values["assigned_to"],
                organization_id,
            )
        if "phone" in update_values and update_values["phone"] is not None:
            duplicate = self.client_repository.get_by_phone(
                update_values["phone"],
                organization_id,
            )
            if duplicate is not None and duplicate.client_id != client.client_id:
                raise ValueError(
                    "A client with this phone number already exists"
                )
        if "client_name" in update_values:
            update_values["client_name"] = " ".join(
                update_values["client_name"].split()
            )

        update_values["last_updated"] = datetime.now(timezone.utc)

        client.apply_updates(**update_values)
        record_audit_event(
            self.db_session,
            organization_id=organization_id,
            actor_id=actor_id,
            action="client.updated",
            entity_type="client",
            entity_id=client.client_id,
            metadata={"fields": sorted(update_values.keys())},
        )
        self.db_session.commit()
        self.db_session.refresh(client)
        return client.to_dict()

    @staticmethod
    def _validate_non_nullable_update_fields(update_values: dict[str, Any]) -> None:
        invalid_fields = sorted(
            field_name
            for field_name, field_value in update_values.items()
            if field_name in NON_NULLABLE_CLIENT_FIELDS and field_value is None
        )
        if invalid_fields:
            raise ValueError(
                f"These fields cannot be null: {', '.join(invalid_fields)}"
            )

    def delete_client(
        self,
        client_id: int,
        organization_id: UUID,
        actor_id: UUID,
    ) -> dict[str, Any]:
        client = self._ensure_client_exists(client_id, organization_id)
        client.deleted_at = datetime.now(timezone.utc)
        client.deleted_by = actor_id
        client.touch()
        record_audit_event(
            self.db_session,
            organization_id=organization_id,
            actor_id=actor_id,
            action="client.archived",
            entity_type="client",
            entity_id=client.client_id,
        )
        self.db_session.commit()
        return {"ok": True, "archived_count": 1, "client_id": client_id}

    def change_client_status(
        self,
        payload: ClientStatusChangeRequest,
        organization_id: UUID,
        actor_id: UUID,
    ) -> dict[str, Any]:
        client = self._ensure_client_exists(payload.client_id, organization_id)
        new_status = self._ensure_status_exists(payload.status_id)
        old_status_no = client.current_status_no

        if old_status_no == payload.status_id:
            raise ValueError(
                f"Client {payload.client_id} already has status {payload.status_id}"
            )

        client.apply_updates(current_status_no=payload.status_id)
        status_update = ClientUpdate(
            client_id=client.client_id,
            update_type="Status Change",
            old_status_no=old_status_no,
            new_status_no=payload.status_id,
            request_type="None",
            request_subtype="None",
            note=(
                f"Status changed via API from {old_status_no} to {payload.status_id}"
            ),
            created_by=str(actor_id),
        )
        self.client_update_repository.add(status_update)
        record_audit_event(
            self.db_session,
            organization_id=organization_id,
            actor_id=actor_id,
            action="client.status_changed",
            entity_type="client",
            entity_id=client.client_id,
            metadata={
                "old_status_no": old_status_no,
                "new_status_no": payload.status_id,
            },
        )
        self.db_session.commit()
        self.db_session.refresh(client)
        self.db_session.refresh(status_update)
        return {
            "ok": True,
            "client": client.to_dict(),
            "status_change": {
                "update_id": status_update.update_id,
                "old_status_no": old_status_no,
                "new_status_no": payload.status_id,
                "new_status_name": new_status.status_name,
            },
        }

    def sync_seeded_test_clients(
        self, organization_id: UUID
    ) -> dict[str, Any]:
        """
        Seed test data by:
        1. Loading users and clients from test seed file
        2. Deleting existing test users (cascades to delete their clients)
        3. Creating test users with deterministic UUIDs
        4. Creating test clients assigned to those users
        
        Returns summary of operations performed.
        """
        seed_data = self._load_test_seed_data()
        
        # Track counts
        users_deleted = 0
        users_created = 0
        clients_created = 0
        
        # Step 1: Delete existing test users by phone (this cascades to clients via FK)
        test_user_phones = [user_data['phone'] for user_data in seed_data['users']]
        for phone in test_user_phones:
            existing_user = self.user_repository.get_by_phone(phone)
            if existing_user:
                if existing_user.organization_id != organization_id:
                    continue
                # First delete all clients assigned to this user
                clients_to_delete = self.client_repository.get_by_assigned_user(
                    existing_user.id,
                    organization_id,
                )
                for client in clients_to_delete:
                    self.client_repository.delete(client)
                
                # Then delete the user
                self.user_repository.delete(existing_user)
                users_deleted += 1
        
        self.db_session.commit()
        
        # Step 2: Create test users with deterministic UUIDs
        # Create a mapping of user names to UUIDs
        user_name_to_id = {}
        for user_data in seed_data['users']:
            # Generate deterministic UUID based on phone number
            user_id = uuid4()
            
            user = User(
                id=user_id,
                organization_id=organization_id,
                name=user_data['name'],
                phone=user_data['phone'],
                role=UserRole(user_data['role']),
                approval_status=user_data['approval_status'],
                is_active=user_data['is_active'],
                contact=user_data.get('contact'),
            )
            self.user_repository.add(user)
            user_name_to_id[user_data['name']] = user_id
            users_created += 1
        
        self.db_session.commit()
        
        # Step 3: Create test clients assigned to test users
        for client_data in seed_data['clients']:
            # Validate status exists
            self._ensure_status_exists(client_data['current_status_no'])
            
            # Get the UUID for the assigned user
            assigned_user_name = client_data.pop('assigned_to_name')
            assigned_user_id = user_name_to_id.get(assigned_user_name)
            
            if not assigned_user_id:
                raise ValueError(
                    f"Test user '{assigned_user_name}' not found in seed data. "
                    f"Available users: {list(user_name_to_id.keys())}"
                )
            
            # Create client with proper UUID reference
            client = Client(
                organization_id=organization_id,
                client_name=client_data['client_name'],
                company_name=client_data.get('company_name'),
                phone=client_data['phone'],
                whatsapp_number=client_data.get('whatsapp_number'),
                email=client_data.get('email'),
                city=client_data.get('city'),
                assigned_to=assigned_user_id,
                current_status_no=client_data['current_status_no'],
                requirement_summary=client_data.get('requirement_summary'),
                priority=client_data['priority'],
                created_date=(
                    datetime.strptime(client_data['created_date'], '%Y-%m-%d').date()
                    if client_data.get('created_date')
                    else date.today()
                ),
            )
            self.client_repository.add(client)
            clients_created += 1
        
        self.db_session.commit()
        
        return {
            "ok": True,
            "seed_path": str(CLIENT_TEST_SEED_PATH),
            "users_deleted": users_deleted,
            "users_created": users_created,
            "clients_created": clients_created,
            "test_users": list(user_name_to_id.keys()),
        }

    @staticmethod
    def _load_test_seed_data(seed_path: Path = CLIENT_TEST_SEED_PATH) -> dict[str, Any]:
        """Load test seed data containing users and clients."""
        with seed_path.open("r", encoding="utf-8") as seed_file:
            data = json.load(seed_file)
        
        # Validate structure
        if 'users' not in data or 'clients' not in data:
            raise ValueError(
                "Invalid seed data structure. Expected 'users' and 'clients' keys."
            )
        
        return data

    def _ensure_status_exists(self, status_no: int):
        status = self.status_repository.get_by_no(status_no)
        if status is None:
            raise ValueError(f"Status {status_no} does not exist")
        return status

    def _ensure_assignable_user(
        self,
        user_id: UUID,
        organization_id: UUID,
    ) -> User:
        user = self.user_repository.get_by_id_in_organization(
            user_id,
            organization_id,
        )
        if (
            user is None
            or user.approval_status != "approved"
            or not user.is_active
            or user.role == UserRole.DEV
        ):
            raise ValueError(
                "Assigned employee is not active in your organization"
            )
        return user

    def _ensure_client_exists(
        self, client_id: int, organization_id: UUID
    ) -> Client:
        client = self.client_repository.get_by_id_in_organization(
            client_id, organization_id
        )
        if client is None:
            raise LookupError(f"Client {client_id} not found")
        return client
