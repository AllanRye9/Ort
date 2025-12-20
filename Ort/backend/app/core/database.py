from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
from sqlalchemy.ext.asyncio import AsyncSession, create_async_engine
from .config import settings

# For SQLite (development/testing)
# Use SQLite for simplicity - no need for PostgreSQL server
SQLITE_DATABASE_URL = "sqlite+aiosqlite:///./real_estate.db"

# Synchronous engine for Alembic migrations (SQLite)
engine = create_engine(
    "sqlite:///./real_estate.db",
    connect_args={"check_same_thread": False},
)

# Async engine for FastAPI (SQLite)
async_engine = create_async_engine(
    SQLITE_DATABASE_URL,
    echo=True,
    future=True,
)

SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
AsyncSessionLocal = sessionmaker(
    async_engine, class_=AsyncSession, expire_on_commit=False
)

Base = declarative_base()


# Dependency for FastAPI
async def get_db():
    async with AsyncSessionLocal() as session:
        try:
            yield session
            await session.commit()
        except Exception:
            await session.rollback()
            raise
        finally:
            await session.close()