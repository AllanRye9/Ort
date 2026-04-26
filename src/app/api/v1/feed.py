"""Home feed endpoint with cursor-based pagination."""
import logging
from datetime import datetime
from typing import Optional

from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session

from app.database.database import get_db
from app.models.marketplace_models import (
    AgricultureListing, ManufacturingProduct,
)
from app.models.models import Property, User
from app.api.v1.api import _get_current_user

router = APIRouter(prefix="/feed", tags=["feed"])
logger = logging.getLogger(__name__)


@router.get("/")
def get_feed(
    after: Optional[str] = Query(None, description="Cursor: ISO datetime string"),
    limit: int = Query(20, ge=1, le=100),
    current_user: User = Depends(_get_current_user),
    db: Session = Depends(get_db),
):
    """Return a mixed feed of recent content (properties, agri listings, products).

    Cursor is an ISO-format datetime string. Items are returned newest-first.
    Response includes ``next_cursor`` for subsequent pages.
    """
    since = None
    if after:
        try:
            since = datetime.fromisoformat(after)
        except ValueError:
            since = None

    items = []

    # Properties
    q = db.query(Property).order_by(Property.created_at.desc())
    if since:
        q = q.filter(Property.created_at < since)
    for p in q.limit(limit).all():
        items.append({
            "type": "property",
            "id": p.id,
            "title": p.title,
            "price": float(p.price),
            "status": p.status,
            "city": p.city,
            "created_at": p.created_at.isoformat() if p.created_at else None,
        })

    # Agriculture listings
    q = db.query(AgricultureListing).order_by(AgricultureListing.created_at.desc())
    if since:
        q = q.filter(AgricultureListing.created_at < since)
    for a in q.limit(limit).all():
        images = a.images or []
        items.append({
            "type": "agriculture",
            "id": a.id,
            "title": a.title,
            "price": float(a.price_per_unit),
            "status": a.status,
            "category": a.category,
            "image_url": images[0] if images else None,
            "created_at": a.created_at.isoformat() if a.created_at else None,
        })

    # Manufacturing products
    q = db.query(ManufacturingProduct).order_by(ManufacturingProduct.created_at.desc())
    if since:
        q = q.filter(ManufacturingProduct.created_at < since)
    for m in q.limit(limit).all():
        images = m.images or []
        items.append({
            "type": "manufacturing",
            "id": m.id,
            "title": m.title,
            "price": float(m.wholesale_price),
            "status": m.status,
            "category": m.category,
            "image_url": images[0] if images else None,
            "created_at": m.created_at.isoformat() if m.created_at else None,
        })

    # Sort all items by created_at descending and take first `limit`
    items.sort(key=lambda x: x.get("created_at") or "", reverse=True)
    items = items[:limit]

    next_cursor = None
    if items:
        oldest = min(items, key=lambda x: x.get("created_at") or "")
        next_cursor = oldest.get("created_at")

    return {"items": items, "next_cursor": next_cursor, "count": len(items)}
