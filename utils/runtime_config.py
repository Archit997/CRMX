from __future__ import annotations

import jwt
from urllib.parse import urlparse

from utils.env_vars import EnvVars


def environment_name() -> str:
    return (EnvVars.get("ENVIRONMENT", "development") or "development").lower()


def is_production() -> bool:
    return environment_name() == "production"


def validate_runtime_config() -> None:
    required = {
        "SUPABASE_URL": EnvVars.get("SUPABASE_URL"),
        "SUPABASE_SERVICE_ROLE_KEY": EnvVars.get("SUPABASE_SERVICE_ROLE_KEY"),
    }
    if not EnvVars.get("DATABASE_URL"):
        required.update(
            {
                "SUPABASE_DB_HOST": EnvVars.get("SUPABASE_DB_HOST"),
                "SUPABASE_DB_PASSWORD": EnvVars.get("SUPABASE_DB_PASSWORD"),
            }
        )

    missing = [
        name
        for name, value in required.items()
        if not value or "<" in value or ">" in value
    ]
    if missing:
        raise RuntimeError(
            "Missing required runtime configuration: "
            + ", ".join(sorted(missing))
        )

    supabase_url = (EnvVars.get("SUPABASE_URL") or "").strip()
    parsed_supabase_url = urlparse(supabase_url)
    if parsed_supabase_url.scheme != "https" or not parsed_supabase_url.netloc:
        raise RuntimeError("SUPABASE_URL must be a valid HTTPS URL")

    service_role_key = EnvVars.get("SUPABASE_SERVICE_ROLE_KEY") or ""
    if service_role_key.startswith(("sb_publishable_", "sb_anon_")):
        raise RuntimeError(
            "SUPABASE_SERVICE_ROLE_KEY cannot be a publishable or anon key"
        )
    if service_role_key.count(".") == 2:
        try:
            claims = jwt.decode(
                service_role_key,
                options={"verify_signature": False},
                algorithms=["HS256", "ES256", "RS256"],
            )
        except jwt.PyJWTError as exc:
            raise RuntimeError(
                "SUPABASE_SERVICE_ROLE_KEY is not a valid JWT"
            ) from exc
        if claims.get("role") != "service_role":
            raise RuntimeError(
                "SUPABASE_SERVICE_ROLE_KEY must have the service_role claim"
            )

    origins = [
        value.strip()
        for value in (EnvVars.get("ALLOWED_ORIGINS") or "").split(",")
        if value.strip()
    ]
    if is_production() and (not origins or "*" in origins):
        raise RuntimeError(
            "Production requires an explicit ALLOWED_ORIGINS allowlist"
        )

    allowed_hosts = [
        value.strip()
        for value in (EnvVars.get("ALLOWED_HOSTS") or "").split(",")
        if value.strip()
    ]
    if is_production() and (not allowed_hosts or "*" in allowed_hosts):
        raise RuntimeError(
            "Production requires an explicit ALLOWED_HOSTS allowlist"
        )
