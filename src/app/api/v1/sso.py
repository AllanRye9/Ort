"""SSO / OAuth2 endpoints (Google)."""
import logging
import secrets

from fastapi import APIRouter, HTTPException, status
from pydantic import BaseModel
import httpx

from app.models.models import User
from app.database.database import local_session
from app.api.v1.auth import _create_access_token, pwd_context

router = APIRouter(prefix="/auth/sso", tags=["sso"])
logger = logging.getLogger(__name__)

GOOGLE_TOKENINFO_URL = "https://oauth2.googleapis.com/tokeninfo"


class GoogleSSORequest(BaseModel):
    id_token: str


@router.post("/google")
async def google_sso(payload: GoogleSSORequest):
    """Verify a Google ID token and return a JWT access token.

    The Flutter client should sign in with Google, obtain an id_token from
    Firebase / Google Sign-In SDK, and POST it here.
    """
    async with httpx.AsyncClient(timeout=10) as client:
        resp = await client.get(
            GOOGLE_TOKENINFO_URL, params={"id_token": payload.id_token}
        )
    if resp.status_code != 200:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid Google ID token",
        )

    token_data = resp.json()
    email = token_data.get("email")
    if not email:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email not present in Google token",
        )

    db = local_session()
    try:
        user = db.query(User).filter(User.email == email).first()
        if not user:
            # Auto-register the user
            user = User(
                role="user",
                first_name=token_data.get("given_name", ""),
                last_name=token_data.get("family_name", ""),
                email=email,
                password_hash=pwd_context.hash(secrets.token_hex(32)),
            )
            db.add(user)
            db.commit()
            db.refresh(user)
        token = _create_access_token({"sub": str(user.id), "role": user.role})
        return {
            "access_token": token,
            "token_type": "bearer",
            "user_id": user.id,
            "role": user.role,
        }
    finally:
        db.close()
