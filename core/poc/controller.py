from __future__ import annotations

from typing import Any

from fastapi import APIRouter, HTTPException, Request, Response

from core.poc.poc_data_service import POCDataService


class POCController:
    router = APIRouter(prefix="/api", tags=["poc"])

    @staticmethod
    def _service(request: Request) -> POCDataService:
        return request.app.state.poc_data_service

    @staticmethod
    @router.get("/health")
    async def health() -> dict[str, Any]:
        return {"ok": True, "mode": "json-poc"}

    @staticmethod
    @router.get("/health/cron")
    async def cron_health() -> dict[str, Any]:
        return {
            "ok": True,
            "jobs": [
                {"name": "daily_followup_digest", "status": "ready"},
                {"name": "receivable_digest", "status": "ready"},
                {"name": "call_audit_ingestion", "status": "planned"},
            ],
        }

    @staticmethod
    @router.post("/auth/login")
    async def login(request: Request, payload: dict[str, Any]) -> dict[str, Any]:
        session = POCController._service(request).authenticate(
            identifier=str(payload.get("identifier", "")),
            password=str(payload.get("password", "")),
        )
        if session is None:
            raise HTTPException(status_code=401, detail="Invalid phone/email or password")
        return session

    @staticmethod
    @router.get("/statuses")
    async def statuses(request: Request) -> list[dict[str, Any]]:
        return POCController._service(request).status_master()

    @staticmethod
    @router.post("/statuses", status_code=201)
    async def create_status(request: Request, payload: dict[str, Any]) -> dict[str, Any]:
        try:
            return POCController._service(request).create_status(payload)
        except KeyError as exc:
            raise HTTPException(status_code=422, detail=f"Missing field: {exc}") from exc

    @staticmethod
    @router.get("/clients")
    async def clients(request: Request) -> list[dict[str, Any]]:
        return POCController._service(request).clients()

    @staticmethod
    @router.get("/clients/search")
    async def search_clients(request: Request, q: str = "") -> list[dict[str, Any]]:
        return POCController._service(request).search_clients(q)

    @staticmethod
    @router.post("/clients", status_code=201)
    async def create_client(request: Request, payload: dict[str, Any]) -> dict[str, Any]:
        try:
            return POCController._service(request).create_client(payload)
        except KeyError as exc:
            raise HTTPException(status_code=422, detail=f"Missing field: {exc}") from exc

    @staticmethod
    @router.get("/clients/{client_id}")
    async def client(request: Request, client_id: int) -> dict[str, Any]:
        row = POCController._service(request).client(client_id)
        if row is None:
            raise HTTPException(status_code=404, detail="Client not found")
        return row

    @staticmethod
    @router.patch("/clients/{client_id}")
    async def update_client(
        request: Request,
        client_id: int,
        payload: dict[str, Any],
    ) -> dict[str, Any]:
        try:
            return POCController._service(request).update_client(client_id, payload)
        except ValueError as exc:
            raise HTTPException(status_code=404, detail=str(exc)) from exc

    @staticmethod
    @router.delete("/clients/{client_id}", status_code=204)
    async def delete_client(request: Request, client_id: int) -> Response:
        try:
            POCController._service(request).delete_client(client_id)
            return Response(status_code=204)
        except ValueError as exc:
            raise HTTPException(status_code=404, detail=str(exc)) from exc

    @staticmethod
    @router.get("/clients/{client_id}/updates")
    async def client_updates(request: Request, client_id: int) -> list[dict[str, Any]]:
        if POCController._service(request).client(client_id) is None:
            raise HTTPException(status_code=404, detail="Client not found")
        return POCController._service(request).client_updates(client_id)

    @staticmethod
    @router.post("/clients/{client_id}/updates", status_code=201)
    async def create_client_update(
        request: Request,
        client_id: int,
        payload: dict[str, Any],
    ) -> dict[str, Any]:
        try:
            return POCController._service(request).create_client_update(client_id, payload)
        except KeyError as exc:
            raise HTTPException(status_code=422, detail=f"Missing field: {exc}") from exc
        except ValueError as exc:
            raise HTTPException(status_code=404, detail=str(exc)) from exc

    @staticmethod
    @router.get("/followups/today")
    async def followups_today(request: Request) -> list[dict[str, Any]]:
        return POCController._service(request).followups_today()

    @staticmethod
    @router.get("/analytics/manager")
    async def manager_analytics(request: Request) -> dict[str, Any]:
        return POCController._service(request).manager_analytics()

    @staticmethod
    @router.get("/finance/receivables")
    async def finance_receivables(request: Request) -> dict[str, Any]:
        return POCController._service(request).finance_receivables()


poc_router = POCController.router
