"""Reviews & Ratings router."""
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session
from typing import List, Optional

from app.database.database import get_db
from app.models.marketplace_models import Review
from app.schemas.marketplace_schemas import ReviewCreate, ReviewResponse

router = APIRouter(prefix="/reviews", tags=["reviews"])


@router.get("/", response_model=List[ReviewResponse])
def list_reviews(
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=1000),
    tenant_id: Optional[int] = Query(None),
    property_id: Optional[int] = Query(None),
    agent_id: Optional[int] = Query(None),
    db: Session = Depends(get_db),
):
    q = db.query(Review)
    if tenant_id:
        q = q.filter(Review.reviewed_tenant_id == tenant_id)
    if property_id:
        q = q.filter(Review.property_id == property_id)
    if agent_id:
        q = q.filter(Review.reviewed_agent_id == agent_id)
    return q.order_by(Review.created_at.desc()).offset(skip).limit(limit).all()


@router.get("/{review_id}", response_model=ReviewResponse)
def get_review(review_id: int, db: Session = Depends(get_db)):
    obj = db.query(Review).filter(Review.id == review_id).first()
    if not obj:
        raise HTTPException(status_code=404, detail="Review not found")
    return obj


@router.post("/", response_model=ReviewResponse, status_code=status.HTTP_201_CREATED)
def create_review(payload: ReviewCreate, db: Session = Depends(get_db)):
    obj = Review(**payload.model_dump())
    db.add(obj)
    db.commit()
    db.refresh(obj)
    return obj


@router.delete("/{review_id}", status_code=status.HTTP_200_OK)
def delete_review(review_id: int, db: Session = Depends(get_db)):
    obj = db.query(Review).filter(Review.id == review_id).first()
    if not obj:
        raise HTTPException(status_code=404, detail="Review not found")
    db.delete(obj)
    db.commit()
    return {"message": "Review deleted successfully"}
