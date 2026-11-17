from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field
app = FastAPI(title="review-service")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])
REVIEWS: list = []

class Review(BaseModel):
    target_type: str            # "restaurant" or "rider"
    target_id: int
    user_id: int = 1
    order_id: int | None = None
    rating: int = Field(ge=1, le=5)
    comment: str = ""

@app.get("/health")
def health(): return {"service": "review-service", "status": "running"}
@app.get("/ready")
def ready(): return {"ready": True}
@app.post("/reviews")
def create(r: Review):
    if r.target_type not in ("restaurant", "rider"):
        raise HTTPException(400, "target_type must be restaurant or rider")
    row = {"id": len(REVIEWS) + 1, **r.model_dump()}
    REVIEWS.append(row); return row
@app.get("/reviews/{target_type}/{target_id}")
def list_for(target_type: str, target_id: int):
    rows = [r for r in REVIEWS if r["target_type"] == target_type and r["target_id"] == target_id]
    avg = round(sum(r["rating"] for r in rows) / len(rows), 1) if rows else None
    return {"target_type": target_type, "target_id": target_id, "average": avg, "count": len(rows), "reviews": rows}
