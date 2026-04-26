"""JWT Authentication router."""
import logging
import os
import re
from datetime import datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException, status
from passlib.context import CryptContext
from jose import jwt
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
