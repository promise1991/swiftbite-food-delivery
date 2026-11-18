from pydantic import Field
from contextlib import asynccontextmanager
from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
import db

@asynccontextmanager
async def lifespan(app):
    db.start(); yield; db.stop()

app = FastAPI(title="review-service", lifespan=lifespan)
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])
COLS = "id, target_type, target_id, user_id, order_id, rating, comment"

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
def ready(): return db.check_ready()

@app.post("/reviews")
def create(r: Review):
    if r.target_type not in ("restaurant", "rider"):
        raise HTTPException(400, "target_type must be restaurant or rider")
    with db.pool.connection() as c:
        return c.execute(f"INSERT INTO reviews (target_type, target_id, user_id, order_id, rating, comment) "
                         f"VALUES (%s, %s, %s, %s, %s, %s) RETURNING {COLS}",
                         (r.target_type, r.target_id, r.user_id, r.order_id, r.rating, r.comment)).fetchone()

@app.get("/reviews/{target_type}/{target_id}")
def list_for(target_type: str, target_id: int):
    with db.pool.connection() as c:
        rows = c.execute(f"SELECT {COLS} FROM reviews WHERE target_type = %s AND target_id = %s ORDER BY id DESC",
                         (target_type, target_id)).fetchall()
    avg = round(sum(r["rating"] for r in rows) / len(rows), 1) if rows else None
    return {"target_type": target_type, "target_id": target_id, "average": avg, "count": len(rows), "reviews": rows}
