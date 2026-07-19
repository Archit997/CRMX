from __future__ import annotations

from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Request, status

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
from utils.supabase_jwt import assert_supabase_user_matches_request

logger = AppLogger.get_logger(__name__)


class UserController:
    router = APIRouter(tags=["users"])

    @staticmethod
    @router.get("/auth/profile/{user_id}")
    async def get_auth_profile(
        user_id: UUID,
        request: Request,
        user_service: Annotated[UserService, Depends(get_user_service)],
    ) -> dict:
        """Get the CRMX app profile and approval state for a Supabase auth user."""
        try:
            assert_supabase_user_matches_request(request, user_id)
            return user_service.get_user_profile(user_id)
        except HTTPException:
            raise
        except Exception as exc:
            logger.log(
                LOG_LEVEL_ERROR,
                f"Get auth profile failed for {request.method} {request.url.path}, error: {exc}",
                exc_info=True,
            )
            raise HTTPException(status_code=500, detail="Failed to fetch auth profile") from exc

    @staticmethod
    @router.post("/auth/signup-request", status_code=status.HTTP_201_CREATED)
    async def request_signup(
        payload: SignupRequest,
        request: Request,
        user_service: Annotated[UserService, Depends(get_user_service)],
    ) -> dict:
        """Create a pending CRMX user profile after Supabase phone OTP verification."""
        try:
            assert_supabase_user_matches_request(request, payload.user_id)
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
        user_service: Annotated[UserService, Depends(get_user_service)],
    ) -> list[dict]:
        """List users waiting for manager approval."""
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
        user_service: Annotated[UserService, Depends(get_user_service)],
    ) -> list[dict]:
        """List users who can be assigned to clients (approved, active, non-DEV role)."""
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
        user_service: Annotated[UserService, Depends(get_user_service)],
    ) -> list[dict]:
        """List all users."""
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
        user_service: Annotated[UserService, Depends(get_user_service)],
    ) -> dict:
        """Get a specific user by ID."""
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
        user_service: Annotated[UserService, Depends(get_user_service)],
    ) -> dict:
        """Create a new user."""
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
        user_service: Annotated[UserService, Depends(get_user_service)],
    ) -> dict:
        """Update a user."""
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
        user_service: Annotated[UserService, Depends(get_user_service)],
    ) -> dict:
        """Approve or reject a pending user."""
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
        user_service: Annotated[UserService, Depends(get_user_service)],
    ) -> dict:
        """Delete a user."""
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
