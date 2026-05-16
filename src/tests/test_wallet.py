"""Tests for MTN wallet top-up integration helpers."""
from app.api.v1 import wallet
from app.schemas.marketplace_schemas import WalletTopupRequest
from fastapi import HTTPException


class MockResponse:
    def __init__(self, status_code, json_data=None, text=""):
        self.status_code = status_code
        self._json_data = json_data or {}
        self.text = text

    def json(self):
        return self._json_data


class MockClient:
    def __init__(self, responses, calls):
        self._responses = list(responses)
        self.calls = calls

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, tb):
        return False

    def post(self, url, headers=None, json=None):
        self.calls.append(
            {
                "url": url,
                "headers": headers or {},
                "json": json,
            }
        )
        return self._responses.pop(0)


def test_get_mtn_callback_host_uses_explicit_host_when_set(monkeypatch):
    monkeypatch.setenv("MTN_COLLECTION_CALLBACK_HOST", "callbacks.example.com")
    monkeypatch.setenv(
        "MTN_COLLECTION_CALLBACK_URL",
        "https://ignored.example.com/api/v1/wallet/callback",
    )

    assert wallet._get_mtn_callback_host() == "callbacks.example.com"


def test_process_mtn_payment_provisions_api_user(monkeypatch):
    base_url = "https://sandbox.momodeveloper.mtn.com"
    monkeypatch.setenv(
        "MTN_COLLECTION_PRIMARY_SUBSCRIPTION_KEY",
        "primary-key",
    )
    monkeypatch.delenv(
        "MTN_COLLECTION_SECONDARY_SUBSCRIPTION_KEY",
        raising=False,
    )
    monkeypatch.delenv("MTN_COLLECTION_SUBSCRIPTION_KEY", raising=False)
    monkeypatch.delenv("MTN_COLLECTION_USER_ID", raising=False)
    monkeypatch.delenv("MTN_COLLECTION_API_KEY", raising=False)
    monkeypatch.setenv(
        "MTN_COLLECTION_CALLBACK_URL",
        "https://merchant.example.com/api/v1/wallet/callback",
    )
    monkeypatch.setenv("MTN_COLLECTION_BASE_URL", base_url)

    calls = []
    fake_client = MockClient(
        [
            MockResponse(201),
            MockResponse(201, {"apiKey": "generated-key"}),
            MockResponse(200, {"access_token": "access-token"}),
            MockResponse(202),
        ],
        calls,
    )
    monkeypatch.setattr(wallet.httpx, "Client", lambda timeout: fake_client)

    reference_id = wallet._process_mtn_payment(
        WalletTopupRequest(
            amount=2,
            payment_method="mtn",
            reference="256700000001",
        )
    )

    assert reference_id
    assert calls[0]["url"] == f"{base_url}/v1_0/apiuser"
    assert calls[0]["headers"]["Ocp-Apim-Subscription-Key"] == "primary-key"
    assert calls[0]["json"] == {"providerCallbackHost": "merchant.example.com"}
    assert calls[1]["url"].endswith(
        f"/v1_0/apiuser/{calls[0]['headers']['X-Reference-Id']}/apikey"
    )
    assert calls[2]["url"] == f"{base_url}/collection/token/"
    assert calls[2]["headers"]["Authorization"].startswith("Basic ")
    assert calls[3]["url"] == f"{base_url}/collection/v1_0/requesttopay"
    assert calls[3]["headers"]["Ocp-Apim-Subscription-Key"] == "primary-key"
    assert calls[3]["json"]["amount"] == "2000"
    assert calls[3]["json"]["payer"]["partyId"] == "256700000001"


def test_process_mtn_payment_requires_callback_host(monkeypatch):
    monkeypatch.setenv(
        "MTN_COLLECTION_PRIMARY_SUBSCRIPTION_KEY",
        "primary-key",
    )
    monkeypatch.delenv("MTN_COLLECTION_CALLBACK_HOST", raising=False)
    monkeypatch.delenv("MTN_COLLECTION_CALLBACK_URL", raising=False)
    monkeypatch.delenv("MTN_COLLECTION_USER_ID", raising=False)
    monkeypatch.delenv("MTN_COLLECTION_API_KEY", raising=False)

    try:
        wallet._process_mtn_payment(
            WalletTopupRequest(
                amount=1,
                payment_method="mtn",
                reference="256700000003",
            )
        )
    except HTTPException as exc:
        assert exc.status_code == 503
        assert "MTN_COLLECTION_CALLBACK_HOST" in exc.detail
    else:
        raise AssertionError("Expected MTN callback host error")


def test_process_mtn_payment_retries_with_secondary_key(monkeypatch):
    base_url = "https://sandbox.momodeveloper.mtn.com/"
    normalized_base_url = base_url.rstrip("/")
    monkeypatch.setenv(
        "MTN_COLLECTION_PRIMARY_SUBSCRIPTION_KEY",
        "primary-key",
    )
    monkeypatch.setenv(
        "MTN_COLLECTION_SECONDARY_SUBSCRIPTION_KEY",
        "secondary-key",
    )
    monkeypatch.setenv("MTN_COLLECTION_USER_ID", "api-user")
    monkeypatch.setenv("MTN_COLLECTION_API_KEY", "api-key")
    monkeypatch.setenv("MTN_COLLECTION_BASE_URL", base_url)

    calls = []
    fake_client = MockClient(
        [
            MockResponse(401, text="unauthorized"),
            MockResponse(200, {"access_token": "access-token"}),
            MockResponse(202),
        ],
        calls,
    )
    monkeypatch.setattr(wallet.httpx, "Client", lambda timeout: fake_client)

    wallet._process_mtn_payment(
        WalletTopupRequest(
            amount=1,
            payment_method="mtn",
            reference="256700000002",
        )
    )

    request_to_pay_url = f"{normalized_base_url}/collection/v1_0/requesttopay"
    assert calls[0]["url"] == f"{normalized_base_url}/collection/token/"
    assert calls[0]["headers"]["Ocp-Apim-Subscription-Key"] == "primary-key"
    assert calls[1]["headers"]["Ocp-Apim-Subscription-Key"] == "secondary-key"
    assert calls[2]["url"] == request_to_pay_url
    assert calls[2]["headers"]["Ocp-Apim-Subscription-Key"] == "secondary-key"
