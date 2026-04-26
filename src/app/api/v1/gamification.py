"""XP, leaderboard, badges, and daily challenge endpoints."""
import math
import logging
from typing import List

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.orm import Session

from app.database.database import get_db
from app.models.models import User
from app.models.gamification_models import (
    UserXP, Badge, UserBadge, DailyChallenge, UserChallengeProgress,
)
from app.schemas.gamification_schemas import (
    XPAwardRequest, XPAwardResponse,
    LeaderboardResponse, LeaderboardEntry,
    BadgeResponse, ChallengeProgressResponse,
)
from app.api.v1.api import _get_current_user

router = APIRouter(prefix="/gamification", tags=["gamification"])
logger = logging.getLogger(__name__)

_XP_PER_LEVEL = 100


def _calculate_level(xp: int) -> int:
    return max(1, math.floor(math.sqrt(xp / _XP_PER_LEVEL)))


def _award_xp_internal(db: Session, user_id: int, amount: int) -> UserXP:
    record = db.query(UserXP).filter(UserXP.user_id == user_id).first()
    if not record:
        record = UserXP(user_id=user_id, xp_total=0, level=1)
        db.add(record)
    record.xp_total = (record.xp_total or 0) + amount
    record.level = _calculate_level(record.xp_total)
    db.commit()
    db.refresh(record)
    return record


@router.post("/xp/award", response_model=XPAwardResponse)
def award_xp(
    payload: XPAwardRequest,
    current_user: User = Depends(_get_current_user),
    db: Session = Depends(get_db),
):
    """Award XP to a user. Restricted to admin role."""
    if current_user.role != "admin":
        raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Admin role required")
    record = _award_xp_internal(db, payload.user_id, payload.amount)
    return XPAwardResponse(
        user_id=payload.user_id,
        xp_total=record.xp_total,
        level=record.level,
        xp_gained=payload.amount,
    )


@router.get("/leaderboard", response_model=LeaderboardResponse)
def get_leaderboard(
    scope: str = Query("global", pattern="^(global|company|organization)$"),
    limit: int = Query(20, ge=1, le=100),
    db: Session = Depends(get_db),
):
    """Return XP leaderboard."""
    q = (
        db.query(UserXP, User)
        .join(User, UserXP.user_id == User.id)
        .order_by(UserXP.xp_total.desc())
        .limit(limit)
    )
    if scope in ("company", "organization"):
        q = q.filter(User.role == scope)

    entries = []
    for rank, (xp_row, user_row) in enumerate(q.all(), start=1):
        entries.append(
            LeaderboardEntry(
                rank=rank,
                user_id=user_row.id,
                first_name=user_row.first_name,
                last_name=user_row.last_name,
                xp_total=xp_row.xp_total,
                level=xp_row.level,
            )
        )
    return LeaderboardResponse(scope=scope, entries=entries)


@router.get("/badges/me", response_model=List[BadgeResponse])
def my_badges(
    current_user: User = Depends(_get_current_user),
    db: Session = Depends(get_db),
):
    rows = (
        db.query(UserBadge, Badge)
        .join(Badge, UserBadge.badge_id == Badge.id)
        .filter(UserBadge.user_id == current_user.id)
        .all()
    )
    result = []
    for ub, badge in rows:
        result.append(
            BadgeResponse(
                id=badge.id,
                name=badge.name,
                description=badge.description,
                icon_url=badge.icon_url,
                criteria_json=badge.criteria_json,
                awarded_at=ub.awarded_at,
            )
        )
    return result


@router.get("/challenges/today", response_model=List[ChallengeProgressResponse])
def get_today_challenges(
    current_user: User = Depends(_get_current_user),
    db: Session = Depends(get_db),
):
    """Return active daily challenges with the current user's progress."""
    challenges = (
        db.query(DailyChallenge)
        .filter(DailyChallenge.is_active == True)  # noqa: E712
        .all()
    )
    result = []
    for ch in challenges:
        prog = (
            db.query(UserChallengeProgress)
            .filter(
                UserChallengeProgress.user_id == current_user.id,
                UserChallengeProgress.challenge_id == ch.id,
            )
            .first()
        )
        progress_val = prog.progress if prog else 0
        completed = (prog.completed_at is not None) if prog else False
        result.append(
            ChallengeProgressResponse(
                challenge_id=ch.id,
                description=ch.description,
                goal_type=ch.goal_type,
                goal_value=ch.goal_value,
                xp_reward=ch.xp_reward,
                progress=progress_val,
                completed=completed,
            )
        )
    return result


@router.get("/xp/me", response_model=XPAwardResponse)
def my_xp(
    current_user: User = Depends(_get_current_user),
    db: Session = Depends(get_db),
):
    record = db.query(UserXP).filter(UserXP.user_id == current_user.id).first()
    return XPAwardResponse(
        user_id=current_user.id,
        xp_total=record.xp_total if record else 0,
        level=record.level if record else 1,
        xp_gained=0,
    )
