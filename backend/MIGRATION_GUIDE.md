# Backend Restructuring - Migration Guide

## Overview
This document describes the restructuring of the real estate application backend from `src/` to a new, organized `backend/` directory structure with improved architecture.

## What Changed

### Directory Structure
**Before** (src/):
```
src/
├── app/
│   ├── api/v1/api.py (monolithic)
│   ├── models/models.py (monolithic)
│   ├── schemas/schemas.py (monolithic)
│   ├── database/database.py
│   └── main.py
└── requirements.txt
```

**After** (backend/):
```
backend/
├── app/
│   ├── main.py (restructured)
│   ├── config.py (NEW - environment config)
│   ├── auth.py (NEW - JWT authentication)
│   ├── database.py (updated)
│   ├── models/ (split into modules)
│   │   ├── user.py
│   │   ├── property.py
│   │   └── transaction.py
│   ├── schemas/ (split into modules)
│   │   ├── user.py
│   │   ├── property.py
│   │   └── transaction.py
│   └── routers/ (split into modules)
│       ├── auth.py (NEW)
│       ├── users.py
│       ├── properties.py
│       └── transactions.py
├── requirements.txt (updated)
├── Dockerfile
├── .env.example (NEW)
└── README.md (NEW)
```

## New Features

### 1. Configuration Management (config.py)
- Centralized environment variable management
- Uses `pydantic-settings` for type-safe configuration
- Supports `.env` files
- Easy to override settings for different environments

### 2. JWT Authentication (auth.py)
- Secure JWT token generation and verification
- Bcrypt password hashing
- Role-based access control (agent/admin)
- OAuth2 password flow
- Token expiration management

### 3. Split Models
**user.py**:
- User model (agents and admins)
- Client model (buyers, sellers, renters)

**property.py**:
- Property model
- PropertyImage model
- Listing model
- Inquiry model
- Appointment model

**transaction.py**:
- Transaction model
- Payment model

### 4. Split Schemas
Organized Pydantic schemas matching the model structure:
- user.py: User and Client schemas
- property.py: Property-related schemas
- transaction.py: Transaction and Payment schemas

### 5. Split Routers
**auth.py** (NEW):
- POST /api/v1/auth/register - User registration
- POST /api/v1/auth/login - User login (returns JWT)
- GET /api/v1/auth/me - Get current user
- POST /api/v1/auth/change-password - Change password

**users.py**:
- User management endpoints (with authentication)
- Client management endpoints

**properties.py**:
- Property CRUD operations
- Property image management
- Listings, inquiries, and appointments

**transactions.py**:
- Transaction management
- Payment tracking

## Key Improvements

### Security
- ✅ JWT token-based authentication
- ✅ Bcrypt password hashing (configurable rounds)
- ✅ Role-based access control
- ✅ Protected endpoints require authentication
- ✅ Admin-only operations enforced

### Code Organization
- ✅ Separated concerns (models, schemas, routers)
- ✅ Single responsibility principle
- ✅ Easier to test and maintain
- ✅ Better code reusability

### Configuration
- ✅ Environment-based configuration
- ✅ Easy to switch between dev/prod
- ✅ Sensitive data in environment variables
- ✅ Type-safe settings with Pydantic

### Documentation
- ✅ Comprehensive README
- ✅ Environment variable examples
- ✅ API endpoint documentation
- ✅ Setup and deployment guides

## Migration Steps

If migrating from old structure to new:

1. **Install new dependencies**:
   ```bash
   cd backend
   pip install -r requirements.txt
   ```

2. **Set up environment**:
   ```bash
   cp .env.example .env
   # Edit .env with your settings
   ```

3. **Generate secret key**:
   ```bash
   openssl rand -hex 32
   # Add to .env as SECRET_KEY
   ```

4. **Run the application**:
   ```bash
   uvicorn app.main:app --reload
   ```

5. **Test authentication**:
   ```bash
   # Register a user
   curl -X POST http://localhost:8000/api/v1/auth/register \
     -H "Content-Type: application/json" \
     -d '{"email":"admin@example.com","password":"password123","role":"admin","first_name":"Admin","last_name":"User"}'
   
   # Login
   curl -X POST http://localhost:8000/api/v1/auth/login \
     -H "Content-Type: application/x-www-form-urlencoded" \
     -d "username=admin@example.com&password=password123"
   ```

## Breaking Changes

### Authentication Required
Most endpoints now require authentication. You must:
1. Register or login to get a JWT token
2. Include token in Authorization header: `Bearer <token>`

### Password Handling
- Passwords are now properly hashed with bcrypt
- Old plain-text passwords won't work
- Users must register through `/api/v1/auth/register`

### Endpoint Changes
- Authentication endpoints moved to `/api/v1/auth/*`
- Some routes reorganized for better REST structure
- Client endpoints now under `/api/v1/users/clients/*`

## Dependencies Added

New dependencies in requirements.txt:
- `pydantic-settings==2.1.0` - Configuration management
- `python-jose[cryptography]==3.3.0` - JWT tokens
- `passlib[bcrypt]==1.7.4` - Password hashing
- `python-multipart==0.0.6` - Form data support

Removed (not needed for core backend):
- redis, celery (can be added back if needed)
- openai (AI features should be separate service)
- geoalchemy2, shapely (can be added back if needed)
- Testing dependencies (should be in separate dev-requirements.txt)
- Code quality tools (should be in separate dev-requirements.txt)

## Testing the New Structure

1. **Start the server**:
   ```bash
   cd backend
   uvicorn app.main:app --reload
   ```

2. **Access documentation**:
   - Swagger UI: http://localhost:8000/docs
   - ReDoc: http://localhost:8000/redoc

3. **Test authentication flow**:
   - Register a new user via POST /api/v1/auth/register
   - Login via POST /api/v1/auth/login
   - Use the returned token for authenticated requests

4. **Test CRUD operations**:
   - Create, read, update, delete properties
   - Manage clients and users
   - Create transactions

## Rollback Plan

If you need to rollback to the old structure:
1. The original `src/` directory is unchanged
2. Simply use the old startup command
3. Point your API clients back to the old endpoints

## Future Enhancements

Potential improvements for the future:
- Database migrations with Alembic
- Comprehensive test suite
- API rate limiting
- Caching with Redis
- Background tasks with Celery
- File upload for property images
- Email notifications
- Search and filtering
- Pagination for large datasets
- API versioning strategy

## Support

For questions or issues with the new structure:
1. Check the README.md for detailed documentation
2. Review the .env.example for configuration options
3. Check API docs at /docs endpoint
4. Review the code comments in each module
