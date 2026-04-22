from fastapi import FastAPI
from routers import fasilitas

app = FastAPI()

app.include_router(fasilitas.router)