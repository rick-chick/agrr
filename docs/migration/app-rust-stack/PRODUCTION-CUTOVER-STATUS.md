# 本番 Rust カットオーバー — 残作業と観測記録

> **最終観測**: 2026-06-01（本番手動スモーク完了申告 + `p7-code-removal-gate.sh`）。本番指紋・レプリカは 2026-05-31（gcloud / curl）  
> **完了条件**: [`P6-COMPLETION-CRITERIA.md`](./P6-COMPLETION-CRITERIA.md) レベル 4・5  
> **デプロイ**: [`.cursor/skills/deploy-server/scripts/gcp-deploy-rust.sh`](../../../.cursor/skills/deploy-server/scripts/gcp-deploy-rust.sh)（test: [`deploy-rust-backend.sh test`](../../../.cursor/skills/gcp-test-local/scripts/deploy-rust-backend.sh)）  
> **手順**: [`.cursor/skills/gcp-test-local/scripts/prod-rust-cutover-checklist.sh`](../../../.cursor/skills/gcp-test-local/scripts/prod-rust-cutover-checklist.sh)

## サマリー（2026-06-01）

| 観点 | 状態 |
|------|------|
| 本番 API トラフィック | **Rust（`agrr-server`）** — LB backend 名 **`rust-backend`**（NEG `agrr-rails-neg` → `agrr-production`） |
| **ローカルゲート** | **2026-06-01 OK** — [`p7-code-removal-gate.sh`](../../../scripts/p7-code-removal-gate.sh)（R4 **109 runs, 0 failures**、`agrr-migrate` GREEN） |
| P6 レベル 4（本番ストラングラー完了） | **達成**（2026-06-01 — 条件 1–3。手動スモークは運用確認済み） |
| P6 レベル 4 #3（手動スモーク） | **完了**（2026-06-01 — `agrr.net` ブラウザ、下表 6 項目） |
| P7 コード削除 Phase 1 | **実施済み**（2026-05-31）— `app/controllers/api`・jobs・channels・API adapters 削除 |
| P7 コード削除 Phase 2（`lib/domain`） | **実施済み**（2026-05-31）— `lib/domain/`・`test/domain/` 削除 |
| P7 Phase 3（Solid Cable DB） | **実施済み**（2026-05-31）— `database.yml` の cable DB・Litestream cable レプリカ削除。Rails は `/cable` 非マウント |
| P7 refinery / 本番イメージ | **実施済み**（2026-05-31）— `Dockerfile.production` 削除、デプロイは `agrr-server` + `agrr-migrate` のみ |
| 本番 DB データ | **in repair 適用済み**（レプリカ確認）。**us 参照作物 7 件**は stages 欠損のまま |

## 残作業

| # | 項目 | 備考 |
|---|------|------|
| ~~1~~ | ~~URL map 命名整理~~ | **実施済み**（2026-05-31）— `agrr-rails-backend` → **`rust-backend`**、旧 backend 削除。[`scripts/agrr-frontend-url-map-simple.yaml`](../../../scripts/agrr-frontend-url-map-simple.yaml) |
| ~~2~~ | ~~本番 **手動スモーク**~~ | **実施済み**（2026-06-01）— OAuth、`auth/me`、計画→最適化 WS、マスタ CRUD、`save_plan`、`POST /undo_deletion` |
| 3 | 本番 **us 参照データ** | `20260531130200` `repair_us_reference_crops` — コード済み。本番 primary へは運用合意後 `agrr-migrate data apply --region us --kind repair` |
| 4 | **P7 出口** #7（必要時） | 参照データの手動 `data apply` — [`P7-EXIT-CHECKLIST.md`](./P7-EXIT-CHECKLIST.md)・[`P7-MIGRATION-RUNBOOK.md`](./P7-MIGRATION-RUNBOOK.md) |

**ローカルゲート**: [`scripts/p7-code-removal-gate.sh`](../../../scripts/p7-code-removal-gate.sh) 1 本で足りる（内部で build + R4 契約 + `agrr-migrate`）。**2026-06-01: OK**（109 runs, 0 failures）。Rust / 起動スクリプトを変えたマージ前のみ再実行。

**完了済み（旧「残作業」から外す）**:

- URL map backend 名 **`rust-backend`** へ整理（2026-05-31）— `agrr-rails-backend` 削除、`agrr.net` `/up`・`/api/v1/health` スモーク OK
- **`Dockerfile.production` 廃止**（2026-05-31）— 本番デプロイは `Dockerfile.agrr-server` のみ（`gcp-deploy.sh` → refinery / Litestream）
- 本番 `agrr-production` を `Dockerfile.agrr-server` でデプロイ — `agrr-server:20260531-222952`
- 本番 refinery — レプリカで `schema verify OK`（`refinery_schema_history` + `data_migration_history` あり）
- 本番 in repair — `20260531120000` / `20260531130100` 適用済み（レプリカ）
- **本番手動スモーク** — 2026-06-01（`agrr.net`、レベル 4 条件 3）

---

## 観測記録（2026-05-31）

### Cloud Run

| 項目 | 値 |
|------|-----|
| サービス | `agrr-production` |
| イメージ | `asia-northeast1-docker.pkg.dev/agrr-475323/agrr/agrr-server:20260531-222952` |
| Run 直 URL | 未認証 curl は 404（想定内）。**LB 経由で検証** |

### GCP URL map（`agrr-frontend-url-map-simple`）

| パス | backend service（LB 上の名前） | 実体 |
|------|-------------------------------|------|
| `/api/*` | **`rust-backend`** | `agrr-rails-neg` → **`agrr-production`（Rust）** |
| `/cable`, `/cable/*` | **`rust-backend`** | 同上 |
| `/auth`, `/auth/*` | **`rust-backend`** | 同上 |
| `/up` | **`rust-backend`** | 同上 |
| `/assets`, `/assets/*` | **`rust-backend`** | 同上 |

NEG 名 `agrr-rails-neg` は歴史的名称のまま（Cloud Run `agrr-production` を指す）。

### エンドポイント指紋（curl `agrr.net`）

| パス | HTTP | 本文・備考 |
|------|------|------------|
| `/up` | 200 | `ok`（**Rust**） |
| `/api/v1/health` | 200 | Rust JSON（`database`, `timestamp` 等） |
| `/api/v1/plans` | 401 | `{"error":"unauthorized"}` |
| `/api/v1/…`（未実装） | 501 | `api_not_migrated` |
| `/auth/login` | 307 | `Location: /login`（SPA） |
| `/cable` | 400 | `upgrade` ヘッダなし（WS 前提） |
| `/health` | 404 | Angular（CDN。Rust `/health` とは別経路） |

### Litestream レプリカ（`tmp/production-primary-replica/primary.sqlite3`）

照会: [production-primary-sqlite-query](../../../.cursor/skills/production-primary-sqlite-query/SKILL.md)（遅延あり得る）。

| 項目 | 結果 |
|------|------|
| `agrr-migrate schema verify` | **OK**（refinery version 2） |
| 履歴表 | `schema_migrations`, `refinery_schema_history`, `data_migration_history` |
| `in` repair | **適用済み** |
| `in` 参照・stages なし | **0** |
| `us` 参照・stages なし | **7**（下表） |

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

## 観測記録（2026-06-01）

### ローカルゲート

| 項目 | 結果 |
|------|------|
| コマンド | `./scripts/p7-code-removal-gate.sh` |
| `cargo build -p agrr-server` | OK |
| R4 契約 | **109 runs, 0 failures**（7.7s） |
| `cargo test -p agrr-migrate` | OK |
| 静的チェック（routes / `lib/domain` / Cable） | OK |

### 本番手動スモーク（レベル 4 条件 3）

| 項目 | 結果 |
|------|------|
| 実施日 | 2026-06-01 |
| 環境 | `https://agrr.net`（ブラウザ） |
| Google OAuth ログイン | OK |
| `GET /api/v1/auth/me` → 200 | OK |
| 私有計画作成 → 最適化 WS 完走 | OK |
| マスタ CRUD（`/api/v1/masters/*`） | OK |
| `POST /api/v1/public_plans/save_plan` | OK |
| `POST /undo_deletion` | OK |
| 記録 | 運用確認済み（利用者申告） |

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

## 推奨実施順（2026-06-01 時点）

**次にやること**

1. **us 参照データ repair 適用**（残作業 #3）— レプリカで dry-run 後、合意のうえ本番: `agrr-migrate data apply --region us --kind repair`（`20260531130200`、fixture: `db/fixtures/us_reference_crops.json`）。手順: [`P7-MIGRATION-RUNBOOK.md`](./P7-MIGRATION-RUNBOOK.md)

**完了済み**

- **本番手動スモーク** **2026-06-01**（レベル 4 条件 3 — 上記観測記録）
- ローカルゲート **2026-06-01**（`p7-code-removal-gate.sh`）
- P7 Phase 1–3、URL map **`rust-backend`**、`Dockerfile.production` 廃止、本番 **`agrr-server` 単体**（2026-05-31）

## 関連

- [`P7-EXIT-CHECKLIST.md`](./P7-EXIT-CHECKLIST.md) — Rails 廃止チェックリスト
- [`P7-MIGRATION-RUNBOOK.md`](./P7-MIGRATION-RUNBOOK.md) — schema / data CLI
- [`README.md`](./README.md) — 索引
