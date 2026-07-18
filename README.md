# katagami（型紙）

SaaS 開発の規律を機械検証で守る「縦串」テンプレートリファレンス。

型紙 = 1 枚の型から各自のプロダクトを仕立てるための下敷き。特定ドメインの学習用リポジトリではなく、
横断規律（環境変数管理・エラー契約・型契約・品質ゲート等）を CI で機械検証する仕組みそのものを提供する。

## 現在地

骨格フェーズ: flake.nix（Nix devshell / uv2nix）+ Makefile + CI + 空アプリ（FastAPI / React）で `make ci` が green。
縦串は今後、依存順に 1 本 = 1 PR で積み上げる。

## 構成

| パス | 内容 |
| --- | --- |
| `flake.nix` | 開発環境の SSoT。backend Python 依存は uv2nix、web node_modules は importNpmLock で Nix build（.venv / npm install 不要） |
| `backend/` | FastAPI アプリ。依存の正本は `pyproject.toml` + `uv.lock`（全依存 `==` 固定） |
| `web/` | React + Vite + TypeScript アプリ。依存の正本は `package.json` + `package-lock.json`（更新は `make lock-web`） |
| `Makefile` | タスクランナー。`make help` で一覧 |
| `.github/workflows/ci.yml` | CI（lint + typecheck + test + build） |

## クイックスタート

```bash
# 前提: Nix（flakes 有効）
nix develop        # 開発環境に入る
make setup         # 初回セットアップ
make ci            # lint + test + build を一括実行（CI 相当）
```
