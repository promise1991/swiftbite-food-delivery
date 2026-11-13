from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import requests
app = FastAPI(title="api-gateway")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])
ROUTES={"restaurants":"http://localhost:8007/restaurants","menu":"http://localhost:8009/menu","order":"http://localhost:8005/order","payment":"http://localhost:8006/payment","delivery":"http://localhost:8012/delivery","auth":"http://localhost:8001/auth","users":"http://localhost:8002/users","search":"http://localhost:8008/search"}
@app.get("/health")
def health():
    return {"service":"api-gateway","status":"running"}
@app.get("/")
def root():
    return {"service":"api-gateway","routes":list(ROUTES.keys())}
