"""
Extended marketplace models for the SaaS platform.
Covers tenants, subscriptions, agriculture, manufacturing, orders,
messaging, RFQ, reviews, and notifications.
"""
from sqlalchemy import (
    Column, Integer, String, Text, Date, DateTime,
    Enum, ForeignKey, Boolean, DECIMAL, Index, JSON, Float, UniqueConstraint
)
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from ..database.database import Base


# ---------------------------------------------------------------------------
# Tenant & Subscription
# ---------------------------------------------------------------------------

class Tenant(Base):
    __tablename__ = "tenants"
    __table_args__ = (
        Index("ix_tenants_owner_user_id", "owner_user_id"),
    )

    id = Column(Integer, primary_key=True)
    owner_user_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    name = Column(String(255), nullable=False)
    slug = Column(String(100), unique=True, nullable=False)
    tenant_type = Column(
        Enum("individual", "sme", "enterprise", "government", "ngo", name="tenant_types"),
        nullable=False,
    )
    description = Column(Text)
    logo_url = Column(Text)
    website = Column(String(255))
    phone = Column(String(30))
    email = Column(String(255))
    address = Column(Text)
    country = Column(String(100))
    is_verified = Column(Boolean, default=False)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, server_default=func.now())

    owner = relationship("User", foreign_keys=[owner_user_id])
    subscriptions = relationship("TenantSubscription", back_populates="tenant")
    agriculture_listings = relationship("AgricultureListing", back_populates="tenant")
    manufacturing_products = relationship("ManufacturingProduct", back_populates="tenant")
    orders_as_seller = relationship("Order", back_populates="seller_tenant", foreign_keys="Order.seller_tenant_id")


class SubscriptionPlan(Base):
    __tablename__ = "subscription_plans"

    id = Column(Integer, primary_key=True)
    name = Column(String(100), nullable=False)
    tier = Column(
        Enum("free", "professional", "enterprise", "government", name="subscription_tiers"),
        nullable=False,
    )
    price_monthly = Column(DECIMAL(10, 2), nullable=False, default=0)
    price_annual = Column(DECIMAL(10, 2))
    listing_limit = Column(Integer, default=10)
    api_access = Column(Boolean, default=False)
    white_label = Column(Boolean, default=False)
    priority_support = Column(Boolean, default=False)
    advanced_analytics = Column(Boolean, default=False)
    features = Column(JSON)
    is_active = Column(Boolean, default=True)
    created_at = Column(DateTime, server_default=func.now())

    subscriptions = relationship("TenantSubscription", back_populates="plan")


class TenantSubscription(Base):
    __tablename__ = "tenant_subscriptions"
    __table_args__ = (
        Index("ix_tenant_subscriptions_tenant_id", "tenant_id"),
        Index("ix_tenant_subscriptions_plan_id", "plan_id"),
    )

    id = Column(Integer, primary_key=True)
    tenant_id = Column(Integer, ForeignKey("tenants.id", ondelete="CASCADE"))
    plan_id = Column(Integer, ForeignKey("subscription_plans.id", ondelete="RESTRICT"))
    status = Column(
        Enum("active", "cancelled", "past_due", "trialing", name="subscription_status"),
        default="active",
        server_default="active",
        nullable=False,
    )
    billing_cycle = Column(
        Enum("monthly", "annual", name="billing_cycles"),
        default="monthly",
        server_default="monthly",
        nullable=False,
    )
    start_date = Column(Date, nullable=False)
    end_date = Column(Date)
    created_at = Column(DateTime, server_default=func.now())

    tenant = relationship("Tenant", back_populates="subscriptions")
    plan = relationship("SubscriptionPlan", back_populates="subscriptions")


# ---------------------------------------------------------------------------
# Agriculture Module
# ---------------------------------------------------------------------------

class AgricultureListing(Base):
    __tablename__ = "agriculture_listings"
    __table_args__ = (
        Index("ix_agri_tenant_id", "tenant_id"),
        Index("ix_agri_status", "status"),
        Index("ix_agri_category", "category"),
    )

    id = Column(Integer, primary_key=True)
    tenant_id = Column(Integer, ForeignKey("tenants.id", ondelete="CASCADE"))
    owner_user_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    title = Column(String(255), nullable=False)
    description = Column(Text)
    category = Column(String(100))          # grains, livestock, produce, etc.
    commodity_type = Column(String(100))    # wheat, maize, cattle, etc.
    quantity_available = Column(Float)
    unit = Column(String(30))               # kg, tons, units, litres
    moq = Column(Float)                     # Minimum Order Quantity
    price_per_unit = Column(DECIMAL(12, 2), nullable=False)
    currency = Column(String(10), default="USD")
    quality_grade = Column(String(50))
    harvest_date = Column(Date)
    expiry_date = Column(Date)
    storage_conditions = Column(Text)
    certification = Column(String(255))     # organic, GAP, etc.
    location = Column(String(255))
    latitude = Column(Float)
    longitude = Column(Float)
    map_link = Column(Text)
    is_perishable = Column(Boolean, default=False)
    images = Column(JSON)                   # list of image URLs
    listing_code = Column(String(30), unique=True, nullable=True)   # e.g. ORT-AGRI-2024-AB1C2D
    is_deleted = Column(Boolean, default=False, server_default="false", nullable=False)
    status = Column(
        Enum("available", "sold_out", "reserved", "expired", name="agri_listing_status"),
        default="available",
        server_default="available",
        nullable=False,
    )
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())

    tenant = relationship("Tenant", back_populates="agriculture_listings")
    owner = relationship("User", foreign_keys=[owner_user_id])
    order_items = relationship("OrderItem", back_populates="agriculture_listing")


# ---------------------------------------------------------------------------
# Manufacturing / Wholesale Module
# ---------------------------------------------------------------------------

class ManufacturingProduct(Base):
    __tablename__ = "manufacturing_products"
    __table_args__ = (
        Index("ix_mfg_tenant_id", "tenant_id"),
        Index("ix_mfg_status", "status"),
        Index("ix_mfg_category", "category"),
    )

    id = Column(Integer, primary_key=True)
    tenant_id = Column(Integer, ForeignKey("tenants.id", ondelete="CASCADE"))
    owner_user_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    title = Column(String(255), nullable=False)
    description = Column(Text)
    category = Column(String(100))          # textiles, crafts, processed_foods, etc.
    sku = Column(String(100))
    batch_number = Column(String(100))
    quantity_available = Column(Integer)
    moq = Column(Integer)                   # Minimum Order Quantity
    unit = Column(String(30))               # units, pieces, kg, etc.
    wholesale_price = Column(DECIMAL(12, 2), nullable=False)
    currency = Column(String(10), default="USD")
    tiered_pricing = Column(JSON)           # [{min_qty: 100, price: 4.50}, ...]
    certifications = Column(JSON)           # ["ISO 9001", "NAFDAC", ...]
    images = Column(JSON)
    supply_chain_info = Column(Text)
    lead_time_days = Column(Integer)
    is_locally_made = Column(Boolean, default=True)
    country_of_origin = Column(String(100))
    location = Column(String(255))
    latitude = Column(Float)
    longitude = Column(Float)
    map_link = Column(Text)
    listing_code = Column(String(30), unique=True, nullable=True)   # e.g. ORT-MFG-2024-AB1C2D
    is_deleted = Column(Boolean, default=False, server_default="false", nullable=False)
    status = Column(
        Enum("available", "out_of_stock", "discontinued", name="mfg_product_status"),
        default="available",
        server_default="available",
        nullable=False,
    )
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())

    tenant = relationship("Tenant", back_populates="manufacturing_products")
    owner = relationship("User", foreign_keys=[owner_user_id])
    order_items = relationship("OrderItem", back_populates="manufacturing_product")


# ---------------------------------------------------------------------------
# Manufacturing Services
# ---------------------------------------------------------------------------

class ManufacturingService(Base):
    __tablename__ = "manufacturing_services"
    __table_args__ = (
        Index("ix_mfg_svc_tenant_id", "tenant_id"),
        Index("ix_mfg_svc_status", "status"),
        Index("ix_mfg_svc_service_type", "service_type"),
    )

    id = Column(Integer, primary_key=True)
    tenant_id = Column(Integer, ForeignKey("tenants.id", ondelete="CASCADE"), nullable=True)
    owner_user_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    title = Column(String(255), nullable=False)
    description = Column(Text)
    service_type = Column(String(100))      # machining, fabrication, welding, etc.
    price = Column(DECIMAL(12, 2), nullable=False)
    pricing_unit = Column(String(50))       # per_hour, per_day, per_project, per_piece, fixed
    currency = Column(String(10), default="USD", server_default="USD")
    min_order_value = Column(DECIMAL(12, 2))
    notice_period_days = Column(Integer)    # days notice required to engage service
    certifications = Column(JSON)           # ["ISO 9001", "CE", ...]
    images = Column(JSON)
    location = Column(String(255))
    country = Column(String(100))
    latitude = Column(Float)
    longitude = Column(Float)
    listing_code = Column(String(30), unique=True, nullable=True)   # e.g. ORT-SVC-2024-AB1C2D
    is_deleted = Column(Boolean, default=False, server_default="false", nullable=False)
    status = Column(
        String(50),
        default="available",
        server_default="available",
        nullable=False,
    )
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())

    owner = relationship("User", foreign_keys=[owner_user_id])


# ---------------------------------------------------------------------------
# Order Management
# ---------------------------------------------------------------------------

class Order(Base):
    __tablename__ = "orders"
    __table_args__ = (
        Index("ix_orders_buyer_user_id", "buyer_user_id"),
        Index("ix_orders_seller_tenant_id", "seller_tenant_id"),
        Index("ix_orders_status", "status"),
    )

    id = Column(Integer, primary_key=True)
    order_number = Column(String(50), unique=True, nullable=False)
    buyer_user_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    seller_tenant_id = Column(Integer, ForeignKey("tenants.id", ondelete="SET NULL"), nullable=True)
    status = Column(
        Enum(
            "pending", "confirmed", "processing", "shipped",
            "delivered", "cancelled", "disputed",
            name="order_status",
        ),
        default="pending",
        server_default="pending",
        nullable=False,
    )
    total_amount = Column(DECIMAL(14, 2))
    currency = Column(String(10), default="USD", server_default="USD", nullable=False)
    payment_status = Column(
        Enum("unpaid", "partial", "paid", "refunded", name="order_payment_status"),
        default="unpaid",
        server_default="unpaid",
        nullable=False,
    )
    payment_method = Column(String(50))
    delivery_address = Column(Text)
    notes = Column(Text)
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())

    buyer = relationship("User", foreign_keys=[buyer_user_id])
    seller_tenant = relationship("Tenant", back_populates="orders_as_seller")
    items = relationship("OrderItem", back_populates="order", cascade="all, delete")


class OrderItem(Base):
    __tablename__ = "order_items"
    __table_args__ = (
        Index("ix_order_items_order_id", "order_id"),
    )

    id = Column(Integer, primary_key=True)
    order_id = Column(Integer, ForeignKey("orders.id", ondelete="CASCADE"))
    # Exactly one of the following FKs is set
    property_id = Column(
        Integer, ForeignKey("properties.id", ondelete="SET NULL"), nullable=True
    )
    agriculture_listing_id = Column(
        Integer, ForeignKey("agriculture_listings.id", ondelete="SET NULL"), nullable=True
    )
    manufacturing_product_id = Column(
        Integer, ForeignKey("manufacturing_products.id", ondelete="SET NULL"), nullable=True
    )
    quantity = Column(Float, nullable=False, default=1)
    unit_price = Column(DECIMAL(12, 2), nullable=False)
    subtotal = Column(DECIMAL(14, 2), nullable=False)

    order = relationship("Order", back_populates="items")
    agriculture_listing = relationship("AgricultureListing", back_populates="order_items")
    manufacturing_product = relationship("ManufacturingProduct", back_populates="order_items")


# ---------------------------------------------------------------------------
# Messaging
# ---------------------------------------------------------------------------

class Conversation(Base):
    __tablename__ = "conversations"
    __table_args__ = (
        Index("ix_conversations_initiator_id", "initiator_id"),
        Index("ix_conversations_recipient_id", "recipient_id"),
    )

    id = Column(Integer, primary_key=True)
    initiator_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    recipient_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    subject = Column(String(255))
    # optional context references
    property_id = Column(Integer, ForeignKey("properties.id", ondelete="SET NULL"), nullable=True)
    order_id = Column(Integer, ForeignKey("orders.id", ondelete="SET NULL"), nullable=True)
    created_at = Column(DateTime, server_default=func.now())

    initiator = relationship("User", foreign_keys=[initiator_id])
    recipient = relationship("User", foreign_keys=[recipient_id])
    messages = relationship("Message", back_populates="conversation", cascade="all, delete")


class Message(Base):
    __tablename__ = "messages"
    __table_args__ = (
        Index("ix_messages_conversation_id", "conversation_id"),
        Index("ix_messages_sender_id", "sender_id"),
    )

    id = Column(Integer, primary_key=True)
    conversation_id = Column(Integer, ForeignKey("conversations.id", ondelete="CASCADE"))
    sender_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    body = Column(Text, nullable=False)
    attachment_url = Column(Text)
    attachment_filename = Column(String(255), nullable=True)  # original filename for downloads
    message_type = Column(
        Enum("text", "file", "voice", name="message_types"),
        default="text",
        server_default="text",
        nullable=False,
    )
    is_read = Column(Boolean, default=False)
    is_deleted = Column(Boolean, default=False, server_default="false", nullable=False)
    sent_at = Column(DateTime, server_default=func.now())

    conversation = relationship("Conversation", back_populates="messages")
    sender = relationship("User", foreign_keys=[sender_id])


# ---------------------------------------------------------------------------
# Request for Quote (RFQ)
# ---------------------------------------------------------------------------

class RFQ(Base):
    __tablename__ = "rfqs"
    __table_args__ = (
        Index("ix_rfqs_buyer_id", "buyer_id"),
        Index("ix_rfqs_seller_tenant_id", "seller_tenant_id"),
        Index("ix_rfqs_status", "status"),
    )

    id = Column(Integer, primary_key=True)
    buyer_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    seller_tenant_id = Column(Integer, ForeignKey("tenants.id", ondelete="SET NULL"), nullable=True)
    property_id = Column(Integer, ForeignKey("properties.id", ondelete="SET NULL"), nullable=True)
    title = Column(String(255), nullable=False)
    description = Column(Text)
    category = Column(String(100))      # property, agriculture, manufacturing
    quantity = Column(Float)
    unit = Column(String(30))
    target_price = Column(DECIMAL(12, 2))
    currency = Column(String(10), default="USD", server_default="USD", nullable=False)
    deadline = Column(Date)
    status = Column(
        Enum("open", "quoted", "accepted", "rejected", "expired", name="rfq_status"),
        default="open",
        server_default="open",
        nullable=False,
    )
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())

    buyer = relationship("User", foreign_keys=[buyer_id])
    seller_tenant = relationship("Tenant")
    responses = relationship("RFQResponse", back_populates="rfq", cascade="all, delete")


class RFQResponse(Base):
    __tablename__ = "rfq_responses"
    __table_args__ = (
        Index("ix_rfq_responses_rfq_id", "rfq_id"),
        Index("ix_rfq_responses_responder_tenant_id", "responder_tenant_id"),
    )

    id = Column(Integer, primary_key=True)
    rfq_id = Column(Integer, ForeignKey("rfqs.id", ondelete="CASCADE"))
    responder_tenant_id = Column(Integer, ForeignKey("tenants.id", ondelete="SET NULL"), nullable=True)
    quoted_price = Column(DECIMAL(12, 2), nullable=False)
    currency = Column(String(10), default="USD", server_default="USD", nullable=False)
    notes = Column(Text)
    valid_until = Column(Date)
    status = Column(
        Enum("pending", "accepted", "rejected", name="rfq_response_status"),
        default="pending",
        server_default="pending",
        nullable=False,
    )
    created_at = Column(DateTime, server_default=func.now())

    rfq = relationship("RFQ", back_populates="responses")
    responder_tenant = relationship("Tenant")


# ---------------------------------------------------------------------------
# Reviews & Ratings
# ---------------------------------------------------------------------------

class Review(Base):
    __tablename__ = "reviews"
    __table_args__ = (
        Index("ix_reviews_reviewer_id", "reviewer_id"),
        Index("ix_reviews_tenant_id", "reviewed_tenant_id"),
        Index("ix_reviews_agent_id", "reviewed_agent_id"),
    )

    id = Column(Integer, primary_key=True)
    reviewer_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    reviewed_tenant_id = Column(Integer, ForeignKey("tenants.id", ondelete="CASCADE"), nullable=True)
    reviewed_agent_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=True)
    # optional context
    order_id = Column(Integer, ForeignKey("orders.id", ondelete="SET NULL"), nullable=True)
    property_id = Column(Integer, ForeignKey("properties.id", ondelete="SET NULL"), nullable=True)
    rating = Column(Integer, nullable=False)            # 1-5
    title = Column(String(255))
    body = Column(Text)
    is_verified_purchase = Column(Boolean, default=False)
    created_at = Column(DateTime, server_default=func.now())

    reviewer = relationship("User", foreign_keys=[reviewer_id])
    reviewed_tenant = relationship("Tenant")
    reviewed_agent = relationship("User", foreign_keys=[reviewed_agent_id])


# ---------------------------------------------------------------------------
# Notifications
# ---------------------------------------------------------------------------

class Notification(Base):
    __tablename__ = "notifications"
    __table_args__ = (
        Index("ix_notifications_user_id", "user_id"),
        Index("ix_notifications_is_read", "is_read"),
    )

    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"))
    title = Column(String(255), nullable=False)
    body = Column(Text)
    notification_type = Column(String(50))  # order_update, message, rfq, etc.
    reference_id = Column(Integer)          # ID of the related entity
    reference_type = Column(String(50))     # order, message, rfq, etc.
    is_read = Column(Boolean, default=False)
    created_at = Column(DateTime, server_default=func.now())

    user = relationship("User", foreign_keys=[user_id])


# ---------------------------------------------------------------------------
# Saved / Favourited Items
# ---------------------------------------------------------------------------

class SavedItem(Base):
    __tablename__ = "saved_items"
    __table_args__ = (
        Index("ix_saved_items_user_id", "user_id"),
        Index("ix_saved_items_item_type", "item_type"),
        # Prevent duplicate saves at the database level
        UniqueConstraint("user_id", "item_type", "item_id", name="uq_saved_items_user_type_item"),
    )

    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    item_type = Column(String(50), nullable=False)   # property, agriculture, manufacturing
    item_id = Column(Integer, nullable=False)
    created_at = Column(DateTime, server_default=func.now())

    user = relationship("User", foreign_keys=[user_id])


# ---------------------------------------------------------------------------
# Admin / Support
# ---------------------------------------------------------------------------

class AdminLog(Base):
    __tablename__ = "admin_logs"
    __table_args__ = (
        Index("ix_admin_logs_admin_id", "admin_id"),
    )
    id = Column(Integer, primary_key=True)
    admin_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    action = Column(String(100), nullable=False)
    target_type = Column(String(50))   # e.g. "user", "property", "ticket"
    target_id = Column(Integer)
    detail = Column(Text)
    created_at = Column(DateTime, server_default=func.now())
    admin = relationship("User", foreign_keys=[admin_id])

class SupportTicket(Base):
    __tablename__ = "support_tickets"
    __table_args__ = (
        Index("ix_support_tickets_user_id", "user_id"),
        Index("ix_support_tickets_status", "status"),
    )
    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    assigned_to = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    subject = Column(String(255), nullable=False)
    body = Column(Text, nullable=False)
    status = Column(String(50), default="open", server_default="open", nullable=False)
    resolution = Column(Text)
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())
    user = relationship("User", foreign_keys=[user_id])
    assignee = relationship("User", foreign_keys=[assigned_to])


# ---------------------------------------------------------------------------
# Wallet & Wallet Transactions
# ---------------------------------------------------------------------------

class UserWallet(Base):
    __tablename__ = "user_wallets"
    __table_args__ = (
        Index("ix_user_wallets_user_id", "user_id"),
    )

    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False, unique=True)
    points = Column(Integer, default=0, server_default="0", nullable=False)
    created_at = Column(DateTime, server_default=func.now())
    updated_at = Column(DateTime, server_default=func.now(), onupdate=func.now())

    user = relationship("User", foreign_keys=[user_id])
    transactions = relationship("WalletTransaction", back_populates="wallet", cascade="all, delete")


class WalletTransaction(Base):
    """Records every debit/credit to a user's wallet."""
    __tablename__ = "wallet_transactions"
    __table_args__ = (
        Index("ix_wallet_transactions_wallet_id", "wallet_id"),
    )

    id = Column(Integer, primary_key=True)
    wallet_id = Column(Integer, ForeignKey("user_wallets.id", ondelete="CASCADE"), nullable=False)
    # "topup" | "spend"
    transaction_type = Column(String(20), nullable=False, server_default="topup")
    amount = Column(Integer, nullable=False)          # points credited or debited
    # payment method for top-ups: "mtn" | "airtel" | "card"
    payment_method = Column(String(30), nullable=True)
    # free-text reference, e.g. phone number, card last-4, or promotion id
    reference = Column(String(255), nullable=True)
    description = Column(String(255), nullable=True)
    created_at = Column(DateTime, server_default=func.now())

    wallet = relationship("UserWallet", back_populates="transactions")


# ---------------------------------------------------------------------------
# Ad Promotions
# ---------------------------------------------------------------------------

class AdPromotion(Base):
    """Tracks paid promotions that display listings at hotspot positions."""
    __tablename__ = "ad_promotions"
    __table_args__ = (
        Index("ix_ad_promotions_user_id", "user_id"),
        Index("ix_ad_promotions_listing", "listing_type", "listing_id"),
        Index("ix_ad_promotions_end_date", "end_date"),
    )

    id = Column(Integer, primary_key=True)
    user_id = Column(Integer, ForeignKey("users.id", ondelete="CASCADE"), nullable=False)
    # "property" | "agriculture" | "manufacturing"
    listing_type = Column(String(30), nullable=False)
    listing_id = Column(Integer, nullable=False)
    duration_days = Column(Integer, nullable=False)   # 7 | 30 | 365
    cost_points = Column(Integer, nullable=False)     # 10 | 26 | 300
    start_date = Column(DateTime, server_default=func.now(), nullable=False)
    end_date = Column(DateTime, nullable=False)
    # "active" | "expired" | "cancelled"
    status = Column(String(20), default="active", server_default="active", nullable=False)
    created_at = Column(DateTime, server_default=func.now())

    user = relationship("User", foreign_keys=[user_id])


# ---------------------------------------------------------------------------
# Product / Order Tracking
# ---------------------------------------------------------------------------

class ProductTracking(Base):
    """Real-time transit updates posted by agents, companies, or organisations.

    Can reference an Order (order_id) or any listing (listing_type + listing_id).
    """

    __tablename__ = "product_tracking"
    __table_args__ = (
        Index("ix_product_tracking_order_id", "order_id"),
        Index("ix_product_tracking_listing", "listing_type", "listing_id"),
        Index("ix_product_tracking_created_by", "created_by_user_id"),
    )

    id = Column(Integer, primary_key=True)
    order_id = Column(Integer, ForeignKey("orders.id", ondelete="CASCADE"), nullable=True)
    listing_type = Column(String(50), nullable=True)   # property, agriculture, manufacturing
    listing_id = Column(Integer, nullable=True)
    # e.g. "order_placed", "processing", "packed", "shipped", "in_transit",
    #      "out_for_delivery", "delivered", "cancelled"
    status = Column(String(50), nullable=False)
    location = Column(String(255), nullable=True)
    description = Column(Text, nullable=True)
    created_by_user_id = Column(Integer, ForeignKey("users.id", ondelete="SET NULL"), nullable=True)
    created_at = Column(DateTime, server_default=func.now())

    created_by = relationship("User", foreign_keys=[created_by_user_id])
