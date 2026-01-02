from fastapi import FastAPI
from app.database.database import engine, Base
from app.api.v1.api import router

app = FastAPI(title="Real Estate Management API", version="1.0.0")

# Create tables
Base.metadata.create_all(bind=engine)

# Include all routes
app.include_router(router, prefix="/api/v1")

@app.get("/")
def home():
    return {"message": "Welcome to Real Estate Management API", "docs": "/docs"}