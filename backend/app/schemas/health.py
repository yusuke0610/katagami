from pydantic import BaseModel


class HealthResponse(BaseModel):
    """ヘルスチェック応答。

    schemas/ 配下の Pydantic モデルは OpenAPI スキーマとして書き出され、
    web の型（src/api/generated.ts）の正本になる。フィールドを変更したら
    `make codegen-types` で再生成してコミットすること（CI の codegen-drift が検証）。
    """

    status: str
    version: str
