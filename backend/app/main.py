import logging
import os

from fastapi import FastAPI, HTTPException, Request
from fastapi.exceptions import RequestValidationError
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse

from app.core import env_keys
from app.core.errors import (
    ErrorCode,
    build_app_error_response,
    generate_error_id,
    normalize_http_exception_detail,
)
from app.routers import notes, tasks
from app.schemas.health import HealthResponse

logger = logging.getLogger(__name__)

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


# --- エラー契約（AppErrorResponse への正規化） ---
# すべてのエラー応答を code / message / action / error_id の共通形に揃える。
# コード集合は FE（web/src/constants/errorCodes.ts）と lint で同期される。


@app.exception_handler(RequestValidationError)
async def _validation_exception_handler(request: Request, exc: RequestValidationError):
    error_id = generate_error_id()
    logger.warning(
        "リクエストバリデーションエラー",
        extra={"http_status": 422, "error_id": error_id, "status": "failed"},
    )
    return JSONResponse(
        status_code=422,
        content=build_app_error_response(
            code=ErrorCode.VALIDATION_ERROR,
            message="入力内容が正しくありません。",
            action="入力内容を見直して再試行してください",
            error_id=error_id,
        ).model_dump(exclude_none=True),
    )


@app.exception_handler(HTTPException)
async def _http_exception_handler(request: Request, exc: HTTPException):
    error_id = generate_error_id()
    payload = normalize_http_exception_detail(
        status_code=exc.status_code,
        detail=exc.detail,
        error_id=error_id,
    )
    log_level = logging.WARNING if exc.status_code < 500 else logging.ERROR
    logger.log(
        log_level,
        "HTTPエラー応答",
        extra={"http_status": exc.status_code, "error_id": payload.error_id, "status": "failed"},
    )
    return JSONResponse(
        status_code=exc.status_code,
        content=payload.model_dump(exclude_none=True),
        headers=exc.headers,
    )


@app.exception_handler(Exception)
async def _unhandled_exception_handler(request: Request, exc: Exception):
    error_id = generate_error_id()
    logger.exception(
        "未処理例外",
        extra={"http_status": 500, "error_id": error_id, "status": "failed"},
    )
    return JSONResponse(
        status_code=500,
        content=build_app_error_response(
            code=ErrorCode.INTERNAL_ERROR,
            message="予期しないエラーが発生しました。",
            action="ページを再読み込みして、解消しない場合は時間を置いて再試行してください",
            error_id=error_id,
        ).model_dump(exclude_none=True),
    )


app.include_router(notes.router)
app.include_router(tasks.router)


@app.get("/health")
def health() -> HealthResponse:
    return HealthResponse(status="ok", version=os.getenv(env_keys.APP_VERSION, "dev"))
