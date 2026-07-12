from __future__ import annotations

from sqlalchemy import text

from db.postgres import PostgresDB


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
                      and table_name in ('client_info', 'client_updates', 'status_master', 'users')
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


if __name__ == "__main__":
    main()
