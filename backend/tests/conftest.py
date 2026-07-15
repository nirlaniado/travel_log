from collections.abc import Generator

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import sessionmaker
from sqlalchemy.pool import StaticPool

from app import models  # noqa: F401  (registers tables on Base.metadata)
from app.database import Base, get_db
from app.main import app


@pytest.fixture()
def engine():
    """One shared in-memory SQLite database per test, via a single pooled
    connection (StaticPool) — a plain engine would hand out a fresh, empty
    in-memory database on every new connection."""
    eng = create_engine(
        "sqlite:///:memory:",
        connect_args={"check_same_thread": False},
        poolclass=StaticPool,
    )
    Base.metadata.create_all(bind=eng)
    yield eng
    eng.dispose()


@pytest.fixture()
def client(engine) -> Generator[TestClient, None, None]:
    """A TestClient with get_db overridden to open a fresh Session per
    request (matching production), all bound to the same test database.
    Additional independent TestClient(app) instances (separate cookie jars,
    same underlying data) can be created inside a test for cross-user
    isolation checks."""
    session_local = sessionmaker(bind=engine, autoflush=False, expire_on_commit=False)

    def override_get_db():
        db = session_local()
        try:
            yield db
        finally:
            db.close()

    app.dependency_overrides[get_db] = override_get_db
    with TestClient(app) as c:
        yield c
    app.dependency_overrides.pop(get_db, None)


def register_and_login(client: TestClient, username: str = "alice", password: str = "supersecret1") -> TestClient:
    client.post("/auth/register", json={"username": username, "password": password})
    return client
