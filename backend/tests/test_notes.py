from fastapi.testclient import TestClient

from app.main import app

PLACE = {
    "name": "Eiffel Tower",
    "country": "France",
    "city": "Paris",
    "latitude": "48.8584",
    "longitude": "2.2945",
    "status": "visited",
    "rating": 5,
    "visited_at": "2025-06-01",
}


def _register(client: TestClient, username: str) -> None:
    client.post("/auth/register", json={"username": username, "password": "supersecret1"})


def _create_place(client: TestClient) -> int:
    return client.post("/places", json=PLACE).json()["id"]


def test_create_note(client: TestClient):
    _register(client, "alice")
    place_id = _create_place(client)

    resp = client.post(f"/places/{place_id}/notes", json={"title": "Sunset", "content": "Go at 9pm in summer."})
    assert resp.status_code == 201
    body = resp.json()
    assert body["title"] == "Sunset"
    assert body["place_id"] == place_id

    detail = client.get(f"/places/{place_id}").json()
    assert len(detail["notes"]) == 1


def test_create_note_blank_content_rejected(client: TestClient):
    _register(client, "alice")
    place_id = _create_place(client)

    resp = client.post(f"/places/{place_id}/notes", json={"title": "Sunset", "content": "   "})
    assert resp.status_code == 422


def test_create_note_on_missing_place_returns_404(client: TestClient):
    _register(client, "alice")
    resp = client.post("/places/999/notes", json={"title": "x", "content": "y"})
    assert resp.status_code == 404


def test_update_note(client: TestClient):
    _register(client, "alice")
    place_id = _create_place(client)
    note_id = client.post(f"/places/{place_id}/notes", json={"title": "Sunset", "content": "Go at 9pm."}).json()["id"]

    resp = client.put(f"/notes/{note_id}", json={"title": "Sunset tip", "content": "Go at 21:00 in summer."})
    assert resp.status_code == 200
    assert resp.json()["title"] == "Sunset tip"


def test_delete_note(client: TestClient):
    _register(client, "alice")
    place_id = _create_place(client)
    note_id = client.post(f"/places/{place_id}/notes", json={"title": "Sunset", "content": "Go at 9pm."}).json()["id"]

    assert client.delete(f"/notes/{note_id}").status_code == 204
    detail = client.get(f"/places/{place_id}").json()
    assert detail["notes"] == []


def test_cross_user_note_access_returns_404(client: TestClient):
    _register(client, "alice")
    place_id = _create_place(client)
    note_id = client.post(f"/places/{place_id}/notes", json={"title": "Sunset", "content": "Go at 9pm."}).json()["id"]

    bob = TestClient(app)
    _register(bob, "bob")

    assert bob.put(f"/notes/{note_id}", json={"title": "x", "content": "y"}).status_code == 404
    assert bob.delete(f"/notes/{note_id}").status_code == 404
