#!/usr/bin/env python3
"""
Simple initialization script for Real Estate AI Platform
Uses SQLite for easy setup
"""
import os
import sys
from pathlib import Path

print("=" * 60)
print("Real Estate AI Platform - Setup")
print("=" * 60)

# Add current directory to Python path
sys.path.insert(0, str(Path(__file__).parent))

# Create .env file if it doesn't exist
env_file = Path(".env")
if not env_file.exists():
    print("\nCreating .env file...")
    env_file.write_text("""# Project Settings
PROJECT_NAME=Real Estate AI Platform
API_V1_STR=/api/v1

# Database (SQLite for development)
DATABASE_URL=sqlite+aiosqlite:///./real_estate.db

# Security
SECRET_KEY=development-secret-key-change-in-production
ACCESS_TOKEN_EXPIRE_MINUTES=30
ALGORITHM=HS256

# CORS
BACKEND_CORS_ORIGINS=["http://localhost:3000","http://127.0.0.1:3000"]
""")
    print("✓ Created .env file")

# Install basic dependencies
print("\nChecking dependencies...")
required_packages = [
    "fastapi",
    "uvicorn[standard]",
    "sqlalchemy",
    "pydantic",
    "python-jose[cryptography]",
    "passlib[bcrypt]",
    "python-multipart",
    "python-dotenv",
]

for package in required_packages:
    try:
        __import__(package.replace("[", ".").replace("]", "").split(".")[0])
        print(f"✓ {package}")
    except ImportError:
        print(f"✗ {package} - installing...")
        os.system(f"pip install {package}")

# Initialize database
print("\nInitializing database...")
try:
    from app.core.database import engine, Base
    from app.models.user import User
    from app.models.property import Property
    
    # Create tables
    Base.metadata.create_all(bind=engine)
    print("✓ Database tables created successfully!")
    
    # Create a test user
    from sqlalchemy.orm import Session
    from app.core.security import get_password_hash
    
    with Session(engine) as session:
        # Check if admin user exists
        from sqlalchemy import select
        result = session.execute(select(User).where(User.email == "admin@example.com"))
        if not result.scalar_one_or_none():
            admin_user = User(
                email="admin@example.com",
                username="admin",
                hashed_password=get_password_hash("admin123"),
                full_name="Administrator",
                role="admin",
                is_active=True,
                is_verified=True
            )
            session.add(admin_user)
            
            # Create a test property
            test_property = Property(
                title="Beautiful Family Home",
                description="A lovely 3-bedroom family home in a quiet neighborhood.",
                property_type="residential",
                status="for_sale",
                price=350000,
                address="123 Main Street",
                city="Springfield",
                state="IL",
                zip_code="62701",
                country="USA",
                bedrooms=3,
                bathrooms=2,
                square_feet=1800,
                lot_size=0.25,
                year_built=2005,
                owner_id=1  # References the admin user
            )
            session.add(test_property)
            
            session.commit()
            print("✓ Created test data:")
            print("  - Admin user: admin@example.com / admin123")
            print("  - Test property: Beautiful Family Home")
    
except Exception as e:
    print(f"✗ Error during setup: {e}")
    import traceback
    traceback.print_exc()

print("\n" + "=" * 60)
print("Setup complete!")
print("\nTo run the application:")
print("  cd backend")
print("  uvicorn app.main:app --reload")
print("\nAccess the API:")
print("  - Main URL: http://localhost:8000")
print("  - API Docs: http://localhost:8000/docs")
print("  - Health check: http://localhost:8000/health")
print("\nTest credentials:")
print("  - Email: admin@example.com")
print("  - Password: admin123")
print("=" * 60)