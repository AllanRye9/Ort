"""Ad Promotions router.

Agents, companies, and organisations pay wallet points to feature their
listings at hotspot position in the app for a chosen duration:
  - 7  days  → 10  points
  - 30 days  → 26  points
  - 365 days → 300 points

All endpoints require a valid JWT.
"""
import os
from datetime import datetime, timedelta, timezone
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import jwt, JWTError
from sqlalchemy.orm import Session

from app.database.database import get_db
from app.models.models import User
from app.models.marketplace_models import AdPromotion, UserWallet, WalletTransaction
from app.schemas.marketplace_schemas import (
    AdPromotionCreate,
    AdPromotionResponse,
    PROMOTION_PLANS,
)

router = APIRouter(prefix="/promotions", tags=["promotions"])

SECRET_KEY = os.getenv("SECRET_KEY", "change-me-in-production")
ALGORITHM = "HS256"
_bearer = HTTPBearer(auto_error=False)


def _get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(_bearer),
    db: Session = Depends(get_db),
) -> User:
    if credentials is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Not authenticated")
    try:
        payload = jwt.decode(credentials.credentials, SECRET_KEY, algorithms=[ALGORITHM])
        user_id: str = payload.get("sub")
        if user_id is None:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")
    except JWTError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")
    user = db.query(User).filter(User.id == int(user_id)).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    return user


@router.post("/", response_model=AdPromotionResponse, status_code=status.HTTP_201_CREATED)
def create_promotion(
    payload: AdPromotionCreate,
    current_user: User = Depends(_get_current_user),
    db: Session = Depends(get_db),
):
    """Purchase an ad promotion for a listing by spending wallet points."""
    cost = PROMOTION_PLANS[payload.duration_days]

    wallet = db.query(UserWallet).filter(UserWallet.user_id == current_user.id).first()
    if wallet is None or wallet.points < cost:
        raise HTTPException(
            status_code=status.HTTP_402_PAYMENT_REQUIRED,
            detail=f"Insufficient wallet points. Required: {cost}, available: {wallet.points if wallet else 0}",
        )

    now = datetime.now(timezone.utc)
    end_date = now + timedelta(days=payload.duration_days)

    promotion = AdPromotion(
        user_id=current_user.id,
        listing_type=payload.listing_type,
        listing_id=payload.listing_id,
        duration_days=payload.duration_days,
        cost_points=cost,
        start_date=now,
        end_date=end_date,
        status="active",
    )
    db.add(promotion)

    # Deduct points from wallet
    wallet.points -= cost
    tx = WalletTransaction(
        wallet_id=wallet.id,
        transaction_type="spend",
        amount=cost,
        description=f"Ad promotion: {payload.listing_type} #{payload.listing_id} for {payload.duration_days} days",
    )
    db.add(tx)
    db.commit()
    db.refresh(promotion)
    return promotion


@router.get("/", response_model=List[AdPromotionResponse])
def list_my_promotions(
    current_user: User = Depends(_get_current_user),
    db: Session = Depends(get_db),
):
    """List all promotions purchased by the current user."""
    _expire_old_promotions(db)
    return (
        db.query(AdPromotion)
        .filter(AdPromotion.user_id == current_user.id)
        .order_by(AdPromotion.created_at.desc())
        .all()
    )


@router.get("/active", response_model=List[AdPromotionResponse])
def list_active_promotions(
    listing_type: Optional[str] = Query(None),
    listing_id: Optional[int] = Query(None),
    db: Session = Depends(get_db),
):
    """Return currently active promotions (public endpoint).

    Optionally filter by listing_type and/or listing_id.
    """
    _expire_old_promotions(db)
    q = db.query(AdPromotion).filter(AdPromotion.status == "active")
    if listing_type:
        q = q.filter(AdPromotion.listing_type == listing_type)
    if listing_id is not None:
        q = q.filter(AdPromotion.listing_id == listing_id)
    return q.order_by(AdPromotion.start_date.desc()).all()


def _expire_old_promotions(db: Session) -> None:
    """Mark promotions whose end_date has passed as 'expired'."""
    now = datetime.now(timezone.utc)
    expired = (
        db.query(AdPromotion)
        .filter(AdPromotion.status == "active", AdPromotion.end_date < now)
        .all()
    )
    for p in expired:
        p.status = "expired"
    if expired:
        db.commit()
