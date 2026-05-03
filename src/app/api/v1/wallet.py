"""Wallet router – manage user wallet points.

Points are loaded via mobile money (MTN / Airtel) or card at a 1:1 cash ratio.
They are spent to purchase ad promotions.

Authentication: all endpoints require a valid JWT (Bearer token).
"""
import os
from typing import List

from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import jwt, JWTError
from sqlalchemy.orm import Session

from app.database.database import get_db
from app.models.models import User
from app.models.marketplace_models import UserWallet, WalletTransaction
from app.schemas.marketplace_schemas import (
    WalletResponse,
    WalletTopupRequest,
    WalletTransactionResponse,
)

router = APIRouter(prefix="/wallet", tags=["wallet"])

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


def _get_or_create_wallet(user_id: int, db: Session) -> UserWallet:
    wallet = db.query(UserWallet).filter(UserWallet.user_id == user_id).first()
    if wallet is None:
        wallet = UserWallet(user_id=user_id)
        db.add(wallet)
        db.commit()
        db.refresh(wallet)
    return wallet


@router.get("/me", response_model=WalletResponse)
def get_my_wallet(
    current_user: User = Depends(_get_current_user),
    db: Session = Depends(get_db),
):
    """Return the current user's wallet balance."""
    return _get_or_create_wallet(current_user.id, db)


@router.post("/topup", response_model=WalletResponse, status_code=status.HTTP_200_OK)
def topup_wallet(
    payload: WalletTopupRequest,
    current_user: User = Depends(_get_current_user),
    db: Session = Depends(get_db),
):
    """Load wallet points via mobile money or card (1 point = 1 cash unit).

    In this implementation the payment is assumed to have been collected
    externally; the endpoint simply credits the points and records the
    transaction.
    """
    wallet = _get_or_create_wallet(current_user.id, db)
    wallet.points += payload.amount
    tx = WalletTransaction(
        wallet_id=wallet.id,
        transaction_type="topup",
        amount=payload.amount,
        payment_method=payload.payment_method,
        reference=payload.reference,
        description=f"Top-up via {payload.payment_method}",
    )
    db.add(tx)
    db.commit()
    db.refresh(wallet)
    return wallet


@router.get("/transactions", response_model=List[WalletTransactionResponse])
def get_my_transactions(
    skip: int = 0,
    limit: int = 50,
    current_user: User = Depends(_get_current_user),
    db: Session = Depends(get_db),
):
    """Return the transaction history for the current user's wallet."""
    wallet = db.query(UserWallet).filter(UserWallet.user_id == current_user.id).first()
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
    current_user: User = Depends(_get_current_user),
    db: Session = Depends(get_db),
):
    """Look up another user's wallet by their public UID (e.g. for top-up gifts).
    Only admins or the user themselves may call this."""
    target = db.query(User).filter(User.user_uid == user_uid).first()
    if not target:
        raise HTTPException(status_code=404, detail="User not found")
    if current_user.role != "admin" and current_user.id != target.id:
        raise HTTPException(status_code=403, detail="Access denied")
    return _get_or_create_wallet(target.id, db)
