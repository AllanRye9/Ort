from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select, func, and_
from ....core.database import get_db
from ....core.security import get_current_user, get_current_active_user
from ....models.user import User
from ....models.property import Property, PropertyType, PropertyStatus
from ....schemas.property import (
    PropertyCreate, 
    PropertyUpdate, 
    PropertyInDB, 
    PropertySearch
)
from ....ai.valuation import valuator

router = APIRouter()


@router.get("/", response_model=List[PropertyInDB])
async def list_properties(
    skip: int = Query(0, ge=0),
    limit: int = Query(20, le=100),
    property_type: Optional[PropertyType] = None,
    min_price: Optional[float] = Query(None, ge=0),
    max_price: Optional[float] = Query(None, ge=0),
    city: Optional[str] = None,
    db: AsyncSession = Depends(get_db)
):
    query = select(Property).where(Property.is_active == True)
    
    if property_type:
        query = query.where(Property.property_type == property_type)
    if min_price:
        query = query.where(Property.price >= min_price)
    if max_price:
        query = query.where(Property.price <= max_price)
    if city:
        query = query.where(func.lower(Property.city) == func.lower(city))
    
    query = query.offset(skip).limit(limit).order_by(Property.created_at.desc())
    
    result = await db.execute(query)
    properties = result.scalars().all()
    return properties


@router.post("/search", response_model=List[PropertyInDB])
async def search_properties(
    filters: PropertySearch,
    db: AsyncSession = Depends(get_db)
):
    query = select(Property).where(Property.is_active == True)
    
    # Apply filters
    if filters.min_price:
        query = query.where(Property.price >= filters.min_price)
    if filters.max_price:
        query = query.where(Property.price <= filters.max_price)
    if filters.property_type:
        query = query.where(Property.property_type == filters.property_type)
    if filters.bedrooms_min:
        query = query.where(Property.bedrooms >= filters.bedrooms_min)
    if filters.bedrooms_max:
        query = query.where(Property.bedrooms <= filters.bedrooms_max)
    if filters.city:
        query = query.where(func.lower(Property.city) == func.lower(filters.city))
    if filters.state:
        query = query.where(func.lower(Property.state) == func.lower(filters.state))
    
    # Sort
    sort_column = getattr(Property, filters.sort_by, Property.created_at)
    if filters.sort_order == "desc":
        query = query.order_by(sort_column.desc())
    else:
        query = query.order_by(sort_column.asc())
    
    # Pagination
    query = query.offset((filters.page - 1) * filters.limit).limit(filters.limit)
    
    result = await db.execute(query)
    properties = result.scalars().all()
    return properties


@router.post("/", response_model=PropertyInDB, status_code=status.HTTP_201_CREATED)
async def create_property(
    property_data: PropertyCreate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    db_property = Property(**property_data.dict(), owner_id=current_user.id)
    
    db.add(db_property)
    await db.commit()
    await db.refresh(db_property)
    
    return db_property


@router.get("/{property_id}", response_model=PropertyInDB)
async def get_property(
    property_id: int,
    db: AsyncSession = Depends(get_db)
):
    query = select(Property).where(Property.id == property_id, Property.is_active == True)
    result = await db.execute(query)
    property = result.scalar_one_or_none()
    
    if not property:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Property not found"
        )
    
    # Increment view count
    property.views_count += 1
    await db.commit()
    await db.refresh(property)
    
    return property


@router.get("/{property_id}/valuation")
async def get_property_valuation(
    property_id: int,
    db: AsyncSession = Depends(get_db)
):
    query = select(Property).where(Property.id == property_id, Property.is_active == True)
    result = await db.execute(query)
    property = result.scalar_one_or_none()
    
    if not property:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Property not found"
        )
    
    # Convert property to dict for AI valuation
    property_dict = {
        "property_type": property.property_type.value,
        "address": property.address,
        "city": property.city,
        "state": property.state,
        "square_feet": property.square_feet,
        "bedrooms": property.bedrooms,
        "bathrooms": property.bathrooms,
        "year_built": property.year_built,
        "price": property.price,
        "lot_size": property.lot_size,
        "amenities": property.amenities or []
    }
    
    # Get AI valuation
    valuation = await valuator.estimate_value(property_dict)
    
    return {
        "property_id": property_id,
        "current_price": property.price,
        "valuation": valuation
    }


@router.put("/{property_id}", response_model=PropertyInDB)
async def update_property(
    property_id: int,
    property_data: PropertyUpdate,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    query = select(Property).where(Property.id == property_id)
    result = await db.execute(query)
    property = result.scalar_one_or_none()
    
    if not property:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Property not found"
        )
    
    # Check ownership or admin rights
    if property.owner_id != current_user.id and current_user.role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized to update this property"
        )
    
    # Update fields
    update_data = property_data.dict(exclude_unset=True)
    for field, value in update_data.items():
        setattr(property, field, value)
    
    await db.commit()
    await db.refresh(property)
    
    return property


@router.delete("/{property_id}")
async def delete_property(
    property_id: int,
    db: AsyncSession = Depends(get_db),
    current_user: User = Depends(get_current_user)
):
    query = select(Property).where(Property.id == property_id)
    result = await db.execute(query)
    property = result.scalar_one_or_none()
    
    if not property:
        raise HTTPException(
            status_code=status.HTTP_404_NOT_FOUND,
            detail="Property not found"
        )
    
    # Check ownership or admin rights
    if property.owner_id != current_user.id and current_user.role != "admin":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Not authorized to delete this property"
        )
    
    # Soft delete
    property.is_active = False
    await db.commit()
    
    return {"message": "Property deleted successfully"}