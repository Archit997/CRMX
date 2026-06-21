import logging
import os
from logging.handlers import RotatingFileHandler
from pathlib import Path
from typing import Any

from utils.constants import (
    LOG_LEVEL_CRITICAL,
    LOG_LEVEL_DEBUG,
    LOG_LEVEL_ERROR,
    LOG_LEVEL_INFO,
    LOG_LEVEL_NOTSET,
    LOG_LEVEL_WARNING,
)


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
        logger_name = self._logger_name if not name else f"{self._logger_name}.{name}"
        self._logger = logging.getLogger(logger_name)

    @classmethod
    def configure(cls) -> None:
        if cls._configured:
            return

        level_name = os.getenv("LOG_LEVEL", LOG_LEVEL_INFO).upper()
        log_level = cls._level_map.get(level_name, logging.INFO)

        logger = logging.getLogger(cls._logger_name)
        logger.setLevel(log_level)
        logger.propagate = False

        if logger.handlers:
            cls._configured = True
            return

        formatter = logging.Formatter(
            "%(asctime)s | %(levelname)s | %(name)s | %(message)s"
        )

        stream_handler = logging.StreamHandler()
        stream_handler.setLevel(log_level)
        stream_handler.setFormatter(formatter)

        log_dir = Path(__file__).resolve().parent.parent / "logs"
        log_dir.mkdir(parents=True, exist_ok=True)
        file_handler = RotatingFileHandler(
            log_dir / "app.log",
            maxBytes=1_048_576,
            backupCount=3,
            delay=True,
        )
        file_handler.setLevel(log_level)
        file_handler.setFormatter(formatter)

        logger.addHandler(stream_handler)
        logger.addHandler(file_handler)
        cls._configured = True

    @classmethod
    def get_logger(cls, name: str | None = None) -> "AppLogger":
        return cls(name)

    def set_level(self, level: str | int) -> None:
        if isinstance(level, str):
            level_value = self._level_map.get(level.upper(), logging.INFO)
        else:
            level_value = level
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

    def log(self, level: str | int, message: str, *args: Any, **kwargs: Any) -> None:
        if isinstance(level, str):
            level_value = self._level_map.get(level.upper(), logging.INFO)
        else:
            level_value = level
        self._logger.log(level_value, message, *args, **kwargs)

    def __getattr__(self, attr: str) -> Any:
        return getattr(self._logger, attr)
