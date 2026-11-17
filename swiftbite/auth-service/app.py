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
