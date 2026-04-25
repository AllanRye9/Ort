"""
Shared pytest fixtures for the FastAPI test suite.
Uses a temporary SQLite database so tests are fully isolated
from any production or development database.
"""
import os
import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker

# Point to a temp SQLite database before importing anything that touches DATABASE_URL
os.environ.setdefault("DATABASE_URL", "sqlite:///./test_ort.db")
os.environ.setdefault("SECRET_KEY", "test-secret-key-for-ci")

from app.database.database import Base, get_db  # noqa: E402
from app.models import models  # noqa: E402, F401 – register tables with Base
from app.models import marketplace_models  # noqa: E402, F401
from app.main import app  # noqa: E402

TEST_DB_URL = "sqlite:///./test_ort.db"

test_engine = create_engine(TEST_DB_URL, connect_args={"check_same_thread": False})
TestingSession = sessionmaker(autocommit=False, autoflush=False, bind=test_engine)


@pytest.fixture(scope="session", autouse=True)
def create_tables():
    """Create all tables once per test session, then drop them."""
    Base.metadata.create_all(bind=test_engine)
    yield
    Base.metadata.drop_all(bind=test_engine)
    # Remove the test DB file
    if os.path.exists("test_ort.db"):
        os.remove("test_ort.db")


@pytest.fixture()
def db_session(create_tables):  # noqa: F811
    """Provide a transactional test database session that rolls back after each test."""
    connection = test_engine.connect()
    transaction = connection.begin()
    session = TestingSession(bind=connection)

    yield session

    session.close()
    transaction.rollback()
    connection.close()


@pytest.fixture()
def client(db_session):
    """Return a TestClient whose DB dependency is overridden with the test session."""

    def _override_get_db():
        try:
            yield db_session
        finally:
            pass

    app.dependency_overrides[get_db] = _override_get_db
    with TestClient(app) as c:
        yield c
    app.dependency_overrides.clear()
