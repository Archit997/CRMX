from fastapi import APIRouter, HTTPException, Request

from services.postgres.postgres_service import PostgresService


class PostgresController:
    router = APIRouter(prefix="/postgres", tags=["postgres"])

    @staticmethod
    def _postgres_service(request: Request) -> PostgresService:
        postgres_service = request.app.state.postgres_service
        if postgres_service is None:
            raise RuntimeError("Postgres is not configured for this local POC run")
        return postgres_service

    @staticmethod
    @router.get("/health")
    async def health(request: Request) -> dict:
        try:
            return PostgresController._postgres_service(request).health()
        except Exception as exc:
            raise HTTPException(status_code=500, detail=str(exc)) from exc


postgres_router = PostgresController.router
