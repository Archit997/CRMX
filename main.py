import uvicorn
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from fastapi.responses import RedirectResponse
from pathlib import Path


from db.postgres import PostgresDB

from core.client.controller import client_router
from core.postgres.postgres_service import PostgresService, postgres_router
from core.status.controller import status_router
from core.user.controller import user_router
from core.whatsapp.webhooks.routes import whatsapp_webhook_router
# POC endpoints commented out - using Postgres endpoints instead
# from core.poc.controller import poc_router
# from core.poc.poc_data_service import POCDataService

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

PROJECT_ROOT = Path(__file__).resolve().parent
DATA_DIR = PROJECT_ROOT / "data"
MOBILE_PROTOTYPE_DIR = PROJECT_ROOT / "mobile-prototype"


@asynccontextmanager
async def lifespan(app: FastAPI):
    postgres_db = PostgresDB()
    try:
        logger.info("Starting application lifespan")
        postgres_db.connect()
        app.state.postgres_db = postgres_db
        app.state.postgres_service = PostgresService(postgres_db)
        # POC data service commented out - using Postgres instead
        # app.state.poc_data_service = POCDataService(DATA_DIR)
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

app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=r"http://(127\.0\.0\.1|localhost)(:\d+)?",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(postgres_router)
app.include_router(client_router)
app.include_router(status_router)
app.include_router(user_router)
app.include_router(whatsapp_webhook_router)

# POC router commented out - using Postgres endpoints instead
# app.include_router(poc_router)
app.mount("/mobile", StaticFiles(directory=MOBILE_PROTOTYPE_DIR, html=True), name="mobile")



@app.get("/")
async def root() -> RedirectResponse:
    # Redirect to docs instead of mobile prototype (POC)
    return RedirectResponse(url="/docs")

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
