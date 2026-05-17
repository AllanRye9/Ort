"""Order management router."""
import uuid
from decimal import Decimal
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session
from typing import List, Optional

from app.database.database import get_db
from app.dependencies import get_current_user
from app.models.models import User
from app.models.marketplace_models import (
    Order,
    OrderItem,
    ProductTracking,
    Tenant,
    Conversation,
    Message,
    Notification,
)
from app.schemas.marketplace_schemas import (
    OrderCreate, OrderUpdate, OrderResponse,
)

router = APIRouter(prefix="/orders", tags=["orders"])

_ORDER_ITEM_REFERENCE_FIELDS = (
    "property_id",
    "agriculture_listing_id",
    "manufacturing_product_id",
    "manufacturing_service_id",
)

_ORDER_STATUS_TO_TRACKING = {
    "pending": "order_placed",
    "confirmed": "processing",
    "processing": "processing",
    "shipped": "shipped",
    "delivered": "delivered",
    "cancelled": "cancelled",
    "disputed": "processing",
}


def _generate_order_number() -> str:
    return f"ORD-{uuid.uuid4().hex[:10].upper()}"


def _display_name(user: Optional[User], fallback_id: Optional[int]) -> str:
    if user is None:
        return f"User #{fallback_id}" if fallback_id is not None else "A buyer"
    full_name = f"{(user.first_name or '').strip()} {(user.last_name or '').strip()}".strip()
    if full_name:
        return full_name
    if user.email:
        return user.email
    return f"User #{user.id}"


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
    for item in items_data:
        refs = [getattr(item, field) for field in _ORDER_ITEM_REFERENCE_FIELDS]
        if sum(1 for ref in refs if ref is not None) != 1:
            raise HTTPException(
                status_code=400,
                detail="Each order item must reference exactly one listing type.",
            )

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
            manufacturing_service_id=item.manufacturing_service_id,
            quantity=item.quantity,
            unit_price=item.unit_price,
            subtotal=subtotal,
        )
        db.add(db_item)

    seller_owner_id = None
    if payload.seller_tenant_id is not None:
        tenant = (
            db.query(Tenant)
            .filter(Tenant.id == payload.seller_tenant_id)
            .first()
        )
        seller_owner_id = tenant.owner_user_id if tenant else None

    buyer = None
    if payload.buyer_user_id is not None:
        buyer = db.query(User).filter(User.id == payload.buyer_user_id).first()
    buyer_label = _display_name(buyer, payload.buyer_user_id)

    if payload.buyer_user_id:
        db.add(
            Notification(
                user_id=payload.buyer_user_id,
                title="Order Confirmed",
                body=f"Your order {order_data['order_number']} has been placed successfully.",
                notification_type="order",
                reference_id=db_order.id,
                reference_type="order",
            )
        )

    if seller_owner_id:
        db.add(
            Notification(
                user_id=seller_owner_id,
                title="New Order Placed",
                body=f"{buyer_label} placed order {order_data['order_number']}.",
                notification_type="order",
                reference_id=db_order.id,
                reference_type="order",
            )
        )

        conversation = (
            db.query(Conversation)
            .filter(
                Conversation.initiator_id == payload.buyer_user_id,
                Conversation.recipient_id == seller_owner_id,
                Conversation.order_id == db_order.id,
            )
            .first()
        )
        if conversation is None:
            conversation = Conversation(
                initiator_id=payload.buyer_user_id,
                recipient_id=seller_owner_id,
                subject=f"Order {order_data['order_number']}",
                order_id=db_order.id,
            )
            db.add(conversation)
            db.flush()
        db.add(
            Message(
                conversation_id=conversation.id,
                sender_id=payload.buyer_user_id,
                body=(
                    f"Order placed by {buyer_label}. "
                    f"Order #{order_data['order_number']} total: {total} {payload.currency or 'USD'}."
                ),
                message_type="text",
            )
        )

    db.add(
        ProductTracking(
            order_id=db_order.id,
            status="order_placed",
            description=f"Order {order_data['order_number']} was placed.",
            created_by_user_id=payload.buyer_user_id,
        )
    )

    db.commit()
    db.refresh(db_order)

    if seller_owner_id:
        try:
            from app.utils.push import notify_user

            notify_user(
                seller_owner_id,
                "New Order Placed",
                f"{buyer_label} placed order {order_data['order_number']}.",
                db,
            )
        except Exception:
            pass

    return db_order


@router.put("/{order_id}", response_model=OrderResponse)
def update_order(order_id: int, payload: OrderUpdate, db: Session = Depends(get_db)):
    obj = db.query(Order).filter(Order.id == order_id).first()
    if not obj:
        raise HTTPException(status_code=404, detail="Order not found")
    previous_status = obj.status
    for k, v in payload.model_dump(exclude_unset=True).items():
        setattr(obj, k, v)

    seller_owner_id = None
    if obj.seller_tenant_id is not None:
        tenant = (
            db.query(Tenant)
            .filter(Tenant.id == obj.seller_tenant_id)
            .first()
        )
        seller_owner_id = tenant.owner_user_id if tenant else None

    if payload.status is not None and payload.status != previous_status:
        if obj.buyer_user_id:
            db.add(
                Notification(
                    user_id=obj.buyer_user_id,
                    title="Order Status Updated",
                    body=f"Order {obj.order_number} is now {payload.status}.",
                    notification_type="order",
                    reference_id=obj.id,
                    reference_type="order",
                )
            )
        if seller_owner_id:
            db.add(
                Notification(
                    user_id=seller_owner_id,
                    title="Order Status Updated",
                    body=f"Order {obj.order_number} is now {payload.status}.",
                    notification_type="order",
                    reference_id=obj.id,
                    reference_type="order",
                )
            )

        db.add(
            ProductTracking(
                order_id=obj.id,
                status=_ORDER_STATUS_TO_TRACKING.get(payload.status, "processing"),
                description=f"Order {obj.order_number} status changed to {payload.status}.",
            )
        )

    db.commit()
    db.refresh(obj)
    return obj


@router.delete("/{order_id}", status_code=status.HTTP_200_OK)
def cancel_order(
    order_id: int,
    db: Session = Depends(get_db),
    current_user: User = Depends(get_current_user),
):
    obj = db.query(Order).filter(Order.id == order_id).first()
    if not obj:
        raise HTTPException(status_code=404, detail="Order not found")
    if current_user.role != "admin" and obj.buyer_user_id != current_user.id:
        raise HTTPException(
            status_code=403,
            detail="Insufficient permissions: only the order creator or an admin can cancel this order",
        )
    obj.status = "cancelled"
    db.commit()
    return {"message": "Order cancelled successfully"}
