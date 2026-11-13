# SwiftBite Notification-service — listens to RabbitMQ
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

app = FastAPI(title="notification-service")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

sent = []

class NotifyReq(BaseModel):
    email: str
    message: str
    order_id: int

@app.get("/health")
def health():
    return {"service":"notification-service","status":"running","sent_count":len(sent)}

@app.post("/notify")
def notify(req: NotifyReq):
    # For now, mock send — in real life, this go call email API
    # In Phase 2, this go be called by RabbitMQ consumer, not directly
    entry = {"order_id":req.order_id,"email":req.email,"message":req.message,"status":"SENT"}
    sent.append(entry)
    print(f"📧 Email sent to {req.email}: {req.message}")
    return entry

@app.get("/notifications")
def list_sent():
    return {"service":"notification-service","data":sent,"count":len(sent)}
