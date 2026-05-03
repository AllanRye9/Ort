"""JWT Authentication router."""
import hmac
import logging
import os
import re
from datetime import datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException, status
from passlib.context import CryptContext
from jose import jwt
from pydantic import BaseModel, Field
from sqlalchemy.exc import IntegrityError, DataError
from sqlalchemy.orm import Session

from app.database.database import get_db
from app.models.models import User
from app.models.marketplace_models import Tenant
from app.schemas.marketplace_schemas import (
    LoginRequest,
    TokenResponse,
    RegisterRequest,
    RegisterResponse,
)

router = APIRouter(prefix="/auth", tags=["auth"])

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

logger = logging.getLogger(__name__)

SECRET_KEY = os.getenv("SECRET_KEY", "change-me-in-production")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = int(os.getenv("ACCESS_TOKEN_EXPIRE_MINUTES", "60"))

_ADMIN_USER = (os.getenv("ADMIN_USER") or "").strip() or None
_ADMIN_PASSWORD = (os.getenv("ADMIN_PASSWORD") or "").strip() or None


def _create_access_token(data: dict) -> str:
    to_encode = data.copy()
    expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode["exp"] = expire
    return jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)


def _make_unique_slug(db: Session, base: str) -> str:
    """Return a URL-safe slug that is unique in the tenants table."""
    slug = re.sub(r"[^a-z0-9]+", "-", base.lower()).strip("-")[:97]
    if len(slug) < 3:
        slug = f"tenant-{slug}" if slug else "tenant"
    candidate = slug
    i = 1
    while db.query(Tenant).filter(Tenant.slug == candidate).first():
        candidate = f"{slug}-{i}"
        i += 1
    return candidate


@router.post("/login", response_model=TokenResponse)
def login(payload: LoginRequest, db: Session = Depends(get_db)):
    # ── ENV-var admin bypass ───────────────────────────────────────────────────
    # When ADMIN_USER and ADMIN_PASSWORD are configured, credentials matching
    # those env vars bypass the normal DB lookup and ensure an admin user exists.
    # hmac.compare_digest is used to prevent timing-based credential leaks.
    if (
        _ADMIN_USER
        and _ADMIN_PASSWORD
        and hmac.compare_digest(payload.email.lower(), _ADMIN_USER.lower())
        and hmac.compare_digest(payload.password, _ADMIN_PASSWORD)
    ):
        admin_user = db.query(User).filter(User.email == _ADMIN_USER).first()
        if admin_user is None:
            # First-time setup: create the admin user record.
            admin_user = User(
                role="admin",
                first_name="Admin",
                last_name="User",
                email=_ADMIN_USER,
                password_hash=pwd_context.hash(_ADMIN_PASSWORD),
            )
            db.add(admin_user)
            db.commit()
            db.refresh(admin_user)
            logger.info("Admin user created from ADMIN_USER env var")
        elif admin_user.role != "admin":
            admin_user.role = "admin"
            db.commit()
            db.refresh(admin_user)
        token = _create_access_token({"sub": str(admin_user.id), "role": "admin"})
        return TokenResponse(access_token=token, user_id=admin_user.id, role="admin")

    user = db.query(User).filter(User.email == payload.email).first()
    try:
        password_matches = user and pwd_context.verify(payload.password, user.password_hash)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Password is too long. Maximum 72 bytes allowed.",
        )
    if not password_matches:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid email or password",
        )
    token = _create_access_token({"sub": str(user.id), "role": user.role})
    return TokenResponse(access_token=token, user_id=user.id, role=user.role)


@router.post("/register", response_model=RegisterResponse, status_code=status.HTTP_201_CREATED)
def register(payload: RegisterRequest, db: Session = Depends(get_db)):
    """
    Unified registration endpoint.

    - **agent**: creates a User account only.
    - **company**: creates a User account and a Tenant with type ``sme``.
    - **organization**: creates a User account and a Tenant whose type is
      determined by ``org_type`` (ngo | government | enterprise | sme).
    """
    # Prevent duplicate emails
    if db.query(User).filter(User.email == payload.email).first():
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="An account with this email already exists",
        )

    # Create the user record. bcrypt raises ValueError if the password exceeds
    # 72 bytes; catch it here so the caller gets a 400 instead of a 500.
    try:
        password_hash = pwd_context.hash(payload.password)
    except ValueError:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Password is too long. Maximum 72 bytes allowed.",
        )

    db_user = User(
        role=payload.role,
        first_name=payload.first_name.strip(),
        last_name=payload.last_name.strip(),
        email=payload.email,
        phone=payload.phone,
        password_hash=password_hash,
        license_number=payload.license_number,
        agency_name=payload.agency_name,
        bio=payload.bio,
        nationality=payload.nationality,
        residing_country=payload.residing_country,
    )
    db.add(db_user)
    try:
        db.flush()  # populate db_user.id without committing yet
    except IntegrityError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="An account with this email already exists",
        )
    except DataError:
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="One or more field values are invalid (e.g. too long)",
        )
    except Exception:
        db.rollback()
        logger.exception("Unexpected error during user flush for %s", payload.email)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Registration failed due to a server error. Please try again.",
        )

    # Generate a stable unique public identifier based on the auto-increment PK.
    db_user.user_uid = f"ORT{db_user.id:06d}"

    # Create an empty wallet for the new user.
    from app.models.marketplace_models import UserWallet
    db_wallet = UserWallet(user_id=db_user.id)
    db.add(db_wallet)

    db_tenant = None
    if payload.role in ("company", "organization"):
        # Model validator guarantees company_name is set for these roles.
        if not payload.company_name:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="company_name is required for company and organization registration",
            )
        # Determine tenant_type
        if payload.role == "company":
            tenant_type = "sme"
        else:
            tenant_type = payload.org_type  # validated by schema

        slug = _make_unique_slug(db, payload.company_name)

        db_tenant = Tenant(
            owner_user_id=db_user.id,
            name=payload.company_name,
            slug=slug,
            tenant_type=tenant_type,
            phone=payload.business_phone or payload.phone,
            email=str(payload.business_email) if payload.business_email else payload.email,
            address=payload.address,
            country=payload.country,
        )
        db.add(db_tenant)
        try:
            db.flush()
        except (IntegrityError, DataError):
            db.rollback()
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Could not create the organisation record. Check the provided details.",
            )
        except Exception:
            db.rollback()
            logger.exception("Unexpected error during tenant flush for %s", payload.email)
            raise HTTPException(
                status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
                detail="Registration failed due to a server error. Please try again.",
            )

    try:
        db.commit()
    except (IntegrityError, DataError):
        db.rollback()
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Registration failed. Please check the provided information and try again.",
        )
    except Exception:
        db.rollback()
        logger.exception("Unexpected error during commit for %s", payload.email)
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Registration failed due to a server error. Please try again.",
        )

    return RegisterResponse(
        user_id=db_user.id,
        role=db_user.role,
        tenant_id=db_tenant.id if db_tenant else None,
        message="Registration successful",
    )


class AdminLoginRequest(BaseModel):
    username: str = Field(..., min_length=1)
    password: str = Field(..., min_length=1)


@router.post("/admin-login", response_model=TokenResponse)
def admin_login(payload: AdminLoginRequest, db: Session = Depends(get_db)):
    """Dedicated admin login endpoint that validates against ADMIN_USER / ADMIN_PASSWORD
    environment variables.  The username does not have to be an e-mail address.
    """
    if not _ADMIN_USER or not _ADMIN_PASSWORD:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Admin credentials are not configured on this server.",
        )
    credentials_ok = hmac.compare_digest(
        payload.username.lower(), _ADMIN_USER.lower()
    ) and hmac.compare_digest(payload.password, _ADMIN_PASSWORD)
    if not credentials_ok:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid admin credentials.",
        )
    # Use the env-var value as the admin e-mail; if it does not contain '@'
    # we synthesise a local-only address so the DB column stays consistent.
    admin_email = _ADMIN_USER if "@" in _ADMIN_USER else f"{_ADMIN_USER}@ort.admin"
    admin_user = db.query(User).filter(User.email == admin_email).first()
    if admin_user is None:
        admin_user = User(
            role="admin",
            first_name="Admin",
            last_name="User",
            email=admin_email,
            password_hash=pwd_context.hash(_ADMIN_PASSWORD),
        )
        db.add(admin_user)
        db.commit()
        db.refresh(admin_user)
        logger.info("Admin user created from ADMIN_USER env var: %s", admin_email)
    elif admin_user.role != "admin":
        admin_user.role = "admin"
        db.commit()
        db.refresh(admin_user)
    token = _create_access_token({"sub": str(admin_user.id), "role": "admin"})
    return TokenResponse(access_token=token, user_id=admin_user.id, role="admin")
