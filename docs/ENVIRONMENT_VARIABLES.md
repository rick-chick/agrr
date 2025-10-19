# 環境変数リファレンス

## AGRR Daemon制御

### `USE_AGRR_DAEMON`

agrr daemonモードを有効化するかどうかを制御します。

**値**:
- `true` - daemon モードを有効化（高速起動）
- `false` または未設定 - CLI モード（デフォルト）

**用途**:
- CloudRunデプロイ時に環境変数として設定
- 同じDockerイメージでCLI版とDaemon版を切り替え可能

**設定例**:

```bash
# CloudRunでdaemonモードを有効化
gcloud run deploy agrr-app \
  --image gcr.io/PROJECT_ID/agrr-app:latest \
  --set-env-vars "USE_AGRR_DAEMON=true" \
  --min-instances=1 \
  --memory 2Gi

# CloudRunでCLIモード（デフォルト）
gcloud run deploy agrr-app \
  --image gcr.io/PROJECT_ID/agrr-app:latest \
  --set-env-vars "USE_AGRR_DAEMON=false" \
  --min-instances=0
```

**注意**:
- daemon モードを有効化するには、事前に agrr binary をビルドしてイメージに含める必要があります
- agrr binary がイメージに含まれていない場合、`USE_AGRR_DAEMON=true`でも自動的にスキップされます

## パフォーマンス影響

| モード | 起動時間 | メモリ | 推奨最小インスタンス | 月額コスト |
|--------|----------|--------|---------------------|-----------|
| CLI (USE_AGRR_DAEMON=false) | 2.4s | 1.5GB | 0 | $0-10 |
| Daemon (USE_AGRR_DAEMON=true) | 初回: 2.4s<br>2回目以降: 0.5s | 1.7GB | 1 | $30-50 |

## 使い分けガイド

### CLI モード（`USE_AGRR_DAEMON=false` or 未設定）を推奨

- ✅ コスト最適化が優先
- ✅ リクエスト頻度が低い（1日数回〜数百回）
- ✅ シンプルな運用を優先
- ✅ agrr binary のビルドが面倒

### Daemon モード（`USE_AGRR_DAEMON=true`）を推奨

以下を**すべて満たす**場合のみ：
- ✅ 最小インスタンス=1で運用している
- ✅ リクエスト頻度が高い（1時間10回以上）
- ✅ agrr実行が頻繁（リクエストの50%以上）
- ✅ 常時稼働のコストが許容できる
- ✅ agrr binary をビルド済み

## 実装例

### CloudRun yaml

```yaml
# CLI モード
apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: agrr-app-cli
spec:
  template:
    metadata:
      annotations:
        autoscaling.knative.dev/minScale: "0"
        autoscaling.knative.dev/maxScale: "10"
    spec:
      containers:
      - image: gcr.io/PROJECT_ID/agrr-app:latest
        env:
        - name: USE_AGRR_DAEMON
          value: "false"
        resources:
          limits:
            memory: 1.5Gi
            cpu: "1"

---
# Daemon モード
apiVersion: serving.knative.dev/v1
kind: Service
metadata:
  name: agrr-app-daemon
spec:
  template:
    metadata:
      annotations:
        autoscaling.knative.dev/minScale: "1"  # 常時起動
        autoscaling.knative.dev/maxScale: "10"
    spec:
      containers:
      - image: gcr.io/PROJECT_ID/agrr-app:latest
        env:
        - name: USE_AGRR_DAEMON
          value: "true"
        resources:
          limits:
            memory: 2Gi
            cpu: "1"
```

### docker-compose.yml

```yaml
services:
  # CLI モード
  web-cli:
    build:
      context: .
      dockerfile: Dockerfile.production
    environment:
      - USE_AGRR_DAEMON=false
    ports:
      - "3000:3000"

  # Daemon モード
  web-daemon:
    build:
      context: .
      dockerfile: Dockerfile.production
    environment:
      - USE_AGRR_DAEMON=true
    ports:
      - "3001:3000"
```

### ローカルテスト

```bash
# CLI モードでテスト
docker run --rm -p 3000:3000 \
  -e USE_AGRR_DAEMON=false \
  -e RAILS_ENV=production \
  -e SECRET_KEY_BASE=dummy \
  agrr-app:latest

# Daemon モードでテスト
docker run --rm -p 3000:3000 \
  -e USE_AGRR_DAEMON=true \
  -e RAILS_ENV=production \
  -e SECRET_KEY_BASE=dummy \
  agrr-app:latest

# ログで確認
# CLI: "Skipping agrr daemon (USE_AGRR_DAEMON not set to 'true')"
# Daemon: "✓ agrr daemon started (PID: xxxx)"
```

## トラブルシューティング

### daemon モードで起動しない

**症状**: `USE_AGRR_DAEMON=true` を設定しても daemon が起動しない

**原因と対処**:

1. **agrr binary がイメージに含まれていない**
   ```bash
   # 確認
   docker run --rm agrr-app:latest ls -lh /usr/local/bin/agrr
   
   # agrr binaryをビルド
   cd lib/core/agrr_core
   ./build_standalone.sh --onefile
   cp dist/agrr ../agrr
   cd ../../..
   
   # イメージを再ビルド
   docker build -f Dockerfile.production -t agrr-app:latest .
   ```

2. **パーミッション不足**
   ```bash
   # /tmp のパーミッションを確認
   docker run --rm agrr-app:latest ls -ld /tmp
   ```

3. **メモリ不足**
   ```bash
   # メモリを増やす
   gcloud run services update agrr-app --memory 2Gi
   ```

### CLI モードで動作確認

```bash
# ログで確認
gcloud logging read "resource.type=cloud_run_revision" --limit 10

# 期待される出力
# "Step 3: Skipping agrr daemon (USE_AGRR_DAEMON not set to 'true')"
```

### Daemon モードで動作確認

```bash
# ログで確認
gcloud logging read "resource.type=cloud_run_revision AND textPayload=~\"agrr daemon\"" --limit 10

# 期待される出力
# "Step 3: Starting agrr daemon..."
# "✓ agrr daemon started (PID: xxxx)"
```

## まとめ

- **デフォルトはCLI モード** - `USE_AGRR_DAEMON` 未設定またはfalse
- **Daemon モードは特殊ケース** - `USE_AGRR_DAEMON=true`
- **同じイメージで切り替え可能** - 環境変数のみで制御
- **agrr binary は事前ビルドが必要** - Daemon モード利用時のみ

詳細は以下を参照：
- [DEPLOYMENT_VARIANTS.md](DEPLOYMENT_VARIANTS.md) - 詳細な使い分けガイド
- [DAEMON_CLOUDRUN_ANALYSIS.md](DAEMON_CLOUDRUN_ANALYSIS.md) - 技術分析
- [QUICK_START_DAEMON.md](../QUICK_START_DAEMON.md) - クイックスタート

