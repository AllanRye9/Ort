"""Messaging router (conversations & messages)."""
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session
from typing import List, Optional

from app.database.database import get_db
from app.models.marketplace_models import Conversation, Message
from app.schemas.marketplace_schemas import (
    ConversationCreate, ConversationResponse,
    MessageCreate, MessageResponse,
)

# conversations live at /api/v1/messages/conversations/
# messages live at /api/v1/messages/
conversations_router = APIRouter(prefix="/messages/conversations", tags=["conversations"])
router = APIRouter(prefix="/messages", tags=["messages"])


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
    obj = Conversation(**payload.model_dump())
    db.add(obj)
    db.commit()
    db.refresh(obj)
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
        .filter(Message.conversation_id == conversation_id)
        .order_by(Message.sent_at.asc())
        .offset(skip)
        .limit(limit)
        .all()
    )


@router.post("/", response_model=MessageResponse, status_code=status.HTTP_201_CREATED)
def send_message(payload: MessageCreate, db: Session = Depends(get_db)):
    # Verify conversation exists
    conv = db.query(Conversation).filter(Conversation.id == payload.conversation_id).first()
    if not conv:
        raise HTTPException(status_code=404, detail="Conversation not found")
    obj = Message(**payload.model_dump())
    db.add(obj)
    db.commit()
    db.refresh(obj)
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
