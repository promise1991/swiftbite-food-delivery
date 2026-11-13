# SwiftBite Delivery-service
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
app = FastAPI(title="delivery-service")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])
RIDERS = [
  {"id":1,"name":"Tunde","vehicle":"Bajaj","phone":"0803-111-2222","status":"AVAILABLE"},
  {"id":2,"name":"Ada","vehicle":"Keke","phone":"0803-333-4444","status":"AVAILABLE"},
]
deliveries = {}
class AssignReq(BaseModel):
    order_id: int
    rider_id: int
class LocationReq(BaseModel):
    order_id: int
    lat: float
    lng: float
@app.get("/health")
def health():
    return {"service":"delivery-service","status":"running"}
@app.get("/riders")
def list_riders():
    return {"service":"delivery-service","data":RIDERS}
@app.post("/delivery/assign")
def assign(req: AssignReq):
    deliveries[req.order_id] = {"order_id":req.order_id,"rider_id":req.rider_id,"status":"ASSIGNED","lat":6.5244,"lng":3.3792}
    return deliveries[req.order_id]
@app.post("/delivery/location")
def update_location(req: LocationReq):
    if req.order_id in deliveries:
        deliveries[req.order_id]["lat"] = req.lat
        deliveries[req.order_id]["lng"] = req.lng
        deliveries[req.order_id]["status"] = "ON_THE_WAY"
        return deliveries[req.order_id]
    return {"detail":"Delivery not found"}
@app.post("/delivery/{order_id}/picked")
def picked(order_id: int):
    if order_id in deliveries:
        deliveries[order_id]["status"] = "PICKED_UP"
        return deliveries[order_id]
    return {"detail":"Delivery not found"}
@app.post("/delivery/{order_id}/delivered")
def delivered(order_id: int):
    if order_id in deliveries:
        deliveries[order_id]["status"] = "DELIVERED"
        return deliveries[order_id]
    return {"detail":"Delivery not found"}
@app.get("/delivery/{order_id}")
def get_delivery(order_id: int):
    return deliveries.get(order_id, {"detail":"Delivery not found"})
