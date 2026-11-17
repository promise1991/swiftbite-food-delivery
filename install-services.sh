#!/usr/bin/env bash
# SwiftBite: replace the placeholder services with the real ones, push to ECR as v2, redeploy, and test.
# Run it from the folder that contains helm/ (swiftbite-food-delivery):   bash install-services.sh
set -euo pipefail
ACCOUNT_ID="${1:-293160392232}"; REGION="${2:-eu-north-1}"
TAG=v2; NS=swiftbitens
REGISTRY="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com"
SERVICES="api-gateway auth-service user-service cart-service order-service payment-service restaurant-service search-service menu-service review-service notification-service delivery-service analytics-service"
[ -d helm/charts ] || { echo "ERROR: run this from the folder that contains helm/ (swiftbite-food-delivery)"; exit 1; }
if [ -z "${SB_WRITE_ONLY:-}" ]; then
  kubectl get ns >/dev/null 2>&1 || { echo "ERROR: kubectl cannot reach the cluster. Run: minikube start"; exit 1; }
fi

echo "=== 1/6 Writing the real service code into ./swiftbite ==="
mkdir -p swiftbite
if [ ! -d swiftbite/frontend ] && [ -d swiftbite-old-backup/frontend ]; then cp -r swiftbite-old-backup/frontend swiftbite/frontend; fi
mkdir -p swiftbite/api-gateway
cat > swiftbite/api-gateway/app.py <<'__SB_EOF__'
import json, os
import httpx
from fastapi import FastAPI, Request, Response
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
app = FastAPI(title="api-gateway")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])
DEFAULT = {
 "auth": "http://auth-service:8001/auth", "users": "http://user-service:8002/users",
 "cart": "http://cart-service:8003/cart", "order": "http://order-service:8005/order",
 "payment": "http://payment-service:8006/payment", "restaurants": "http://restaurant-service:8007/restaurants",
 "search": "http://search-service:8008/search", "menu": "http://menu-service:8009/menu",
 "reviews": "http://review-service:8010/reviews", "notifications": "http://notification-service:8011/notifications",
 "delivery": "http://delivery-service:8012/delivery", "analytics": "http://analytics-service:8013/analytics"}
ROUTES = json.loads(os.getenv("ROUTES_JSON", "null")) or DEFAULT   # override all routes from a Helm ConfigMap
client = httpx.AsyncClient(timeout=10)
SKIP = {"host", "content-length", "connection", "transfer-encoding", "accept-encoding"}

@app.get("/health")
def health(): return {"service": "api-gateway", "status": "running", "routes": list(ROUTES)}
@app.get("/ready")
def ready(): return {"ready": True}

@app.api_route("/{name}", methods=["GET", "POST", "PUT", "PATCH", "DELETE"])
@app.api_route("/{name}/{path:path}", methods=["GET", "POST", "PUT", "PATCH", "DELETE"])
async def proxy(request: Request, name: str, path: str = ""):
    base = ROUTES.get(name)
    if not base: return JSONResponse({"detail": f"unknown route '{name}'"}, 404)
    url = base + ("/" + path if path else "")
    try:
        r = await client.request(request.method, url, params=request.query_params, content=await request.body(),
                                 headers={k: v for k, v in request.headers.items() if k.lower() not in SKIP})
    except httpx.HTTPError:
        return JSONResponse({"detail": f"{name} service unavailable"}, 502)
    return Response(r.content, r.status_code, media_type=r.headers.get("content-type"))
__SB_EOF__
cat > swiftbite/api-gateway/requirements.txt <<'__SB_EOF__'
fastapi
uvicorn
pydantic
httpx
pika
__SB_EOF__
cat > swiftbite/api-gateway/Dockerfile <<'__SB_EOF__'
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
EXPOSE 8000
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]
__SB_EOF__
mkdir -p swiftbite/auth-service
cat > swiftbite/auth-service/app.py <<'__SB_EOF__'
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
app = FastAPI(title="auth-service")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])
USERS = {"promise@example.com": {"password": "1234", "user_id": 1}}   # test user
class LoginReq(BaseModel):
    email: str
    password: str
    role: str = "user"
@app.get("/health")
def health(): return {"service": "auth-service", "status": "running"}
@app.get("/ready")
def ready(): return {"ready": True}
@app.post("/auth/login")
def login(req: LoginReq):
    u = USERS.get(req.email)
    if u and u["password"] == req.password:
        return {"token": f"mock-jwt-token-{u['user_id']}", "user_id": u["user_id"], "role": req.role, "email": req.email}
    return {"detail": "Invalid login"}
@app.post("/auth/register")
def register(req: LoginReq):
    uid = max(u["user_id"] for u in USERS.values()) + 1
    USERS[req.email] = {"password": req.password, "user_id": uid}
    return {"user_id": uid, "email": req.email, "role": req.role, "status": "REGISTERED"}
__SB_EOF__
cat > swiftbite/auth-service/requirements.txt <<'__SB_EOF__'
fastapi
uvicorn
pydantic
httpx
pika
__SB_EOF__
cat > swiftbite/auth-service/Dockerfile <<'__SB_EOF__'
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
EXPOSE 8001
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8001"]
__SB_EOF__
mkdir -p swiftbite/user-service
cat > swiftbite/user-service/app.py <<'__SB_EOF__'
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
app = FastAPI(title="user-service")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])
USERS = {1: {"id": 1, "name": "Promise", "email": "promise@example.com", "phone": "+2348000000000"}}
ADDRESSES = {1: [{"id": 1, "label": "Home", "street": "12 Bode Thomas St", "area": "Surulere", "city": "Lagos"}]}
class Profile(BaseModel):
    name: str = ""
    email: str = ""
    phone: str = ""
class Address(BaseModel):
    label: str = "Home"
    street: str
    area: str = ""
    city: str = "Lagos"
@app.get("/health")
def health(): return {"service": "user-service", "status": "running"}
@app.get("/ready")
def ready(): return {"ready": True}
@app.get("/users/{uid}")
def get_user(uid: int):
    if uid not in USERS: raise HTTPException(404, "user not found")
    return {**USERS[uid], "addresses": ADDRESSES.get(uid, [])}
@app.put("/users/{uid}")
def put_user(uid: int, p: Profile):
    USERS[uid] = {**USERS.get(uid, {"id": uid}), **p.model_dump(exclude_unset=True)}
    return USERS[uid]
@app.get("/users/{uid}/addresses")
def addresses(uid: int): return ADDRESSES.get(uid, [])
@app.post("/users/{uid}/addresses")
def add_address(uid: int, a: Address):
    rows = ADDRESSES.setdefault(uid, [])
    row = {"id": max([r["id"] for r in rows], default=0) + 1, **a.model_dump()}
    rows.append(row); return row
@app.delete("/users/{uid}/addresses/{aid}")
def del_address(uid: int, aid: int):
    ADDRESSES[uid] = [r for r in ADDRESSES.get(uid, []) if r["id"] != aid]
    return {"deleted": aid}
__SB_EOF__
cat > swiftbite/user-service/requirements.txt <<'__SB_EOF__'
fastapi
uvicorn
pydantic
httpx
pika
__SB_EOF__
cat > swiftbite/user-service/Dockerfile <<'__SB_EOF__'
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
EXPOSE 8002
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8002"]
__SB_EOF__
mkdir -p swiftbite/cart-service
cat > swiftbite/cart-service/app.py <<'__SB_EOF__'
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
app = FastAPI(title="cart-service")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])
CARTS: dict = {}  # in-memory, like the other mock services

class Item(BaseModel):
    user_id: int = 1
    restaurant_id: int
    item_id: int
    name: str
    price: float
    qty: int = 1
class Qty(BaseModel):
    qty: int

def view(uid: int):
    c = CARTS.get(uid, {"restaurant_id": None, "items": {}})
    items = list(c["items"].values())
    return {"user_id": uid, "restaurant_id": c["restaurant_id"], "items": items,
            "count": sum(i["qty"] for i in items),
            "total": round(sum(i["price"] * i["qty"] for i in items), 2)}

@app.get("/health")
def health(): return {"service": "cart-service", "status": "running"}
@app.get("/ready")
def ready(): return {"ready": True}
@app.get("/cart/{uid}")
def get_cart(uid: int): return view(uid)
@app.post("/cart/add")
def add(i: Item):
    c = CARTS.get(i.user_id)
    if not c or c["restaurant_id"] != i.restaurant_id:  # one restaurant per cart
        c = CARTS[i.user_id] = {"restaurant_id": i.restaurant_id, "items": {}}
    if i.item_id in c["items"]: c["items"][i.item_id]["qty"] += i.qty
    else: c["items"][i.item_id] = {"item_id": i.item_id, "name": i.name, "price": i.price, "qty": i.qty}
    return view(i.user_id)
@app.put("/cart/{uid}/item/{item_id}")
def set_qty(uid: int, item_id: int, q: Qty):
    c = CARTS.get(uid)
    if c and item_id in c["items"]:
        if q.qty <= 0: del c["items"][item_id]
        else: c["items"][item_id]["qty"] = q.qty
    return view(uid)
@app.delete("/cart/{uid}/item/{item_id}")
def remove(uid: int, item_id: int): return set_qty(uid, item_id, Qty(qty=0))
@app.delete("/cart/{uid}")
def clear(uid: int):
    CARTS.pop(uid, None); return view(uid)
__SB_EOF__
cat > swiftbite/cart-service/requirements.txt <<'__SB_EOF__'
fastapi
uvicorn
pydantic
__SB_EOF__
cat > swiftbite/cart-service/Dockerfile <<'__SB_EOF__'
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app.py .
EXPOSE 8003
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8003"]
__SB_EOF__
mkdir -p swiftbite/order-service
cat > swiftbite/order-service/app.py <<'__SB_EOF__'
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
__SB_EOF__
cat > swiftbite/order-service/requirements.txt <<'__SB_EOF__'
fastapi
uvicorn
pydantic
httpx
pika
__SB_EOF__
cat > swiftbite/order-service/Dockerfile <<'__SB_EOF__'
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
EXPOSE 8005
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8005"]
__SB_EOF__
cat > swiftbite/order-service/events.py <<'__SB_EOF__'
import json, os, threading
import pika
URL = os.getenv("RABBITMQ_URL", "amqp://guest:guest@rabbitmq:5672/")
EXCHANGE = os.getenv("RABBITMQ_EXCHANGE", "swiftbite.events")
def _pub(key, body):
    try:
        p = pika.URLParameters(URL); p.socket_timeout = 2; p.connection_attempts = 1
        c = pika.BlockingConnection(p); ch = c.channel()
        ch.exchange_declare(EXCHANGE, "topic", durable=True)
        ch.basic_publish(EXCHANGE, key, json.dumps(body)); c.close()
    except Exception as e:
        print("event not published:", key, e, flush=True)
def publish(key, body): threading.Thread(target=_pub, args=(key, body), daemon=True).start()
__SB_EOF__
mkdir -p swiftbite/payment-service
cat > swiftbite/payment-service/app.py <<'__SB_EOF__'
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
__SB_EOF__
cat > swiftbite/payment-service/requirements.txt <<'__SB_EOF__'
fastapi
uvicorn
pydantic
httpx
pika
__SB_EOF__
cat > swiftbite/payment-service/Dockerfile <<'__SB_EOF__'
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
EXPOSE 8006
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8006"]
__SB_EOF__
cat > swiftbite/payment-service/events.py <<'__SB_EOF__'
import json, os, threading
import pika
URL = os.getenv("RABBITMQ_URL", "amqp://guest:guest@rabbitmq:5672/")
EXCHANGE = os.getenv("RABBITMQ_EXCHANGE", "swiftbite.events")
def _pub(key, body):
    try:
        p = pika.URLParameters(URL); p.socket_timeout = 2; p.connection_attempts = 1
        c = pika.BlockingConnection(p); ch = c.channel()
        ch.exchange_declare(EXCHANGE, "topic", durable=True)
        ch.basic_publish(EXCHANGE, key, json.dumps(body)); c.close()
    except Exception as e:
        print("event not published:", key, e, flush=True)
def publish(key, body): threading.Thread(target=_pub, args=(key, body), daemon=True).start()
__SB_EOF__
mkdir -p swiftbite/restaurant-service
cat > swiftbite/restaurant-service/app.py <<'__SB_EOF__'
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
app = FastAPI(title="restaurant-service")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])
R = [
 {"id": 1, "name": "Mama Put Kitchen", "cuisine": "African food", "area": "Surulere", "rating": 4.6, "eta": "25-35 min"},
 {"id": 2, "name": "Pasta Palace", "cuisine": "Pasta", "area": "Yaba", "rating": 4.4, "eta": "30-40 min"},
 {"id": 3, "name": "Grill House", "cuisine": "Fast food", "area": "Ikeja", "rating": 4.2, "eta": "20-30 min"},
 {"id": 4, "name": "Green Bowl", "cuisine": "Salad", "area": "Lekki", "rating": 4.5, "eta": "25-35 min"},
 {"id": 5, "name": "Sweet Crumbs", "cuisine": "Pastries", "area": "Ogudu", "rating": 4.3, "eta": "20-30 min"},
 {"id": 6, "name": "Wok This Way", "cuisine": "Asian food", "area": "Yaba", "rating": 4.1, "eta": "30-45 min"}]
class New(BaseModel):
    name: str
    cuisine: str = "African food"
    area: str = "Lagos"
@app.get("/health")
def health(): return {"service": "restaurant-service", "status": "running"}
@app.get("/ready")
def ready(): return {"ready": True}
@app.get("/restaurants")
def list_all(area: str = "", cuisine: str = ""):
    return [r for r in R if (not area or area.lower() in r["area"].lower()) and (not cuisine or cuisine.lower() in r["cuisine"].lower())]
@app.get("/restaurants/{rid}")
def one(rid: int):
    for r in R:
        if r["id"] == rid: return r
    raise HTTPException(404, "restaurant not found")
@app.post("/restaurants")
def create(n: New):
    row = {"id": max(r["id"] for r in R) + 1, **n.model_dump(), "rating": None, "eta": "30-40 min"}
    R.append(row); return row
__SB_EOF__
cat > swiftbite/restaurant-service/requirements.txt <<'__SB_EOF__'
fastapi
uvicorn
pydantic
httpx
pika
__SB_EOF__
cat > swiftbite/restaurant-service/Dockerfile <<'__SB_EOF__'
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
EXPOSE 8007
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8007"]
__SB_EOF__
mkdir -p swiftbite/search-service
cat > swiftbite/search-service/app.py <<'__SB_EOF__'
import os
import httpx
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
app = FastAPI(title="search-service")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])
RESTAURANT_URL = os.getenv("RESTAURANT_URL", "http://restaurant-service:8007")
MENU_URL = os.getenv("MENU_URL", "http://menu-service:8009")
@app.get("/health")
def health(): return {"service": "search-service", "status": "running"}
@app.get("/ready")
def ready(): return {"ready": True}
@app.get("/search")
def search(q: str = ""):
    ql = q.strip().lower()
    with httpx.Client(timeout=3) as c:
        try: restaurants = c.get(f"{RESTAURANT_URL}/restaurants").json()
        except Exception: raise HTTPException(502, "restaurant-service unavailable")
        out = []
        for r in restaurants:
            try: foods = [i["name"] for i in c.get(f"{MENU_URL}/menu/{r['id']}").json() if ql in i["name"].lower()]
            except Exception: foods = []
            if not ql or any(ql in str(r[k]).lower() for k in ("name", "cuisine", "area")) or foods:
                out.append({**r, "matched_items": foods if ql else []})
    return {"query": q, "count": len(out), "results": out}
__SB_EOF__
cat > swiftbite/search-service/requirements.txt <<'__SB_EOF__'
fastapi
uvicorn
pydantic
httpx
pika
__SB_EOF__
cat > swiftbite/search-service/Dockerfile <<'__SB_EOF__'
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
EXPOSE 8008
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8008"]
__SB_EOF__
mkdir -p swiftbite/menu-service
cat > swiftbite/menu-service/app.py <<'__SB_EOF__'
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
app = FastAPI(title="menu-service")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])
M = {
 1: [("Jollof rice and chicken", 3500), ("Pounded yam and egusi", 4200), ("Chapman", 1500)],
 2: [("Spaghetti bolognese", 4000), ("Creamy chicken penne", 4500), ("Garlic bread", 1200)],
 3: [("Double beef burger", 5000), ("Peppered chicken wings", 3800), ("Fries", 1500)],
 4: [("Caesar salad", 3800), ("Chicken avocado bowl", 4800), ("Fresh smoothie", 2000)],
 5: [("Meat pie", 1000), ("Chin chin pack", 1500), ("Cream doughnut", 900)],
 6: [("Chicken fried rice", 4200), ("Beef noodles", 3900), ("Spring rolls", 2000)]}
MENU = {rid: [{"id": rid * 10 + i + 1, "restaurant_id": rid, "name": n, "price": p} for i, (n, p) in enumerate(items)] for rid, items in M.items()}
class Item(BaseModel):
    name: str
    price: float
@app.get("/health")
def health(): return {"service": "menu-service", "status": "running"}
@app.get("/ready")
def ready(): return {"ready": True}
@app.get("/menu/{rid}")
def get_menu(rid: int): return MENU.get(rid, [])
@app.post("/menu/{rid}")
def add(rid: int, i: Item):
    rows = MENU.setdefault(rid, [])
    row = {"id": max([r["id"] for r in rows], default=rid * 10) + 1, "restaurant_id": rid, **i.model_dump()}
    rows.append(row); return row
@app.put("/menu/{rid}/{item_id}")
def update(rid: int, item_id: int, i: Item):
    for r in MENU.get(rid, []):
        if r["id"] == item_id: r.update(i.model_dump()); return r
    raise HTTPException(404, "item not found")
@app.delete("/menu/{rid}/{item_id}")
def delete(rid: int, item_id: int):
    MENU[rid] = [r for r in MENU.get(rid, []) if r["id"] != item_id]; return {"deleted": item_id}
__SB_EOF__
cat > swiftbite/menu-service/requirements.txt <<'__SB_EOF__'
fastapi
uvicorn
pydantic
httpx
pika
__SB_EOF__
cat > swiftbite/menu-service/Dockerfile <<'__SB_EOF__'
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
EXPOSE 8009
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8009"]
__SB_EOF__
mkdir -p swiftbite/review-service
cat > swiftbite/review-service/app.py <<'__SB_EOF__'
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
app = FastAPI(title="review-service")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])
REVIEWS: list = []

class Review(BaseModel):
    target_type: str            # "restaurant" or "rider"
    target_id: int
    user_id: int = 1
    order_id: int | None = None
    rating: int = Field(ge=1, le=5)
    comment: str = ""

@app.get("/health")
def health(): return {"service": "review-service", "status": "running"}
@app.get("/ready")
def ready(): return {"ready": True}
@app.post("/reviews")
def create(r: Review):
    if r.target_type not in ("restaurant", "rider"):
        raise HTTPException(400, "target_type must be restaurant or rider")
    row = {"id": len(REVIEWS) + 1, **r.model_dump()}
    REVIEWS.append(row); return row
@app.get("/reviews/{target_type}/{target_id}")
def list_for(target_type: str, target_id: int):
    rows = [r for r in REVIEWS if r["target_type"] == target_type and r["target_id"] == target_id]
    avg = round(sum(r["rating"] for r in rows) / len(rows), 1) if rows else None
    return {"target_type": target_type, "target_id": target_id, "average": avg, "count": len(rows), "reviews": rows}
__SB_EOF__
cat > swiftbite/review-service/requirements.txt <<'__SB_EOF__'
fastapi
uvicorn
pydantic
__SB_EOF__
cat > swiftbite/review-service/Dockerfile <<'__SB_EOF__'
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app.py .
EXPOSE 8010
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8010"]
__SB_EOF__
mkdir -p swiftbite/notification-service
cat > swiftbite/notification-service/app.py <<'__SB_EOF__'
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
__SB_EOF__
cat > swiftbite/notification-service/requirements.txt <<'__SB_EOF__'
fastapi
uvicorn
pydantic
pika
__SB_EOF__
cat > swiftbite/notification-service/Dockerfile <<'__SB_EOF__'
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY app.py .
EXPOSE 8011
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8011"]
__SB_EOF__
mkdir -p swiftbite/delivery-service
cat > swiftbite/delivery-service/app.py <<'__SB_EOF__'
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
__SB_EOF__
cat > swiftbite/delivery-service/requirements.txt <<'__SB_EOF__'
fastapi
uvicorn
pydantic
httpx
pika
__SB_EOF__
cat > swiftbite/delivery-service/Dockerfile <<'__SB_EOF__'
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
EXPOSE 8012
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8012"]
__SB_EOF__
mkdir -p swiftbite/analytics-service
cat > swiftbite/analytics-service/app.py <<'__SB_EOF__'
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
__SB_EOF__
cat > swiftbite/analytics-service/requirements.txt <<'__SB_EOF__'
fastapi
uvicorn
pydantic
httpx
pika
__SB_EOF__
cat > swiftbite/analytics-service/Dockerfile <<'__SB_EOF__'
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY . .
EXPOSE 8013
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8013"]
__SB_EOF__

echo "=== 2/6 Setting chart ports to match the real services ==="
for pair in api-gateway:8000 auth-service:8001 user-service:8002 cart-service:8003 order-service:8005 payment-service:8006 restaurant-service:8007 search-service:8008 menu-service:8009 review-service:8010 notification-service:8011 delivery-service:8012 analytics-service:8013; do
  s=${pair%%:*}; p=${pair##*:}
  sed -i "s/^  port: .*/  port: $p/" "helm/charts/$s/values.yaml"
done
if [ -n "${SB_WRITE_ONLY:-}" ]; then echo "write-only mode: stopping here"; exit 0; fi

echo "=== 3/6 Building and pushing 13 images as :$TAG (a few minutes) ==="
aws ecr get-login-password --region "$REGION" | docker login --username AWS --password-stdin "$REGISTRY"
for s in $SERVICES; do
  aws ecr describe-repositories --repository-names "$s" --region "$REGION" >/dev/null 2>&1 \
    || aws ecr create-repository --repository-name "$s" --region "$REGION" >/dev/null
  echo ">>> $s"
  docker build -q -t "$REGISTRY/$s:$TAG" "./swiftbite/$s" >/dev/null
  docker push -q "$REGISTRY/$s:$TAG" >/dev/null
done

echo "=== 4/6 Refreshing the ECR pull secret ==="
kubectl create namespace "$NS" --dry-run=client -o yaml | kubectl apply -f - >/dev/null
kubectl -n "$NS" create secret docker-registry ecr-secret --docker-server="$REGISTRY" --docker-username=AWS \
  --docker-password="$(aws ecr get-login-password --region "$REGION")" --dry-run=client -o yaml | kubectl apply -f - >/dev/null

echo "=== 5/6 Deploying with Helm (frontend keeps its working v1 image) ==="
helm dependency update ./helm/swiftbite >/dev/null
helm upgrade --install swiftbite ./helm/swiftbite -n "$NS" --create-namespace \
  --set global.image.registry="$REGISTRY" --set global.image.tag="$TAG" \
  --set global.imagePullSecrets=ecr-secret --set frontend.image.tag=v1 >/dev/null

echo "=== 6/6 Waiting for pods, then testing through the frontend ==="
for s in $SERVICES frontend; do
  if kubectl rollout status "deploy/$s" -n "$NS" --timeout=240s >/dev/null 2>&1; then echo "  ready: $s"; else echo "  NOT READY: $s"; fi
done
kubectl port-forward -n "$NS" svc/frontend 18080:80 >/dev/null 2>&1 &
PF=$!
sleep 5
R=$(curl -s -m 10 localhost:18080/api/restaurants || true)
M=$(curl -s -m 10 localhost:18080/api/menu/1 || true)
L=$(curl -s -m 10 -X POST localhost:18080/api/auth/login -H 'Content-Type: application/json' -d '{"email":"promise@example.com","password":"1234","role":"user"}' || true)
kill $PF 2>/dev/null || true
echo "$R" | grep -q "Mama Put" && echo "  PASS  restaurants" || echo "  FAIL  restaurants: ${R:0:150}"
echo "$M" | grep -q "Jollof"   && echo "  PASS  menu"        || echo "  FAIL  menu: ${M:0:150}"
echo "$L" | grep -q "token"    && echo "  PASS  login"       || echo "  FAIL  login: ${L:0:150}"
echo
kubectl get pods -n "$NS"
echo
echo "Open the site:  kubectl port-forward -n $NS svc/frontend 3000:80   then http://localhost:3000"
