from app.main import app
from fastapi.testclient import TestClient

client = TestClient(app)


def test_health_returns_ok() -> None:
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok", "version": "dev"}


def test_health_allows_cors_origin() -> None:
    """既定の CORS 許可オリジンからのリクエストに CORS ヘッダが付与される。"""
    response = client.get("/health", headers={"Origin": "http://localhost:5173"})
    assert response.status_code == 200
    assert response.headers["access-control-allow-origin"] == "http://localhost:5173"


def test_health_rejects_unknown_cors_origin() -> None:
    """許可外オリジンには CORS ヘッダを返さない（ブラウザ側でブロックされる）。"""
    response = client.get("/health", headers={"Origin": "https://evil.example.com"})
    assert response.status_code == 200
    assert "access-control-allow-origin" not in response.headers
