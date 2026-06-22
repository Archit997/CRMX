from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Request, status

from services.postgres.exceptions import ConflictError
from services.postgres.dependencies import get_status_service
from services.status.status_service import StatusCreateRequest, StatusService
from utils.constants import LOG_LEVEL_ERROR
from utils.logger import AppLogger

logger = AppLogger.get_logger(__name__)


class StatusController:
    router = APIRouter(tags=["status"])

    @staticmethod
    @router.get("/master-status")
    async def list_statuses(
        request: Request,
        status_service: Annotated[StatusService, Depends(get_status_service)],
    ) -> list[dict]:
        try:
            return status_service.list_statuses()
        except Exception as exc:
            logger.log(
                LOG_LEVEL_ERROR,
                f"List statuses failed for {request.method} {request.url.path}, error: {exc}",
                exc_info=True,
            )
            raise HTTPException(status_code=500, detail="Failed to fetch statuses") from exc

    @staticmethod
    @router.post("/master-status", status_code=status.HTTP_201_CREATED)
    async def create_status(
        payload: StatusCreateRequest,
        request: Request,
        status_service: Annotated[StatusService, Depends(get_status_service)],
    ) -> dict:
        try:
            return status_service.create_status(payload)
        except ConflictError as exc:
            raise HTTPException(status_code=409, detail=str(exc)) from exc
        except Exception as exc:
            logger.log(
                LOG_LEVEL_ERROR,
                f"Create status failed for {request.method} {request.url.path}, error: {exc}",
                exc_info=True,
            )
            raise HTTPException(status_code=500, detail="Failed to create status") from exc


status_router = StatusController.router
