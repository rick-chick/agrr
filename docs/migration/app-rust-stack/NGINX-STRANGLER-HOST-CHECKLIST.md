# nginx strangler host checklist (`docker/nginx-strangler-host.conf`)

> **方針（2026-05-29）**: **Rails フォールバックなし**。`location /api/` → Rust。未登録パスは agrr-server **501** `api_not_migrated`。`location /` は **404**（API を Rails に送らない）。
>
> 開発: `./scripts/rust-only-dev-stack.sh`（`AGRR_RUST_API=1`）または `./scripts/e2e-strangler-stack.sh`。

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

## 実装ギャップ（501 になりうる — Rust 側で実装）

- `POST /api/v1/public_plans/plans`（wizard create）— 要確認
- `POST` AI create 系（`crops/ai_create` 等）— Angular 未使用なら 501 可
- `backdoor` — スコープ外なら 501

## 検証

```bash
./scripts/verify-angular-api-rust-routing.sh  # フロントパスと route 文字列
AGRR_SERVER_CONTRACT_REBUILD=1 COVERAGE=false ./scripts/run-rust-contract-tests.sh
```
