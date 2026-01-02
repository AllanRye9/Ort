from pydantic import BaseModel, Field, validator
from typing import Optional
from datetime import datetime, date

# User schema
class UserBase(BaseModel):
    role: str
    first_name: str
    last_name: str
    email: str
    phone: Optional[str] = None

class UserCreate(UserBase):
    role: str = Field(..., pattern="^(agent|admin)$")
    first_name: str = Field(..., min_length=2, max_length=100)
    last_name: str = Field(..., min_length=2, max_length=100)
    email: str = Field(..., max_length=255)
    phone: Optional[str] = Field(None, max_length=20)
    password: str = Field(..., min_length=8)

    @validator("first_name", "last_name", "email", pre=True)
    def no_blank(cls, value):
        if not value or not value.strip():
            raise ValueError("Field cannot be blank")
        return value.strip()

class UserResponse(UserBase):
    id: int
    created_at: datetime

    class Config:
        from_attributes = True  # Changed from orm_mode=True in Pydantic V2

# Client schema
class ClientBase(BaseModel):
    first_name: str
    last_name: str
    email: Optional[str] = None
    phone: Optional[str] = None
    client_type: str

class ClientCreate(ClientBase):
    agent_id: Optional[int] = None
    client_type: str = Field(..., pattern="^(buyer|seller|renter)$")

    @validator("first_name", "last_name", pre=True)
    def no_blank(cls, value):
        if not value or not value.strip():
            raise ValueError("Field cannot be blank")
        return value.strip()

class ClientResponse(ClientBase):
    id: int
    created_at: datetime

    class Config:
        from_attributes = True

# Property schema
class PropertyBase(BaseModel):
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
    agent_id: Optional[int] = None
    owner_id: Optional[int] = None
    property_type: str = Field(..., pattern="^(house|apartment|land|commercial)$")
    price: float = Field(..., gt=0)
    bedrooms: Optional[int] = Field(None, ge=0)
    bathrooms: Optional[int] = Field(None, ge=0)
    area_sqft: Optional[int] = Field(None, gt=0)

    @validator("title", "address", pre=True)
    def no_blank(cls, value):
        if not value or not value.strip():
            raise ValueError("Field cannot be blank")
        return value.strip()

class PropertyResponse(PropertyBase):
    id: int
    status: str
    created_at: datetime

    class Config:
        from_attributes = True

# Property images
class PropertyImageBase(BaseModel):
    image_url: str
    is_primary: Optional[bool] = False

class PropertyImageCreate(PropertyImageBase):
    property_id: int

class PropertyImageResponse(PropertyImageBase):
    id: int

    class Config:
        from_attributes = True

# Listing schema
class ListingBase(BaseModel):
    listing_type: str
    listed_price: float
    listing_date: date
    expiry_date: Optional[date] = None

class ListingCreate(ListingBase):
    property_id: int
    listing_type: str = Field(..., pattern="^(sale|rent)$")
    listed_price: float = Field(..., gt=0)

class ListingResponse(ListingBase):
    id: int

    class Config:
        from_attributes = True

# Inquiries schema
class InquiryBase(BaseModel):
    message: Optional[str] = None

class InquiryCreate(InquiryBase):
    property_id: int
    client_id: Optional[int] = None

class InquiryResponse(InquiryBase):
    id: int
    status: str
    created_at: datetime

    class Config:
        from_attributes = True

# Appointment schema
class AppointmentBase(BaseModel):
    appointment_date: datetime

class AppointmentCreate(AppointmentBase):
    property_id: int
    agent_id: int
    client_id: int

class AppointmentResponse(AppointmentBase):
    id: int
    status: str

    class Config:
        from_attributes = True

# Transaction schema
class TransactionBase(BaseModel):
    sale_price: float
    commission: Optional[float] = None
    transaction_date: date

class TransactionCreate(TransactionBase):
    property_id: int
    agent_id: int
    buyer_id: int
    sale_price: float = Field(..., gt=0)

class TransactionResponse(TransactionBase):
    id: int

    class Config:
        from_attributes = True

# Payments schema
class PaymentBase(BaseModel):
    amount: float
    payment_method: Optional[str] = None

class PaymentCreate(PaymentBase):
    transaction_id: int
    amount: float = Field(..., gt=0)

class PaymentResponse(PaymentBase):
    id: int
    payment_date: date

    class Config:
        from_attributes = True