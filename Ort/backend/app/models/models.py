from sqlalchemy import (
    Column, Integer, String, Text, Date, DateTime, 
    Enum, ForeignKey, Boolean, DECIMAL
)
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from ..database.database import Base


class User(Base):
    __tablename__ = "users"

    id = Column(Integer, primary_key=True)
    role = Column(Enum("agent", "admin", name="user_roles"), nullable=False)
    first_name = Column(String(100), nullable=False)
    last_name = Column(String(100), nullable=False)
    email = Column(String(255), unique=True, nullable=False)
    phone = Column(String(20))
    password_hash = Column(Text, nullable=False)
    created_at = Column(DateTime, server_default=func.now())

    properties = relationship("Property", back_populates="agent")
    clients = relationship("Client", back_populates="agent")


class Client(Base):
    __tablename__ = "clients"

    id = Column(Integer, primary_key=True)
    agent_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"))
    first_name = Column(String(100), nullable=False)
    last_name = Column(String(100), nullable=False)
    email = Column(String(255))
    phone = Column(String(20))
    client_type = Column(Enum("buyer", "seller", "renter", name="client_types"))
    created_at = Column(DateTime, server_default=func.now())

    agent = relationship("User", back_populates="clients")
    properties = relationship("Property", back_populates="owner")


class Property(Base):
    __tablename__ = "properties"

    id = Column(Integer, primary_key=True)
    owner_id = Column(Integer, ForeignKey("clients.id", ondelete="SET NULL"))
    agent_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"))
    title = Column(String(255), nullable=False)
    description = Column(Text)
    property_type = Column(Enum("house", "apartment", "land", "commercial", name="property_types"))
    address = Column(Text, nullable=False)
    city = Column(String(100))
    price = Column(DECIMAL(12, 2), nullable=False)
    bedrooms = Column(Integer)
    bathrooms = Column(Integer)
    area_sqft = Column(Integer)
    status = Column(Enum("available", "sold", "rented", "pending", name="property_status"), default="available")
    created_at = Column(DateTime, server_default=func.now())

    agent = relationship("User", back_populates="properties")
    owner = relationship("Client", back_populates="properties")
    images = relationship("PropertyImage", back_populates="property", cascade="all, delete")
    listings = relationship("Listing", back_populates="property")
    inquiries = relationship("Inquiry", back_populates="property")
    appointments = relationship("Appointment", back_populates="property")


class PropertyImage(Base):
    __tablename__ = "property_images"

    id = Column(Integer, primary_key=True)
    property_id = Column(Integer, ForeignKey("properties.id", ondelete="CASCADE"))
    image_url = Column(Text, nullable=False)
    is_primary = Column(Boolean, default=False)

    property = relationship("Property", back_populates="images")


class Listing(Base):
    __tablename__ = "listings"

    id = Column(Integer, primary_key=True)
    property_id = Column(Integer, ForeignKey("properties.id", ondelete="CASCADE"))
    listing_type = Column(Enum("sale", "rent", name="listing_types"), nullable=False)
    listed_price = Column(DECIMAL(12, 2), nullable=False)
    listing_date = Column(Date, nullable=False)
    expiry_date = Column(Date)

    property = relationship("Property", back_populates="listings")


class Inquiry(Base):
    __tablename__ = "inquiries"

    id = Column(Integer, primary_key=True)
    property_id = Column(Integer, ForeignKey("properties.id", ondelete="CASCADE"))
    client_id = Column(Integer, ForeignKey("clients.id", ondelete="SET NULL"))
    message = Column(Text)
    status = Column(Enum("new", "contacted", "closed", name="inquiry_status"), default="new")
    created_at = Column(DateTime, server_default=func.now())

    property = relationship("Property", back_populates="inquiries")
    client = relationship("Client")


class Appointment(Base):
    __tablename__ = "appointments"

    id = Column(Integer, primary_key=True)
    property_id = Column(Integer, ForeignKey("properties.id", ondelete="CASCADE"))
    agent_id = Column(Integer, ForeignKey("users.id"))
    client_id = Column(Integer, ForeignKey("clients.id"))
    appointment_date = Column(DateTime, nullable=False)
    status = Column(Enum("scheduled", "completed", "cancelled", name="appointment_status"), default="scheduled")

    property = relationship("Property", back_populates="appointments")
    agent = relationship("User")
    client = relationship("Client")


class Transaction(Base):
    __tablename__ = "transactions"

    id = Column(Integer, primary_key=True)
    property_id = Column(Integer, ForeignKey("properties.id"))
    agent_id = Column(Integer, ForeignKey("users.id"))
    buyer_id = Column(Integer, ForeignKey("clients.id"))
    sale_price = Column(DECIMAL(12, 2), nullable=False)
    commission = Column(DECIMAL(12, 2))
    transaction_date = Column(Date, nullable=False)

    property = relationship("Property")
    agent = relationship("User")
    buyer = relationship("Client")
    payments = relationship("Payment", back_populates="transaction", cascade="all, delete")


class Payment(Base):
    __tablename__ = "payments"

    id = Column(Integer, primary_key=True)
    transaction_id = Column(Integer, ForeignKey("transactions.id", ondelete="CASCADE"))
    amount = Column(DECIMAL(12, 2), nullable=False)
    payment_method = Column(String(30))
    payment_date = Column(Date, server_default=func.current_date())

    transaction = relationship("Transaction", back_populates="payments")