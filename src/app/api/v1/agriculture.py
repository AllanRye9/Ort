"""Agriculture listings router."""
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session
from typing import List, Optional

from app.database.database import get_db
from app.models.marketplace_models import AgricultureListing
from app.schemas.marketplace_schemas import (
    AgricultureListingCreate,
    AgricultureListingUpdate,
    AgricultureListingResponse,
)

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
    db: Session = Depends(get_db),
):
    q = db.query(AgricultureListing)
    if category:
        q = q.filter(AgricultureListing.category == category)
    if status:
        q = q.filter(AgricultureListing.status == status)
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
    return q.order_by(AgricultureListing.created_at.desc()).offset(skip).limit(limit).all()


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
