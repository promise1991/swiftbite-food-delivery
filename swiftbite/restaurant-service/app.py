from contextlib import asynccontextmanager
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import db

@asynccontextmanager
async def lifespan(app):
    db.start(); yield; db.stop()

app = FastAPI(title="restaurant-service", lifespan=lifespan)
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])
COLS = "id, name, cuisine, area, rating::float AS rating, eta"

class New(BaseModel):
    name: str
    cuisine: str = "African food"
    area: str = "Lagos"

@app.get("/health")
def health(): return {"service": "restaurant-service", "status": "running"}
@app.get("/ready")
def ready(): return db.check_ready()

@app.get("/restaurants")
def list_all(area: str = "", cuisine: str = ""):
    with db.pool.connection() as c:
        return c.execute(f"SELECT {COLS} FROM restaurants WHERE area ILIKE %s AND cuisine ILIKE %s ORDER BY id",
                         (f"%{area}%", f"%{cuisine}%")).fetchall()

@app.get("/restaurants/{rid}")
def one(rid: int):
    with db.pool.connection() as c:
        r = c.execute(f"SELECT {COLS} FROM restaurants WHERE id = %s", (rid,)).fetchone()
    if not r: raise HTTPException(404, "restaurant not found")
    return r

@app.post("/restaurants")
def create(n: New):
    with db.pool.connection() as c:
        return c.execute(f"INSERT INTO restaurants (name, cuisine, area) VALUES (%s, %s, %s) RETURNING {COLS}",
                         (n.name, n.cuisine, n.area)).fetchone()
