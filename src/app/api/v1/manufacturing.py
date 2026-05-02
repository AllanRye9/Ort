"""Manufacturing / wholesale products router."""
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session
from typing import List, Optional

from app.database.database import get_db
from app.dependencies import get_current_user
from app.models.models import User
from app.models.marketplace_models import ManufacturingProduct, Tenant
from app.schemas.marketplace_schemas import (
    ManufacturingProductCreate,
    ManufacturingProductUpdate,
    ManufacturingProductResponse,
    MfgStatusUpdate,
)
from app.utils.geo import haversine_km

router = APIRouter(prefix="/manufacturing", tags=["manufacturing"])


@router.get("/", response_model=List[ManufacturingProductResponse])
def list_products(
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=1000),
    category: Optional[str] = Query(None),
    status: Optional[str] = Query(None),
    tenant_id: Optional[int] = Query(None),
    owner_user_id: Optional[int] = Query(None),
    keyword: Optional[str] = Query(None),
    min_price: Optional[float] = Query(None),
    max_price: Optional[float] = Query(None),
    location: Optional[str] = Query(None),
    lat: Optional[float] = Query(None),
    lon: Optional[float] = Query(None),
    radius_km: Optional[float] = Query(None, gt=0),
    db: Session = Depends(get_db),
):
    q = db.query(ManufacturingProduct).filter(ManufacturingProduct.is_deleted == False)
    if category:
        q = q.filter(ManufacturingProduct.category == category)
    if status:
        q = q.filter(ManufacturingProduct.status == status)
    elif lat is not None and lon is not None and radius_km is not None:
        q = q.filter(ManufacturingProduct.status == "available")
    if tenant_id:
        q = q.filter(ManufacturingProduct.tenant_id == tenant_id)
    if owner_user_id is not None:
        q = q.filter(ManufacturingProduct.owner_user_id == owner_user_id)
    if keyword:
        like = f"%{keyword}%"
        q = q.filter(
            (ManufacturingProduct.title.ilike(like)) |
            (ManufacturingProduct.category.ilike(like))
        )
    if min_price is not None:
        q = q.filter(ManufacturingProduct.wholesale_price >= min_price)
    if max_price is not None:
        q = q.filter(ManufacturingProduct.wholesale_price <= max_price)
    if location:
        q = q.filter(ManufacturingProduct.location.ilike(f"%{location}%"))

    items = q.order_by(ManufacturingProduct.created_at.desc()).offset(skip).limit(limit).all()

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


@router.patch("/{product_id}/status", response_model=ManufacturingProductResponse)
def update_product_status(
    product_id: int,
    payload: MfgStatusUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    obj = db.query(ManufacturingProduct).filter(ManufacturingProduct.id == product_id).first()
    if not obj:
        raise HTTPException(status_code=404, detail="Manufacturing product not found")
    if obj.tenant_id is not None:
        tenant = db.query(Tenant).filter(Tenant.id == obj.tenant_id).first()
        if tenant is None or tenant.owner_user_id != current_user.id:
            raise HTTPException(status_code=403, detail="Not authorised to update this product")
    elif obj.owner_user_id is not None and obj.owner_user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorised to update this product")
    obj.status = payload.status
    db.commit()
    db.refresh(obj)
    return obj


@router.get("/{product_id}", response_model=ManufacturingProductResponse)
def get_product(product_id: int, db: Session = Depends(get_db)):
    obj = db.query(ManufacturingProduct).filter(ManufacturingProduct.id == product_id, ManufacturingProduct.is_deleted == False).first()
    if not obj:
        raise HTTPException(status_code=404, detail="Manufacturing product not found")
    return obj


@router.post("/", response_model=ManufacturingProductResponse, status_code=status.HTTP_201_CREATED)
def create_product(payload: ManufacturingProductCreate, db: Session = Depends(get_db)):
    obj = ManufacturingProduct(**payload.model_dump())
    db.add(obj)
    db.commit()
    db.refresh(obj)
    return obj


@router.put("/{product_id}", response_model=ManufacturingProductResponse)
def update_product(product_id: int, payload: ManufacturingProductUpdate, db: Session = Depends(get_db)):
    obj = db.query(ManufacturingProduct).filter(ManufacturingProduct.id == product_id).first()
    if not obj:
        raise HTTPException(status_code=404, detail="Manufacturing product not found")
    for k, v in payload.model_dump(exclude_unset=True).items():
        setattr(obj, k, v)
    db.commit()
    db.refresh(obj)
    return obj


@router.delete("/{product_id}", status_code=status.HTTP_200_OK)
def delete_product(product_id: int, db: Session = Depends(get_db)):
    obj = db.query(ManufacturingProduct).filter(ManufacturingProduct.id == product_id, ManufacturingProduct.is_deleted == False).first()
    if not obj:
        raise HTTPException(status_code=404, detail="Manufacturing product not found")
    obj.is_deleted = True
    db.commit()
    return {"message": "Manufacturing product deleted successfully"}
