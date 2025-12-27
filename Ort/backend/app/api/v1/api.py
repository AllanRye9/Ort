from fastapi import FastAPI
from ...models.models import create_tables

app = FastAPI()

@app.get('/')

async def home():
    x = create_tables()
    return {"result":   x}