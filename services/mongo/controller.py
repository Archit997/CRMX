from fastapi import APIRouter, HTTPException, Request

from services.mongo.mongo_service import MongoService


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
            raise HTTPException(status_code=500, detail=str(exc)) from exc


mongo_router = MongoController.router
