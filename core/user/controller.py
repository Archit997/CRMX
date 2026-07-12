from __future__ import annotations

from typing import Annotated
from uuid import UUID

from fastapi import APIRouter, Depends, HTTPException, Request, status

from core.postgres.dependencies import get_user_service
from core.user.user_service import UserCreateRequest, UserService, UserUpdateRequest
from utils.constants import LOG_LEVEL_ERROR
from utils.logger import AppLogger

logger = AppLogger.get_logger(__name__)


class UserController:
    router = APIRouter(tags=["users"])

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
