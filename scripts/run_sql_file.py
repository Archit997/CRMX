from __future__ import annotations

import argparse
from pathlib import Path

from sqlalchemy import text

from db.postgres import PostgresDB


def main() -> None:
    parser = argparse.ArgumentParser(description="Run a SQL file against configured Postgres.")
    parser.add_argument("sql_file", type=Path)
    args = parser.parse_args()

    sql_path = args.sql_file.resolve()
    sql = sql_path.read_text(encoding="utf-8")

    db = PostgresDB()
    db.connect()
    try:
      with db.session_scope() as session:
          session.execute(text(sql))
          session.commit()
    finally:
        db.disconnect()

    print(f"Applied SQL file: {sql_path}")


if __name__ == "__main__":
    main()
