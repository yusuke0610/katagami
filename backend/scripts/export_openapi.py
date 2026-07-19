"""FastAPI アプリの OpenAPI スキーマを JSON にダンプするスクリプト。

web の型生成（``openapi-typescript``）の入力となる ``backend/openapi.json`` を出力する。
通常は ``make codegen-types``（Nix devshell 経由）から呼び出される。

出力先はデフォルトで ``backend/openapi.json``。第 1 引数で変更可能。

注意:
- ``app.main`` を import するだけで FastAPI app は構築される（サーバーは起動しない）。
- diff の安定化のため ``sort_keys=True`` で出力する（openapi-typescript はキー順に依存しない）。
"""

import json
import sys
from pathlib import Path

# scripts/ から見たプロジェクトルート（backend/）配下に openapi.json を出力する。
# `app` パッケージ解決を cwd に依存させないため、app の import より前に path を通す。
_BACKEND_DIR = Path(__file__).resolve().parent.parent
_DEFAULT_OUTPUT = _BACKEND_DIR / "openapi.json"
sys.path.insert(0, str(_BACKEND_DIR))


def main() -> None:
    from app.main import app

    output_path = Path(sys.argv[1]) if len(sys.argv) > 1 else _DEFAULT_OUTPUT
    schema = app.openapi()
    # 末尾に改行を付け、エディタ・lint と整合させる。
    output_path.write_text(
        json.dumps(schema, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(f"OpenAPI スキーマを書き出しました: {output_path}")


if __name__ == "__main__":
    main()
