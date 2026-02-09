from sqlalchemy import Column, Integer, String, Text, DateTime, Enum, ForeignKey
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from ..database import Base


class User(Base):
    """User model for agents and admins"""
    __tablename__ = "users"

    id = Column(Integer, primary_key=True)
    role = Column(Enum("agent", "admin", name="user_roles"), nullable=False)
    first_name = Column(String(100), nullable=False)
    last_name = Column(String(100), nullable=False)
    email = Column(String(255), unique=True, nullable=False)
    phone = Column(String(20))
    password_hash = Column(Text, nullable=False)
    created_at = Column(DateTime, server_default=func.now())

    # Relationships
    properties = relationship("Property", back_populates="agent")
    clients = relationship("Client", back_populates="agent")


class Client(Base):
    """Client model for buyers, sellers, and renters"""
    __tablename__ = "clients"

    id = Column(Integer, primary_key=True)
    agent_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"))
    first_name = Column(String(100), nullable=False)
    last_name = Column(String(100), nullable=False)
    email = Column(String(255))
    phone = Column(String(20))
    client_type = Column(Enum("buyer", "seller", "renter", name="client_types"))
    created_at = Column(DateTime, server_default=func.now())

    # Relationships
    agent = relationship("User", back_populates="clients")
    properties = relationship("Property", back_populates="owner")
