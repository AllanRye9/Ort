"""Tenant & Subscription router."""
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session
from typing import List

from app.database.database import get_db
from app.models.marketplace_models import Tenant, SubscriptionPlan, TenantSubscription
from app.schemas.marketplace_schemas import (
    TenantCreate, TenantUpdate, TenantResponse,
    SubscriptionPlanCreate, SubscriptionPlanResponse,
    TenantSubscriptionCreate, TenantSubscriptionResponse,
)

router = APIRouter(tags=["tenants"])


# ---- Tenants ----

@router.get("/tenants/", response_model=List[TenantResponse])
def list_tenants(
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=1000),
    db: Session = Depends(get_db),
):
    return db.query(Tenant).offset(skip).limit(limit).all()


@router.get("/tenants/{tenant_id}", response_model=TenantResponse)
def get_tenant(tenant_id: int, db: Session = Depends(get_db)):
    obj = db.query(Tenant).filter(Tenant.id == tenant_id).first()
    if not obj:
        raise HTTPException(status_code=404, detail="Tenant not found")
    return obj


@router.post("/tenants/", response_model=TenantResponse, status_code=status.HTTP_201_CREATED)
def create_tenant(payload: TenantCreate, db: Session = Depends(get_db)):
    if db.query(Tenant).filter(Tenant.slug == payload.slug).first():
        raise HTTPException(status_code=409, detail="Slug already in use")
    obj = Tenant(**payload.model_dump())
    db.add(obj)
    db.commit()
    db.refresh(obj)
    return obj


@router.put("/tenants/{tenant_id}", response_model=TenantResponse)
def update_tenant(tenant_id: int, payload: TenantUpdate, db: Session = Depends(get_db)):
    obj = db.query(Tenant).filter(Tenant.id == tenant_id).first()
    if not obj:
        raise HTTPException(status_code=404, detail="Tenant not found")
    for k, v in payload.model_dump(exclude_unset=True).items():
        setattr(obj, k, v)
    db.commit()
    db.refresh(obj)
    return obj


@router.delete("/tenants/{tenant_id}", status_code=status.HTTP_200_OK)
def delete_tenant(tenant_id: int, db: Session = Depends(get_db)):
    obj = db.query(Tenant).filter(Tenant.id == tenant_id).first()
    if not obj:
        raise HTTPException(status_code=404, detail="Tenant not found")
    db.delete(obj)
    db.commit()
    return {"message": "Tenant deleted successfully"}


# ---- Subscription Plans ----

@router.get("/subscription-plans/", response_model=List[SubscriptionPlanResponse])
def list_plans(db: Session = Depends(get_db)):
    return db.query(SubscriptionPlan).filter(SubscriptionPlan.is_active.is_(True)).all()


@router.get("/subscription-plans/{plan_id}", response_model=SubscriptionPlanResponse)
def get_plan(plan_id: int, db: Session = Depends(get_db)):
    obj = db.query(SubscriptionPlan).filter(SubscriptionPlan.id == plan_id).first()
    if not obj:
        raise HTTPException(status_code=404, detail="Plan not found")
    return obj


@router.post("/subscription-plans/", response_model=SubscriptionPlanResponse, status_code=status.HTTP_201_CREATED)
def create_plan(payload: SubscriptionPlanCreate, db: Session = Depends(get_db)):
    obj = SubscriptionPlan(**payload.model_dump())
    db.add(obj)
    db.commit()
    db.refresh(obj)
    return obj


# ---- Tenant Subscriptions ----

@router.get("/tenant-subscriptions/", response_model=List[TenantSubscriptionResponse])
def list_tenant_subscriptions(
    tenant_id: int = Query(...),
    db: Session = Depends(get_db),
):
    return db.query(TenantSubscription).filter(TenantSubscription.tenant_id == tenant_id).all()


@router.post(
    "/tenant-subscriptions/",
    response_model=TenantSubscriptionResponse,
    status_code=status.HTTP_201_CREATED,
)
def create_tenant_subscription(payload: TenantSubscriptionCreate, db: Session = Depends(get_db)):
    obj = TenantSubscription(**payload.model_dump())
    db.add(obj)
    db.commit()
    db.refresh(obj)
    return obj
