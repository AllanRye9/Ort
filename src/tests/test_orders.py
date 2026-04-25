"""Tests for the /api/v1/orders endpoint."""
from decimal import Decimal

TENANT_PAYLOAD = {
    "name": "Seller Corp",
    "slug": "seller-corp",
    "tenant_type": "sme",
    "email": "seller@corp.com",
}


def _create_tenant(client):
    resp = client.post("/api/v1/tenants/", json=TENANT_PAYLOAD)
    assert resp.status_code == 201, resp.text
    return resp.json()


ORDER_ITEM = {
    "quantity": 10,
    "unit_price": "5.00",
}


def _build_order(seller_id):
    return {
        "seller_tenant_id": seller_id,
        "currency": "USD",
        "items": [ORDER_ITEM],
    }


def test_list_orders_empty(client):
    resp = client.get("/api/v1/orders/")
    assert resp.status_code == 200
    assert isinstance(resp.json(), list)


def test_create_order(client):
    tenant = _create_tenant(client)
    resp = client.post("/api/v1/orders/", json=_build_order(tenant["id"]))
    assert resp.status_code == 201, resp.text
    data = resp.json()
    assert data["status"] == "pending"
    assert data["payment_status"] == "unpaid"
    assert data["currency"] == "USD"
    assert len(data["items"]) == 1
    assert data["order_number"].startswith("ORD-")


def test_get_order_by_id(client):
    tenant = _create_tenant(client)
    order = client.post("/api/v1/orders/", json=_build_order(tenant["id"])).json()
    resp = client.get(f"/api/v1/orders/{order['id']}")
    assert resp.status_code == 200
    assert resp.json()["id"] == order["id"]


def test_get_order_not_found(client):
    resp = client.get("/api/v1/orders/99999")
    assert resp.status_code == 404


def test_update_order_status(client):
    tenant = _create_tenant(client)
    order = client.post("/api/v1/orders/", json=_build_order(tenant["id"])).json()
    resp = client.put(f"/api/v1/orders/{order['id']}", json={"status": "confirmed"})
    assert resp.status_code == 200
    assert resp.json()["status"] == "confirmed"


def test_cancel_order(client):
    tenant = _create_tenant(client)
    order = client.post("/api/v1/orders/", json=_build_order(tenant["id"])).json()
    resp = client.delete(f"/api/v1/orders/{order['id']}")
    assert resp.status_code == 200
    updated = client.get(f"/api/v1/orders/{order['id']}").json()
    assert updated["status"] == "cancelled"


def test_order_total_calculated(client):
    tenant = _create_tenant(client)
    items = [
        {"quantity": 2, "unit_price": "10.00"},
        {"quantity": 5, "unit_price": "4.00"},
    ]
    payload = {"seller_tenant_id": tenant["id"], "items": items}
    resp = client.post("/api/v1/orders/", json=payload)
    assert resp.status_code == 201, resp.text
    data = resp.json()
    # 2*10 + 5*4 = 40
    assert Decimal(data["total_amount"]) == Decimal("40.00")
