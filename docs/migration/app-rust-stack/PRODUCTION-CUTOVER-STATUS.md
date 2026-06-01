# 本番 Rust カットオーバー — 完了（2026-06-01）

> **状態**: P6 レベル 4・P7 **クローズ**（本番 `agrr.net` 確認済み）  
> **完了条件の定義（履歴）**: [`../archive/P6-COMPLETION-CRITERIA.md`](../archive/P6-COMPLETION-CRITERIA.md)  
> **data repair 手順**: [`P7-MIGRATION-RUNBOOK.md`](./P7-MIGRATION-RUNBOOK.md)  
> **ローカルゲート**: [`scripts/p7-code-removal-gate.sh`](../../../scripts/p7-code-removal-gate.sh)

## サマリー

| 観点 | 状態 |
|------|------|
| 本番 API / WS / OAuth | **Rust**（`agrr-server` on `agrr-production`、LB **`rust-backend`**) |
| P6 レベル 4 | **達成**（LB・ヘルス・手動スモーク 2026-06-01） |
| P7 本番経路からの Rails 削除 | **完了**（2026-05-31） |
| 本番 DB repair | **in** `20260531120000`/`20260531130100`、**us** `20260531130200`（2026-06-01 確認済み） |
| ローカルゲート | **2026-06-01 OK**（R4 109 runs, 0 failures） |

**移行プログラムの残作業: なし。**

## P7 出口チェックリスト（すべて完了）

| # | 項目 | 完了 |
|---|------|------|
| 1 | URL map `rust-backend` | 2026-05-31 |
| 2 | `lib/domain/` 削除 | 2026-05-31 |
| 3 | Rails API adapter / Solid Cable DB 削除 | 2026-05-31 |
| 4 | refinery（[`P7-REFINERY-ADR.md`](./P7-REFINERY-ADR.md)） | 2026-05-31 |
| 5 | R4 contract on Rust GREEN | 2026-06-01 |
| 6 | 本番 Cloud Run Rust 単体 + Litestream | 2026-05-31 |
| 7 | 参照データ repair（in / us、手動 `data apply`） | 2026-06-01 |

## P7「削除」の境界（リポジトリに Rails が残る理由）

| 区分 | 内容 |
|------|------|
| **削除済み** | `app/controllers/api/`、`lib/domain/`、`test/domain/`、API jobs/channels、大半の API adapters、`Dockerfile.production`、Solid Cable DB |
| **本番** | `/api/*` `/cable` `/auth/*` → `agrr-server` のみ |
| **P8.6 後の残存** | `config/**` 等の遺産ファイルのみ（[`P8-RAILS-SHELL-REMOVAL.md`](./P8-RAILS-SHELL-REMOVAL.md)）。`auth_test` は agrr-server の dev ルート |

レベル 5 は「本番で Rails API 不要」（P6）。リポジトリからの Rails 除去は P8 完了（[`P8-RAILS-SHELL-REMOVAL.md`](./P8-RAILS-SHELL-REMOVAL.md)）。

## 本番確認記録（2026-06-01）

手動スモーク（`agrr.net`）: OAuth、`auth/me`、計画→最適化 WS、マスタ CRUD、`save_plan`、`POST /undo_deletion` — **OK**。

## 運用メモ（移行後）

- **デプロイ**: [`.cursor/skills/deploy-server/scripts/gcp-deploy.sh`](../../../.cursor/skills/deploy-server/scripts/gcp-deploy.sh)
- **レプリカ照会**（読み取り専用）: [production-primary-sqlite-query](../../../.cursor/skills/production-primary-sqlite-query/SKILL.md)、[`scripts/refresh-production-primary-replica.sh`](../../../scripts/refresh-production-primary-replica.sh)
- **一括 data migrate（再実行時）**: [`scripts/production-data-migrate-inner.sh`](../../../scripts/production-data-migrate-inner.sh) — in/us は `kind=repair`

## 関連

- [`README.md`](./README.md) — 索引
- [`P8-RAILS-SHELL-REMOVAL.md`](./P8-RAILS-SHELL-REMOVAL.md) — リポジトリから Rails を外す（P7 後）
- [`../archive/TRACKING-P6.yaml`](../archive/TRACKING-P6.yaml) — BC 切替（全 `done`、履歴）
