"""Wallet router – manage user wallet points.

Points are loaded via mobile money (MTN / Airtel) or card.
They are spent to purchase ad promotions.

Authentication: all endpoints require a valid JWT (Bearer token).
"""
import base64
import logging
import os
import time
import uuid
from typing import List
from urllib.parse import urlparse

import httpx
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import JWTError, jwt
from sqlalchemy.orm import Session

from app.database.database import get_db
from app.models.marketplace_models import UserWallet, WalletTransaction
from app.models.models import User

from app.schemas.marketplace_schemas import (  # isort: skip
    WalletResponse,
    WalletTopupRequest,
    WalletTransactionResponse,
)

router = APIRouter(prefix="/wallet", tags=["wallet"])

SECRET_KEY = os.getenv("SECRET_KEY", "change-me-in-production")
ALGORITHM = "HS256"
_bearer = HTTPBearer(auto_error=False)
POINT_UGX_VALUE = 1000

# Static fallback rates used only when live rate fetch fails.
# Last reviewed: 2026-05-16.
_STATIC_FX_TO_UGX = {
    "UGX": 1.0,
    "USD": 1 / 3750.0,  # 1 UGX ≈ 0.000267 USD (assuming 1 USD ≈ 3750 UGX)
    "EUR": 1 / 4050.0,  # 1 EUR ≈ 4050 UGX
    "KES": 1 / 29.0,  # 1 KES ≈ 29 UGX
    "TZS": 1 / 1.5,  # 1 TZS ≈ 1.5 UGX
    "RWF": 1 / 3.0,  # 1 RWF ≈ 3 UGX
    "AED": 1 / 1020.0,  # 1 AED ≈ 1020 UGX
    "GBP": 1 / 4800.0,  # 1 GBP ≈ 4800 UGX
}
_FX_CACHE_TTL_SECONDS = 3600
_FX_FALLBACK_CACHE_TTL_SECONDS = 300
_FX_API_URL = os.getenv("FX_API_URL", "https://open.er-api.com/v6/latest/UGX")
_FX_API_TIMEOUT_SECONDS = float(os.getenv("FX_API_TIMEOUT_SECONDS", "4.0"))
_MTN_API_TIMEOUT_SECONDS = float(os.getenv("MTN_API_TIMEOUT_SECONDS", "15.0"))
_fx_cache: dict[str, tuple[float, float]] = {}
_logger = logging.getLogger(__name__)
_MTN_AUTH_FAILURE_STATUS_CODES = {401, 403}


def _get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(_bearer),
    db: Session = Depends(get_db),
) -> User:
    if credentials is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Not authenticated",
        )
    try:
        payload = jwt.decode(
            credentials.credentials, SECRET_KEY, algorithms=[ALGORITHM]
        )
        user_id: str = payload.get("sub")
        if user_id is None:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Invalid token",
            )
    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token"
        )
    user = db.query(User).filter(User.id == int(user_id)).first()
    if not user:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND, detail="User not found"
        )
    return user


def _get_or_create_wallet(user_id: int, db: Session) -> UserWallet:
    wallet = db.query(UserWallet).filter(UserWallet.user_id == user_id).first()
    if wallet is None:
        wallet = UserWallet(user_id=user_id)
        db.add(wallet)
        db.commit()
        db.refresh(wallet)
    return wallet


def _fx_rate_from_ugx(currency: str) -> float:
    target = (currency or "UGX").upper()
    if target in _STATIC_FX_TO_UGX:
        return _STATIC_FX_TO_UGX[target]
    return _STATIC_FX_TO_UGX["UGX"]


def _live_fx_rate_from_ugx(currency: str) -> float:
    target = (currency or "UGX").upper()
    if target == "UGX":
        return 1.0
    cached = _fx_cache.get(target)
    now = time.time()
    if cached and cached[1] > now:
        return cached[0]
    try:
        with httpx.Client(timeout=_FX_API_TIMEOUT_SECONDS) as client:
            res = client.get(_FX_API_URL)
            res.raise_for_status()
            data = res.json()
            rates = data.get("rates") or {}
            rate = rates.get(target)
            if isinstance(rate, (int, float)) and rate > 0:
                parsed = float(rate)
                _fx_cache[target] = (parsed, now + _FX_CACHE_TTL_SECONDS)
                return parsed
    except Exception as exc:
        _logger.warning(
            "Live FX fetch failed for %s, using fallback: %s",
            target,
            exc,
        )
    fallback = _fx_rate_from_ugx(target)
    _fx_cache[target] = (fallback, now + _FX_FALLBACK_CACHE_TTL_SECONDS)
    return fallback


def _wallet_payload(wallet: UserWallet, display_currency: str) -> dict:
    currency = (display_currency or "UGX").upper()
    ugx_value = _points_to_ugx(int(wallet.points))
    rate = _live_fx_rate_from_ugx(currency)
    return {
        "id": wallet.id,
        "user_id": wallet.user_id,
        "points": wallet.points,
        "ugx_value": ugx_value,
        "display_currency": currency,
        "display_amount": round(ugx_value * rate, 2),
        "exchange_rate": rate,
        "created_at": wallet.created_at,
        "updated_at": wallet.updated_at,
    }


def _points_to_ugx(points: int) -> int:
    return points * POINT_UGX_VALUE


def _get_mtn_subscription_keys() -> list[str]:
    keys = [
        os.getenv("MTN_COLLECTION_PRIMARY_SUBSCRIPTION_KEY"),
        os.getenv("MTN_COLLECTION_SECONDARY_SUBSCRIPTION_KEY"),
        os.getenv("MTN_COLLECTION_SUBSCRIPTION_KEY"),
    ]
    resolved: list[str] = []
    for key in keys:
        if key and key not in resolved:
            resolved.append(key)
    return resolved


def _get_mtn_callback_host() -> str | None:
    callback_host = os.getenv("MTN_COLLECTION_CALLBACK_HOST")
    if callback_host:
        return callback_host
    callback_url = os.getenv("MTN_COLLECTION_CALLBACK_URL")
    if not callback_url:
        return None
    if "://" not in callback_url:
        return callback_url
    parsed = urlparse(callback_url)
    if parsed.hostname:
        return parsed.hostname
    return None


def _post_mtn_request(
    client: httpx.Client,
    url: str,
    subscription_keys: list[str],
    headers: dict[str, str] | None = None,
    json: dict | None = None,
) -> tuple[httpx.Response, str]:
    base_headers = headers or {}
    last_response: httpx.Response | None = None
    last_key = ""
    for index, subscription_key in enumerate(subscription_keys):
        response = client.post(
            url,
            headers={
                **base_headers,
                "Ocp-Apim-Subscription-Key": subscription_key,
            },
            json=json,
        )
        if (
            response.status_code in _MTN_AUTH_FAILURE_STATUS_CODES
            and index < len(subscription_keys) - 1
        ):
            _logger.warning(
                (
                    "MTN request to %s failed with subscription key #%s "
                    "(status=%s); retrying with fallback key"
                ),
                url,
                index + 1,
                response.status_code,
            )
            last_response = response
            last_key = subscription_key
            continue
        return response, subscription_key
    if last_response is None:
        raise RuntimeError("No MTN subscription keys available for request.")
    return last_response, last_key


def _provision_mtn_api_user(
    client: httpx.Client,
    base_url: str,
    subscription_keys: list[str],
    callback_host: str | None,
) -> tuple[str, str]:
    if not callback_host:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=(
                "MTN Mobile Money provisioning requires "
                "MTN_COLLECTION_CALLBACK_HOST or "
                "MTN_COLLECTION_CALLBACK_URL."
            ),
        )
    api_user = str(uuid.uuid4())
    user_res, active_key = _post_mtn_request(
        client,
        f"{base_url}/v1_0/apiuser",
        subscription_keys,
        headers={
            "Content-Type": "application/json",
            "X-Reference-Id": api_user,
        },
        json={"providerCallbackHost": callback_host},
    )
    if user_res.status_code >= 400:
        _logger.error(
            "MTN API user provisioning failed (status=%s): %s",
            user_res.status_code,
            user_res.text,
        )
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Failed to provision MTN Mobile Money API user.",
        )

    key_res = client.post(
        f"{base_url}/v1_0/apiuser/{api_user}/apikey",
        headers={
            "Content-Type": "application/json",
            "Ocp-Apim-Subscription-Key": active_key,
        },
    )
    if (
        key_res.status_code in _MTN_AUTH_FAILURE_STATUS_CODES
        and active_key != subscription_keys[-1]
    ):
        key_res, _ = _post_mtn_request(
            client,
            f"{base_url}/v1_0/apiuser/{api_user}/apikey",
            subscription_keys,
            headers={"Content-Type": "application/json"},
        )
    if key_res.status_code >= 400:
        _logger.error(
            "MTN API key generation failed (status=%s): %s",
            key_res.status_code,
            key_res.text,
        )
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="Failed to generate MTN Mobile Money API key.",
        )

    try:
        key_data = key_res.json()
    except ValueError as exc:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="MTN API key generation returned invalid JSON.",
        ) from exc
    api_key = key_data.get("apiKey") if isinstance(key_data, dict) else None
    if not api_key:
        raise HTTPException(
            status_code=status.HTTP_502_BAD_GATEWAY,
            detail="MTN API key generation returned no apiKey.",
        )
    return api_user, api_key


def _process_mtn_payment(payload: WalletTopupRequest) -> str:
    """Charge MTN Mobile Money using the MoMo Collection API."""
    api_user = os.getenv("MTN_COLLECTION_USER_ID")
    api_key = os.getenv("MTN_COLLECTION_API_KEY")
    target_env = os.getenv("MTN_COLLECTION_TARGET_ENV", "live")
    callback_url = os.getenv("MTN_COLLECTION_CALLBACK_URL")
    callback_host = _get_mtn_callback_host()
    base_url = os.getenv(
        "MTN_COLLECTION_BASE_URL", "https://momodeveloper.mtn.com"
    ).rstrip("/")
    subscription_keys = _get_mtn_subscription_keys()

    if not subscription_keys:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail=(
                "MTN Mobile Money is not configured. "
                "Set MTN_COLLECTION_PRIMARY_SUBSCRIPTION_KEY or "
                "MTN_COLLECTION_SECONDARY_SUBSCRIPTION_KEY."
            ),
        )
    if not payload.reference:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="MTN top-up requires a mobile number in `reference`.",
        )

    # MTN token endpoint expects HTTP Basic auth with API user id and API key.
    amount_ugx = _points_to_ugx(payload.amount)
    reference_id = str(uuid.uuid4())

    with httpx.Client(timeout=_MTN_API_TIMEOUT_SECONDS) as client:
        if not (api_user and api_key):
            api_user, api_key = _provision_mtn_api_user(
                client,
                base_url,
                subscription_keys,
                callback_host,
            )
        credentials = f"{api_user}:{api_key}".encode("utf-8")
        auth = base64.b64encode(credentials).decode("utf-8")
        token_res, subscription_key = _post_mtn_request(
            client,
            f"{base_url}/collection/token/",
            subscription_keys,
            headers={"Authorization": f"Basic {auth}"},
        )
        if token_res.status_code >= 400:
            _logger.error(
                "MTN token request failed (status=%s): %s",
                token_res.status_code,
                token_res.text,
            )
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="Failed to authenticate with MTN Mobile Money.",
            )
        token_data = token_res.json()
        access_token = token_data.get("access_token")
        if not access_token:
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="MTN payment authentication returned no access token.",
            )

        headers = {
            "Authorization": f"Bearer {access_token}",
            "X-Reference-Id": reference_id,
            "X-Target-Environment": target_env,
            "Ocp-Apim-Subscription-Key": subscription_key,
            "Content-Type": "application/json",
        }
        if callback_url:
            headers["X-Callback-Url"] = callback_url

        req_res = client.post(
            f"{base_url}/collection/v1_0/requesttopay",
            headers=headers,
            json={
                "amount": str(amount_ugx),
                "currency": "UGX",
                "externalId": f"wallet-topup-{reference_id[:8]}",
                "payer": {
                    "partyIdType": "MSISDN",
                    "partyId": payload.reference,
                },
                "payerMessage": "ORT wallet top-up",
                "payeeNote": f"Wallet top-up for {payload.amount} points",
            },
        )
        if req_res.status_code >= 400:
            _logger.error(
                "MTN request-to-pay failed (status=%s): %s",
                req_res.status_code,
                req_res.text,
            )
            raise HTTPException(
                status_code=status.HTTP_502_BAD_GATEWAY,
                detail="MTN request-to-pay failed.",
            )

    return reference_id


@router.get("/me", response_model=WalletResponse)
def get_my_wallet(
    currency: str = "UGX",
    current_user: User = Depends(_get_current_user),
    db: Session = Depends(get_db),
):
    """Return the current user's wallet balance."""
    wallet = _get_or_create_wallet(current_user.id, db)
    return _wallet_payload(wallet, currency)


@router.post(
    "/topup",
    response_model=WalletResponse,
    status_code=status.HTTP_200_OK,
)
def topup_wallet(
    payload: WalletTopupRequest,
    currency: str = "UGX",
    current_user: User = Depends(_get_current_user),
    db: Session = Depends(get_db),
):
    """Load wallet points via mobile money or card (1 point = 1,000 UGX)."""
    payment_reference = payload.reference
    if payload.payment_method == "mtn":
        payment_reference = _process_mtn_payment(payload)

    wallet = _get_or_create_wallet(current_user.id, db)
    wallet.points += payload.amount
    tx = WalletTransaction(
        wallet_id=wallet.id,
        transaction_type="topup",
        amount=payload.amount,
        payment_method=payload.payment_method,
        reference=payment_reference,
        description=(
            f"Top-up via {payload.payment_method.upper()} "
            f"({_points_to_ugx(payload.amount)} UGX)"
        ),
    )
    db.add(tx)
    db.commit()
    db.refresh(wallet)
    return _wallet_payload(wallet, currency)


@router.get("/transactions", response_model=List[WalletTransactionResponse])
def get_my_transactions(
    skip: int = 0,
    limit: int = 50,
    current_user: User = Depends(_get_current_user),
    db: Session = Depends(get_db),
):
    """Return the transaction history for the current user's wallet."""
    wallet_query = db.query(UserWallet).filter(  # noqa: E501
        UserWallet.user_id == current_user.id
    )
    wallet = wallet_query.first()
    if wallet is None:
        return []
    return (
        db.query(WalletTransaction)
        .filter(WalletTransaction.wallet_id == wallet.id)
        .order_by(WalletTransaction.created_at.desc())
        .offset(skip)
        .limit(limit)
        .all()
    )


@router.get("/user/{user_uid}", response_model=WalletResponse)
def get_wallet_by_uid(
    user_uid: str,
    currency: str = "UGX",
    current_user: User = Depends(_get_current_user),
    db: Session = Depends(get_db),
):
    """Look up another user's wallet by public UID.

    Only admins or the user themselves may call this.
    """
    target = db.query(User).filter(User.user_uid == user_uid).first()
    if not target:
        raise HTTPException(status_code=404, detail="User not found")
    if current_user.role != "admin" and current_user.id != target.id:
        raise HTTPException(status_code=403, detail="Access denied")
    wallet = _get_or_create_wallet(target.id, db)
    return _wallet_payload(wallet, currency)
