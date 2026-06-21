from pymongo import MongoClient
from pymongo.database import Database

from services.mongo.constants import DEFAULT_DB_NAME
from utils.env_vars import EnvVars
from utils.logger import AppLogger

logger = AppLogger.get_logger(__name__)


class MongoDBClient:
    def __init__(self) -> None:
        self._client: MongoClient | None = None

    def connect(self) -> None:
        if self._client is not None:
            return

        mongo_uri = EnvVars.get("MONGODB_URI")
        if not mongo_uri:
            logger.error("MongoDB connection failed because MONGODB_URI is not set")
            raise ValueError("MONGODB_URI is not set")

        try:
            self._client = MongoClient(mongo_uri)
            logger.info("MongoDB client initialized")
        except Exception:
            logger.exception("Failed to initialize MongoDB client")
            raise

    def disconnect(self) -> None:
        if self._client is not None:
            try:
                self._client.close()
                logger.info("MongoDB client disconnected")
            except Exception:
                logger.exception("Failed to close MongoDB client cleanly")
                raise
            finally:
                self._client = None

    def get_database(self) -> Database:
        self.connect()
        db_name = EnvVars.get("MONGODB_DB_NAME", DEFAULT_DB_NAME)
        return self._client[db_name]

    def ping(self) -> dict:
        try:
            return self.get_database().command("ping")
        except Exception:
            logger.exception("MongoDB ping failed")
            raise
