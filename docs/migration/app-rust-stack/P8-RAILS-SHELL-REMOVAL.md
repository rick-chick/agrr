# P8 — リポジトリからの Rails シェル削除

> **P7 との違い**: P7 は「本番で Rails API に依存しない」ことの完了（2026-05-31）。P8 は **リポジトリと開発体験**から Rails を外す。

**本番の正**: [`PRODUCTION-CUTOVER-STATUS.md`](./PRODUCTION-CUTOVER-STATUS.md)（移行プログラム残作業なし）。

## いま残っている Rails（P8.5 後）

| 領域 | 例 | 役割 |
|------|-----|------|
| 契約ハーネス | `app/models/**`, `test/contract/**`, `test/factories/**`, 縮小 `Gemfile` | R4: Minitest + ActiveRecord fixture → **agrr-server** |
| テスト実行 | `scripts/run-rust-contract-tests.sh`, `Dockerfile.test` | co-located `agrr-server` + refinery DB |
| スキーマ履歴 | `db/migrate_archive/` | 参照のみ。新規は **refinery**（`crates/agrr-migrate`） |

**削除済み（P8.5）**: HTTP シェル（controllers/views/adapters）、`Dockerfile`（dev Rails）、Compose `web` / `rails-up.sh`、モデル単体テスト、OmniAuth/CORS/Propshaft 依存。

**削除済み（P8.5.1）**: Hotwire 資産（`app/assets/`、`app/javascript/`、root `package.json`）、`test-integration` Compose、`Procfile.dev` / `bin/dev`、Selenium プロファイル、RuboCop/Brakeman CI（Gemfile から除去済み）。

**削除済み（再削除しない）**: `lib/domain/`, `app/controllers/api/`, API adapters/jobs/channels, `Dockerfile.production`, Solid Cable DB。

## 開発の正

```bash
# Docker（正）— .cursor/skills/dev-docker/SKILL.md
.cursor/skills/dev-docker/scripts/load-reference-data.sh
.cursor/skills/dev-docker/scripts/up.sh

# ホスト Rust
.cursor/skills/dev-docker/scripts/load-reference-data-host.sh
.cursor/skills/dev-docker/scripts/host-rust-stack.sh

# Angular
cd frontend && ng serve --host 127.0.0.1
```

## フェーズ（推奨順）

| Phase | 内容 | ゲート |
|-------|------|--------|
| **P8.0** | ドキュメント・スクリプト文言（`rails db:prepare` → `agrr-migrate`） | **完了**（`bin/setup`, `test/README.md`, dev-docker スキル既存） |
| **P8.1** | テストランナー整理（空ディレクトリ、`bin/domain-lib-test` 廃止、`bin/test` は Rust 契約を正と明記） | **完了**（`bin/test`, test-common SKILL, 空 `test/channels` 等削除） |
| **P8.2** | DB ブートストラップの Rails 依存除去 | **完了**（`load-reference-data.sh` / `load-reference-data-host.sh`） |
| **P8.3** | Compose / README の既定起動を Rust に | **完了**（[dev-docker](../../../.cursor/skills/dev-docker/SKILL.md)） |
| **P8.4** | テスト縮小（廃止 API 統合テスト削除、`run-test-rails.sh` から `test/contract` 除外） | **完了**（2026-06-01）— R4: `run-rust-contract-tests.sh` GREEN、Rails シェル 212 件 GREEN |
| **P8.5** | HTTP シェル・モデルテスト・dev Rails 削除。Gemfile は契約ハーネス用に縮小 | **完了**（2026-06-01）— R4 109 GREEN、`p7-code-removal-gate.sh` |
| **P8.6** | 契約ハーネスの Rust 化（Gemfile 完全削除） | TBD |

## ゲート

- **Compose 開発**: [`.cursor/skills/dev-docker/SKILL.md`](../../../.cursor/skills/dev-docker/SKILL.md)
- **Rust 変更**: [`scripts/p7-code-removal-gate.sh`](../../../scripts/p7-code-removal-gate.sh)
- **契約**: [`scripts/run-rust-contract-tests.sh`](../../../scripts/run-rust-contract-tests.sh)
