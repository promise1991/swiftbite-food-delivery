# SwiftBite Restaurant-service
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
app = FastAPI(title="restaurant-service")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])
RESTAURANTS = [
  {"id":1,"name":"Mama Put Place","rating":4.8,"delivery_time":"25-35 mins","fee":1000,"image":"mama-put.jpg"},
  {"id":2,"name":"Shawarma King","rating":4.7,"delivery_time":"20-30 mins","fee":1200,"image":"shawarma.jpg"},
  {"id":3,"name":"Pizza Hub","rating":4.6,"delivery_time":"30-40 mins","fee":1500,"image":"pizza.jpg"},
]
@app.get("/health")
def health():
    return {"service":"restaurant-service","status":"running"}
@app.get("/restaurants")
def list_restaurants():
    return {"service":"restaurant-service","data":RESTAURANTS,"count":len(RESTAURANTS)}
@app.get("/restaurants/{rid}")
def get_one(rid: int):
    for r in RESTAURANTS:
        if r["id"] == rid:
            return r
    return {"detail":"Restaurant not found"}
