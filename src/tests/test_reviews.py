"""Tests for the /api/v1/reviews endpoints."""

USER_PAYLOAD = {
    "role": "agent",
    "first_name": "Rev",
    "last_name": "Viewer",
    "email": "reviewer@example.com",
    "password": "TestPass1!",
}
TENANT_PAYLOAD = {
    "name": "Reviewed Corp",
    "slug": "reviewed-corp",
    "tenant_type": "sme",
    "email": "reviewed@corp.com",
}


def _create_user(client):
    resp = client.post("/api/v1/users/", json=USER_PAYLOAD)
    assert resp.status_code == 201, resp.text
    return resp.json()


def _auth_headers(client, email, password):
    resp = client.post("/api/v1/auth/login", json={"email": email, "password": password})
    assert resp.status_code == 200, resp.text
    return {"Authorization": f"Bearer {resp.json()['access_token']}"}


def _create_tenant(client):
    resp = client.post("/api/v1/tenants/", json=TENANT_PAYLOAD)
    assert resp.status_code == 201, resp.text
    return resp.json()


def test_list_reviews_empty(client):
    resp = client.get("/api/v1/reviews/")
    assert resp.status_code == 200
    assert isinstance(resp.json(), list)


def test_create_review(client):
    user = _create_user(client)
    tenant = _create_tenant(client)
    payload = {
        "reviewer_id": user["id"],
        "reviewed_tenant_id": tenant["id"],
        "rating": 5,
        "title": "Great service",
        "body": "Very satisfied!",
    }
    resp = client.post("/api/v1/reviews/", json=payload)
    assert resp.status_code == 201, resp.text
    data = resp.json()
    assert data["rating"] == 5
    assert data["title"] == "Great service"


def test_get_review_by_id(client):
    user = _create_user(client)
    tenant = _create_tenant(client)
    review = client.post(
        "/api/v1/reviews/",
        json={"reviewer_id": user["id"], "reviewed_tenant_id": tenant["id"], "rating": 4},
    ).json()
    resp = client.get(f"/api/v1/reviews/{review['id']}")
    assert resp.status_code == 200
    assert resp.json()["id"] == review["id"]


def test_get_review_not_found(client):
    resp = client.get("/api/v1/reviews/99999")
    assert resp.status_code == 404


def test_review_rating_out_of_range(client):
    user = _create_user(client)
    payload = {"reviewer_id": user["id"], "rating": 10}
    resp = client.post("/api/v1/reviews/", json=payload)
    assert resp.status_code == 422


def test_delete_review(client):
    user = _create_user(client)
    tenant = _create_tenant(client)
    review = client.post(
        "/api/v1/reviews/",
        json={"reviewer_id": user["id"], "reviewed_tenant_id": tenant["id"], "rating": 3},
    ).json()
    headers = _auth_headers(client, USER_PAYLOAD["email"], USER_PAYLOAD["password"])
    resp = client.delete(f"/api/v1/reviews/{review['id']}", headers=headers)
    assert resp.status_code == 200
    assert client.get(f"/api/v1/reviews/{review['id']}").status_code == 404
