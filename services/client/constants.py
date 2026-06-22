from pathlib import Path

CLIENT_TEST_SEED_PATH = (
    Path(__file__).resolve().parent.parent.parent
    / "db"
    / "postgres"
    / "seeds"
    / "test_clients_seed.json"
)

CLIENT_SEED_LOOKUP_FIELD = "phone"
