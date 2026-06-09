"""Service listings router — professional, technical, and general services."""
import secrets
import string
from datetime import datetime as _dt
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel, Field
from sqlalchemy import not_, or_
from sqlalchemy.orm import Session

from app.database.database import get_db
from app.dependencies import get_current_user
from app.models.models import User
from app.models.marketplace_models import ServiceListing, Tenant
from app.utils.geo import haversine_km

router = APIRouter(prefix="/services", tags=["services"])

_ALPHABET = string.ascii_uppercase + string.digits


# ──────────────────────────────────────────────────────────────────────────────
# Pydantic schemas (inline – no circular imports)
# ──────────────────────────────────────────────────────────────────────────────

class ServiceListingCreate(BaseModel):
    title: str = Field(..., min_length=3, max_length=255)
    description: Optional[str] = None
    category: str = Field(..., min_length=2, max_length=100)
    sub_category: Optional[str] = None
    service_mode: Optional[str] = None           # onsite | remote | hybrid
    price: Optional[float] = None
    price_currency: Optional[str] = "UGX"
    pricing_type: Optional[str] = "negotiable"   # fixed | negotiable | hourly | per_day | per_project
    pricing_notes: Optional[str] = None
    country: Optional[str] = None
    city: Optional[str] = None
    address: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    whatsapp_number: Optional[str] = None
    contact_email: Optional[str] = None
    website_url: Optional[str] = None
    google_maps_url: Optional[str] = None
    images: Optional[list] = None
    documents: Optional[list] = None
    tags: Optional[list] = None
    tenant_id: Optional[int] = None
    posted_by_user_id: Optional[int] = None
    status: Optional[str] = "active"

    class Config:
        from_attributes = True


class ServiceListingUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    category: Optional[str] = None
    sub_category: Optional[str] = None
    service_mode: Optional[str] = None
    price: Optional[float] = None
    price_currency: Optional[str] = None
    pricing_type: Optional[str] = None
    pricing_notes: Optional[str] = None
    country: Optional[str] = None
    city: Optional[str] = None
    address: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    whatsapp_number: Optional[str] = None
    contact_email: Optional[str] = None
    website_url: Optional[str] = None
    google_maps_url: Optional[str] = None
    images: Optional[list] = None
    documents: Optional[list] = None
    tags: Optional[list] = None
    status: Optional[str] = None
    is_flash_deal: Optional[bool] = None
    is_today_deal: Optional[bool] = None

    class Config:
        from_attributes = True


class ServiceListingResponse(BaseModel):
    id: int
    title: str
    description: Optional[str] = None
    category: str
    sub_category: Optional[str] = None
    service_mode: Optional[str] = None
    price: Optional[float] = None
    price_currency: Optional[str] = "UGX"
    pricing_type: str
    pricing_notes: Optional[str] = None
    country: Optional[str] = None
    city: Optional[str] = None
    address: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    whatsapp_number: Optional[str] = None
    contact_email: Optional[str] = None
    website_url: Optional[str] = None
    google_maps_url: Optional[str] = None
    images: Optional[list] = None
    documents: Optional[list] = None
    tags: Optional[list] = None
    tenant_id: Optional[int] = None
    posted_by_user_id: Optional[int] = None
    listing_code: Optional[str] = None
    status: str
    is_flash_deal: bool = False
    is_today_deal: bool = False
    is_verified: bool = False
    view_count: int = 0
    created_at: Optional[str] = None

    class Config:
        from_attributes = True

    @classmethod
    def from_orm(cls, obj: ServiceListing) -> "ServiceListingResponse":
        d = {
            "id": obj.id,
            "title": obj.title,
            "description": obj.description,
            "category": obj.category,
            "sub_category": obj.sub_category,
            "service_mode": obj.service_mode,
            "price": float(obj.price) if obj.price is not None else None,
            "price_currency": obj.price_currency or "UGX",
            "pricing_type": obj.pricing_type or "negotiable",
            "pricing_notes": obj.pricing_notes,
            "country": obj.country,
            "city": obj.city,
            "address": obj.address,
            "latitude": obj.latitude,
            "longitude": obj.longitude,
            "whatsapp_number": obj.whatsapp_number,
            "contact_email": obj.contact_email,
            "website_url": obj.website_url,
            "google_maps_url": obj.google_maps_url,
            "images": obj.images or [],
            "documents": obj.documents or [],
            "tags": obj.tags or [],
            "tenant_id": obj.tenant_id,
            "posted_by_user_id": obj.posted_by_user_id,
            "listing_code": obj.listing_code,
            "status": obj.status or "active",
            "is_flash_deal": obj.is_flash_deal or False,
            "is_today_deal": obj.is_today_deal or False,
            "is_verified": obj.is_verified or False,
            "view_count": obj.view_count or 0,
            "created_at": obj.created_at.isoformat() if obj.created_at else None,
        }
        return cls(**d)


# ──────────────────────────────────────────────────────────────────────────────
# Helpers
# ──────────────────────────────────────────────────────────────────────────────

def _generate_code(db: Session) -> str:
    year = _dt.now().year
    for _ in range(20):
        suffix = "".join(secrets.choice(_ALPHABET) for _ in range(6))
        code = f"ORT-SVC-{year}-{suffix}"
        if not db.query(ServiceListing).filter(ServiceListing.listing_code == code).first():
            return code
    return f"ORT-SVC-{year}-{''.join(secrets.choice(_ALPHABET) for _ in range(10))}"


# ──────────────────────────────────────────────────────────────────────────────
# CRUD Endpoints
# ──────────────────────────────────────────────────────────────────────────────

@router.get("/", response_model=List[ServiceListingResponse])
def list_services(
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=1000),
    category: Optional[str] = Query(None),
    status: Optional[str] = Query(None),
    tenant_id: Optional[int] = Query(None),
    posted_by_user_id: Optional[int] = Query(None),
    keyword: Optional[str] = Query(None),
    country: Optional[str] = Query(None),
    city: Optional[str] = Query(None),
    service_mode: Optional[str] = Query(None),
    min_price: Optional[float] = Query(None),
    max_price: Optional[float] = Query(None),
    is_flash_deal: Optional[bool] = Query(None),
    is_today_deal: Optional[bool] = Query(None),
    lat: Optional[float] = Query(None),
    lon: Optional[float] = Query(None),
    radius_km: Optional[float] = Query(None, gt=0),
    db: Session = Depends(get_db),
):
    q = db.query(ServiceListing).filter(ServiceListing.is_deleted == False)
    if category:
        q = q.filter(ServiceListing.category.ilike(f"%{category}%"))
    if status:
        q = q.filter(ServiceListing.status == status)
    if tenant_id:
        q = q.filter(ServiceListing.tenant_id == tenant_id)
    if posted_by_user_id is not None:
        q = q.filter(ServiceListing.posted_by_user_id == posted_by_user_id)
    if service_mode:
        q = q.filter(ServiceListing.service_mode == service_mode)
    if keyword:
        like = f"%{keyword}%"
        q = q.filter(
            (ServiceListing.title.ilike(like)) |
            (ServiceListing.description.ilike(like)) |
            (ServiceListing.category.ilike(like)) |
            (ServiceListing.city.ilike(like))
        )
    if min_price is not None:
        q = q.filter(ServiceListing.price >= min_price)
    if max_price is not None:
        q = q.filter(ServiceListing.price <= max_price)
    if country:
        q = q.filter(ServiceListing.country.ilike(f"%{country}%"))
    if city:
        q = q.filter(ServiceListing.city.ilike(f"%{city}%"))
    if is_flash_deal is not None:
        q = q.filter(ServiceListing.is_flash_deal == is_flash_deal)
    if is_today_deal is not None:
        q = q.filter(ServiceListing.is_today_deal == is_today_deal)

    items = q.order_by(ServiceListing.created_at.desc()).offset(skip).limit(limit).all()

    if lat is not None and lon is not None and radius_km is not None:
        filtered = []
        for it in items:
            if it.latitude is not None and it.longitude is not None:
                if haversine_km(lat, lon, it.latitude, it.longitude) <= radius_km:
                    filtered.append(it)
        items = filtered

    return [ServiceListingResponse.from_orm(i) for i in items]


@router.get("/{service_id}", response_model=ServiceListingResponse)
def get_service(service_id: int, db: Session = Depends(get_db)):
    item = db.query(ServiceListing).filter(
        ServiceListing.id == service_id, ServiceListing.is_deleted == False
    ).first()
    if not item:
        raise HTTPException(status_code=404, detail="Service listing not found")
    # Increment view count
    item.view_count = (item.view_count or 0) + 1
    db.commit()
    db.refresh(item)
    return ServiceListingResponse.from_orm(item)


@router.post("/", response_model=ServiceListingResponse, status_code=status.HTTP_201_CREATED)
def create_service(
    payload: ServiceListingCreate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    data = payload.model_dump()
    data["listing_code"] = _generate_code(db)
    data.setdefault("posted_by_user_id", current_user.id)
    item = ServiceListing(**data)
    db.add(item)
    db.commit()
    db.refresh(item)
    return ServiceListingResponse.from_orm(item)


@router.put("/{service_id}", response_model=ServiceListingResponse)
def update_service(
    service_id: int,
    payload: ServiceListingUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    item = db.query(ServiceListing).filter(
        ServiceListing.id == service_id, ServiceListing.is_deleted == False
    ).first()
    if not item:
        raise HTTPException(status_code=404, detail="Service listing not found")
    if current_user.role != "admin" and item.posted_by_user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Insufficient permissions")
    for k, v in payload.model_dump(exclude_unset=True).items():
        setattr(item, k, v)
    db.commit()
    db.refresh(item)
    return ServiceListingResponse.from_orm(item)


@router.delete("/{service_id}", status_code=status.HTTP_200_OK)
def delete_service(
    service_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    item = db.query(ServiceListing).filter(
        ServiceListing.id == service_id, ServiceListing.is_deleted == False
    ).first()
    if not item:
        raise HTTPException(status_code=404, detail="Service listing not found")
    if current_user.role != "admin" and item.posted_by_user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Insufficient permissions")
    item.is_deleted = True
    db.commit()
    return {"message": "Service listing deleted"}
