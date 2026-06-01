# P7 migration runbook — refinery schema + manual data CLI

Operational guide for [`agrr-migrate`](../../../crates/agrr-migrate). Schema migrations run on app startup; reference data is **manual only**.

## Rust 本番移行時に必要なこと（要約）

**デプロイ（Cloud Run 起動）だけでは参照データは直らない。** 起動時は [`db_bootstrap_common.sh`](../../../scripts/db_bootstrap_common.sh) 経由の **`agrr-migrate schema run` のみ**（[`start_agrr_server.sh`](../../../scripts/start_agrr_server.sh)）。`kind=repair` を含む **すべての `data apply` は手動**。

| 区分 | 例 | デプロイ時に自動？ | 適用方法 |
|------|-----|-------------------|----------|
| **Schema**（DDL / refinery） | `data_migration_history` テーブル追加など | **はい** | 起動時 `schema run` |
| **Data** `base` / `nutrients` / `pests` / `tasks` / … | `20251018130418` in base など | **いいえ** | `agrr-migrate data apply --region … --kind …` |
| **Data** `repair` | `in`: `20260531120000` farms、`20260531130100` crops — `us`: `20260531130200` crops | **いいえ** | `data apply --region in --kind repair` / `--region us --kind repair` |

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
cargo run -p agrr-migrate -- data apply --region in --kind repair
cargo run -p agrr-migrate -- data apply --region jp --kind templates
cargo run -p agrr-migrate -- data apply --region jp,us --kind dev_fixtures
```

Or use [dev-docker `load-reference-data-host.sh`](../../../.cursor/skills/dev-docker/scripts/load-reference-data-host.sh) (wraps `agrr-migrate`, including `in` repair).

**GCP test** (Litestream-restored DB with broken inline India crops): [`.cursor/skills/gcp-test-local/scripts/run-gcp-test-data-migrate.sh`](../../../.cursor/skills/gcp-test-local/scripts/run-gcp-test-data-migrate.sh) — bootstrap + `data apply --region in --kind repair` + replicate, then restore normal `start_agrr_server.sh` deploy.

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

## US `crop_stages` repair — 本番適用の整理

### 種類の区別（混同しない）

| 種類 | 例 | Cloud Run 起動時（`start_agrr_server.sh`） | 手動 |
|------|-----|-------------------------------------------|------|
| **Schema**（DDL） | `refinery_schema_history`、テーブル追加 | **自動** — `agrr-migrate schema run` | 通常不要 |
| **Data**（参照データ） | `base` / `nutrients` / … | **走らない** | `agrr-migrate data apply` |
| **Data repair**（修復） | US: `20260531130200` `repair_us_reference_crops` | **走らない** | `data apply --region us --kind repair` |

**通常の本番デプロイ（`gcp-deploy.sh` → `start_agrr_server.sh`）だけでは、US repair は DB に一切触れない。** イメージに `us_reference_crops.json` が入っていても、中身は「実行可能な道具」が載っただけ。

### US repair が DB でやること（1 回だけ）

1. `data_migration_history` に `20260531130200` が **無ければ** 実行（あれば **skip**）。
2. `region=us` かつ `crop_stages` が無い参照作物を削除。
3. `db/fixtures/us_reference_crops.json` から参照作物＋`crop_stages` を upsert。
4. 成功時に `data_migration_history` へ `20260531130200` を記録。

India の `data apply --region in --kind repair` とは別コマンド。US は **作物のみ**（`20260531130200` 1 本）。India は farms + crops の 2 本が同じ `--region in --kind repair` で順に走る。

### 前提（順序）

1. **コードが入ったイメージをデプロイ済み** — マニフェストに `20260531130200`、Rust に `repair_us_reference_crops`、`/app/db/fixtures/us_reference_crops.json`（[`Dockerfile.agrr-server`](../../../Dockerfile.agrr-server) の `COPY db/fixtures`）。
2. **書き込み先は本番 primary** — Litestream が複製する `/tmp/production.sqlite3`（環境変数 `AGRR_SQLITE_PATH`）。レプリカコピーへの `data apply` は**本番を変えない**。

未デプロイの古いイメージで `data apply --region us --kind repair` しても、マニフェストに `20260531130200` が無ければ **何も起きない**（pending エントリなし）。

### 環境変数の意味

| 変数 | 本番 Cloud Run | レプリカ検証（ホスト） |
|------|----------------|------------------------|
| `AGRR_APP_ROOT` | `/app`（fixture・manifest のルート） | リポジトリルート `$PWD` |
| `AGRR_SQLITE_PATH` | `/tmp/production.sqlite3`（Litestream primary） | `tmp/production-primary-replica/primary.sqlite3` 等 |

```bash
# 本番コンテナ内（primary に書く）のイメージ
export AGRR_APP_ROOT=/app
export AGRR_SQLITE_PATH=/tmp/production.sqlite3
agrr-migrate data list    # pending に 20260531130200 repair_us_reference_crops があるか
agrr-migrate data apply --region us --kind repair
```

### 本番への書き込み経路（3 段階）

| 段階 | 目的 | 手順 |
|------|------|------|
| **A. 検証のみ** | 本番を変えず効果確認 | [`scripts/refresh-production-primary-replica.sh`](../../../scripts/refresh-production-primary-replica.sh) → ホストで `AGRR_APP_ROOT=$PWD` `AGRR_SQLITE_PATH=.../primary.sqlite3` → `data apply --region us --kind repair` → `without_stages` が 0 か確認 |
| **B. 本番 primary へ適用** | 実データ修復 | Litestream 付きで primary を開き、上記 `data apply` を **1 回**実行 → Litestream が GCS へ複製（数分待つ） |
| **C. 事後確認** | 適用済み・欠損解消 | レプリカで `SELECT version FROM data_migration_history WHERE version='20260531130200';` と `us` の `without_stages=0` |

**B の具体例（運用スクリプト）**: [`.cursor/skills/deploy-server/scripts/run-production-data-migrate.sh`](../../../.cursor/skills/deploy-server/scripts/run-production-data-migrate.sh) は、一時 revision で `production-data-migrate-inner.sh` を走らせ、Litestream restore → migrate → replicate する。**現状の inner は in repair + us `base` のみ**（US repair は含まない）。US repair だけ載せるなら inner を差し替えるか、同等の one-shot で `data apply --region us --kind repair` のみ実行する。

**手動で Cloud Run に SSH する想定はない。** 書き込むなら「migrate 用 entrypoint の revision を 1 台立てて primary + Litestream 経由で GCS に反映」が安全。

### よくある誤解

| 誤解 | 事実 |
|------|------|
| デプロイしたら repair 済み | **誤り**。デプロイはバイナリ・fixture の配備のみ。 |
| `schema run` が data もやる | **誤り**。起動時は schema のみ。 |
| `data apply --region us --kind base` で stages が直る | **不十分**。stub 作物が残る場合は **`kind=repair`**（`repair_us_reference_crops`）が必要。 |
| 何度も repair すると重複 | **誤り**。`data_migration_history` で 2 回目は skip。fixture upsert は冪等。 |
| レプリカで apply = 本番修復済み | **誤り**。レプリカは読み取り用コピー。本番は B 経路が必要。 |

## Data recovery matrix

| Symptom | Command |
|---------|---------|
| Missing JP/US reference farms/crops/weather | `data apply --region jp` or `us` `--kind base` |
| Missing India reference base | `data apply --region in --kind base` |
| India public plan shows only Punjab (stub farm) | `data apply --region in --kind repair` (requires `db/fixtures/india_reference_weather.json` in image) |
| India optimization fails (`crop has no growth stages`) | `data apply --region in --kind repair` (applies `repair_india_reference_crops`; requires `db/fixtures/india_reference_crops.json` in image). Then `data apply --region in --kind nutrients` if nutrients are missing. |
| US reference crops without `crop_stages` (e.g. 7 stub rows) | `data apply --region us --kind repair` (applies `repair_us_reference_crops`; requires `db/fixtures/us_reference_crops.json` in image). |
| Missing pests | `data apply --region <jp\|in\|us> --kind pests` |
| Missing agricultural tasks | `data apply --region <jp\|in\|us> --kind tasks` |
| Missing nutrients | `data apply --region <jp\|in\|us> --kind nutrients` |
| Missing crop task templates (JP only) | `data apply --region jp --kind templates` |
| Missing admin + sample fixtures (dev) | `data apply --region jp,us --kind dev_fixtures` |
| Missing schedule blueprints | **Not in CLI** — generate out of band (legacy Rails script removed P8); review SQL/data migration separately |

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
