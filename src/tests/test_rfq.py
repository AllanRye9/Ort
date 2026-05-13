"""Tests for the /api/v1/rfqs endpoints."""

USER_PAYLOAD = {
    "role": "agent",
    "first_name": "RFQ",
    "last_name": "Buyer",
    "email": "rfq.buyer@example.com",
    "password": "TestPass1!",
}

RFQ_PAYLOAD = {
    "title": "Need 500 kg of Maize",
    "description": "Looking for best price",
    "quantity": 500.0,
    "unit": "kg",
    "currency": "USD",
}

PROPERTY_PAYLOAD = {
    "title": "Fixed Price Property",
    "property_type": "house",
    "address": "123 Test Street",
    "price": "250000.00",
    "pricing_type": "fixed",
}


def _create_user(client):
    resp = client.post("/api/v1/users/", json=USER_PAYLOAD)
    assert resp.status_code == 201, resp.text
    return resp.json()


def test_list_rfqs_empty(client):
    resp = client.get("/api/v1/rfq/")
    assert resp.status_code == 200
    assert isinstance(resp.json(), list)


def test_create_rfq(client):
    user = _create_user(client)
    payload = {**RFQ_PAYLOAD, "buyer_id": user["id"]}
    resp = client.post("/api/v1/rfq/", json=payload)
    assert resp.status_code == 201, resp.text
    data = resp.json()
    assert data["title"] == RFQ_PAYLOAD["title"]
    assert data["status"] == "open"


def test_get_rfq_by_id(client):
    user = _create_user(client)
    rfq = client.post("/api/v1/rfq/", json={**RFQ_PAYLOAD, "buyer_id": user["id"]}).json()
    resp = client.get(f"/api/v1/rfq/{rfq['id']}")
    assert resp.status_code == 200
    assert resp.json()["id"] == rfq["id"]


def test_get_rfq_not_found(client):
    resp = client.get("/api/v1/rfq/99999")
    assert resp.status_code == 404


def test_update_rfq_status(client):
    user = _create_user(client)
    rfq = client.post("/api/v1/rfq/", json={**RFQ_PAYLOAD, "buyer_id": user["id"]}).json()
    resp = client.put(f"/api/v1/rfq/{rfq['id']}", json={"status": "accepted"})
    assert resp.status_code == 200
    assert resp.json()["status"] == "accepted"


def test_rfq_response_flow(client):
    """Test creating a response to an RFQ."""
    user = _create_user(client)
    rfq = client.post("/api/v1/rfq/", json={**RFQ_PAYLOAD, "buyer_id": user["id"]}).json()

    response_payload = {
        "rfq_id": rfq["id"],
        "quoted_price": "2.80",
        "currency": "USD",
        "notes": "Best deal available",
    }
    resp = client.post(f"/api/v1/rfq/{rfq['id']}/responses", json=response_payload)
    assert resp.status_code == 201, resp.text
    data = resp.json()
    assert data["status"] == "pending"
    assert data["rfq_id"] == rfq["id"]

    # Verify the RFQ status was updated to "quoted"
    updated_rfq = client.get(f"/api/v1/rfq/{rfq['id']}").json()
    assert updated_rfq["status"] == "quoted"


def test_create_property_bid_rejects_fixed_pricing(client):
    prop_resp = client.post("/api/v1/properties/", json=PROPERTY_PAYLOAD)
    assert prop_resp.status_code == 201, prop_resp.text
    prop = prop_resp.json()

    user = _create_user(client)
    resp = client.post(
        "/api/v1/rfq/",
        json={
            "title": "Bid on fixed property",
            "buyer_id": user["id"],
            "property_id": prop["id"],
            "target_price": "200000.00",
            "currency": "USD",
        },
    )
    assert resp.status_code == 400
