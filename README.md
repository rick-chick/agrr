# AGRR - 農業計画支援システム

Angular SPA + **agrr-server**（Rust API / WebSocket / OAuth）+ SQLite（Litestream）— 本番は Google Cloud Run。

本番 API は **Rust のみ**（P7 完了）。リポジトリには開発・テスト用の **Rails シェル**が残っている（削除計画: [`docs/migration/app-rust-stack/P8-RAILS-SHELL-REMOVAL.md`](docs/migration/app-rust-stack/P8-RAILS-SHELL-REMOVAL.md)）。

## 🚀 クイックスタート（推奨: Rust 開発スタック）

### 初回セットアップ

```bash
chmod +x scripts/*.sh

# DB（refinery + 参照マスタ）
./scripts/load-development-reference-data.sh

# ターミナル 1: agrr デーモン + agrr-server + nginx (:3000)
./scripts/dev-rust-stack.sh

# ターミナル 2: Angular
cd frontend && ng serve --host 127.0.0.1
```

- API / `/cable` / `/auth`: http://127.0.0.1:3000（ng serve :4200 から向く）
- 停止: `./scripts/dev-rust-stack.sh stop`
- 本番切替・P7 状態: [`docs/migration/app-rust-stack/PRODUCTION-CUTOVER-STATUS.md`](docs/migration/app-rust-stack/PRODUCTION-CUTOVER-STATUS.md)

### 新規計画作成（AGRR デーモン）

最適化には `lib/core/agrr` デーモンが必要。

- `dev-rust-stack.sh` 起動時にソケットが無ければデーモンを自動起動する
- バイナリ未ビルド時: `cd lib/core/agrr_core && ./build_standalone.sh --onefile && cp dist/agrr ../agrr`

### レガシー: Docker Compose（Rails シェル）

```bash
docker compose up   # :3000 で rails server（SPA フォールバック・auth_test 等）
```

P8 で既定を Rust に寄せる予定。新規開発は上記 **dev-rust-stack** を使う。

---

## 🧪 テスト

**必ず test-common / 専用スクリプト経由**。生 `rails test` は開発 DB 破壊防止のため `test/test_helper.rb` で拒否される。

```bash
./bin/test                                                    # 全体（Rails 残存 + cargo + R4 rust）
.cursor/skills/test-common/scripts/run-test-rails.sh          # Rails シェル回帰のみ
.cursor/skills/test-common/scripts/run-test-rust-domain.sh    # agrr-domain
scripts/run-rust-contract-tests.sh                            # R4 契約（本番経路の正）
.cursor/skills/test-common/scripts/run-test-frontend.sh       # Angular
```

詳細: [.cursor/skills/test-common/SKILL.md](.cursor/skills/test-common/SKILL.md)、[`.cursor/rules/rails-testing-workflow.mdc`](.cursor/rules/rails-testing-workflow.mdc)。

---

## 📚 主要ドキュメント

| ドキュメント | 用途 |
|------------|------|
| [ARCHITECTURE.md](ARCHITECTURE.md) | レイヤ規約（Rust 正・Rails は dev シェル） |
| [CLAUDE.md](CLAUDE.md) | エージェント向け要約 |
| [docs/migration/app-rust-stack/](docs/migration/app-rust-stack/) | P6–P8 移行 |
| [docs/README.md](docs/README.md) | 補助 doc 索引 |

---

## 🌐 本番環境

- **URL**: https://agrr.net
- **API/WS**: Cloud Run `agrr-server`（`Dockerfile.agrr-server`）
- **SPA**: GCS + Cloud CDN
- **DB**: SQLite + Litestream → GCS

### デプロイ

```bash
.cursor/skills/deploy-server/scripts/gcp-deploy.sh
.cursor/skills/deploy-frontend/scripts/gcp-frontend-deploy.sh deploy production
```

---

## 🛠 技術スタック

| カテゴリ | 技術 |
|---------|------|
| バックエンド（本番） | **agrr-server**（Rust / Axum）、`agrr-domain`、`agrr-migrate`（refinery） |
| フロント | Angular 21（`frontend/`） |
| フロント配信 | GCS + Cloud CDN |
| DB | SQLite（primary / cache）、Litestream → GCS |
| 最適化・気象 | agrr Python バイナリ / デーモン（`lib/core/agrr`） |
| 開発シェル（縮小中） | Rails 8 — SPA フォールバック・契約テスト用 AR・`auth_test` のみ |

---

**最終更新**: 2026-06-01
