from __future__ import annotations

import json
from datetime import date, datetime, timezone
from pathlib import Path
from typing import Any, Literal
from uuid import UUID

from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from db.postgres import Client, ClientUpdate
from services.client.constants import CLIENT_SEED_LOOKUP_FIELD, CLIENT_TEST_SEED_PATH
from services.client.client_repository import ClientRepository
from services.client.client_update_repository import ClientUpdateRepository
from services.status.status_repository import StatusRepository

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
    client_name: str = Field(min_length=1)
    company_name: str | None = None
    phone: str = Field(min_length=1)
    whatsapp_number: str | None = None
    email: str | None = None
    city: str | None = None
    assigned_to: UUID
    current_status_no: int
    requirement_summary: str | None = None
    priority: Literal["Hot", "Warm", "Cold"]
    created_date: date | None = None


class ClientPatchRequest(BaseModel):
    client_id: int
    client_name: str | None = None
    company_name: str | None = None
    phone: str | None = None
    whatsapp_number: str | None = None
    email: str | None = None
    city: str | None = None
    assigned_to: UUID | None = None
    current_status_no: int | None = None
    requirement_summary: str | None = None
    priority: Literal["Hot", "Warm", "Cold"] | None = None
    created_date: date | None = None


class ClientStatusChangeRequest(BaseModel):
    client_id: int
    status_id: int


class ClientService:
    def __init__(
        self,
        db_session: Session,
        client_repository: ClientRepository,
        client_update_repository: ClientUpdateRepository,
        status_repository: StatusRepository,
    ) -> None:
        self.db_session = db_session
        self.client_repository = client_repository
        self.client_update_repository = client_update_repository
        self.status_repository = status_repository

    def list_clients(self) -> list[dict[str, Any]]:
        return [client.to_dict() for client in self.client_repository.list_clients()]

    def search_clients(self, search_term: str) -> list[dict[str, Any]]:
        normalized_term = search_term.strip()
        if not normalized_term:
            return []

        return [client.to_dict() for client in self.client_repository.search(normalized_term)]

    def create_client(self, payload: ClientCreateRequest) -> dict[str, Any]:
        self._ensure_status_exists(payload.current_status_no)

        client_values = _model_payload(payload, exclude_unset=True)
        if client_values.get("created_date") is None:
            client_values.pop("created_date", None)
        client = Client(**client_values)
        self.client_repository.add(client)
        self.db_session.commit()
        self.db_session.refresh(client)
        return client.to_dict()

    def patch_client(self, payload: ClientPatchRequest) -> dict[str, Any]:
        client_id = payload.client_id
        client = self._ensure_client_exists(client_id)

        update_values = _model_payload(payload, exclude_unset=True)
        update_values.pop("client_id", None)

        if not update_values:
            raise ValueError("No client fields provided for update")

        self._validate_non_nullable_update_fields(update_values)

        if "current_status_no" in update_values and update_values["current_status_no"] is not None:
            self._ensure_status_exists(update_values["current_status_no"])

        update_values["last_updated"] = datetime.now(timezone.utc)

        client.apply_updates(**update_values)
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

    def delete_client(self, client_id: int) -> dict[str, Any]:
        client = self._ensure_client_exists(client_id)
        self.client_repository.delete(client)
        self.db_session.commit()
        return {"ok": True, "deleted_count": 1, "client_id": client_id}

    def change_client_status(self, payload: ClientStatusChangeRequest) -> dict[str, Any]:
        client = self._ensure_client_exists(payload.client_id)
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
            created_by="system",
        )
        self.client_update_repository.add(status_update)
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

    def sync_seeded_test_clients(self) -> dict[str, Any]:
        seeded_clients = self._load_seeded_test_clients()
        inserted = 0
        updated = 0

        for payload in seeded_clients:
            self._ensure_status_exists(payload.current_status_no)
            client_values = _model_payload(payload, exclude_unset=True)
            if client_values.get("created_date") is None:
                client_values.pop("created_date", None)

            existing_client = self.client_repository.get_by_phone(payload.phone)
            if existing_client is None:
                self.client_repository.add(Client(**client_values))
                inserted += 1
                continue

            existing_client.apply_updates(**client_values)
            updated += 1

        self.db_session.commit()
        return {
            "ok": True,
            "lookup_field": CLIENT_SEED_LOOKUP_FIELD,
            "seed_path": str(CLIENT_TEST_SEED_PATH),
            "seeded_count": len(seeded_clients),
            "inserted_count": inserted,
            "updated_count": updated,
        }

    def _ensure_status_exists(self, status_no: int):
        status = self.status_repository.get_by_no(status_no)
        if status is None:
            raise ValueError(f"Status {status_no} does not exist")
        return status

    def _ensure_client_exists(self, client_id: int) -> Client:
        client = self.client_repository.get_by_id(client_id)
        if client is None:
            raise LookupError(f"Client {client_id} not found")
        return client

    @staticmethod
    def _load_seeded_test_clients(seed_path: Path = CLIENT_TEST_SEED_PATH) -> list[ClientCreateRequest]:
        with seed_path.open("r", encoding="utf-8") as seed_file:
            payload = json.load(seed_file)
        return [ClientCreateRequest(**item) for item in payload]
