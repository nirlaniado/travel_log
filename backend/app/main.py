from fastapi import Depends, FastAPI, Response, status
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import text
from sqlalchemy.orm import Session

from .config import get_settings
from .database import get_db
from .routers import auth, notes, places

app = FastAPI(title="Travel Logs API", version="1.0.0")


class ApiPrefixMiddleware:
    """Strip a leading /api so the same image works behind proxies that can't
    rewrite paths (AWS ALB). Proxies that do strip it (nginx ingress, Caddy)
    are unaffected — the prefix simply never appears here."""

    def __init__(self, app, prefix: str = "/api"):
        self.app = app
        self.prefix = prefix

    async def __call__(self, scope, receive, send):
        if scope["type"] == "http":
            path = scope.get("path", "")
            if path == self.prefix or path.startswith(self.prefix + "/"):
                scope = dict(scope)
                scope["path"] = path[len(self.prefix):] or "/"
                raw_path = scope.get("raw_path")
                if raw_path is not None:
                    scope["raw_path"] = raw_path[len(self.prefix):] or b"/"
        await self.app(scope, receive, send)


app.add_middleware(ApiPrefixMiddleware)

# CSRF strategy: the session cookie is SameSite=Lax, and CORS only allows
# the configured frontend origins with credentials. State-changing routes
# are JSON POST/PUT/DELETE, which cross-site forms cannot produce.
app.add_middleware(
    CORSMiddleware,
    allow_origins=get_settings().cors_origin_list,
    allow_credentials=True,
    allow_methods=["GET", "POST", "PUT", "DELETE"],
    allow_headers=["Content-Type"],
)

app.include_router(auth.router)
app.include_router(places.router)
app.include_router(notes.router)


@app.get("/health", tags=["health"])
def health(response: Response, db: Session = Depends(get_db)):
    try:
        db.execute(text("SELECT 1"))
    except Exception:
        response.status_code = status.HTTP_503_SERVICE_UNAVAILABLE
        return {"status": "degraded", "db": "error"}
    return {"status": "ok", "db": "ok"}
