from fastapi import APIRouter
from database import get_pool
from models import FasilitasCreate
import json

router = APIRouter(prefix="/api/fasilitas", tags=["Fasilitas"])

# GET ALL
@router.get("/")
async def get_all():
    pool = await get_pool()
    async with pool.acquire() as conn:
        rows = await conn.fetch("""
            SELECT id, nama, jenis,
            ST_AsGeoJSON(geom) as geom
            FROM fasilitas
        """)
    return [dict(r) for r in rows]

# GET BY ID
@router.get("/{id}")
async def get_by_id(id: int):
    pool = await get_pool()
    async with pool.acquire() as conn:
        row = await conn.fetchrow("""
            SELECT id, nama, jenis,
            ST_X(geom) as longitude,
            ST_Y(geom) as latitude
            FROM fasilitas WHERE id=$1
        """, id)
    return dict(row)

# GEOJSON
@router.get("/geojson")
async def geojson():
    pool = await get_pool()
    async with pool.acquire() as conn:
        rows = await conn.fetch("""
            SELECT id, nama, jenis,
            ST_AsGeoJSON(geom) as geom
            FROM fasilitas
        """)
    
    features = []
    for r in rows:
        features.append({
            "type": "Feature",
            "geometry": json.loads(r["geom"]),
            "properties": {
                "id": r["id"],
                "nama": r["nama"],
                "jenis": r["jenis"]
            }
        })

    return {"type": "FeatureCollection", "features": features}

# POST
@router.post("/")
async def create(data: FasilitasCreate):
    pool = await get_pool()
    async with pool.acquire() as conn:
        row = await conn.fetchrow("""
            INSERT INTO fasilitas (nama, jenis, alamat, geom)
            VALUES ($1,$2,$3, ST_SetSRID(ST_Point($4,$5),4326))
            RETURNING id
        """, data.nama, data.jenis, data.alamat, data.longitude, data.latitude)
    return {"message": "berhasil", "id": row["id"]}

# NEARBY
@router.get("/nearby")
async def nearby(lat: float, lon: float, radius: int = 1000):
    pool = await get_pool()
    async with pool.acquire() as conn:
        rows = await conn.fetch("""
            SELECT id, nama,
            ST_Distance(
                geom::geography,
                ST_Point($1,$2)::geography
            ) as jarak
            FROM fasilitas
            WHERE ST_DWithin(
                geom::geography,
                ST_Point($1,$2)::geography,
                $3
            )
        """, lon, lat, radius)
    return [dict(r) for r in rows]