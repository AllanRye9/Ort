"""Product / order tracking router.

Agents, companies, and organisations post transit status updates.
Users read the timeline to see where their product/order is.
"""
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session
from typing import List, Optional

from app.database.database import get_db
from app.models.marketplace_models import ProductTracking
from app.schemas.marketplace_schemas import (
    ProductTrackingCreate,
    ProductTrackingResponse,
)

router = APIRouter(prefix="/tracking", tags=["tracking"])


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
def create_tracking_event(payload: ProductTrackingCreate, db: Session = Depends(get_db)):
    """Post a new transit/status update for a product or order."""
    if payload.order_id is None and (payload.listing_type is None or payload.listing_id is None):
        raise HTTPException(
            status_code=400,
            detail="Provide either order_id or both listing_type and listing_id.",
        )
    event = ProductTracking(**payload.model_dump())
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
