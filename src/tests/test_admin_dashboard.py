from datetime import datetime, timedelta

from app.models.marketplace_models import ProductTracking


def _register_admin_and_get_token(client):
    client.post(
        "/api/v1/auth/register",
        json={
            "role": "agent",
            "first_name": "Admin",
            "last_name": "User",
            "email": "admin@example.com",
            "password": "SecurePass1!",
        },
    )
    login = client.post(
        "/api/v1/auth/login",
        json={"email": "admin@example.com", "password": "SecurePass1!"},
    )
    assert login.status_code == 200, login.text
    return login.json()["access_token"]


def test_dashboard_location_analytics_returns_country_and_transitions(client, db_session):
    now = datetime.utcnow()
    db_session.add_all(
        [
            ProductTracking(
                listing_type="agriculture",
                listing_id=101,
                status="processing",
                location="Kampala, Uganda",
                created_at=now - timedelta(hours=2),
            ),
            ProductTracking(
                listing_type="agriculture",
                listing_id=101,
                status="in_transit",
                location="Jinja, Uganda",
                created_at=now - timedelta(hours=1),
            ),
            ProductTracking(
                listing_type="manufacturing",
                listing_id=202,
                status="delivered",
                location="Dubai, United Arab Emirates",
                created_at=now - timedelta(minutes=30),
            ),
        ]
    )
    db_session.commit()

    token = _register_admin_and_get_token(client)
    resp = client.get(
        "/api/v1/admin/dashboard/location-analytics?days=30&top_n=5",
        headers={"Authorization": f"Bearer {token}"},
    )
    assert resp.status_code == 200, resp.text
    data = resp.json()
    countries = {row["country"] for row in data["top_tracking_countries"]}
    assert "Uganda" in countries
    transitions = {
        (row["from_status"], row["to_status"]) for row in data["tracking_status_transitions"]
    }
    assert ("processing", "in_transit") in transitions
