"""Role-specific dashboard endpoints."""
import logging
from datetime import datetime, timedelta

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session

from app.database.database import get_db
from app.models.models import User, Property
from app.models.marketplace_models import (
    AgricultureListing, ManufacturingProduct, Order,
    Conversation, Message, Notification,
)
from app.models.gamification_models import UserXP
from app.schemas.gamification_schemas import DashboardStats
from app.api.v1.api import _get_current_user

router = APIRouter(prefix="/dashboard", tags=["dashboard"])
logger = logging.getLogger(__name__)


def _get_xp(db: Session, user_id: int) -> dict:
    xp_record = db.query(UserXP).filter(UserXP.user_id == user_id).first()
    return {
        "xp_total": xp_record.xp_total if xp_record else 0,
        "level": xp_record.level if xp_record else 1,
    }


@router.get("/user", response_model=DashboardStats)
def user_dashboard(
    current_user: User = Depends(_get_current_user),
    db: Session = Depends(get_db),
):
    since = datetime.utcnow() - timedelta(days=7)
    recent_orders = (
        db.query(Order)
        .filter(Order.buyer_user_id == current_user.id)
        .filter(Order.created_at >= since)
        .limit(5)
        .all()
    )
    unread_msgs = (
        db.query(Message)
        .filter(Message.sender_id != current_user.id)
        .filter(Message.is_read == False)  # noqa: E712
        .limit(10)
        .all()
    )
    xp = _get_xp(db, current_user.id)
    return DashboardStats(
        role="user",
        user_id=current_user.id,
        stats={
            "total_orders": db.query(Order).filter(Order.buyer_user_id == current_user.id).count(),
            "unread_messages": len(unread_msgs),
        },
        recent_activity=[
            {"type": "order", "id": o.id, "status": o.status, "created_at": o.created_at.isoformat()}
            for o in recent_orders
        ],
        xp_total=xp["xp_total"],
        level=xp["level"],
    )


@router.get("/agent", response_model=DashboardStats)
def agent_dashboard(
    current_user: User = Depends(_get_current_user),
    db: Session = Depends(get_db),
):
    if current_user.role != "agent":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Agent role required")
    props = db.query(Property).filter(Property.agent_id == current_user.id).all()
    xp = _get_xp(db, current_user.id)
    return DashboardStats(
        role="agent",
        user_id=current_user.id,
        stats={
            "total_listings": len(props),
            "active_listings": sum(1 for p in props if p.status == "available"),
        },
        recent_activity=[
            {"type": "property", "id": p.id, "title": p.title, "status": p.status}
            for p in props[:5]
        ],
        xp_total=xp["xp_total"],
        level=xp["level"],
    )


@router.get("/company", response_model=DashboardStats)
def company_dashboard(
    current_user: User = Depends(_get_current_user),
    db: Session = Depends(get_db),
):
    if current_user.role not in ("company", "organization"):
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Company/organization role required")
    from app.models.marketplace_models import Tenant
    tenant = db.query(Tenant).filter(Tenant.owner_user_id == current_user.id).first()
    if not tenant:
        return DashboardStats(role=current_user.role, user_id=current_user.id, stats={}, recent_activity=[])

    orders = db.query(Order).filter(Order.seller_tenant_id == tenant.id).all()
    products = db.query(ManufacturingProduct).filter(ManufacturingProduct.tenant_id == tenant.id).all()
    agriculture = db.query(AgricultureListing).filter(AgricultureListing.tenant_id == tenant.id).all()
    xp = _get_xp(db, current_user.id)
    return DashboardStats(
        role=current_user.role,
        user_id=current_user.id,
        stats={
            "total_orders": len(orders),
            "pending_orders": sum(1 for o in orders if o.status == "pending"),
            "total_products": len(products) + len(agriculture),
            "revenue": float(sum(o.total_amount or 0 for o in orders if o.payment_status == "paid")),
        },
        recent_activity=[
            {"type": "order", "id": o.id, "status": o.status, "created_at": o.created_at.isoformat()}
            for o in sorted(orders, key=lambda x: x.created_at, reverse=True)[:5]
        ],
        xp_total=xp["xp_total"],
        level=xp["level"],
    )


@router.get("/organization", response_model=DashboardStats)
def organization_dashboard(
    current_user: User = Depends(_get_current_user),
    db: Session = Depends(get_db),
):
    # Organizations see same as company but with different label
    return company_dashboard(current_user=current_user, db=db)
