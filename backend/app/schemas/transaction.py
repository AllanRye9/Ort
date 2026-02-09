from pydantic import BaseModel, Field
from typing import Optional
from datetime import date


class TransactionBase(BaseModel):
    """Base transaction schema"""
    sale_price: float
    commission: Optional[float] = None
    transaction_date: date


class TransactionCreate(TransactionBase):
    """Schema for creating a transaction"""
    property_id: int
    agent_id: int
    buyer_id: int
    sale_price: float = Field(..., gt=0)


class TransactionResponse(TransactionBase):
    """Schema for transaction response"""
    id: int

    model_config = {"from_attributes": True}


class PaymentBase(BaseModel):
    """Base payment schema"""
    amount: float
    payment_method: Optional[str] = None


class PaymentCreate(PaymentBase):
    """Schema for creating a payment"""
    transaction_id: int
    amount: float = Field(..., gt=0)


class PaymentResponse(PaymentBase):
    """Schema for payment response"""
    id: int
    payment_date: date

    model_config = {"from_attributes": True}
