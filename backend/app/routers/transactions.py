from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List

from ..database import get_db
from ..models.transaction import Transaction, Payment
from ..models.user import User
from ..schemas.transaction import (
    TransactionCreate, TransactionResponse,
    PaymentCreate, PaymentResponse
)
from ..auth import get_current_user

router = APIRouter(prefix="/transactions", tags=["Transactions"])


# ========== TRANSACTION ENDPOINTS ==========

@router.get("/", response_model=List[TransactionResponse])
def get_transactions(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get all transactions (authenticated users only)"""
    return db.query(Transaction).all()


@router.get("/{transaction_id}", response_model=TransactionResponse)
def get_transaction(
    transaction_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get a specific transaction by ID"""
    transaction = db.query(Transaction).filter(Transaction.id == transaction_id).first()
    if not transaction:
        raise HTTPException(status_code=404, detail="Transaction not found")
    return transaction


@router.post("/", response_model=TransactionResponse, status_code=status.HTTP_201_CREATED)
def create_transaction(
    transaction: TransactionCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Create a new transaction"""
    db_transaction = Transaction(
        property_id=transaction.property_id,
        agent_id=transaction.agent_id,
        buyer_id=transaction.buyer_id,
        sale_price=transaction.sale_price,
        commission=transaction.commission,
        transaction_date=transaction.transaction_date
    )
    db.add(db_transaction)
    db.commit()
    db.refresh(db_transaction)
    return db_transaction


@router.put("/{transaction_id}", response_model=TransactionResponse)
def update_transaction(
    transaction_id: int,
    transaction_update: TransactionCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Update transaction information"""
    transaction = db.query(Transaction).filter(Transaction.id == transaction_id).first()
    if not transaction:
        raise HTTPException(status_code=404, detail="Transaction not found")
    
    # Check permissions (admin or transaction agent)
    if current_user.role != "admin" and transaction.agent_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized to update this transaction"
        )
    
    for key, value in transaction_update.model_dump().items():
        setattr(transaction, key, value)
    
    db.commit()
    db.refresh(transaction)
    return transaction


@router.delete("/{transaction_id}", status_code=status.HTTP_200_OK)
def delete_transaction(
    transaction_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Delete a transaction"""
    transaction = db.query(Transaction).filter(Transaction.id == transaction_id).first()
    if not transaction:
        raise HTTPException(status_code=404, detail="Transaction not found")
    
    # Check permissions (admin only)
    if current_user.role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin access required to delete transactions"
        )
    
    db.delete(transaction)
    db.commit()
    return {"message": "Transaction deleted successfully"}


# ========== PAYMENT ENDPOINTS ==========

@router.get("/payments/all", response_model=List[PaymentResponse])
def get_payments(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get all payments"""
    return db.query(Payment).all()


@router.get("/payments/{payment_id}", response_model=PaymentResponse)
def get_payment(
    payment_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get a specific payment by ID"""
    payment = db.query(Payment).filter(Payment.id == payment_id).first()
    if not payment:
        raise HTTPException(status_code=404, detail="Payment not found")
    return payment


@router.post("/payments/", response_model=PaymentResponse, status_code=status.HTTP_201_CREATED)
def create_payment(
    payment: PaymentCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Create a new payment"""
    db_payment = Payment(
        transaction_id=payment.transaction_id,
        amount=payment.amount,
        payment_method=payment.payment_method
    )
    db.add(db_payment)
    db.commit()
    db.refresh(db_payment)
    return db_payment


@router.delete("/payments/{payment_id}", status_code=status.HTTP_200_OK)
def delete_payment(
    payment_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Delete a payment"""
    payment = db.query(Payment).filter(Payment.id == payment_id).first()
    if not payment:
        raise HTTPException(status_code=404, detail="Payment not found")
    
    # Check permissions (admin only)
    if current_user.role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Admin access required to delete payments"
        )
    
    db.delete(payment)
    db.commit()
    return {"message": "Payment deleted successfully"}
