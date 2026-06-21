import uvicorn
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse

from db.postgres import PostgresDB
from services.client.controller import client_router
from services.postgres import PostgresService, postgres_router
from services.status.controller import status_router
from utils.constants import (
    APP_TITLE,
    APP_VERSION,
    DEFAULT_SERVER_HOST,
    DEFAULT_SERVER_PORT,
)
from utils.env_vars import EnvVars
from utils.logger import AppLogger

from contextlib import asynccontextmanager

AppLogger.configure()
logger = AppLogger.get_logger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    postgres_db = PostgresDB()
    try:
        logger.info("Starting application lifespan")
        postgres_db.connect()
        app.state.postgres_db = postgres_db
        app.state.postgres_service = PostgresService(postgres_db)
        yield
    except Exception:
        logger.exception("Application lifespan failed")
        raise
    finally:
        try:
            postgres_db.disconnect()
            logger.info("Application lifespan stopped")
        except Exception:
            logger.exception("Application shutdown failed")
            raise


app = FastAPI(title=APP_TITLE, version=APP_VERSION, lifespan=lifespan)
app.include_router(postgres_router)
app.include_router(client_router)
app.include_router(status_router)


@app.exception_handler(Exception)
async def unhandled_exception_handler(request: Request, exc: Exception) -> JSONResponse:
    logger.exception(
        "Unhandled exception during request %s %s",
        request.method,
        request.url.path,
    )
    return JSONResponse(
        status_code=500,
        content={"detail": "Internal server error"},
    )


if __name__ == "__main__":
    host = EnvVars.get("SERVER_HOST", DEFAULT_SERVER_HOST)
    port = int(EnvVars.get("SERVER_PORT", str(DEFAULT_SERVER_PORT)))
    logger.info("Starting uvicorn server on %s:%s", host, port)
    uvicorn.run("main:app", host=host, port=port, reload=True)
