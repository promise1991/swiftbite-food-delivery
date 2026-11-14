import os
from datetime import datetime, timezone
import httpx
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from events import publish
app = FastAPI(title="order-service")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])
DELIVERY_URL = os.getenv("DELIVERY_URL", "http://delivery-service:8012")
ORDERS: dict = {}
NEXT = {"id": 1000}
STATUSES = ["PLACED", "ACCEPTED", "PICKED_UP", "DELIVERED", "CANCELLED"]
EVENT = {"PLACED": "order.placed", "ACCEPTED": "order.accepted", "PICKED_UP": "delivery.picked_up", "DELIVERED": "order.delivered"}
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
@app.get("/health")
def health(): return {"service": "order-service", "status": "running"}
@app.get("/ready")
def ready(): return {"ready": True}
@app.post("/order")
def create(o: NewOrder):
    NEXT["id"] += 1; oid = NEXT["id"]
    items = [i.model_dump() for i in o.items]
    row = {"id": oid, "order_id": oid, "user_id": o.user_id, "restaurant_id": o.restaurant_id, "items": items,
           "items_summary": ", ".join(f"{i['qty']} × {i['name']}" for i in items),
           "total": o.total or sum(i["price"] * i["qty"] for i in items), "status": "PLACED",
           "created_at": datetime.now(timezone.utc).isoformat()}
    ORDERS[oid] = row
    publish("order.placed", {"order_id": oid, "email": "customer@example.com"})
    return row
@app.get("/order")
def list_orders(user_id: int | None = None, status: str | None = None):
    rows = [o for o in ORDERS.values() if (user_id is None or o["user_id"] == user_id) and (status is None or o["status"] == status)]
    return sorted(rows, key=lambda o: o["id"], reverse=True)
@app.get("/order/{oid}")
def get_order(oid: int):
    if oid not in ORDERS: raise HTTPException(404, "order not found")
    return ORDERS[oid]
@app.put("/order/{oid}/status")
def set_status(oid: int, s: Status):
    if oid not in ORDERS: raise HTTPException(404, "order not found")
    if s.status not in STATUSES: raise HTTPException(400, f"status must be one of {STATUSES}")
    o = ORDERS[oid]; o["status"] = s.status
    if s.status == "ACCEPTED":   # hand over to delivery so a rider gets assigned
        try: httpx.post(f"{DELIVERY_URL}/delivery", json={"order_id": oid, "restaurant_id": o["restaurant_id"], "items_summary": o["items_summary"]}, timeout=3)
        except Exception as e: print("delivery-service unreachable:", e, flush=True)
    if s.status in EVENT: publish(EVENT[s.status], {"order_id": oid, "email": "customer@example.com"})
    return o
