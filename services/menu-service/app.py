# SwiftBite Menu-service
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
app = FastAPI(title="menu-service")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])
MENUS = {
  1: [
    {"id":101,"name":"Jollof Rice","price":5000,"desc":"Smoky party jollof + chicken"},
    {"id":102,"name":"Fried Rice","price":5500,"desc":"Fried rice + turkey"},
  ],
  2: [
    {"id":201,"name":"Shawarma","price":7000,"desc":"Chicken shawarma + extra sauce"},
    {"id":202,"name":"Shawarma Platter","price":12000,"desc":"Double meat + fries"},
  ],
  3: [
    {"id":301,"name":"Pizza Pepperoni","price":12000,"desc":"Large pepperoni pizza"},
    {"id":302,"name":"Pizza Chicken","price":13000,"desc":"Large chicken pizza"},
  ],
}
@app.get("/health")
def health():
    return {"service":"menu-service","status":"running"}
@app.get("/menu/{restaurant_id}")
def get_menu(restaurant_id: int):
    return {"service":"menu-service","restaurant_id":restaurant_id,"data":MENUS.get(restaurant_id,[])}
