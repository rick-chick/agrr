---
name: deploy-server
description: Deploy the backend to GCP Cloud Run (production). agrr-server only (Dockerfile.agrr-server). Use when the user asks to deploy server, backend, Rust, agrr-server, or production server.
---

# サーバーデプロイ (Production)

本番 Cloud Run（`agrr-production`）へ **agrr-server**（Rust）をデプロイする。Rails 本番イメージ（`Dockerfile.production`）は P7 で廃止済み。

## 前提条件

- `gcloud` CLI がインストール・認証済み (`gcloud auth login`)
- Docker が起動中
- `.env.gcp` がプロジェクトルートに存在 (`env.gcp.example` から作成)

## デプロイ手順

### 1. 事前確認

```
Task Progress:
- [ ] masterブランチにいるか（意図しないブランチからのデプロイを防止）
- [ ] 未コミットの変更がないか
- [ ] テストが通っているか
- [ ] .env.gcp が存在するか
```

```bash
git branch --show-current
git status --short
```

### 2. デプロイ実行

`gcp-deploy` は docker build 前に `scripts/ensure-reference-fixtures.sh`（`AGRR_FIXTURES_REQUIRED=1`）で天気 fixture を GCS から取得する。初回は `gcloud auth application-default login` が必要。

```bash
.cursor/skills/deploy-server/scripts/gcp-deploy.sh
# または明示:
.cursor/skills/deploy-server/scripts/gcp-deploy-rust.sh
```

GCP test: [`.cursor/skills/gcp-test-local/scripts/deploy-rust-backend.sh test`](../gcp-test-local/scripts/deploy-rust-backend.sh)

| 項目 | 値 |
|------|-----|
| Dockerfile | [`Dockerfile.agrr-server`](../../../Dockerfile.agrr-server) |
| イメージ | `agrr-server:YYYYMMDD-HHMMSS`（`RUST_IMAGE_NAME`） |
| エントリ | [`scripts/start_agrr_server.sh`](../../../scripts/start_agrr_server.sh) |
| ポート | 8080 |
| `/up` | 本文 `ok` |
| スキーマ | 起動時 `agrr-migrate schema run`（refinery） |

共通処理（[`_agrr-server-cloud-run.sh`](scripts/_agrr-server-cloud-run.sh)）:
1. 前提条件（`.env.gcp`、`master` ブランチ — `SKIP_GIT_CHECKS=1` で省略可）
2. ビルド・Artifact Registry へ push（`:latest` も更新）
3. Cloud Run `agrr-production` へデプロイ（`SCHEDULER_AUTH_TOKEN` は Secret `scheduler-auth-token`）
4. ヘルスチェック（本番は `https://agrr.net/up` 等 LB 経由。`ingress=internal-and-cloud-load-balancing` のため `*.run.app/up` は 404）

### 3. デプロイ後の確認

```bash
gcloud run services describe agrr-production --region asia-northeast1 --project agrr-475323 --format 'value(status.url)'
curl -s https://agrr.net/up   # デプロイスクリプトの本番ヘルスチェックと同じ経路
gcloud run services logs read agrr-production --region asia-northeast1 --project agrr-475323 --limit 50
```

## 主要な設定値

| 項目 | 値 |
|------|-----|
| プロジェクト | `agrr-475323` |
| リージョン | `asia-northeast1` |
| サービス名 | `agrr-production` |
| LB backend | `rust-backend`（[`scripts/agrr-frontend-url-map-simple.yaml`](../../../scripts/agrr-frontend-url-map-simple.yaml)） |

## 参照

- [P7-MIGRATION-RUNBOOK.md](../../../docs/migration/app-rust-stack/P7-MIGRATION-RUNBOOK.md) — refinery / 手動 `data apply`
- [PRODUCTION-CUTOVER-STATUS.md](../../../docs/migration/app-rust-stack/PRODUCTION-CUTOVER-STATUS.md)
