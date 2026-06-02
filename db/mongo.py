from pymongo import MongoClient
from pymongo.database import Database

from utils.constants import DEFAULT_DB_NAME
from utils.env_vars import EnvVars


class MongoDBClient:
    def __init__(self) -> None:
        self._client: MongoClient | None = None

    def connect(self) -> None:
        if self._client is not None:
            return

        mongo_uri = EnvVars.get("MONGODB_URI")
        if not mongo_uri:
            raise ValueError("MONGODB_URI is not set")

        self._client = MongoClient(mongo_uri)

    def disconnect(self) -> None:
        if self._client is not None:
            self._client.close()
            self._client = None

    def get_database(self) -> Database:
        self.connect()
        db_name = EnvVars.get("MONGODB_DB_NAME", DEFAULT_DB_NAME)
        return self._client[db_name]

    def ping(self) -> dict:
        return self.get_database().command("ping")
