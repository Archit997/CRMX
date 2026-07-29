from __future__ import annotations

import json
import logging
import os
from datetime import datetime, timezone
from logging.handlers import RotatingFileHandler
from pathlib import Path
from typing import Any

from dotenv import load_dotenv

from utils.constants import (
    LOG_LEVEL_CRITICAL,
    LOG_LEVEL_DEBUG,
    LOG_LEVEL_ERROR,
    LOG_LEVEL_INFO,
    LOG_LEVEL_NOTSET,
    LOG_LEVEL_WARNING,
)
from utils.logging.redaction import redact_message
from utils.request_context import get_request_id


PROJECT_ROOT = Path(__file__).resolve().parents[2]


class _RequestContextFilter(logging.Filter):
    def filter(self, record: logging.LogRecord) -> bool:
        record.request_id = get_request_id()
        return True


class _RedactingTextFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        return redact_message(super().format(record))


class _JsonFormatter(logging.Formatter):
    def format(self, record: logging.LogRecord) -> str:
        payload: dict[str, Any] = {
            "timestamp": datetime.now(timezone.utc).isoformat(),
            "level": record.levelname,
            "request_id": getattr(record, "request_id", "-"),
            "logger": record.name,
            "message": redact_message(record.getMessage()),
        }
        if record.exc_info:
            payload["exception"] = redact_message(
                self.formatException(record.exc_info)
            )
        return json.dumps(payload, ensure_ascii=True)


class AppLogger:
    _configured = False
    _logger_name = "crmx"
    _level_map = {
        LOG_LEVEL_NOTSET: logging.NOTSET,
        LOG_LEVEL_DEBUG: logging.DEBUG,
        LOG_LEVEL_INFO: logging.INFO,
        LOG_LEVEL_WARNING: logging.WARNING,
        LOG_LEVEL_ERROR: logging.ERROR,
        LOG_LEVEL_CRITICAL: logging.CRITICAL,
    }

    def __init__(self, name: str | None = None) -> None:
        self.configure()
        logger_name = (
            self._logger_name if not name else f"{self._logger_name}.{name}"
        )
        self._logger = logging.getLogger(logger_name)

    @classmethod
    def configure(cls) -> None:
        if cls._configured:
            return

        load_dotenv(PROJECT_ROOT / ".env")
        level_name = os.getenv("LOG_LEVEL", LOG_LEVEL_INFO).upper()
        log_level = cls._level_map.get(level_name, logging.INFO)

        logger = logging.getLogger(cls._logger_name)
        logger.setLevel(log_level)
        logger.propagate = False

        if logger.handlers:
            cls._configured = True
            return

        if os.getenv("LOG_FORMAT", "text").lower() == "json":
            formatter: logging.Formatter = _JsonFormatter()
        else:
            formatter = _RedactingTextFormatter(
                "%(asctime)s | %(levelname)s | "
                "request_id=%(request_id)s | %(name)s | %(message)s"
            )

        stream_handler = logging.StreamHandler()
        stream_handler.setLevel(log_level)
        stream_handler.setFormatter(formatter)
        stream_handler.addFilter(_RequestContextFilter())
        logger.addHandler(stream_handler)

        log_to_file = os.getenv("LOG_TO_FILE", "true").lower() in {
            "1",
            "true",
            "yes",
        }
        if log_to_file:
            configured_dir = Path(os.getenv("LOG_DIR", "logs"))
            log_dir = (
                configured_dir
                if configured_dir.is_absolute()
                else PROJECT_ROOT / configured_dir
            )
            log_dir.mkdir(parents=True, exist_ok=True)
            file_handler = RotatingFileHandler(
                log_dir / "app.log",
                maxBytes=int(os.getenv("LOG_MAX_BYTES", "10485760")),
                backupCount=int(os.getenv("LOG_BACKUP_COUNT", "5")),
                delay=True,
            )
            file_handler.setLevel(log_level)
            file_handler.setFormatter(formatter)
            file_handler.addFilter(_RequestContextFilter())
            logger.addHandler(file_handler)

        cls._configured = True

    @classmethod
    def get_logger(cls, name: str | None = None) -> "AppLogger":
        return cls(name)

    def set_level(self, level: str | int) -> None:
        level_value = (
            self._level_map.get(level.upper(), logging.INFO)
            if isinstance(level, str)
            else level
        )
        self._logger.setLevel(level_value)

    def notset(self, message: str, *args: Any, **kwargs: Any) -> None:
        self._logger.log(logging.NOTSET, message, *args, **kwargs)

    def debug(self, message: str, *args: Any, **kwargs: Any) -> None:
        self._logger.debug(message, *args, **kwargs)

    def info(self, message: str, *args: Any, **kwargs: Any) -> None:
        self._logger.info(message, *args, **kwargs)

    def warning(self, message: str, *args: Any, **kwargs: Any) -> None:
        self._logger.warning(message, *args, **kwargs)

    def error(self, message: str, *args: Any, **kwargs: Any) -> None:
        self._logger.error(message, *args, **kwargs)

    def critical(self, message: str, *args: Any, **kwargs: Any) -> None:
        self._logger.critical(message, *args, **kwargs)

    def exception(self, message: str, *args: Any, **kwargs: Any) -> None:
        self._logger.exception(message, *args, **kwargs)

    def log(
        self,
        level: str | int,
        message: str,
        *args: Any,
        **kwargs: Any,
    ) -> None:
        level_value = (
            self._level_map.get(level.upper(), logging.INFO)
            if isinstance(level, str)
            else level
        )
        self._logger.log(level_value, message, *args, **kwargs)

    def __getattr__(self, attr: str) -> Any:
        return getattr(self._logger, attr)
