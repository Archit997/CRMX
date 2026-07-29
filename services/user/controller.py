from __future__ import annotations

from typing import Annotated, Literal
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Request, status

from services.auth.dependencies import (
    get_authenticated_user_for_signup,
    get_current_user,
    require_admin,
    require_manager_or_admin,
)
from services.postgres.dependencies import get_user_service
from services.user.user_service import (
    SignupRequest,
    UserAccessUpdateRequest,
    UserCreateRequest,
    UserService,
    UserUpdateRequest,
    UserVerificationRequest,
)
from utils.constants import LOG_LEVEL_ERROR
from utils.logging import AppLogger

logger = AppLogger.get_logger(__name__)


class UserController:
    router = APIRouter(tags=["users"])

    @staticmethod
    @router.post(
        "/api/auth/signup-request",
        status_code=status.HTTP_201_CREATED,
    )
    async def request_signup(
        payload: SignupRequest,
        request: Request,
        authenticated_user: Annotated[dict, Depends(get_authenticated_user_for_signup)],
        user_service: Annotated[UserService, Depends(get_user_service)],
    ) -> dict:
        """
        Create a pending CRMX user profile after backend OTP verification.
        
        This endpoint is called when a new user completes OTP verification but
        doesn't have a profile in the CRMX database yet. The user must provide
        their name, role, and optional contact info to create a signup request
        pending admin approval.
        
        Special: This endpoint allows inactive/not-approved users to access it
        (since they're creating their initial signup request).
        
        User ID and phone are derived from the verified Supabase JWT.
        """
        try:
            phone = authenticated_user.get("phone")
            if not phone:
                raise HTTPException(
                    status_code=status.HTTP_401_UNAUTHORIZED,
                    detail="Authenticated phone number is missing",
                )

            return user_service.request_signup(
                payload,
                user_id=UUID(authenticated_user["id"]),
                phone=phone,
            )
        except ValueError as exc:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
        except HTTPException:
            raise
        except Exception as exc:
            logger.log(
                LOG_LEVEL_ERROR,
                f"Signup request failed for {request.method} {request.url.path}, error: {exc}",
                exc_info=True,
            )
            raise HTTPException(status_code=500, detail="Failed to create signup request") from exc

    @staticmethod
    @router.get("/users/pending")
    async def list_pending_users(
        request: Request,
        admin: Annotated[dict, Depends(require_admin)],
        user_service: Annotated[UserService, Depends(get_user_service)],
    ) -> list[dict]:
        """
        List users waiting for manager/admin approval.
        
        Access: ADMIN only
        """
        try:
            return user_service.list_pending_users(
                _organization_id(admin)
            )
        except Exception as exc:
            logger.log(
                LOG_LEVEL_ERROR,
                f"List pending users failed for {request.method} {request.url.path}, error: {exc}",
                exc_info=True,
            )
            raise HTTPException(status_code=500, detail="Failed to fetch pending users") from exc

    @staticmethod
    @router.get("/users/assignable")
    async def list_assignable_users(
        request: Request,
        manager: Annotated[dict, Depends(require_manager_or_admin)],
        user_service: Annotated[UserService, Depends(get_user_service)],
    ) -> list[dict]:
        """
        List users who can be assigned to clients (approved, active, non-DEV role).
        
        Access: MANAGER, ADMIN
        """
        try:
            return user_service.list_assignable_users(
                _organization_id(manager)
            )
        except Exception as exc:
            logger.log(
                LOG_LEVEL_ERROR,
                f"List assignable users failed for {request.method} {request.url.path}, error: {exc}",
                exc_info=True,
            )
            raise HTTPException(status_code=500, detail="Failed to fetch assignable users") from exc

    @staticmethod
    @router.get("/users")
    async def list_users(
        request: Request,
        admin: Annotated[dict, Depends(require_admin)],
        user_service: Annotated[UserService, Depends(get_user_service)],
        approval_status: Literal["pending", "approved", "rejected"] | None = None,
    ) -> list[dict]:
        """
        List all users.
        
        Access: ADMIN only. Results are scoped to the admin's organization.
        """
        try:
            return user_service.list_users(
                _organization_id(admin), approval_status
            )
        except Exception as exc:
            logger.log(
                LOG_LEVEL_ERROR,
                f"List users failed for {request.method} {request.url.path}, error: {exc}",
                exc_info=True,
            )
            raise HTTPException(status_code=500, detail="Failed to fetch users") from exc

    @staticmethod
    @router.get("/users/{user_id}")
    async def get_user(
        user_id: UUID,
        request: Request,
        admin: Annotated[dict, Depends(require_admin)],
        user_service: Annotated[UserService, Depends(get_user_service)],
    ) -> dict:
        """
        Get a specific user by ID.
        
        Access: ADMIN only
        """
        try:
            return user_service.get_user(user_id, _organization_id(admin))
        except LookupError as exc:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
        except Exception as exc:
            logger.log(
                LOG_LEVEL_ERROR,
                f"Get user failed for {request.method} {request.url.path}, error: {exc}",
                exc_info=True,
            )
            raise HTTPException(status_code=500, detail="Failed to fetch user") from exc

    @staticmethod
    @router.post("/users", status_code=status.HTTP_201_CREATED)
    async def create_user(
        payload: UserCreateRequest,
        request: Request,
        admin: Annotated[dict, Depends(require_admin)],
        user_service: Annotated[UserService, Depends(get_user_service)],
    ) -> dict:
        """
        Create a new user.
        
        Access: ADMIN only
        """
        try:
            return user_service.create_user(
                payload,
                _organization_id(admin),
                UUID(admin["id"]),
            )
        except ValueError as exc:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
        except Exception as exc:
            logger.log(
                LOG_LEVEL_ERROR,
                f"Create user failed for {request.method} {request.url.path}, error: {exc}",
                exc_info=True,
            )
            raise HTTPException(status_code=500, detail="Failed to create user") from exc

    @staticmethod
    @router.patch("/users/{user_id}")
    async def update_user(
        user_id: UUID,
        payload: UserUpdateRequest,
        request: Request,
        admin: Annotated[dict, Depends(require_admin)],
        user_service: Annotated[UserService, Depends(get_user_service)],
    ) -> dict:
        """
        Update a user.
        
        Access: ADMIN only
        """
        # Ensure the user_id in the path matches the one in the payload
        if payload.user_id != user_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="User ID in path does not match user ID in payload",
            )

        try:
            return user_service.update_user(
                payload,
                _organization_id(admin),
                UUID(admin["id"]),
            )
        except LookupError as exc:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
        except ValueError as exc:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
        except Exception as exc:
            logger.log(
                LOG_LEVEL_ERROR,
                f"Update user failed for {request.method} {request.url.path}, error: {exc}",
                exc_info=True,
            )
            raise HTTPException(status_code=500, detail="Failed to update user") from exc

    @staticmethod
    @router.patch("/users/{user_id}/verification")
    async def verify_user(
        user_id: UUID,
        payload: UserVerificationRequest,
        request: Request,
        admin: Annotated[dict, Depends(require_admin)],
        user_service: Annotated[UserService, Depends(get_user_service)],
    ) -> dict:
        """
        Approve or reject a pending user.
        
        Access: ADMIN only
        """
        try:
            return user_service.verify_user(
                user_id,
                payload,
                _organization_id(admin),
                UUID(admin["id"]),
            )
        except LookupError as exc:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
        except ValueError as exc:
            raise HTTPException(
                status_code=status.HTTP_409_CONFLICT,
                detail=str(exc),
            ) from exc
        except Exception as exc:
            logger.log(
                LOG_LEVEL_ERROR,
                f"Verify user failed for {request.method} {request.url.path}, error: {exc}",
                exc_info=True,
            )
            raise HTTPException(status_code=500, detail="Failed to verify user") from exc

    @staticmethod
    @router.delete("/users/{user_id}")
    async def delete_user(
        user_id: UUID,
        request: Request,
        admin: Annotated[dict, Depends(require_admin)],
        user_service: Annotated[UserService, Depends(get_user_service)],
    ) -> dict:
        """
        Archive a user while preserving history and audit records.
        
        Access: ADMIN only
        """
        try:
            return user_service.delete_user(
                user_id,
                _organization_id(admin),
                UUID(admin["id"]),
            )
        except LookupError as exc:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
        except ValueError as exc:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
        except Exception as exc:
            logger.log(
                LOG_LEVEL_ERROR,
                f"Archive user failed for {request.method} {request.url.path}, error: {exc}",
                exc_info=True,
            )
            raise HTTPException(status_code=500, detail="Failed to archive user") from exc


    @staticmethod
    @router.patch("/users/{user_id}/access")
    async def update_user_access(
        user_id: UUID,
        payload: UserAccessUpdateRequest,
        request: Request,
        admin: Annotated[dict, Depends(require_admin)],
        user_service: Annotated[UserService, Depends(get_user_service)],
    ) -> dict:
        """Change an employee role or active state inside the admin's organization."""
        try:
            return user_service.update_access(
                user_id,
                payload,
                _organization_id(admin),
                UUID(admin["id"]),
            )
        except LookupError as exc:
            raise HTTPException(
                status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)
            ) from exc
        except ValueError as exc:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)
            ) from exc
        except Exception as exc:
            logger.log(
                LOG_LEVEL_ERROR,
                f"Update access failed for {request.method} {request.url.path}, error: {exc}",
                exc_info=True,
            )
            raise HTTPException(
                status_code=500, detail="Failed to update user access"
            ) from exc


def _organization_id(user: dict) -> UUID:
    value = user.get("organization_id")
    if not value:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Organization setup is required",
        )
    return UUID(value)


user_router = UserController.router
