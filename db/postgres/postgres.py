from __future__ import annotations

from contextlib import contextmanager
from typing import Any, Generator
from urllib.parse import quote_plus

from sqlalchemy import create_engine, text
from sqlalchemy.engine import Engine, RowMapping
from sqlalchemy.orm import Session, sessionmaker

from utils.env_vars import EnvVars
from utils.logger import AppLogger

logger = AppLogger.get_logger(__name__)


class PostgresDB:
    """
    Postgres interface for services to run CRUD and raw SQL operations.
    """

    def __init__(self) -> None:
        self._engine: Engine | None = None
        self._session_factory: sessionmaker[Session] | None = None

    def connect(self) -> None:
        if self._engine is not None:
            return
        try:
            self._engine = create_engine(
                self._database_url(),
                pool_pre_ping=True,
                future=True,
            )
            self._session_factory = sessionmaker(
                bind=self._engine,
                autoflush=False,
                expire_on_commit=False,
                future=True,
            )
            logger.info("Postgres engine initialized")
        except Exception:
            logger.exception("Failed to initialize Postgres engine")
            raise

    def disconnect(self) -> None:
        if self._engine is not None:
            try:
                self._engine.dispose()
                logger.info("Postgres engine disposed")
            except Exception:
                logger.exception("Failed to dispose Postgres engine cleanly")
                raise
            finally:
                self._engine = None
                self._session_factory = None

    def ping(self) -> dict[str, Any]:
        row = self.fetch_one("select now() as db_time;")
        return {"ok": True, "db_time": row["db_time"] if row else None}

    def create_session(self) -> Session:
        self.connect()
        if self._session_factory is None:
            raise RuntimeError("Postgres session factory is not initialized")
        return self._session_factory()

    @contextmanager
    def session_scope(self) -> Generator[Session, None, None]:
        db_session = self.create_session()
        try:
            yield db_session
        except Exception:
            db_session.rollback()
            logger.exception("Postgres session failed and was rolled back")
            raise
        finally:
            db_session.close()

    # ---------- Raw SQL helpers ----------
    def execute_sql(self, sql: str, params: dict[str, Any] | None = None) -> int:
        statement = text(sql)
        with self.session_scope() as db_session:
            result = db_session.execute(statement, params or {})
            db_session.commit()
            return result.rowcount if result.rowcount is not None else 0

    def fetch_one(self, sql: str, params: dict[str, Any] | None = None) -> dict[str, Any] | None:
        statement = text(sql)
        with self.session_scope() as db_session:
            result = db_session.execute(statement, params or {}).mappings().first()
            return dict(result) if result else None

    def fetch_all(self, sql: str, params: dict[str, Any] | None = None) -> list[dict[str, Any]]:
        statement = text(sql)
        with self.session_scope() as db_session:
            rows = db_session.execute(statement, params or {}).mappings().all()
            return [dict(row) for row in rows]

    def _database_url(self) -> str:
        direct_url = EnvVars.get("DATABASE_URL")
        if direct_url:
            return direct_url

        host = EnvVars.get("SUPABASE_DB_HOST")
        port = EnvVars.get("SUPABASE_DB_PORT", "5432")
        name = EnvVars.get("SUPABASE_DB_NAME", "postgres")
        user = EnvVars.get("SUPABASE_DB_USER", "postgres")
        password = EnvVars.get("SUPABASE_DB_PASSWORD")
        ssl_mode = EnvVars.get("SUPABASE_SSL_MODE", "require")

        if not host or not password:
            logger.error(
                "Postgres configuration is incomplete; DATABASE_URL or Supabase credentials are missing"
            )
            raise ValueError(
                "Set DATABASE_URL or SUPABASE_DB_HOST and SUPABASE_DB_PASSWORD"
            )

        encoded_password = quote_plus(password)
        return (
            f"postgresql+psycopg://{user}:{encoded_password}@{host}:{port}/{name}"
            f"?sslmode={ssl_mode}"
        )

    @staticmethod
    def _row_to_dict(row: RowMapping | None) -> dict[str, Any] | None:
        return dict(row) if row else None
