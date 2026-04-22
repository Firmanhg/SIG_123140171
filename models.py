from pydantic import BaseModel

class FasilitasCreate(BaseModel):
    nama: str
    jenis: str
    alamat: str | None = None
    longitude: float
    latitude: float