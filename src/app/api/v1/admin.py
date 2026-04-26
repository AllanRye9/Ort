"""Enterprise admin API."""
import logging
from datetime import datetime, timedelta
from typing import List

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.database.database import get_db
from app.models.models import User
from app.models.marketplace_models import Message, Notification
from app.models.gamification_models import (
    AuditEvent, ImageRecord, Badge, UserBadge, DailyChallenge,
)
from app.schemas.gamification_schemas import (
    AuditEventResponse, EngagementStats, ChurnRiskUser,
)
from app.api.v1.api import _get_current_user

router = APIRouter(prefix="/admin", tags=["admin"])
logger = logging.getLogger(__name__)


def _require_admin(current_user: User = Depends(_get_current_user)) -> User:
    if current_user.role != "admin":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin role required")
    return current_user


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


# ── User management ──────────────────────────────────────────────────────────

@router.get("/users", response_model=List[dict])
def admin_list_users(
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=500),
    admin: User = Depends(_require_admin),
    db: Session = Depends(get_db),
):
    users = db.query(User).offset(skip).limit(limit).all()
    return [
        {
            "id": u.id,
            "email": u.email,
            "role": u.role,
            "first_name": u.first_name,
            "last_name": u.last_name,
            "created_at": u.created_at.isoformat() if u.created_at else None,
        }
        for u in users
    ]


# ── Moderation queue ─────────────────────────────────────────────────────────

@router.get("/moderation/images")
def moderation_queue(
    status_filter: str = Query("pending", pattern="^(pending|approved|rejected)$"),
    skip: int = Query(0, ge=0),
    limit: int = Query(50, ge=1, le=200),
    admin: User = Depends(_require_admin),
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
    admin: User = Depends(_require_admin),
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


# ── Analytics ────────────────────────────────────────────────────────────────

@router.get("/analytics/engagement", response_model=EngagementStats)
def engagement_stats(
    admin: User = Depends(_require_admin),
    db: Session = Depends(get_db),
):
    now = datetime.utcnow()
    day_ago = now - timedelta(days=1)
    month_ago = now - timedelta(days=30)

    dau = db.query(User).filter(User.created_at >= day_ago).count()
    mau = db.query(User).filter(User.created_at >= month_ago).count()
    uploads_today = db.query(ImageRecord).filter(ImageRecord.created_at >= day_ago).count()
    messages_today = db.query(Message).filter(Message.sent_at >= day_ago).count()
    new_users_today = db.query(User).filter(User.created_at >= day_ago).count()

    return EngagementStats(
        dau=dau,
        mau=mau,
        uploads_today=uploads_today,
        messages_today=messages_today,
        new_users_today=new_users_today,
    )


@router.get("/analytics/churn-risk")
def churn_risk_users(
    inactive_days: int = Query(14, ge=1),
    admin: User = Depends(_require_admin),
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


# ── Audit logs ───────────────────────────────────────────────────────────────

@router.get("/audit-logs", response_model=List[AuditEventResponse])
def get_audit_logs(
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=500),
    admin: User = Depends(_require_admin),
    db: Session = Depends(get_db),
):
    return (
        db.query(AuditEvent)
        .order_by(AuditEvent.created_at.desc())
        .offset(skip)
        .limit(limit)
        .all()
    )


# ── Badge management ─────────────────────────────────────────────────────────

@router.post("/badges")
def create_badge(
    name: str,
    description: str = None,
    icon_url: str = None,
    admin: User = Depends(_require_admin),
    db: Session = Depends(get_db),
):
    badge = Badge(name=name, description=description, icon_url=icon_url)
    db.add(badge)
    db.commit()
    db.refresh(badge)
    return {"id": badge.id, "name": badge.name}


@router.post("/badges/{badge_id}/award/{user_id}")
def award_badge(
    badge_id: int,
    user_id: int,
    admin: User = Depends(_require_admin),
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


# ── Daily challenge management ────────────────────────────────────────────────

@router.post("/challenges")
def create_challenge(
    description: str,
    goal_type: str,
    goal_value: int,
    xp_reward: int,
    admin: User = Depends(_require_admin),
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
