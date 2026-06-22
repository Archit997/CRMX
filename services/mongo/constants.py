from pathlib import Path

DEFAULT_DB_NAME = "crmx"

COLLECTION_STATUS_MASTER = "status_master"
COLLECTION_CLIENTS = "clients"
COLLECTION_CLIENT_UPDATES = "client_updates"

STATUS_MASTER_SEED_PATH = (
    Path(__file__).resolve().parent.parent.parent
    / "db"
    / "postgres"
    / "seeds"
    / "status_master_seed.json"
)
