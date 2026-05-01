"""Agent-specific statistics and client-engagement endpoints.

These endpoints are public (no admin role required) and are intended for
agents to retrieve statistics and client information about their own listings.
"""
from fastapi import APIRouter, Depends, Query
from sqlalchemy.orm import Session
from sqlalchemy import func
from typing import List

from app.database.database import get_db
from app.models.models import Property, User
from app.models.marketplace_models import (
    Conversation,
    Order,
    OrderItem,
    Review,
    SavedItem,
)

router = APIRouter(prefix="/agent", tags=["agent"])


# ─── Stats ────────────────────────────────────────────────────────────────────

@router.get("/stats")
def get_agent_stats(
    agent_id: int = Query(..., ge=1),
    db: Session = Depends(get_db),
):
    """Return listing statistics for a given agent."""
    # Agent's active property IDs
    prop_ids = [
        r[0]
        for r in db.query(Property.id).filter(
            Property.agent_id == agent_id,
            Property.is_deleted.is_(False),
        ).all()
    ]

    total_properties = len(prop_ids)

    total_bids: int = 0
    total_saves: int = 0
    if prop_ids:
        total_bids = (
            db.query(func.count(OrderItem.id))
            .filter(OrderItem.property_id.in_(prop_ids))
            .scalar()
        ) or 0

        total_saves = (
            db.query(func.count(SavedItem.id))
            .filter(
                SavedItem.item_type == "property",
                SavedItem.item_id.in_(prop_ids),
            )
            .scalar()
        ) or 0

    # Conversations where this agent is the recipient
    total_messages: int = (
        db.query(func.count(Conversation.id))
        .filter(Conversation.recipient_id == agent_id)
        .scalar()
    ) or 0

    # Reviews for this agent
    review_rows = (
        db.query(Review.rating)
        .filter(Review.reviewed_agent_id == agent_id)
        .all()
    )
    total_reviews = len(review_rows)
    avg_rating = (
        round(sum(r[0] for r in review_rows) / total_reviews, 1)
        if total_reviews > 0
        else 0.0
    )

    return {
        "agent_id": agent_id,
        "total_properties": total_properties,
        "total_bids": total_bids,
        "total_saves": total_saves,
        "total_messages": total_messages,
        "total_reviews": total_reviews,
        "avg_rating": avg_rating,
    }


# ─── Clients ──────────────────────────────────────────────────────────────────

@router.get("/clients")
def get_agent_clients(
    agent_id: int = Query(..., ge=1),
    db: Session = Depends(get_db),
):
    """Return users who interacted with an agent's listings.

    Interactions tracked:
    * ``saved``    – user saved one of the agent's properties
    * ``bid``      – user placed a bid (order) on one of the agent's properties
    * ``messaged`` – user started a conversation with the agent
    """
    prop_ids = [
        r[0]
        for r in db.query(Property.id).filter(
            Property.agent_id == agent_id,
            Property.is_deleted.is_(False),
        ).all()
    ]

    # user_id → set of action labels
    user_actions: dict[int, set[str]] = {}

    if prop_ids:
        # Saved
        for s in (
            db.query(SavedItem.user_id)
            .filter(
                SavedItem.item_type == "property",
                SavedItem.item_id.in_(prop_ids),
            )
            .distinct()
            .all()
        ):
            uid = s[0]
            user_actions.setdefault(uid, set()).add("saved")

        # Bids (orders whose items reference one of the agent's properties)
        bid_rows = (
            db.query(Order.buyer_user_id)
            .join(OrderItem, Order.id == OrderItem.order_id)
            .filter(
                OrderItem.property_id.in_(prop_ids),
                Order.buyer_user_id.isnot(None),
            )
            .distinct()
            .all()
        )
        for row in bid_rows:
            uid = row[0]
            user_actions.setdefault(uid, set()).add("bid")

    # Messaged (conversations where agent is the recipient)
    msg_rows = (
        db.query(Conversation.initiator_id)
        .filter(
            Conversation.recipient_id == agent_id,
            Conversation.initiator_id.isnot(None),
        )
        .distinct()
        .all()
    )
    for row in msg_rows:
        uid = row[0]
        user_actions.setdefault(uid, set()).add("messaged")

    # Fetch user details for all interacting users
    clients: List[dict] = []
    if user_actions:
        users = (
            db.query(User)
            .filter(User.id.in_(user_actions.keys()))
            .all()
        )
        for u in users:
            clients.append(
                {
                    "user_id": u.id,
                    "first_name": u.first_name,
                    "last_name": u.last_name,
                    "email": u.email,
                    "phone": u.phone,
                    "avatar_url": u.avatar_url,
                    "actions": sorted(user_actions[u.id]),
                }
            )

    # Sort by name for consistent ordering
    clients.sort(key=lambda c: (c["first_name"] or "", c["last_name"] or ""))

    return {"agent_id": agent_id, "total": len(clients), "clients": clients}
