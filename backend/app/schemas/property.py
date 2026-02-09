from pydantic import BaseModel, Field, field_validator
from typing import Optional
from datetime import datetime, date


class PropertyBase(BaseModel):
    """Base property schema"""
    title: str
    description: Optional[str] = None
    property_type: str
    address: str
    city: Optional[str] = None
    price: float
    bedrooms: Optional[int] = None
    bathrooms: Optional[int] = None
    area_sqft: Optional[int] = None


class PropertyCreate(PropertyBase):
    """Schema for creating a new property"""
    agent_id: Optional[int] = None
    owner_id: Optional[int] = None
    property_type: str = Field(..., pattern="^(house|apartment|land|commercial)$")
    price: float = Field(..., gt=0)
    bedrooms: Optional[int] = Field(None, ge=0)
    bathrooms: Optional[int] = Field(None, ge=0)
    area_sqft: Optional[int] = Field(None, gt=0)

    @field_validator("title", "address")
    @classmethod
    def no_blank(cls, value):
        if not value or not value.strip():
            raise ValueError("Field cannot be blank")
        return value.strip()


class PropertyResponse(PropertyBase):
    """Schema for property response"""
    id: int
    status: str
    created_at: datetime

    model_config = {"from_attributes": True}


class PropertyImageBase(BaseModel):
    """Base property image schema"""
    image_url: str
    is_primary: Optional[bool] = False


class PropertyImageCreate(PropertyImageBase):
    """Schema for creating a property image"""
    property_id: int


class PropertyImageResponse(PropertyImageBase):
    """Schema for property image response"""
    id: int

    model_config = {"from_attributes": True}


class ListingBase(BaseModel):
    """Base listing schema"""
    listing_type: str
    listed_price: float
    listing_date: date
    expiry_date: Optional[date] = None


class ListingCreate(ListingBase):
    """Schema for creating a listing"""
    property_id: int
    listing_type: str = Field(..., pattern="^(sale|rent)$")
    listed_price: float = Field(..., gt=0)


class ListingResponse(ListingBase):
    """Schema for listing response"""
    id: int

    model_config = {"from_attributes": True}


class InquiryBase(BaseModel):
    """Base inquiry schema"""
    message: Optional[str] = None


class InquiryCreate(InquiryBase):
    """Schema for creating an inquiry"""
    property_id: int
    client_id: Optional[int] = None


class InquiryResponse(InquiryBase):
    """Schema for inquiry response"""
    id: int
    status: str
    created_at: datetime

    model_config = {"from_attributes": True}


class AppointmentBase(BaseModel):
    """Base appointment schema"""
    appointment_date: datetime


class AppointmentCreate(AppointmentBase):
    """Schema for creating an appointment"""
    property_id: int
    agent_id: int
    client_id: int


class AppointmentResponse(AppointmentBase):
    """Schema for appointment response"""
    id: int
    status: str

    model_config = {"from_attributes": True}
