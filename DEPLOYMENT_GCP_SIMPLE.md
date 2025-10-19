# GCP CloudRunデプロイ - 簡単ガイド

## クイックスタート

### 1. 準備

```bash
# .env.gcpを作成（env.gcp.exampleからコピー）
cp env.gcp.example .env.gcp

# 必要な値を設定
# - PROJECT_ID
# - RAILS_MASTER_KEY
# - SECRET_KEY_BASE
# - GCS_BUCKET
```

### 2. デプロイ

#### CLI版（デフォルト、推奨）

```bash
./scripts/gcp-deploy.sh
```

#### Daemon版（高頻度アクセス向け）

```bash
# 1. agrr binaryをビルド（初回のみ）
cd lib/core/agrr_core
./build_standalone.sh --onefile
cp dist/agrr ../agrr
cd ../../..

# 2. Daemon版としてデプロイ
USE_AGRR_DAEMON=true ./scripts/gcp-deploy.sh
```

## 環境変数制御

### CLI版
- **環境変数**: `USE_AGRR_DAEMON=false` または未設定
- **最小インスタンス**: 0（コスト最適）
- **起動時間**: 2.4s
- **月額**: $0-10

### Daemon版
- **環境変数**: `USE_AGRR_DAEMON=true`
- **最小インスタンス**: 1（自動設定）
- **起動時間**: 初回 2.4s、2回目以降 0.5s
- **月額**: $30-50

## デプロイ後の切り替え

環境変数を変更するだけで切り替え可能：

```bash
# CLI版に変更
gcloud run services update agrr-production \
  --update-env-vars "USE_AGRR_DAEMON=false" \
  --min-instances=0

# Daemon版に変更
gcloud run services update agrr-production \
  --update-env-vars "USE_AGRR_DAEMON=true" \
  --min-instances=1
```

## スクリプトオプション

### 環境変数でカスタマイズ

```bash
# サービス名を変更
SERVICE_NAME=agrr-dev ./scripts/gcp-deploy.sh

# リージョンを変更
REGION=us-central1 ./scripts/gcp-deploy.sh

# Daemon版でデプロイ
USE_AGRR_DAEMON=true ./scripts/gcp-deploy.sh
```

### .env.gcpで設定

```bash
# .env.gcp
PROJECT_ID=your-project-id
REGION=asia-northeast1
SERVICE_NAME=agrr-production
USE_AGRR_DAEMON=false  # trueでDaemon版

RAILS_MASTER_KEY=xxx
SECRET_KEY_BASE=xxx
GCS_BUCKET=your-bucket
ALLOWED_HOSTS=xxx
```

## トラブルシューティング

### デプロイエラー

```bash
# ログ確認
gcloud run services logs read agrr-production --limit 50

# サービス詳細確認
gcloud run services describe agrr-production --region asia-northeast1
```

### Daemon版でdaemonが起動しない

```bash
# 1. agrr binaryがイメージに含まれているか確認
# ログに以下が表示されればOK:
# "✓ agrr binary and dependencies included (daemon mode available with USE_AGRR_DAEMON=true)"

# 2. 環境変数が設定されているか確認
gcloud run services describe agrr-production \
  --format="value(spec.template.spec.containers[0].env)" \
  --region asia-northeast1 | grep USE_AGRR_DAEMON

# 3. Daemon起動ログを確認
gcloud run services logs read agrr-production --limit 200 | grep -E "(Step 3|daemon)"
```

## まとめ

### デフォルト: CLI版

```bash
./scripts/gcp-deploy.sh
```

### 高頻度アクセス: Daemon版

```bash
# 初回のみagrr binaryビルド
cd lib/core/agrr_core && ./build_standalone.sh --onefile && cp dist/agrr ../agrr && cd ../../..

# デプロイ
USE_AGRR_DAEMON=true ./scripts/gcp-deploy.sh
```

**迷ったらCLI版から始めてください！** 必要に応じて環境変数を変更するだけでDaemon版に切り替えられます。

詳細は [DEPLOYMENT_GCP.md](DEPLOYMENT_GCP.md) を参照してください。

