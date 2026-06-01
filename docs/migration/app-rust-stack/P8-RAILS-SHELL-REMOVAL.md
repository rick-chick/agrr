# P8 — リポジトリからの Rails シェル削除

> **P7 との違い**: P7 は「本番で Rails API に依存しない」ことの完了（2026-05-31）。P8 は **リポジトリと開発体験**から Rails を外す。

**本番の正**: [`PRODUCTION-CUTOVER-STATUS.md`](./PRODUCTION-CUTOVER-STATUS.md)（移行プログラム残作業なし）。

## 「移行」でないもの（誤解防止）

| よくある誤解 | 事実 |
|--------------|------|
| P8.6 で API を Rust に実装する | **いいえ。** 本番 API は P7 時点で **`agrr-server` のみ**。Ruby 契約は最初から `RUST_CONTRACT_BASE_URL`（co-located `agrr-server`）を叩いている |
| `test/contract/auth_me_contract_test.rb` を `agrr-r4-contract` に書き直す必要がある | **いいえ。** `GET /api/v1/auth/me` は [`crates/agrr-server/src/auth_api.rs`](../../../crates/agrr-server/src/auth_api.rs) に実装済み。薄い auth 契約は **Playwright E2E**（モックログイン・`/api/v1/auth/me` 非モック）で足りるため、**Rust R4 への逐語移植はしない**（Gem 削除時に Ruby 契約ごと除去） |
| P8.6.1「進行中」＝機能未実装 | **いいえ。** 残作業は **Minitest + ActiveRecord fixture + `Gemfile`** の除去。複雑な BC だけ `agrr-r4-contract` へ寄せ、それ以外は移植せず削除 |

## いま残っている Rails（P8.5 後）

| 領域 | 例 | 役割 |
|------|-----|------|
| 契約ハーネス | `app/models/**`, `test/contract/**`, `test/factories/**`, 縮小 `Gemfile` | **検証対象は常に agrr-server**。Ruby は fixture 投入と Minitest のみ（段階的に `crates/agrr-r4-contract` + Rust seed へ） |
| テスト実行 | `scripts/run-rust-contract-tests.sh`, `Dockerfile.test` | co-located `agrr-server` + refinery DB + `agrr-r4-contract-tests` → 続けて Ruby 契約 |
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
| **P8.5.1** | Hotwire 資産・test-integration・RuboCop/Brakeman CI 削除 | **完了**（2026-06-01） |
| **P8.6.0** | 契約テスト Rust 専用化（`rust_contract?` 分岐・未使用 support 削除） | **完了**（2026-06-01）— R4 GREEN |
| **P8.6.1** | `agrr-r4-contract` + `run-rust-contract-tests.sh` 統合。重い Ruby 契約のみ Rust へ | **進行中** — 下表「Rust へ寄せる」 |
| **P8.6** | `Gemfile` 完全削除（残る Ruby 契約は除去または Rust 化済み） | TBD（P8.6.1 完了後） |

### Ruby 契約の P8.6 扱い（2026-06-02）

| 区分 | 例 | 扱い |
|------|-----|------|
| **agrr-r4-contract 済** | `/api/v1/health`, `/cable`, `*/ai_create` スモーク | 維持（旧 Ruby スモークは削除済み） |
| **Rust 移植不要**（Gem 削除時に Ruby 削除） | `auth_me_contract_test.rb`, `auth_logout_contract_test.rb` | `auth_api.rs` 実装済み。回帰は E2E + 必要なら将来 `agrr-r4-contract` に統合スモーク 1 本で足りる |
| **Rust へ寄せる**（AR fixture が重い） | `masters_*`, `private_*`, `public_*`, `plan_*`, `internal_*`, `backdoor_*`, `deletion_undo_*`, `field_cultivation_*` 等 | fixture を Rust seed / sqlite ヘルパに替えてから Ruby ファイル削除 |

P6 の [`TRACKING-P6.yaml`](./TRACKING-P6.yaml) `wave_e.contract_tests` は **当時の R4 ゲート一覧**であり、P8.6 で「すべて `agrr-r4-contract` に写す」リストではない。

## ゲート

- **Compose 開発**: [`.cursor/skills/dev-docker/SKILL.md`](../../../.cursor/skills/dev-docker/SKILL.md)
- **Rust 変更**: [`scripts/p7-code-removal-gate.sh`](../../../scripts/p7-code-removal-gate.sh)
- **契約**: [`scripts/run-rust-contract-tests.sh`](../../../scripts/run-rust-contract-tests.sh)
