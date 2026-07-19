"""エラー契約（AppErrorResponse への正規化）のテスト。

テスト専用のルートを app に追加し、例外ハンドラが共通形
（code / message / action / error_id）へ正規化することを検証する。
"""

from app.core.errors import ErrorCode, raise_app_error
from app.main import app
from fastapi import APIRouter
from fastapi.testclient import TestClient

_router = APIRouter()


@_router.get("/_test/app-error")
def _app_error() -> None:
    raise_app_error(
        status_code=404,
        code=ErrorCode.VALIDATION_ERROR,
        message="対象が見つかりません。",
        action="ID を確認してください",
    )


@_router.get("/_test/unhandled")
def _unhandled() -> None:
    raise RuntimeError("boom")


@_router.get("/_test/validated")
def _validated(count: int) -> dict[str, int]:
    return {"count": count}


app.include_router(_router)

client = TestClient(app, raise_server_exceptions=False)


def test_raise_app_error_returns_contract_shape() -> None:
    response = client.get("/_test/app-error")
    assert response.status_code == 404
    body = response.json()
    assert body["code"] == "VALIDATION_ERROR"
    assert body["message"] == "対象が見つかりません。"
    assert body["action"] == "ID を確認してください"
    assert len(body["error_id"]) == 12


def test_validation_error_is_normalized() -> None:
    response = client.get("/_test/validated", params={"count": "not-a-number"})
    assert response.status_code == 422
    body = response.json()
    assert body["code"] == "VALIDATION_ERROR"
    assert body["message"] == "入力内容が正しくありません。"
    assert "error_id" in body


def test_unhandled_exception_is_normalized_to_internal_error() -> None:
    response = client.get("/_test/unhandled")
    assert response.status_code == 500
    body = response.json()
    assert body["code"] == "INTERNAL_ERROR"
    assert body["message"] == "予期しないエラーが発生しました。"
    assert "error_id" in body
