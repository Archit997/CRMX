from __future__ import annotations

from pathlib import Path

import jwt
import pytest

from scripts.apply_migrations import (
    baseline_files,
    file_checksum,
    migration_files,
    migration_sql,
)
from utils.runtime_config import validate_runtime_config


def _set_valid_environment(monkeypatch: pytest.MonkeyPatch) -> None:
    service_key = jwt.encode(
        {"role": "service_role"},
        "runtime-test-secret-with-at-least-32-bytes",
        algorithm="HS256",
    )
    values = {
        "ENVIRONMENT": "production",
        "DATABASE_URL": "postgresql://user:password@db.example.com/postgres",
        "SUPABASE_URL": "https://example.supabase.co",
        "SUPABASE_SERVICE_ROLE_KEY": service_key,
        "ALLOWED_ORIGINS": "https://app.example.com",
        "ALLOWED_HOSTS": "api.example.com",
    }
    for name, value in values.items():
        monkeypatch.setenv(name, value)


def test_production_runtime_config_accepts_explicit_allowlists(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    _set_valid_environment(monkeypatch)

    validate_runtime_config()


def test_production_runtime_config_rejects_publishable_server_key(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    _set_valid_environment(monkeypatch)
    monkeypatch.setenv(
        "SUPABASE_SERVICE_ROLE_KEY",
        "sb_publishable_not-a-server-secret",
    )

    with pytest.raises(RuntimeError, match="publishable or anon"):
        validate_runtime_config()


def test_production_runtime_config_rejects_wildcard_hosts(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    _set_valid_environment(monkeypatch)
    monkeypatch.setenv("ALLOWED_HOSTS", "*")

    with pytest.raises(RuntimeError, match="ALLOWED_HOSTS"):
        validate_runtime_config()


def test_migration_discovery_is_ordered_and_transaction_wrappers_are_removed(
    tmp_path: Path,
) -> None:
    second = tmp_path / "002_second.sql"
    first = tmp_path / "001_first.sql"
    ignored = tmp_path / "notes.sql"
    first.write_text("begin;\nselect 1;\ncommit;\n", encoding="utf-8")
    second.write_text("BEGIN;\nselect 2;\nCOMMIT;\n", encoding="utf-8")
    ignored.write_text("select 3;", encoding="utf-8")

    assert migration_files(tmp_path) == [first, second]
    assert migration_sql(first).strip() == "select 1;"
    assert migration_sql(second).strip() == "select 2;"
    assert file_checksum(first) != file_checksum(second)
    assert baseline_files([first, second], first.name) == [first]

    with pytest.raises(RuntimeError, match="Unknown baseline"):
        baseline_files([first, second], "003_missing.sql")
