from fastapi import APIRouter
from .endpoints import properties, auth

api_router = APIRouter()

# Include routers with appropriate prefixes
api_router.include_router(auth.router, prefix="/auth", tags=["authentication"])
api_router.include_router(properties.router, prefix="/properties", tags=["properties"])