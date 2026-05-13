"""Tests for the /api/v1/properties CRUD endpoints."""
from decimal import Decimal

PROPERTY_PAYLOAD = {
    "title": "Test House",
    "property_type": "house",
    "address": "123 Test Street",
    "city": "Nairobi",
    "price": "250000.00",
    "bedrooms": 3,
    "bathrooms": 2,
    "area_sqft": 1500,
}


def _create_property(client, payload=None):
    payload = payload or PROPERTY_PAYLOAD
    resp = client.post("/api/v1/properties/", json=payload)
    assert resp.status_code == 201, resp.text
    return resp.json()


def test_list_properties_empty(client):
    resp = client.get("/api/v1/properties/")
    assert resp.status_code == 200
    assert isinstance(resp.json(), list)


def test_create_property(client):
    data = _create_property(client)
    assert data["title"] == PROPERTY_PAYLOAD["title"]
    assert data["status"] == "available"
    assert data["pricing_type"] == "negotiable"
    assert "id" in data


def test_get_property_by_id(client):
    prop = _create_property(client)
    resp = client.get(f"/api/v1/properties/{prop['id']}")
    assert resp.status_code == 200
    assert resp.json()["id"] == prop["id"]


def test_get_property_not_found(client):
    resp = client.get("/api/v1/properties/99999")
    assert resp.status_code == 404


def test_update_property(client):
    prop = _create_property(client)
    resp = client.put(f"/api/v1/properties/{prop['id']}", json={"city": "Mombasa"})
    assert resp.status_code == 200
    assert resp.json()["city"] == "Mombasa"


def test_update_property_status(client):
    prop = _create_property(client)
    resp = client.put(f"/api/v1/properties/{prop['id']}", json={"status": "sold"})
    assert resp.status_code == 200
    assert resp.json()["status"] == "sold"


def test_delete_property(client):
    prop = _create_property(client)
    resp = client.delete(f"/api/v1/properties/{prop['id']}")
    assert resp.status_code == 200
    assert client.get(f"/api/v1/properties/{prop['id']}").status_code == 404


def test_create_property_invalid_type(client):
    payload = {**PROPERTY_PAYLOAD, "property_type": "mansion"}
    resp = client.post("/api/v1/properties/", json=payload)
    assert resp.status_code == 422
