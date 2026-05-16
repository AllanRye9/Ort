"""Messaging router (conversations & messages)."""
import re
from fastapi import APIRouter, Depends, HTTPException, Query, status
from pydantic import BaseModel
from sqlalchemy.orm import Session
from typing import List, Optional

from app.database.database import get_db
from app.models.models import User
from app.models.marketplace_models import Conversation, Message, Notification
from app.schemas.marketplace_schemas import (
    ConversationCreate, ConversationResponse,
    MessageCreate, MessageResponse,
)

# conversations live at /api/v1/messages/conversations/
# messages live at /api/v1/messages/
conversations_router = APIRouter(prefix="/messages/conversations", tags=["conversations"])
router = APIRouter(prefix="/messages", tags=["messages"])
_ALLOWED_RECIPIENT_ROLES = {"agent", "company", "organization"}
_MIN_LOCATION_LENGTH = 2
_MAX_LOCATION_LENGTH = 120
_MIN_COORDINATE_PRECISION = 3


def _display_name(user: User) -> str:
    full_name = f"{(user.first_name or '').strip()} {(user.last_name or '').strip()}".strip()
    if full_name:
        return full_name
    if user.email:
        return user.email
    return f"User #{user.id}"


def _extract_location_from_text(text: Optional[str]) -> Optional[str]:
    """Extract location tokens from free-form message text.

    Supported formats include:
    - `location: Kampala`
    - `address=Kigali Heights`
    - coordinate pairs like `0.3476, 32.5825`
    """
    if not text:
        return None
    body = text.strip()
    if not body:
        return None

    # Match keyed location snippets like `location: Kampala` or `address=Plot 5`.
    # Captures the value segment between configured min/max lengths while
    # excluding line breaks and semicolons.
    # The `{{...}}` notation below is escaped f-string syntax to emit regex
    # quantifier braces literally.
    keyed = re.search(
        rf"(?im)\b(?:location|loc|address|place)\s*[:=-]\s*([^\n\r;]{{{_MIN_LOCATION_LENGTH},{_MAX_LOCATION_LENGTH}}})",
        body,
    )
    if keyed:
        value = keyed.group(1).strip(" .,-")
        return value or None

    # Match coordinate pairs like `0.3476, 32.5825` with minimum decimal
    # precision and optional +/- sign.
    coords = re.search(
        rf"(?<!\d)([-+]?\d{{1,2}}\.\d{{{_MIN_COORDINATE_PRECISION},}}),\s*([-+]?\d{{1,3}}\.\d{{{_MIN_COORDINATE_PRECISION},}})(?!\d)",
        body,
    )
    if coords:
        return f"{coords.group(1)}, {coords.group(2)}"

    return None


# ---- Conversations ----

@conversations_router.get("/", response_model=List[ConversationResponse])
def list_conversations(
    user_id: Optional[int] = Query(None),
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=1000),
    db: Session = Depends(get_db),
):
    q = db.query(Conversation)
    if user_id:
        q = q.filter(
            (Conversation.initiator_id == user_id) | (Conversation.recipient_id == user_id)
        )
    return q.offset(skip).limit(limit).all()


@conversations_router.get("/{conversation_id}", response_model=ConversationResponse)
def get_conversation(conversation_id: int, db: Session = Depends(get_db)):
    obj = db.query(Conversation).filter(Conversation.id == conversation_id).first()
    if not obj:
        raise HTTPException(status_code=404, detail="Conversation not found")
    return obj


@conversations_router.post("/", response_model=ConversationResponse, status_code=status.HTTP_201_CREATED)
def create_conversation(payload: ConversationCreate, db: Session = Depends(get_db)):
    initiator = None
    if payload.initiator_id is not None:
        initiator = db.query(User).filter(User.id == payload.initiator_id).first()
        if not initiator:
            raise HTTPException(status_code=404, detail="Initiator not found")

    recipient = db.query(User).filter(User.id == payload.recipient_id).first()
    if not recipient:
        raise HTTPException(status_code=404, detail="Recipient not found")
    if initiator is not None and initiator.id == recipient.id:
        raise HTTPException(status_code=400, detail="You cannot start a conversation with yourself")
    if recipient.role not in _ALLOWED_RECIPIENT_ROLES:
        raise HTTPException(
            status_code=400,
            detail="Conversations can only be started with agents, companies, or organizations",
        )

    obj = Conversation(**payload.model_dump())
    db.add(obj)
    db.flush()

    if initiator is not None:
        sender_label = _display_name(initiator)
        summary = payload.subject.strip() if payload.subject else "General enquiry"
        db.add(
            Notification(
                user_id=recipient.id,
                title="New Contact Request",
                body=f"{sender_label} started a conversation: {summary}",
                notification_type="contact",
                reference_id=obj.id,
                reference_type="conversation",
            )
        )
        db.add(
            Message(
                conversation_id=obj.id,
                sender_id=initiator.id,
                body=f"Contact request from {sender_label}: {summary}",
                message_type="text",
            )
        )

    db.commit()
    db.refresh(obj)

    if initiator is not None:
        try:
            from app.utils.push import notify_user

            notify_user(
                recipient.id,
                "New Contact Request",
                f"{_display_name(initiator)} started a conversation with you.",
                db,
            )
        except Exception:
            pass

    return obj


# ---- Messages ----

@router.get("/", response_model=List[MessageResponse])
def list_messages(
    conversation_id: int = Query(...),
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=1000),
    db: Session = Depends(get_db),
):
    return (
        db.query(Message)
        .filter(Message.conversation_id == conversation_id, Message.is_deleted.is_(False))
        # Message threads are shown in reverse chronological order so the newest
        # activity is visible first. Use id as a deterministic tiebreaker when
        # multiple messages share the same sent_at timestamp.
        .order_by(Message.sent_at.desc(), Message.id.desc())
        .offset(skip)
        .limit(limit)
        .all()
    )


@router.post("/", response_model=MessageResponse, status_code=status.HTTP_201_CREATED)
def send_message(payload: MessageCreate, db: Session = Depends(get_db)):
    conv = db.query(Conversation).filter(Conversation.id == payload.conversation_id).first()
    if not conv:
        raise HTTPException(status_code=404, detail="Conversation not found")
    if payload.sender_id not in {conv.initiator_id, conv.recipient_id}:
        raise HTTPException(status_code=403, detail="Sender is not part of this conversation")
    obj = Message(**payload.model_dump())
    db.add(obj)
    db.flush()

    extracted_location = _extract_location_from_text(payload.body)
    if extracted_location:
        conv.location = extracted_location

    # Create a notification for the other participant
    recipient_id = None
    if conv.initiator_id and conv.initiator_id != payload.sender_id:
        recipient_id = conv.initiator_id
    elif conv.recipient_id and conv.recipient_id != payload.sender_id:
        recipient_id = conv.recipient_id

    if recipient_id:
        from app.models.marketplace_models import Notification
        notif = Notification(
            user_id=recipient_id,
            title="New Message",
            body=payload.body[:120] if payload.body else None,
            notification_type="message",
            reference_id=payload.conversation_id,
            reference_type="conversation",
        )
        db.add(notif)

    db.commit()
    db.refresh(obj)

    # Send FCM push notification to recipient
    if recipient_id:
        try:
            from app.utils.push import notify_user
            preview = (payload.body or "")[:80]
            notify_user(recipient_id, "New Message", preview or "You have a new message", db)
        except Exception:
            pass  # Push failure must never break the message API

    return obj


@router.put("/{message_id}/read", response_model=MessageResponse)
def mark_as_read(message_id: int, db: Session = Depends(get_db)):
    obj = db.query(Message).filter(Message.id == message_id).first()
    if not obj:
        raise HTTPException(status_code=404, detail="Message not found")
    obj.is_read = True
    db.commit()
    db.refresh(obj)
    return obj


class MessageDeleteRequest(BaseModel):
    sender_id: int


class MessageBodyClearRequest(BaseModel):
    sender_id: int
    placeholder: str = "[message body removed]"


class ConversationLocationUpdateRequest(BaseModel):
    actor_id: int
    location: Optional[str] = None


class ConversationDeleteRequest(BaseModel):
    actor_id: int


@router.delete("/{message_id}", status_code=status.HTTP_200_OK)
def delete_message(
    message_id: int,
    payload: MessageDeleteRequest,
    db: Session = Depends(get_db),
):
    """Soft-delete a message.  Only the original sender may delete it."""
    obj = db.query(Message).filter(Message.id == message_id, Message.is_deleted.is_(False)).first()
    if not obj:
        raise HTTPException(status_code=404, detail="Message not found")
    if obj.sender_id != payload.sender_id:
        raise HTTPException(status_code=403, detail="You can only delete your own messages")
    obj.is_deleted = True
    db.commit()
    return {"message": "Message deleted"}


@router.patch("/{message_id}/body", response_model=MessageResponse)
def clear_message_body(
    message_id: int,
    payload: MessageBodyClearRequest,
    db: Session = Depends(get_db),
):
    """Clear only the text body while keeping the message record."""
    obj = db.query(Message).filter(Message.id == message_id, Message.is_deleted.is_(False)).first()
    if not obj:
        raise HTTPException(status_code=404, detail="Message not found")
    if obj.sender_id != payload.sender_id:
        raise HTTPException(status_code=403, detail="You can only edit your own messages")
    stripped = payload.placeholder.strip() if payload.placeholder else ""
    obj.body = stripped or "[message body removed]"
    db.commit()
    db.refresh(obj)
    return obj


@conversations_router.patch("/{conversation_id}/location", response_model=ConversationResponse)
def update_conversation_location(
    conversation_id: int,
    payload: ConversationLocationUpdateRequest,
    db: Session = Depends(get_db),
):
    obj = db.query(Conversation).filter(Conversation.id == conversation_id).first()
    if not obj:
        raise HTTPException(status_code=404, detail="Conversation not found")
    if payload.actor_id not in {obj.initiator_id, obj.recipient_id}:
        raise HTTPException(status_code=403, detail="Not allowed to update this conversation")
    stripped = payload.location.strip() if payload.location else ""
    obj.location = stripped or None
    db.commit()
    db.refresh(obj)
    return obj


@conversations_router.delete("/{conversation_id}", status_code=status.HTTP_200_OK)
def delete_conversation(
    conversation_id: int,
    payload: ConversationDeleteRequest,
    db: Session = Depends(get_db),
):
    obj = db.query(Conversation).filter(Conversation.id == conversation_id).first()
    if not obj:
        raise HTTPException(status_code=404, detail="Conversation not found")
    if payload.actor_id not in {obj.initiator_id, obj.recipient_id}:
        raise HTTPException(status_code=403, detail="Not allowed to delete this conversation")
    db.delete(obj)
    db.commit()
    return {"message": "Conversation deleted"}
