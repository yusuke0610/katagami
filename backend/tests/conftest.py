"""テスト共通設定。

アプリケーション import より前に環境変数を確定する。
app.db.database は import 時に DATABASE_URL を評価するため、
テスト用の一時 SQLite を先に必ず設定しておく。
"""

import os
import tempfile

from app.core import env_keys

_TEST_DB_DIR = tempfile.mkdtemp(prefix="katagami-test-db-")
os.environ.setdefault(env_keys.DATABASE_URL, f"sqlite:///{_TEST_DB_DIR}/test.db")

# テスト用テーブルを作成する（スキーマの正本は alembic だが、テストでは create_all 可）
from app import models  # noqa: E402, F401
from app.db import Base, engine  # noqa: E402

Base.metadata.create_all(bind=engine)
