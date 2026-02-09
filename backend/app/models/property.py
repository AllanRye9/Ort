from sqlalchemy import Column, Integer, String, Text, Date, DateTime, Enum, ForeignKey, Boolean, DECIMAL
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from ..database import Base


class Property(Base):
    """Property model for real estate listings"""
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

    # Relationships
    agent = relationship("User", back_populates="properties")
    owner = relationship("Client", back_populates="properties")
    images = relationship("PropertyImage", back_populates="property", cascade="all, delete")
    listings = relationship("Listing", back_populates="property")
    inquiries = relationship("Inquiry", back_populates="property")
    appointments = relationship("Appointment", back_populates="property")


class PropertyImage(Base):
    """Property image model"""
    __tablename__ = "property_images"

    id = Column(Integer, primary_key=True)
    property_id = Column(Integer, ForeignKey("properties.id", ondelete="CASCADE"))
    image_url = Column(Text, nullable=False)
    is_primary = Column(Boolean, default=False)

    # Relationships
    property = relationship("Property", back_populates="images")


class Listing(Base):
    """Property listing model for sale or rent"""
    __tablename__ = "listings"

    id = Column(Integer, primary_key=True)
    property_id = Column(Integer, ForeignKey("properties.id", ondelete="CASCADE"))
    listing_type = Column(Enum("sale", "rent", name="listing_types"), nullable=False)
    listed_price = Column(DECIMAL(12, 2), nullable=False)
    listing_date = Column(Date, nullable=False)
    expiry_date = Column(Date)

    # Relationships
    property = relationship("Property", back_populates="listings")


class Inquiry(Base):
    """Client inquiry model"""
    __tablename__ = "inquiries"

    id = Column(Integer, primary_key=True)
    property_id = Column(Integer, ForeignKey("properties.id", ondelete="CASCADE"))
    client_id = Column(Integer, ForeignKey("clients.id", ondelete="SET NULL"))
    message = Column(Text)
    status = Column(Enum("new", "contacted", "closed", name="inquiry_status"), default="new")
    created_at = Column(DateTime, server_default=func.now())

    # Relationships
    property = relationship("Property", back_populates="inquiries")
    client = relationship("Client")


class Appointment(Base):
    """Property viewing appointment model"""
    __tablename__ = "appointments"

    id = Column(Integer, primary_key=True)
    property_id = Column(Integer, ForeignKey("properties.id", ondelete="CASCADE"))
    agent_id = Column(Integer, ForeignKey("users.id"))
    client_id = Column(Integer, ForeignKey("clients.id"))
    appointment_date = Column(DateTime, nullable=False)
    status = Column(Enum("scheduled", "completed", "cancelled", name="appointment_status"), default="scheduled")

    # Relationships
    property = relationship("Property", back_populates="appointments")
    agent = relationship("User")
    client = relationship("Client")
