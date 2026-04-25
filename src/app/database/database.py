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
# sql_type may include DEFAULT so that existing rows receive the default value
# when the column is first added.
# ---------------------------------------------------------------------------
_MIGRATIONS: list[tuple[str, str, str]] = [
    ("users", "license_number", "VARCHAR(100)"),
    ("users", "agency_name",    "VARCHAR(255)"),
    ("users", "bio",            "TEXT"),
    # Core real-estate table status columns – backfill if somehow absent
    ("properties",          "status",         "VARCHAR(50)  DEFAULT 'available'"),
    ("inquiries",           "status",         "VARCHAR(50)  DEFAULT 'new'"),
    ("appointments",        "status",         "VARCHAR(50)  DEFAULT 'scheduled'"),
    # Marketplace table status / type / currency columns
    ("agriculture_listings",  "status",         "VARCHAR(50)  DEFAULT 'available'"),
    ("manufacturing_products","status",         "VARCHAR(50)  DEFAULT 'available'"),
    ("orders",               "status",         "VARCHAR(50)  DEFAULT 'pending'"),
    ("orders",               "payment_status", "VARCHAR(50)  DEFAULT 'unpaid'"),
    ("orders",               "currency",       "VARCHAR(10)  DEFAULT 'USD'"),
    ("messages",             "message_type",   "VARCHAR(50)  DEFAULT 'text'"),
    ("rfqs",                 "status",         "VARCHAR(50)  DEFAULT 'open'"),
    ("rfqs",                 "currency",       "VARCHAR(10)  DEFAULT 'USD'"),
    ("rfq_responses",        "status",         "VARCHAR(50)  DEFAULT 'pending'"),
    ("rfq_responses",        "currency",       "VARCHAR(10)  DEFAULT 'USD'"),
    ("tenant_subscriptions", "status",         "VARCHAR(50)  DEFAULT 'active'"),
    ("tenant_subscriptions", "billing_cycle",  "VARCHAR(50)  DEFAULT 'monthly'"),
]

# Columns whose type needs widening on existing databases.
# Skipped on SQLite (which ignores VARCHAR length constraints anyway).
_ALTER_COLUMN_MIGRATIONS: list[tuple[str, str, str]] = [
    ("users", "phone", "VARCHAR(30)"),
]


def run_schema_migrations() -> None:
    """Add columns that exist in SQLAlchemy models but may be absent from an
    already-created database.  Uses SQLAlchemy's inspector so it works with
    both SQLite and PostgreSQL.

    Also backfills NULL values in status/type/currency columns so that
    response-model serialisation never fails with a validation error."""
    import re
    _IDENT_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
    # Allowlist for col_type: only well-known SQL base types plus an optional
    # DEFAULT clause whose value is a single-quoted alphanumeric string.
    # All values come from the hardcoded _MIGRATIONS constant, but we validate
    # defensively so that an accidental edit cannot produce an injection.
    _COL_TYPE_RE = re.compile(
        r"^(?:VARCHAR|TEXT|INTEGER|DECIMAL|FLOAT|BOOLEAN|DATE|DATETIME)"
        r"(?:\s*\(\s*\d+(?:\s*,\s*\d+)?\s*\))?"   # optional (len) or (p,s)
        r"(?:\s+DEFAULT\s+'[A-Za-z0-9_]+')?$",      # optional DEFAULT clause
        re.IGNORECASE,
    )

    inspector = inspect(engine)
    existing_tables = set(inspector.get_table_names())

    with engine.begin() as conn:
        for table, column, col_type in _MIGRATIONS:
            # Guard against unexpected names (all values come from the
            # hardcoded _MIGRATIONS constant, but validate defensively).
            if not (_IDENT_RE.match(table) and _IDENT_RE.match(column)):
                logger.error(
                    "Schema migration skipped – unsafe identifier: %s.%s", table, column
                )
                continue
            if not _COL_TYPE_RE.match(col_type.strip()):
                logger.error(
                    "Schema migration skipped – unsafe col_type for %s.%s: %s",
                    table, column, col_type,
                )
                continue
            if table not in existing_tables:
                continue
            # Re-fetch column list inside the transaction so we always see
            # the current state of the schema.
            existing_cols = {
                c["name"] for c in inspect(conn).get_columns(table)
            }
            if column not in existing_cols:
                try:
                    # SQL DDL identifiers (table/column names) cannot be bound
                    # as query parameters; they must be interpolated.  Safety
                    # is ensured by the _IDENT_RE and _COL_TYPE_RE checks above
                    # which confirm all three values match strict allow-list
                    # patterns (all sourced from the hardcoded _MIGRATIONS
                    # constant, never from user input).
                    conn.execute(text(f"ALTER TABLE {table} ADD COLUMN {column} {col_type}"))
                    logger.info("Schema migration: added column %s.%s", table, column)
                except Exception as exc:  # pragma: no cover
                    logger.warning(
                        "Schema migration warning for %s.%s: %s", table, column, exc
                    )
            else:
                # Column already exists – backfill any NULL values to the
                # declared DEFAULT so that Pydantic response serialisation
                # never receives None for a required string field.
                # Extract default from col_type string, e.g.
                # "VARCHAR(50) DEFAULT 'available'" → 'available'
                # Both table/column are already validated by _IDENT_RE above.
                # default_val is bound as a query parameter to prevent injection.
                _default_match = re.search(r"DEFAULT\s+'([^']+)'", col_type, re.IGNORECASE)
                if _default_match:
                    default_val = _default_match.group(1)
                    try:
                        conn.execute(
                            text(
                                f"UPDATE {table} SET {column} = :dv"
                                f" WHERE {column} IS NULL"
                            ),
                            {"dv": default_val},
                        )
                    except Exception as exc:  # pragma: no cover
                        logger.warning(
                            "Backfill migration warning for %s.%s: %s", table, column, exc
                        )

    # Widen column types on PostgreSQL for existing databases.
    # SQLite ignores VARCHAR length so this step is unnecessary there.
    if not SQLALCHEMY_DATABASE_URL.startswith("sqlite"):
        with engine.begin() as conn:
            for table, column, col_type in _ALTER_COLUMN_MIGRATIONS:
                if not (_IDENT_RE.match(table) and _IDENT_RE.match(column)):
                    logger.error(
                        "ALTER migration skipped – unsafe identifier: %s.%s", table, column
                    )
                    continue
                try:
                    conn.execute(
                        text(f"ALTER TABLE {table} ALTER COLUMN {column} TYPE {col_type}")
                    )
                    logger.info("Schema migration: widened column %s.%s to %s", table, column, col_type)
                except Exception as exc:  # pragma: no cover
                    logger.warning(
                        "Schema migration warning for alter %s.%s: %s", table, column, exc
                    )