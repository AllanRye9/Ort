"""Notifications router."""
import os
from fastapi import APIRouter, Depends, HTTPException, Query, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from jose import jwt, JWTError
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session
from typing import List, Optional

from app.database.database import get_db
from app.models.models import User
from app.models.marketplace_models import Notification, UserDeviceToken
from app.schemas.marketplace_schemas import (
    NotificationCreate, NotificationUpdate, NotificationResponse,
)

router = APIRouter(prefix="/notifications", tags=["notifications"])

SECRET_KEY = os.getenv("SECRET_KEY", "change-me-in-production")
ALGORITHM = "HS256"
_bearer = HTTPBearer(auto_error=False)


def _get_current_user_optional(
    credentials: HTTPAuthorizationCredentials = Depends(_bearer),
    db: Session = Depends(get_db),
) -> Optional[User]:
    if credentials is None:
        return None
    try:
        payload = jwt.decode(credentials.credentials, SECRET_KEY, algorithms=[ALGORITHM])
        user_id: str = payload.get("sub")
        if user_id is None:
            return None
    except JWTError:
        return None
    return db.query(User).filter(User.id == int(user_id)).first()


@router.get("/", response_model=List[NotificationResponse])
def list_notifications(
    user_id: int = Query(...),
    unread_only: bool = Query(False),
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=1000),
    db: Session = Depends(get_db),
):
    q = db.query(Notification).filter(Notification.user_id == user_id)
    if unread_only:
        q = q.filter(Notification.is_read.is_(False))
    return q.order_by(Notification.created_at.desc()).offset(skip).limit(limit).all()


@router.post("/", response_model=NotificationResponse, status_code=status.HTTP_201_CREATED)
def create_notification(payload: NotificationCreate, db: Session = Depends(get_db)):
    obj = Notification(**payload.model_dump())
    db.add(obj)
    db.commit()
    db.refresh(obj)
    return obj


@router.get("/{notification_id}", response_model=NotificationResponse)
def get_notification(notification_id: int, db: Session = Depends(get_db)):
    obj = db.query(Notification).filter(Notification.id == notification_id).first()
    if not obj:
        raise HTTPException(status_code=404, detail="Notification not found")
    return obj


@router.put("/read-all/", status_code=status.HTTP_200_OK)
def mark_all_read(user_id: int = Query(...), db: Session = Depends(get_db)):
    db.query(Notification).filter(
        Notification.user_id == user_id,
        Notification.is_read.is_(False),
    ).update({"is_read": True})
    db.commit()
    return {"message": "All notifications marked as read"}


@router.put("/{notification_id}", response_model=NotificationResponse)
def update_notification(
    notification_id: int,
    payload: NotificationUpdate,
    db: Session = Depends(get_db),
):
    obj = db.query(Notification).filter(Notification.id == notification_id).first()
    if not obj:
        raise HTTPException(status_code=404, detail="Notification not found")
    for k, v in payload.model_dump(exclude_unset=True).items():
        setattr(obj, k, v)
    db.commit()
    db.refresh(obj)
    return obj


# ── Device Token Registration ──────────────────────────────────────────────

class DeviceTokenRequest(BaseModel):
    user_id: int
    token: str = Field(..., min_length=1)
    platform: Optional[str] = Field(None, description="android | ios | web")


@router.post("/device-token", status_code=status.HTTP_200_OK)
def register_device_token(
    payload: DeviceTokenRequest,
    db: Session = Depends(get_db),
):
    """Register or update a device FCM token for push notifications.

    If the token already exists for this user it is updated (upsert).
    A user may have multiple tokens (e.g. multiple devices).
    """
    existing = db.query(UserDeviceToken).filter(
        UserDeviceToken.user_id == payload.user_id,
        UserDeviceToken.token == payload.token,
    ).first()
    if existing:
        if payload.platform and existing.platform != payload.platform:
            existing.platform = payload.platform
            db.commit()
        return {"message": "Token already registered"}
    obj = UserDeviceToken(
        user_id=payload.user_id,
        token=payload.token,
        platform=payload.platform,
    )
    db.add(obj)
    db.commit()
    return {"message": "Device token registered"}


@router.delete("/device-token", status_code=status.HTTP_200_OK)
def unregister_device_token(
    user_id: int = Query(...),
    token: str = Query(...),
    db: Session = Depends(get_db),
):
    """Remove a device FCM token (e.g. on logout)."""
    obj = db.query(UserDeviceToken).filter(
        UserDeviceToken.user_id == user_id,
        UserDeviceToken.token == token,
    ).first()
    if obj:
        db.delete(obj)
        db.commit()
    return {"message": "Token removed"}
