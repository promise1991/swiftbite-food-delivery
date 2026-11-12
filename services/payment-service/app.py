# SwiftBite Payment-service — MOCK Paystack (Test Mode, no real money)
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
app = FastAPI(title="payment-service")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])
class CreateReq(BaseModel):
    order_id: int
    amount: int
class ConfirmReq(BaseModel):
    payment_id: str
    card: str
payments = {}
@app.get("/health")
def health():
    return {"service":"payment-service","status":"running"}
@app.post("/payment/create")
def create(req: CreateReq):
    pid = f"PAY-{req.order_id}"
    # Idempotency: if already created, return same one — no double charge
    if pid in payments:
        return {"payment_id": pid, "status": payments[pid]["status"], "amount": req.amount}
    payments[pid] = {"order_id": req.order_id, "amount": req.amount, "status": "PENDING"}
    return {"payment_id": pid, "status": "PENDING", "amount": req.amount}
@app.post("/payment/confirm")
def confirm(req: ConfirmReq):
    # Test cards: 4084... = SUCCESS, 0000... = FAILED
    if req.card.startswith("4084"):
        payments[req.payment_id]["status"] = "SUCCESS"
    else:
        payments[req.payment_id]["status"] = "FAILED"
    return {"payment_id": req.payment_id, "status": payments[req.payment_id]["status"]}
@app.post("/payment/refund")
def refund(req: ConfirmReq):
    payments[req.payment_id]["status"] = "REFUNDED"
    return {"payment_id": req.payment_id, "status": "REFUNDED"}
