"""ORT AI endpoints – description generation and support chat.

Uses the Groq API (free tier, llama3-8b-8192) when GROQ_API_KEY is set,
otherwise falls back to a simple rule-based stub so the app still works
without an API key configured.
"""
import os
import re
from typing import List, Optional

import httpx
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel

router = APIRouter(prefix="/ai", tags=["ai"])

_GROQ_API_KEY = os.getenv("GROQ_API_KEY", "")
_GROQ_BASE = "https://api.groq.com/openai/v1"
_MODEL = "llama3-8b-8192"

_SYSTEM_SUPPORT = (
    "You are ORT AI, the intelligent assistant for the Ort unified commerce platform. "
    "Ort connects buyers and sellers of real estate, agricultural produce, and "
    "manufactured goods across Uganda and internationally. "
    "You help users navigate the platform, answer product questions, assist with "
    "listings, explain pricing, guide through orders, and resolve support issues. "
    "Always be helpful, concise, and friendly. When you don't know something specific "
    "about a listing, guide the user to contact the seller directly."
)


class DescriptionRequest(BaseModel):
    listing_type: str          # "property" | "agriculture" | "manufacturing_product" | "manufacturing_service"
    title: str
    category: Optional[str] = None
    location: Optional[str] = None
    extra_context: Optional[str] = None


class DescriptionResponse(BaseModel):
    description: str


class ChatMessage(BaseModel):
    role: str   # "user" | "model"
    text: str


class ChatRequest(BaseModel):
    messages: List[ChatMessage]


class ChatResponse(BaseModel):
    reply: str


async def _groq_chat(system: str, messages: list[dict]) -> str:
    """Call Groq chat completion endpoint. Returns the assistant text."""
    if not _GROQ_API_KEY:
        raise RuntimeError("GROQ_API_KEY not configured")
    payload = {
        "model": _MODEL,
        "messages": [{"role": "system", "content": system}] + messages,
        "max_tokens": 500,
        "temperature": 0.7,
    }
    async with httpx.AsyncClient(timeout=30) as client:
        resp = await client.post(
            f"{_GROQ_BASE}/chat/completions",
            json=payload,
            headers={"Authorization": f"Bearer {_GROQ_API_KEY}"},
        )
    if resp.status_code != 200:
        raise RuntimeError(f"Groq API error {resp.status_code}: {resp.text[:200]}")
    data = resp.json()
    return data["choices"][0]["message"]["content"].strip()


def _stub_description(req: DescriptionRequest) -> str:
    """Fallback description when no AI key is configured."""
    parts = [f"{req.title}"]
    if req.category:
        parts.append(f"Category: {req.category}.")
    if req.location:
        parts.append(f"Located in {req.location}.")
    if req.listing_type == "property":
        parts.append("This property offers great value and is ready for viewing.")
    elif req.listing_type == "agriculture":
        parts.append("Fresh, high-quality produce available for bulk purchase.")
    elif req.listing_type == "manufacturing_product":
        parts.append("Locally manufactured product meeting quality standards.")
    elif req.listing_type == "manufacturing_service":
        parts.append("Professional service with experienced staff and modern equipment.")
    return " ".join(parts)


@router.post("/generate-description", response_model=DescriptionResponse)
async def generate_description(req: DescriptionRequest):
    """Generate an AI description for a listing based on basic details."""
    prompt = (
        f"Write a concise, professional marketplace listing description (2-4 sentences) "
        f"for a {req.listing_type.replace('_', ' ')} titled '{req.title}'."
    )
    if req.category:
        prompt += f" Category: {req.category}."
    if req.location:
        prompt += f" Location: {req.location}."
    if req.extra_context:
        prompt += f" Additional details: {req.extra_context}."
    prompt += " Keep it factual, attractive to buyers, and under 80 words."

    try:
        text = await _groq_chat(
            "You are a professional marketplace listing copywriter.",
            [{"role": "user", "content": prompt}],
        )
    except RuntimeError:
        text = _stub_description(req)

    # Strip any surrounding quotes the model may add
    text = re.sub(r'^["\']|["\']$', '', text.strip())
    return DescriptionResponse(description=text)


@router.post("/chat", response_model=ChatResponse)
async def ai_chat(req: ChatRequest):
    """ORT AI support chat. Accepts a conversation history and returns the next reply."""
    if not req.messages:
        raise HTTPException(status_code=400, detail="messages must not be empty")

    groq_messages = []
    for m in req.messages:
        role = "user" if m.role in ("user", "human") else "assistant"
        groq_messages.append({"role": role, "content": m.text})

    try:
        reply = await _groq_chat(_SYSTEM_SUPPORT, groq_messages)
    except RuntimeError:
        # Graceful fallback
        reply = (
            "I'm the ORT AI assistant. I'm currently operating in limited mode. "
            "For immediate help, please contact our support team via the platform's "
            "Messages feature or email support@ort.app."
        )

    return ChatResponse(reply=reply)
