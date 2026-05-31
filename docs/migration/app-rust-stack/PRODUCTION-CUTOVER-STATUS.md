# 本番 Rust カットオーバー — 完了状態と観測記録

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
| 本番 DB データ | **in / us repair 適用済み**（運用申告 2026-06-01。`20260531130200` 含む） |

## 移行プログラムの残作業

**なし**（2026-06-01 — 本番 `agrr.net` で手動スモーク・in/us repair まで運用確認済み）。通常の機能デプロイ・PR マージは**本移行の残タスクではない**。

## P7「削除」— 済んでいることと残っていること

本番 API/WS から Rails を外す **P7 の削除は 2026-05-31 に完了**している。進んでいないように見えるのは、**リポジトリから Rails 全体を消したわけではない**ため。

| 区分 | 状態 | 例 |
|------|------|-----|
| **削除済み（本番経路）** | 完了 | `app/controllers/api/`、`lib/domain/`、`test/domain/`、API jobs/channels、API 用 adapters、`Dockerfile.production`、Solid Cable DB |
| **本番は Rust のみ** | 完了 | LB → `agrr-server`（`/api/*` `/cable` `/auth/*`） |
| **意図的に残存（開発・テスト用 Rails シェル）** | 別スコープ | `spa#index`、静的ページ、`auth_test`、[`config/routes.rb`](../../../config/routes.rb) の dev ルート、Rails テスト基盤（`docker compose` / `run-test-rails.sh`）、一部 `app/adapters`（auth_test 等） |

**レベル 5（P7）の定義**は [`P6-COMPLETION-CRITERIA.md`](./P6-COMPLETION-CRITERIA.md) — 「本番で Rails API に依存しない」であり、「`Gemfile` や Rails プロジェクトの全消し」ではない。

**ローカルゲート**: [`scripts/p7-code-removal-gate.sh`](../../../scripts/p7-code-removal-gate.sh) 1 本で足りる（内部で build + R4 契約 + `agrr-migrate`）。**2026-06-01: OK**（109 runs, 0 failures）。Rust / 起動スクリプトを変えたマージ前のみ再実行。

**完了済み（旧「残作業」から外す）**:

- URL map backend 名 **`rust-backend`** へ整理（2026-05-31）— `agrr-rails-backend` 削除、`agrr.net` `/up`・`/api/v1/health` スモーク OK
- **`Dockerfile.production` 廃止**（2026-05-31）— 本番デプロイは `Dockerfile.agrr-server` のみ（`gcp-deploy.sh` → refinery / Litestream）
- 本番 `agrr-production` を `Dockerfile.agrr-server` でデプロイ — `agrr-server:20260531-222952`
- 本番 refinery — レプリカで `schema verify OK`（`refinery_schema_history` + `data_migration_history` あり）
- 本番 in repair — `20260531120000` / `20260531130100` 適用済み
- 本番 us repair — `20260531130200` 適用済み（2026-06-01）
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
| `us` 参照・stages なし | **7**（**2026-05-31 レプリカ時点**。us repair 適用後は本番確認済み — 下記 2026-06-01） |

> **注意**: この節はカットオーバー直後のレプリカ観測の**履歴**。2026-06-01 時点の本番確認で us repair・手動スモークは OK のため、現状の「残課題」ではない。

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
| us 参照データ repair（`20260531130200`） | OK（本番確認済み） |
| 記録 | 運用確認済み |

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

## クローズ（2026-06-01）

**Rust 本番移行（P6 レベル 4・P7）はクローズ。** 本番確認（スモーク・in/us repair）まで含めて完了。

以降の「Rails 関連」は **別プログラム**（例: 開発用 Rails シェル縮小、`ARCHITECTURE.md` の記述を Rust 正に合わせる）であり、本ドキュメントの残作業ではない。

## 関連

- [`P7-EXIT-CHECKLIST.md`](./P7-EXIT-CHECKLIST.md) — Rails 廃止チェックリスト
- [`P7-MIGRATION-RUNBOOK.md`](./P7-MIGRATION-RUNBOOK.md) — schema / data CLI
- [`README.md`](./README.md) — 索引
