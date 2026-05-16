"""Tests for the /api/v1/auth endpoints (register & login)."""
import pytest


AGENT_PAYLOAD = {
    "role": "agent",
    "first_name": "Jane",
    "last_name": "Doe",
    "email": "jane.doe@example.com",
    "password": "SecurePass1!",
    "phone": "+2541234567890",
}

COMPANY_PAYLOAD = {
    "role": "company",
    "first_name": "Alice",
    "last_name": "Smith",
    "email": "alice@acme.com",
    "password": "SecurePass1!",
    "phone": "+2541111111111",
    "company_name": "Acme Corp",
}

ORG_PAYLOAD = {
    "role": "organization",
    "first_name": "Bob",
    "last_name": "Jones",
    "email": "bob@ngo.org",
    "password": "SecurePass1!",
    "company_name": "Help NGO",
    "org_type": "ngo",
}


# ---------------------------------------------------------------------------
# Registration
# ---------------------------------------------------------------------------

def test_register_agent(client):
    resp = client.post("/api/v1/auth/register", json=AGENT_PAYLOAD)
    assert resp.status_code == 201, resp.text
    data = resp.json()
    assert data["role"] == "agent"
    assert "user_id" in data
    assert data["tenant_id"] is None


def test_register_company(client):
    resp = client.post("/api/v1/auth/register", json=COMPANY_PAYLOAD)
    assert resp.status_code == 201, resp.text
    data = resp.json()
    assert data["role"] == "company"
    assert data["tenant_id"] is not None


def test_register_organization(client):
    resp = client.post("/api/v1/auth/register", json=ORG_PAYLOAD)
    assert resp.status_code == 201, resp.text
    data = resp.json()
    assert data["role"] == "organization"
    assert data["tenant_id"] is not None


def test_register_duplicate_email(client):
    client.post("/api/v1/auth/register", json=AGENT_PAYLOAD)
    resp = client.post("/api/v1/auth/register", json=AGENT_PAYLOAD)
    assert resp.status_code == 409


def test_register_duplicate_email_case_insensitive(client):
    client.post("/api/v1/auth/register", json=AGENT_PAYLOAD)
    resp = client.post(
        "/api/v1/auth/register",
        json={**AGENT_PAYLOAD, "email": "JANE.DOE@EXAMPLE.COM"},
    )
    assert resp.status_code == 409


def test_register_missing_company_name(client):
    payload = {**COMPANY_PAYLOAD, "email": "new@acme.com", "company_name": None}
    resp = client.post("/api/v1/auth/register", json=payload)
    assert resp.status_code == 422


def test_register_org_missing_org_type(client):
    payload = {**ORG_PAYLOAD, "email": "other@ngo.org", "org_type": None}
    resp = client.post("/api/v1/auth/register", json=payload)
    assert resp.status_code == 422


def test_register_invalid_role(client):
    payload = {**AGENT_PAYLOAD, "email": "bad@role.com", "role": "admin"}
    resp = client.post("/api/v1/auth/register", json=payload)
    assert resp.status_code == 422


def test_register_short_password(client):
    payload = {**AGENT_PAYLOAD, "email": "shortpwd@test.com", "password": "abc"}
    resp = client.post("/api/v1/auth/register", json=payload)
    assert resp.status_code == 422


# ---------------------------------------------------------------------------
# Login
# ---------------------------------------------------------------------------

def test_login_success(client):
    client.post("/api/v1/auth/register", json=AGENT_PAYLOAD)
    resp = client.post(
        "/api/v1/auth/login",
        json={"email": AGENT_PAYLOAD["email"], "password": AGENT_PAYLOAD["password"]},
    )
    assert resp.status_code == 200, resp.text
    data = resp.json()
    assert "access_token" in data
    assert data["token_type"] == "bearer"
    assert data["role"] == "agent"


def test_login_case_insensitive_email(client):
    client.post("/api/v1/auth/register", json=AGENT_PAYLOAD)
    resp = client.post(
        "/api/v1/auth/login",
        json={"email": "JANE.DOE@EXAMPLE.COM", "password": AGENT_PAYLOAD["password"]},
    )
    assert resp.status_code == 200, resp.text


def test_login_wrong_password(client):
    client.post("/api/v1/auth/register", json=AGENT_PAYLOAD)
    resp = client.post(
        "/api/v1/auth/login",
        json={"email": AGENT_PAYLOAD["email"], "password": "WrongPass!"},
    )
    assert resp.status_code == 401


def test_login_unknown_email(client):
    resp = client.post(
        "/api/v1/auth/login",
        json={"email": "nobody@nowhere.com", "password": "SomePass1!"},
    )
    assert resp.status_code == 401


def test_get_me_requires_auth(client):
    resp = client.get("/api/v1/users/me")
    assert resp.status_code == 401


def test_get_me_with_valid_token(client):
    client.post("/api/v1/auth/register", json=AGENT_PAYLOAD)
    login = client.post(
        "/api/v1/auth/login",
        json={"email": AGENT_PAYLOAD["email"], "password": AGENT_PAYLOAD["password"]},
    )
    token = login.json()["access_token"]
    resp = client.get("/api/v1/users/me", headers={"Authorization": f"Bearer {token}"})
    assert resp.status_code == 200
    assert resp.json()["email"] == AGENT_PAYLOAD["email"]
