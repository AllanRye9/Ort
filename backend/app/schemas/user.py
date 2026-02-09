from pydantic import BaseModel, Field, field_validator
from typing import Optional
from datetime import datetime


class UserBase(BaseModel):
    """Base user schema"""
    role: str
    first_name: str
    last_name: str
    email: str
    phone: Optional[str] = None


class UserCreate(UserBase):
    """Schema for creating a new user"""
    role: str = Field(..., pattern="^(agent|admin)$")
    first_name: str = Field(..., min_length=2, max_length=100)
    last_name: str = Field(..., min_length=2, max_length=100)
    email: str = Field(..., max_length=255)
    phone: Optional[str] = Field(None, max_length=20)
    password: str = Field(..., min_length=8)

    @field_validator("first_name", "last_name", "email")
    @classmethod
    def no_blank(cls, value):
        if not value or not value.strip():
            raise ValueError("Field cannot be blank")
        return value.strip()


class UserUpdate(BaseModel):
    """Schema for updating user information"""
    first_name: Optional[str] = Field(None, min_length=2, max_length=100)
    last_name: Optional[str] = Field(None, min_length=2, max_length=100)
    email: Optional[str] = Field(None, max_length=255)
    phone: Optional[str] = Field(None, max_length=20)
    password: Optional[str] = Field(None, min_length=8)


class UserResponse(UserBase):
    """Schema for user response"""
    id: int
    created_at: datetime

    model_config = {"from_attributes": True}


class ClientBase(BaseModel):
    """Base client schema"""
    first_name: str
    last_name: str
    email: Optional[str] = None
    phone: Optional[str] = None
    client_type: str


class ClientCreate(ClientBase):
    """Schema for creating a new client"""
    agent_id: Optional[int] = None
    client_type: str = Field(..., pattern="^(buyer|seller|renter)$")

    @field_validator("first_name", "last_name")
    @classmethod
    def no_blank(cls, value):
        if not value or not value.strip():
            raise ValueError("Field cannot be blank")
        return value.strip()


class ClientResponse(ClientBase):
    """Schema for client response"""
    id: int
    created_at: datetime

    model_config = {"from_attributes": True}
