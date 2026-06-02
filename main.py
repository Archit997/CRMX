import uvicorn
from fastapi import FastAPI

from db.postgres import PostgresDB
from services.postgres import PostgresService, postgres_router
from utils.constants import (
    APP_TITLE,
    APP_VERSION,
    DEFAULT_SERVER_HOST,
    DEFAULT_SERVER_PORT,
)
from utils.env_vars import EnvVars


from contextlib import asynccontextmanager


@asynccontextmanager
async def lifespan(app: FastAPI):
    postgres_db = PostgresDB()
    postgres_db.connect()
    app.state.postgres_service = PostgresService(postgres_db)
    try:
        yield
    finally:
        postgres_db.disconnect()


app = FastAPI(title=APP_TITLE, version=APP_VERSION, lifespan=lifespan)
app.include_router(postgres_router)

if __name__ == "__main__":
    host = EnvVars.get("SERVER_HOST", DEFAULT_SERVER_HOST)
    port = int(EnvVars.get("SERVER_PORT", str(DEFAULT_SERVER_PORT)))
    uvicorn.run("main:app", host=host, port=port, reload=True)
