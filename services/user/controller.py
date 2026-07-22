from __future__ import annotations

from typing import Annotated
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
    UserCreateRequest,
    UserService,
    UserUpdateRequest,
    UserVerificationRequest,
)
from utils.constants import LOG_LEVEL_ERROR
from utils.logger import AppLogger

logger = AppLogger.get_logger(__name__)


class UserController:
    router = APIRouter(tags=["users"])

    @staticmethod
    @router.post("/auth/signup-request", status_code=status.HTTP_201_CREATED)
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
        
        The user_id in the payload must match the authenticated user's ID.
        """
        try:
            # Verify that the user_id in payload matches the authenticated user
            auth_user_id = authenticated_user.get("id")
            if str(payload.user_id) != auth_user_id:
                raise HTTPException(
                    status_code=status.HTTP_403_FORBIDDEN,
                    detail="User ID mismatch: cannot create signup request for another user",
                )
            
            return user_service.request_signup(payload)
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
        manager: Annotated[dict, Depends(require_manager_or_admin)],
        user_service: Annotated[UserService, Depends(get_user_service)],
    ) -> list[dict]:
        """
        List users waiting for manager/admin approval.
        
        Access: MANAGER, ADMIN
        """
        try:
            return user_service.list_pending_users()
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
            return user_service.list_assignable_users()
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
        current_user: Annotated[dict, Depends(get_current_user)],
        user_service: Annotated[UserService, Depends(get_user_service)],
    ) -> list[dict]:
        """
        List all users.
        
        Access: All authenticated employees
        """
        try:
            return user_service.list_users()
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
        current_user: Annotated[dict, Depends(get_current_user)],
        user_service: Annotated[UserService, Depends(get_user_service)],
    ) -> dict:
        """
        Get a specific user by ID.
        
        Access: All authenticated employees
        """
        try:
            return user_service.get_user(user_id)
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
        current_user: Annotated[dict, Depends(get_current_user)],
        user_service: Annotated[UserService, Depends(get_user_service)],
    ) -> dict:
        """
        Create a new user.
        
        Access: All authenticated employees
        """
        try:
            return user_service.create_user(payload)
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
        current_user: Annotated[dict, Depends(get_current_user)],
        user_service: Annotated[UserService, Depends(get_user_service)],
    ) -> dict:
        """
        Update a user.
        
        Access: All authenticated employees
        """
        # Ensure the user_id in the path matches the one in the payload
        if payload.user_id != user_id:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="User ID in path does not match user ID in payload",
            )

        try:
            return user_service.update_user(payload)
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
            return user_service.verify_user(user_id, payload)
        except LookupError as exc:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
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
        Delete a user.
        
        Access: ADMIN only
        """
        try:
            return user_service.delete_user(user_id)
        except LookupError as exc:
            raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail=str(exc)) from exc
        except ValueError as exc:
            raise HTTPException(status_code=status.HTTP_400_BAD_REQUEST, detail=str(exc)) from exc
        except Exception as exc:
            logger.log(
                LOG_LEVEL_ERROR,
                f"Delete user failed for {request.method} {request.url.path}, error: {exc}",
                exc_info=True,
            )
            raise HTTPException(status_code=500, detail="Failed to delete user") from exc


user_router = UserController.router
