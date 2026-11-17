import json, os, threading, time
from datetime import datetime, timezone
import pika
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
app = FastAPI(title="notification-service")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

RABBITMQ_URL = os.getenv("RABBITMQ_URL", "amqp://guest:guest@rabbitmq:5672/")
EXCHANGE = os.getenv("RABBITMQ_EXCHANGE", "swiftbite.events")
QUEUE = os.getenv("RABBITMQ_QUEUE", "notifications")
LOG: list = []
STATE = {"mq_connected": False}

TEMPLATES = {
    "order.placed": "Your SwiftBite order #{order_id} has been placed.",
    "order.accepted": "Your restaurant accepted order #{order_id}.",
    "delivery.picked_up": "Your rider picked up order #{order_id} and is on the way.",
    "order.delivered": "Order #{order_id} has arrived. Enjoy, and rate your meal!",
    "payment.success": "Payment received for order #{order_id}.",
}

def send(channel: str, to: str, subject: str, message: str):
    # Mock senders. Swap for SES / Twilio / Termii later.
    row = {"at": datetime.now(timezone.utc).isoformat(), "channel": channel, "to": to,
           "subject": subject, "message": message}
    LOG.append(row); LOG[:] = LOG[-200:]
    print(f"[{channel.upper()}] to={to} | {subject} | {message}", flush=True)
    return row

def handle(ch, method, props, body):
    try:
        evt = json.loads(body)
        key = method.routing_key
        msg = TEMPLATES.get(key, f"Update on your order: {key}").format(order_id=evt.get("order_id", "?"))
        send("email", evt.get("email", "customer@example.com"), "SwiftBite update", msg)
        if evt.get("phone"): send("sms", evt["phone"], "SwiftBite", msg)
    except Exception as e:
        print("bad event:", e, flush=True)
    ch.basic_ack(method.delivery_tag)

def consume():
    while True:
        try:
            conn = pika.BlockingConnection(pika.URLParameters(RABBITMQ_URL))
            ch = conn.channel()
            ch.exchange_declare(EXCHANGE, "topic", durable=True)
            ch.queue_declare(QUEUE, durable=True)
            for k in ("order.*", "delivery.*", "payment.*"): ch.queue_bind(QUEUE, EXCHANGE, k)
            ch.basic_consume(QUEUE, handle)
            STATE["mq_connected"] = True
            ch.start_consuming()
        except Exception as e:
            STATE["mq_connected"] = False
            print("rabbitmq unavailable, retrying in 5s:", e, flush=True)
            time.sleep(5)

@app.on_event("startup")
def start(): threading.Thread(target=consume, daemon=True).start()

class Msg(BaseModel):
    channel: str = "email"
    to: str
    subject: str = "SwiftBite"
    message: str

@app.get("/health")
def health(): return {"service": "notification-service", "status": "running", "rabbitmq": STATE["mq_connected"]}
@app.get("/ready")
def ready(): return {"ready": True}   # stays ready without RabbitMQ; consumer keeps retrying
@app.post("/notifications/send")
def post(m: Msg): return send(m.channel, m.to, m.subject, m.message)
@app.get("/notifications")
def history(): return {"count": len(LOG), "items": LOG[-50:]}
