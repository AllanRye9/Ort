"""Manufacturing / wholesale products router."""
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session
from typing import List, Optional

from app.database.database import get_db
from app.models.marketplace_models import ManufacturingProduct
from app.schemas.marketplace_schemas import (
    ManufacturingProductCreate,
    ManufacturingProductUpdate,
    ManufacturingProductResponse,
)

router = APIRouter(prefix="/manufacturing", tags=["manufacturing"])


@router.get("/", response_model=List[ManufacturingProductResponse])
def list_products(
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
    q = db.query(ManufacturingProduct)
    if category:
        q = q.filter(ManufacturingProduct.category == category)
    if status:
        q = q.filter(ManufacturingProduct.status == status)
    if tenant_id:
        q = q.filter(ManufacturingProduct.tenant_id == tenant_id)
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
    return q.order_by(ManufacturingProduct.created_at.desc()).offset(skip).limit(limit).all()


@router.get("/{product_id}", response_model=ManufacturingProductResponse)
def get_product(product_id: int, db: Session = Depends(get_db)):
    obj = db.query(ManufacturingProduct).filter(ManufacturingProduct.id == product_id).first()
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
    obj = db.query(ManufacturingProduct).filter(ManufacturingProduct.id == product_id).first()
    if not obj:
        raise HTTPException(status_code=404, detail="Manufacturing product not found")
    db.delete(obj)
    db.commit()
    return {"message": "Manufacturing product deleted successfully"}
