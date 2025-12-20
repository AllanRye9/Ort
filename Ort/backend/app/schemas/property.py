from pydantic import BaseModel, Field, validator
from typing import Optional, List, Dict, Any
from datetime import datetime
from enum import Enum


class PropertyType(str, Enum):
    RESIDENTIAL = "residential"
    COMMERCIAL = "commercial"
    INDUSTRIAL = "industrial"
    LAND = "land"


class PropertyStatus(str, Enum):
    FOR_SALE = "for_sale"
    FOR_RENT = "for_rent"
    SOLD = "sold"
    RENTED = "rented"
    OFF_MARKET = "off_market"


class PropertyBase(BaseModel):
    title: str = Field(..., min_length=5, max_length=255)
    description: Optional[str] = None
    property_type: PropertyType
    status: PropertyStatus = PropertyStatus.FOR_SALE
    price: float = Field(..., gt=0)
    address: str
    city: str
    state: Optional[str] = None
    zip_code: Optional[str] = None
    country: str = "USA"
    latitude: Optional[float] = Field(None, ge=-90, le=90)
    longitude: Optional[float] = Field(None, ge=-180, le=180)
    bedrooms: Optional[int] = Field(None, ge=0)
    bathrooms: Optional[float] = Field(None, ge=0)
    square_feet: Optional[int] = Field(None, ge=0)
    lot_size: Optional[float] = Field(None, ge=0)
    year_built: Optional[int] = None
    amenities: List[str] = []
    features: Dict[str, Any] = {}


class PropertyCreate(PropertyBase):
    pass


class PropertyUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    price: Optional[float] = None
    status: Optional[PropertyStatus] = None
    bedrooms: Optional[int] = None
    bathrooms: Optional[float] = None
    square_feet: Optional[int] = None
    amenities: Optional[List[str]] = None
    is_active: Optional[bool] = None


class PropertyInDB(PropertyBase):
    id: int
    owner_id: Optional[int] = None
    agent_id: Optional[int] = None
    is_featured: bool = False
    is_active: bool = True
    views_count: int = 0
    created_at: datetime
    updated_at: Optional[datetime] = None
    
    class Config:
        from_attributes = True


class PropertySearch(BaseModel):
    min_price: Optional[float] = Field(None, ge=0)
    max_price: Optional[float] = Field(None, ge=0)
    property_type: Optional[PropertyType] = None
    bedrooms_min: Optional[int] = Field(None, ge=0)
    bedrooms_max: Optional[int] = Field(None, ge=0)
    city: Optional[str] = None
    state: Optional[str] = None
    page: int = Field(1, ge=1)
    limit: int = Field(20, ge=1, le=100)
    sort_by: str = "created_at"
    sort_order: str = "desc"
    
    @validator('sort_order')
    def validate_sort_order(cls, v):
        if v not in ['asc', 'desc']:
            raise ValueError('sort_order must be "asc" or "desc"')
        return v