import os
from collections.abc import Generator

from sqlalchemy import create_engine
from sqlalchemy.orm import Session, declarative_base, sessionmaker

from app.core import env_keys

# 接続 URL は env（DATABASE_URL）で注入する。既定はローカルの SQLite ファイル。
# 別 RDBMS / マネージド DB（libSQL / PostgreSQL 等）へ差し替える場合はここを起点に
# パラメータ化する（URL 形式と engine オプションのみが差分になるように保つ）。
_db_url = os.getenv(env_keys.DATABASE_URL, "sqlite:///./katagami.db")

# SQLite はスレッド跨ぎの接続共有を既定で禁止するが、FastAPI は複数スレッドから
# セッションを使うため無効化する（SQLite ドライバ固有の引数）
_connect_args = {"check_same_thread": False} if _db_url.startswith("sqlite") else {}

engine = create_engine(
    _db_url,
    connect_args=_connect_args,
    pool_pre_ping=True,
)

SessionLocal = sessionmaker(
    autocommit=False,
    autoflush=False,
    bind=engine,
)

# ORM モデルの基底クラス。スキーマの正本は alembic のマイグレーション
# （本番経路で Base.metadata.create_all は使わない）
Base = declarative_base()


def get_db() -> Generator[Session, None, None]:
    """リクエストスコープの DB セッションを提供する FastAPI dependency。"""
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
