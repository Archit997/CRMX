import os
from pathlib import Path

from dotenv import dotenv_values, load_dotenv

_PROJECT_ROOT = Path(__file__).resolve().parent.parent
_DEFAULT_ENV_FILE = _PROJECT_ROOT / ".env"


class _EnvVarsMeta(type):
    def __getattr__(cls, name: str) -> str:
        if name.startswith("_"):
            raise AttributeError(name)
        value = cls.get(name)
        if value is None:
            raise AttributeError(name)
        return value


class EnvVars(metaclass=_EnvVarsMeta):
    """Loads variables from the project .env file and exposes them for runtime lookup."""
    _loaded: bool = False

    @classmethod
    def _ensure_loaded(cls) -> None:
        if not cls._loaded:
            cls.load()

    @classmethod
    def load(cls, env_file: Path | str | None = None) -> None:
        path = Path(env_file) if env_file else _DEFAULT_ENV_FILE
        try:
            load_dotenv(path)
            cls._loaded = True
        except Exception:
            cls._loaded = False

    @classmethod
    def get(cls, name: str, default: str | None = None) -> str | None:
        try:
            cls._ensure_loaded()
            return os.getenv(name, default)
        except Exception:
            return default