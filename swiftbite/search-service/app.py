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
