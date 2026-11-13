from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
app = FastAPI(title="auth-service")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])
class LoginReq(BaseModel):
    email: str
    password: str
    role: str = "user"
@app.get("/health")
def health():
    return {"service":"auth-service","status":"running"}
@app.post("/auth/login")
def login(req: LoginReq):
    # Mock login — test user: promise@example.com / 1234
    if req.email=="promise@example.com" and req.password=="1234":
        return {"token":"mock-jwt-token-123","user_id":1,"role":req.role,"email":req.email}
    return {"detail":"Invalid login"}
@app.post("/auth/register")
def register(req: LoginReq):
    return {"user_id":2,"email":req.email,"role":req.role,"status":"REGISTERED"}
