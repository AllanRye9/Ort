"""RFQ (Request for Quote) router."""
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session
from typing import List, Optional

from app.database.database import get_db
from app.models.models import Property, User
from app.models.marketplace_models import (
    RFQ,
    RFQResponse as RFQResponseModel,
    Tenant,
    Conversation,
    Message,
    Notification,
)
from app.schemas.marketplace_schemas import (
    RFQCreate, RFQUpdate, RFQResponse,
    RFQResponseCreate, RFQResponseResponse,
)

router = APIRouter(prefix="/rfq", tags=["rfq"])


def _display_name(user: Optional[User], fallback_id: Optional[int]) -> str:
    if user is None:
        return f"User #{fallback_id}" if fallback_id is not None else "A buyer"
    full_name = f"{(user.first_name or '').strip()} {(user.last_name or '').strip()}".strip()
    if full_name:
        return full_name
    if user.email:
        return user.email
    return f"User #{user.id}"


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
    if payload.property_id is not None and payload.target_price is not None:
        prop = db.query(Property).filter(Property.id == payload.property_id).first()
        if prop is None:
            raise HTTPException(status_code=404, detail="Property not found")
        if prop.pricing_type == "fixed":
            raise HTTPException(status_code=400, detail="Bidding is disabled for this listing")
        if payload.buyer_id is not None and prop.agent_id == payload.buyer_id:
            raise HTTPException(status_code=400, detail="You cannot bid on your own listing")
    obj = RFQ(**payload.model_dump())
    db.add(obj)
    db.flush()

    seller_owner_id = None
    if payload.seller_tenant_id is not None:
        tenant = (
            db.query(Tenant)
            .filter(Tenant.id == payload.seller_tenant_id)
            .first()
        )
        seller_owner_id = tenant.owner_user_id if tenant else None
        if payload.buyer_id is not None and seller_owner_id == payload.buyer_id:
            raise HTTPException(status_code=400, detail="You cannot bid on your own listing")

    buyer = None
    if payload.buyer_id is not None:
        buyer = db.query(User).filter(User.id == payload.buyer_id).first()
    buyer_label = _display_name(buyer, payload.buyer_id)

    if seller_owner_id:
        db.add(
            Notification(
                user_id=seller_owner_id,
                title="New Quote Request",
                body=f"{buyer_label} requested a quote: {payload.title}",
                notification_type="rfq",
                reference_id=obj.id,
                reference_type="rfq",
            )
        )
        conversation = (
            db.query(Conversation)
            .filter(
                Conversation.initiator_id == payload.buyer_id,
                Conversation.recipient_id == seller_owner_id,
                Conversation.subject == payload.title,
            )
            .first()
        )
        if conversation is None:
            conversation = Conversation(
                initiator_id=payload.buyer_id,
                recipient_id=seller_owner_id,
                subject=payload.title,
                property_id=payload.property_id,
            )
            db.add(conversation)
            db.flush()
        db.add(
            Message(
                conversation_id=conversation.id,
                sender_id=payload.buyer_id,
                body=(
                    f"Quote request from {buyer_label}: {payload.title}. "
                    f"Details: {payload.description or 'No additional details provided.'}"
                ),
                message_type="text",
            )
        )

    db.commit()
    db.refresh(obj)

    if seller_owner_id:
        try:
            from app.utils.push import notify_user

            notify_user(
                seller_owner_id,
                "New Quote Request",
                f"{buyer_label} requested a quote.",
                db,
            )
        except Exception:
            pass

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
