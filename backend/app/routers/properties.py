from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List

from ..database import get_db
from ..models.property import Property, PropertyImage, Listing, Inquiry, Appointment
from ..models.user import User
from ..schemas.property import (
    PropertyCreate, PropertyResponse,
    PropertyImageCreate, PropertyImageResponse,
    ListingCreate, ListingResponse,
    InquiryCreate, InquiryResponse,
    AppointmentCreate, AppointmentResponse
)
from ..auth import get_current_user

router = APIRouter(prefix="/properties", tags=["Properties"])


# ========== PROPERTY ENDPOINTS ==========

@router.get("/", response_model=List[PropertyResponse])
def get_properties(db: Session = Depends(get_db)):
    """Get all properties (public endpoint)"""
    return db.query(Property).all()


@router.get("/{property_id}", response_model=PropertyResponse)
def get_property(property_id: int, db: Session = Depends(get_db)):
    """Get a specific property by ID (public endpoint)"""
    property = db.query(Property).filter(Property.id == property_id).first()
    if not property:
        raise HTTPException(status_code=404, detail="Property not found")
    return property


@router.post("/", response_model=PropertyResponse, status_code=status.HTTP_201_CREATED)
def create_property(
    property: PropertyCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Create a new property (authenticated users only)"""
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
        agent_id=property.agent_id or current_user.id
    )
    db.add(db_property)
    db.commit()
    db.refresh(db_property)
    return db_property


@router.put("/{property_id}", response_model=PropertyResponse)
def update_property(
    property_id: int,
    property_update: PropertyCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Update property information"""
    property = db.query(Property).filter(Property.id == property_id).first()
    if not property:
        raise HTTPException(status_code=404, detail="Property not found")
    
    # Check permissions (admin or property agent)
    if current_user.role != "admin" and property.agent_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized to update this property"
        )
    
    for key, value in property_update.model_dump().items():
        setattr(property, key, value)
    
    db.commit()
    db.refresh(property)
    return property


@router.delete("/{property_id}", status_code=status.HTTP_200_OK)
def delete_property(
    property_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Delete a property"""
    property = db.query(Property).filter(Property.id == property_id).first()
    if not property:
        raise HTTPException(status_code=404, detail="Property not found")
    
    # Check permissions (admin or property agent)
    if current_user.role != "admin" and property.agent_id != current_user.id:
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized to delete this property"
        )
    
    db.delete(property)
    db.commit()
    return {"message": "Property deleted successfully"}


# ========== PROPERTY IMAGE ENDPOINTS ==========

@router.get("/images/all", response_model=List[PropertyImageResponse])
def get_property_images(db: Session = Depends(get_db)):
    """Get all property images"""
    return db.query(PropertyImage).all()


@router.get("/images/{image_id}", response_model=PropertyImageResponse)
def get_property_image(image_id: int, db: Session = Depends(get_db)):
    """Get a specific property image"""
    image = db.query(PropertyImage).filter(PropertyImage.id == image_id).first()
    if not image:
        raise HTTPException(status_code=404, detail="Property image not found")
    return image


@router.post("/images/", response_model=PropertyImageResponse, status_code=status.HTTP_201_CREATED)
def create_property_image(
    image: PropertyImageCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Add a new property image"""
    db_image = PropertyImage(
        property_id=image.property_id,
        image_url=image.image_url,
        is_primary=image.is_primary
    )
    db.add(db_image)
    db.commit()
    db.refresh(db_image)
    return db_image


@router.delete("/images/{image_id}", status_code=status.HTTP_200_OK)
def delete_property_image(
    image_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Delete a property image"""
    image = db.query(PropertyImage).filter(PropertyImage.id == image_id).first()
    if not image:
        raise HTTPException(status_code=404, detail="Property image not found")
    
    db.delete(image)
    db.commit()
    return {"message": "Property image deleted successfully"}


# ========== LISTING ENDPOINTS ==========

@router.get("/listings/all", response_model=List[ListingResponse])
def get_listings(db: Session = Depends(get_db)):
    """Get all listings"""
    return db.query(Listing).all()


@router.get("/listings/{listing_id}", response_model=ListingResponse)
def get_listing(listing_id: int, db: Session = Depends(get_db)):
    """Get a specific listing"""
    listing = db.query(Listing).filter(Listing.id == listing_id).first()
    if not listing:
        raise HTTPException(status_code=404, detail="Listing not found")
    return listing


@router.post("/listings/", response_model=ListingResponse, status_code=status.HTTP_201_CREATED)
def create_listing(
    listing: ListingCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Create a new listing"""
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

@router.get("/inquiries/all", response_model=List[InquiryResponse])
def get_inquiries(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get all inquiries"""
    return db.query(Inquiry).all()


@router.get("/inquiries/{inquiry_id}", response_model=InquiryResponse)
def get_inquiry(
    inquiry_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get a specific inquiry"""
    inquiry = db.query(Inquiry).filter(Inquiry.id == inquiry_id).first()
    if not inquiry:
        raise HTTPException(status_code=404, detail="Inquiry not found")
    return inquiry


@router.post("/inquiries/", response_model=InquiryResponse, status_code=status.HTTP_201_CREATED)
def create_inquiry(inquiry: InquiryCreate, db: Session = Depends(get_db)):
    """Create a new inquiry (public endpoint for potential clients)"""
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

@router.get("/appointments/all", response_model=List[AppointmentResponse])
def get_appointments(
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get all appointments"""
    return db.query(Appointment).all()


@router.get("/appointments/{appointment_id}", response_model=AppointmentResponse)
def get_appointment(
    appointment_id: int,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Get a specific appointment"""
    appointment = db.query(Appointment).filter(Appointment.id == appointment_id).first()
    if not appointment:
        raise HTTPException(status_code=404, detail="Appointment not found")
    return appointment


@router.post("/appointments/", response_model=AppointmentResponse, status_code=status.HTTP_201_CREATED)
def create_appointment(
    appointment: AppointmentCreate,
    current_user: User = Depends(get_current_user),
    db: Session = Depends(get_db)
):
    """Create a new appointment"""
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
