# GCP CloudRun デプロイガイド - 環境変数制御版

## 概要

1つのDockerイメージで環境変数 `USE_AGRR_DAEMON` によりCLI版とDaemon版を切り替え可能です。

## ⚡ 最速デプロイ（推奨）

既存の`gcp-deploy.sh`スクリプトを使用：

```bash
# CLI版（デフォルト）
./scripts/gcp-deploy.sh

# Daemon版（高頻度アクセス向け）
USE_AGRR_DAEMON=true ./scripts/gcp-deploy.sh
```

詳細は [DEPLOYMENT_GCP_SIMPLE.md](DEPLOYMENT_GCP_SIMPLE.md) を参照してください。

---

## 手動デプロイ

### 1. Dockerイメージのビルド

#### オプションA: CLI版のみ（agrr binary不要）

```bash
# agrr binaryなしでビルド（CLI版のみ）
docker build -f Dockerfile.production -t gcr.io/PROJECT_ID/agrr-app:latest .
```

#### オプションB: Daemon版対応（agrr binaryを含む）

```bash
# 1. agrr binaryをビルド
cd lib/core/agrr_core
./build_standalone.sh --onefile
cp dist/agrr ../agrr
cd ../../..

# 2. Dockerイメージをビルド（agrr binary含む）
docker build -f Dockerfile.production -t gcr.io/PROJECT_ID/agrr-app:latest .
```

### 2. GCRにプッシュ

```bash
# GCPプロジェクトID設定
export PROJECT_ID="your-gcp-project-id"

# 認証
gcloud auth configure-docker

# プッシュ
docker push gcr.io/${PROJECT_ID}/agrr-app:latest
```

### 3. CloudRunにデプロイ

#### パターンA: CLI版としてデプロイ（推奨）

```bash
gcloud run deploy agrr-app \
  --image gcr.io/${PROJECT_ID}/agrr-app:latest \
  --platform managed \
  --region asia-northeast1 \
  --set-env-vars "USE_AGRR_DAEMON=false" \
  --min-instances=0 \
  --max-instances=10 \
  --memory 1.5Gi \
  --cpu 1 \
  --allow-unauthenticated
```

#### パターンB: Daemon版としてデプロイ

```bash
gcloud run deploy agrr-app-daemon \
  --image gcr.io/${PROJECT_ID}/agrr-app:latest \
  --platform managed \
  --region asia-northeast1 \
  --set-env-vars "USE_AGRR_DAEMON=true" \
  --min-instances=1 \
  --max-instances=10 \
  --memory 2Gi \
  --cpu 1 \
  --allow-unauthenticated
```

## 環境変数制御の仕組み

### `USE_AGRR_DAEMON`

| 値 | 動作 | 起動時間 | メモリ | 推奨最小インスタンス |
|----|------|----------|--------|---------------------|
| `false` または未設定 | CLI版（デフォルト） | 2.4s | 1.5GB | 0 |
| `true` | Daemon版 | 初回: 2.4s<br>2回目以降: 0.5s | 1.7GB | 1 |

### 起動ログで確認

#### CLI版
```
=== Starting Rails Application with Litestream ===
Port: 3000
AGRR Daemon Mode: false
...
Step 3: Skipping agrr daemon (USE_AGRR_DAEMON not set to 'true')
```

#### Daemon版
```
=== Starting Rails Application with Litestream + agrr daemon ===
Port: 3000
AGRR Daemon Mode: true
...
Step 3: Starting agrr daemon...
✓ agrr daemon started (PID: 1234)
```

## 実践例

### 例1: 開発環境とプロダクション環境で分ける

```bash
# 開発環境: CLI版（コスト重視）
gcloud run deploy agrr-app-dev \
  --image gcr.io/${PROJECT_ID}/agrr-app:latest \
  --set-env-vars "USE_AGRR_DAEMON=false" \
  --min-instances=0 \
  --memory 1.5Gi

# プロダクション環境: Daemon版（パフォーマンス重視）
gcloud run deploy agrr-app-prod \
  --image gcr.io/${PROJECT_ID}/agrr-app:latest \
  --set-env-vars "USE_AGRR_DAEMON=true" \
  --min-instances=1 \
  --memory 2Gi
```

### 例2: トラフィック分割でA/Bテスト

```bash
# 1. Daemon版をデプロイ（トラフィック0%）
gcloud run deploy agrr-app \
  --image gcr.io/${PROJECT_ID}/agrr-app:latest \
  --set-env-vars "USE_AGRR_DAEMON=true" \
  --min-instances=1 \
  --no-traffic

# 2. トラフィックを徐々に移行
gcloud run services update-traffic agrr-app \
  --to-revisions=LATEST=10,PREVIOUS=90

# 3. 問題なければ100%に
gcloud run services update-traffic agrr-app \
  --to-latest
```

### 例3: 環境変数のみを変更

```bash
# 既存のCLI版をDaemon版に変更（イメージは同じ）
gcloud run services update agrr-app \
  --set-env-vars "USE_AGRR_DAEMON=true" \
  --min-instances=1 \
  --memory 2Gi

# 再びCLI版に戻す
gcloud run services update agrr-app \
  --set-env-vars "USE_AGRR_DAEMON=false" \
  --min-instances=0 \
  --memory 1.5Gi
```

## YAML設定ファイル

### CLI版（service-cli.yaml）

```yaml
apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: agrr-app-cli
  labels:
    cloud.googleapis.com/location: asia-northeast1
spec:
  template:
    metadata:
      annotations:
        autoscaling.knative.dev/minScale: "0"
        autoscaling.knative.dev/maxScale: "10"
    spec:
      containerConcurrency: 80
      timeoutSeconds: 300
      containers:
      - image: gcr.io/PROJECT_ID/agrr-app:latest
        env:
        - name: USE_AGRR_DAEMON
          value: "false"
        - name: RAILS_ENV
          value: "production"
        - name: RAILS_LOG_TO_STDOUT
          value: "true"
        resources:
          limits:
            cpu: "1000m"
            memory: 1.5Gi
```

### Daemon版（service-daemon.yaml）

```yaml
apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: agrr-app-daemon
  labels:
    cloud.googleapis.com/location: asia-northeast1
spec:
  template:
    metadata:
      annotations:
        autoscaling.knative.dev/minScale: "1"  # 常時起動
        autoscaling.knative.dev/maxScale: "10"
    spec:
      containerConcurrency: 80
      timeoutSeconds: 300
      containers:
      - image: gcr.io/PROJECT_ID/agrr-app:latest
        env:
        - name: USE_AGRR_DAEMON
          value: "true"
        - name: RAILS_ENV
          value: "production"
        - name: RAILS_LOG_TO_STDOUT
          value: "true"
        resources:
          limits:
            cpu: "1000m"
            memory: 2Gi
```

デプロイ：
```bash
gcloud run services replace service-cli.yaml
gcloud run services replace service-daemon.yaml
```

## トラブルシューティング

### 1. Daemon版で起動しない

```bash
# ログ確認
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=agrr-app" --limit 50

# 確認ポイント
# ✓ "AGRR Daemon Mode: true" が表示されているか
# ✓ "agrr binary not found" が表示されていないか
```

**対処**: agrr binary がイメージに含まれていない場合、再ビルドが必要
```bash
cd lib/core/agrr_core
./build_standalone.sh --onefile
cp dist/agrr ../agrr
cd ../../..
docker build -f Dockerfile.production -t gcr.io/${PROJECT_ID}/agrr-app:latest .
docker push gcr.io/${PROJECT_ID}/agrr-app:latest
```

### 2. メモリ不足エラー

```bash
# メモリを増やす
gcloud run services update agrr-app --memory 2.5Gi
```

### 3. 環境変数が反映されない

```bash
# 現在の環境変数を確認
gcloud run services describe agrr-app --format="value(spec.template.spec.containers[0].env)"

# 環境変数を更新（既存の値を上書き）
gcloud run services update agrr-app \
  --update-env-vars "USE_AGRR_DAEMON=true"

# 環境変数を削除
gcloud run services update agrr-app \
  --remove-env-vars "USE_AGRR_DAEMON"
```

## コスト最適化

### CLI版（低コスト）
- 最小インスタンス: 0
- メモリ: 1.5Gi
- 月額: $0-10（リクエスト時のみ課金）

### Daemon版（パフォーマンス優先）
- 最小インスタンス: 1
- メモリ: 2Gi
- 月額: $30-50（常時稼働）

### 推奨設定

| トラフィック | 推奨モード | 最小インスタンス |
|-------------|-----------|----------------|
| < 100 req/日 | CLI | 0 |
| 100-1000 req/日 | CLI | 0-1 |
| > 1000 req/日 | CLI or Daemon | 1 |
| > 10000 req/日 | Daemon | 1-3 |

## まとめ

### メリット
- ✅ 1つのイメージで両モード対応
- ✅ 環境変数のみで切り替え可能
- ✅ デプロイ後も変更が容易
- ✅ A/Bテストが簡単

### 注意点
- ⚠️ Daemon版にはagrr binaryが必要
- ⚠️ Daemon版は最小インスタンス=1推奨
- ⚠️ デフォルトはCLI版

### 推奨フロー
1. まずCLI版でデプロイ（`USE_AGRR_DAEMON=false`）
2. トラフィック増加に応じてDaemon版を検討
3. 環境変数を変更するだけで切り替え可能

詳細は [docs/ENVIRONMENT_VARIABLES.md](docs/ENVIRONMENT_VARIABLES.md) を参照してください。

