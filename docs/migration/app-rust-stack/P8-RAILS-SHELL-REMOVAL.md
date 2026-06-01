# P8 — リポジトリからの Rails シェル削除

> **P7 との違い**: P7 は「本番で Rails API に依存しない」ことの完了（2026-05-31）。P8 は **リポジトリと開発体験**から Rails を外す。

**本番の正**: [`PRODUCTION-CUTOVER-STATUS.md`](./PRODUCTION-CUTOVER-STATUS.md)（移行プログラム残作業なし）。

## 「移行」でないもの（誤解防止）

| よくある誤解 | 事実 |
|--------------|------|
| P8 で API を Rust に実装する | **いいえ。** 本番 API は P7 時点で **`agrr-server` のみ** |
| 削除した Ruby 契約を `agrr-r4-contract` に写す必要がある | **いいえ。** 回帰は **E2E** + **`agrr-domain` / adapter 単体**。R4 は **health + `/cable` ルーティング** のみ（AI 等の業務は domain の責務） |

## 回帰の正（P8.6 以降）

| 層 | 手段 |
|----|------|
| HTTP/WS スモーク | `crates/agrr-r4-contract` + `scripts/run-rust-contract-tests.sh` |
| ドメイン | `cargo test`（`agrr-domain`） |
| 永続化 adapter | `cargo test`（`agrr-adapters-sqlite` 等） |
| 画面・認証フロー | Playwright E2E（`/api/v1/auth/me` 非モック） |

## いま残っている Rails 痕跡（P8.7 後）

| 領域 | 例 | 備考 |
|------|-----|------|
| i18n（Rust 正） | `config/locales/**` | `agrr-server` の `locale_catalog` が読む（削除不可） |
| Litestream | `config/litestream.yml`, `config/litestream.development.yml` | `Dockerfile.agrr-server` が COPY |
| スキーマ履歴 | `db/migrate_archive/` 等 | `legacy_versions.yaml` の参照。新規スキーマは **refinery** |

**削除済み（P8.6）**: `Gemfile` / `Gemfile.lock`、`app/models/**`、`test/contract/**`、`test/factories/**`、`test/test_helper.rb`、Dockerfile.test の Ruby 段、Compose `bundle_cache`。

**削除済み（P8.7）**: `config/application.rb`・`routes.rb`・`environments/`・`initializers/`・`database.yml` 等、`config.ru`、`Rakefile`・`lib/tasks/**`・`bin/rails`・`bin/rake`、`.rubocop.yml`、`scripts/compare_rails_rust_migration_parity.rb`、`scripts/extract_reference_data_json.rb`、Playwright の Rails `webServer`。

**削除済み（P8.7 追補）**: `bin/` の Rails 依存ワンオフ（`generate_pest_data_migration.rb`、`fetch_*_reference_weather_data`、`convert_india_to_hindi`、`translate_*_crop_stages`、`update_india_farms_to_hindi`）。参照データの天気 fixture は `agrr-migrate data apply` + [`run-production-agrr-cli.sh`](../../../.cursor/skills/production-admin/scripts/run-production-agrr-cli.sh) 等で再取得。`scripts/verify-weather-sqlite-local.sh` の scheduler 窓は Python（`SchedulerUserFarmFetchWindowPolicy` 相当）に置換。

**削除済み（P8.5 以前）**: HTTP シェル、Hotwire、`lib/domain/`、API adapters、本番 Rails イメージ。

## 開発の正

```bash
.cursor/skills/dev-docker/scripts/load-reference-data.sh
.cursor/skills/dev-docker/scripts/up.sh
cd frontend && ng serve --host 127.0.0.1
```

## フェーズ

| Phase | 内容 | 状態 |
|-------|------|------|
| **P8.0–P8.5.1** | 開発 Rust 化・HTTP シェル・Hotwire 削除 | **完了** |
| **P8.6.0** | 契約ランナー Rust 専用経路 | **完了** |
| **P8.6.1** | `agrr-r4-contract` 統合 | **完了**（R4 は health + `/cable` の 2 本） |
| **P8.6** | Ruby 契約・`Gemfile`・AR fixture 削除（**移植せず削除**） | **完了**（2026-06-02） |
| **P8.7** | Rails 設定・Rake・移行用 Ruby スクリプト・Playwright Rails 起動の削除 | **完了**（2026-06-02） |

## ゲート

- **Compose 開発**: [`.cursor/skills/dev-docker/SKILL.md`](../../../.cursor/skills/dev-docker/SKILL.md)
- **Rust 変更**: [`scripts/p7-code-removal-gate.sh`](../../../scripts/p7-code-removal-gate.sh)
- **契約**: [`scripts/run-rust-contract-tests.sh`](../../../scripts/run-rust-contract-tests.sh)
