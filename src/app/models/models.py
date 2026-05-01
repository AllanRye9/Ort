from sqlalchemy import (
    Column, Integer, String, Text, Date, DateTime,
    Enum, ForeignKey, Boolean, DECIMAL, Index, LargeBinary, Float
)
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from ..database.database import Base


class User(Base):
    __tablename__ = "users"
    __table_args__ = (
        Index("ix_users_email", "email"),
    )

    id = Column(Integer, primary_key=True)
    role = Column(Enum("user", "agent", "admin", "company", "organization", name="user_roles"), nullable=False)
    first_name = Column(String(100), nullable=False)
    last_name = Column(String(100), nullable=False)
    email = Column(String(255), unique=True, nullable=False)
    phone = Column(String(30))
    password_hash = Column(Text, nullable=False)
    # Agent-specific fields
    license_number = Column(String(100), nullable=True)
    agency_name = Column(String(255), nullable=True)
    bio = Column(Text, nullable=True)
    avatar_url = Column(Text, nullable=True)
    created_at = Column(DateTime, server_default=func.now())

    properties = relationship("Property", back_populates="agent")
    clients = relationship("Client", back_populates="agent")


class Client(Base):
    __tablename__ = "clients"
    __table_args__ = (
        Index("ix_clients_agent_id", "agent_id"),
    )

    id = Column(Integer, primary_key=True)
    agent_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
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
    __table_args__ = (
        Index("ix_properties_agent_id", "agent_id"),
        Index("ix_properties_owner_id", "owner_id"),
        Index("ix_properties_status", "status"),
        Index("ix_properties_city", "city"),
    )

    id = Column(Integer, primary_key=True)
    owner_id = Column(Integer, ForeignKey("clients.id", ondelete="SET NULL"), nullable=True)
    agent_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    title = Column(String(255), nullable=False)
    description = Column(Text)
    property_type = Column(Enum("house", "apartment", "land", "commercial", "villa", "office", "warehouse", "other", name="property_types"))
    address = Column(Text, nullable=False)
    city = Column(String(100))
    price = Column(DECIMAL(12, 2), nullable=False)
    bedrooms = Column(Integer)
    bathrooms = Column(Integer)
    area_sqft = Column(Integer)
    country = Column(String(100), nullable=True)
    plot_length_m = Column(Float, nullable=True)
    plot_width_m = Column(Float, nullable=True)
    land_category = Column(String(50), nullable=True)   # farmland, residential, industrial, other
    land_area_acres = Column(Float, nullable=True)       # area in acres for land properties
    status = Column(Enum("available", "sold", "rented", "pending", "unavailable", name="property_status"), default="available", server_default="available", nullable=False)
    latitude = Column(Float, nullable=True)
    longitude = Column(Float, nullable=True)
    is_deleted = Column(Boolean, default=False, server_default="false", nullable=False)
    created_at = Column(DateTime, server_default=func.now())

    agent = relationship("User", back_populates="properties")
    owner = relationship("Client", back_populates="properties")
    images = relationship("PropertyImage", back_populates="property", cascade="all, delete")
    listings = relationship("Listing", back_populates="property")
    inquiries = relationship("Inquiry", back_populates="property")
    appointments = relationship("Appointment", back_populates="property")


class PropertyImage(Base):
    __tablename__ = "property_images"
    __table_args__ = (
        Index("ix_property_images_property_id", "property_id"),
    )

    id = Column(Integer, primary_key=True)
    property_id = Column(Integer, ForeignKey("properties.id", ondelete="CASCADE"))
    image_url = Column(Text, nullable=False)
    is_primary = Column(Boolean, default=False)

    property = relationship("Property", back_populates="images")


class Listing(Base):
    __tablename__ = "listings"
    __table_args__ = (
        Index("ix_listings_property_id", "property_id"),
    )

    id = Column(Integer, primary_key=True)
    property_id = Column(Integer, ForeignKey("properties.id", ondelete="CASCADE"))
    listing_type = Column(Enum("sale", "rent", name="listing_types"), nullable=False)
    listed_price = Column(DECIMAL(12, 2), nullable=False)
    listing_date = Column(Date, nullable=False)
    expiry_date = Column(Date)

    property = relationship("Property", back_populates="listings")


class Inquiry(Base):
    __tablename__ = "inquiries"
    __table_args__ = (
        Index("ix_inquiries_property_id", "property_id"),
        Index("ix_inquiries_client_id", "client_id"),
    )

    id = Column(Integer, primary_key=True)
    property_id = Column(Integer, ForeignKey("properties.id", ondelete="CASCADE"))
    client_id = Column(Integer, ForeignKey("clients.id", ondelete="SET NULL"), nullable=True)
    message = Column(Text)
    status = Column(Enum("new", "contacted", "closed", name="inquiry_status"), default="new", server_default="new", nullable=False)
    created_at = Column(DateTime, server_default=func.now())

    property = relationship("Property", back_populates="inquiries")
    client = relationship("Client")


class Appointment(Base):
    __tablename__ = "appointments"
    __table_args__ = (
        Index("ix_appointments_property_id", "property_id"),
        Index("ix_appointments_agent_id", "agent_id"),
        Index("ix_appointments_client_id", "client_id"),
    )

    id = Column(Integer, primary_key=True)
    property_id = Column(Integer, ForeignKey("properties.id", ondelete="CASCADE"))
    agent_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    client_id = Column(Integer, ForeignKey("clients.id", ondelete="SET NULL"), nullable=True)
    appointment_date = Column(DateTime, nullable=False)
    status = Column(Enum("scheduled", "completed", "cancelled", name="appointment_status"), default="scheduled", server_default="scheduled", nullable=False)

    property = relationship("Property", back_populates="appointments")
    agent = relationship("User")
    client = relationship("Client")


class Transaction(Base):
    __tablename__ = "transactions"
    __table_args__ = (
        Index("ix_transactions_property_id", "property_id"),
        Index("ix_transactions_agent_id", "agent_id"),
        Index("ix_transactions_buyer_id", "buyer_id"),
    )

    id = Column(Integer, primary_key=True)
    property_id = Column(Integer, ForeignKey("properties.id", ondelete="SET NULL"), nullable=True)
    agent_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    buyer_id = Column(Integer, ForeignKey("clients.id", ondelete="SET NULL"), nullable=True)
    sale_price = Column(DECIMAL(12, 2), nullable=False)
    commission = Column(DECIMAL(12, 2))
    transaction_date = Column(Date, nullable=False)

    property = relationship("Property")
    agent = relationship("User")
    buyer = relationship("Client")
    payments = relationship("Payment", back_populates="transaction", cascade="all, delete")


class Payment(Base):
    __tablename__ = "payments"
    __table_args__ = (
        Index("ix_payments_transaction_id", "transaction_id"),
    )

    id = Column(Integer, primary_key=True)
    transaction_id = Column(Integer, ForeignKey("transactions.id", ondelete="CASCADE"))
    amount = Column(DECIMAL(12, 2), nullable=False)
    payment_method = Column(String(30))
    payment_date = Column(Date, server_default=func.current_date())

    transaction = relationship("Transaction", back_populates="payments")


class ImageBlob(Base):
    """Stores uploaded image binary data in the database.

    Used as a persistence layer when S3/object-storage is not configured
    so that images survive container restarts on platforms like Railway.
    """

    __tablename__ = "image_blobs"

    id = Column(String(36), primary_key=True)  # UUID string
    data = Column(LargeBinary, nullable=False)
    content_type = Column(String(50), nullable=False, server_default="image/jpeg")
    created_at = Column(DateTime, server_default=func.now())


class UploadRecord(Base):
    """Tracks who uploaded each image to enable ownership-based deletion.

    ``key`` stores either the S3 object key (e.g. ``listings/uuid.jpg``) for
    S3-backed uploads or the ImageBlob UUID for database-mode uploads.
    ``uploaded_by_user_id`` is NULL when the upload was made without
    authentication (e.g. anonymous or pre-auth-tracking requests).
    """

    __tablename__ = "upload_records"
    __table_args__ = (
        Index("ix_upload_records_key", "key"),
        Index("ix_upload_records_user_id", "uploaded_by_user_id"),
    )

    id = Column(Integer, primary_key=True)
    key = Column(String(512), nullable=False, unique=True)
    uploaded_by_user_id = Column(
        Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True
    )
    created_at = Column(DateTime, server_default=func.now())