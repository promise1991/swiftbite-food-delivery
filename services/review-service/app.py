from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
app = FastAPI(title="review-service")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])
reviews=[]
class Rev(BaseModel):
    restaurant_id: int
    rating: int
    comment: str
@app.get("/health")
def health():
    return {"service":"review-service","status":"running"}
@app.post("/reviews")
def add(r: Rev):
    reviews.append(r.dict())
    return {"status":"REVIEW_ADDED","data":r.dict()}
@app.get("/reviews")
def list_rev():
    return {"service":"review-service","data":reviews,"count":len(reviews)}
