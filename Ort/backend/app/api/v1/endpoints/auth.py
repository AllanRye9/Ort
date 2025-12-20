from datetime import timedelta
from typing import Any
from fastapi import APIRouter, Depends, HTTPException, status
from fastapi.security import OAuth2PasswordRequestForm
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from ....core.database import get_db
from ....core.security import (
    verify_password, 
    create_access_token, 
    get_password_hash,
    get_current_user,
    get_current_active_user
)
from ....core.config import settings
from ....schemas.user import UserCreate, UserInDB, Token, UserRole
from ....models.user import User  # Import directly

router = APIRouter()


@router.post("/token", response_model=Token)
async def login(
    form_data: OAuth2PasswordRequestForm = Depends(),
    db: AsyncSession = Depends(get_db)
) -> Any:
    # Find user by email (username field in OAuth2PasswordRequestForm)
    result = await db.execute(select(User).where(User.email == form_data.username))
    user = result.scalar_one_or_none()
    
    if not user or not verify_password(form_data.password, user.hashed_password):
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Incorrect email or password",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    access_token_expires = timedelta(minutes=settings.ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        subject=user.email,
        expires_delta=access_token_expires
    )
    
    return {"access_token": access_token, "token_type": "bearer"}


@router.post("/register", response_model=UserInDB, status_code=status.HTTP_201_CREATED)
async def register(
    user_data: UserCreate,
    db: AsyncSession = Depends(get_db)
) -> Any:
    # Check if user already exists
    result = await db.execute(select(User).where(User.email == user_data.email))
    existing_user = result.scalar_one_or_none()
    
    if existing_user:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Email already registered"
        )
    
    # Check username if provided
    if user_data.username:
        result = await db.execute(select(User).where(User.username == user_data.username))
        existing_username = result.scalar_one_or_none()
        if existing_username:
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="Username already taken"
            )
    
    # Create new user
    hashed_password = get_password_hash(user_data.password)
    db_user = User(
        email=user_data.email,
        hashed_password=hashed_password,
        username=user_data.username,
        full_name=user_data.full_name,
        role=user_data.role
    )
    
    db.add(db_user)
    await db.commit()
    await db.refresh(db_user)
    
    return db_user


@router.get("/me", response_model=UserInDB)
async def read_users_me(
    current_user: User = Depends(get_current_user)
) -> Any:
    return current_user


@router.get("/me/active", response_model=UserInDB)
async def read_users_me_active(
    current_user: User = Depends(get_current_active_user)
) -> Any:
    return current_user