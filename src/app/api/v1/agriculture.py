"""Agriculture listings router."""
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session
from typing import List, Optional

from app.database.database import get_db
from app.dependencies import get_current_user
from app.models.models import User
from app.models.marketplace_models import AgricultureListing, Tenant
from app.schemas.marketplace_schemas import (
    AgricultureListingCreate,
    AgricultureListingUpdate,
    AgricultureListingResponse,
    AgriStatusUpdate,
)
from app.utils.geo import haversine_km

router = APIRouter(prefix="/agriculture", tags=["agriculture"])


@router.get("/", response_model=List[AgricultureListingResponse])
def list_listings(
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=1000),
    category: Optional[str] = Query(None),
    status: Optional[str] = Query(None),
    tenant_id: Optional[int] = Query(None),
    keyword: Optional[str] = Query(None),
    min_price: Optional[float] = Query(None),
    max_price: Optional[float] = Query(None),
    location: Optional[str] = Query(None),
    lat: Optional[float] = Query(None),
    lon: Optional[float] = Query(None),
    radius_km: Optional[float] = Query(None, gt=0),
    db: Session = Depends(get_db),
):
    q = db.query(AgricultureListing)
    if category:
        q = q.filter(AgricultureListing.category == category)
    if status:
        q = q.filter(AgricultureListing.status == status)
    elif lat is not None and lon is not None and radius_km is not None:
        # Default to available-only when doing a geo search
        q = q.filter(AgricultureListing.status == "available")
    if tenant_id:
        q = q.filter(AgricultureListing.tenant_id == tenant_id)
    if keyword:
        like = f"%{keyword}%"
        q = q.filter(
            (AgricultureListing.title.ilike(like)) |
            (AgricultureListing.commodity_type.ilike(like))
        )
    if min_price is not None:
        q = q.filter(AgricultureListing.price_per_unit >= min_price)
    if max_price is not None:
        q = q.filter(AgricultureListing.price_per_unit <= max_price)
    if location:
        q = q.filter(AgricultureListing.location.ilike(f"%{location}%"))

    items = q.order_by(AgricultureListing.created_at.desc()).offset(skip).limit(limit).all()

    # Apply in-memory geo radius filter + sort by distance
    if lat is not None and lon is not None and radius_km is not None:
        with_dist = []
        for item in items:
            if item.latitude is not None and item.longitude is not None:
                d = haversine_km(lat, lon, item.latitude, item.longitude)
                if d <= radius_km:
                    with_dist.append((d, item))
        with_dist.sort(key=lambda x: x[0])
        items = [i for _, i in with_dist]

    return items



@router.patch("/{listing_id}/status", response_model=AgricultureListingResponse)
def update_listing_status(
    listing_id: int,
    payload: AgriStatusUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    obj = db.query(AgricultureListing).filter(AgricultureListing.id == listing_id).first()
    if not obj:
        raise HTTPException(status_code=404, detail="Agriculture listing not found")
    if obj.tenant_id is not None:
        tenant = db.query(Tenant).filter(Tenant.id == obj.tenant_id).first()
        if tenant is None or tenant.owner_user_id != current_user.id:
            raise HTTPException(status_code=403, detail="Not authorised to update this listing")
    obj.status = payload.status
    db.commit()
    db.refresh(obj)
    return obj


@router.get("/{listing_id}", response_model=AgricultureListingResponse)
def get_listing(listing_id: int, db: Session = Depends(get_db)):
    obj = db.query(AgricultureListing).filter(AgricultureListing.id == listing_id).first()
    if not obj:
        raise HTTPException(status_code=404, detail="Agriculture listing not found")
    return obj


@router.post("/", response_model=AgricultureListingResponse, status_code=status.HTTP_201_CREATED)
def create_listing(payload: AgricultureListingCreate, db: Session = Depends(get_db)):
    obj = AgricultureListing(**payload.model_dump())
    db.add(obj)
    db.commit()
    db.refresh(obj)
    return obj


@router.put("/{listing_id}", response_model=AgricultureListingResponse)
def update_listing(listing_id: int, payload: AgricultureListingUpdate, db: Session = Depends(get_db)):
    obj = db.query(AgricultureListing).filter(AgricultureListing.id == listing_id).first()
    if not obj:
        raise HTTPException(status_code=404, detail="Agriculture listing not found")
    for k, v in payload.model_dump(exclude_unset=True).items():
        setattr(obj, k, v)
    db.commit()
    db.refresh(obj)
    return obj


@router.delete("/{listing_id}", status_code=status.HTTP_200_OK)
def delete_listing(listing_id: int, db: Session = Depends(get_db)):
    obj = db.query(AgricultureListing).filter(AgricultureListing.id == listing_id).first()
    if not obj:
        raise HTTPException(status_code=404, detail="Agriculture listing not found")
    db.delete(obj)
    db.commit()
    return {"message": "Agriculture listing deleted successfully"}
