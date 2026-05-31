# nginx strangler host checklist (`docker/nginx-strangler-host.conf`)

> **方針（2026-05-29）**: **Rails フォールバックなし**。`location /api/` → Rust。未登録パスは agrr-server **501** `api_not_migrated`。`location /` は **404**（API を Rails に送らない）。
>
> 開発: **`./scripts/dev-rust-stack.sh`** のみ。

## Rust upstream（`127.0.0.1:8080`）

| Pattern | nginx | agrr-server |
|---------|-------|-------------|
| `/health`, `/up` | `location` → rust | yes |
| `/auth/*`, `/auth/test/` | → rust | partial OAuth |
| `/cable` | → rust | WS + jobs in progress |
| `/undo_deletion` | → rust | yes |
| `/api/*` | **`location /api/`** → rust | 実装済み + catch-all 501 |

## 禁止

| パターン | 理由 |
|----------|------|
| `location /` → `rails_backend` for API | 完了定義違反 |
| 個別 `/api/v1/...` のみ列挙して残りを Rails | 廃止 — `/api/` 一括で Rust |

## パリティ確認

- ルート台帳: `tmp/api-v1-routes-ledger.md`（手動更新）
- 回帰: `scripts/run-rust-contract-tests.sh`（`test/contract/*` — PATCH・公開 mutation・AI smoke・internal 気象・backdoor 含む）

## contact_messages（仕様メモ）

- Rails routes に `GET index` があるが controller action なし
- Rust `GET /api/v1/contact_messages` は空配列 `[]`（データ非公開）

## 検証

```bash
./scripts/run-rust-contract-tests.sh  # R4 契約（Angular が叩く API の網羅）
AGRR_SERVER_CONTRACT_REBUILD=1 COVERAGE=false ./scripts/run-rust-contract-tests.sh
```
