from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Request

from services.auth.dependencies import require_developer
from services.postgres.constants import POSTGRES_ROUTE_PREFIX, POSTGRES_ROUTE_TAG
from services.postgres.postgres_service import PostgresService
from utils.constants import LOG_LEVEL_ERROR
from utils.logger import AppLogger

logger = AppLogger.get_logger(__name__)


class PostgresController:
    router = APIRouter(prefix=POSTGRES_ROUTE_PREFIX, tags=[POSTGRES_ROUTE_TAG])

    @staticmethod
    def _postgres_service(request: Request) -> PostgresService:
        return request.app.state.postgres_service

    @staticmethod
    @router.get("/health")
    async def health(
        request: Request,
        dev: Annotated[dict, Depends(require_developer)],
    ) -> dict:
        """
        Check PostgreSQL database health.
        
        Access: DEV (Developer) role only
        """
        try:
            return PostgresController._postgres_service(request).health()
        except Exception as exc:
            logger.log(
                LOG_LEVEL_ERROR,
                f"Postgres health endpoint failed for {request.method} {request.url.path}, error: {exc}",
                exc_info=True,
            )
            raise HTTPException(status_code=500, detail="Postgres health check failed") from exc


postgres_router = PostgresController.router
