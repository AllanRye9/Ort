"""Tests for the /api/v1/users CRUD endpoints."""

USER_PAYLOAD = {
    "role": "agent",
    "first_name": "Test",
    "last_name": "User",
    "email": "testuser@example.com",
    "password": "TestPass1!",
}


def _create_user(client, payload=None):
    payload = payload or USER_PAYLOAD
    resp = client.post("/api/v1/users/", json=payload)
    assert resp.status_code == 201, resp.text
    return resp.json()


def test_list_users_empty(client):
    resp = client.get("/api/v1/users/")
    assert resp.status_code == 200
    assert isinstance(resp.json(), list)


def test_create_user(client):
    data = _create_user(client)
    assert data["email"] == USER_PAYLOAD["email"]
    assert data["role"] == "agent"
    assert "id" in data


def test_get_user_by_id(client):
    user = _create_user(client)
    resp = client.get(f"/api/v1/users/{user['id']}")
    assert resp.status_code == 200
    assert resp.json()["id"] == user["id"]


def test_get_user_not_found(client):
    resp = client.get("/api/v1/users/99999")
    assert resp.status_code == 404


def test_update_user(client):
    user = _create_user(client)
    resp = client.put(f"/api/v1/users/{user['id']}", json={"first_name": "Updated"})
    assert resp.status_code == 200
    assert resp.json()["first_name"] == "Updated"


def test_delete_user(client):
    user = _create_user(client)
    resp = client.delete(f"/api/v1/users/{user['id']}")
    assert resp.status_code == 200
    # Confirm it's gone
    assert client.get(f"/api/v1/users/{user['id']}").status_code == 404


def test_create_user_duplicate_email(client):
    _create_user(client)
    resp = client.post("/api/v1/users/", json=USER_PAYLOAD)
    assert resp.status_code == 409
