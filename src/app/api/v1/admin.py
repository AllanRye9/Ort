"""Admin-only API router.

All endpoints require the caller to be authenticated with role == 'admin'.
"""
import logging
import os
from datetime import datetime, timedelta
from typing import List, Optional

from fastapi import APIRouter, Depends, HTTPException, Query, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import jwt, JWTError
from pydantic import BaseModel
from sqlalchemy import func
from sqlalchemy.orm import Session

from app.database.database import get_db
from app.models.models import (
    Appointment, Client, Inquiry, Payment,
    Property, PropertyImage, Transaction, User,
)
from app.models.marketplace_models import (
    AdminLog, AgricultureListing, ManufacturingProduct,
    Message, Notification, Order, SupportTicket, Tenant,
)

router = APIRouter(prefix="/admin", tags=["admin"])

logger = logging.getLogger(__name__)

SECRET_KEY = os.getenv("SECRET_KEY", "change-me-in-production")
ALGORITHM = "HS256"
_bearer = HTTPBearer(auto_error=False)


def _get_admin_user(
    credentials: HTTPAuthorizationCredentials = Depends(_bearer),
    db: Session = Depends(get_db),
) -> User:
    if credentials is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Not authenticated")
    try:
        payload = jwt.decode(credentials.credentials, SECRET_KEY, algorithms=[ALGORITHM])
        user_id: str = payload.get("sub")
        if user_id is None:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")
    except JWTError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")
    try:
        user_id = int(user_id)
    except ValueError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    if user.role != "admin":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin access required")
    return user


def _log_action(db: Session, admin: User, action: str, target_type: str = None, target_id: int = None, detail: str = None):
    """Add an audit log entry to the current session (does not commit)."""
    log = AdminLog(
        admin_id=admin.id,
        action=action,
        target_type=target_type,
        target_id=target_id,
        detail=detail,
    )
    db.add(log)


# ─── Schemas ──────────────────────────────────────────────────────────────────

class UserAdminUpdate(BaseModel):
    role: Optional[str] = None
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    phone: Optional[str] = None

class BroadcastNotificationRequest(BaseModel):
    title: str
    body: str
    target_role: Optional[str] = None  # None = all users

class TicketCreate(BaseModel):
    subject: str
    body: str

class TicketAdminUpdate(BaseModel):
    status: Optional[str] = None
    assigned_to: Optional[int] = None
    resolution: Optional[str] = None

class TicketReply(BaseModel):
    body: str


# ─── Dashboard ────────────────────────────────────────────────────────────────

@router.get("/dashboard/stats")
def get_dashboard_stats(
    admin: User = Depends(_get_admin_user),
    db: Session = Depends(get_db),
):
    """High-level metrics for the admin dashboard."""
    total_users = db.query(func.count(User.id)).scalar()
    users_by_role = {
        row[0]: row[1]
        for row in db.query(User.role, func.count(User.id)).group_by(User.role).all()
    }
    total_properties = db.query(func.count(Property.id)).scalar()
    total_tenants = db.query(func.count(Tenant.id)).scalar()
    total_orders = db.query(func.count(Order.id)).scalar()
    pending_orders = db.query(func.count(Order.id)).filter(Order.status == "pending").scalar()
    total_messages = db.query(func.count(Message.id)).scalar()
    open_tickets = db.query(func.count(SupportTicket.id)).filter(SupportTicket.status == "open").scalar()
    total_tickets = db.query(func.count(SupportTicket.id)).scalar()
    total_agriculture = db.query(func.count(AgricultureListing.id)).scalar()
    total_manufacturing = db.query(func.count(ManufacturingProduct.id)).scalar()

    # New users in the last 30 days
    thirty_days_ago = datetime.utcnow() - timedelta(days=30)
    new_users_30d = db.query(func.count(User.id)).filter(User.created_at >= thirty_days_ago).scalar()

    return {
        "total_users": total_users,
        "users_by_role": users_by_role,
        "new_users_last_30_days": new_users_30d,
        "total_properties": total_properties,
        "total_tenants": total_tenants,
        "total_orders": total_orders,
        "pending_orders": pending_orders,
        "total_messages": total_messages,
        "open_support_tickets": open_tickets,
        "total_support_tickets": total_tickets,
        "total_agriculture_listings": total_agriculture,
        "total_manufacturing_products": total_manufacturing,
    }


# ─── User Management ──────────────────────────────────────────────────────────

@router.get("/users/")
def admin_list_users(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
    role: Optional[str] = Query(None),
    search: Optional[str] = Query(None),
    admin: User = Depends(_get_admin_user),
    db: Session = Depends(get_db),
):
    """List all users with optional role filter and search."""
    q = db.query(User)
    if role:
        q = q.filter(User.role == role)
    if search:
        like = f"%{search}%"
        q = q.filter(
            (User.email.ilike(like)) |
            (User.first_name.ilike(like)) |
            (User.last_name.ilike(like))
        )
    total = q.count()
    users = q.offset(skip).limit(limit).all()
    return {
        "total": total,
        "users": [
            {
                "id": u.id,
                "role": u.role,
                "first_name": u.first_name,
                "last_name": u.last_name,
                "email": u.email,
                "phone": u.phone,
                "created_at": u.created_at,
                "agency_name": u.agency_name,
                "avatar_url": u.avatar_url,
            }
            for u in users
        ],
    }


@router.get("/users/{user_id}")
def admin_get_user(
    user_id: int,
    admin: User = Depends(_get_admin_user),
    db: Session = Depends(get_db),
):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return {
        "id": user.id,
        "role": user.role,
        "first_name": user.first_name,
        "last_name": user.last_name,
        "email": user.email,
        "phone": user.phone,
        "created_at": user.created_at,
        "agency_name": user.agency_name,
        "license_number": user.license_number,
        "bio": user.bio,
        "avatar_url": user.avatar_url,
    }


@router.patch("/users/{user_id}")
def admin_update_user(
    user_id: int,
    payload: UserAdminUpdate,
    admin: User = Depends(_get_admin_user),
    db: Session = Depends(get_db),
):
    """Update a user's role or profile fields."""
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    data = payload.model_dump(exclude_unset=True)
    for k, v in data.items():
        setattr(user, k, v)
    _log_action(db, admin, "update_user", "user", user_id, str(data))
    db.commit()
    db.refresh(user)
    return {"message": "User updated", "user_id": user_id}


@router.delete("/users/{user_id}")
def admin_delete_user(
    user_id: int,
    admin: User = Depends(_get_admin_user),
    db: Session = Depends(get_db),
):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    if user.id == admin.id:
        raise HTTPException(status_code=400, detail="Cannot delete your own admin account")
    db.delete(user)
    _log_action(db, admin, "delete_user", "user", user_id)
    db.commit()
    return {"message": "User deleted"}


# ─── Content Moderation ───────────────────────────────────────────────────────

@router.get("/content/properties/")
def admin_list_properties(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
    status_filter: Optional[str] = Query(None, alias="status"),
    admin: User = Depends(_get_admin_user),
    db: Session = Depends(get_db),
):
    q = db.query(Property)
    if status_filter:
        q = q.filter(Property.status == status_filter)
    total = q.count()
    props = q.offset(skip).limit(limit).all()
    return {
        "total": total,
        "properties": [
            {
                "id": p.id,
                "title": p.title,
                "city": p.city,
                "price": str(p.price),
                "status": p.status,
                "agent_id": p.agent_id,
                "created_at": p.created_at,
            }
            for p in props
        ],
    }


@router.patch("/content/properties/{property_id}/status")
def admin_update_property_status(
    property_id: int,
    new_status: str = Query(...),
    admin: User = Depends(_get_admin_user),
    db: Session = Depends(get_db),
):
    prop = db.query(Property).filter(Property.id == property_id).first()
    if not prop:
        raise HTTPException(status_code=404, detail="Property not found")
    prop.status = new_status
    _log_action(db, admin, "update_property_status", "property", property_id, new_status)
    db.commit()
    return {"message": "Property status updated", "status": new_status}


@router.delete("/content/properties/{property_id}")
def admin_delete_property(
    property_id: int,
    admin: User = Depends(_get_admin_user),
    db: Session = Depends(get_db),
):
    prop = db.query(Property).filter(Property.id == property_id).first()
    if not prop:
        raise HTTPException(status_code=404, detail="Property not found")
    db.delete(prop)
    _log_action(db, admin, "delete_property", "property", property_id)
    db.commit()
    return {"message": "Property deleted"}


@router.get("/content/agriculture/")
def admin_list_agriculture(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
    status_filter: Optional[str] = Query(None, alias="status"),
    admin: User = Depends(_get_admin_user),
    db: Session = Depends(get_db),
):
    q = db.query(AgricultureListing)
    if status_filter:
        q = q.filter(AgricultureListing.status == status_filter)
    total = q.count()
    items = q.offset(skip).limit(limit).all()
    return {
        "total": total,
        "listings": [
            {
                "id": i.id,
                "title": i.title,
                "category": i.category,
                "status": i.status,
                "tenant_id": i.tenant_id,
                "created_at": i.created_at,
            }
            for i in items
        ],
    }


@router.patch("/content/agriculture/{listing_id}/status")
def admin_update_agriculture_status(
    listing_id: int,
    new_status: str = Query(...),
    admin: User = Depends(_get_admin_user),
    db: Session = Depends(get_db),
):
    listing = db.query(AgricultureListing).filter(AgricultureListing.id == listing_id).first()
    if not listing:
        raise HTTPException(status_code=404, detail="Agriculture listing not found")
    listing.status = new_status
    _log_action(db, admin, "update_agriculture_status", "agriculture", listing_id, new_status)
    db.commit()
    return {"message": "Status updated", "status": new_status}


@router.get("/content/manufacturing/")
def admin_list_manufacturing(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
    status_filter: Optional[str] = Query(None, alias="status"),
    admin: User = Depends(_get_admin_user),
    db: Session = Depends(get_db),
):
    q = db.query(ManufacturingProduct)
    if status_filter:
        q = q.filter(ManufacturingProduct.status == status_filter)
    total = q.count()
    items = q.offset(skip).limit(limit).all()
    return {
        "total": total,
        "products": [
            {
                "id": i.id,
                "title": i.title,
                "category": i.category,
                "status": i.status,
                "tenant_id": i.tenant_id,
                "created_at": i.created_at,
            }
            for i in items
        ],
    }


@router.patch("/content/manufacturing/{product_id}/status")
def admin_update_manufacturing_status(
    product_id: int,
    new_status: str = Query(...),
    admin: User = Depends(_get_admin_user),
    db: Session = Depends(get_db),
):
    product = db.query(ManufacturingProduct).filter(ManufacturingProduct.id == product_id).first()
    if not product:
        raise HTTPException(status_code=404, detail="Product not found")
    product.status = new_status
    _log_action(db, admin, "update_manufacturing_status", "manufacturing", product_id, new_status)
    db.commit()
    return {"message": "Status updated", "status": new_status}


# ─── Media Management ─────────────────────────────────────────────────────────

@router.get("/media/images/")
def admin_list_images(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
    admin: User = Depends(_get_admin_user),
    db: Session = Depends(get_db),
):
    total = db.query(func.count(PropertyImage.id)).scalar()
    images = db.query(PropertyImage).offset(skip).limit(limit).all()
    return {
        "total": total,
        "images": [
            {
                "id": img.id,
                "property_id": img.property_id,
                "image_url": img.image_url,
                "is_primary": img.is_primary,
            }
            for img in images
        ],
    }


@router.delete("/media/images/bulk")
def admin_bulk_delete_images(
    image_ids: List[int],
    admin: User = Depends(_get_admin_user),
    db: Session = Depends(get_db),
):
    deleted = db.query(PropertyImage).filter(PropertyImage.id.in_(image_ids)).delete(synchronize_session=False)
    _log_action(db, admin, "bulk_delete_images", "image", None, f"deleted {deleted} of {len(image_ids)} images")
    db.commit()
    return {"message": f"Deleted {deleted} images"}


@router.delete("/media/images/{image_id}")
def admin_delete_image(
    image_id: int,
    admin: User = Depends(_get_admin_user),
    db: Session = Depends(get_db),
):
    image = db.query(PropertyImage).filter(PropertyImage.id == image_id).first()
    if not image:
        raise HTTPException(status_code=404, detail="Image not found")
    db.delete(image)
    _log_action(db, admin, "delete_image", "image", image_id)
    db.commit()
    return {"message": "Image deleted"}


# ─── Notifications / Broadcast ────────────────────────────────────────────────

@router.post("/notifications/broadcast")
def admin_broadcast_notification(
    payload: BroadcastNotificationRequest,
    admin: User = Depends(_get_admin_user),
    db: Session = Depends(get_db),
):
    """Send a broadcast notification to all users (or filtered by role)."""
    q = db.query(User.id)
    if payload.target_role:
        q = q.filter(User.role == payload.target_role)
    user_ids = [row[0] for row in q.all()]
    db.bulk_save_objects([
        Notification(
            user_id=uid,
            title=payload.title,
            body=payload.body,
            notification_type="broadcast",
        )
        for uid in user_ids
    ])
    _log_action(db, admin, "broadcast_notification", None, None, f"Sent to {len(user_ids)} users: {payload.title}")
    db.commit()
    return {"message": f"Notification sent to {len(user_ids)} users"}


# ─── Reports & Analytics ──────────────────────────────────────────────────────

@router.get("/reports/overview")
def admin_reports_overview(
    days: int = Query(30, ge=1, le=365),
    admin: User = Depends(_get_admin_user),
    db: Session = Depends(get_db),
):
    """Aggregate engagement metrics for the last N days."""
    since = datetime.utcnow() - timedelta(days=days)

    new_users = db.query(func.count(User.id)).filter(User.created_at >= since).scalar()
    new_properties = db.query(func.count(Property.id)).filter(Property.created_at >= since).scalar()
    new_orders = db.query(func.count(Order.id)).filter(Order.created_at >= since).scalar()
    # Message uses `sent_at` instead of `created_at`
    new_messages = db.query(func.count(Message.id)).filter(Message.sent_at >= since).scalar()
    new_agriculture = db.query(func.count(AgricultureListing.id)).filter(AgricultureListing.created_at >= since).scalar()
    new_manufacturing = db.query(func.count(ManufacturingProduct.id)).filter(ManufacturingProduct.created_at >= since).scalar()

    orders_by_status = {
        row[0]: row[1]
        for row in db.query(Order.status, func.count(Order.id)).group_by(Order.status).all()
    }

    return {
        "period_days": days,
        "new_users": new_users,
        "new_properties": new_properties,
        "new_orders": new_orders,
        "new_messages": new_messages,
        "new_agriculture_listings": new_agriculture,
        "new_manufacturing_products": new_manufacturing,
        "orders_by_status": orders_by_status,
    }


@router.get("/reports/users")
def admin_reports_users(
    days: int = Query(30, ge=1, le=365),
    admin: User = Depends(_get_admin_user),
    db: Session = Depends(get_db),
):
    """User registration trends broken down by role."""
    since = datetime.utcnow() - timedelta(days=days)
    registrations_by_role = {
        row[0]: row[1]
        for row in db.query(User.role, func.count(User.id))
        .filter(User.created_at >= since)
        .group_by(User.role)
        .all()
    }
    total_by_role = {
        row[0]: row[1]
        for row in db.query(User.role, func.count(User.id)).group_by(User.role).all()
    }
    return {
        "period_days": days,
        "registrations_by_role": registrations_by_role,
        "total_by_role": total_by_role,
    }


# ─── Audit / Admin Logs ───────────────────────────────────────────────────────

@router.get("/logs/")
def admin_get_logs(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
    admin: User = Depends(_get_admin_user),
    db: Session = Depends(get_db),
):
    total = db.query(func.count(AdminLog.id)).scalar()
    logs = db.query(AdminLog).order_by(AdminLog.created_at.desc()).offset(skip).limit(limit).all()
    return {
        "total": total,
        "logs": [
            {
                "id": log.id,
                "admin_id": log.admin_id,
                "action": log.action,
                "target_type": log.target_type,
                "target_id": log.target_id,
                "detail": log.detail,
                "created_at": log.created_at,
            }
            for log in logs
        ],
    }


# ─── Support Tickets ──────────────────────────────────────────────────────────

@router.get("/tickets/")
def admin_list_tickets(
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
    ticket_status: Optional[str] = Query(None, alias="status"),
    admin: User = Depends(_get_admin_user),
    db: Session = Depends(get_db),
):
    q = db.query(SupportTicket)
    if ticket_status:
        q = q.filter(SupportTicket.status == ticket_status)
    total = q.count()
    tickets = q.order_by(SupportTicket.created_at.desc()).offset(skip).limit(limit).all()
    return {
        "total": total,
        "tickets": [
            {
                "id": t.id,
                "user_id": t.user_id,
                "subject": t.subject,
                "status": t.status,
                "assigned_to": t.assigned_to,
                "created_at": t.created_at,
                "updated_at": t.updated_at,
            }
            for t in tickets
        ],
    }


@router.get("/tickets/{ticket_id}")
def admin_get_ticket(
    ticket_id: int,
    admin: User = Depends(_get_admin_user),
    db: Session = Depends(get_db),
):
    ticket = db.query(SupportTicket).filter(SupportTicket.id == ticket_id).first()
    if not ticket:
        raise HTTPException(status_code=404, detail="Ticket not found")
    return {
        "id": ticket.id,
        "user_id": ticket.user_id,
        "subject": ticket.subject,
        "body": ticket.body,
        "status": ticket.status,
        "resolution": ticket.resolution,
        "assigned_to": ticket.assigned_to,
        "created_at": ticket.created_at,
        "updated_at": ticket.updated_at,
    }


@router.patch("/tickets/{ticket_id}")
def admin_update_ticket(
    ticket_id: int,
    payload: TicketAdminUpdate,
    admin: User = Depends(_get_admin_user),
    db: Session = Depends(get_db),
):
    ticket = db.query(SupportTicket).filter(SupportTicket.id == ticket_id).first()
    if not ticket:
        raise HTTPException(status_code=404, detail="Ticket not found")
    data = payload.model_dump(exclude_unset=True)
    for k, v in data.items():
        setattr(ticket, k, v)
    _log_action(db, admin, "update_ticket", "ticket", ticket_id, str(data))
    db.commit()
    db.refresh(ticket)
    return {"message": "Ticket updated"}


# ─── User-facing ticket creation ──────────────────────────────────────────────

# Also expose a user-facing ticket creation endpoint (non-admin)
user_tickets_router = APIRouter(prefix="/tickets", tags=["support"])

_bearer_user = HTTPBearer(auto_error=False)


def _get_any_user(
    credentials: HTTPAuthorizationCredentials = Depends(_bearer_user),
    db: Session = Depends(get_db),
) -> User:
    if credentials is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Not authenticated")
    try:
        payload = jwt.decode(credentials.credentials, SECRET_KEY, algorithms=[ALGORITHM])
        user_id: str = payload.get("sub")
        if user_id is None:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")
    except JWTError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")
    try:
        user_id = int(user_id)
    except ValueError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    return user


@user_tickets_router.post("/", status_code=201)
def create_ticket(
    payload: TicketCreate,
    current_user: User = Depends(_get_any_user),
    db: Session = Depends(get_db),
):
    ticket = SupportTicket(
        user_id=current_user.id,
        subject=payload.subject,
        body=payload.body,
    )
    db.add(ticket)
    db.commit()
    db.refresh(ticket)
    return {"id": ticket.id, "subject": ticket.subject, "status": ticket.status}


@user_tickets_router.get("/mine")
def get_my_tickets(
    current_user: User = Depends(_get_any_user),
    db: Session = Depends(get_db),
):
    tickets = db.query(SupportTicket).filter(SupportTicket.user_id == current_user.id).all()
    return [
        {
            "id": t.id,
            "subject": t.subject,
            "status": t.status,
            "created_at": t.created_at,
        }
        for t in tickets
    ]


# ─── Gamification admin endpoints ─────────────────────────────────────────────
# These endpoints manage AI moderation queue, gamification analytics,
# badge management, and daily challenge CRUD using the gamification models.

from app.models.gamification_models import (
    AuditEvent, ImageRecord, Badge, UserBadge, DailyChallenge,
)
from app.schemas.gamification_schemas import (
    AuditEventResponse, EngagementStats, ChurnRiskUser,
)


def _write_audit(db: Session, actor_id: int, action: str, target_type: str = None,
                 target_id: int = None, metadata: dict = None):
    db.add(AuditEvent(
        actor_id=actor_id,
        action=action,
        target_type=target_type,
        target_id=target_id,
        metadata_json=metadata,
    ))
    db.commit()


@router.get("/moderation/images")
def moderation_queue(
    status_filter: str = Query("pending", pattern="^(pending|approved|rejected)$"),
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
    admin: User = Depends(_get_admin_user),
    db: Session = Depends(get_db),
):
    rows = (
        db.query(ImageRecord)
        .filter(ImageRecord.moderation_status == status_filter)
        .order_by(ImageRecord.created_at.asc())
        .offset(skip)
        .limit(limit)
        .all()
    )
    return [
        {
            "id": r.id,
            "url": r.url,
            "user_id": r.user_id,
            "moderation_status": r.moderation_status,
            "tags": r.tags,
            "created_at": r.created_at.isoformat() if r.created_at else None,
        }
        for r in rows
    ]


@router.patch("/moderation/images/{image_id}")
def update_moderation_status(
    image_id: int,
    new_status: str = Query(..., pattern="^(approved|rejected)$"),
    admin: User = Depends(_get_admin_user),
    db: Session = Depends(get_db),
):
    rec = db.query(ImageRecord).filter(ImageRecord.id == image_id).first()
    if not rec:
        raise HTTPException(status_code=404, detail="Image record not found")
    rec.moderation_status = new_status
    db.commit()
    _write_audit(db, admin.id, "moderation_update", "image_record", image_id,
                 {"new_status": new_status})
    return {"id": image_id, "moderation_status": new_status}


@router.get("/analytics/engagement", response_model=EngagementStats)
def engagement_stats(
    admin: User = Depends(_get_admin_user),
    db: Session = Depends(get_db),
):
    now = datetime.utcnow()
    day_ago = now - timedelta(days=1)
    month_ago = now - timedelta(days=30)
    new_users_day = db.query(User).filter(User.created_at >= day_ago).count()
    new_users_month = db.query(User).filter(User.created_at >= month_ago).count()
    uploads_today = db.query(ImageRecord).filter(ImageRecord.created_at >= day_ago).count()
    messages_today = db.query(Message).filter(Message.sent_at >= day_ago).count()
    return EngagementStats(
        dau=new_users_day,
        mau=new_users_month,
        uploads_today=uploads_today,
        messages_today=messages_today,
        new_users_today=new_users_day,
    )


@router.get("/analytics/churn-risk")
def churn_risk_users(
    inactive_days: int = Query(14, ge=1),
    admin: User = Depends(_get_admin_user),
    db: Session = Depends(get_db),
):
    cutoff = datetime.utcnow() - timedelta(days=inactive_days)
    users = db.query(User).filter(User.created_at < cutoff).limit(100).all()
    return [
        ChurnRiskUser(
            user_id=u.id,
            email=u.email,
            last_active=u.created_at,
            days_inactive=inactive_days,
        )
        for u in users
    ]


@router.get("/audit-events", response_model=List[AuditEventResponse])
def get_audit_events(
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=500),
    admin: User = Depends(_get_admin_user),
    db: Session = Depends(get_db),
):
    return (
        db.query(AuditEvent)
        .order_by(AuditEvent.created_at.desc())
        .offset(skip)
        .limit(limit)
        .all()
    )


@router.post("/gamification/badges")
def create_badge(
    name: str,
    description: str = None,
    icon_url: str = None,
    admin: User = Depends(_get_admin_user),
    db: Session = Depends(get_db),
):
    badge = Badge(name=name, description=description, icon_url=icon_url)
    db.add(badge)
    db.commit()
    db.refresh(badge)
    return {"id": badge.id, "name": badge.name}


@router.post("/gamification/badges/{badge_id}/award/{user_id}")
def award_badge(
    badge_id: int,
    user_id: int,
    admin: User = Depends(_get_admin_user),
    db: Session = Depends(get_db),
):
    existing = db.query(UserBadge).filter(
        UserBadge.user_id == user_id, UserBadge.badge_id == badge_id
    ).first()
    if existing:
        return {"message": "Badge already awarded"}
    db.add(UserBadge(user_id=user_id, badge_id=badge_id))
    db.commit()
    _write_audit(db, admin.id, "badge_awarded", "user", user_id, {"badge_id": badge_id})
    return {"message": "Badge awarded"}


@router.post("/gamification/challenges")
def create_challenge(
    description: str,
    goal_type: str,
    goal_value: int,
    xp_reward: int,
    admin: User = Depends(_get_admin_user),
    db: Session = Depends(get_db),
):
    ch = DailyChallenge(
        description=description,
        goal_type=goal_type,
        goal_value=goal_value,
        xp_reward=xp_reward,
    )
    db.add(ch)
    db.commit()
    db.refresh(ch)
    return {"id": ch.id, "description": ch.description}


