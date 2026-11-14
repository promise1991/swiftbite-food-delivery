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
