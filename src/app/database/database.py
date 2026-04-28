import logging
import os
import traceback

from sqlalchemy import create_engine, inspect, text
from sqlalchemy.orm import DeclarativeBase, sessionmaker

logger = logging.getLogger(__name__)

SQLALCHEMY_DATABASE_URL = os.getenv("DATABASE_URL")
if not SQLALCHEMY_DATABASE_URL:
    raise RuntimeError(
        "DATABASE_URL environment variable is not set. "
        "Please configure a PostgreSQL connection string, e.g. "
        "postgresql://user:password@host/dbname"
    )

# Railway (and Heroku) provide "postgres://" URLs; SQLAlchemy 2.x requires
# the "postgresql://" scheme.  Normalise here so the app works transparently.
if SQLALCHEMY_DATABASE_URL.startswith("postgres://"):
    SQLALCHEMY_DATABASE_URL = SQLALCHEMY_DATABASE_URL.replace(
        "postgres://", "postgresql://", 1
    )

# Log which database backend is in use (mask credentials for safety).
_db_scheme = SQLALCHEMY_DATABASE_URL.split("://")[0]
logger.info("Database backend: %s", _db_scheme)

# ---------------------------------------------------------------------------
# Engine creation
# SQLAlchemy is lazy – it does not open a real connection until the first
# query, so create_engine() itself rarely fails.  We immediately verify the
# connection with a lightweight SELECT 1 so that a misconfigured DATABASE_URL
# is caught at startup (and logged) rather than silently at request time.
# ---------------------------------------------------------------------------
try:
    engine = create_engine(SQLALCHEMY_DATABASE_URL)
    # Eagerly verify the connection so DATABASE_URL problems surface at startup.
    with engine.connect() as _probe:
        _probe.execute(text("SELECT 1"))
    logger.info("Database connection verified successfully")
except Exception as exc:
    logger.error(
        "Failed to connect to the database (%s): %s\n%s",
        _db_scheme,
        exc,
        traceback.format_exc(),
    )
    # Re-raise so Gunicorn/Uvicorn logs the failure and the worker exits
    # cleanly instead of hanging on the first request.
    raise

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
# startup against an existing PostgreSQL database.
# sql_type may include DEFAULT so that existing rows receive the default value
# when the column is first added.
# ---------------------------------------------------------------------------
_MIGRATIONS: list[tuple[str, str, str]] = [
    ("users", "license_number", "VARCHAR(100)"),
    ("users", "agency_name",    "VARCHAR(255)"),
    ("users", "bio",            "TEXT"),
    ("users", "avatar_url",     "TEXT"),
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
    ("admin_logs",       "detail",         "TEXT"),
    ("support_tickets",  "status",         "VARCHAR(50)  DEFAULT 'open'"),
    ("support_tickets",  "resolution",     "TEXT"),
    ("manufacturing_products", "location", "VARCHAR(255)"),
    ("agriculture_listings", "map_link", "TEXT"),
    ("manufacturing_products", "map_link", "TEXT"),
    ("reviews",          "reviewed_agent_id", "INTEGER"),
    ("saved_items", "user_id",    "INTEGER"),
    ("saved_items", "item_type",  "VARCHAR(50)"),
    ("saved_items", "item_id",    "INTEGER"),
]

# Columns whose type needs widening on existing databases.
_ALTER_COLUMN_MIGRATIONS: list[tuple[str, str, str]] = [
    ("users", "phone", "VARCHAR(30)"),
]

# Enum values to add to existing PostgreSQL enum types.
# Each entry is (enum_type_name, value_to_add).
# Uses "ADD VALUE IF NOT EXISTS" so it is safe to run on any database state.
_ENUM_VALUE_MIGRATIONS: list[tuple[str, str]] = [
    ("user_roles", "user"),
    ("user_roles", "company"),
    ("user_roles", "organization"),
    ("property_types", "villa"),
    ("property_types", "office"),
    ("property_types", "warehouse"),
    ("property_types", "other"),
]


def run_schema_migrations() -> None:
    """Add columns that exist in SQLAlchemy models but may be absent from an
    already-created PostgreSQL database.  Uses SQLAlchemy's inspector to
    detect missing columns.

    Also backfills NULL values in status/type/currency columns so that
    response-model serialisation never fails with a validation error.

    All DDL/DML runs under AUTOCOMMIT so that a failure in one step never
    leaves a PostgreSQL transaction in the ABORTED state and never prevents
    subsequent migration steps from executing.
    """
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

    # Run every migration statement under AUTOCOMMIT.  This guarantees that:
    # 1. A failed DDL statement does not abort subsequent statements.
    # 2. ALTER TYPE … ADD VALUE works on PostgreSQL < 12 (which disallows
    #    that command inside an explicit transaction).
    # SQL DDL identifiers (table/column/type names) cannot be bound as query
    # parameters; they must be interpolated.  Safety is ensured by the
    # _IDENT_RE and _COL_TYPE_RE checks below which confirm all values match
    # strict allow-list patterns (all sourced from the hardcoded migration
    # constants, never from user input).
    ac_engine = engine.execution_options(isolation_level="AUTOCOMMIT")

    with ac_engine.connect() as conn:
        existing_tables = set(inspect(conn).get_table_names())

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
            # Re-fetch column list so we always see the current schema state.
            existing_cols = {c["name"] for c in inspect(conn).get_columns(table)}
            if column not in existing_cols:
                try:
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

    # Widen column types on existing PostgreSQL databases.
    with ac_engine.connect() as conn:
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

    # Add missing values to PostgreSQL enum types.
    # Existing databases created before 'company'/'organization' were added to
    # the user_roles enum need this step; fresh databases created by
    # create_all() already include all values so this is a safe no-op there.
    with ac_engine.connect() as conn:
        for enum_name, enum_value in _ENUM_VALUE_MIGRATIONS:
            if not (_IDENT_RE.match(enum_name) and _IDENT_RE.match(enum_value)):
                logger.error(
                    "Enum migration skipped – unsafe identifier: %s / %s",
                    enum_name, enum_value,
                )
                continue
            try:
                conn.execute(
                    text(
                        f"ALTER TYPE {enum_name}"
                        f" ADD VALUE IF NOT EXISTS '{enum_value}'"
                    )
                )
                logger.info(
                    "Enum migration: ensured value '%s' exists in type %s",
                    enum_value, enum_name,
                )
            except Exception as exc:  # pragma: no cover
                logger.warning(
                    "Enum migration warning for %s / %s: %s",
                    enum_name, enum_value, exc,
                )