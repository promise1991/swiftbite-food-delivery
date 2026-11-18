import os
import httpx
from contextlib import asynccontextmanager
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import db

@asynccontextmanager
async def lifespan(app):
    db.start(); yield; db.stop()

from events import publish
app = FastAPI(title="order-service", lifespan=lifespan)
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])
DELIVERY_URL = os.getenv("DELIVERY_URL", "http://delivery-service:8012")
STATUSES = ["PLACED", "ACCEPTED", "PICKED_UP", "DELIVERED", "CANCELLED"]
EVENT = {"PLACED": "order.placed", "ACCEPTED": "order.accepted", "PICKED_UP": "delivery.picked_up", "DELIVERED": "order.delivered"}
COLS = "id, user_id, restaurant_id, total::float AS total, status, created_at"

class Line(BaseModel):
    id: int | None = None
    item_id: int | None = None
    name: str = ""
    price: float = 0
    qty: int = 1
class NewOrder(BaseModel):
    user_id: int = 1
    restaurant_id: int | None = None
    items: list[Line] = []
    total: float = 0
class Status(BaseModel):
    status: str

def with_items(c, orders):
    ids = [o["id"] for o in orders]
    rows = c.execute("SELECT order_id, item_id, item_id AS id, name, price::float AS price, qty FROM order_items "
                     "WHERE order_id = ANY(%s) ORDER BY id", (ids,)).fetchall() if ids else []
    by = {}
    for r in rows: by.setdefault(r.pop("order_id"), []).append(r)
    return [{**o, "order_id": o["id"], "items": by.get(o["id"], []),
             "items_summary": ", ".join(f"{i['qty']} × {i['name']}" for i in by.get(o["id"], []))} for o in orders]

@app.get("/health")
def health(): return {"service": "order-service", "status": "running"}
@app.get("/ready")
def ready(): return db.check_ready()

@app.post("/order")
def create(o: NewOrder):
    total = o.total or sum(i.price * i.qty for i in o.items)
    with db.pool.connection() as c:      # one transaction: the order and its items are saved together or not at all
        row = c.execute(f"INSERT INTO orders (user_id, restaurant_id, total) VALUES (%s, %s, %s) RETURNING {COLS}",
                        (o.user_id, o.restaurant_id, total)).fetchone()
        for i in o.items:
            c.execute("INSERT INTO order_items (order_id, item_id, name, price, qty) VALUES (%s, %s, %s, %s, %s)",
                      (row["id"], i.item_id or i.id or 0, i.name, i.price, i.qty))
        order = with_items(c, [row])[0]
    publish("order.placed", {"order_id": order["id"], "email": "customer@example.com"})
    return order

@app.get("/order")
def list_orders(user_id: int | None = None, status: str | None = None):
    with db.pool.connection() as c:
        rows = c.execute(f"SELECT {COLS} FROM orders WHERE (%s::int IS NULL OR user_id = %s) AND (%s::text IS NULL OR status = %s) "
                         "ORDER BY id DESC LIMIT 200", (user_id, user_id, status, status)).fetchall()
        return with_items(c, rows)

@app.get("/order/{oid}")
def get_order(oid: int):
    with db.pool.connection() as c:
        row = c.execute(f"SELECT {COLS} FROM orders WHERE id = %s", (oid,)).fetchone()
        if not row: raise HTTPException(404, "order not found")
        return with_items(c, [row])[0]

@app.put("/order/{oid}/status")
def set_status(oid: int, s: Status):
    if s.status not in STATUSES: raise HTTPException(400, f"status must be one of {STATUSES}")
    with db.pool.connection() as c:
        row = c.execute(f"UPDATE orders SET status = %s WHERE id = %s RETURNING {COLS}", (s.status, oid)).fetchone()
        if not row: raise HTTPException(404, "order not found")
        order = with_items(c, [row])[0]
    if s.status == "ACCEPTED":   # hand over to delivery so a rider gets assigned
        try: httpx.post(f"{DELIVERY_URL}/delivery", json={"order_id": oid, "restaurant_id": order["restaurant_id"], "items_summary": order["items_summary"]}, timeout=3)
        except Exception as e: print("delivery-service unreachable:", e, flush=True)
    if s.status in EVENT: publish(EVENT[s.status], {"order_id": oid, "email": "customer@example.com"})
    return order
