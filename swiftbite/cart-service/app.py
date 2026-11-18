import json, os
import redis
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
app = FastAPI(title="cart-service")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])
r = redis.Redis.from_url(os.getenv("REDIS_URL", "redis://redis:6379/0"), decode_responses=True)
TTL = 7 * 24 * 3600   # abandoned carts expire after a week

class Item(BaseModel):
    user_id: int = 1
    restaurant_id: int
    item_id: int
    name: str
    price: float
    qty: int = 1
class Qty(BaseModel):
    qty: int

def load(uid: int):
    raw = r.get(f"cart:{uid}")
    return json.loads(raw) if raw else {"restaurant_id": None, "items": {}}
def save(uid: int, c):
    if c["items"]: r.set(f"cart:{uid}", json.dumps(c), ex=TTL)
    else: r.delete(f"cart:{uid}")
def view(uid: int):
    c = load(uid); items = list(c["items"].values())
    return {"user_id": uid, "restaurant_id": c["restaurant_id"], "items": items,
            "count": sum(i["qty"] for i in items), "total": round(sum(i["price"] * i["qty"] for i in items), 2)}

@app.get("/health")
def health(): return {"service": "cart-service", "status": "running"}
@app.get("/ready")
def ready():
    from fastapi import HTTPException
    try: r.ping()
    except Exception: raise HTTPException(503, "redis unavailable")
    return {"ready": True}
@app.get("/cart/{uid}")
def get_cart(uid: int): return view(uid)
@app.post("/cart/add")
def add(i: Item):
    c = load(i.user_id)
    if c["restaurant_id"] != i.restaurant_id:     # one restaurant per cart
        c = {"restaurant_id": i.restaurant_id, "items": {}}
    k = str(i.item_id)
    if k in c["items"]: c["items"][k]["qty"] += i.qty
    else: c["items"][k] = {"item_id": i.item_id, "name": i.name, "price": i.price, "qty": i.qty}
    save(i.user_id, c); return view(i.user_id)
@app.put("/cart/{uid}/item/{item_id}")
def set_qty(uid: int, item_id: int, q: Qty):
    c = load(uid); k = str(item_id)
    if k in c["items"]:
        if q.qty <= 0: del c["items"][k]
        else: c["items"][k]["qty"] = q.qty
        save(uid, c)
    return view(uid)
@app.delete("/cart/{uid}/item/{item_id}")
def remove(uid: int, item_id: int): return set_qty(uid, item_id, Qty(qty=0))
@app.delete("/cart/{uid}")
def clear(uid: int):
    r.delete(f"cart:{uid}"); return view(uid)
