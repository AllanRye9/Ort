"""Firebase Cloud Messaging (FCM) push notification helper.

Requires the ``FIREBASE_SERVER_KEY`` environment variable (legacy FCM v1 key)
or ``FIREBASE_PROJECT_ID`` + ``FIREBASE_SERVICE_ACCOUNT_JSON`` for the newer
HTTP v1 API.

When no credentials are configured the helper silently skips sending so that
the application works without Firebase in development / CI environments.
"""
import json
import logging
import os
from typing import Optional

logger = logging.getLogger(__name__)

_FCM_LEGACY_KEY = (os.getenv("FIREBASE_SERVER_KEY") or "").strip() or None
_FCM_LEGACY_URL = "https://fcm.googleapis.com/fcm/send"


def _send_legacy(token: str, title: str, body: str, data: Optional[dict] = None) -> bool:
    """Send a push notification via the FCM legacy HTTP API.

    Returns True on success, False on failure.
    """
    try:
        import urllib.request

        payload = json.dumps({
            "to": token,
            "notification": {"title": title, "body": body, "sound": "default"},
            "data": data or {},
        }).encode()
        req = urllib.request.Request(
            _FCM_LEGACY_URL,
            data=payload,
            headers={
                "Authorization": f"key={_FCM_LEGACY_KEY}",
                "Content-Type": "application/json",
            },
            method="POST",
        )
        with urllib.request.urlopen(req, timeout=5) as resp:
            return resp.status == 200
    except Exception as exc:  # pragma: no cover
        logger.warning("FCM send error for token %s…: %s", token[:12], exc)
        return False


def send_push_notification(
    tokens: list[str],
    title: str,
    body: str,
    data: Optional[dict] = None,
) -> None:
    """Send a push notification to one or more FCM device tokens.

    Silently skips when ``FIREBASE_SERVER_KEY`` is not set.
    """
    if not _FCM_LEGACY_KEY:
        return
    if not tokens:
        return
    for token in tokens:
        _send_legacy(token, title, body, data)


def get_user_tokens(user_id: int, db) -> list[str]:
    """Return all active FCM device tokens for the given user."""
    from app.models.marketplace_models import UserDeviceToken
    rows = db.query(UserDeviceToken.token).filter(
        UserDeviceToken.user_id == user_id
    ).all()
    return [r.token for r in rows]


def notify_user(user_id: int, title: str, body: str, db, data: Optional[dict] = None) -> None:
    """Convenience wrapper: look up tokens and send a push notification."""
    tokens = get_user_tokens(user_id, db)
    send_push_notification(tokens, title, body, data)
