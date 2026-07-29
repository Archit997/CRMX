from __future__ import annotations

from datetime import datetime, timezone
from unittest.mock import MagicMock
from uuid import uuid4

import pytest
from pydantic import ValidationError

from db.postgres import Organization, User
from db.postgres.models import UserRole
from services.organization.organization_service import (
    OrganizationBootstrapRequest,
    OrganizationService,
)
from services.user.user_service import (
    SignupRequest,
    UserService,
    UserVerificationRequest,
)


def test_new_company_bootstrap_creates_approved_admin() -> None:
    db_session = MagicMock()
    organization_repository = MagicMock()
    organization_repository.slug_exists.return_value = False
    organization_repository.join_code_exists.return_value = False
    user_repository = MagicMock()
    user_repository.get_by_id.return_value = None
    user_repository.get_by_phone.return_value = None
    service = OrganizationService(
        db_session,
        organization_repository,
        user_repository,
    )
    user_id = uuid4()

    result = service.bootstrap(
        OrganizationBootstrapRequest(
            organization_name="Sharma Steel Works",
            admin_name="Om Sharma",
        ),
        user_id=user_id,
        phone="+919999999999",
    )

    created_user = user_repository.add.call_args.args[0]
    assert created_user.id == user_id
    assert created_user.role == UserRole.ADMIN
    assert created_user.approval_status == "approved"
    assert created_user.is_active is True
    assert created_user.organization_id is not None
    join_code = result["organization"]["join_code"]
    assert join_code.startswith("SHARMAST-")
    assert len(join_code.rsplit("-", maxsplit=1)[1]) == 10


def test_employee_signup_requires_a_valid_organization_code() -> None:
    db_session = MagicMock()
    user_repository = MagicMock()
    user_repository.get_any_by_id.return_value = None
    user_repository.get_by_phone.return_value = None
    organization_repository = MagicMock()
    organization_repository.get_by_join_code.return_value = None
    service = UserService(
        db_session,
        user_repository,
        organization_repository,
    )

    with pytest.raises(ValueError, match="Organization code not found"):
        service.request_signup(
            SignupRequest(
                name="Ravi Kumar",
                organization_code="WRONG-CODE",
                role="EMPLOYEE",
            ),
            user_id=uuid4(),
            phone="+918888888888",
        )


def test_employee_signup_is_pending_in_selected_organization() -> None:
    db_session = MagicMock()
    user_repository = MagicMock()
    user_repository.get_any_by_id.return_value = None
    user_repository.get_by_phone.return_value = None
    organization = Organization(
        id=uuid4(),
        name="Sharma Steel Works",
        slug="sharma-steel-works",
        join_code="SHARMAST-AB12",
        is_active=True,
    )
    organization_repository = MagicMock()
    organization_repository.get_by_join_code.return_value = organization
    service = UserService(
        db_session,
        user_repository,
        organization_repository,
    )

    service.request_signup(
        SignupRequest(
            name="Ravi Kumar",
            organization_code="sharmast-ab12",
            role="EMPLOYEE",
        ),
        user_id=uuid4(),
        phone="+918888888888",
    )

    created_user = user_repository.add.call_args.args[0]
    assert created_user.organization_id == organization.id
    assert created_user.approval_status == "pending"
    assert created_user.is_active is False


def test_admin_approval_is_scoped_and_audited() -> None:
    db_session = MagicMock()
    organization_id = uuid4()
    admin_id = uuid4()
    pending_user = User(
        id=uuid4(),
        organization_id=organization_id,
        name="Ravi Kumar",
        role=UserRole.EMPLOYEE,
        phone="+918888888888",
        approval_status="pending",
        is_active=False,
    )
    user_repository = MagicMock()
    user_repository.get_by_id_in_organization.return_value = pending_user
    service = UserService(
        db_session,
        user_repository,
        MagicMock(),
    )

    result = service.verify_user(
        pending_user.id,
        UserVerificationRequest(approval_status="approved"),
        organization_id,
        admin_id,
    )

    user_repository.get_by_id_in_organization.assert_called_once_with(
        pending_user.id, organization_id
    )
    assert result["approval_status"] == "approved"
    assert result["is_active"] is True
    assert result["verified_by"] == str(admin_id)


def test_signup_rejects_client_supplied_identity_fields() -> None:
    with pytest.raises(ValidationError):
        SignupRequest(
            user_id=uuid4(),
            phone="+918888888888",
            name="Ravi Kumar",
            organization_code="SHARMAST-AB12",
            role="EMPLOYEE",
        )


def test_archived_user_cannot_submit_a_new_signup_request() -> None:
    archived_user = User(
        id=uuid4(),
        organization_id=uuid4(),
        name="Ravi Kumar",
        role=UserRole.EMPLOYEE,
        phone="+918888888888",
        approval_status="rejected",
        is_active=False,
        deleted_at=datetime.now(timezone.utc),
    )
    user_repository = MagicMock()
    user_repository.get_any_by_id.return_value = archived_user
    service = UserService(
        MagicMock(),
        user_repository,
        MagicMock(),
    )

    with pytest.raises(ValueError, match="archived"):
        service.request_signup(
            SignupRequest(
                name="Ravi Kumar",
                organization_code="SHARMAST-AB12",
            ),
            user_id=archived_user.id,
            phone=archived_user.phone,
        )


def test_user_delete_is_soft_and_scoped_to_admin_organization() -> None:
    organization_id = uuid4()
    admin_id = uuid4()
    employee = User(
        id=uuid4(),
        organization_id=organization_id,
        name="Ravi Kumar",
        role=UserRole.EMPLOYEE,
        phone="+918888888888",
        approval_status="approved",
        is_active=False,
    )
    db_session = MagicMock()
    db_session.query.return_value.filter.return_value.count.return_value = 0
    user_repository = MagicMock()
    user_repository.get_by_id_in_organization.return_value = employee
    service = UserService(
        db_session,
        user_repository,
        MagicMock(),
    )

    result = service.delete_user(
        employee.id,
        organization_id,
        admin_id,
    )

    user_repository.get_by_id_in_organization.assert_called_once_with(
        employee.id,
        organization_id,
    )
    user_repository.delete.assert_not_called()
    assert employee.deleted_at is not None
    assert employee.deleted_by == admin_id
    assert result["archived_count"] == 1
