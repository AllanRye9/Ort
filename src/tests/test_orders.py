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


BUYER_PAYLOAD = {
    "role": "user",
    "first_name": "Order",
    "last_name": "Buyer",
    "email": "order.buyer@example.com",
    "password": "TestPass1!",
}


def _create_product(client, tenant_id):
    payload = {
        "tenant_id": tenant_id,
        "title": "Order Test Product",
        "wholesale_price": "5.00",
        "quantity_available": 50,
        "unit": "pcs",
    }
    resp = client.post("/api/v1/manufacturing/", json=payload)
    assert resp.status_code == 201, resp.text
    return resp.json()


def _create_service(client, tenant_id):
    payload = {
        "tenant_id": tenant_id,
        "title": "Order Test Service",
        "price": "15.00",
        "service_type": "consultation",
    }
    resp = client.post("/api/v1/manufacturing/services/", json=payload)
    assert resp.status_code == 201, resp.text
    return resp.json()


def _build_order(seller_id, product_id):
    return {
        "seller_tenant_id": seller_id,
        "currency": "USD",
        "items": [
            {
                "manufacturing_product_id": product_id,
                "quantity": 10,
                "unit_price": "5.00",
            }
        ],
    }


def _create_user(client):
    resp = client.post("/api/v1/users/", json=BUYER_PAYLOAD)
    assert resp.status_code == 201, resp.text
    return resp.json()


def _auth_headers(client, email, password):
    resp = client.post("/api/v1/auth/login", json={"email": email, "password": password})
    assert resp.status_code == 200, resp.text
    return {"Authorization": f"Bearer {resp.json()['access_token']}"}


def test_list_orders_empty(client):
    resp = client.get("/api/v1/orders/")
    assert resp.status_code == 200
    assert isinstance(resp.json(), list)


def test_create_order(client):
    tenant = _create_tenant(client)
    product = _create_product(client, tenant["id"])
    resp = client.post("/api/v1/orders/", json=_build_order(tenant["id"], product["id"]))
    assert resp.status_code == 201, resp.text
    data = resp.json()
    assert data["status"] == "pending"
    assert data["payment_status"] == "unpaid"
    assert data["currency"] == "USD"
    assert len(data["items"]) == 1
    assert data["order_number"].startswith("ORD-")


def test_get_order_by_id(client):
    tenant = _create_tenant(client)
    product = _create_product(client, tenant["id"])
    order = client.post("/api/v1/orders/", json=_build_order(tenant["id"], product["id"])).json()
    resp = client.get(f"/api/v1/orders/{order['id']}")
    assert resp.status_code == 200
    assert resp.json()["id"] == order["id"]


def test_get_order_not_found(client):
    resp = client.get("/api/v1/orders/99999")
    assert resp.status_code == 404


def test_update_order_status(client):
    tenant = _create_tenant(client)
    product = _create_product(client, tenant["id"])
    order = client.post("/api/v1/orders/", json=_build_order(tenant["id"], product["id"])).json()
    resp = client.put(f"/api/v1/orders/{order['id']}", json={"status": "confirmed"})
    assert resp.status_code == 200
    assert resp.json()["status"] == "confirmed"


def test_cancel_order(client):
    buyer = _create_user(client)
    tenant = _create_tenant(client)
    product = _create_product(client, tenant["id"])
    order = client.post(
        "/api/v1/orders/",
        json={**_build_order(tenant["id"], product["id"]), "buyer_user_id": buyer["id"]},
    ).json()
    headers = _auth_headers(client, BUYER_PAYLOAD["email"], BUYER_PAYLOAD["password"])
    resp = client.delete(f"/api/v1/orders/{order['id']}", headers=headers)
    assert resp.status_code == 200
    updated = client.get(f"/api/v1/orders/{order['id']}").json()
    assert updated["status"] == "cancelled"


def test_order_total_calculated(client):
    tenant = _create_tenant(client)
    product = _create_product(client, tenant["id"])
    items = [
        {"manufacturing_product_id": product["id"], "quantity": 2, "unit_price": "10.00"},
        {"manufacturing_product_id": product["id"], "quantity": 5, "unit_price": "4.00"},
    ]
    payload = {"seller_tenant_id": tenant["id"], "items": items}
    resp = client.post("/api/v1/orders/", json=payload)
    assert resp.status_code == 201, resp.text
    data = resp.json()
    # 2*10 + 5*4 = 40
    assert Decimal(data["total_amount"]) == Decimal("40.00")


def test_create_order_with_service_item(client):
    tenant = _create_tenant(client)
    service = _create_service(client, tenant["id"])
    payload = {
        "seller_tenant_id": tenant["id"],
        "items": [
            {
                "manufacturing_service_id": service["id"],
                "quantity": 2,
                "unit_price": "15.00",
            }
        ],
    }
    resp = client.post("/api/v1/orders/", json=payload)
    assert resp.status_code == 201, resp.text
    data = resp.json()
    assert data["items"][0]["manufacturing_service_id"] == service["id"]


def test_create_order_creates_notifications_and_tracking(client):
    seller = client.post(
        "/api/v1/users/",
        json={
            "role": "agent",
            "first_name": "Seller",
            "last_name": "Owner",
            "email": "seller.owner@example.com",
            "password": "TestPass1!",
        },
    ).json()
    tenant_payload = {**TENANT_PAYLOAD, "slug": "seller-corp-owned", "owner_user_id": seller["id"]}
    tenant = client.post("/api/v1/tenants/", json=tenant_payload).json()
    product = _create_product(client, tenant["id"])
    buyer = _create_user(client)

    resp = client.post(
        "/api/v1/orders/",
        json={**_build_order(tenant["id"], product["id"]), "buyer_user_id": buyer["id"]},
    )
    assert resp.status_code == 201, resp.text
    order_id = resp.json()["id"]

    buyer_notifications = client.get(f"/api/v1/notifications/?user_id={buyer['id']}").json()
    assert any(n["reference_id"] == order_id and n["title"] == "Order Confirmed" for n in buyer_notifications)

    seller_notifications = client.get(f"/api/v1/notifications/?user_id={seller['id']}").json()
    assert any(n["reference_id"] == order_id and n["title"] == "New Order Placed" for n in seller_notifications)

    tracking = client.get(f"/api/v1/tracking/?order_id={order_id}").json()
    assert any(t["status"] == "order_placed" for t in tracking)
