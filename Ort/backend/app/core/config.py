# core/config.py
from typing import List
from pydantic import AnyHttpUrl
from pydantic_settings import BaseSettings
from pydantic.functional_validators import validator 
from dotenv import load_dotenv

# Load environment variables
load_dotenv()


class Settings(BaseSettings):
    # API Settings
    API_V1_STR: str = "/api/v1"
    PROJECT_NAME: str = "Real Estate AI Platform"
    
    # Backend CORS Origins
    BACKEND_CORS_ORIGINS: List[AnyHttpUrl] = []
    
    @validator("BACKEND_CORS_ORIGINS", pre=True)
    def assemble_cors_origins(cls, v: str | List[str]) -> List[str] | str:
        if isinstance(v, str) and not v.startswith("["):
            return [i.strip() for i in v.split(",")]
        elif isinstance(v, (list, str)):
            return v
        raise ValueError(v)
    
    # Use SQLite for development (no database server needed)
    DATABASE_URL: str = "sqlite+aiosqlite:///./real_estate.db"
    
    # Security
    SECRET_KEY: str = "your-secret-key-change-this-in-production"
    ACCESS_TOKEN_EXPIRE_MINUTES: int = 30
    ALGORITHM: str = "HS256"
    
    # Redis (optional for now)
    REDIS_URL: str = "redis://localhost:6379"
    
    # OpenAI (optional for now)
    OPENAI_API_KEY: str = ""
    
    class Config:
        case_sensitive = True
        env_file = ".env"


settings = Settings()