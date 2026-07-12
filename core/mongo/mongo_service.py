import json

from db.mongo import MongoDBClient
from pymongo.database import Database

from core.mongo.constants import (
    COLLECTION_CLIENTS,
    COLLECTION_CLIENT_UPDATES,
    COLLECTION_STATUS_MASTER,
    STATUS_MASTER_SEED_PATH,
)
from utils.constants import LOG_LEVEL_ERROR
from utils.logger import AppLogger

logger = AppLogger.get_logger(__name__)


class MongoService:
    def __init__(self, mongo_client: MongoDBClient) -> None:
        self.mongo_client = mongo_client

    @staticmethod
    def _ensure_indexes(db: Database) -> None:
        db[COLLECTION_STATUS_MASTER].create_index("status_no", unique=True)
        db[COLLECTION_CLIENTS].create_index("client_id", unique=True)
        db[COLLECTION_CLIENT_UPDATES].create_index("update_id", unique=True)
        db[COLLECTION_CLIENT_UPDATES].create_index("client_id")

    @staticmethod
    def _load_status_master_seed() -> list[dict]:
        with STATUS_MASTER_SEED_PATH.open("r", encoding="utf-8") as seed_file:
            return json.load(seed_file)

    def health(self) -> dict:
        try:
            self.mongo_client.ping()
            return {"ok": True}
        except Exception as exc:
            logger.log(
                LOG_LEVEL_ERROR,
                f"Mongo health check failed, error: {exc}",
                exc_info=True,
            )
            raise

    def seed_status_master(self, reset: bool = False) -> dict:
        try:
            db = self.mongo_client.get_database()
            self._ensure_indexes(db)
            collection = db[COLLECTION_STATUS_MASTER]
            status_master_seed = self._load_status_master_seed()

            if reset:
                collection.delete_many({})

            inserted = 0
            updated = 0
            for item in status_master_seed:
                result = collection.update_one(
                    {"status_no": item["status_no"]},
                    {"$set": item},
                    upsert=True,
                )
                if result.upserted_id is not None:
                    inserted += 1
                elif result.modified_count > 0:
                    updated += 1

            return {
                "ok": True,
                "reset": reset,
                "inserted": inserted,
                "updated": updated,
                "total_seed_rows": len(status_master_seed),
            }
        except Exception as exc:
            logger.log(
                LOG_LEVEL_ERROR,
                f"Mongo status master seed failed for path {STATUS_MASTER_SEED_PATH}, reset={reset}, error: {exc}",
                exc_info=True,
            )
            raise
