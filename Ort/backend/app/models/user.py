from sqlalchemy import Column, Integer, String, Boolean, DateTime, Enum, JSON, Text, Float
from sqlalchemy.sql import func
from ..core.database import Base
import enum


class UserRole(str, enum.Enum):
    ADMIN = "admin"
    AGENT = "agent"
    BUYER = "buyer"
    SELLER = "seller"
    INVESTOR = "investor"


class User(Base):
    __tablename__ = "users"
    
    id = Column(Integer, primary_key=True, index=True)
    email = Column(String(255), unique=True, index=True, nullable=False)
    username = Column(String(100), unique=True, index=True)
    hashed_password = Column(String(255), nullable=False)
    full_name = Column(String(255))
    phone = Column(String(50))
    role = Column(Enum(UserRole), default=UserRole.BUYER)
    is_active = Column(Boolean, default=True)
    is_verified = Column(Boolean, default=False)
    is_premium = Column(Boolean, default=False)
    profile_picture = Column(String(500))
    bio = Column(Text)
    preferences = Column(JSON, default={})
    saved_properties = Column(JSON, default=[])
    search_history = Column(JSON, default=[])
    city = Column(String(100))
    state = Column(String(100))
    country = Column(String(100))
    license_number = Column(String(100))
    company = Column(String(255))
    years_experience = Column(Integer)
    specialties = Column(JSON, default=[])
    investment_budget_min = Column(Float)
    investment_budget_max = Column(Float)
    investment_preferences = Column(JSON, default={})
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    last_login = Column(DateTime(timezone=True))
    subscription_tier = Column(String(50))
    subscription_expires = Column(DateTime(timezone=True))