from __future__ import annotations

from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, status

from services.auth.dependencies import (
    get_authenticated_user_for_signup,
    require_admin,
)
from services.organization.organization_service import (
    OrganizationBootstrapRequest,
    OrganizationService,
)
from services.postgres.dependencies import get_organization_service


router = APIRouter(prefix="/api/organizations", tags=["organizations"])


@router.post("/bootstrap", status_code=status.HTTP_201_CREATED)
async def bootstrap_organization(
    payload: OrganizationBootstrapRequest,
    authenticated_user: Annotated[
        dict, Depends(get_authenticated_user_for_signup)
    ],
    organization_service: Annotated[
        OrganizationService, Depends(get_organization_service)
    ],
) -> dict:
    phone = authenticated_user.get("phone")
    if not phone:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authenticated phone number is missing",
        )
    try:
        return organization_service.bootstrap(
            payload,
            user_id=UUID(authenticated_user["id"]),
            phone=phone,
        )
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=str(exc),
        ) from exc


@router.get("/me")
async def get_my_organization(
    admin: Annotated[dict, Depends(require_admin)],
    organization_service: Annotated[
        OrganizationService, Depends(get_organization_service)
    ],
) -> dict:
    organization_id = admin.get("organization_id")
    if not organization_id:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Organization setup is required",
        )
    try:
        return organization_service.get_for_user(UUID(organization_id))
    except LookupError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(exc),
        ) from exc

@router.post("/join-code/rotate")
async def rotate_join_code(
    admin: Annotated[dict, Depends(require_admin)],
    organization_service: Annotated[
        OrganizationService, Depends(get_organization_service)
    ],
) -> dict:
    organization_id = admin.get("organization_id")
    if not organization_id:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Organization setup is required",
        )
    try:
        return organization_service.rotate_join_code(
            UUID(organization_id),
            UUID(admin["id"]),
        )
    except LookupError as exc:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail=str(exc),
        ) from exc
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail=str(exc),
        ) from exc


organization_router = router
