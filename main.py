import re
import time
from uuid import uuid4

import uvicorn
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.middleware.trustedhost import TrustedHostMiddleware
from fastapi.responses import JSONResponse

from db.postgres import PostgresDB
from services.auth.controller import auth_router
from services.audit.controller import audit_router
from services.client.controller import client_router
from services.organization.controller import organization_router
from services.postgres import PostgresService
from services.postgres.controller import postgres_router
from services.status.controller import status_router
from services.user.controller import user_router
from utils.constants import (
    APP_TITLE,
    APP_VERSION,
    DEFAULT_SERVER_HOST,
    DEFAULT_SERVER_PORT,
)

from utils.env_vars import EnvVars
from utils.logging import AppLogger
from utils.request_context import get_request_id, reset_request_id, set_request_id
from utils.runtime_config import is_production, validate_runtime_config

from contextlib import asynccontextmanager

AppLogger.configure()
logger = AppLogger.get_logger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    postgres_db = PostgresDB()
    try:
        logger.info("Starting application lifespan")
        validate_runtime_config()
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


app = FastAPI(
    title=APP_TITLE,
    version=APP_VERSION,
    lifespan=lifespan,
    docs_url=None if is_production() else "/docs",
    redoc_url=None if is_production() else "/redoc",
    openapi_url=None if is_production() else "/openapi.json",
)

REQUEST_ID_PATTERN = re.compile(r"^[A-Za-z0-9._:-]{1,128}$")


@app.middleware("http")
async def request_logging_middleware(request: Request, call_next):
    supplied_request_id = request.headers.get("X-Request-ID", "").strip()
    request_id = (
        supplied_request_id
        if REQUEST_ID_PATTERN.fullmatch(supplied_request_id)
        else str(uuid4())
    )
    context_token = set_request_id(request_id)
    started_at = time.perf_counter()
    try:
        response = await call_next(request)
        duration_ms = (time.perf_counter() - started_at) * 1000
        logger.info(
            "request_completed method=%s path=%s status=%s duration_ms=%.2f",
            request.method,
            request.url.path,
            response.status_code,
            duration_ms,
        )
        response.headers["X-Request-ID"] = request_id
        response.headers["X-Content-Type-Options"] = "nosniff"
        response.headers["X-Frame-Options"] = "DENY"
        response.headers["Referrer-Policy"] = "no-referrer"
        if request.url.path.startswith("/api/auth"):
            response.headers["Cache-Control"] = "no-store"
        return response
    except Exception:
        duration_ms = (time.perf_counter() - started_at) * 1000
        logger.exception(
            "request_failed method=%s path=%s duration_ms=%.2f",
            request.method,
            request.url.path,
            duration_ms,
        )
        raise
    finally:
        reset_request_id(context_token)

origins = [
    o.strip()
    for o in (EnvVars.get("ALLOWED_ORIGINS") or "").split(",")
    if o.strip()
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=origins,
    allow_credentials=False,
    allow_methods=["GET", "POST", "PATCH", "DELETE", "OPTIONS"],
    allow_headers=["Authorization", "Content-Type", "X-Request-ID"],
    expose_headers=["X-Request-ID"],
)

allowed_hosts = [
    host.strip()
    for host in (EnvVars.get("ALLOWED_HOSTS") or "").split(",")
    if host.strip()
]
if allowed_hosts:
    app.add_middleware(
        TrustedHostMiddleware,
        allowed_hosts=allowed_hosts,
    )

app.include_router(auth_router)
app.include_router(audit_router)
app.include_router(postgres_router)
app.include_router(client_router)
app.include_router(organization_router)
app.include_router(status_router)
app.include_router(user_router)

@app.get("/")
async def root() -> JSONResponse:
    return JSONResponse(
        status_code=200,
        content={"service": APP_TITLE, "version": APP_VERSION},
    )


@app.get("/health")
async def health() -> JSONResponse:
    return JSONResponse(status_code=200, content={"status": "ok"})


@app.get("/ready")
async def ready(request: Request) -> JSONResponse:
    try:
        request.app.state.postgres_db.ping()
        return JSONResponse(status_code=200, content={"status": "ready"})
    except Exception:
        logger.exception("Readiness check failed")
        return JSONResponse(
            status_code=503,
            content={"status": "unavailable"},
        )


@app.exception_handler(Exception)
async def unhandled_exception_handler(request: Request, exc: Exception) -> JSONResponse:
    logger.exception(
        "Unhandled exception during request %s %s",
        request.method,
        request.url.path,
    )
    return JSONResponse(
        status_code=500,
        content={
            "detail": "Internal server error",
            "request_id": get_request_id(),
        },
    )


if __name__ == "__main__":
    host = EnvVars.get("SERVER_HOST", DEFAULT_SERVER_HOST)
    port = int(EnvVars.get("SERVER_PORT", str(DEFAULT_SERVER_PORT)))
    logger.info("Starting uvicorn server on %s:%s", host, port)
    uvicorn.run(
        "main:app",
        host=host,
        port=port,
        reload=not is_production(),
    )
