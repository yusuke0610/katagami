from enum import Enum
from typing import Any, NoReturn
from uuid import uuid4

from fastapi import HTTPException
from pydantic import BaseModel, ConfigDict


class ErrorCode(str, Enum):
    """API エラーレスポンスの共通エラーコード。

    本 enum は FE 側の ``web/src/constants/errorCodes.ts:ERROR_CODES`` および
    ``web/src/constants/errorMessages.ts:ERROR_CONFIG`` のキー集合と一致させること。
    片方だけ変更すると FE 側で ``INTERNAL_ERROR`` にサイレント fallback して
    適切なメッセージと recovery action が表示されなくなる。

    新しいコードを追加する手順:
      1. 本 enum に値を追加
      2. ``web/src/constants/errorCodes.ts:ERROR_CODES`` に文字列を追加
      3. ``web/src/constants/errorMessages.ts:ERROR_CONFIG`` にメッセージと recovery を追加

    本 enum と ``ERROR_CODES`` の集合一致は ``scripts/lint-env-keys.sh``
    （``make lint-env-keys`` / CI）で機械検証する。
    FE 側の型縛りは FE 内で完結し BE 起点の追加漏れを拾えないため、それを補う。
    """

    # バリデーション
    VALIDATION_ERROR = "VALIDATION_ERROR"
    # サーバー
    INTERNAL_ERROR = "INTERNAL_ERROR"


class AppErrorResponse(BaseModel):
    """API エラーレスポンスの共通形。すべてのエラーはこの形で返す。"""

    code: ErrorCode
    message: str
    action: str | None = None
    retry_after: int | None = None
    error_id: str | None = None

    model_config = ConfigDict(use_enum_values=True)


def generate_error_id() -> str:
    """ログと突合しやすい短いエラー ID を生成する。"""
    return uuid4().hex[:12]


def build_app_error_response(
    *,
    code: ErrorCode,
    message: str,
    action: str | None = None,
    retry_after: int | None = None,
    error_id: str | None = None,
) -> AppErrorResponse:
    return AppErrorResponse(
        code=code,
        message=message,
        action=action,
        retry_after=retry_after,
        error_id=error_id,
    )


def raise_app_error(
    *,
    status_code: int,
    code: ErrorCode,
    message: str,
    action: str | None = None,
    retry_after: int | None = None,
    headers: dict[str, str] | None = None,
) -> NoReturn:
    """エラー契約（AppErrorResponse）に沿った HTTPException を送出する。

    ルーター / サービス層はエラー時に必ず本関数（または HTTPException +
    AppErrorResponse 形の detail）を使い、素の文字列 detail を増やさない。
    """
    raise HTTPException(
        status_code=status_code,
        detail=build_app_error_response(
            code=code,
            message=message,
            action=action,
            retry_after=retry_after,
        ).model_dump(exclude_none=True),
        headers=headers,
    )


def infer_error_code(status_code: int, detail: Any = None) -> ErrorCode:
    """既存の文字列 detail からも可能な範囲でエラーコードを推定する。"""
    if isinstance(detail, dict) and isinstance(detail.get("code"), str):
        try:
            return ErrorCode(detail["code"])
        except ValueError:
            pass

    if status_code in (400, 404, 409, 422):
        return ErrorCode.VALIDATION_ERROR
    return ErrorCode.INTERNAL_ERROR


def normalize_http_exception_detail(
    *,
    status_code: int,
    detail: Any,
    error_id: str,
) -> AppErrorResponse:
    """FastAPI の既存 HTTPException を AppErrorResponse に正規化する。"""
    if isinstance(detail, dict) and isinstance(detail.get("code"), str) and isinstance(
        detail.get("message"), str
    ):
        payload = {**detail, "error_id": detail.get("error_id") or error_id}
        return AppErrorResponse.model_validate(payload)

    if isinstance(detail, str):
        message = detail
    elif detail is None:
        message = "予期しないエラーが発生しました。"
    else:
        message = str(detail)

    return build_app_error_response(
        code=infer_error_code(status_code, detail),
        message=message,
        error_id=error_id,
    )
