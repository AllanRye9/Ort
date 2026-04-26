"""Pydantic schemas for gamification, admin, GDPR, WebSocket."""
from typing import Any, Dict, List, Optional
from datetime import datetime

from pydantic import BaseModel, Field


# ========== XP & LEVELS ==========

class XPAwardRequest(BaseModel):
    user_id: int
    amount: int = Field(..., gt=0)
    reason: str = ""


class XPAwardResponse(BaseModel):
    user_id: int
    xp_total: int
    level: int
    xp_gained: int


class LeaderboardEntry(BaseModel):
    rank: int
    user_id: int
    first_name: str
    last_name: str
    xp_total: int
    level: int


class LeaderboardResponse(BaseModel):
    scope: str
    entries: List[LeaderboardEntry]


# ========== BADGES ==========

class BadgeResponse(BaseModel):
    id: int
    name: str
    description: Optional[str] = None
    icon_url: Optional[str] = None
    criteria_json: Optional[Dict[str, Any]] = None
    awarded_at: Optional[datetime] = None

    model_config = {"from_attributes": True}


# ========== DAILY CHALLENGES ==========

class ChallengeProgressResponse(BaseModel):
    challenge_id: int
    description: str
    goal_type: str
    goal_value: int
    xp_reward: int
    progress: int
    completed: bool

    model_config = {"from_attributes": True}


# ========== IMAGE RECORD ==========

class ImageRecordResponse(BaseModel):
    id: int
    url: str
    moderation_status: str
    tags: Optional[List[str]] = None
    created_at: datetime

    model_config = {"from_attributes": True}


# ========== AUDIT ==========

class AuditEventResponse(BaseModel):
    id: int
    actor_id: Optional[int] = None
    action: str
    target_type: Optional[str] = None
    target_id: Optional[int] = None
    metadata_json: Optional[Dict[str, Any]] = None
    created_at: datetime

    model_config = {"from_attributes": True}


# ========== ADMIN ANALYTICS ==========

class EngagementStats(BaseModel):
    dau: int
    mau: int
    uploads_today: int
    messages_today: int
    new_users_today: int


class ChurnRiskUser(BaseModel):
    user_id: int
    email: str
    last_active: Optional[datetime] = None
    days_inactive: int

# ========== GDPR ==========

VALID_CONSENT_TYPES = {"privacy_policy", "marketing", "analytics"}
_CONSENT_PATTERN = "^(" + "|".join(sorted(VALID_CONSENT_TYPES)) + ")$"


class ConsentCreate(BaseModel):
    consent_type: str = Field(..., pattern=_CONSENT_PATTERN)
    version: str


class ConsentResponse(BaseModel):
    id: int
    user_id: int
    consent_type: str
    version: str
    accepted_at: datetime

    model_config = {"from_attributes": True}


# ========== ONBOARDING ==========

class OnboardingUpdate(BaseModel):
    step: int = Field(..., ge=0)
    completed: Optional[bool] = False


class OnboardingResponse(BaseModel):
    user_id: int
    onboarding_step: int
    onboarding_completed: bool


# ========== DASHBOARD ==========

class DashboardStats(BaseModel):
    role: str
    user_id: int
    recent_activity: List[Dict[str, Any]] = []
    stats: Dict[str, Any] = {}
    xp_total: Optional[int] = None
    level: Optional[int] = None
