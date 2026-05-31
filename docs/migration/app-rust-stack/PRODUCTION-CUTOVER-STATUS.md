# 本番 Rust カットオーバー — 残作業と観測記録

> **最終観測**: 2026-05-31（gcloud / curl / Litestream レプリカ / `run-rust-contract-tests.sh`）  
> **完了条件**: [`P6-COMPLETION-CRITERIA.md`](./P6-COMPLETION-CRITERIA.md) レベル 4・5  
> **デプロイ**: [`.cursor/skills/deploy-server/scripts/gcp-deploy-rust.sh`](../../../.cursor/skills/deploy-server/scripts/gcp-deploy-rust.sh)（test: [`deploy-rust-backend.sh test`](../../../.cursor/skills/gcp-test-local/scripts/deploy-rust-backend.sh)）  
**手順**: [`.cursor/skills/gcp-test-local/scripts/prod-rust-cutover-checklist.sh`](../../../.cursor/skills/gcp-test-local/scripts/prod-rust-cutover-checklist.sh)

## 残作業

| # | 項目 | 備考 |
|---|------|------|
| 1 | 本番 `rust-backend` + URL map 切替 | `/api/*` `/cable` `/auth/*` `/up` → 現状すべて `agrr-rails-backend` |
| 2 | 本番 `agrr-production` を `Dockerfile.agrr-server` に | 現行 `agrr:20260420-091559`（Rails） |
| 3 | 本番初回 refinery / schema | レプリカで `schema verify`・手順合意（本番は `schema_migrations` のみ） |
| 4 | 本番 `data apply`（必要分） | us 参照作物 **7件** stages 欠損（下記）。India repair では直らない |
| 5 | 本番スモーク | OAuth・計画→WS・マスタ CRUD — **map 切替後** |
| 6 | P7 | Rails サービス廃止・[`P7-EXIT-CHECKLIST.md`](./P7-EXIT-CHECKLIST.md) |

**ローカルゲート**（切替前に再実行）: `cargo build -p agrr-server` + `COVERAGE=false ./scripts/run-rust-contract-tests.sh`（2026-05-31: 112 runs, 0 failures）。

**GCP test**: `agrr-test:latest`（Rust）、直 URL `/up` → `ok`。`agrr.net` 経由では未使用。

---

## 観測記録（2026-05-31）

### GCP URL map（`agrr-frontend-url-map-simple`）

| パス | backend service |
|------|-----------------|
| `/api/*` | `agrr-rails-backend` |
| `/cable`, `/cable/*` | `agrr-rails-backend` |
| `/auth`, `/auth/*` | `agrr-rails-backend` |
| `/up` | `agrr-rails-backend` |

`rust-backend` 用 backend service **なし**。`agrr-rails-neg` → `agrr-production`。

### エンドポイント指紋（curl）

| | `agrr-test`（Run 直 URL） | `agrr.net`（LB） |
|--|---------------------------|------------------|
| `/up` | `200` `ok` | `200` Rails JSON |
| `/health` | `200` `ok` | `404` Angular |
| 未知 API | `501` `api_not_migrated` | `404` Rails |

### Litestream レプリカ

照会: [production-primary-sqlite-query](../../../.cursor/skills/production-primary-sqlite-query/SKILL.md)（遅延あり得る）。

| 環境 | バケット | マイグレーション表 | India repair | in 参照・stages なし | us 参照・stages なし |
|------|----------|-------------------|--------------|----------------------|----------------------|
| GCP test | `agrr-test-db` | refinery + `data_migration_history` | 適用済み | 0 | — |
| 本番 | `agrr-production-db` | `schema_migrations` のみ | 履歴表なし | 0 | **7** |

本番 us 参照作物（stages なし）:

| id | name |
|----|------|
| 76 | Almonds (Nonpareil) |
| 77 | Apples (Red Delicious) |
| 78 | Carrots (Standard) |
| 79 | Cotton (Upland Cotton) |
| 80 | Rice (Long Grain) |
| 81 | Soybeans (Standard) |
| 82 | Wheat (Winter Wheat) |

---

## ローカルレプリカコピー（本番ライブ非接触）

```bash
./scripts/refresh-production-primary-replica.sh
# → tmp/production-primary-replica/primary.sqlite3（gitignore 済み）
```

`agrr-migrate` の検証例:

```bash
export AGRR_APP_ROOT=$PWD
export AGRR_SQLITE_PATH=$PWD/tmp/production-primary-replica/primary.sqlite3
agrr-migrate schema verify
agrr-migrate data list
```

## 推奨実施順

1. レプリカで schema / us 7件の修復方針（運用合意）— 上記コピーで実施
2. 本番 `agrr-server` + `rust-backend` + URL map
3. 必要なら手動 `data apply`、切替後スモーク
4. P7

## 関連

- [`P7-MIGRATION-RUNBOOK.md`](./P7-MIGRATION-RUNBOOK.md) — schema / data CLI
- [`README.md`](./README.md) — 索引
