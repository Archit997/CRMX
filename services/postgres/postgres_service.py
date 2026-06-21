from db.postgres import PostgresDB
from utils.constants import LOG_LEVEL_ERROR
from utils.logger import AppLogger

logger = AppLogger.get_logger(__name__)


class PostgresService:
    def __init__(self, postgres_db: PostgresDB) -> None:
        self.postgres_db = postgres_db

    def health(self) -> dict:
        try:
            return self.postgres_db.ping()
        except Exception as exc:
            logger.log(
                LOG_LEVEL_ERROR,
                f"Postgres health check failed, error: {exc}",
                exc_info=True,
            )
            raise
