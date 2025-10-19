# 環境変数制御 - 実装完了サマリー

## ✅ 完了内容

環境変数 `USE_AGRR_DAEMON` で CLI版とDaemon版を切り替え可能になりました。

## 📁 更新されたファイル

### 主要ファイル
1. **`scripts/start_app.sh`** - 環境変数による分岐を追加
2. **`Dockerfile.production`** - agrr binaryのオプショナル対応
3. **`docker-compose.yml`** - web-daemonサービスを環境変数制御に変更
4. **`lib/core/.dockerkeep`** - ディレクトリ存在保証

### ドキュメント
5. **`docs/ENVIRONMENT_VARIABLES.md`** - 環境変数リファレンス
6. **`DEPLOYMENT_GCP.md`** - GCP CloudRunデプロイガイド

### 不要になったファイル（削除可能）
- ~~`scripts/start_app_with_agrr_daemon.sh`~~ - start_app.shに統合
- ~~`Dockerfile.with-agrr-daemon`~~ - Dockerfile.productionに統合

## 🚀 使い方

### 基本コマンド

```bash
# CLI版（デフォルト）
docker build -f Dockerfile.production -t agrr-app:latest .
docker run -e USE_AGRR_DAEMON=false agrr-app:latest

# Daemon版
docker build -f Dockerfile.production -t agrr-app:latest .
docker run -e USE_AGRR_DAEMON=true agrr-app:latest
```

### Docker Compose

```bash
# CLI版
docker compose up web

# Daemon版
docker compose --profile daemon up web-daemon
```

### CloudRun

```bash
# 1つのイメージをビルド
docker build -f Dockerfile.production -t gcr.io/PROJECT_ID/agrr-app:latest .
docker push gcr.io/PROJECT_ID/agrr-app:latest

# CLI版としてデプロイ
gcloud run deploy agrr-app-cli \
  --image gcr.io/PROJECT_ID/agrr-app:latest \
  --set-env-vars "USE_AGRR_DAEMON=false" \
  --min-instances=0

# Daemon版としてデプロイ（同じイメージ）
gcloud run deploy agrr-app-daemon \
  --image gcr.io/PROJECT_ID/agrr-app:latest \
  --set-env-vars "USE_AGRR_DAEMON=true" \
  --min-instances=1
```

## 📊 環境変数の動作

| `USE_AGRR_DAEMON` | 動作 | 起動時間 | メモリ | 推奨最小インスタンス |
|-------------------|------|----------|--------|---------------------|
| 未設定 | CLI版（デフォルト） | 2.4s | 1.5GB | 0 |
| `false` | CLI版 | 2.4s | 1.5GB | 0 |
| `true` | Daemon版 | 初回: 2.4s<br>2回目以降: 0.5s | 1.7GB | 1 |

## 🔍 ログで確認

### CLI版
```bash
=== Starting Rails Application with Litestream ===
Port: 3000
AGRR Daemon Mode: false
...
Step 3: Skipping agrr daemon (USE_AGRR_DAEMON not set to 'true')
```

### Daemon版
```bash
=== Starting Rails Application with Litestream + agrr daemon ===
Port: 3000
AGRR Daemon Mode: true
...
Step 3: Starting agrr daemon...
✓ agrr daemon started (PID: 1234)
```

## 🏗️ アーキテクチャ

### 統合前（複数ファイル）
```
Dockerfile                    # CLI版
Dockerfile.with-agrr-daemon  # Daemon版
scripts/start_app.sh         # CLI版起動
scripts/start_app_with_agrr_daemon.sh  # Daemon版起動
```

### 統合後（環境変数制御）✅
```
Dockerfile.production        # 両対応（agrr binaryはオプショナル）
scripts/start_app.sh         # 環境変数で分岐
└─ USE_AGRR_DAEMON=true  → daemon起動
└─ USE_AGRR_DAEMON=false → daemonスキップ
```

## 🎯 メリット

1. **1つのイメージで両対応**
   - ビルドは1回だけ
   - イメージ管理が簡単

2. **デプロイ後も切り替え可能**
   - 環境変数を変更するだけ
   - イメージの再ビルド不要

3. **A/Bテストが容易**
   - トラフィック分割でテスト可能
   - ロールバックも簡単

4. **コスト最適化**
   - 環境ごとに最適モードを選択
   - dev: CLI、prod: Daemon など

## ⚙️ 実装詳細

### scripts/start_app.sh の変更点

```bash
# 環境変数チェック
if [ "${USE_AGRR_DAEMON}" = "true" ]; then
    echo "=== Starting with agrr daemon ==="
    # daemon起動処理
    /usr/local/bin/agrr daemon start
else
    echo "=== Starting without daemon ==="
    # daemonスキップ
fi

# cleanup時もdaemon停止
cleanup() {
    if [ "${USE_AGRR_DAEMON}" = "true" ]; then
        /usr/local/bin/agrr daemon stop
    fi
}
```

### Dockerfile.production の変更点

```dockerfile
# agrr binaryをオプショナルにコピー
COPY --chown=appuser:appuser lib/core/ /tmp/agrr_temp/
RUN if [ -f /tmp/agrr_temp/agrr ]; then \
        mv /tmp/agrr_temp/agrr /usr/local/bin/agrr && \
        echo "✓ agrr binary included"; \
    else \
        echo "⚠ agrr binary not found (daemon mode disabled)"; \
    fi
```

## 🧹 クリーンアップ（オプション）

不要になったファイルを削除できます：

```bash
# オプション：旧ファイルを削除
rm scripts/start_app_with_agrr_daemon.sh
rm Dockerfile.with-agrr-daemon

# 注意：ドキュメントは残しておくことを推奨
# - README_DAEMON.md
# - QUICK_START_DAEMON.md
# - docs/DEPLOYMENT_VARIANTS.md
# など
```

## 📚 関連ドキュメント

- [docs/ENVIRONMENT_VARIABLES.md](docs/ENVIRONMENT_VARIABLES.md) - 環境変数詳細
- [DEPLOYMENT_GCP.md](DEPLOYMENT_GCP.md) - GCPデプロイ手順
- [QUICK_START_DAEMON.md](QUICK_START_DAEMON.md) - クイックスタート
- [docs/DEPLOYMENT_VARIANTS.md](docs/DEPLOYMENT_VARIANTS.md) - 使い分けガイド

## ✅ まとめ

### 変更点
- ✅ 環境変数 `USE_AGRR_DAEMON` で制御
- ✅ 1つのイメージで両モード対応
- ✅ scripts/start_app.sh を統合
- ✅ Dockerfile.production を統合

### 使い方
- デフォルト（CLI版）: 環境変数なし or `USE_AGRR_DAEMON=false`
- Daemon版: `USE_AGRR_DAEMON=true` + agrr binary必須

### 推奨
- **ほとんどの場合**: CLI版（`USE_AGRR_DAEMON=false`）
- **高頻度アクセス**: Daemon版（`USE_AGRR_DAEMON=true`）

### 次のステップ
1. ローカルでテスト: `docker compose --profile daemon up web-daemon`
2. CloudRunにデプロイ: `DEPLOYMENT_GCP.md` 参照
3. トラフィック増加に応じて環境変数を変更

