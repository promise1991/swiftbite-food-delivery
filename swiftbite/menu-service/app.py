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
