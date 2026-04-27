"""Saved / favourited items router."""
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session
from typing import List, Optional

from app.database.database import get_db
from app.models.marketplace_models import SavedItem
from app.schemas.marketplace_schemas import SavedItemCreate, SavedItemResponse

router = APIRouter(prefix="/saved-items", tags=["saved-items"])


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
