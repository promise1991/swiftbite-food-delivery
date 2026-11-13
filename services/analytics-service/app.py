from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
app = FastAPI(title="analytics-service")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])
@app.get("/health")
def health():
    return {"service":"analytics-service","status":"running"}
@app.get("/analytics/summary")
def summary():
    return {"service":"analytics-service","orders_today":12,"revenue_today":145000,"top_food":"Shawarma","active_riders":2}
