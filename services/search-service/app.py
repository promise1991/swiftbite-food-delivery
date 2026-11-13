from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
app = FastAPI(title="search-service")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])
DATA=[{"type":"restaurant","name":"Mama Put Place"},{"type":"food","name":"Jollof Rice"},{"type":"food","name":"Shawarma"},{"type":"restaurant","name":"Pizza Hub"}]
@app.get("/health")
def health():
    return {"service":"search-service","status":"running"}
@app.get("/search")
def search(q: str=""):
    res=[x for x in DATA if q.lower() in x["name"].lower()]
    return {"service":"search-service","query":q,"data":res,"count":len(res)}
