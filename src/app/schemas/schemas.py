from decimal import Decimal
from typing import Optional
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
    role: str = Field(..., pattern="^(agent|admin|company|organization)$")
    first_name: str = Field(..., min_length=2, max_length=100)
    last_name: str = Field(..., min_length=2, max_length=100)
    phone: Optional[str] = Field(None, max_length=20)
    password: str = Field(..., min_length=8)

    @field_validator("first_name", "last_name", mode="before")
    @classmethod
    def no_blank(cls, value: str) -> str:
        if not value or not value.strip():
            raise ValueError("Field cannot be blank")
        return value.strip()


class UserUpdate(BaseModel):
    role: Optional[str] = Field(None, pattern="^(agent|admin|company|organization)$")
    first_name: Optional[str] = Field(None, min_length=2, max_length=100)
    last_name: Optional[str] = Field(None, min_length=2, max_length=100)
    email: Optional[EmailStr] = None
    phone: Optional[str] = Field(None, max_length=20)
    password: Optional[str] = Field(None, min_length=8)

    @field_validator("first_name", "last_name", mode="before")
    @classmethod
    def no_blank(cls, value: Optional[str]) -> Optional[str]:
        if value is not None and not value.strip():
            raise ValueError("Field cannot be blank")
        return value.strip() if value else value


class UserResponse(UserBase):
    id: int
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


class PropertyCreate(PropertyBase):
    agent_id: Optional[int] = None
    owner_id: Optional[int] = None
    property_type: str = Field(..., pattern="^(house|apartment|land|commercial)$")
    price: Decimal = Field(..., gt=0)
    bedrooms: Optional[int] = Field(None, ge=0)
    bathrooms: Optional[int] = Field(None, ge=0)
    area_sqft: Optional[int] = Field(None, gt=0)

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
    property_type: Optional[str] = Field(None, pattern="^(house|apartment|land|commercial)$")
    address: Optional[str] = None
    city: Optional[str] = None
    price: Optional[Decimal] = Field(None, gt=0)
    bedrooms: Optional[int] = Field(None, ge=0)
    bathrooms: Optional[int] = Field(None, ge=0)
    area_sqft: Optional[int] = Field(None, gt=0)
    status: Optional[str] = Field(None, pattern="^(available|sold|rented|pending)$")

    @field_validator("title", "address", mode="before")
    @classmethod
    def no_blank(cls, value: Optional[str]) -> Optional[str]:
        if value is not None and not value.strip():
            raise ValueError("Field cannot be blank")
        return value.strip() if value else value


class PropertyResponse(PropertyBase):
    id: int
    status: str
    created_at: datetime

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