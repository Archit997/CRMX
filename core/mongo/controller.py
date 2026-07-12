from fastapi import APIRouter, HTTPException, Request

from core.mongo.mongo_service import MongoService
from utils.constants import LOG_LEVEL_ERROR
from utils.logger import AppLogger

logger = AppLogger.get_logger(__name__)


class MongoController:
    router = APIRouter()

    @staticmethod
    def _mongo_service(request: Request) -> MongoService:
        return request.app.state.mongo_service

    @staticmethod
    @router.get("/health")
    async def health(request: Request) -> dict:
        try:
            return MongoController._mongo_service(request).health()
        except Exception as exc:
            logger.log(
                LOG_LEVEL_ERROR,
                f"Mongo health endpoint failed for {request.method} {request.url.path}, error: {exc}",
                exc_info=True,
            )
            raise HTTPException(status_code=500, detail="Mongo health check failed") from exc


mongo_router = MongoController.router
