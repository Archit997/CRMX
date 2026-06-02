from db.postgres import PostgresDB


class PostgresService:
    def __init__(self, postgres_db: PostgresDB) -> None:
        self.postgres_db = postgres_db

    def health(self) -> dict:
        return self.postgres_db.ping()
