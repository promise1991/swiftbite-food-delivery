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
