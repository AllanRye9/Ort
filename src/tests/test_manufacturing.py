"""Tests for the /api/v1/manufacturing endpoints."""

TENANT_PAYLOAD = {
    "name": "Mfg Ltd",
    "slug": "mfg-ltd",
    "tenant_type": "sme",
    "email": "mfg@ltd.com",
}

PRODUCT_BASE = {
    "title": "Hand-woven Basket",
    "wholesale_price": "12.99",
    "quantity_available": 500,
    "unit": "units",
    "is_locally_made": True,
}


def _create_tenant(client):
    resp = client.post("/api/v1/tenants/", json=TENANT_PAYLOAD)
    assert resp.status_code == 201, resp.text
    return resp.json()


def test_list_manufacturing_empty(client):
    resp = client.get("/api/v1/manufacturing/")
    assert resp.status_code == 200
    assert isinstance(resp.json(), list)


def test_create_manufacturing_product(client):
    tenant = _create_tenant(client)
    payload = {**PRODUCT_BASE, "tenant_id": tenant["id"]}
    resp = client.post("/api/v1/manufacturing/", json=payload)
    assert resp.status_code == 201, resp.text
    data = resp.json()
    assert data["title"] == "Hand-woven Basket"
    assert data["status"] == "available"
    assert data["currency"] == "UGX"
    assert data["pricing_type"] == "negotiable"


def test_get_manufacturing_product(client):
    tenant = _create_tenant(client)
    payload = {**PRODUCT_BASE, "tenant_id": tenant["id"]}
    product = client.post("/api/v1/manufacturing/", json=payload).json()
    resp = client.get(f"/api/v1/manufacturing/{product['id']}")
    assert resp.status_code == 200
    assert resp.json()["id"] == product["id"]


def test_get_manufacturing_not_found(client):
    resp = client.get("/api/v1/manufacturing/99999")
    assert resp.status_code == 404


def test_update_manufacturing_product(client):
    tenant = _create_tenant(client)
    payload = {**PRODUCT_BASE, "tenant_id": tenant["id"]}
    product = client.post("/api/v1/manufacturing/", json=payload).json()
    resp = client.put(f"/api/v1/manufacturing/{product['id']}", json={"status": "out_of_stock"})
    assert resp.status_code == 200
    assert resp.json()["status"] == "out_of_stock"


def test_delete_manufacturing_product(client):
    tenant = _create_tenant(client)
    payload = {**PRODUCT_BASE, "tenant_id": tenant["id"]}
    product = client.post("/api/v1/manufacturing/", json=payload).json()
    resp = client.delete(f"/api/v1/manufacturing/{product['id']}")
    assert resp.status_code == 200
    assert client.get(f"/api/v1/manufacturing/{product['id']}").status_code == 404
