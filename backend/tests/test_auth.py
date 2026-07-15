from fastapi.testclient import TestClient

from app.config import get_settings
from app.main import app


def test_register_creates_user_and_session_cookie(client: TestClient):
    resp = client.post("/auth/register", json={"username": "alice", "password": "supersecret1"})
    assert resp.status_code == 201
    body = resp.json()
    assert body["username"] == "alice"
    assert "password" not in body
    assert "password_hash" not in body
    assert "session" in resp.cookies


def test_register_duplicate_username_conflicts(client: TestClient):
    client.post("/auth/register", json={"username": "alice", "password": "supersecret1"})
    resp = client.post("/auth/register", json={"username": "alice", "password": "anotherpass1"})
    assert resp.status_code == 409


def test_register_weak_password_rejected(client: TestClient):
    resp = client.post("/auth/register", json={"username": "bob", "password": "short"})
    assert resp.status_code == 422


def test_register_invalid_username_charset_rejected(client: TestClient):
    resp = client.post("/auth/register", json={"username": "bad user!", "password": "supersecret1"})
    assert resp.status_code == 422


def test_login_wrong_password_returns_401(client: TestClient):
    client.post("/auth/register", json={"username": "alice", "password": "supersecret1"})
    resp = client.post("/auth/login", json={"username": "alice", "password": "wrongpassword"})
    assert resp.status_code == 401


def test_login_unknown_user_returns_same_401_as_wrong_password(client: TestClient):
    resp = client.post("/auth/login", json={"username": "ghost", "password": "whatever1"})
    assert resp.status_code == 401
    assert resp.json()["detail"] == "Invalid username or password"


def test_login_success_sets_cookie(client: TestClient):
    client.post("/auth/register", json={"username": "alice", "password": "supersecret1"})
    client.cookies.clear()
    resp = client.post("/auth/login", json={"username": "alice", "password": "supersecret1"})
    assert resp.status_code == 200
    assert "session" in resp.cookies


def test_login_lockout_after_max_failed_attempts(client: TestClient):
    client.post("/auth/register", json={"username": "alice", "password": "supersecret1"})
    client.cookies.clear()
    max_attempts = get_settings().login_max_failed_attempts

    for _ in range(max_attempts):
        resp = client.post("/auth/login", json={"username": "alice", "password": "wrongpassword"})
        assert resp.status_code == 401

    locked_resp = client.post("/auth/login", json={"username": "alice", "password": "wrongpassword"})
    assert locked_resp.status_code == 429
    assert "Retry-After" in locked_resp.headers

    # Correct password is also rejected while locked out.
    still_locked = client.post("/auth/login", json={"username": "alice", "password": "supersecret1"})
    assert still_locked.status_code == 429


def test_me_requires_authentication(client: TestClient):
    assert client.get("/auth/me").status_code == 401


def test_me_returns_current_user(client: TestClient):
    client.post("/auth/register", json={"username": "alice", "password": "supersecret1"})
    resp = client.get("/auth/me")
    assert resp.status_code == 200
    assert resp.json()["username"] == "alice"


def test_logout_revokes_session_server_side(client: TestClient):
    client.post("/auth/register", json={"username": "alice", "password": "supersecret1"})
    assert client.get("/auth/me").status_code == 200
    token = client.cookies.get("session")
    assert token

    logout_resp = client.post("/auth/logout")
    assert logout_resp.status_code == 200

    # A fresh client presenting the pre-logout token must be rejected —
    # proves the token is dead server-side, not just cleared in this client.
    replay_client = TestClient(app)
    replay_client.cookies.set("session", token)
    assert replay_client.get("/auth/me").status_code == 401
