from sqlalchemy import Column, Integer, Date, ForeignKey, DECIMAL, String
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
from ..database import Base


class Transaction(Base):
    """Real estate transaction model"""
    __tablename__ = "transactions"

    id = Column(Integer, primary_key=True)
    property_id = Column(Integer, ForeignKey("properties.id"))
    agent_id = Column(Integer, ForeignKey("users.id"))
    buyer_id = Column(Integer, ForeignKey("clients.id"))
    sale_price = Column(DECIMAL(12, 2), nullable=False)
    commission = Column(DECIMAL(12, 2))
    transaction_date = Column(Date, nullable=False)

    # Relationships
    property = relationship("Property")
    agent = relationship("User")
    buyer = relationship("Client")
    payments = relationship("Payment", back_populates="transaction", cascade="all, delete")


class Payment(Base):
    """Payment model for transactions"""
    __tablename__ = "payments"

    id = Column(Integer, primary_key=True)
    transaction_id = Column(Integer, ForeignKey("transactions.id", ondelete="CASCADE"))
    amount = Column(DECIMAL(12, 2), nullable=False)
    payment_method = Column(String(30))
    payment_date = Column(Date, server_default=func.current_date())

    # Relationships
    transaction = relationship("Transaction", back_populates="payments")
