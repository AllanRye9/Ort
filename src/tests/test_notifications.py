"""Tests for the /api/v1/notifications endpoints."""

USER_PAYLOAD = {
    "role": "agent",
    "first_name": "Notify",
    "last_name": "User",
    "email": "notify.user@example.com",
    "password": "TestPass1!",
}


def _create_user(client):
    resp = client.post("/api/v1/users/", json=USER_PAYLOAD)
    assert resp.status_code == 201, resp.text
    return resp.json()


def test_list_notifications_empty(client):
    user = _create_user(client)
    resp = client.get(f"/api/v1/notifications/?user_id={user['id']}")
    assert resp.status_code == 200
    assert isinstance(resp.json(), list)


def test_create_notification(client):
    user = _create_user(client)
    payload = {
        "user_id": user["id"],
        "title": "Your order was confirmed",
        "body": "Order #ORD-001 confirmed",
        "notification_type": "order_update",
    }
    resp = client.post("/api/v1/notifications/", json=payload)
    assert resp.status_code == 201, resp.text
    data = resp.json()
    assert data["title"] == "Your order was confirmed"
    assert data["is_read"] is False


def test_get_notification_by_id(client):
    user = _create_user(client)
    notif = client.post(
        "/api/v1/notifications/",
        json={"user_id": user["id"], "title": "Test"},
    ).json()
    resp = client.get(f"/api/v1/notifications/{notif['id']}")
    assert resp.status_code == 200
    assert resp.json()["id"] == notif["id"]


def test_get_notification_not_found(client):
    resp = client.get("/api/v1/notifications/99999")
    assert resp.status_code == 404


def test_mark_notification_read(client):
    user = _create_user(client)
    notif = client.post(
        "/api/v1/notifications/",
        json={"user_id": user["id"], "title": "Unread"},
    ).json()
    resp = client.put(f"/api/v1/notifications/{notif['id']}", json={"is_read": True})
    assert resp.status_code == 200
    assert resp.json()["is_read"] is True


def test_mark_all_read(client):
    user = _create_user(client)
    client.post("/api/v1/notifications/", json={"user_id": user["id"], "title": "N1"})
    client.post("/api/v1/notifications/", json={"user_id": user["id"], "title": "N2"})
    resp = client.put(f"/api/v1/notifications/read-all/?user_id={user['id']}")
    assert resp.status_code == 200
    notifications = client.get(
        f"/api/v1/notifications/?user_id={user['id']}&unread_only=true"
    ).json()
    assert len(notifications) == 0

