import os

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.core import env_keys

app = FastAPI(title="katagami")

# CORS 許可オリジン（カンマ区切り）。env 名は env_keys が正本
_cors_origins = [
    origin.strip()
    for origin in os.getenv(env_keys.CORS_ORIGINS, "http://localhost:5173").split(",")
    if origin.strip()
]
app.add_middleware(
    CORSMiddleware,
    allow_origins=_cors_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok", "version": os.getenv(env_keys.APP_VERSION, "dev")}
