import os
from collections import Counter
from datetime import datetime, timezone
import httpx
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
app = FastAPI(title="analytics-service")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])
ORDER_URL = os.getenv("ORDER_URL", "http://order-service:8005")
def orders():
    try: return httpx.get(f"{ORDER_URL}/order", timeout=3).json()
    except Exception: raise HTTPException(502, "order-service unavailable")
@app.get("/health")
def health(): return {"service": "analytics-service", "status": "running"}
@app.get("/ready")
def ready(): return {"ready": True}
@app.get("/analytics/summary")
def summary():
    rows = orders(); today = datetime.now(timezone.utc).date().isoformat()
    td = [o for o in rows if o["created_at"][:10] == today]
    return {"date": today, "orders_today": len(td), "orders_total": len(rows),
            "revenue_today": sum(o["total"] for o in td if o["status"] != "CANCELLED"),
            "by_status": dict(Counter(o["status"] for o in td))}
@app.get("/analytics/orders-today")
def orders_today(): return {"orders_today": summary()["orders_today"]}
