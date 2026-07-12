from __future__ import annotations

from typing import Any, Literal

from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from db.postgres import StatusMaster
from core.postgres.exceptions import ConflictError
from core.status.status_repository import StatusRepository


def _model_payload(model: BaseModel) -> dict[str, Any]:
    if hasattr(model, "model_dump"):
        return model.model_dump(exclude_unset=True)
    return model.dict(exclude_unset=True)


class StatusCreateRequest(BaseModel):
    status_no: int
    status_name: str = Field(min_length=1)
    category: Literal["Lead", "Client", "Critical"]
    description: str | None = None
    is_active: bool = True


class StatusService:
    def __init__(self, db_session: Session, status_repository: StatusRepository) -> None:
        self.db_session = db_session
        self.status_repository = status_repository

    def list_statuses(self) -> list[dict[str, Any]]:
        return [status.to_dict() for status in self.status_repository.list_all()]

    def create_status(self, payload: StatusCreateRequest) -> dict[str, Any]:
        existing_status = self.status_repository.get_by_no(payload.status_no)
        if existing_status is not None:
            raise ConflictError(f"Status {payload.status_no} already exists")

        status_record = StatusMaster(**_model_payload(payload))
        self.status_repository.add(status_record)
        self.db_session.commit()
        self.db_session.refresh(status_record)
        return status_record.to_dict()
