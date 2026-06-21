from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Request, status

from services.client.client_service import (
    ClientCreateRequest,
    ClientPatchRequest,
    ClientStatusChangeRequest,
    ClientService,
)
from services.postgres.dependencies import get_client_service
from utils.constants import LOG_LEVEL_ERROR
from utils.logger import AppLogger

logger = AppLogger.get_logger(__name__)


class ClientController:
    router = APIRouter(tags=["clients"])

    @staticmethod
    @router.get("/client-list")
    async def list_clients(
        request: Request,
        client_service: Annotated[ClientService, Depends(get_client_service)],
    ) -> list[dict]:
        try:
            return client_service.list_clients()
        except Exception as exc:
            logger.log(
                LOG_LEVEL_ERROR,
                f"List clients failed for {request.method} {request.url.path}, error: {exc}",
                exc_info=True,
            )
            raise HTTPException(status_code=500, detail="Failed to fetch clients") from exc

    @staticmethod
    @router.get("/client/{search_term}")
    async def search_clients(
        search_term: str,
        request: Request,
        client_service: Annotated[ClientService, Depends(get_client_service)],
    ) -> list[dict]:
        try:
            return client_service.search_clients(search_term)
        except Exception as exc:
            logger.log(
                LOG_LEVEL_ERROR,
                f"Search client failed for {request.method} {request.url.path}, error: {exc}",
                exc_info=True,
            )
            raise HTTPException(status_code=500, detail="Failed to search clients") from exc

    @staticmethod
    @router.post("/client", status_code=status.HTTP_201_CREATED)
    async def create_client(
        payload: ClientCreateRequest,
        request: Request,
        client_service: Annotated[ClientService, Depends(get_client_service)],
    ) -> dict:
        try:
            return client_service.create_client(payload)
        except ValueError as exc:
            raise HTTPException(status_code=400, detail=str(exc)) from exc
        except Exception as exc:
            logger.log(
                LOG_LEVEL_ERROR,
                f"Create client failed for {request.method} {request.url.path}, error: {exc}",
                exc_info=True,
            )
            raise HTTPException(status_code=500, detail="Failed to create client") from exc

    @staticmethod
    @router.patch("/client-list")
    async def patch_client(
        payload: ClientPatchRequest,
        request: Request,
        client_service: Annotated[ClientService, Depends(get_client_service)],
    ) -> dict:
        try:
            return client_service.patch_client(payload)
        except LookupError as exc:
            raise HTTPException(status_code=404, detail=str(exc)) from exc
        except ValueError as exc:
            raise HTTPException(status_code=400, detail=str(exc)) from exc
        except Exception as exc:
            logger.log(
                LOG_LEVEL_ERROR,
                f"Patch client failed for {request.method} {request.url.path}, error: {exc}",
                exc_info=True,
            )
            raise HTTPException(status_code=500, detail="Failed to update client") from exc

    @staticmethod
    @router.delete("/client")
    async def delete_client(
        client_id: int,
        request: Request,
        client_service: Annotated[ClientService, Depends(get_client_service)],
    ) -> dict:
        try:
            return client_service.delete_client(client_id)
        except LookupError as exc:
            raise HTTPException(status_code=404, detail=str(exc)) from exc
        except Exception as exc:
            logger.log(
                LOG_LEVEL_ERROR,
                f"Delete client failed for {request.method} {request.url.path}, error: {exc}",
                exc_info=True,
            )
            raise HTTPException(status_code=500, detail="Failed to delete client") from exc

    @staticmethod
    @router.post("/client-test-seed")
    async def sync_seeded_test_clients(
        request: Request,
        client_service: Annotated[ClientService, Depends(get_client_service)],
    ) -> dict:
        try:
            return client_service.sync_seeded_test_clients()
        except ValueError as exc:
            raise HTTPException(status_code=400, detail=str(exc)) from exc
        except Exception as exc:
            logger.log(
                LOG_LEVEL_ERROR,
                f"Seed test clients failed for {request.method} {request.url.path}, error: {exc}",
                exc_info=True,
            )
            raise HTTPException(status_code=500, detail="Failed to seed test clients") from exc

    @staticmethod
    @router.post("/change-client-status")
    async def change_client_status(
        payload: ClientStatusChangeRequest,
        request: Request,
        client_service: Annotated[ClientService, Depends(get_client_service)],
    ) -> dict:
        try:
            return client_service.change_client_status(payload)
        except LookupError as exc:
            raise HTTPException(status_code=404, detail=str(exc)) from exc
        except ValueError as exc:
            raise HTTPException(status_code=400, detail=str(exc)) from exc
        except Exception as exc:
            logger.log(
                LOG_LEVEL_ERROR,
                f"Change client status failed for {request.method} {request.url.path}, error: {exc}",
                exc_info=True,
            )
            raise HTTPException(status_code=500, detail="Failed to change client status") from exc


client_router = ClientController.router
