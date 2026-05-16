"""Tests for the /api/v1/messages endpoints (conversations & messages)."""

USER_A = {
    "role": "agent",
    "first_name": "User",
    "last_name": "Alpha",
    "email": "user.alpha@example.com",
    "password": "TestPass1!",
}
USER_B = {
    "role": "agent",
    "first_name": "User",
    "last_name": "Beta",
    "email": "user.beta@example.com",
    "agency_name": "Beta Labs",
    "password": "TestPass1!",
}
USER_C = {
    "role": "user",
    "first_name": "User",
    "last_name": "Charlie",
    "email": "user.charlie@example.com",
    "password": "TestPass1!",
}


def _create_user(client, payload):
    resp = client.post("/api/v1/users/", json=payload)
    assert resp.status_code == 201, resp.text
    return resp.json()


def test_create_conversation(client):
    a = _create_user(client, USER_A)
    b = _create_user(client, USER_B)
    resp = client.post(
        "/api/v1/messages/conversations/",
        json={"initiator_id": a["id"], "recipient_id": b["id"], "subject": "Hello"},
    )
    assert resp.status_code == 201, resp.text
    data = resp.json()
    assert data["initiator_id"] == a["id"]
    assert data["recipient_id"] == b["id"]


def test_list_conversations(client):
    a = _create_user(client, USER_A)
    b = _create_user(client, USER_B)
    client.post(
        "/api/v1/messages/conversations/",
        json={"initiator_id": a["id"], "recipient_id": b["id"]},
    )
    resp = client.get("/api/v1/messages/conversations/")
    assert resp.status_code == 200
    assert len(resp.json()) >= 1


def test_create_conversation_rejects_self(client):
    a = _create_user(client, USER_A)
    resp = client.post(
        "/api/v1/messages/conversations/",
        json={"initiator_id": a["id"], "recipient_id": a["id"]},
    )
    assert resp.status_code == 400


def test_create_conversation_rejects_non_business_recipient(client):
    a = _create_user(client, USER_A)
    c = _create_user(client, USER_C)
    resp = client.post(
        "/api/v1/messages/conversations/",
        json={"initiator_id": a["id"], "recipient_id": c["id"]},
    )
    assert resp.status_code == 400


def test_send_and_list_messages(client):
    a = _create_user(client, USER_A)
    b = _create_user(client, USER_B)
    conv = client.post(
        "/api/v1/messages/conversations/",
        json={"initiator_id": a["id"], "recipient_id": b["id"]},
    ).json()

    msg_resp = client.post(
        "/api/v1/messages/",
        json={"conversation_id": conv["id"], "sender_id": a["id"], "body": "Hi there!"},
    )
    assert msg_resp.status_code == 201, msg_resp.text
    msg = msg_resp.json()
    assert msg["body"] == "Hi there!"
    assert msg["message_type"] == "text"
    assert msg["is_read"] is False

    second_msg_resp = client.post(
        "/api/v1/messages/",
        json={"conversation_id": conv["id"], "sender_id": b["id"], "body": "Newest message"},
    )
    assert second_msg_resp.status_code == 201, second_msg_resp.text

    list_resp = client.get(f"/api/v1/messages/?conversation_id={conv['id']}")
    assert list_resp.status_code == 200
    data = list_resp.json()
    assert len(data) == 2
    assert data[0]["id"] > data[1]["id"]
    assert data[0]["body"] == "Newest message"
    assert data[1]["body"] == "Hi there!"


def test_clear_message_body_keeps_record(client):
    a = _create_user(client, USER_A)
    b = _create_user(client, USER_B)
    conv = client.post(
        "/api/v1/messages/conversations/",
        json={"initiator_id": a["id"], "recipient_id": b["id"]},
    ).json()

    msg_resp = client.post(
        "/api/v1/messages/",
        json={"conversation_id": conv["id"], "sender_id": a["id"], "body": "Sensitive text"},
    )
    assert msg_resp.status_code == 201, msg_resp.text
    msg = msg_resp.json()

    clear_resp = client.patch(
        f"/api/v1/messages/{msg['id']}/body",
        json={"sender_id": a["id"]},
    )
    assert clear_resp.status_code == 200, clear_resp.text
    cleared = clear_resp.json()
    assert cleared["id"] == msg["id"]
    assert cleared["body"] == "[message body removed]"

    listed = client.get(f"/api/v1/messages/?conversation_id={conv['id']}")
    assert listed.status_code == 200
    assert len(listed.json()) == 1
    assert listed.json()[0]["id"] == msg["id"]


def test_update_conversation_location(client):
    a = _create_user(client, USER_A)
    b = _create_user(client, USER_B)
    conv_resp = client.post(
        "/api/v1/messages/conversations/",
        json={"initiator_id": a["id"], "recipient_id": b["id"]},
    )
    assert conv_resp.status_code == 201, conv_resp.text
    conv = conv_resp.json()

    update_resp = client.patch(
        f"/api/v1/messages/conversations/{conv['id']}/location",
        json={"actor_id": a["id"], "location": "Kampala"},
    )
    assert update_resp.status_code == 200, update_resp.text
    assert update_resp.json()["location"] == "Kampala"


def test_lookup_business_user_by_name(client):
    _create_user(client, USER_A)
    _create_user(client, USER_B)

    lookup = client.get("/api/v1/users/lookup", params={"q": "Beta Labs", "role_scope": "business"})
    assert lookup.status_code == 200, lookup.text
    user = lookup.json()
    assert user["email"] == USER_B["email"]
    assert user["agency_name"] == USER_B["agency_name"]
