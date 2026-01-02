from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List

from app.database.database import get_db
from app.models.models import User, Client, Property, PropertyImage, Listing, Inquiry, Appointment, Transaction, Payment
from app.schemas.schemas import (
    UserCreate, UserResponse,
    ClientCreate, ClientResponse,
    PropertyCreate, PropertyResponse,
    PropertyImageCreate, PropertyImageResponse,
    ListingCreate, ListingResponse,
    InquiryCreate, InquiryResponse,
    AppointmentCreate, AppointmentResponse,
    TransactionCreate, TransactionResponse,
    PaymentCreate, PaymentResponse
)

router = APIRouter()


# ========== USER ENDPOINTS ==========

@router.get("/users/", response_model=List[UserResponse])
def get_users(db: Session = Depends(get_db)):
    return db.query(User).all()


@router.get("/users/{user_id}", response_model=UserResponse)
def get_user(user_id: int, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user


@router.post("/users/", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
def create_user(user: UserCreate, db: Session = Depends(get_db)):
    # In production, hash the password before storing
    db_user = User(
        role=user.role,
        first_name=user.first_name,
        last_name=user.last_name,
        email=user.email,
        phone=user.phone,
        password_hash=user.password  # This should be hashed
    )
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user


@router.put("/users/{user_id}", response_model=UserResponse)
def update_user(user_id: int, user_update: UserCreate, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    # Update user fields
    for key, value in user_update.dict().items():
        setattr(user, key, value)
    
    db.commit()
    db.refresh(user)
    return user


@router.delete("/users/{user_id}", status_code=status.HTTP_200_OK)
def delete_user(user_id: int, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    
    db.delete(user)
    db.commit()
    return {"message": "User deleted successfully"}


# ========== CLIENT ENDPOINTS ==========

@router.get("/clients/", response_model=List[ClientResponse])
def get_clients(db: Session = Depends(get_db)):
    return db.query(Client).all()


@router.get("/clients/{client_id}", response_model=ClientResponse)
def get_client(client_id: int, db: Session = Depends(get_db)):
    client = db.query(Client).filter(Client.id == client_id).first()
    if not client:
        raise HTTPException(status_code=404, detail="Client not found")
    return client


@router.post("/clients/", response_model=ClientResponse, status_code=status.HTTP_201_CREATED)
def create_client(client: ClientCreate, db: Session = Depends(get_db)):
    db_client = Client(
        first_name=client.first_name,
        last_name=client.last_name,
        email=client.email,
        phone=client.phone,
        client_type=client.client_type,
        agent_id=client.agent_id
    )
    db.add(db_client)
    db.commit()
    db.refresh(db_client)
    return db_client


@router.put("/clients/{client_id}", response_model=ClientResponse)
def update_client(client_id: int, client_update: ClientCreate, db: Session = Depends(get_db)):
    client = db.query(Client).filter(Client.id == client_id).first()
    if not client:
        raise HTTPException(status_code=404, detail="Client not found")
    
    for key, value in client_update.dict().items():
        setattr(client, key, value)
    
    db.commit()
    db.refresh(client)
    return client


@router.delete("/clients/{client_id}", status_code=status.HTTP_200_OK)
def delete_client(client_id: int, db: Session = Depends(get_db)):
    client = db.query(Client).filter(Client.id == client_id).first()
    if not client:
        raise HTTPException(status_code=404, detail="Client not found")
    
    db.delete(client)
    db.commit()
    return {"message": "Client deleted successfully"}


# ========== PROPERTY ENDPOINTS ==========

@router.get("/properties/", response_model=List[PropertyResponse])
def get_properties(db: Session = Depends(get_db)):
    return db.query(Property).all()


@router.get("/properties/{property_id}", response_model=PropertyResponse)
def get_property(property_id: int, db: Session = Depends(get_db)):
    property = db.query(Property).filter(Property.id == property_id).first()
    if not property:
        raise HTTPException(status_code=404, detail="Property not found")
    return property


@router.post("/properties/", response_model=PropertyResponse, status_code=status.HTTP_201_CREATED)
def create_property(property: PropertyCreate, db: Session = Depends(get_db)):
    db_property = Property(
        title=property.title,
        description=property.description,
        property_type=property.property_type,
        address=property.address,
        city=property.city,
        price=property.price,
        bedrooms=property.bedrooms,
        bathrooms=property.bathrooms,
        area_sqft=property.area_sqft,
        owner_id=property.owner_id,
        agent_id=property.agent_id
    )
    db.add(db_property)
    db.commit()
    db.refresh(db_property)
    return db_property


@router.put("/properties/{property_id}", response_model=PropertyResponse)
def update_property(property_id: int, property_update: PropertyCreate, db: Session = Depends(get_db)):
    property = db.query(Property).filter(Property.id == property_id).first()
    if not property:
        raise HTTPException(status_code=404, detail="Property not found")
    
    for key, value in property_update.dict().items():
        setattr(property, key, value)
    
    db.commit()
    db.refresh(property)
    return property


@router.delete("/properties/{property_id}", status_code=status.HTTP_200_OK)
def delete_property(property_id: int, db: Session = Depends(get_db)):
    property = db.query(Property).filter(Property.id == property_id).first()
    if not property:
        raise HTTPException(status_code=404, detail="Property not found")
    
    db.delete(property)
    db.commit()
    return {"message": "Property deleted successfully"}


# ========== PROPERTY IMAGE ENDPOINTS ==========

@router.get("/property-images/", response_model=List[PropertyImageResponse])
def get_property_images(db: Session = Depends(get_db)):
    return db.query(PropertyImage).all()


@router.get("/property-images/{image_id}", response_model=PropertyImageResponse)
def get_property_image(image_id: int, db: Session = Depends(get_db)):
    image = db.query(PropertyImage).filter(PropertyImage.id == image_id).first()
    if not image:
        raise HTTPException(status_code=404, detail="Property image not found")
    return image


@router.post("/property-images/", response_model=PropertyImageResponse, status_code=status.HTTP_201_CREATED)
def create_property_image(image: PropertyImageCreate, db: Session = Depends(get_db)):
    db_image = PropertyImage(
        property_id=image.property_id,
        image_url=image.image_url,
        is_primary=image.is_primary
    )
    db.add(db_image)
    db.commit()
    db.refresh(db_image)
    return db_image


@router.delete("/property-images/{image_id}", status_code=status.HTTP_200_OK)
def delete_property_image(image_id: int, db: Session = Depends(get_db)):
    image = db.query(PropertyImage).filter(PropertyImage.id == image_id).first()
    if not image:
        raise HTTPException(status_code=404, detail="Property image not found")
    
    db.delete(image)
    db.commit()
    return {"message": "Property image deleted successfully"}


# ========== LISTING ENDPOINTS ==========

@router.get("/listings/", response_model=List[ListingResponse])
def get_listings(db: Session = Depends(get_db)):
    return db.query(Listing).all()


@router.get("/listings/{listing_id}", response_model=ListingResponse)
def get_listing(listing_id: int, db: Session = Depends(get_db)):
    listing = db.query(Listing).filter(Listing.id == listing_id).first()
    if not listing:
        raise HTTPException(status_code=404, detail="Listing not found")
    return listing


@router.post("/listings/", response_model=ListingResponse, status_code=status.HTTP_201_CREATED)
def create_listing(listing: ListingCreate, db: Session = Depends(get_db)):
    db_listing = Listing(
        property_id=listing.property_id,
        listing_type=listing.listing_type,
        listed_price=listing.listed_price,
        listing_date=listing.listing_date,
        expiry_date=listing.expiry_date
    )
    db.add(db_listing)
    db.commit()
    db.refresh(db_listing)
    return db_listing


# ========== INQUIRY ENDPOINTS ==========

@router.get("/inquiries/", response_model=List[InquiryResponse])
def get_inquiries(db: Session = Depends(get_db)):
    return db.query(Inquiry).all()


@router.get("/inquiries/{inquiry_id}", response_model=InquiryResponse)
def get_inquiry(inquiry_id: int, db: Session = Depends(get_db)):
    inquiry = db.query(Inquiry).filter(Inquiry.id == inquiry_id).first()
    if not inquiry:
        raise HTTPException(status_code=404, detail="Inquiry not found")
    return inquiry


@router.post("/inquiries/", response_model=InquiryResponse, status_code=status.HTTP_201_CREATED)
def create_inquiry(inquiry: InquiryCreate, db: Session = Depends(get_db)):
    db_inquiry = Inquiry(
        property_id=inquiry.property_id,
        client_id=inquiry.client_id,
        message=inquiry.message
    )
    db.add(db_inquiry)
    db.commit()
    db.refresh(db_inquiry)
    return db_inquiry


# ========== APPOINTMENT ENDPOINTS ==========

@router.get("/appointments/", response_model=List[AppointmentResponse])
def get_appointments(db: Session = Depends(get_db)):
    return db.query(Appointment).all()


@router.get("/appointments/{appointment_id}", response_model=AppointmentResponse)
def get_appointment(appointment_id: int, db: Session = Depends(get_db)):
    appointment = db.query(Appointment).filter(Appointment.id == appointment_id).first()
    if not appointment:
        raise HTTPException(status_code=404, detail="Appointment not found")
    return appointment


@router.post("/appointments/", response_model=AppointmentResponse, status_code=status.HTTP_201_CREATED)
def create_appointment(appointment: AppointmentCreate, db: Session = Depends(get_db)):
    db_appointment = Appointment(
        property_id=appointment.property_id,
        agent_id=appointment.agent_id,
        client_id=appointment.client_id,
        appointment_date=appointment.appointment_date
    )
    db.add(db_appointment)
    db.commit()
    db.refresh(db_appointment)
    return db_appointment


# ========== TRANSACTION ENDPOINTS ==========

@router.get("/transactions/", response_model=List[TransactionResponse])
def get_transactions(db: Session = Depends(get_db)):
    return db.query(Transaction).all()


@router.get("/transactions/{transaction_id}", response_model=TransactionResponse)
def get_transaction(transaction_id: int, db: Session = Depends(get_db)):
    transaction = db.query(Transaction).filter(Transaction.id == transaction_id).first()
    if not transaction:
        raise HTTPException(status_code=404, detail="Transaction not found")
    return transaction


@router.post("/transactions/", response_model=TransactionResponse, status_code=status.HTTP_201_CREATED)
def create_transaction(transaction: TransactionCreate, db: Session = Depends(get_db)):
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


# ========== PAYMENT ENDPOINTS ==========

@router.get("/payments/", response_model=List[PaymentResponse])
def get_payments(db: Session = Depends(get_db)):
    return db.query(Payment).all()


@router.get("/payments/{payment_id}", response_model=PaymentResponse)
def get_payment(payment_id: int, db: Session = Depends(get_db)):
    payment = db.query(Payment).filter(Payment.id == payment_id).first()
    if not payment:
        raise HTTPException(status_code=404, detail="Payment not found")
    return payment


@router.post("/payments/", response_model=PaymentResponse, status_code=status.HTTP_201_CREATED)
def create_payment(payment: PaymentCreate, db: Session = Depends(get_db)):
    db_payment = Payment(
        transaction_id=payment.transaction_id,
        amount=payment.amount,
        payment_method=payment.payment_method
    )
    db.add(db_payment)
    db.commit()
    db.refresh(db_payment)
    return db_payment