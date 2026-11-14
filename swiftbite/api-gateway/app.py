import json, os
import httpx
from fastapi import FastAPI, Request, Response
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
app = FastAPI(title="api-gateway")
app.add_middleware(CORSMiddleware, allow_origins=["*"], allow_methods=["*"], allow_headers=["*"])
DEFAULT = {
 "auth": "http://auth-service:8001/auth", "users": "http://user-service:8002/users",
 "cart": "http://cart-service:8003/cart", "order": "http://order-service:8005/order",
 "payment": "http://payment-service:8006/payment", "restaurants": "http://restaurant-service:8007/restaurants",
 "search": "http://search-service:8008/search", "menu": "http://menu-service:8009/menu",
 "reviews": "http://review-service:8010/reviews", "notifications": "http://notification-service:8011/notifications",
 "delivery": "http://delivery-service:8012/delivery", "analytics": "http://analytics-service:8013/analytics"}
ROUTES = json.loads(os.getenv("ROUTES_JSON", "null")) or DEFAULT   # override all routes from a Helm ConfigMap
client = httpx.AsyncClient(timeout=10)
SKIP = {"host", "content-length", "connection", "transfer-encoding", "accept-encoding"}

@app.get("/health")
def health(): return {"service": "api-gateway", "status": "running", "routes": list(ROUTES)}
@app.get("/ready")
def ready(): return {"ready": True}

@app.api_route("/{name}", methods=["GET", "POST", "PUT", "PATCH", "DELETE"])
@app.api_route("/{name}/{path:path}", methods=["GET", "POST", "PUT", "PATCH", "DELETE"])
async def proxy(request: Request, name: str, path: str = ""):
    base = ROUTES.get(name)
    if not base: return JSONResponse({"detail": f"unknown route '{name}'"}, 404)
    url = base + ("/" + path if path else "")
    try:
        r = await client.request(request.method, url, params=request.query_params, content=await request.body(),
                                 headers={k: v for k, v in request.headers.items() if k.lower() not in SKIP})
    except httpx.HTTPError:
        return JSONResponse({"detail": f"{name} service unavailable"}, 502)
    return Response(r.content, r.status_code, media_type=r.headers.get("content-type"))
