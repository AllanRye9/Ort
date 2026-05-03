"""Product / order tracking router.

Agents, companies, and organisations post transit status updates.
Users read the timeline to see where their product/order is.
"""
from fastapi import APIRouter, Depends, HTTPException, Query, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import jwt, JWTError
import os
from sqlalchemy.orm import Session
from typing import List, Optional

from app.database.database import get_db
from app.models.marketplace_models import ProductTracking
from app.schemas.marketplace_schemas import (
    ProductTrackingCreate,
    ProductTrackingResponse,
)

router = APIRouter(prefix="/tracking", tags=["tracking"])

_SECRET_KEY = os.getenv("SECRET_KEY", "change-me-in-production")
_ALGORITHM = "HS256"
_bearer = HTTPBearer(auto_error=False)

_POSTER_ROLES = {"agent", "company", "organization", "admin"}


def _get_optional_user(
    credentials: HTTPAuthorizationCredentials = Depends(_bearer),
    db: Session = Depends(get_db),
):
    """Return (user_id, role) or (None, None) if unauthenticated."""
    if credentials is None:
        return None, None
    try:
        payload = jwt.decode(
            credentials.credentials, _SECRET_KEY, algorithms=[_ALGORITHM]
        )
        sub = payload.get("sub")
        role = payload.get("role")
        if sub is None:
            return None, None
        return int(sub), role
    except (JWTError, ValueError):
        return None, None


@router.get("/", response_model=List[ProductTrackingResponse])
def list_tracking_events(
    order_id: Optional[int] = Query(None),
    listing_type: Optional[str] = Query(None),
    listing_id: Optional[int] = Query(None),
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=500),
    db: Session = Depends(get_db),
):
    """Return tracking events for an order or a listing, ordered oldest first."""
    q = db.query(ProductTracking)
    if order_id is not None:
        q = q.filter(ProductTracking.order_id == order_id)
    if listing_type is not None:
        q = q.filter(ProductTracking.listing_type == listing_type)
    if listing_id is not None:
        q = q.filter(ProductTracking.listing_id == listing_id)
    return q.order_by(ProductTracking.created_at.asc()).offset(skip).limit(limit).all()


@router.post("/", response_model=ProductTrackingResponse, status_code=status.HTTP_201_CREATED)
def create_tracking_event(
    payload: ProductTrackingCreate,
    db: Session = Depends(get_db),
    user_info=Depends(_get_optional_user),
):
    """Post a new transit/status update for a product or order.

    Requires the caller to be authenticated as an agent, company, organisation,
    or admin.  Unauthenticated requests receive 401.
    """
    user_id, role = user_info
    if user_id is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Authentication required to post tracking updates.",
        )
    if role not in _POSTER_ROLES:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Only agents, companies, organisations, and admins can post tracking updates.",
        )
    if payload.order_id is None and (payload.listing_type is None or payload.listing_id is None):
        raise HTTPException(
            status_code=400,
            detail="Provide either order_id or both listing_type and listing_id.",
        )
    # Inject the authenticated user as the creator
    data = payload.model_dump()
    if data.get("created_by_user_id") is None:
        data["created_by_user_id"] = user_id
    event = ProductTracking(**data)
    db.add(event)
    db.commit()
    db.refresh(event)
    return event


@router.get("/{event_id}", response_model=ProductTrackingResponse)
def get_tracking_event(event_id: int, db: Session = Depends(get_db)):
    event = db.query(ProductTracking).filter(ProductTracking.id == event_id).first()
    if not event:
        raise HTTPException(status_code=404, detail="Tracking event not found")
    return event
