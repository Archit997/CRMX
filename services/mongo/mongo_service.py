from db.mongo import MongoDBClient
from utils.constants import COLLECTION_CLIENTS, COLLECTION_CLIENT_UPDATES, COLLECTION_STATUS_MASTER, STATUS_MASTER_SEED

from pymongo.database import Database

class MongoService:
    def __init__(self, mongo_client: MongoDBClient) -> None:
        self.mongo_client = mongo_client

    def _ensure_indexes(db: Database) -> None:
        db[COLLECTION_STATUS_MASTER].create_index("status_no", unique=True)
        db[COLLECTION_CLIENTS].create_index("client_id", unique=True)
        db[COLLECTION_CLIENT_UPDATES].create_index("update_id", unique=True)
        db[COLLECTION_CLIENT_UPDATES].create_index("client_id")

    def health(self) -> dict:
        self.mongo_client.ping()
        return {"ok": True}

    def seed_status_master(self, reset: bool = False) -> dict:
        db = self.mongo_client.get_database()

        self._ensure_indexes(db)
        collection = db[COLLECTION_STATUS_MASTER]

        if reset:
            collection.delete_many({})

        inserted = 0
        updated = 0
        for item in STATUS_MASTER_SEED:
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
            "total_seed_rows": len(STATUS_MASTER_SEED),
        }