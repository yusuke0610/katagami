"""baseline（空のマイグレーション基点）

Revision ID: 0001_baseline
Revises:
Create Date: 2026-07-19

スキーマ変更を伴わない基点リビジョン。マイグレーション機構
（alembic_version テーブルの作成・upgrade/downgrade の実行経路）を
モデル導入前に検証可能にする。
"""

from typing import Sequence, Union

# revision identifiers, used by Alembic.
revision: str = "0001_baseline"
down_revision: Union[str, None] = None
branch_labels: Union[str, Sequence[str], None] = None
depends_on: Union[str, Sequence[str], None] = None


def upgrade() -> None:
    pass


def downgrade() -> None:
    pass
