import hashlib, hmac, os
import psycopg
from contextlib import asynccontextmanager
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import db

@asynccontextmanager
async def lifespan(app):
    db.start(); yield; db.stop()

app = FastAPI(title="auth-service", lifespan=lifespan)
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])

class LoginReq(BaseModel):
    email: str
    password: str
    role: str = "user"

def hash_pw(pw: str, salt: str | None = None) -> str:
    salt = salt or os.urandom(8).hex()
    return f"{salt}${hashlib.pbkdf2_hmac('sha256', pw.encode(), salt.encode(), 100_000).hex()}"

def verify(pw: str, stored: str) -> bool:
    return hmac.compare_digest(hash_pw(pw, stored.split("$")[0]), stored)

@app.get("/health")
def health(): return {"service": "auth-service", "status": "running"}
@app.get("/ready")
def ready(): return db.check_ready()

@app.post("/auth/login")
def login(req: LoginReq):
    with db.pool.connection() as c:
        u = c.execute("SELECT id, password_hash FROM users WHERE email = %s", (req.email,)).fetchone()
    if u and verify(req.password, u["password_hash"]):
        return {"token": f"mock-jwt-token-{u['id']}", "user_id": u["id"], "role": req.role, "email": req.email}
    return {"detail": "Invalid login"}

@app.post("/auth/register")
def register(req: LoginReq):
    try:
        with db.pool.connection() as c:
            row = c.execute("INSERT INTO users (email, password_hash) VALUES (%s, %s) RETURNING id",
                            (req.email, hash_pw(req.password))).fetchone()
    except psycopg.errors.UniqueViolation:
        return {"detail": "Email already registered"}
    return {"user_id": row["id"], "email": req.email, "role": req.role, "status": "REGISTERED"}
