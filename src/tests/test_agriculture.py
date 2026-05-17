"""Tests for the /api/v1/agriculture endpoints."""

TENANT_PAYLOAD = {
    "name": "Farm Co",
    "slug": "farm-co",
    "tenant_type": "sme",
    "email": "farm@co.com",
}

LISTING_BASE = {
    "title": "Organic Maize",
    "price_per_unit": "3.50",
    "quantity_available": 1000,
    "unit": "kg",
}

OWNER_PAYLOAD = {
    "role": "agent",
    "first_name": "Agri",
    "last_name": "Owner",
    "email": "agri.owner@example.com",
    "password": "TestPass1!",
}


def _create_tenant(client):
    resp = client.post("/api/v1/tenants/", json=TENANT_PAYLOAD)
    assert resp.status_code == 201, resp.text
    return resp.json()


def _create_user(client):
    resp = client.post("/api/v1/users/", json=OWNER_PAYLOAD)
    assert resp.status_code == 201, resp.text
    return resp.json()


def _auth_headers(client, email, password):
    resp = client.post("/api/v1/auth/login", json={"email": email, "password": password})
    assert resp.status_code == 200, resp.text
    return {"Authorization": f"Bearer {resp.json()['access_token']}"}


def test_list_agriculture_listings_empty(client):
    resp = client.get("/api/v1/agriculture/")
    assert resp.status_code == 200
    assert isinstance(resp.json(), list)


def test_create_agriculture_listing(client):
    tenant = _create_tenant(client)
    payload = {**LISTING_BASE, "tenant_id": tenant["id"]}
    resp = client.post("/api/v1/agriculture/", json=payload)
    assert resp.status_code == 201, resp.text
    data = resp.json()
    assert data["title"] == "Organic Maize"
    assert data["status"] == "available"
    assert data["currency"] == "UGX"
    assert data["pricing_type"] == "negotiable"


def test_get_agriculture_listing(client):
    tenant = _create_tenant(client)
    payload = {**LISTING_BASE, "tenant_id": tenant["id"]}
    listing = client.post("/api/v1/agriculture/", json=payload).json()
    resp = client.get(f"/api/v1/agriculture/{listing['id']}")
    assert resp.status_code == 200
    assert resp.json()["id"] == listing["id"]


def test_get_agriculture_listing_not_found(client):
    resp = client.get("/api/v1/agriculture/99999")
    assert resp.status_code == 404


def test_update_agriculture_listing(client):
    tenant = _create_tenant(client)
    payload = {**LISTING_BASE, "tenant_id": tenant["id"]}
    listing = client.post("/api/v1/agriculture/", json=payload).json()
    resp = client.put(f"/api/v1/agriculture/{listing['id']}", json={"status": "sold_out"})
    assert resp.status_code == 200
    assert resp.json()["status"] == "sold_out"


def test_delete_agriculture_listing(client):
    owner = _create_user(client)
    tenant = _create_tenant(client)
    payload = {**LISTING_BASE, "tenant_id": tenant["id"], "owner_user_id": owner["id"]}
    listing = client.post("/api/v1/agriculture/", json=payload).json()
    headers = _auth_headers(client, OWNER_PAYLOAD["email"], OWNER_PAYLOAD["password"])
    resp = client.delete(f"/api/v1/agriculture/{listing['id']}", headers=headers)
    assert resp.status_code == 200
    assert client.get(f"/api/v1/agriculture/{listing['id']}").status_code == 404


def test_filter_agriculture_matches_uae_alias(client):
    tenant = _create_tenant(client)
    created = client.post(
        "/api/v1/agriculture/",
        json={
            **LISTING_BASE,
            "tenant_id": tenant["id"],
            "location": "Dubai, United Arab Emirates",
        },
    )
    assert created.status_code == 201, created.text

    resp = client.get("/api/v1/agriculture/", params={"country": "UAE"})
    assert resp.status_code == 200
    assert len(resp.json()) == 1
