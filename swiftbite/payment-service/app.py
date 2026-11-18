import uuid
from contextlib import asynccontextmanager
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import db

@asynccontextmanager
async def lifespan(app):
    db.start(); yield; db.stop()

from events import publish
app = FastAPI(title="payment-service", lifespan=lifespan)
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])
COLS = "payment_id, reference, order_id, amount::float AS amount, provider, currency, status, paid_at"

class Pay(BaseModel):
    order_id: int
    amount: float
    provider: str = "paystack"      # paystack | flutterwave

@app.get("/health")
def health(): return {"service": "payment-service", "status": "running"}
@app.get("/ready")
def ready(): return db.check_ready()

@app.post("/payment")
def pay(p: Pay):
    if p.provider not in ("paystack", "flutterwave"): raise HTTPException(400, "provider must be paystack or flutterwave")
    ok = p.amount > 0
    ref = ("PSK_" if p.provider == "paystack" else "FLW_") + uuid.uuid4().hex[:12].upper()
    with db.pool.connection() as c:
        row = c.execute(
            "INSERT INTO payments (payment_id, reference, order_id, amount, provider, status) VALUES (%s, %s, %s, %s, %s, %s) "
            "ON CONFLICT (order_id) DO UPDATE SET payment_id = EXCLUDED.payment_id, reference = EXCLUDED.reference, "
            "amount = EXCLUDED.amount, provider = EXCLUDED.provider, status = EXCLUDED.status, paid_at = now() "
            f"RETURNING {COLS}", (uuid.uuid4().hex[:10], ref, p.order_id, p.amount, p.provider, "success" if ok else "failed")).fetchone()
    if ok: publish("payment.success", {"order_id": p.order_id, "email": "customer@example.com"})
    return row

@app.get("/payment/{order_id}")
def get_payment(order_id: int):
    with db.pool.connection() as c:
        row = c.execute(f"SELECT {COLS} FROM payments WHERE order_id = %s", (order_id,)).fetchone()
    if not row: raise HTTPException(404, "no payment for this order")
    return row
