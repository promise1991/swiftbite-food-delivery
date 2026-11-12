# SwiftBite Order-service
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import requests
app = FastAPI(title="order-service")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])
orders = {}
next_id = 1
class OrderReq(BaseModel):
    user_id: int
    items: list
    total: int
    address: str
@app.get("/health")
def health():
    return {"service":"order-service","status":"running"}
@app.post("/order/create")
def create(req: OrderReq):
    global next_id
    oid = next_id; next_id += 1
    orders[oid] = {"order_id":oid,"user_id":req.user_id,"items":req.items,"total":req.total,"address":req.address,"status":"PENDING"}
    # Call payment-service (Sync - must wait, money must comot)
    try:
        pay = requests.post("http://localhost:8006/payment/create", json={"order_id":oid,"amount":req.total}, timeout=5).json()
        orders[oid]["payment_id"] = pay["payment_id"]
        orders[oid]["status"] = "WAITING_PAYMENT"
    except Exception as e:
        orders[oid]["status"] = "PAYMENT_UNREACHABLE"
    return orders[oid]
@app.get("/order/{oid}")
def get_order(oid: int):
    return orders.get(oid, {"detail":"Order not found"})
@app.post("/order/{oid}/mark-paid")
def mark_paid(oid: int):
    # Called after payment SUCCESS — this is where we go publish to RabbitMQ later
    if oid in orders:
        orders[oid]["status"] = "PAID"
        # TODO Phase 2: publish to RabbitMQ queue "order_created"
        # For now, just return — notification will be manual
        return orders[oid]
    return {"detail":"Order not found"}
