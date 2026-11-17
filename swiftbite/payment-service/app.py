import uuid
from datetime import datetime, timezone
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from events import publish
app = FastAPI(title="payment-service")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])
PAYMENTS: dict = {}
class Pay(BaseModel):
    order_id: int
    amount: float
    provider: str = "paystack"      # paystack | flutterwave
@app.get("/health")
def health(): return {"service": "payment-service", "status": "running"}
@app.get("/ready")
def ready(): return {"ready": True}
@app.post("/payment")
def pay(p: Pay):
    if p.provider not in ("paystack", "flutterwave"): raise HTTPException(400, "provider must be paystack or flutterwave")
    ok = p.amount > 0
    row = {"payment_id": uuid.uuid4().hex[:10], "reference": ("PSK_" if p.provider == "paystack" else "FLW_") + uuid.uuid4().hex[:12].upper(),
           "order_id": p.order_id, "amount": p.amount, "provider": p.provider, "currency": "NGN",
           "status": "success" if ok else "failed", "paid_at": datetime.now(timezone.utc).isoformat()}
    PAYMENTS[p.order_id] = row
    if ok: publish("payment.success", {"order_id": p.order_id, "email": "customer@example.com"})
    return row
@app.get("/payment/{order_id}")
def get_payment(order_id: int):
    if order_id not in PAYMENTS: raise HTTPException(404, "no payment for this order")
    return PAYMENTS[order_id]
