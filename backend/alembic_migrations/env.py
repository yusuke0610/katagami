import os
from logging.config import fileConfig

from alembic import context

# モデルのメタデータを登録するため import が必要
from app import models  # noqa: F401
from app.core import env_keys
from app.db import Base
from sqlalchemy import create_engine, pool

config = context.config

if config.config_file_name is not None:
    fileConfig(config.config_file_name)

target_metadata = Base.metadata


def _database_url() -> str:
    """接続 URL を DATABASE_URL から構築する（既定は app.db.database と同じ SQLite）。"""
    return os.getenv(env_keys.DATABASE_URL, "sqlite:///./katagami.db")


def run_migrations_offline() -> None:
    """オフラインモード（DB 接続なし）でマイグレーション SQL を生成する。"""
    context.configure(
        url=_database_url(),
        target_metadata=target_metadata,
        literal_binds=True,
        dialect_opts={"paramstyle": "named"},
    )

    with context.begin_transaction():
        context.run_migrations()


def run_migrations_online() -> None:
    """オンラインモードで DATABASE_URL に接続してマイグレーションを実行する。"""
    connectable = create_engine(_database_url(), poolclass=pool.NullPool)

    with connectable.connect() as connection:
        context.configure(connection=connection, target_metadata=target_metadata)

        with context.begin_transaction():
            context.run_migrations()


if context.is_offline_mode():
    run_migrations_offline()
else:
    run_migrations_online()
