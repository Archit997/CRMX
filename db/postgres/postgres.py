from __future__ import annotations

from contextlib import contextmanager
from typing import Any, Generator
from urllib.parse import quote_plus

from sqlalchemy import create_engine, delete, insert, select, text, update
from sqlalchemy.engine import Engine, RowMapping
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.orm import Session
from sqlalchemy.sql.elements import TextClause
from sqlalchemy.sql.schema import Table

from utils.env_vars import EnvVars


class PostgresDB:
    """
    Postgres interface for services to run CRUD and raw SQL operations.
    """

    def __init__(self) -> None:
        self._engine: Engine | None = None

    def connect(self) -> None:
        if self._engine is not None:
            return
        self._engine = create_engine(
            self._database_url(),
            pool_pre_ping=True,
            future=True,
        )

    def disconnect(self) -> None:
        if self._engine is not None:
            self._engine.dispose()
            self._engine = None

    def ping(self) -> dict[str, Any]:
        row = self.fetch_one("select now() as db_time;")
        return {"ok": True, "db_time": row["db_time"] if row else None}

    @contextmanager
    def session(self) -> Generator[Session, None, None]:
        self.connect()
        db_session = Session(self._engine)
        try:
            yield db_session
            db_session.commit()
        except Exception:
            db_session.rollback()
            raise
        finally:
            db_session.close()

    # ---------- Raw SQL helpers ----------
    def execute_sql(self, sql: str, params: dict[str, Any] | None = None) -> int:
        statement = text(sql)
        with self.session() as db_session:
            result = db_session.execute(statement, params or {})
            return result.rowcount if result.rowcount is not None else 0

    def fetch_one(self, sql: str, params: dict[str, Any] | None = None) -> dict[str, Any] | None:
        statement = text(sql)
        with self.session() as db_session:
            result = db_session.execute(statement, params or {}).mappings().first()
            return dict(result) if result else None

    def fetch_all(self, sql: str, params: dict[str, Any] | None = None) -> list[dict[str, Any]]:
        statement = text(sql)
        with self.session() as db_session:
            rows = db_session.execute(statement, params or {}).mappings().all()
            return [dict(row) for row in rows]

    # ---------- Core CRUD helpers ----------
    def insert_one(self, table: Table, values: dict[str, Any]) -> dict[str, Any] | None:
        stmt = insert(table).values(**values).returning(table)
        with self.session() as db_session:
            row = db_session.execute(stmt).mappings().first()
            return self._row_to_dict(row)

    def select_one(
        self,
        table: Table,
        where_clause: Any,
    ) -> dict[str, Any] | None:
        stmt = select(table).where(where_clause).limit(1)
        with self.session() as db_session:
            row = db_session.execute(stmt).mappings().first()
            return self._row_to_dict(row)

    def select_many(
        self,
        table: Table,
        where_clause: Any | None = None,
        limit: int | None = None,
        offset: int | None = None,
    ) -> list[dict[str, Any]]:
        stmt = select(table)
        if where_clause is not None:
            stmt = stmt.where(where_clause)
        if limit is not None:
            stmt = stmt.limit(limit)
        if offset is not None:
            stmt = stmt.offset(offset)
        with self.session() as db_session:
            rows = db_session.execute(stmt).mappings().all()
            return [dict(row) for row in rows]

    def update_many(
        self,
        table: Table,
        where_clause: Any,
        values: dict[str, Any],
    ) -> int:
        stmt = update(table).where(where_clause).values(**values)
        with self.session() as db_session:
            result = db_session.execute(stmt)
            return result.rowcount if result.rowcount is not None else 0

    def delete_many(self, table: Table, where_clause: Any) -> int:
        stmt = delete(table).where(where_clause)
        with self.session() as db_session:
            result = db_session.execute(stmt)
            return result.rowcount if result.rowcount is not None else 0

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
