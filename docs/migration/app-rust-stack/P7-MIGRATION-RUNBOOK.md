# P7 migration runbook — refinery schema + manual data CLI

Operational guide for [`agrr-migrate`](../../../crates/agrr-migrate). Schema migrations run on app startup; reference data is **manual only**.

## Rust 本番移行時に必要なこと（要約）

**デプロイ（Cloud Run 起動）だけでは参照データは直らない。** 起動時は [`db_bootstrap_common.sh`](../../../scripts/db_bootstrap_common.sh) 経由の **`agrr-migrate schema run` のみ**（[`start_agrr_server.sh`](../../../scripts/start_agrr_server.sh)）。`kind=repair` を含む **すべての `data apply` は手動**。

| 区分 | 例 | デプロイ時に自動？ | 適用方法 |
|------|-----|-------------------|----------|
| **Schema**（DDL / refinery） | `data_migration_history` テーブル追加など | **はい** | 起動時 `schema run` |
| **Data** `base` / `nutrients` / `pests` / `tasks` / … | `20251018130418` in base など | **いいえ** | `agrr-migrate data apply --region … --kind …` |
| **Data** `repair` | `20260531120000` repair_india_reference_farms、`20260531130100` repair_india_reference_crops | **いいえ** | `data apply --region in --kind repair` |

`20260531120000` / `20260531130100` はマニフェスト上 `region=in`, `kind=repair`（[`legacy_versions.yaml`](../../../crates/agrr-migrate/manifest/legacy_versions.yaml)）。**イメージに manifest・fixture が入っていても、デプロイだけでは `data_migration_history` にも DB データにも反映されない。**

### チェックリスト（本番・staging・GCP test 共通）

1. **イメージ** — [`Dockerfile.agrr-server`](../../../Dockerfile.agrr-server) に `agrr-migrate` バイナリ、`crates/agrr-migrate/manifest`、`data/extracted`、`db/fixtures`（特に `india_reference_weather.json` / `india_reference_crops.json`）が含まれること。
2. **Litestream 復元済み DB** — 空 DB に baseline しない。手順は下記 [Litestream-restored production / staging DB](#litestream-restored-production--staging-db)。
3. **Schema** — デプロイ後 `schema verify`。**Rails 由来の履歴のみ**の DB は `schema stamp` → `data stamp`（dry-run 後）を検証用コピーで実施。
4. **Data（手動・環境ごとに合意）** — 症状に応じて [Data recovery matrix](#data-recovery-matrix) の `data apply` を実行。未適用分だけ走る（`data_migration_history` で skip）。
5. **India repair（region 不具合）** — test で in 参照作物に `crop_stages` が無い／公開プラン最適化が `crop has no growth stages` のとき:
   ```bash
   export AGRR_APP_ROOT=/app   # コンテナ内、またはホストでレプリカを指す
   export AGRR_SQLITE_PATH=/path/to/primary.sqlite3
   agrr-migrate data apply --region in --kind repair
   ```
   farms（`20260531120000`）→ crops（`20260531130100`）の順。fixture 欠落時は **エラーで止まり履歴は付かない**。
6. **検証** — `agrr-migrate data list`；参照作物の stages（例: in で `without_stages=0`）；公開プラン最適化のスモーク。
7. **本番 DB** — **運用合意なしに `data apply` を本番 primary に対して実行しない**（レプリカコピーで dry-run / 検証してから）。

### test と本番の違い（誤解しやすい点）

- **同じマニフェスト・同じ repair コマンド**でも、**既に壊れている region／行だけ**が対象（例: test の in はインライン作物、本番の in は stages あり得る／本番 us は stages 無し参照作物があり得る）。
- **GCP test にデプロイ済み ≠ repair 適用済み**。デプロイはコードと fixture の配備；**DB 修復は別途 `data apply`**。
- **本番も region 別の参照データ不整合がありうる**。「in の crop_stages だけ見て本番 migrate 不要」とは断定しない。不足 kind／region は matrix と DB 照会で決める。

### 関連コマンド

```bash
agrr-migrate schema verify
agrr-migrate schema status
agrr-migrate data list
agrr-migrate data apply --region in --kind repair   # 20260531120000, 20260531130100（未適用時のみ）
```

## Tools and env

| Variable | Default | Purpose |
|----------|---------|---------|
| `AGRR_APP_ROOT` | current directory | Repo root (`db/fixtures`, `crates/agrr-migrate/data/extracted`) |
| `AGRR_SQLITE_PATH` | `storage/development.sqlite3` | Primary SQLite |
| `AGRR_CACHE_SQLITE_PATH` | `storage/development_cache.sqlite3` | Cache SQLite |
| `AGRR_MIGRATE_SKIP_WEATHER` | unset | When set, `base` skips large weather JSON (crops + basic farms only; tests/dev) |

Build: `cargo build -p agrr-migrate --release`

`data apply` is **Rust-only** (rusqlite + committed JSON/fixtures). It does **not** require `Gemfile`, `bundle`, or Rails.

## New developer setup (empty primary)

```bash
export AGRR_APP_ROOT=/path/to/agrr
export AGRR_SQLITE_PATH="$AGRR_APP_ROOT/storage/development.sqlite3"

cargo run -p agrr-migrate -- schema run
cargo run -p agrr-migrate -- data apply \
  --region jp,in,us \
  --kind base,nutrients,pests,tasks
cargo run -p agrr-migrate -- data apply --region jp --kind templates
cargo run -p agrr-migrate -- data apply --region jp,us --kind dev_fixtures
```

Or use [`scripts/load-development-reference-data.sh`](../../../scripts/load-development-reference-data.sh) (wraps `agrr-migrate`).

### Weather fixtures (`base` kind)

- JP/US/IN weather: `db/fixtures/*_reference_weather.json` (~100MB+ per region).
- Loaded via **streaming** top-level farm keys (low peak memory vs full-file parse).
- Expect several minutes per region on first apply; re-apply is idempotent (skips via `data_migration_history` + upserts).
- Optional: run one region at a time, e.g. `data apply --region jp --kind base`.

## Regenerating extracted JSON (maintainers)

When `db/migrate_archive` task/pest definitions change:

```bash
bundle exec ruby scripts/extract_reference_data_json.rb
```

Writes `crates/agrr-migrate/data/extracted/{tasks,pests,templates}/`. Pests export needs reference pests in the dev DB (run archive pest migrations first if `in` is empty).

## Litestream-restored production / staging DB

**Do not** run baseline on a restored DB that already has tables.

1. Restore replica to a **copy** (never stamp production directly without verify).
2. `agrr-migrate schema verify` — must pass.
3. If upgrading from Rails-only history:  
   `agrr-migrate schema stamp --dry-run` then `agrr-migrate schema stamp`  
   `agrr-migrate data stamp --dry-run` then `agrr-migrate data stamp`
4. Deploy version with `agrr-migrate schema run` in entrypoint — applies only **pending** refinery versions (e.g. V2 `data_migration_history`).

## Data recovery matrix

| Symptom | Command |
|---------|---------|
| Missing JP/US reference farms/crops/weather | `data apply --region jp` or `us` `--kind base` |
| Missing India reference base | `data apply --region in --kind base` |
| India public plan shows only Punjab (stub farm) | `data apply --region in --kind repair` (requires `db/fixtures/india_reference_weather.json` in image) |
| India optimization fails (`crop has no growth stages`) | `data apply --region in --kind repair` (applies `repair_india_reference_crops`; requires `db/fixtures/india_reference_crops.json` in image). Then `data apply --region in --kind nutrients` if nutrients are missing. |
| Missing pests | `data apply --region <jp\|in\|us> --kind pests` |
| Missing agricultural tasks | `data apply --region <jp\|in\|us> --kind tasks` |
| Missing nutrients | `data apply --region <jp\|in\|us> --kind nutrients` |
| Missing crop task templates (JP only) | `data apply --region jp --kind templates` |
| Missing admin + sample fixtures (dev) | `data apply --region jp,us --kind dev_fixtures` |
| Missing schedule blueprints | **Not in CLI** — use `bin/generate_crop_task_schedule_blueprints.rb`, review, apply SQL/migration separately |

Check status: `agrr-migrate data list`

## Parity verification (Rails archive vs agrr-migrate)

| | Rails 側 | Rust 側 |
|---|----------|---------|
| Schema | `agrr-migrate schema run` | 同左 |
| Data | `db/migrate_archive` の data 系 + `scripts/apply_extracted_reference_tasks.rb`（tasks は JSON） | `agrr-migrate data apply`（全 kind） |

`scripts/compare_rails_rust_migration_parity.rb` は両方の DB を作り、`sqlite3 .schema` と `.dump` の INSERT 行を diff する（差分は `tmp/migration_parity/rails.*.txt` と `rust.*.txt`）。

```bash
# スキーマのみ（CI 向け・数秒）
bundle exec ruby scripts/compare_rails_rust_migration_parity.rb --schema-only

# 参照データまで（天気 JSON 込み・数十分）
bundle exec ruby scripts/compare_rails_rust_migration_parity.rb
```

CI: `cargo test -p agrr-migrate --test migration_parity_test`（スキーマのみ。データ全体は `#[ignore]`）

`AGRR_MIGRATE_SKIP_WEATHER` は **agrr-migrate の `base` 実装用**（開発・単体テスト）であり、パリティ用ではない。

## Schema rollback

Schema is **forward-only**. Roll back by restoring SQLite from Litestream/object storage.

## Legacy manifest

`crates/agrr-migrate/manifest/legacy_versions.yaml` — generated by:

```bash
ruby scripts/generate_legacy_versions_manifest.rb
```

P7a PRs must include a complete manifest (120 primary migrations tagged).
