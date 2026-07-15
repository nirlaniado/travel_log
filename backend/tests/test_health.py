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


class _BrokenSession:
    """Simulates a real DB outage: SQLAlchemy connects lazily, so failure
    surfaces when a query actually executes, not when the session object
    is created."""

    def execute(self, *_args, **_kwargs):
        raise RuntimeError("simulated db outage")

    def close(self):
        pass


def _broken_session() -> Generator[Session, None, None]:
    yield _BrokenSession()


@pytest.fixture(autouse=True)
def _reset_overrides():
    yield
    app.dependency_overrides.pop(get_db, None)


def test_health_ok_when_db_reachable():
    app.dependency_overrides[get_db] = _sqlite_session
    response = TestClient(app).get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok", "db": "ok"}


def test_health_503_when_db_unreachable():
    app.dependency_overrides[get_db] = _broken_session
    response = TestClient(app).get("/health")
    assert response.status_code == 503
    assert response.json() == {"status": "degraded", "db": "error"}
