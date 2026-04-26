"""
Gamification models: XP, badges, daily challenges, image records, audit events,
GDPR consents.
"""
from sqlalchemy import (
    Column, Integer, String, Text, Date, DateTime,
    Boolean, ForeignKey, Index, JSON, Float,
)
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func

from ..database.database import Base


class UserXP(Base):
    __tablename__ = "user_xp"
    __table_args__ = (Index("ix_user_xp_user_id", "user_id"),)

    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), unique=True)
    xp_total = Column(Integer, default=0, server_default="0", nullable=False)
    level = Column(Integer, default=1, server_default="1", nullable=False)
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())

    user = relationship("User", foreign_keys=[user_id])


class Badge(Base):
    __tablename__ = "badges"

    id = Column(Integer, primary_key=True)
    name = Column(String(100), nullable=False, unique=True)
    description = Column(Text)
    icon_url = Column(Text)
    criteria_json = Column(JSON)
    created_at = Column(DateTime, server_default=func.now())

    user_badges = relationship("UserBadge", back_populates="badge")


class UserBadge(Base):
    __tablename__ = "user_badges"
    __table_args__ = (
        Index("ix_user_badges_user_id", "user_id"),
        Index("ix_user_badges_badge_id", "badge_id"),
    )

    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"))
    badge_id = Column(Integer, ForeignKey("badges.id", ondelete="CASCADE"))
    awarded_at = Column(DateTime, server_default=func.now())

    user = relationship("User", foreign_keys=[user_id])
    badge = relationship("Badge", back_populates="user_badges")


class DailyChallenge(Base):
    __tablename__ = "daily_challenges"

    id = Column(Integer, primary_key=True)
    description = Column(Text, nullable=False)
    goal_type = Column(String(50), nullable=False)  # upload, message, profile_complete, etc.
    goal_value = Column(Integer, nullable=False, default=1)
    xp_reward = Column(Integer, nullable=False, default=10)
    is_active = Column(Boolean, default=True, server_default="true", nullable=False)
    created_at = Column(DateTime, server_default=func.now())

    progress = relationship("UserChallengeProgress", back_populates="challenge")


class UserChallengeProgress(Base):
    __tablename__ = "user_challenge_progress"
    __table_args__ = (
        Index("ix_ucp_user_id", "user_id"),
        Index("ix_ucp_challenge_id", "challenge_id"),
    )

    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"))
    challenge_id = Column(Integer, ForeignKey("daily_challenges.id", ondelete="CASCADE"))
    progress = Column(Integer, default=0, server_default="0", nullable=False)
    completed_at = Column(DateTime, nullable=True)

    user = relationship("User", foreign_keys=[user_id])
    challenge = relationship("DailyChallenge", back_populates="progress")


class ImageRecord(Base):
    """Tracks uploaded images for moderation and tagging."""
    __tablename__ = "image_records"
    __table_args__ = (
        Index("ix_image_records_user_id", "user_id"),
        Index("ix_image_records_moderation_status", "moderation_status"),
    )

    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    url = Column(Text, nullable=False)
    moderation_status = Column(
        String(20), default="pending", server_default="pending", nullable=False
    )
    tags = Column(JSON, default=lambda: [])
    duration_seconds = Column(Float, nullable=True)  # for voice messages
    created_at = Column(DateTime, server_default=func.now())

    user = relationship("User", foreign_keys=[user_id])


class AuditEvent(Base):
    """Audit log for admin-sensitive mutations."""
    __tablename__ = "audit_events"
    __table_args__ = (
        Index("ix_audit_events_actor_id", "actor_id"),
        Index("ix_audit_events_target_type", "target_type"),
        Index("ix_audit_events_created_at", "created_at"),
    )

    id = Column(Integer, primary_key=True)
    actor_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    action = Column(String(100), nullable=False)
    target_type = Column(String(50))
    target_id = Column(Integer)
    metadata_json = Column(JSON)
    created_at = Column(DateTime, server_default=func.now())

    actor = relationship("User", foreign_keys=[actor_id])


class Consent(Base):
    """GDPR/CCPA consent records."""
    __tablename__ = "consents"
    __table_args__ = (
        Index("ix_consents_user_id", "user_id"),
    )

    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"))
    consent_type = Column(String(50), nullable=False)  # privacy_policy, marketing, analytics
    version = Column(String(20), nullable=False)
    accepted_at = Column(DateTime, server_default=func.now())

    user = relationship("User", foreign_keys=[user_id])
