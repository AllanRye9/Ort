import os
import sys

print("Setting up Real Estate AI Platform...")
print("=" * 50)

# Create .env file if it doesn't exist
env_file = ".env"
if not os.path.exists(env_file):
    with open(env_file, "w") as f:
        f.write("""# Project Settings
PROJECT_NAME=Real Estate AI Platform
API_V1_STR=/api/v1

# Database
POSTGRES_SERVER=localhost
POSTGRES_USER=postgres
POSTGRES_PASSWORD=password
POSTGRES_DB=real_estate_db

# Security
SECRET_KEY=your-super-secret-key-change-this-in-production
ACCESS_TOKEN_EXPIRE_MINUTES=30
ALGORITHM=HS256

# Redis
REDIS_URL=redis://localhost:6379

# OpenAI
OPENAI_API_KEY=your-openai-api-key-here

# CORS
BACKEND_CORS_ORIGINS=["http://localhost:3000","http://127.0.0.1:3000"]
""")
    print(f"✓ Created {env_file} file")

# Install basic dependencies
print("\nInstalling basic dependencies...")
os.system("pip install fastapi uvicorn sqlalchemy pydantic python-jose[cryptography] passlib[bcrypt] python-multipart python-dotenv")

# Create a minimal database setup
print("\nSetting up database...")
try:
    # Create a simple SQLite database for testing
    from sqlalchemy import create_engine, Column, Integer, String, Float, DateTime, Text, Boolean, Enum, JSON
    from sqlalchemy.ext.declarative import declarative_base
    from sqlalchemy.sql import func
    import enum
    
    Base = declarative_base()
    
    class UserRole(str, enum.Enum):
        ADMIN = "admin"
        AGENT = "agent"
        BUYER = "buyer"
        SELLER = "seller"
        INVESTOR = "investor"
    
    class User(Base):
        __tablename__ = "users"
        
        id = Column(Integer, primary_key=True, index=True)
        email = Column(String(255), unique=True, index=True, nullable=False)
        username = Column(String(100), unique=True, index=True)
        hashed_password = Column(String(255), nullable=False)
        full_name = Column(String(255))
        role = Column(Enum(UserRole), default=UserRole.BUYER)
        is_active = Column(Boolean, default=True)
        created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    class PropertyType(str, enum.Enum):
        RESIDENTIAL = "residential"
        COMMERCIAL = "commercial"
        INDUSTRIAL = "industrial"
        LAND = "land"
    
    class PropertyStatus(str, enum.Enum):
        FOR_SALE = "for_sale"
        FOR_RENT = "for_rent"
        SOLD = "sold"
        RENTED = "rented"
    
    class Property(Base):
        __tablename__ = "properties"
        
        id = Column(Integer, primary_key=True, index=True)
        title = Column(String(255), nullable=False)
        description = Column(Text)
        property_type = Column(Enum(PropertyType), nullable=False)
        status = Column(Enum(PropertyStatus), default=PropertyStatus.FOR_SALE)
        price = Column(Float, nullable=False)
        address = Column(String(500), nullable=False)
        city = Column(String(100), nullable=False)
        state = Column(String(100))
        bedrooms = Column(Integer)
        bathrooms = Column(Float)
        square_feet = Column(Integer)
        owner_id = Column(Integer, index=True)
        is_active = Column(Boolean, default=True)
        created_at = Column(DateTime(timezone=True), server_default=func.now())
    
    engine = create_engine('sqlite:///test.db')
    Base.metadata.create_all(bind=engine)
    print("✓ Database setup complete")
    
except Exception as e:
    print(f"✗ Database setup error: {e}")

print("\n" + "=" * 50)
print("Setup complete!")
print("\nTo run the application:")
print("1. cd backend")
print("2. uvicorn app.main:app --reload")
print("\nAccess the API at: http://localhost:8000")
print("API documentation at: http://localhost:8000/docs")