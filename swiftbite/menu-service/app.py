from contextlib import asynccontextmanager
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import db

@asynccontextmanager
async def lifespan(app):
    db.start(); yield; db.stop()

app = FastAPI(title="menu-service", lifespan=lifespan)
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])
COLS = "id, restaurant_id, name, price::float AS price"

class Item(BaseModel):
    name: str
    price: float

@app.get("/health")
def health(): return {"service": "menu-service", "status": "running"}
@app.get("/ready")
def ready(): return db.check_ready()

@app.get("/menu/{rid}")
def get_menu(rid: int):
    with db.pool.connection() as c:
        return c.execute(f"SELECT {COLS} FROM menu_items WHERE restaurant_id = %s ORDER BY id", (rid,)).fetchall()

@app.post("/menu/{rid}")
def add(rid: int, i: Item):
    with db.pool.connection() as c:
        return c.execute(f"INSERT INTO menu_items (restaurant_id, name, price) VALUES (%s, %s, %s) RETURNING {COLS}",
                         (rid, i.name, i.price)).fetchone()

@app.put("/menu/{rid}/{item_id}")
def update(rid: int, item_id: int, i: Item):
    with db.pool.connection() as c:
        r = c.execute(f"UPDATE menu_items SET name = %s, price = %s WHERE id = %s AND restaurant_id = %s RETURNING {COLS}",
                      (i.name, i.price, item_id, rid)).fetchone()
    if not r: raise HTTPException(404, "item not found")
    return r

@app.delete("/menu/{rid}/{item_id}")
def delete(rid: int, item_id: int):
    with db.pool.connection() as c:
        c.execute("DELETE FROM menu_items WHERE id = %s AND restaurant_id = %s", (item_id, rid))
    return {"deleted": item_id}
