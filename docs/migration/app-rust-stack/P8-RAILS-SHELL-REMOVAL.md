# P8 — リポジトリからの Rails シェル削除

> **P7 との違い**: P7 は「本番で Rails API に依存しない」ことの完了（2026-05-31）。P8 は **リポジトリと開発体験**から Rails を外す。

**本番の正**: [`PRODUCTION-CUTOVER-STATUS.md`](./PRODUCTION-CUTOVER-STATUS.md)（移行プログラム残作業なし）。

## いま残っている Rails（2026-06-01）

| 領域 | 例 | 役割 |
|------|-----|------|
| HTTP シェル | `spa#index`, `pages#*`, `auth_test`, `/up` | ローカル HTML フォールバック・dev モック |
| ActiveRecord | `app/models/**` | 契約テストの fixture / Session、モデル単体テスト |
| テスト基盤 | `run-test-rails.sh`, `Dockerfile.test`, `test/contract/**`（Minitest + `CONTRACT_RUNTIME=rust`） | R4 は **Rust 向け**だがハーネスはまだ Ruby |
| Compose | `docker compose up` → `rails server` | 旧来の開発起動 |
| スキーマ | `db/migrate`（履歴） | 新規は **refinery**（`crates/agrr-migrate`）のみ発行 |

**削除済み（再削除しない）**: `lib/domain/`, `app/controllers/api/`, API adapters/jobs/channels, `Dockerfile.production`, Solid Cable DB。

## 開発の正（現時点）

```bash
# DB 初回
./scripts/load-development-reference-data.sh

# API / WS / auth
./scripts/dev-rust-stack.sh

# Angular
cd frontend && ng serve --host 127.0.0.1
```

`docker compose up`（Rails）は **レガシー**。P8 で既定を Rust に寄せる。

## フェーズ（推奨順）

| Phase | 内容 | ゲート |
|-------|------|--------|
| **P8.0** | ドキュメント・スクリプト文言（`rails db:prepare` → `agrr-migrate`） | レビュー |
| **P8.1** | テストランナー整理（空ディレクトリ、`bin/domain-lib-test` 廃止、`bin/test` は Rust 契約を正と明記） | `./bin/test` / CI |
| **P8.2** | DB ブートストラップの Rails 依存除去 | `dev-rust-stack.sh` 起動 |
| **P8.3** | Compose / README の既定起動を Rust に | 手動 smoke |
| **P8.4** | テスト縮小（AR モデルテスト・Rails 専用 integration の移管 or 削除） | R4 GREEN |
| **P8.5** | Gemfile・Rails アプリツリー削除 | `p7-code-removal-gate.sh` + フロント E2E |

## ゲート

- **Rust 変更**: [`scripts/p7-code-removal-gate.sh`](../../../scripts/p7-code-removal-gate.sh)
- **契約**: [`scripts/run-rust-contract-tests.sh`](../../../scripts/run-rust-contract-tests.sh)
- **進捗メモ**: [`tmp/rails-shell-removal-tasks.md`](../../../tmp/rails-shell-removal-tasks.md)
