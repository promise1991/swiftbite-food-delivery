from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
app = FastAPI(title="user-service")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])
@app.get("/health")
def health():
    return {"service":"user-service","status":"running"}
@app.get("/users/1")
def get_user():
    return {"id":1,"name":"Promise Opah","email":"promise@example.com","address":"2 Matthew Ojo Street","phone":"0803-111-2222"}
