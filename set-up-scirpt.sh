#!/bin/bash

# Exit immediately if a command fails
set -e

echo "============================================"
echo " ort - Setup Started"
echo "============================================"

# -----------------------------
# Day 1: Project Initialization
# -----------------------------
echo "[Day 1] Initializing project..."

PROJECT_NAME="Ort"

mkdir -p $PROJECT_NAME
cd $PROJECT_NAME

python3 -m venv venv
source venv/bin/activate   # For Windows use: venv\Scripts\activate

echo "Virtual environment activated."

# --------------------------------
# Day 2–3: Project Structure Setup
# --------------------------------
echo "[Day 2–3] Creating project structure..."

mkdir -p backend/app/api/v1/{endpoints,dependencies,routers}
mkdir -p backend/app/core
mkdir -p backend/app/{models,schemas,services,ai,tasks,utils}
mkdir -p backend/{tests,alembic}
mkdir -p backend/requirements

# Create core files
touch backend/app/core/{config.py,security.py,database.py}

# Create requirement files
touch backend/requirements/{dev.txt,prod.txt}

# Create Dockerfile
touch backend/Dockerfile

echo "Project structure created."

# --------------------------------
# Day 4–5: Dependency Management
# --------------------------------
echo "[Day 4–5] Adding dependencies..."

cat <<EOF > backend/requirements/base.txt
fastapi==0.104.1
uvicorn[standard]==0.24.0
sqlalchemy==2.0.23
alembic==1.12.1
psycopg2-binary==2.9.9
asyncpg==0.29.0
pydantic==2.5.0
pydantic-settings==2.1.0
python-jose[cryptography]==3.3.0
passlib[bcrypt]==1.7.4
redis==5.0.1
celery==5.3.4
geoalchemy2==0.14.1
shapely==2.0.2
openai==0.28.0
python-multipart==0.0.6
httpx==0.25.1
EOF

echo "Base dependencies written."

# Optional: Install dependencies immediately
pip install --upgrade pip
pip install -r backend/requirements/base.txt

echo "Dependencies installed."

# -----------------------------
# Completion Message
# -----------------------------
echo "============================================"
echo " Setup Completed Successfully 🎉"
echo " Project Location: $(pwd)"
echo " Virtual Env: Activated"
echo "============================================"
