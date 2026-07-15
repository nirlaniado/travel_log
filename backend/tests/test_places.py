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


def test_unauthenticated_requests_are_rejected(client: TestClient):
    assert client.get("/places").status_code == 401
    assert client.post("/places", json=PLACE).status_code == 401


def test_create_and_list_place(client: TestClient):
    _register(client, "alice")

    create_resp = client.post("/places", json=PLACE)
    assert create_resp.status_code == 201
    body = create_resp.json()
    assert body["name"] == "Eiffel Tower"
    assert body["status"] == "visited"

    list_resp = client.get("/places")
    assert list_resp.status_code == 200
    assert len(list_resp.json()) == 1


def test_filter_places_by_status(client: TestClient):
    _register(client, "alice")
    client.post("/places", json=PLACE)
    wishlist_place = {
        **PLACE,
        "name": "Kyoto",
        "country": "Japan",
        "city": None,
        "status": "wishlist",
        "rating": None,
        "visited_at": None,
    }
    client.post("/places", json=wishlist_place)

    visited = client.get("/places", params={"status": "visited"})
    assert visited.status_code == 200
    assert len(visited.json()) == 1
    assert visited.json()[0]["name"] == "Eiffel Tower"

    wishlist = client.get("/places", params={"status": "wishlist"})
    assert len(wishlist.json()) == 1
    assert wishlist.json()[0]["name"] == "Kyoto"


def test_invalid_status_rejected(client: TestClient):
    _register(client, "alice")
    resp = client.post("/places", json={**PLACE, "status": "bogus"})
    assert resp.status_code == 422


def test_rating_out_of_range_rejected(client: TestClient):
    _register(client, "alice")
    resp = client.post("/places", json={**PLACE, "rating": 9})
    assert resp.status_code == 422


def test_get_place_detail_includes_notes(client: TestClient):
    _register(client, "alice")
    place_id = client.post("/places", json=PLACE).json()["id"]

    detail = client.get(f"/places/{place_id}")
    assert detail.status_code == 200
    assert detail.json()["notes"] == []


def test_update_place(client: TestClient):
    _register(client, "alice")
    place_id = client.post("/places", json=PLACE).json()["id"]

    updated = client.put(f"/places/{place_id}", json={**PLACE, "status": "liked", "rating": 4})
    assert updated.status_code == 200
    assert updated.json()["status"] == "liked"
    assert updated.json()["rating"] == 4


def test_delete_place(client: TestClient):
    _register(client, "alice")
    place_id = client.post("/places", json=PLACE).json()["id"]

    assert client.delete(f"/places/{place_id}").status_code == 204
    assert client.get(f"/places/{place_id}").status_code == 404


def test_cross_user_place_access_returns_404(client: TestClient):
    _register(client, "alice")
    place_id = client.post("/places", json=PLACE).json()["id"]

    bob = TestClient(app)
    _register(bob, "bob")

    assert bob.get(f"/places/{place_id}").status_code == 404
    assert bob.put(f"/places/{place_id}", json=PLACE).status_code == 404
    assert bob.delete(f"/places/{place_id}").status_code == 404

    # Bob's own list is unaffected by Alice's data.
    assert bob.get("/places").json() == []
