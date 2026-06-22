import uvicorn
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import RedirectResponse
from fastapi.staticfiles import StaticFiles
from pathlib import Path

from services.poc import POCDataService, poc_router
from utils.constants import (
    APP_TITLE,
    APP_VERSION,
    DEFAULT_SERVER_HOST,
    DEFAULT_SERVER_PORT,
)
from utils.env_vars import EnvVars

try:
    from db.postgres import PostgresDB
    from services.postgres import PostgresService, postgres_router
except ModuleNotFoundError:
    PostgresDB = None
    PostgresService = None
    postgres_router = None

from contextlib import asynccontextmanager

PROJECT_ROOT = Path(__file__).resolve().parent
DATA_DIR = PROJECT_ROOT / "data"
MOBILE_PROTOTYPE_DIR = PROJECT_ROOT / "mobile-prototype"


@asynccontextmanager
async def lifespan(app: FastAPI):
    postgres_db = PostgresDB() if PostgresDB else None
    app.state.poc_data_service = POCDataService(DATA_DIR)
    try:
        if postgres_db is None or PostgresService is None:
            app.state.postgres_service = None
        else:
            postgres_db.connect()
            app.state.postgres_service = PostgresService(postgres_db)
    except Exception:
        app.state.postgres_service = None
    try:
        yield
    finally:
        if postgres_db is not None:
            postgres_db.disconnect()


app = FastAPI(title=APP_TITLE, version=APP_VERSION, lifespan=lifespan)
app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://127.0.0.1:8080",
        "http://127.0.0.1:8081",
        "http://127.0.0.1:8090",
        "http://localhost:8080",
        "http://localhost:8081",
        "http://localhost:8090",
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)
if postgres_router is not None:
    app.include_router(postgres_router)
app.include_router(poc_router)
app.mount("/mobile", StaticFiles(directory=MOBILE_PROTOTYPE_DIR, html=True), name="mobile")


@app.get("/")
async def root() -> RedirectResponse:
    return RedirectResponse(url="/mobile/index.html")

if __name__ == "__main__":
    host = EnvVars.get("SERVER_HOST", DEFAULT_SERVER_HOST)
    port = int(EnvVars.get("SERVER_PORT", str(DEFAULT_SERVER_PORT)))
    uvicorn.run("main:app", host=host, port=port, reload=True)
