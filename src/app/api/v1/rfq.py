"""RFQ (Request for Quote) router."""
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session
from typing import List, Optional

from app.database.database import get_db
from app.models.marketplace_models import RFQ, RFQResponse as RFQResponseModel
from app.schemas.marketplace_schemas import (
    RFQCreate, RFQUpdate, RFQResponse,
    RFQResponseCreate, RFQResponseResponse,
)

router = APIRouter(prefix="/rfq", tags=["rfq"])


@router.get("/", response_model=List[RFQResponse])
def list_rfqs(
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=1000),
    buyer_id: Optional[int] = Query(None),
    seller_tenant_id: Optional[int] = Query(None),
    rfq_status: Optional[str] = Query(None),
    db: Session = Depends(get_db),
):
    q = db.query(RFQ)
    if buyer_id:
        q = q.filter(RFQ.buyer_id == buyer_id)
    if seller_tenant_id:
        q = q.filter(RFQ.seller_tenant_id == seller_tenant_id)
    if rfq_status:
        q = q.filter(RFQ.status == rfq_status)
    return q.offset(skip).limit(limit).all()


@router.get("/{rfq_id}", response_model=RFQResponse)
def get_rfq(rfq_id: int, db: Session = Depends(get_db)):
    obj = db.query(RFQ).filter(RFQ.id == rfq_id).first()
    if not obj:
        raise HTTPException(status_code=404, detail="RFQ not found")
    return obj


@router.post("/", response_model=RFQResponse, status_code=status.HTTP_201_CREATED)
def create_rfq(payload: RFQCreate, db: Session = Depends(get_db)):
    obj = RFQ(**payload.model_dump())
    db.add(obj)
    db.commit()
    db.refresh(obj)
    return obj


@router.put("/{rfq_id}", response_model=RFQResponse)
def update_rfq(rfq_id: int, payload: RFQUpdate, db: Session = Depends(get_db)):
    obj = db.query(RFQ).filter(RFQ.id == rfq_id).first()
    if not obj:
        raise HTTPException(status_code=404, detail="RFQ not found")
    for k, v in payload.model_dump(exclude_unset=True).items():
        setattr(obj, k, v)
    db.commit()
    db.refresh(obj)
    return obj


# ---- RFQ Responses ----

@router.get("/{rfq_id}/responses", response_model=List[RFQResponseResponse])
def list_rfq_responses(rfq_id: int, db: Session = Depends(get_db)):
    return db.query(RFQResponseModel).filter(RFQResponseModel.rfq_id == rfq_id).all()


@router.post("/{rfq_id}/responses", response_model=RFQResponseResponse, status_code=status.HTTP_201_CREATED)
def create_rfq_response(rfq_id: int, payload: RFQResponseCreate, db: Session = Depends(get_db)):
    rfq = db.query(RFQ).filter(RFQ.id == rfq_id).first()
    if not rfq:
        raise HTTPException(status_code=404, detail="RFQ not found")
    data = payload.model_dump()
    data["rfq_id"] = rfq_id
    obj = RFQResponseModel(**data)
    db.add(obj)
    # Update RFQ status to quoted
    rfq.status = "quoted"
    db.commit()
    db.refresh(obj)
    return obj
