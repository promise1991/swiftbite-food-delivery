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
