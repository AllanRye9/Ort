from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from .database.database import engine, Base
from .api import router

app = FastAPI(title="Real Estate Management API", version="1.0.0")

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["http://localhost:3000"],  # React dev server
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Create tables
Base.metadata.create_all(bind=engine)

# Include all routes
app.include_router(router, prefix="/api/v1")

@app.get("/")
def home():
    return {"message": "Welcome to Real Estate Management API", "docs": "/docs"}