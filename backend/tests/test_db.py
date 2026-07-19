"""DB 基盤（セッション / マイグレーション機構）のテスト。"""

import os
import subprocess
import sys
import tempfile
from pathlib import Path

from app.core import env_keys
from app.db import get_db
from sqlalchemy import text

_BACKEND_DIR = Path(__file__).resolve().parent.parent


def test_get_db_yields_working_session() -> None:
    """get_db が動作するセッションを提供し、終了時にクローズする。"""
    generator = get_db()
    session = next(generator)
    try:
        assert session.execute(text("SELECT 1")).scalar() == 1
    finally:
        generator.close()


def test_alembic_upgrade_head_applies_baseline() -> None:
    """alembic upgrade head が DATABASE_URL の DB に適用できる（env.py の配線検証）。"""
    with tempfile.TemporaryDirectory(prefix="katagami-alembic-") as tmp_dir:
        db_path = Path(tmp_dir) / "migrate.db"
        env = {**os.environ, env_keys.DATABASE_URL: f"sqlite:///{db_path}"}
        result = subprocess.run(
            [sys.executable, "-m", "alembic", "upgrade", "head"],
            cwd=_BACKEND_DIR,
            env=env,
            capture_output=True,
            text=True,
        )
        assert result.returncode == 0, result.stderr

        # 適用済みリビジョンが baseline であることを実 DB で確認する
        from sqlalchemy import create_engine

        engine = create_engine(f"sqlite:///{db_path}")
        with engine.connect() as connection:
            version = connection.execute(text("SELECT version_num FROM alembic_version")).scalar()
        assert version == "0001_baseline"
