# 本番 Rust カットオーバー — 残作業と観測記録

> **最終観測**: 2026-05-31（gcloud / curl / 本番レプリカ / `run-rust-contract-tests.sh` / `p7-code-removal-gate.sh`）  
> **完了条件**: [`P6-COMPLETION-CRITERIA.md`](./P6-COMPLETION-CRITERIA.md) レベル 4・5  
> **デプロイ**: [`.cursor/skills/deploy-server/scripts/gcp-deploy-rust.sh`](../../../.cursor/skills/deploy-server/scripts/gcp-deploy-rust.sh)（test: [`deploy-rust-backend.sh test`](../../../.cursor/skills/gcp-test-local/scripts/deploy-rust-backend.sh)）  
> **手順**: [`.cursor/skills/gcp-test-local/scripts/prod-rust-cutover-checklist.sh`](../../../.cursor/skills/gcp-test-local/scripts/prod-rust-cutover-checklist.sh)

## サマリー（2026-05-31）

| 観点 | 状態 |
|------|------|
| 本番 API トラフィック | **Rust（`agrr-server`）** — LB 上の backend 名は `agrr-rails-backend` のままだが、NEG は `agrr-production`（Rust イメージ） |
| P6 レベル 4（本番ストラングラー・トラフィック） | **実質達成**（指紋・501 フォールバック・契約テスト GREEN） |
| P7 コード削除 Phase 1 | **実施済み**（2026-05-31）— `app/controllers/api`・jobs・channels・API adapters 削除 |
| P7 コード削除 Phase 2（`lib/domain`） | **実施済み**（2026-05-31）— `lib/domain/`・`test/domain/` 削除 |
| P7 Phase 3（Solid Cable DB） | **実施済み**（2026-05-31）— `database.yml` の cable DB・Litestream cable レプリカ削除。Rails は `/cable` 非マウント |
| 本番 DB データ | **in repair 適用済み**（レプリカ確認）。**us 参照作物 7 件**は stages 欠損のまま |

## 残作業

| # | 項目 | 備考 |
|---|------|------|
| 1 | URL map の **命名整理**（任意・**スキップ可**） | GCP 上の backend **リソース名**（`agrr-rails-backend`）のみ。`agrr.net` のパス・NEG 先（`agrr-production`）は既に Rust。**リネームしなくても本番挙動は変わらない**（[`ADR-strangler-lb-url-map.md`](./ADR-strangler-lb-url-map.md) の `rust-backend` は論理名）。実施する場合のみ `url-maps validate` → `import` で手順ミスに注意 |
| 2 | 本番 **手動スモーク** | OAuth ログイン、`auth/me`、計画作成→最適化 WS、マスタ CRUD、`save_plan`、`POST /undo_deletion` |
| 3 | 本番 **us 参照データ**（必要時） | 7 件の `crop_stages` 欠損。`in` repair では直らない。運用合意のうえ `agrr-migrate data apply` |
| 4 | **P7** Rails 資産削除（残） | [`P7-EXIT-CHECKLIST.md`](./P7-EXIT-CHECKLIST.md) — URL map 命名・Rails 本番イメージ廃止など |

**ローカルゲート**（削除 PR 前に再実行）: `cargo build -p agrr-server` + `COVERAGE=false ./scripts/run-rust-contract-tests.sh` + [`scripts/p7-code-removal-gate.sh`](../../../scripts/p7-code-removal-gate.sh)（2026-05-31: contract **112 runs, 0 failures**、p7 gate **OK**）。

**完了済み（旧「残作業」から外す）**:

- 本番 `agrr-production` を `Dockerfile.agrr-server` でデプロイ — `agrr-server:20260531-222952`
- 本番 refinery — レプリカで `schema verify OK`（`refinery_schema_history` + `data_migration_history` あり）
- 本番 in repair — `20260531120000` / `20260531130100` 適用済み（レプリカ）

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
| `/api/*` | `agrr-rails-backend` | `agrr-rails-neg` → **`agrr-production`（Rust）** |
| `/cable`, `/cable/*` | `agrr-rails-backend` | 同上 |
| `/auth`, `/auth/*` | `agrr-rails-backend` | 同上 |
| `/up` | `agrr-rails-backend` | 同上 |

専用 `rust-backend` backend service は **未作成**（1 NEG / 1 Cloud Run に集約）。

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

## 推奨実施順（更新）

1. 手動スモーク（上記 #2）
2. us 7 件の修復方針（運用合意・必要なら `data apply`）
3. P7 Phase 1 — ゲート済み Rails API / jobs / channels 削除 PR
4. P7 Phase 2 — `lib/domain` 削除（`p7-code-removal-gate.sh` 再実行後）
5. URL map 命名整理・Rails Cloud Run 廃止（P7 完了）

## 関連

- [`P7-EXIT-CHECKLIST.md`](./P7-EXIT-CHECKLIST.md) — Rails 廃止チェックリスト
- [`P7-MIGRATION-RUNBOOK.md`](./P7-MIGRATION-RUNBOOK.md) — schema / data CLI
- [`README.md`](./README.md) — 索引
