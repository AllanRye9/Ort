"""ORT AI endpoints – description generation and support chat.

Uses the Groq API (free tier, llama-3.3-70b-versatile) when GROQ_API_KEY is set,
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
_MODEL = "llama-3.3-70b-versatile"

_SYSTEM_SUPPORT = (
    "You are ORT AI, the intelligent assistant embedded in the Ort unified commerce platform. "
    "ORT AI supports multiple request types: listing assistance, product & service recommendations, "
    "platform guidance, support queries, and location-aware search. "
    "You are persistent — you remain active until the user explicitly closes you. "
    "Maintain context across the conversation and handle concurrent topics gracefully.\n\n"
    "Ort is a SaaS marketplace that connects buyers and sellers across three verticals:\n"
    "  1. Real Estate / Properties – residential, commercial, and land listings for sale or rent.\n"
    "  2. Agriculture – fresh produce, grains, livestock, processed foods, and agri-inputs sold in bulk.\n"
    "  3. Manufacturing (MFG) – locally-made wholesale products (textiles, electronics, furniture, "
    "metals, chemicals, plastics, automotive parts, food processing goods) and B2B services "
    "(machining, fabrication, welding, assembly, finishing, testing, printing, packaging).\n\n"
    "KEY PLATFORM CONCEPTS:\n"
    "• Listing Code – a unique reference code (e.g. ORT-PROP-2024-AB1C2D) assigned to every "
    "listing. Users can copy it from the detail screen to share or use for support queries.\n"
    "• Marketplace Mode – users can switch between Local (goods in their country) and "
    "International (cross-border, primarily Uganda ↔ UAE) views in Settings. "
    "Local mode requires location access; if denied, the app automatically switches to International mode.\n"
    "• Location Filtering – all listings are filtered by the user's country in Local mode. "
    "In International mode, listings are shown from other countries with all prices converted to USD.\n"
    "• Currency Conversion – International mode converts all listing prices to USD automatically "
    "using up-to-date exchange rates. Original currencies (UGX for Uganda, AED for UAE) are preserved.\n"
    "• Personalization – the home feed ranks listings based on the user's viewing history and "
    "interaction patterns. Listings you have viewed appear first within your location filter.\n"
    "• Bids – buyers can bid on properties. The agent reviews bids and contacts the buyer via Messages.\n"
    "• RFQ (Request for Quote) – buyers send quote requests to MFG sellers.\n"
    "• Orders – buyers can place direct orders on MFG products; tracked through pending → confirmed → "
    "processing → shipped → delivered stages.\n"
    "• Tenant / Organisation – sellers can operate under a tenant account (individual, SME, enterprise, "
    "government, or NGO) with subscription plans (free, professional, enterprise, government).\n"
    "• Currencies – Uganda listings use UGX, UAE listings use AED; International mode shows all in USD.\n"
    "• AI Auto-Fill – when creating a listing, users can tap the ✨ button next to the Description "
    "field to have ORT AI generate a professional description automatically.\n\n"
    "INTELLIGENT SEARCH & INTENT DETECTION:\n"
    "When a user asks a search-type question (e.g. 'cheap land in Kampala', 'maize under $500', "
    "'apartments for rent in UAE', 'tractor parts', 'welding services near me'), you MUST:\n"
    "  1. Detect the intent: search for a listing type (property/agriculture/manufacturing).\n"
    "  2. Extract entities: category, location, price range, keywords, unit of measure.\n"
    "  3. Recognise synonyms: 'land' = property (land type), 'maize/corn/ugali base' = agriculture, "
    "'apartment/flat/unit' = property (residential), 'tractor' = agriculture or manufacturing, "
    "'cheap/affordable/budget' = low price filter, 'near me/nearby/local' = Local mode filter.\n"
    "  4. Respond with:\n"
    "     a. A clear interpretation of what the user is looking for.\n"
    "     b. Suggested search terms and filters to apply in the app (category, location, max price).\n"
    "     c. Navigation guidance: which screen/tab to open (Properties, Agriculture, or Manufacturing).\n"
    "     d. If the listing code pattern is detected (e.g. ORT-PROP-...), explain how to search by it.\n"
    "  5. Keep responses concise and actionable — no lengthy paragraphs for search intents.\n\n"
    "HOW TO HANDLE REQUEST TYPES:\n"
    "• Support queries: Gather details about the issue and suggest concrete steps to resolve it.\n"
    "• Recommendations: Use context (location, category, price range) to suggest relevant listings.\n"
    "• Listing assistance: Help users write better titles, descriptions, and set competitive prices.\n"
    "• System guidance: Explain features, navigation, modes, permissions, and billing clearly.\n"
    "• Search help: Interpret the user's natural language query, map it to app filters, and guide them "
    "to the right screen. Always suggest switching to the correct marketplace mode if needed.\n\n"
    "Always be helpful, concise, and accurate. Never make up specific listing details you don't have. "
    "For issues you cannot resolve, direct users to Messages or support@ort.app."
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
        "max_tokens": 1024,
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
    loc = f" in {req.location}" if req.location else ""
    cat = f" ({req.category})" if req.category else ""
    if req.listing_type == "property":
        return (
            f"**Overview**\n{req.title} is a well-positioned property{loc} offering excellent "
            f"value in a competitive market{cat}.\n\n"
            "**Key Features**\nThis property features a practical layout, quality finishes, "
            "and convenient access to essential amenities including transport links, schools, "
            "and commercial facilities.\n\n"
            "**Value Proposition**\nIdeal for owner-occupiers and investors alike, this listing "
            "presents a compelling opportunity with strong rental yield potential and long-term "
            "capital appreciation in a growing area."
        )
    elif req.listing_type == "agriculture":
        return (
            f"**Overview**\n{req.title} is a high-quality agricultural commodity{cat} sourced "
            f"directly from trusted producers{loc}.\n\n"
            "**Quality & Specifications**\nThis commodity meets industry-standard grading "
            "requirements and is available in bulk quantities with flexible packaging options. "
            "Handled under proper storage conditions to maintain freshness and shelf life.\n\n"
            "**Supply & Value**\nCompetitively priced with reliable supply continuity. "
            "Suitable for processors, wholesalers, and exporters seeking consistent quality "
            "at favourable terms. Minimum order quantities available on request."
        )
    elif req.listing_type == "manufacturing_product":
        return (
            f"**Overview**\n{req.title} is a locally manufactured{cat} product{loc} designed "
            "to meet the demands of B2B buyers across various industries.\n\n"
            "**Specifications & Features**\nProduced to consistent quality standards with "
            "durable materials and precise manufacturing tolerances. Available in standard "
            "configurations with custom sizing or branding options on request.\n\n"
            "**Use Cases & Benefits**\nSuited to a wide range of commercial and industrial "
            "applications. Benefits include short lead times, competitive wholesale pricing, "
            "and the reliability of locally sourced production."
        )
    elif req.listing_type == "manufacturing_service":
        return (
            f"**Overview**\n{req.title} is a professional manufacturing service{cat} "
            f"delivered by an experienced team{loc}.\n\n"
            "**Capabilities & Specifications**\nEquipped with modern machinery capable of "
            "handling a variety of materials and project scales. Turnaround times are "
            "competitive and quality checks are performed at every production stage.\n\n"
            "**Benefits & Value Proposition**\nClients benefit from precision workmanship, "
            "flexible project intake, and transparent pricing. Ideal for businesses seeking "
            "a dependable local manufacturing partner for both prototyping and production runs."
        )
    parts = [f"{req.title}"]
    if req.category:
        parts.append(f"Category: {req.category}.")
    if req.location:
        parts.append(f"Located in {req.location}.")
    parts.append("Contact us for more information.")
    return " ".join(parts)


@router.post("/generate-description", response_model=DescriptionResponse)
async def generate_description(req: DescriptionRequest):
    """Generate an AI description for a listing based on basic details."""
    listing_label = req.listing_type.replace('_', ' ')

    if req.listing_type == "property":
        instructions = (
            "Write a detailed, professional real-estate listing description. "
            "Structure it with three clearly labelled sections:\n"
            "1. Overview – introduce the property (type, general character, standout appeal).\n"
            "2. Key Features – bullet or prose covering location, size, layout, rooms, amenities, "
            "and any notable highlights (pool, parking, views, security, etc.).\n"
            "3. Value Proposition – explain why this is a compelling buy or rental opportunity "
            "(investment potential, lifestyle fit, or competitive pricing).\n"
            "Be specific, evocative, and factual. Aim for 120-180 words total."
        )
    elif req.listing_type == "agriculture":
        instructions = (
            "Write a detailed, professional agricultural commodity listing description. "
            "Structure it with three clearly labelled sections:\n"
            "1. Overview – describe the commodity (type, variety, origin region, and intended use).\n"
            "2. Quality & Specifications – cover grade, certification, moisture content, "
            "packaging, storage conditions, harvest season, and any distinguishing quality markers.\n"
            "3. Supply & Value – highlight quantity availability, minimum order, lead time, "
            "and why buyers should choose this supplier (reliability, freshness, competitive price).\n"
            "Be specific and factual. Aim for 120-180 words total."
        )
    elif req.listing_type == "manufacturing_product":
        instructions = (
            "Write a detailed, professional B2B manufacturing product listing description. "
            "Structure it with three clearly labelled sections:\n"
            "1. Overview – describe the product, its primary function, and target industry.\n"
            "2. Specifications & Features – cover materials, dimensions, capacity, tolerances, "
            "standards compliance, certifications, and manufacturing process if relevant.\n"
            "3. Use Cases & Benefits – explain the main applications, the problems it solves, "
            "and why buyers should source from this manufacturer "
            "(lead time, local production, custom orders, pricing competitiveness).\n"
            "Be specific and factual. Aim for 120-180 words total."
        )
    elif req.listing_type == "manufacturing_service":
        instructions = (
            "Write a detailed, professional B2B manufacturing service listing description. "
            "Structure it with three clearly labelled sections:\n"
            "1. Overview – describe the service, the technology or method used, and target clients.\n"
            "2. Capabilities & Specifications – cover equipment, capacity, tolerances, turnaround "
            "time, materials handled, and any quality certifications.\n"
            "3. Benefits & Value Proposition – explain key advantages "
            "(speed, precision, cost-efficiency, local availability, custom work capability) "
            "and types of projects best suited to this provider.\n"
            "Be specific and factual. Aim for 120-180 words total."
        )
    else:
        instructions = (
            "Write a detailed, professional marketplace listing description with three sections: "
            "Overview, Key Features, and Value Proposition. Aim for 120-180 words."
        )

    prompt = f"{instructions}\n\nListing title: '{req.title}'."
    if req.category:
        prompt += f"\nCategory: {req.category}."
    if req.location:
        prompt += f"\nLocation: {req.location}."
    if req.extra_context:
        prompt += f"\nAdditional details: {req.extra_context}."
    prompt += "\n\nWrite the description now:"

    try:
        text = await _groq_chat(
            "You are an expert marketplace listing copywriter specialising in B2B commerce.",
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
