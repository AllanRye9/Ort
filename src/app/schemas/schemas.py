from decimal import Decimal
from typing import Any, Dict, List, Optional
from datetime import datetime, date

from pydantic import BaseModel, Field, EmailStr, field_validator


# ========== USER ==========

class UserBase(BaseModel):
    role: str
    first_name: str
    last_name: str
    email: EmailStr
    phone: Optional[str] = None


class UserCreate(UserBase):
    role: str = Field(..., pattern="^(user|agent|admin|company|organization)$")
    first_name: str = Field(..., min_length=2, max_length=100)
    last_name: str = Field(..., min_length=2, max_length=100)
    phone: Optional[str] = Field(None, max_length=20)
    password: str = Field(..., min_length=8, max_length=128)

    @field_validator("first_name", "last_name", mode="before")
    @classmethod
    def no_blank(cls, value: str) -> str:
        if not value or not value.strip():
            raise ValueError("Field cannot be blank")
        return value.strip()


class UserUpdate(BaseModel):
    role: Optional[str] = Field(None, pattern="^(user|agent|admin|company|organization)$")
    first_name: Optional[str] = Field(None, min_length=2, max_length=100)
    last_name: Optional[str] = Field(None, min_length=2, max_length=100)
    email: Optional[EmailStr] = None
    phone: Optional[str] = Field(None, max_length=20)
    password: Optional[str] = Field(None, min_length=8, max_length=128)
    bio: Optional[str] = None
    avatar_url: Optional[str] = None
    license_number: Optional[str] = Field(None, max_length=100)
    agency_name: Optional[str] = Field(None, max_length=255)

    @field_validator("first_name", "last_name", mode="before")
    @classmethod
    def no_blank(cls, value: Optional[str]) -> Optional[str]:
        if value is not None and not value.strip():
            raise ValueError("Field cannot be blank")
        return value.strip() if value else value


class UserResponse(UserBase):
    id: int
    license_number: Optional[str] = None
    agency_name: Optional[str] = None
    bio: Optional[str] = None
    avatar_url: Optional[str] = None
    nationality: Optional[str] = None
    residing_country: Optional[str] = None
    user_uid: Optional[str] = None
    created_at: datetime

    model_config = {"from_attributes": True}


# ========== CLIENT ==========

class ClientBase(BaseModel):
    first_name: str
    last_name: str
    email: Optional[EmailStr] = None
    phone: Optional[str] = None
    client_type: str


class ClientCreate(ClientBase):
    agent_id: Optional[int] = None
    client_type: str = Field(..., pattern="^(buyer|seller|renter)$")

    @field_validator("first_name", "last_name", mode="before")
    @classmethod
    def no_blank(cls, value: str) -> str:
        if not value or not value.strip():
            raise ValueError("Field cannot be blank")
        return value.strip()


class ClientUpdate(BaseModel):
    agent_id: Optional[int] = None
    first_name: Optional[str] = Field(None, min_length=2, max_length=100)
    last_name: Optional[str] = Field(None, min_length=2, max_length=100)
    email: Optional[EmailStr] = None
    phone: Optional[str] = Field(None, max_length=20)
    client_type: Optional[str] = Field(None, pattern="^(buyer|seller|renter)$")

    @field_validator("first_name", "last_name", mode="before")
    @classmethod
    def no_blank(cls, value: Optional[str]) -> Optional[str]:
        if value is not None and not value.strip():
            raise ValueError("Field cannot be blank")
        return value.strip() if value else value


class ClientResponse(ClientBase):
    id: int
    created_at: datetime

    model_config = {"from_attributes": True}


# ========== PROPERTY ==========

class PropertyBase(BaseModel):
    title: str
    description: Optional[str] = None
    property_type: str
    address: str
    city: Optional[str] = None
    price: Decimal
    bedrooms: Optional[int] = None
    bathrooms: Optional[int] = None
    area_sqft: Optional[int] = None
    country: Optional[str] = None
    plot_length_m: Optional[float] = None
    plot_width_m: Optional[float] = None
    land_category: Optional[str] = None
    land_area_acres: Optional[float] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    # Extended listing fields
    property_age: Optional[int] = None
    furnishing: Optional[str] = None
    purpose: Optional[str] = None
    amenities: Optional[List[str]] = None
    floors: Optional[int] = None
    building_name: Optional[str] = None
    parking_spaces: Optional[int] = None


class PropertyCreate(PropertyBase):
    agent_id: Optional[int] = None
    owner_id: Optional[int] = None
    property_type: str = Field(..., pattern="^(house|apartment|land|commercial|villa|office|warehouse|other)$")
    price: Decimal = Field(..., gt=0)
    bedrooms: Optional[int] = Field(None, ge=0)
    bathrooms: Optional[int] = Field(None, ge=0)
    area_sqft: Optional[int] = Field(None, gt=0)
    plot_length_m: Optional[float] = Field(None, gt=0)
    plot_width_m: Optional[float] = Field(None, gt=0)
    land_category: Optional[str] = Field(None, pattern="^(farmland|residential|industrial|other)$")
    land_area_acres: Optional[float] = Field(None, gt=0)
    images: Optional[List[str]] = None
    # Extended fields
    property_age: Optional[int] = Field(None, ge=0)
    furnishing: Optional[str] = Field(None, pattern="^(unfurnished|furnished|semi_furnished)$")
    purpose: Optional[str] = Field(None, pattern="^(rent|sale)$")
    amenities: Optional[List[str]] = None
    floors: Optional[int] = Field(None, ge=1)
    building_name: Optional[str] = Field(None, max_length=255)
    parking_spaces: Optional[int] = Field(None, ge=0)

    @field_validator("title", "address", mode="before")
    @classmethod
    def no_blank(cls, value: str) -> str:
        if not value or not value.strip():
            raise ValueError("Field cannot be blank")
        return value.strip()


class PropertyUpdate(BaseModel):
    agent_id: Optional[int] = None
    owner_id: Optional[int] = None
    title: Optional[str] = Field(None, min_length=1, max_length=255)
    description: Optional[str] = None
    property_type: Optional[str] = Field(None, pattern="^(house|apartment|land|commercial|villa|office|warehouse|other)$")
    address: Optional[str] = None
    city: Optional[str] = None
    price: Optional[Decimal] = Field(None, gt=0)
    bedrooms: Optional[int] = Field(None, ge=0)
    bathrooms: Optional[int] = Field(None, ge=0)
    area_sqft: Optional[int] = Field(None, gt=0)
    country: Optional[str] = None
    plot_length_m: Optional[float] = Field(None, gt=0)
    plot_width_m: Optional[float] = Field(None, gt=0)
    land_category: Optional[str] = Field(None, pattern="^(farmland|residential|industrial|other)$")
    land_area_acres: Optional[float] = Field(None, gt=0)
    status: Optional[str] = Field(None, pattern="^(available|sold|rented|pending|unavailable)$")
    # Extended fields
    property_age: Optional[int] = Field(None, ge=0)
    furnishing: Optional[str] = Field(None, pattern="^(unfurnished|furnished|semi_furnished)$")
    purpose: Optional[str] = Field(None, pattern="^(rent|sale)$")
    amenities: Optional[List[str]] = None
    floors: Optional[int] = Field(None, ge=1)
    building_name: Optional[str] = Field(None, max_length=255)
    parking_spaces: Optional[int] = Field(None, ge=0)

    @field_validator("title", "address", mode="before")
    @classmethod
    def no_blank(cls, value: Optional[str]) -> Optional[str]:
        if value is not None and not value.strip():
            raise ValueError("Field cannot be blank")
        return value.strip() if value else value


class AgentProfileResponse(BaseModel):
    """Minimal agent/company/organisation profile embedded in property responses."""
    id: int
    role: str
    first_name: str
    last_name: str
    email: str
    phone: Optional[str] = None
    bio: Optional[str] = None
    avatar_url: Optional[str] = None
    license_number: Optional[str] = None
    agency_name: Optional[str] = None
    user_uid: Optional[str] = None

    model_config = {"from_attributes": True}


class PropertyResponse(PropertyBase):
    id: int
    agent_id: Optional[int] = None
    status: str
    listing_code: Optional[str] = None
    created_at: datetime
    image_urls: List[str] = []
    agent_profile: Optional[AgentProfileResponse] = None

    @classmethod
    def from_orm_with_images(cls, prop) -> "PropertyResponse":
        obj = cls.model_validate(prop)
        obj.image_urls = [img.image_url for img in (prop.images or [])]
        if prop.agent is not None:
            obj.agent_profile = AgentProfileResponse.model_validate(prop.agent)
        return obj

    model_config = {"from_attributes": True}


# ========== PROPERTY IMAGE ==========

class PropertyImageBase(BaseModel):
    image_url: str
    is_primary: Optional[bool] = False


class PropertyImageCreate(PropertyImageBase):
    property_id: int


class PropertyImageResponse(PropertyImageBase):
    id: int

    model_config = {"from_attributes": True}


# ========== LISTING ==========

class ListingBase(BaseModel):
    listing_type: str
    listed_price: Decimal
    listing_date: date
    expiry_date: Optional[date] = None


class ListingCreate(ListingBase):
    property_id: int
    listing_type: str = Field(..., pattern="^(sale|rent)$")
    listed_price: Decimal = Field(..., gt=0)


class ListingResponse(ListingBase):
    id: int

    model_config = {"from_attributes": True}


# ========== INQUIRY ==========

class InquiryBase(BaseModel):
    message: Optional[str] = None


class InquiryCreate(InquiryBase):
    property_id: int
    client_id: Optional[int] = None


class InquiryResponse(InquiryBase):
    id: int
    status: str
    created_at: datetime

    model_config = {"from_attributes": True}


# ========== APPOINTMENT ==========

class AppointmentBase(BaseModel):
    appointment_date: datetime


class AppointmentCreate(AppointmentBase):
    property_id: int
    agent_id: int
    client_id: int


class AppointmentResponse(AppointmentBase):
    id: int
    status: str

    model_config = {"from_attributes": True}


# ========== TRANSACTION ==========

class TransactionBase(BaseModel):
    sale_price: Decimal
    commission: Optional[Decimal] = None
    transaction_date: date


class TransactionCreate(TransactionBase):
    property_id: int
    agent_id: int
    buyer_id: int
    sale_price: Decimal = Field(..., gt=0)


class TransactionResponse(TransactionBase):
    id: int

    model_config = {"from_attributes": True}


# ========== PAYMENT ==========

class PaymentBase(BaseModel):
    amount: Decimal
    payment_method: Optional[str] = None


class PaymentCreate(PaymentBase):
    transaction_id: int
    amount: Decimal = Field(..., gt=0)


class PaymentResponse(PaymentBase):
    id: int
    payment_date: date

    model_config = {"from_attributes": True}