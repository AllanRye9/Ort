"""
Pydantic v2 schemas for the extended SaaS marketplace models.
"""
from decimal import Decimal
from typing import Any, Dict, List, Optional
from datetime import datetime, date

from pydantic import BaseModel, Field, EmailStr, field_validator


# ========== AUTH ==========

class LoginRequest(BaseModel):
    email: EmailStr
    password: str = Field(..., min_length=1)


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    user_id: Optional[int] = None
    role: Optional[str] = None


# ========== TENANT ==========

class TenantBase(BaseModel):
    name: str
    tenant_type: str
    description: Optional[str] = None
    logo_url: Optional[str] = None
    website: Optional[str] = None
    phone: Optional[str] = None
    email: Optional[EmailStr] = None
    address: Optional[str] = None
    country: Optional[str] = None


class TenantCreate(TenantBase):
    slug: str = Field(..., min_length=3, max_length=100, pattern=r"^[a-z0-9-]+$")
    tenant_type: str = Field(..., pattern="^(individual|sme|enterprise|government|ngo)$")
    owner_user_id: Optional[int] = None

    @field_validator("name", mode="before")
    @classmethod
    def no_blank(cls, v: str) -> str:
        if not v or not v.strip():
            raise ValueError("Field cannot be blank")
        return v.strip()


class TenantUpdate(BaseModel):
    name: Optional[str] = None
    tenant_type: Optional[str] = Field(None, pattern="^(individual|sme|enterprise|government|ngo)$")
    description: Optional[str] = None
    logo_url: Optional[str] = None
    website: Optional[str] = None
    phone: Optional[str] = None
    email: Optional[EmailStr] = None
    address: Optional[str] = None
    country: Optional[str] = None
    is_verified: Optional[bool] = None
    is_active: Optional[bool] = None


class TenantResponse(TenantBase):
    id: int
    slug: str
    is_verified: bool
    is_active: bool
    created_at: datetime

    model_config = {"from_attributes": True}


# ========== SUBSCRIPTION PLAN ==========

class SubscriptionPlanBase(BaseModel):
    name: str
    tier: str
    price_monthly: Decimal
    price_annual: Optional[Decimal] = None
    listing_limit: Optional[int] = 10
    api_access: Optional[bool] = False
    white_label: Optional[bool] = False
    priority_support: Optional[bool] = False
    advanced_analytics: Optional[bool] = False
    features: Optional[Dict[str, Any]] = None


class SubscriptionPlanCreate(SubscriptionPlanBase):
    tier: str = Field(..., pattern="^(free|professional|enterprise|government)$")
    price_monthly: Decimal = Field(..., ge=0)


class SubscriptionPlanResponse(SubscriptionPlanBase):
    id: int
    is_active: bool
    created_at: datetime

    model_config = {"from_attributes": True}


# ========== TENANT SUBSCRIPTION ==========

class TenantSubscriptionCreate(BaseModel):
    tenant_id: int
    plan_id: int
    billing_cycle: str = Field("monthly", pattern="^(monthly|annual)$")
    start_date: date


class TenantSubscriptionResponse(BaseModel):
    id: int
    tenant_id: int
    plan_id: int
    status: str
    billing_cycle: str
    start_date: date
    end_date: Optional[date] = None
    created_at: datetime

    model_config = {"from_attributes": True}


# ========== AGRICULTURE LISTING ==========

class AgricultureListingBase(BaseModel):
    title: str
    description: Optional[str] = None
    category: Optional[str] = None
    commodity_type: Optional[str] = None
    quantity_available: Optional[float] = None
    unit: Optional[str] = None
    moq: Optional[float] = None
    price_per_unit: Decimal
    currency: Optional[str] = "USD"
    quality_grade: Optional[str] = None
    harvest_date: Optional[date] = None
    expiry_date: Optional[date] = None
    storage_conditions: Optional[str] = None
    certification: Optional[str] = None
    location: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    is_perishable: Optional[bool] = False
    images: Optional[List[str]] = None


class AgricultureListingCreate(AgricultureListingBase):
    tenant_id: int
    price_per_unit: Decimal = Field(..., gt=0)

    @field_validator("title", mode="before")
    @classmethod
    def no_blank(cls, v: str) -> str:
        if not v or not v.strip():
            raise ValueError("Field cannot be blank")
        return v.strip()


class AgricultureListingUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    category: Optional[str] = None
    commodity_type: Optional[str] = None
    quantity_available: Optional[float] = None
    unit: Optional[str] = None
    moq: Optional[float] = None
    price_per_unit: Optional[Decimal] = Field(None, gt=0)
    currency: Optional[str] = None
    quality_grade: Optional[str] = None
    harvest_date: Optional[date] = None
    expiry_date: Optional[date] = None
    storage_conditions: Optional[str] = None
    certification: Optional[str] = None
    location: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    is_perishable: Optional[bool] = None
    images: Optional[List[str]] = None
    status: Optional[str] = Field(None, pattern="^(available|sold_out|reserved|expired)$")


class AgricultureListingResponse(AgricultureListingBase):
    id: int
    tenant_id: int
    status: str
    created_at: datetime

    model_config = {"from_attributes": True}


# ========== MANUFACTURING PRODUCT ==========

class ManufacturingProductBase(BaseModel):
    title: str
    description: Optional[str] = None
    category: Optional[str] = None
    sku: Optional[str] = None
    batch_number: Optional[str] = None
    quantity_available: Optional[int] = None
    moq: Optional[int] = None
    unit: Optional[str] = None
    wholesale_price: Decimal
    currency: Optional[str] = "USD"
    tiered_pricing: Optional[List[Dict[str, Any]]] = None
    certifications: Optional[List[str]] = None
    images: Optional[List[str]] = None
    supply_chain_info: Optional[str] = None
    lead_time_days: Optional[int] = None
    is_locally_made: Optional[bool] = True
    country_of_origin: Optional[str] = None


class ManufacturingProductCreate(ManufacturingProductBase):
    tenant_id: int
    wholesale_price: Decimal = Field(..., gt=0)

    @field_validator("title", mode="before")
    @classmethod
    def no_blank(cls, v: str) -> str:
        if not v or not v.strip():
            raise ValueError("Field cannot be blank")
        return v.strip()


class ManufacturingProductUpdate(BaseModel):
    title: Optional[str] = None
    description: Optional[str] = None
    category: Optional[str] = None
    sku: Optional[str] = None
    batch_number: Optional[str] = None
    quantity_available: Optional[int] = None
    moq: Optional[int] = None
    unit: Optional[str] = None
    wholesale_price: Optional[Decimal] = Field(None, gt=0)
    currency: Optional[str] = None
    tiered_pricing: Optional[List[Dict[str, Any]]] = None
    certifications: Optional[List[str]] = None
    images: Optional[List[str]] = None
    supply_chain_info: Optional[str] = None
    lead_time_days: Optional[int] = None
    is_locally_made: Optional[bool] = None
    country_of_origin: Optional[str] = None
    status: Optional[str] = Field(None, pattern="^(available|out_of_stock|discontinued)$")


class ManufacturingProductResponse(ManufacturingProductBase):
    id: int
    tenant_id: int
    status: str
    created_at: datetime

    model_config = {"from_attributes": True}


# ========== ORDER ==========

class OrderItemCreate(BaseModel):
    property_id: Optional[int] = None
    agriculture_listing_id: Optional[int] = None
    manufacturing_product_id: Optional[int] = None
    quantity: float = Field(..., gt=0)
    unit_price: Decimal = Field(..., gt=0)


class OrderItemResponse(BaseModel):
    id: int
    property_id: Optional[int] = None
    agriculture_listing_id: Optional[int] = None
    manufacturing_product_id: Optional[int] = None
    quantity: float
    unit_price: Decimal
    subtotal: Decimal

    model_config = {"from_attributes": True}


class OrderCreate(BaseModel):
    seller_tenant_id: int
    buyer_user_id: Optional[int] = None
    currency: Optional[str] = "USD"
    payment_method: Optional[str] = None
    delivery_address: Optional[str] = None
    notes: Optional[str] = None
    items: List[OrderItemCreate]


class OrderUpdate(BaseModel):
    status: Optional[str] = Field(
        None,
        pattern="^(pending|confirmed|processing|shipped|delivered|cancelled|disputed)$",
    )
    payment_status: Optional[str] = Field(
        None, pattern="^(unpaid|partial|paid|refunded)$"
    )
    delivery_address: Optional[str] = None
    notes: Optional[str] = None


class OrderResponse(BaseModel):
    id: int
    order_number: str
    buyer_user_id: Optional[int] = None
    seller_tenant_id: Optional[int] = None
    status: str
    total_amount: Optional[Decimal] = None
    currency: str
    payment_status: str
    payment_method: Optional[str] = None
    delivery_address: Optional[str] = None
    notes: Optional[str] = None
    created_at: datetime
    items: List[OrderItemResponse] = []

    model_config = {"from_attributes": True}


# ========== CONVERSATION & MESSAGE ==========

class ConversationCreate(BaseModel):
    recipient_id: int
    initiator_id: Optional[int] = None
    subject: Optional[str] = None
    property_id: Optional[int] = None
    order_id: Optional[int] = None


class ConversationResponse(BaseModel):
    id: int
    initiator_id: Optional[int] = None
    recipient_id: Optional[int] = None
    subject: Optional[str] = None
    property_id: Optional[int] = None
    order_id: Optional[int] = None
    created_at: datetime

    model_config = {"from_attributes": True}


class MessageCreate(BaseModel):
    conversation_id: int
    sender_id: Optional[int] = None
    body: str = Field(..., min_length=1)
    attachment_url: Optional[str] = None
    message_type: Optional[str] = Field("text", pattern="^(text|file|voice)$")

    @field_validator("body", mode="before")
    @classmethod
    def no_blank(cls, v: str) -> str:
        if not v or not v.strip():
            raise ValueError("Message body cannot be blank")
        return v.strip()


class MessageResponse(BaseModel):
    id: int
    conversation_id: int
    sender_id: Optional[int] = None
    body: str
    attachment_url: Optional[str] = None
    message_type: str
    is_read: bool
    sent_at: datetime

    model_config = {"from_attributes": True}


# ========== RFQ ==========

class RFQCreate(BaseModel):
    seller_tenant_id: Optional[int] = None
    buyer_id: Optional[int] = None
    title: str = Field(..., min_length=3)
    description: Optional[str] = None
    category: Optional[str] = None
    quantity: Optional[float] = None
    unit: Optional[str] = None
    target_price: Optional[Decimal] = None
    currency: Optional[str] = "USD"
    deadline: Optional[date] = None

    @field_validator("title", mode="before")
    @classmethod
    def no_blank(cls, v: str) -> str:
        if not v or not v.strip():
            raise ValueError("Field cannot be blank")
        return v.strip()


class RFQUpdate(BaseModel):
    status: Optional[str] = Field(
        None, pattern="^(open|quoted|accepted|rejected|expired)$"
    )
    title: Optional[str] = None
    description: Optional[str] = None
    quantity: Optional[float] = None
    target_price: Optional[Decimal] = None
    deadline: Optional[date] = None


class RFQResponse(BaseModel):
    id: int
    buyer_id: Optional[int] = None
    seller_tenant_id: Optional[int] = None
    title: str
    description: Optional[str] = None
    category: Optional[str] = None
    quantity: Optional[float] = None
    unit: Optional[str] = None
    target_price: Optional[Decimal] = None
    currency: str
    deadline: Optional[date] = None
    status: str
    created_at: datetime

    model_config = {"from_attributes": True}


class RFQResponseCreate(BaseModel):
    rfq_id: int
    responder_tenant_id: Optional[int] = None
    quoted_price: Decimal = Field(..., gt=0)
    currency: Optional[str] = "USD"
    notes: Optional[str] = None
    valid_until: Optional[date] = None


class RFQResponseResponse(BaseModel):
    id: int
    rfq_id: int
    responder_tenant_id: Optional[int] = None
    quoted_price: Decimal
    currency: str
    notes: Optional[str] = None
    valid_until: Optional[date] = None
    status: str
    created_at: datetime

    model_config = {"from_attributes": True}


# ========== REVIEW ==========

class ReviewCreate(BaseModel):
    reviewer_id: Optional[int] = None
    reviewed_tenant_id: Optional[int] = None
    order_id: Optional[int] = None
    property_id: Optional[int] = None
    rating: int = Field(..., ge=1, le=5)
    title: Optional[str] = None
    body: Optional[str] = None
    is_verified_purchase: Optional[bool] = False


class ReviewResponse(BaseModel):
    id: int
    reviewer_id: Optional[int] = None
    reviewed_tenant_id: Optional[int] = None
    order_id: Optional[int] = None
    property_id: Optional[int] = None
    rating: int
    title: Optional[str] = None
    body: Optional[str] = None
    is_verified_purchase: bool
    created_at: datetime

    model_config = {"from_attributes": True}


# ========== NOTIFICATION ==========

class NotificationCreate(BaseModel):
    user_id: int
    title: str
    body: Optional[str] = None
    notification_type: Optional[str] = None
    reference_id: Optional[int] = None
    reference_type: Optional[str] = None


class NotificationUpdate(BaseModel):
    is_read: Optional[bool] = None


class NotificationResponse(BaseModel):
    id: int
    user_id: int
    title: str
    body: Optional[str] = None
    notification_type: Optional[str] = None
    reference_id: Optional[int] = None
    reference_type: Optional[str] = None
    is_read: bool
    created_at: datetime

    model_config = {"from_attributes": True}
