import logging
import os

from sqlalchemy import create_engine, inspect, text
from sqlalchemy.orm import DeclarativeBase, sessionmaker

logger = logging.getLogger(__name__)

SQLALCHEMY_DATABASE_URL = os.getenv("DATABASE_URL", "sqlite:///./real_estate.db")

# Railway (and Heroku) provide "postgres://" URLs; SQLAlchemy 2.x requires
# the "postgresql://" scheme.  Normalise here so the app works transparently
# on both local SQLite and production PostgreSQL.
if SQLALCHEMY_DATABASE_URL.startswith("postgres://"):
    SQLALCHEMY_DATABASE_URL = SQLALCHEMY_DATABASE_URL.replace(
        "postgres://", "postgresql://", 1
    )

connect_args = {"check_same_thread": False} if SQLALCHEMY_DATABASE_URL.startswith("sqlite") else {}

engine = create_engine(SQLALCHEMY_DATABASE_URL, connect_args=connect_args)
local_session = sessionmaker(autocommit=False, autoflush=False, bind=engine)


class Base(DeclarativeBase):
    pass


def get_db():
    db = local_session()
    try:
        yield db
    finally:
        db.close()


# ---------------------------------------------------------------------------
# Idempotent schema migrations
# Each entry is (table_name, column_name, sql_type).
# The function adds the column only when it is absent – safe to run on every
# startup against both SQLite (dev) and PostgreSQL (prod).
# ---------------------------------------------------------------------------
_MIGRATIONS: list[tuple[str, str, str]] = [
    ("users", "license_number", "VARCHAR(100)"),
    ("users", "agency_name",    "VARCHAR(255)"),
    ("users", "bio",            "TEXT"),
]


def run_schema_migrations() -> None:
    """Add columns that exist in SQLAlchemy models but may be absent from an
    already-created database.  Uses SQLAlchemy's inspector so it works with
    both SQLite and PostgreSQL."""
    inspector = inspect(engine)
    existing_tables = set(inspector.get_table_names())

    with engine.begin() as conn:
        for table, column, col_type in _MIGRATIONS:
            if table not in existing_tables:
                continue
            existing_cols = {c["name"] for c in inspector.get_columns(table)}
            if column not in existing_cols:
                try:
                    conn.execute(text(f"ALTER TABLE {table} ADD COLUMN {column} {col_type}"))
                    logger.info("Schema migration: added column %s.%s", table, column)
                except Exception as exc:  # pragma: no cover
                    logger.warning(
                        "Schema migration warning for %s.%s: %s", table, column, exc
                    )