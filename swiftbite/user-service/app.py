import psycopg
from contextlib import asynccontextmanager
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import db

@asynccontextmanager
async def lifespan(app):
    db.start(); yield; db.stop()

app = FastAPI(title="user-service", lifespan=lifespan)
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

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
def ready(): return db.check_ready()

@app.get("/users/{uid}")
def get_user(uid: int):
    with db.pool.connection() as c:
        u = c.execute("SELECT id, name, email, phone FROM users WHERE id = %s", (uid,)).fetchone()
        if not u: raise HTTPException(404, "user not found")
        addr = c.execute("SELECT id, label, street, area, city FROM addresses WHERE user_id = %s ORDER BY id", (uid,)).fetchall()
    return {**u, "addresses": addr}

@app.put("/users/{uid}")
def put_user(uid: int, p: Profile):
    with db.pool.connection() as c:
        return c.execute(
            "INSERT INTO users (id, name, email, phone) VALUES (%s, %s, %s, %s) "
            "ON CONFLICT (id) DO UPDATE SET name = EXCLUDED.name, email = EXCLUDED.email, phone = EXCLUDED.phone "
            "RETURNING id, name, email, phone", (uid, p.name, p.email, p.phone)).fetchone()

@app.get("/users/{uid}/addresses")
def addresses(uid: int):
    with db.pool.connection() as c:
        return c.execute("SELECT id, label, street, area, city FROM addresses WHERE user_id = %s ORDER BY id", (uid,)).fetchall()

@app.post("/users/{uid}/addresses")
def add_address(uid: int, a: Address):
    try:
        with db.pool.connection() as c:
            return c.execute("INSERT INTO addresses (user_id, label, street, area, city) VALUES (%s, %s, %s, %s, %s) "
                             "RETURNING id, label, street, area, city", (uid, a.label, a.street, a.area, a.city)).fetchone()
    except psycopg.errors.ForeignKeyViolation:
        raise HTTPException(404, "user not found: create the profile first")

@app.delete("/users/{uid}/addresses/{aid}")
def del_address(uid: int, aid: int):
    with db.pool.connection() as c:
        c.execute("DELETE FROM addresses WHERE id = %s AND user_id = %s", (aid, uid))
    return {"deleted": aid}
