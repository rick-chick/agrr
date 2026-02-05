# GCP Test Environment Setup

このドキュメントでは、productionと同等の独立したtest環境をGCPに構築する手順を説明します。

## ⚠️ 重要：デプロイ順序

**通常のベストプラクティス**: まずtest環境をデプロイして動作確認してから、production環境にデプロイします。

### 推奨フロー
1. **Test環境のデプロイ** → 動作確認
2. **Production環境へのデプロイ** → 本番運用

### 現在の状況
- Production: 既に稼働中（過去にデプロイ済み）
- Test: このドキュメントで新規作成

> 💡 **注意**: 現在はProductionが先に稼働していますが、今後の変更はTest環境で先にテストすることを推奨します。

## クイックセットアップ

### 前提条件
- GCPプロジェクトへの適切な権限（Storage Admin）
- gcloud CLIのインストールと認証
- Dockerのインストール

### 1. 環境変数の設定

```bash
# .env.gcp.testを作成
cp env.gcp.test.example .env.gcp.test

# 必要に応じて編集
vi .env.gcp.test
```

### 2. GCS Bucketの作成（手動）

Storage Admin権限を持つユーザーアカウントで実行：

```bash
# Bucketを作成
gsutil mb -l asia-northeast1 gs://agrr-test-db

# Service Accountに権限を付与
gsutil iam ch serviceAccount:cloud-run-agrr@agrr-475323.iam.gserviceaccount.com:objectAdmin gs://agrr-test-db
```

または、セットアップスクリプトを実行して状態を確認：

```bash
./scripts/setup-test-bucket.sh
```

### 3. デプロイ

```bash
# デプロイ実行
./scripts/gcp-deploy-test.sh deploy
```

これで完了です。

## 概要

test環境は以下の特徴を持ちます：
- productionとは完全に独立したCloud Runサービス
- 独自のGCSバケット (`agrr-test-db`) を使用
- 独自のLitestream設定でデータベースを管理
- productionと同じ構成（Dockerfile、起動スクリプトなど）


## Quick: deploy Angular to the test environment (new script)

This project includes `scripts/gcp-frontend-deploy.sh` to build and deploy the Angular app to a GCS bucket and optionally invalidate Cloud CDN.

Example: create a test bucket and grant the CI service account deploy rights.

1. Create a bucket (replace placeholders):
```bash
PROJECT_ID=your-gcp-project
REGION=us-central1
TEST_BUCKET_NAME=your-project-frontend-test

gcloud config set project "$PROJECT_ID"
gsutil mb -l "$REGION" -p "$PROJECT_ID" gs://"$TEST_BUCKET_NAME"
```

2. Grant the CI service account minimal deploy permissions:
```bash
SA_EMAIL=ci-deployer@${PROJECT_ID}.iam.gserviceaccount.com

# Allow uploading and setting metadata
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/storage.objectAdmin"

# Allow CDN invalidation (URL map invalidation). Adjust role to match org policy.
gcloud projects add-iam-policy-binding "$PROJECT_ID" \
  --member="serviceAccount:${SA_EMAIL}" \
  --role="roles/compute.loadBalancerAdmin"
```

3. Create a `.env.gcp.frontend.test` with at least:
```
PROJECT_ID=your-gcp-project
REGION=us-central1
BUCKET_NAME=your-project-frontend-test
API_BASE_URL=https://api-test.example.com
URL_MAP_NAME=your-url-map-name    # optional, for CDN invalidation
```

4. Deploy (locally or from CI):
```bash
# Dry-run:
DRY_RUN=1 ./scripts/gcp-frontend-deploy.sh deploy test

# Real deploy:
./scripts/gcp-frontend-deploy.sh deploy test
```

Notes:
- The script will build the app, inject `window.API_BASE_URL` into `index.html`, sync files to the bucket, set Cache-Control metadata (no-cache for index.html, long TTL for hashed assets), and invalidate Cloud CDN if `URL_MAP_NAME` is set.
- Ensure `gcloud` and `gsutil` are authenticated with a service account that has the roles granted above (CI uses a service account JSON configured in Secrets).
