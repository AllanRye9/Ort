from sqlalchemy import Column, Integer, String, Float, DateTime, Text, Boolean, Enum
from sqlalchemy.sql import func
from ..core.database import Base
import enum
import json


class PropertyType(str, enum.Enum):
    RESIDENTIAL = "residential"
    COMMERCIAL = "commercial"
    INDUSTRIAL = "industrial"
    LAND = "land"


class PropertyStatus(str, enum.Enum):
    FOR_SALE = "for_sale"
    FOR_RENT = "for_rent"
    SOLD = "sold"
    RENTED = "rented"
    OFF_MARKET = "off_market"


class Property(Base):
    __tablename__ = "properties"
    
    id = Column(Integer, primary_key=True, index=True)
    title = Column(String(255), nullable=False)
    description = Column(Text)
    property_type = Column(Enum(PropertyType), nullable=False)
    status = Column(Enum(PropertyStatus), default=PropertyStatus.FOR_SALE)
    price = Column(Float, nullable=False)
    address = Column(String(500), nullable=False)
    city = Column(String(100), nullable=False)
    state = Column(String(100))
    zip_code = Column(String(20))
    country = Column(String(100), default="USA")
    latitude = Column(Float)
    longitude = Column(Float)
    bedrooms = Column(Integer)
    bathrooms = Column(Float)
    square_feet = Column(Integer)
    lot_size = Column(Float)
    year_built = Column(Integer)
    # For SQLite, we'll store JSON as Text and handle serialization
    amenities = Column(Text, default="[]")
    features = Column(Text, default="{}")
    images = Column(Text, default="[]")
    virtual_tour_url = Column(String(500))
    ai_valuation = Column(Float)
    market_score = Column(Float)
    investment_potential = Column(Float)
    # risk_assessment as Text for SQLite
    risk_assessment = Column(Text, default="{}")
    zillow_id = Column(String(100))
    redfin_id = Column(String(100))
    mls_number = Column(String(100))
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    last_refreshed = Column(DateTime(timezone=True))
    owner_id = Column(Integer, index=True)
    agent_id = Column(Integer, index=True)
    is_featured = Column(Boolean, default=False)
    is_active = Column(Boolean, default=True)
    views_count = Column(Integer, default=0)