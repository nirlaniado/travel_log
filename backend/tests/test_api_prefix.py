from collections.abc import Generator

import pytest
from fastapi.testclient import TestClient
from sqlalchemy import create_engine
from sqlalchemy.orm import Session, sessionmaker

from app.database import get_db
from app.main import app


def _sqlite_session() -> Generator[Session, None, None]:
    engine = create_engine("sqlite:///:memory:")
    db = sessionmaker(bind=engine)()
    try:
        yield db
    finally:
        db.close()


@pytest.fixture(autouse=True)
def _db_override():
    app.dependency_overrides[get_db] = _sqlite_session
    yield
    app.dependency_overrides.pop(get_db, None)


def test_api_prefixed_path_reaches_same_route():
    client = TestClient(app)
    assert client.get("/health").status_code == 200
    prefixed = client.get("/api/health")
    assert prefixed.status_code == 200
    assert prefixed.json() == client.get("/health").json()


def test_unprefixed_routes_unaffected():
    client = TestClient(app)
    # 401 (not 404) proves the auth route resolved normally without the prefix
    assert client.get("/auth/me").status_code == 401
    assert client.get("/api/auth/me").status_code == 401
