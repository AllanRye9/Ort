"""Manufacturing / wholesale products and services router."""
import secrets
import string
from datetime import datetime as _dt

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import not_
from sqlalchemy.orm import Session
from typing import List, Optional

from app.database.database import get_db
from app.dependencies import get_current_user
from app.models.models import User
from app.models.marketplace_models import ManufacturingProduct, ManufacturingService, Tenant
from app.schemas.marketplace_schemas import (
    ManufacturingProductCreate,
    ManufacturingProductUpdate,
    ManufacturingProductResponse,
    MfgStatusUpdate,
    ManufacturingServiceCreate,
    ManufacturingServiceUpdate,
    ManufacturingServiceResponse,
    MfgServiceStatusUpdate,
    OwnerProfileResponse,
)
from app.utils.countries import country_equals_clause
from app.utils.geo import haversine_km

router = APIRouter(prefix="/manufacturing", tags=["manufacturing"])

_ALPHABET = string.ascii_uppercase + string.digits


def _generate_mfg_listing_code(db: Session) -> str:
    year = _dt.now().year
    for _ in range(20):
        suffix = ''.join(secrets.choice(_ALPHABET) for _ in range(6))
        code = f"ORT-MFG-{year}-{suffix}"
        if not db.query(ManufacturingProduct).filter(ManufacturingProduct.listing_code == code).first():
            return code
    return f"ORT-MFG-{year}-{''.join(secrets.choice(_ALPHABET) for _ in range(10))}"


def _generate_svc_listing_code(db: Session) -> str:
    year = _dt.now().year
    for _ in range(20):
        suffix = ''.join(secrets.choice(_ALPHABET) for _ in range(6))
        code = f"ORT-SVC-{year}-{suffix}"
        if not db.query(ManufacturingService).filter(ManufacturingService.listing_code == code).first():
            return code
    return f"ORT-SVC-{year}-{''.join(secrets.choice(_ALPHABET) for _ in range(10))}"


def _enrich_product(obj: ManufacturingProduct) -> ManufacturingProductResponse:
    """Build a response with owner_profile populated from the owner relationship."""
    resp = ManufacturingProductResponse.model_validate(obj)
    if obj.owner is not None:
        resp.owner_profile = OwnerProfileResponse.model_validate(obj.owner)
    return resp


def _enrich_service(obj: ManufacturingService) -> ManufacturingServiceResponse:
    resp = ManufacturingServiceResponse.model_validate(obj)
    if obj.owner is not None:
        resp.owner_profile = OwnerProfileResponse.model_validate(obj.owner)
    return resp


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
    country: Optional[str] = Query(None),
    exclude_country: Optional[str] = Query(None),
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
    if country:
        country_clause = country_equals_clause(ManufacturingProduct.country_of_origin, country)
        if country_clause is not None:
            q = q.filter(country_clause)
    if exclude_country:
        exclude_clause = country_equals_clause(ManufacturingProduct.country_of_origin, exclude_country)
        if exclude_clause is not None:
            q = q.filter(
                (ManufacturingProduct.country_of_origin == None) |
                (not_(exclude_clause))
            )

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

    return [_enrich_product(i) for i in items]


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
    return _enrich_product(obj)


@router.get("/{product_id}", response_model=ManufacturingProductResponse)
def get_product(product_id: int, db: Session = Depends(get_db)):
    obj = db.query(ManufacturingProduct).filter(ManufacturingProduct.id == product_id, ManufacturingProduct.is_deleted == False).first()
    if not obj:
        raise HTTPException(status_code=404, detail="Manufacturing product not found")
    return _enrich_product(obj)


@router.post("/", response_model=ManufacturingProductResponse, status_code=status.HTTP_201_CREATED)
def create_product(payload: ManufacturingProductCreate, db: Session = Depends(get_db)):
    data = payload.model_dump()
    if not data.get("listing_code"):
        data["listing_code"] = _generate_mfg_listing_code(db)
    obj = ManufacturingProduct(**data)
    db.add(obj)
    db.commit()
    db.refresh(obj)

    creator_id = data.get("owner_user_id")
    if creator_id:
        try:
            from app.models.marketplace_models import Notification
            from app.utils.push import notify_user
            db.add(Notification(
                user_id=creator_id,
                title="Product Published ✅",
                body=f"Your product '{obj.name}' is now live.",
                notification_type="listing_created",
                reference_id=obj.id,
                reference_type="manufacturing",
            ))
            db.commit()
            notify_user(creator_id, "Product Published ✅",
                        f"Your product '{obj.name}' is now live.", db)
        except Exception:
            pass

    return _enrich_product(obj)


@router.put("/{product_id}", response_model=ManufacturingProductResponse)
def update_product(product_id: int, payload: ManufacturingProductUpdate, db: Session = Depends(get_db)):
    obj = db.query(ManufacturingProduct).filter(ManufacturingProduct.id == product_id).first()
    if not obj:
        raise HTTPException(status_code=404, detail="Manufacturing product not found")
    for k, v in payload.model_dump(exclude_unset=True).items():
        setattr(obj, k, v)
    db.commit()
    db.refresh(obj)
    return _enrich_product(obj)


@router.delete("/{product_id}", status_code=status.HTTP_200_OK)
def delete_product(
    product_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    obj = db.query(ManufacturingProduct).filter(ManufacturingProduct.id == product_id, ManufacturingProduct.is_deleted == False).first()
    if not obj:
        raise HTTPException(status_code=404, detail="Manufacturing product not found")
    if current_user.role != "admin":
        allowed = False
        if obj.tenant_id is not None:
            tenant = db.query(Tenant).filter(Tenant.id == obj.tenant_id).first()
            allowed = tenant is not None and tenant.owner_user_id == current_user.id
        elif obj.owner_user_id is not None:
            allowed = obj.owner_user_id == current_user.id
        if not allowed:
            raise HTTPException(
                status_code=403,
                detail="Insufficient permissions: only the creator or an admin can delete this product",
            )
    obj.is_deleted = True
    db.commit()
    return {"message": "Manufacturing product deleted successfully"}


# ─── Services ────────────────────────────────────────────────────────────────

services_router = APIRouter(prefix="/manufacturing/services", tags=["manufacturing-services"])


@services_router.get("/", response_model=List[ManufacturingServiceResponse])
def list_services(
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=1000),
    service_type: Optional[str] = Query(None),
    status: Optional[str] = Query(None),
    tenant_id: Optional[int] = Query(None),
    owner_user_id: Optional[int] = Query(None),
    keyword: Optional[str] = Query(None),
    min_price: Optional[float] = Query(None),
    max_price: Optional[float] = Query(None),
    lat: Optional[float] = Query(None),
    lon: Optional[float] = Query(None),
    radius_km: Optional[float] = Query(None, gt=0),
    country: Optional[str] = Query(None),
    exclude_country: Optional[str] = Query(None),
    db: Session = Depends(get_db),
):
    q = db.query(ManufacturingService).filter(ManufacturingService.is_deleted == False)
    if service_type:
        q = q.filter(ManufacturingService.service_type == service_type)
    if status:
        q = q.filter(ManufacturingService.status == status)
    elif lat is not None and lon is not None and radius_km is not None:
        q = q.filter(ManufacturingService.status == "available")
    if tenant_id:
        q = q.filter(ManufacturingService.tenant_id == tenant_id)
    if owner_user_id is not None:
        q = q.filter(ManufacturingService.owner_user_id == owner_user_id)
    if keyword:
        like = f"%{keyword}%"
        q = q.filter(
            (ManufacturingService.title.ilike(like)) |
            (ManufacturingService.service_type.ilike(like))
        )
    if min_price is not None:
        q = q.filter(ManufacturingService.price >= min_price)
    if max_price is not None:
        q = q.filter(ManufacturingService.price <= max_price)
    if country:
        country_clause = country_equals_clause(ManufacturingService.country, country)
        if country_clause is not None:
            q = q.filter(country_clause)
    if exclude_country:
        exclude_clause = country_equals_clause(ManufacturingService.country, exclude_country)
        if exclude_clause is not None:
            q = q.filter(
                (ManufacturingService.country.is_(None)) |
                (not_(exclude_clause))
            )

    items = q.order_by(ManufacturingService.created_at.desc()).offset(skip).limit(limit).all()

    if lat is not None and lon is not None and radius_km is not None:
        with_dist = []
        for item in items:
            if item.latitude is not None and item.longitude is not None:
                d = haversine_km(lat, lon, item.latitude, item.longitude)
                if d <= radius_km:
                    with_dist.append((d, item))
        with_dist.sort(key=lambda x: x[0])
        items = [i for _, i in with_dist]

    return [_enrich_service(i) for i in items]


@services_router.get("/{service_id}", response_model=ManufacturingServiceResponse)
def get_service(service_id: int, db: Session = Depends(get_db)):
    obj = db.query(ManufacturingService).filter(
        ManufacturingService.id == service_id,
        ManufacturingService.is_deleted == False,
    ).first()
    if not obj:
        raise HTTPException(status_code=404, detail="Manufacturing service not found")
    return _enrich_service(obj)


@services_router.post("/", response_model=ManufacturingServiceResponse, status_code=status.HTTP_201_CREATED)
def create_service(payload: ManufacturingServiceCreate, db: Session = Depends(get_db)):
    data = payload.model_dump()
    if not data.get("listing_code"):
        data["listing_code"] = _generate_svc_listing_code(db)
    obj = ManufacturingService(**data)
    db.add(obj)
    db.commit()
    db.refresh(obj)

    creator_id = data.get("owner_user_id")
    if creator_id:
        try:
            from app.models.marketplace_models import Notification
            from app.utils.push import notify_user
            db.add(Notification(
                user_id=creator_id,
                title="Service Published ✅",
                body=f"Your service '{obj.name}' is now live.",
                notification_type="listing_created",
                reference_id=obj.id,
                reference_type="manufacturing_service",
            ))
            db.commit()
            notify_user(creator_id, "Service Published ✅",
                        f"Your service '{obj.name}' is now live.", db)
        except Exception:
            pass

    return _enrich_service(obj)


@services_router.patch("/{service_id}/status", response_model=ManufacturingServiceResponse)
def update_service_status(
    service_id: int,
    payload: MfgServiceStatusUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    obj = db.query(ManufacturingService).filter(ManufacturingService.id == service_id).first()
    if not obj:
        raise HTTPException(status_code=404, detail="Manufacturing service not found")
    if obj.tenant_id is not None:
        tenant = db.query(Tenant).filter(Tenant.id == obj.tenant_id).first()
        if tenant is None or tenant.owner_user_id != current_user.id:
            raise HTTPException(status_code=403, detail="Not authorised to update this service")
    elif obj.owner_user_id is not None and obj.owner_user_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorised to update this service")
    obj.status = payload.status
    db.commit()
    db.refresh(obj)
    return _enrich_service(obj)


@services_router.put("/{service_id}", response_model=ManufacturingServiceResponse)
def update_service(service_id: int, payload: ManufacturingServiceUpdate, db: Session = Depends(get_db)):
    obj = db.query(ManufacturingService).filter(ManufacturingService.id == service_id).first()
    if not obj:
        raise HTTPException(status_code=404, detail="Manufacturing service not found")
    for k, v in payload.model_dump(exclude_unset=True).items():
        setattr(obj, k, v)
    db.commit()
    db.refresh(obj)
    return _enrich_service(obj)


@services_router.delete("/{service_id}", status_code=status.HTTP_200_OK)
def delete_service(
    service_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    obj = db.query(ManufacturingService).filter(
        ManufacturingService.id == service_id,
        ManufacturingService.is_deleted == False,
    ).first()
    if not obj:
        raise HTTPException(status_code=404, detail="Manufacturing service not found")
    if current_user.role != "admin":
        allowed = False
        if obj.tenant_id is not None:
            tenant = db.query(Tenant).filter(Tenant.id == obj.tenant_id).first()
            allowed = tenant is not None and tenant.owner_user_id == current_user.id
        elif obj.owner_user_id is not None:
            allowed = obj.owner_user_id == current_user.id
        if not allowed:
            raise HTTPException(
                status_code=403,
                detail="Insufficient permissions: only the creator or an admin can delete this service",
            )
    obj.is_deleted = True
    db.commit()
    return {"message": "Manufacturing service deleted successfully"}
