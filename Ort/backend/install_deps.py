import subprocess
import sys

subprocess.check_call([sys.executable, "-m", "pip", "install", "--upgrade", "pip"])
subprocess.check_call([sys.executable, "-m", "pip", "install", "setuptools", "wheel"])
subprocess.check_call([sys.executable, "-m", "pip", "install", "pydantic-settings"])

def install_packages():
    packages = [
        "fastapi==0.104.1",
        "uvicorn[standard]==0.24.0",
        "sqlalchemy==2.0.23",
        "alembic==1.12.1",
        "psycopg2-binary==2.9.9",
        "asyncpg==0.29.0",
        "pydantic==2.5.0",
        "pydantic-settings==2.1.0",
        "python-jose[cryptography]==3.3.0",
        "passlib[bcrypt]==1.7.4",
        "redis==5.0.1",
        "celery==5.3.4",
        "python-multipart==0.0.6",
        "httpx==0.25.1",
        "openai==0.28.0",
        "python-dotenv==1.0.0",
    ]
    
    print("Installing required packages...")
    for package in packages:
        print(f"Installing {package}...")
        subprocess.check_call([sys.executable, "-m", "pip", "install", package])
    
    print("\nAll packages installed successfully!")

if __name__ == "__main__":
    install_packages()