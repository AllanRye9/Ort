"""GDPR/CCPA compliance endpoints."""
import io
import json
import logging
import secrets
import zipfile
from datetime import datetime

from fastapi import APIRouter, Depends, Response, status
from sqlalchemy.orm import Session

from app.database.database import get_db
from app.models.models import User
from app.models.marketplace_models import Message, Notification, Order
from app.models.gamification_models import Consent
from app.schemas.gamification_schemas import ConsentCreate, ConsentResponse
from app.api.v1.api import _get_current_user

router = APIRouter(prefix="/me", tags=["gdpr"])
logger = logging.getLogger(__name__)


@router.get("/data-export")
def export_my_data(
    current_user: User = Depends(_get_current_user),
    db: Session = Depends(get_db),
):
    """Export all user data as a ZIP file (GDPR Article 20 data portability)."""
    profile = {
        "id": current_user.id,
        "email": current_user.email,
        "first_name": current_user.first_name,
        "last_name": current_user.last_name,
        "phone": current_user.phone,
        "role": current_user.role,
        "created_at": current_user.created_at.isoformat() if current_user.created_at else None,
    }

    messages = [
        {
            "id": m.id,
            "conversation_id": m.conversation_id,
            "body": m.body,
            "sent_at": m.sent_at.isoformat() if m.sent_at else None,
        }
        for m in db.query(Message).filter(Message.sender_id == current_user.id).all()
    ]

    orders = [
        {
            "id": o.id,
            "order_number": o.order_number,
            "status": o.status,
            "total_amount": str(o.total_amount),
            "created_at": o.created_at.isoformat() if o.created_at else None,
        }
        for o in db.query(Order).filter(Order.buyer_user_id == current_user.id).all()
    ]

    notifications = [
        {
            "id": n.id,
            "title": n.title,
            "body": n.body,
            "created_at": n.created_at.isoformat() if n.created_at else None,
        }
        for n in db.query(Notification).filter(Notification.user_id == current_user.id).all()
    ]

    buf = io.BytesIO()
    with zipfile.ZipFile(buf, "w", zipfile.ZIP_DEFLATED) as zf:
        zf.writestr("profile.json", json.dumps(profile, indent=2))
        zf.writestr("messages.json", json.dumps(messages, indent=2))
        zf.writestr("orders.json", json.dumps(orders, indent=2))
        zf.writestr("notifications.json", json.dumps(notifications, indent=2))

    buf.seek(0)
    filename = f"data_export_user_{current_user.id}_{datetime.utcnow().date()}.zip"
    return Response(
        content=buf.read(),
        media_type="application/zip",
        headers={"Content-Disposition": f'attachment; filename="{filename}"'},
    )


@router.delete("/account", status_code=status.HTTP_200_OK)
def delete_my_account(
    current_user: User = Depends(_get_current_user),
    db: Session = Depends(get_db),
):
    """Soft-delete the user account by anonymising PII (GDPR Article 17)."""
    anon_suffix = secrets.token_hex(8)
    current_user.email = f"deleted_{anon_suffix}@deleted.invalid"
    current_user.first_name = "Deleted"
    current_user.last_name = "User"
    current_user.phone = None
    current_user.password_hash = secrets.token_hex(32)
    db.commit()
    logger.info("Account anonymised for user_id=%s", current_user.id)
    return {"message": "Account successfully deleted and data anonymised."}


@router.post("/consents", response_model=ConsentResponse, status_code=status.HTTP_201_CREATED)
def record_consent(
    payload: ConsentCreate,
    current_user: User = Depends(_get_current_user),
    db: Session = Depends(get_db),
):
    """Record a GDPR consent for the current user."""
    record = Consent(
        user_id=current_user.id,
        consent_type=payload.consent_type,
        version=payload.version,
    )
    db.add(record)
    db.commit()
    db.refresh(record)
    return record


@router.get("/consents")
def list_consents(
    current_user: User = Depends(_get_current_user),
    db: Session = Depends(get_db),
):
    return db.query(Consent).filter(Consent.user_id == current_user.id).all()


@router.patch("/onboarding")
def update_onboarding(
    step: int,
    completed: bool = False,
    current_user: User = Depends(_get_current_user),
    db: Session = Depends(get_db),
):
    """Advance the onboarding step for the current user."""
    current_user.onboarding_step = step
    if completed:
        current_user.onboarding_completed = True
    db.commit()
    return {
        "user_id": current_user.id,
        "onboarding_step": current_user.onboarding_step,
        "onboarding_completed": current_user.onboarding_completed,
    }
