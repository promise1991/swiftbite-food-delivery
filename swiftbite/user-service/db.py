import os
from psycopg.rows import dict_row
from psycopg_pool import ConnectionPool

# DATABASE_URL comes from the db-credentials Secret (one database + role per service)
pool = ConnectionPool(os.environ.get("DATABASE_URL", ""), min_size=1, max_size=5, open=False,
                      kwargs={"row_factory": dict_row})

def start(): pool.open(wait=True, timeout=60)
def stop(): pool.close()

def check_ready():
    from fastapi import HTTPException
    try:
        with pool.connection() as c: c.execute("SELECT 1")
    except Exception:
        raise HTTPException(503, "database unavailable")
    return {"ready": True}
