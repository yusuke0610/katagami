"""ORM モデルパッケージ。

新しいモデルモジュールを追加したら本ファイルで import すること。
alembic（alembic_migrations/env.py）は本パッケージを import して
Base.metadata にテーブルを登録し、autogenerate の対象にする。
"""

from app.models.note import Note
from app.models.task import AsyncTask

__all__ = ["AsyncTask", "Note"]
