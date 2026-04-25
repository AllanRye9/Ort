"""Tests for the /api/v1/tenants CRUD endpoints."""

TENANT_PAYLOAD = {
    "name": "Test Company",
    "slug": "test-company",
    "tenant_type": "sme",
    "phone": "+254700000000",
    "email": "contact@testcompany.com",
    "country": "Kenya",
}


def _create_tenant(client, payload=None):
    payload = payload or TENANT_PAYLOAD
    resp = client.post("/api/v1/tenants/", json=payload)
    assert resp.status_code == 201, resp.text
    return resp.json()


def test_list_tenants_empty(client):
    resp = client.get("/api/v1/tenants/")
    assert resp.status_code == 200
    assert isinstance(resp.json(), list)


def test_create_tenant(client):
    data = _create_tenant(client)
    assert data["name"] == TENANT_PAYLOAD["name"]
    assert data["slug"] == TENANT_PAYLOAD["slug"]
    assert data["tenant_type"] == "sme"
    assert "id" in data


def test_get_tenant_by_id(client):
    tenant = _create_tenant(client)
    resp = client.get(f"/api/v1/tenants/{tenant['id']}")
    assert resp.status_code == 200
    assert resp.json()["id"] == tenant["id"]


def test_get_tenant_not_found(client):
    resp = client.get("/api/v1/tenants/99999")
    assert resp.status_code == 404


def test_update_tenant(client):
    tenant = _create_tenant(client)
    resp = client.put(f"/api/v1/tenants/{tenant['id']}", json={"country": "Uganda"})
    assert resp.status_code == 200
    assert resp.json()["country"] == "Uganda"


def test_delete_tenant(client):
    tenant = _create_tenant(client)
    resp = client.delete(f"/api/v1/tenants/{tenant['id']}")
    assert resp.status_code == 200
    assert client.get(f"/api/v1/tenants/{tenant['id']}").status_code == 404


def test_create_tenant_duplicate_slug(client):
    _create_tenant(client)
    resp = client.post("/api/v1/tenants/", json=TENANT_PAYLOAD)
    assert resp.status_code == 409


def test_create_tenant_invalid_type(client):
    payload = {**TENANT_PAYLOAD, "slug": "unique-slug", "tenant_type": "unknown"}
    resp = client.post("/api/v1/tenants/", json=payload)
    assert resp.status_code == 422
