import asyncio, os
import httpx
from fastapi import FastAPI, HTTPException, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
app = FastAPI(title="delivery-service")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])
ORDER_URL = os.getenv("ORDER_URL", "http://order-service:8005")
RIDERS = [{"id": 1, "name": "Tunde"}, {"id": 2, "name": "Amaka"}, {"id": 3, "name": "Chidi"}]
DELIVERIES: dict = {}
FLOW = ["ACCEPTED", "PICKED_UP", "DELIVERED"]
class New(BaseModel):
    order_id: int
    restaurant_id: int | None = None
    items_summary: str = ""
class Status(BaseModel):
    status: str
@app.get("/health")
def health(): return {"service": "delivery-service", "status": "running"}
@app.get("/ready")
def ready(): return {"ready": True}
@app.post("/delivery")
def create(n: New):
    if n.order_id not in DELIVERIES:      # idempotent; round-robin rider assignment
        DELIVERIES[n.order_id] = {"id": n.order_id, "order_id": n.order_id, "restaurant_id": n.restaurant_id,
            "items_summary": n.items_summary, "rider": RIDERS[len(DELIVERIES) % len(RIDERS)], "status": "ACCEPTED"}
    return DELIVERIES[n.order_id]
@app.get("/delivery")
def list_all(status: str | None = None, rider_id: int | None = None):
    return [d for d in DELIVERIES.values() if (not status or d["status"] == status) and (not rider_id or d["rider"]["id"] == rider_id)]
@app.get("/delivery/{order_id}")
def one(order_id: int):
    if order_id not in DELIVERIES: raise HTTPException(404, "no delivery for this order yet")
    return DELIVERIES[order_id]
@app.put("/delivery/{order_id}/status")
def update(order_id: int, s: Status):
    if order_id not in DELIVERIES: raise HTTPException(404, "no delivery for this order yet")
    if s.status not in FLOW: raise HTTPException(400, f"status must be one of {FLOW}")
    DELIVERIES[order_id]["status"] = s.status
    try: httpx.put(f"{ORDER_URL}/order/{order_id}/status", json={"status": s.status}, timeout=3)  # keeps order-service in sync
    except Exception as e: print("order-service unreachable:", e, flush=True)
    return DELIVERIES[order_id]
@app.websocket("/delivery/ws/{order_id}")
async def track(ws: WebSocket, order_id: int):
    await ws.accept(); last = None
    try:
        while True:
            d = DELIVERIES.get(order_id); cur = d["status"] if d else "PENDING"
            if cur != last:
                await ws.send_json({"order_id": order_id, "status": cur, "rider": d["rider"] if d else None}); last = cur
            await asyncio.sleep(2)
    except WebSocketDisconnect: pass
