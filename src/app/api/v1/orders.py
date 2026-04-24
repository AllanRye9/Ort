"""Order management router."""
import uuid
from decimal import Decimal
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session
from typing import List, Optional

from app.database.database import get_db
from app.models.marketplace_models import Order, OrderItem
from app.schemas.marketplace_schemas import (
    OrderCreate, OrderUpdate, OrderResponse,
)

router = APIRouter(prefix="/orders", tags=["orders"])


def _generate_order_number() -> str:
    return f"ORD-{uuid.uuid4().hex[:10].upper()}"


@router.get("/", response_model=List[OrderResponse])
def list_orders(
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=1000),
    buyer_user_id: Optional[int] = Query(None),
    seller_tenant_id: Optional[int] = Query(None),
    order_status: Optional[str] = Query(None),
    db: Session = Depends(get_db),
):
    q = db.query(Order)
    if buyer_user_id:
        q = q.filter(Order.buyer_user_id == buyer_user_id)
    if seller_tenant_id:
        q = q.filter(Order.seller_tenant_id == seller_tenant_id)
    if order_status:
        q = q.filter(Order.status == order_status)
    return q.offset(skip).limit(limit).all()


@router.get("/{order_id}", response_model=OrderResponse)
def get_order(order_id: int, db: Session = Depends(get_db)):
    obj = db.query(Order).filter(Order.id == order_id).first()
    if not obj:
        raise HTTPException(status_code=404, detail="Order not found")
    return obj


@router.post("/", response_model=OrderResponse, status_code=status.HTTP_201_CREATED)
def create_order(payload: OrderCreate, db: Session = Depends(get_db)):
    items_data = payload.items
    order_data = payload.model_dump(exclude={"items"})
    order_data["order_number"] = _generate_order_number()

    # Calculate total
    total = Decimal("0")
    for item in items_data:
        subtotal = Decimal(str(item.unit_price)) * Decimal(str(item.quantity))
        total += subtotal

    order_data["total_amount"] = total

    db_order = Order(**order_data)
    db.add(db_order)
    db.flush()  # get id before adding items

    for item in items_data:
        subtotal = Decimal(str(item.unit_price)) * Decimal(str(item.quantity))
        db_item = OrderItem(
            order_id=db_order.id,
            property_id=item.property_id,
            agriculture_listing_id=item.agriculture_listing_id,
            manufacturing_product_id=item.manufacturing_product_id,
            quantity=item.quantity,
            unit_price=item.unit_price,
            subtotal=subtotal,
        )
        db.add(db_item)

    db.commit()
    db.refresh(db_order)
    return db_order


@router.put("/{order_id}", response_model=OrderResponse)
def update_order(order_id: int, payload: OrderUpdate, db: Session = Depends(get_db)):
    obj = db.query(Order).filter(Order.id == order_id).first()
    if not obj:
        raise HTTPException(status_code=404, detail="Order not found")
    for k, v in payload.model_dump(exclude_unset=True).items():
        setattr(obj, k, v)
    db.commit()
    db.refresh(obj)
    return obj


@router.delete("/{order_id}", status_code=status.HTTP_200_OK)
def cancel_order(order_id: int, db: Session = Depends(get_db)):
    obj = db.query(Order).filter(Order.id == order_id).first()
    if not obj:
        raise HTTPException(status_code=404, detail="Order not found")
    obj.status = "cancelled"
    db.commit()
    return {"message": "Order cancelled successfully"}
