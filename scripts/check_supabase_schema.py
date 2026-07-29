from __future__ import annotations

import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from sqlalchemy import text

from db.postgres import PostgresDB


EXPECTED_TABLES = {
    "audit_events",
    "client_info",
    "client_updates",
    "organizations",
    "schema_migrations",
    "status_master",
    "users",
}

EXPECTED_USER_COLUMNS = {
    "approval_status",
    "contact",
    "deleted_at",
    "deleted_by",
    "id",
    "is_active",
    "name",
    "organization_id",
    "phone",
    "role",
}


def main() -> None:
    db = PostgresDB()
    db.connect()
    try:
        with db.session_scope() as session:
            tables = session.execute(
                text(
                    """
                    select table_name
                    from information_schema.tables
                    where table_schema = 'public'
                    order by table_name
                    """
                )
            ).scalars().all()
            user_columns = session.execute(
                text(
                    """
                    select column_name
                    from information_schema.columns
                    where table_schema = 'public'
                      and table_name = 'users'
                    order by ordinal_position
                    """
                )
            ).scalars().all()
    finally:
        db.disconnect()

    print("tables=" + ",".join(tables))
    print("users_columns=" + ",".join(user_columns))
    missing_tables = EXPECTED_TABLES.difference(tables)
    missing_columns = EXPECTED_USER_COLUMNS.difference(user_columns)
    if missing_tables or missing_columns:
        if missing_tables:
            print("missing_tables=" + ",".join(sorted(missing_tables)))
        if missing_columns:
            print("missing_users_columns=" + ",".join(sorted(missing_columns)))
        raise SystemExit(1)


if __name__ == "__main__":
    main()
