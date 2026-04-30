import os
from fastapi import APIRouter, Depends, HTTPException, Query, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from passlib.context import CryptContext
from jose import jwt, JWTError
from sqlalchemy.orm import Session
from typing import List, Optional

from app.database.database import get_db
from app.models.models import (
    Appointment, Client, Inquiry, Listing, Payment,
    Property, PropertyImage, Transaction, User,
)
from app.schemas.schemas import (
    AppointmentCreate, AppointmentResponse,
    ClientCreate, ClientResponse, ClientUpdate,
    InquiryCreate, InquiryResponse,
    ListingCreate, ListingResponse,
    PaymentCreate, PaymentResponse,
    PropertyCreate, PropertyImageCreate, PropertyImageResponse,
    PropertyResponse, PropertyUpdate,
    TransactionCreate, TransactionResponse,
    UserCreate, UserResponse, UserUpdate,
)
from app.schemas.marketplace_schemas import PropertyStatusUpdate
from app.utils.geo import haversine_km

# Marketplace module routers
from app.api.v1 import (
    auth as auth_router,
    tenants as tenants_router,
    agriculture as agriculture_router,
    manufacturing as manufacturing_router,
    orders as orders_router,
    messages as messages_router,
    rfq as rfq_router,
    reviews as reviews_router,
    notifications as notifications_router,
    upload as upload_router,
    admin as admin_module,
    saved_items as saved_items_router,
)

router = APIRouter()

# Register marketplace module routers
router.include_router(auth_router.router)
router.include_router(tenants_router.router)
router.include_router(agriculture_router.router)
router.include_router(manufacturing_router.router)
router.include_router(orders_router.router)
router.include_router(messages_router.conversations_router)
router.include_router(messages_router.router)
router.include_router(rfq_router.router)
router.include_router(reviews_router.router)
router.include_router(notifications_router.router)
router.include_router(upload_router.router)
router.include_router(admin_module.router)
router.include_router(admin_module.user_tickets_router)
router.include_router(saved_items_router.router)

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")

_bearer = HTTPBearer(auto_error=False)

SECRET_KEY = os.getenv("SECRET_KEY", "change-me-in-production")
ALGORITHM = "HS256"





def _get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(_bearer),
    db: Session = Depends(get_db),
) -> User:
    if credentials is None:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Not authenticated")
    try:
        payload = jwt.decode(credentials.credentials, SECRET_KEY, algorithms=[ALGORITHM])
        user_id: str = payload.get("sub")
        if user_id is None:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")
    except JWTError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")
    try:
        user_id = int(user_id)
    except ValueError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid token")
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="User not found")
    return user


# ========== USER ENDPOINTS ==========

@router.get("/users/", response_model=List[UserResponse])
def get_users(
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=1000),
    db: Session = Depends(get_db),
):
    return db.query(User).offset(skip).limit(limit).all()


@router.get("/users/me", response_model=UserResponse)
def get_current_user_me(current_user: User = Depends(_get_current_user)):
    return current_user


@router.patch("/users/me", response_model=UserResponse)
def update_current_user_me(
    user_update: UserUpdate,
    current_user: User = Depends(_get_current_user),
    db: Session = Depends(get_db),
):
    """Allow the authenticated user to update their own profile."""
    data = user_update.model_dump(exclude_unset=True)
    if "password" in data:
        data["password_hash"] = pwd_context.hash(data.pop("password")[:72])
    for key, value in data.items():
        setattr(current_user, key, value)
    db.commit()
    db.refresh(current_user)
    return current_user


@router.get("/users/{user_id}", response_model=UserResponse)
def get_user(user_id: int, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")
    return user


@router.post("/users/", response_model=UserResponse, status_code=status.HTTP_201_CREATED)
def create_user(user: UserCreate, db: Session = Depends(get_db)):
    if db.query(User).filter(User.email == user.email).first():
        raise HTTPException(status_code=409, detail="Email already registered")
    db_user = User(
        role=user.role,
        first_name=user.first_name,
        last_name=user.last_name,
        email=user.email,
        phone=user.phone,
        password_hash=pwd_context.hash(user.password[:72]),
    )
    db.add(db_user)
    db.commit()
    db.refresh(db_user)
    return db_user


@router.put("/users/{user_id}", response_model=UserResponse)
def update_user(user_id: int, user_update: UserUpdate, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.id == user_id).first()
    if not user:
        raise HTTPException(status_code=404, detail="User not found")

    data = user_update.model_dump(exclude_unset=True)
    if "password" in data:
        data["password_hash"] = pwd_context.hash(data.pop("password")[:72])
    for key, value in data.items():
        setattr(user, key, value)

    db.commit()
    db.refresh(user)
    return user


@router.delete("/users/me", status_code=status.HTTP_200_OK)
def delete_current_user_me(
    current_user: User = Depends(_get_current_user),
    db: Session = Depends(get_db),
):
    """Allow the authenticated user to permanently delete their own account."""
    db.delete(current_user)
    db.commit()
    return {"message": "Account deleted successfully"}


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
def get_clients(
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=1000),
    db: Session = Depends(get_db),
):
    return db.query(Client).offset(skip).limit(limit).all()


@router.get("/clients/{client_id}", response_model=ClientResponse)
def get_client(client_id: int, db: Session = Depends(get_db)):
    client = db.query(Client).filter(Client.id == client_id).first()
    if not client:
        raise HTTPException(status_code=404, detail="Client not found")
    return client


@router.post("/clients/", response_model=ClientResponse, status_code=status.HTTP_201_CREATED)
def create_client(client: ClientCreate, db: Session = Depends(get_db)):
    db_client = Client(**client.model_dump())
    db.add(db_client)
    db.commit()
    db.refresh(db_client)
    return db_client


@router.put("/clients/{client_id}", response_model=ClientResponse)
def update_client(client_id: int, client_update: ClientUpdate, db: Session = Depends(get_db)):
    client = db.query(Client).filter(Client.id == client_id).first()
    if not client:
        raise HTTPException(status_code=404, detail="Client not found")

    for key, value in client_update.model_dump(exclude_unset=True).items():
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
def get_properties(
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=1000),
    keyword: Optional[str] = Query(None),
    min_price: Optional[float] = Query(None),
    max_price: Optional[float] = Query(None),
    city: Optional[str] = Query(None),
    property_type: Optional[str] = Query(None),
    status: Optional[str] = Query(None),
    lat: Optional[float] = Query(None),
    lon: Optional[float] = Query(None),
    radius_km: Optional[float] = Query(None, gt=0),
    db: Session = Depends(get_db),
):
    q = db.query(Property)
    if keyword:
        like = f"%{keyword}%"
        q = q.filter(
            (Property.title.ilike(like)) |
            (Property.address.ilike(like)) |
            (Property.city.ilike(like))
        )
    if min_price is not None:
        q = q.filter(Property.price >= min_price)
    if max_price is not None:
        q = q.filter(Property.price <= max_price)
    if city:
        q = q.filter(Property.city.ilike(f"%{city}%"))
    if property_type:
        q = q.filter(Property.property_type == property_type)
    if status:
        q = q.filter(Property.status == status)
    elif lat is not None and lon is not None and radius_km is not None:
        q = q.filter(Property.status == "available")
    props = q.offset(skip).limit(limit).all()

    if lat is not None and lon is not None and radius_km is not None:
        with_dist = []
        for p in props:
            if p.latitude is not None and p.longitude is not None:
                d = haversine_km(lat, lon, p.latitude, p.longitude)
                if d <= radius_km:
                    with_dist.append((d, p))
        with_dist.sort(key=lambda x: x[0])
        props = [p for _, p in with_dist]

    return [PropertyResponse.from_orm_with_images(p) for p in props]


@router.get("/properties/{property_id}", response_model=PropertyResponse)
def get_property(property_id: int, db: Session = Depends(get_db)):
    prop = db.query(Property).filter(Property.id == property_id).first()
    if not prop:
        raise HTTPException(status_code=404, detail="Property not found")
    return PropertyResponse.from_orm_with_images(prop)


@router.post("/properties/", response_model=PropertyResponse, status_code=status.HTTP_201_CREATED)
def create_property(prop: PropertyCreate, db: Session = Depends(get_db)):
    prop_data = prop.model_dump(exclude={"images"})
    db_property = Property(**prop_data)
    db.add(db_property)
    db.flush()  # assign id before creating images
    if prop.images:
        for idx, url in enumerate(prop.images):
            db.add(PropertyImage(property_id=db_property.id, image_url=url, is_primary=(idx == 0)))
    db.commit()
    db.refresh(db_property)
    return PropertyResponse.from_orm_with_images(db_property)


@router.put("/properties/{property_id}", response_model=PropertyResponse)
def update_property(property_id: int, prop_update: PropertyUpdate, db: Session = Depends(get_db)):
    prop = db.query(Property).filter(Property.id == property_id).first()
    if not prop:
        raise HTTPException(status_code=404, detail="Property not found")

    for key, value in prop_update.model_dump(exclude_unset=True).items():
        setattr(prop, key, value)

    db.commit()
    db.refresh(prop)
    return PropertyResponse.from_orm_with_images(prop)


@router.patch("/properties/{property_id}/status", response_model=PropertyResponse)
def update_property_status(
    property_id: int,
    payload: PropertyStatusUpdate,
    db: Session = Depends(get_db),
    current_user: User = Depends(_get_current_user),
):
    prop = db.query(Property).filter(Property.id == property_id).first()
    if not prop:
        raise HTTPException(status_code=404, detail="Property not found")
    if prop.agent_id is not None and prop.agent_id != current_user.id:
        raise HTTPException(status_code=403, detail="Not authorised to update this property")
    prop.status = payload.status
    db.commit()
    db.refresh(prop)
    return PropertyResponse.from_orm_with_images(prop)


@router.delete("/properties/{property_id}", status_code=status.HTTP_200_OK)
def delete_property(property_id: int, db: Session = Depends(get_db)):
    prop = db.query(Property).filter(Property.id == property_id).first()
    if not prop:
        raise HTTPException(status_code=404, detail="Property not found")

    db.delete(prop)
    db.commit()
    return {"message": "Property deleted successfully"}


# ========== PROPERTY IMAGE ENDPOINTS ==========

@router.get("/property-images/", response_model=List[PropertyImageResponse])
def get_property_images(
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=1000),
    property_id: Optional[int] = Query(None),
    db: Session = Depends(get_db),
):
    q = db.query(PropertyImage)
    if property_id is not None:
        q = q.filter(PropertyImage.property_id == property_id)
    return q.offset(skip).limit(limit).all()


@router.get("/property-images/{image_id}", response_model=PropertyImageResponse)
def get_property_image(image_id: int, db: Session = Depends(get_db)):
    image = db.query(PropertyImage).filter(PropertyImage.id == image_id).first()
    if not image:
        raise HTTPException(status_code=404, detail="Property image not found")
    return image


@router.post("/property-images/", response_model=PropertyImageResponse, status_code=status.HTTP_201_CREATED)
def create_property_image(image: PropertyImageCreate, db: Session = Depends(get_db)):
    db_image = PropertyImage(**image.model_dump())
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
def get_listings(
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=1000),
    db: Session = Depends(get_db),
):
    return db.query(Listing).offset(skip).limit(limit).all()


@router.get("/listings/{listing_id}", response_model=ListingResponse)
def get_listing(listing_id: int, db: Session = Depends(get_db)):
    listing = db.query(Listing).filter(Listing.id == listing_id).first()
    if not listing:
        raise HTTPException(status_code=404, detail="Listing not found")
    return listing


@router.post("/listings/", response_model=ListingResponse, status_code=status.HTTP_201_CREATED)
def create_listing(listing: ListingCreate, db: Session = Depends(get_db)):
    db_listing = Listing(**listing.model_dump())
    db.add(db_listing)
    db.commit()
    db.refresh(db_listing)
    return db_listing


# ========== INQUIRY ENDPOINTS ==========

@router.get("/inquiries/", response_model=List[InquiryResponse])
def get_inquiries(
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=1000),
    db: Session = Depends(get_db),
):
    return db.query(Inquiry).offset(skip).limit(limit).all()


@router.get("/inquiries/{inquiry_id}", response_model=InquiryResponse)
def get_inquiry(inquiry_id: int, db: Session = Depends(get_db)):
    inquiry = db.query(Inquiry).filter(Inquiry.id == inquiry_id).first()
    if not inquiry:
        raise HTTPException(status_code=404, detail="Inquiry not found")
    return inquiry


@router.post("/inquiries/", response_model=InquiryResponse, status_code=status.HTTP_201_CREATED)
def create_inquiry(inquiry: InquiryCreate, db: Session = Depends(get_db)):
    db_inquiry = Inquiry(**inquiry.model_dump())
    db.add(db_inquiry)
    db.commit()
    db.refresh(db_inquiry)
    return db_inquiry


# ========== APPOINTMENT ENDPOINTS ==========

@router.get("/appointments/", response_model=List[AppointmentResponse])
def get_appointments(
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=1000),
    db: Session = Depends(get_db),
):
    return db.query(Appointment).offset(skip).limit(limit).all()


@router.get("/appointments/{appointment_id}", response_model=AppointmentResponse)
def get_appointment(appointment_id: int, db: Session = Depends(get_db)):
    appointment = db.query(Appointment).filter(Appointment.id == appointment_id).first()
    if not appointment:
        raise HTTPException(status_code=404, detail="Appointment not found")
    return appointment


@router.post("/appointments/", response_model=AppointmentResponse, status_code=status.HTTP_201_CREATED)
def create_appointment(appointment: AppointmentCreate, db: Session = Depends(get_db)):
    db_appointment = Appointment(**appointment.model_dump())
    db.add(db_appointment)
    db.commit()
    db.refresh(db_appointment)
    return db_appointment


# ========== TRANSACTION ENDPOINTS ==========

@router.get("/transactions/", response_model=List[TransactionResponse])
def get_transactions(
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=1000),
    db: Session = Depends(get_db),
):
    return db.query(Transaction).offset(skip).limit(limit).all()


@router.get("/transactions/{transaction_id}", response_model=TransactionResponse)
def get_transaction(transaction_id: int, db: Session = Depends(get_db)):
    transaction = db.query(Transaction).filter(Transaction.id == transaction_id).first()
    if not transaction:
        raise HTTPException(status_code=404, detail="Transaction not found")
    return transaction


@router.post("/transactions/", response_model=TransactionResponse, status_code=status.HTTP_201_CREATED)
def create_transaction(transaction: TransactionCreate, db: Session = Depends(get_db)):
    db_transaction = Transaction(**transaction.model_dump())
    db.add(db_transaction)
    db.commit()
    db.refresh(db_transaction)
    return db_transaction


# ========== PAYMENT ENDPOINTS ==========

@router.get("/payments/", response_model=List[PaymentResponse])
def get_payments(
    skip: int = Query(0, ge=0),
    limit: int = Query(100, ge=1, le=1000),
    db: Session = Depends(get_db),
):
    return db.query(Payment).offset(skip).limit(limit).all()


@router.get("/payments/{payment_id}", response_model=PaymentResponse)
def get_payment(payment_id: int, db: Session = Depends(get_db)):
    payment = db.query(Payment).filter(Payment.id == payment_id).first()
    if not payment:
        raise HTTPException(status_code=404, detail="Payment not found")
    return payment


@router.post("/payments/", response_model=PaymentResponse, status_code=status.HTTP_201_CREATED)
def create_payment(payment: PaymentCreate, db: Session = Depends(get_db)):
    db_payment = Payment(**payment.model_dump())
    db.add(db_payment)
    db.commit()
    db.refresh(db_payment)
    return db_payment