"""Saved / favourited items router."""
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session
from typing import List, Optional

from app.database.database import get_db
from app.models.marketplace_models import SavedItem
from app.schemas.marketplace_schemas import SavedItemCreate, SavedItemResponse

router = APIRouter(prefix="/saved-items", tags=["saved-items"])


def _notify_item_owner(item_type: str, item_id: int, saver_user_id: int, db: Session) -> None:
    """Send an in-app notification (and FCM push) to the owner of a saved item."""
    try:
        from app.models.marketplace_models import Notification
        from app.models.marketplace_models import (
            AgricultureListing, ManufacturingProduct,
        )
        from app.models.models import Property

        owner_id: Optional[int] = None
        label = item_type.title()

        if item_type == "property":
            row = db.query(Property).filter(Property.id == item_id).first()
            if row:
                owner_id = row.agent_id
                label = f"property '{row.title}'"
        elif item_type == "agriculture":
            row = db.query(AgricultureListing).filter(AgricultureListing.id == item_id).first()
            if row:
                owner_id = row.owner_user_id or (row.tenant.owner_user_id if row.tenant else None)
                label = f"listing '{row.title}'"
        elif item_type == "manufacturing":
            row = db.query(ManufacturingProduct).filter(ManufacturingProduct.id == item_id).first()
            if row:
                owner_id = row.owner_user_id or (row.tenant.owner_user_id if row.tenant else None)
                label = f"product '{row.name}'"

        if owner_id and owner_id != saver_user_id:
            notif = Notification(
                user_id=owner_id,
                title="New Favourite ❤️",
                body=f"Someone saved your {label}.",
                notification_type="favourite",
                reference_id=item_id,
                reference_type=item_type,
            )
            db.add(notif)
            db.flush()
            from app.utils.push import notify_user
            notify_user(owner_id, "New Favourite ❤️", f"Someone saved your {label}.", db)
    except Exception:
        pass  # Notification failure must never break the save endpoint


@router.get("/", response_model=List[SavedItemResponse])
def list_saved_items(
    user_id: int = Query(...),
    item_type: Optional[str] = Query(None),
    db: Session = Depends(get_db),
):
    q = db.query(SavedItem).filter(SavedItem.user_id == user_id)
    if item_type:
        q = q.filter(SavedItem.item_type == item_type)
    return q.order_by(SavedItem.created_at.desc()).all()


@router.post("/", response_model=SavedItemResponse, status_code=status.HTTP_201_CREATED)
def save_item(payload: SavedItemCreate, db: Session = Depends(get_db)):
    # Prevent duplicates
    existing = db.query(SavedItem).filter(
        SavedItem.user_id == payload.user_id,
        SavedItem.item_type == payload.item_type,
        SavedItem.item_id == payload.item_id,
    ).first()
    if existing:
        return existing
    obj = SavedItem(**payload.model_dump())
    db.add(obj)
    db.commit()
    db.refresh(obj)

    # Notify the item owner that their listing was saved/liked
    _notify_item_owner(payload.item_type, payload.item_id, payload.user_id, db)

    return obj


@router.delete("/", status_code=status.HTTP_200_OK)
def unsave_item(
    user_id: int = Query(...),
    item_type: str = Query(...),
    item_id: int = Query(...),
    db: Session = Depends(get_db),
):
    obj = db.query(SavedItem).filter(
        SavedItem.user_id == user_id,
        SavedItem.item_type == item_type,
        SavedItem.item_id == item_id,
    ).first()
    if not obj:
        raise HTTPException(status_code=404, detail="Saved item not found")
    db.delete(obj)
    db.commit()
    return {"message": "Item removed from saved"}


@router.get("/check", response_model=bool)
def check_saved(
    user_id: int = Query(...),
    item_type: str = Query(...),
    item_id: int = Query(...),
    db: Session = Depends(get_db),
):
    return db.query(SavedItem).filter(
        SavedItem.user_id == user_id,
        SavedItem.item_type == item_type,
        SavedItem.item_id == item_id,
    ).first() is not None
