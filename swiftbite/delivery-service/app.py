import asyncio, os
import httpx
from fastapi import WebSocket, WebSocketDisconnect
from contextlib import asynccontextmanager
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import db

@asynccontextmanager
async def lifespan(app):
    db.start(); yield; db.stop()

app = FastAPI(title="delivery-service", lifespan=lifespan)
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])
ORDER_URL = os.getenv("ORDER_URL", "http://order-service:8005")
FLOW = ["ACCEPTED", "PICKED_UP", "DELIVERED"]
SELECT = ("SELECT d.order_id, d.restaurant_id, d.items_summary, d.status, r.id AS rider_id, r.name AS rider_name "
          "FROM deliveries d JOIN riders r ON r.id = d.rider_id")

class New(BaseModel):
    order_id: int
    restaurant_id: int | None = None
    items_summary: str = ""
class Status(BaseModel):
    status: str

def out(r):
    return {"id": r["order_id"], "order_id": r["order_id"], "restaurant_id": r["restaurant_id"],
            "items_summary": r["items_summary"], "rider": {"id": r["rider_id"], "name": r["rider_name"]}, "status": r["status"]}

@app.get("/health")
def health(): return {"service": "delivery-service", "status": "running"}
@app.get("/ready")
def ready(): return db.check_ready()

@app.post("/delivery")
def create(n: New):
    with db.pool.connection() as c:
        row = c.execute(f"{SELECT} WHERE d.order_id = %s", (n.order_id,)).fetchone()
        if not row:      # idempotent; round-robin rider assignment
            riders = c.execute("SELECT id FROM riders ORDER BY id").fetchall()
            if not riders: raise HTTPException(503, "no riders available")
            count = c.execute("SELECT count(*) AS n FROM deliveries").fetchone()["n"]
            c.execute("INSERT INTO deliveries (order_id, restaurant_id, items_summary, rider_id) VALUES (%s, %s, %s, %s)",
                      (n.order_id, n.restaurant_id, n.items_summary, riders[count % len(riders)]["id"]))
            row = c.execute(f"{SELECT} WHERE d.order_id = %s", (n.order_id,)).fetchone()
    return out(row)

@app.get("/delivery")
def list_all(status: str | None = None, rider_id: int | None = None):
    with db.pool.connection() as c:
        rows = c.execute(f"{SELECT} WHERE (%s::text IS NULL OR d.status = %s) AND (%s::int IS NULL OR d.rider_id = %s) "
                         "ORDER BY d.order_id DESC LIMIT 200", (status, status, rider_id, rider_id)).fetchall()
    return [out(r) for r in rows]

@app.get("/delivery/{order_id}")
def one(order_id: int):
    with db.pool.connection() as c:
        row = c.execute(f"{SELECT} WHERE d.order_id = %s", (order_id,)).fetchone()
    if not row: raise HTTPException(404, "no delivery for this order yet")
    return out(row)

@app.put("/delivery/{order_id}/status")
def update(order_id: int, s: Status):
    if s.status not in FLOW: raise HTTPException(400, f"status must be one of {FLOW}")
    with db.pool.connection() as c:
        c.execute("UPDATE deliveries SET status = %s, updated_at = now() WHERE order_id = %s", (s.status, order_id))
        row = c.execute(f"{SELECT} WHERE d.order_id = %s", (order_id,)).fetchone()
    if not row: raise HTTPException(404, "no delivery for this order yet")
    try: httpx.put(f"{ORDER_URL}/order/{order_id}/status", json={"status": s.status}, timeout=3)  # keeps order-service in sync
    except Exception as e: print("order-service unreachable:", e, flush=True)
    return out(row)

@app.websocket("/delivery/ws/{order_id}")
async def track(ws: WebSocket, order_id: int):
    await ws.accept(); last = None
    try:
        while True:
            with db.pool.connection() as c:
                row = c.execute(f"{SELECT} WHERE d.order_id = %s", (order_id,)).fetchone()
            cur = row["status"] if row else "PENDING"
            if cur != last:
                await ws.send_json({"order_id": order_id, "status": cur, "rider": {"id": row["rider_id"], "name": row["rider_name"]} if row else None}); last = cur
            await asyncio.sleep(2)
    except WebSocketDisconnect: pass
