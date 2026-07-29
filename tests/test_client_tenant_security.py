from __future__ import annotations

from unittest.mock import MagicMock
from uuid import uuid4

import pytest

from db.postgres import Client
from services.client.client_service import ClientCreateRequest, ClientService


def _service() -> tuple[ClientService, MagicMock, MagicMock, MagicMock]:
    db_session = MagicMock()
    client_repository = MagicMock()
    status_repository = MagicMock()
    status_repository.get_by_no.return_value = MagicMock()
    user_repository = MagicMock()
    service = ClientService(
        db_session,
        client_repository,
        MagicMock(),
        status_repository,
        user_repository,
    )
    return service, db_session, client_repository, user_repository


def test_client_assignment_cannot_cross_organization() -> None:
    service, _, _, user_repository = _service()
    user_repository.get_by_id_in_organization.return_value = None

    with pytest.raises(ValueError, match="not active"):
        service.create_client(
            ClientCreateRequest(
                client_name="ABC Traders",
                phone="+919999999999",
                assigned_to=uuid4(),
                current_status_no=1,
                priority="Hot",
            ),
            organization_id=uuid4(),
            actor_id=uuid4(),
        )


def test_client_delete_archives_instead_of_removing_history() -> None:
    service, db_session, client_repository, _ = _service()
    organization_id = uuid4()
    actor_id = uuid4()
    client = Client(
        client_id=101,
        client_name="ABC Traders",
        phone="+919999999999",
        organization_id=organization_id,
        assigned_to=uuid4(),
        current_status_no=1,
        priority="Hot",
    )
    client_repository.get_by_id_in_organization.return_value = client

    result = service.delete_client(
        client.client_id,
        organization_id,
        actor_id,
    )

    client_repository.delete.assert_not_called()
    assert client.deleted_at is not None
    assert client.deleted_by == actor_id
    assert result["archived_count"] == 1
    db_session.commit.assert_called_once()
