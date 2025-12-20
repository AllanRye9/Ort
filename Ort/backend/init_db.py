import sys
import os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

# Install missing dependencies first
print("Checking dependencies...")
try:
    import geoalchemy2
    print("✓ geoalchemy2 is installed")
except ImportError:
    print("✗ geoalchemy2 not found. Installing...")
    os.system("pip install geoalchemy2 shapely")

try:
    from app.core.database import engine, Base
    from app.models.user import User
    from app.models.property import Property
    
    print("Creating database tables...")
    Base.metadata.create_all(bind=engine)
    print("✓ Database tables created successfully!")
    
except Exception as e:
    print(f"✗ Error: {e}")
    print("\nTrying to create tables without geoalchemy2...")
    
    # Create a simplified version without geoalchemy2
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
        phone = Column(String(50))
        role = Column(Enum(UserRole), default=UserRole.BUYER)
        is_active = Column(Boolean, default=True)
        is_verified = Column(Boolean, default=False)
        is_premium = Column(Boolean, default=False)
        profile_picture = Column(String(500))
        bio = Column(Text)
        preferences = Column(JSON, default={})
        saved_properties = Column(JSON, default=[])
        search_history = Column(JSON, default=[])
        city = Column(String(100))
        state = Column(String(100))
        country = Column(String(100))
        license_number = Column(String(100))
        company = Column(String(255))
        years_experience = Column(Integer)
        specialties = Column(JSON, default=[])
        investment_budget_min = Column(Float)
        investment_budget_max = Column(Float)
        investment_preferences = Column(JSON, default={})
        created_at = Column(DateTime(timezone=True), server_default=func.now())
        updated_at = Column(DateTime(timezone=True), onupdate=func.now())
        last_login = Column(DateTime(timezone=True))
        subscription_tier = Column(String(50))
        subscription_expires = Column(DateTime(timezone=True))
    
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
        OFF_MARKET = "off_market"
    
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
        zip_code = Column(String(20))
        country = Column(String(100), default="USA")
        latitude = Column(Float)
        longitude = Column(Float)
        bedrooms = Column(Integer)
        bathrooms = Column(Float)
        square_feet = Column(Integer)
        lot_size = Column(Float)
        year_built = Column(Integer)
        amenities = Column(JSON, default=[])
        features = Column(JSON, default={})
        owner_id = Column(Integer, index=True)
        agent_id = Column(Integer, index=True)
        is_featured = Column(Boolean, default=False)
        is_active = Column(Boolean, default=True)
        views_count = Column(Integer, default=0)
        created_at = Column(DateTime(timezone=True), server_default=func.now())
        updated_at = Column(DateTime(timezone=True), onupdate=func.now())
    
    # Use SQLite for simplicity
    engine = create_engine('sqlite:///real_estate.db')
    Base.metadata.create_all(bind=engine)
    print("✓ Database tables created successfully with SQLite!")