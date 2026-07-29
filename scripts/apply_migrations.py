from __future__ import annotations

import argparse
import hashlib
import re
import sys
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parent.parent
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from sqlalchemy import text

from db.postgres import PostgresDB


MIGRATION_PATTERN = re.compile(r"^\d{3}_.+\.sql$")
MIGRATIONS_DIR = PROJECT_ROOT / "db" / "postgres"
LOCK_NAME = "crmx_schema_migrations"


def migration_files(directory: Path = MIGRATIONS_DIR) -> list[Path]:
    return sorted(
        path
        for path in directory.iterdir()
        if path.is_file() and MIGRATION_PATTERN.fullmatch(path.name)
    )


def file_checksum(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def migration_sql(path: Path) -> str:
    sql = path.read_text(encoding="utf-8")
    sql = re.sub(r"\A\s*begin\s*;\s*", "", sql, count=1, flags=re.IGNORECASE)
    sql = re.sub(r"\s*commit\s*;\s*\Z", "", sql, count=1, flags=re.IGNORECASE)
    return sql


def baseline_files(files: list[Path], target: str) -> list[Path]:
    names = [path.name for path in files]
    if target not in names:
        raise RuntimeError(f"Unknown baseline migration: {target}")
    return files[: names.index(target) + 1]


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Apply pending CRMX SQL migrations in numeric order."
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="List pending migrations without applying them.",
    )
    parser.add_argument(
        "--baseline-through",
        metavar="MIGRATION",
        help=(
            "Record existing migrations through this filename without "
            "executing them. Use only after verifying a legacy database."
        ),
    )
    args = parser.parse_args()
    if args.dry_run and args.baseline_through:
        parser.error("--dry-run and --baseline-through cannot be combined")

    db = PostgresDB()
    db.connect()
    try:
        with db.session_scope() as session:
            session.execute(
                text(
                    """
                    create table if not exists public.schema_migrations (
                        version text primary key,
                        checksum text not null,
                        applied_at timestamptz not null default now()
                    )
                    """
                )
            )
            session.commit()
            session.execute(
                text("select pg_advisory_lock(hashtext(:lock_name))"),
                {"lock_name": LOCK_NAME},
            )

            try:
                applied = dict(
                    session.execute(
                        text(
                            "select version, checksum "
                            "from public.schema_migrations"
                        )
                    ).all()
                )

                pending: list[tuple[Path, str]] = []
                files = migration_files()
                for path in files:
                    checksum = file_checksum(path)
                    previous_checksum = applied.get(path.name)
                    if previous_checksum is None:
                        pending.append((path, checksum))
                    elif previous_checksum != checksum:
                        raise RuntimeError(
                            f"Applied migration was modified: {path.name}"
                        )

                if args.baseline_through:
                    for path in baseline_files(
                        files, args.baseline_through
                    ):
                        checksum = file_checksum(path)
                        previous_checksum = applied.get(path.name)
                        if previous_checksum is None:
                            session.execute(
                                text(
                                    """
                                    insert into public.schema_migrations (
                                        version,
                                        checksum
                                    ) values (
                                        :version,
                                        :checksum
                                    )
                                    """
                                ),
                                {
                                    "version": path.name,
                                    "checksum": checksum,
                                },
                            )
                            print(f"BASELINED {path.name}")
                        elif previous_checksum != checksum:
                            raise RuntimeError(
                                "Applied migration was modified: "
                                f"{path.name}"
                            )
                    session.commit()
                    return

                if args.dry_run:
                    for path, _ in pending:
                        print(f"PENDING {path.name}")
                    if not pending:
                        print("No pending migrations")
                    return

                for path, checksum in pending:
                    session.connection().exec_driver_sql(migration_sql(path))
                    session.execute(
                        text(
                            """
                            insert into public.schema_migrations (
                                version,
                                checksum
                            ) values (
                                :version,
                                :checksum
                            )
                            """
                        ),
                        {"version": path.name, "checksum": checksum},
                    )
                    session.commit()
                    print(f"APPLIED {path.name}")

                if not pending:
                    print("No pending migrations")
            finally:
                session.execute(
                    text("select pg_advisory_unlock(hashtext(:lock_name))"),
                    {"lock_name": LOCK_NAME},
                )
                session.commit()
    finally:
        db.disconnect()


if __name__ == "__main__":
    main()
