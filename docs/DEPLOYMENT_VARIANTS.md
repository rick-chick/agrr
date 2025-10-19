# デプロイバリエーション - CLI版 vs Daemon版

## 概要

AGRRプロジェクトは2つのデプロイバリエーションを提供します：

1. **CLI版**（デフォルト） - agrrをCLIとして都度実行
2. **Daemon版**（オプション） - agrrをdaemonとして常駐させ高速実行

## ファイル構成

### CLI版（デフォルト）

```
agrr/
├── Dockerfile                    # CLI版Dockerfile
└── scripts/
    └── start_app.sh             # CLI版起動スクリプト
```

### Daemon版（オプション）

```
agrr/
├── Dockerfile.with-agrr-daemon         # Daemon版Dockerfile
├── scripts/
│   └── start_app_with_agrr_daemon.sh  # Daemon版起動スクリプト
└── lib/core/
    └── agrr                            # agrr binary（要ビルド）
```

## 使い分けガイド

### CLI版を選ぶべきケース ✅ 推奨

- **コスト最適化が優先**
- **最小インスタンス=0**で運用したい
- **リクエスト頻度が低い**（1日数回程度）
- **agrr実行が稀**
- **シンプルな運用**を優先

**メリット**:
- コストが安い（最小インスタンス=0可能）
- シンプル（追加プロセス無し）
- メモリ消費が少ない
- デバッグしやすい

**デメリット**:
- agrr起動に毎回2.4秒かかる

### Daemon版を選ぶべきケース

- **最小インスタンス=1**で運用している
- **リクエスト頻度が高い**（1時間10回以上）
- **agrr実行が頻繁**（リクエストの50%以上）
- **レスポンス速度**を優先
- **常時稼働のコスト**が許容できる

**メリット**:
- agrr起動が高速（2.4s → 0.5s、4.8倍）
- 2回目以降のリクエストが快適

**デメリット**:
- コスト増加（+$30-50/月）
- メモリ消費増加（+200MB）
- 運用が複雑化

## デプロイ方法

### 1. CLI版のデプロイ（デフォルト）

#### ローカルビルド

```bash
# Dockerイメージビルド
docker build -t agrr-app:cli .

# ローカルテスト
docker run --rm -p 3000:3000 \
  -e RAILS_ENV=production \
  -e SECRET_KEY_BASE=dummy_key \
  agrr-app:cli
```

#### CloudRun

```bash
# GCRにプッシュ
PROJECT_ID="your-gcp-project-id"
docker tag agrr-app:cli gcr.io/${PROJECT_ID}/agrr-app:cli
docker push gcr.io/${PROJECT_ID}/agrr-app:cli

# デプロイ
gcloud run deploy agrr-app \
  --image gcr.io/${PROJECT_ID}/agrr-app:cli \
  --platform managed \
  --region asia-northeast1 \
  --min-instances=0 \
  --max-instances=10 \
  --memory 1.5Gi \
  --allow-unauthenticated
```

#### AWS App Runner（既存スクリプト）

```bash
# 既存のデプロイスクリプトを使用
./scripts/aws-deploy.sh
```

### 2. Daemon版のデプロイ

#### 事前準備：agrr binaryのビルド

```bash
# 1. agrr binaryをビルド
cd lib/core/agrr_core
./build_standalone.sh --onefile

# 2. バイナリを配置
cp dist/agrr ../agrr
chmod +x ../agrr

# 3. 確認
ls -lh ../agrr
# -rwxr-xr-x 1 user user 113M ... ../agrr

cd ../../..
```

#### ローカルビルド

```bash
# Dockerイメージビルド（daemon版）
docker build -f Dockerfile.with-agrr-daemon -t agrr-app:daemon .

# ローカルテスト
docker run --rm -p 3000:3000 \
  -e RAILS_ENV=production \
  -e SECRET_KEY_BASE=dummy_key \
  agrr-app:daemon

# ログで確認
# "✓ agrr daemon started (PID: xxxx)" が表示されればOK
```

#### CloudRun

```bash
# GCRにプッシュ
PROJECT_ID="your-gcp-project-id"
docker tag agrr-app:daemon gcr.io/${PROJECT_ID}/agrr-app:daemon
docker push gcr.io/${PROJECT_ID}/agrr-app:daemon

# デプロイ（最小インスタンス=1推奨）
gcloud run deploy agrr-app-daemon \
  --image gcr.io/${PROJECT_ID}/agrr-app:daemon \
  --platform managed \
  --region asia-northeast1 \
  --min-instances=1 \
  --max-instances=1 \
  --memory 2Gi \
  --allow-unauthenticated
```

#### AWS App Runner（カスタムデプロイ）

```bash
# 1. 環境変数でdaemon版を指定
export USE_DAEMON_VERSION=true

# 2. デプロイスクリプト実行
./scripts/aws-deploy-daemon.sh
```

## 切り替え方法

### 開発環境（Docker Compose）

```yaml
# docker-compose.yml

# CLI版
services:
  web:
    build:
      context: .
      dockerfile: Dockerfile
    # ...

# Daemon版
services:
  web-daemon:
    build:
      context: .
      dockerfile: Dockerfile.with-agrr-daemon
    # ...
```

```bash
# CLI版で起動
docker compose up web

# Daemon版で起動
docker compose up web-daemon
```

### 本番環境

#### CloudRun: サービス名で分ける

```bash
# CLI版サービス
gcloud run deploy agrr-app-cli --image gcr.io/.../agrr-app:cli

# Daemon版サービス
gcloud run deploy agrr-app-daemon --image gcr.io/.../agrr-app:daemon
```

#### App Runner: 環境変数で切り替え

```bash
# CLI版
./scripts/aws-deploy.sh

# Daemon版
USE_DAEMON_VERSION=true ./scripts/aws-deploy.sh
```

## パフォーマンス比較

### CLI版

| 項目 | 値 |
|------|-----|
| agrr起動時間 | 2.4s（毎回） |
| メモリ使用量 | 1.5GB |
| 最小インスタンス | 0（推奨） |
| 月額コスト（CloudRun） | $0-10 |
| ディスク使用量 | ベースライン |

### Daemon版

| 項目 | 値 |
|------|-----|
| agrr起動時間 | 初回: 2.4s、2回目以降: 0.5s |
| メモリ使用量 | 1.7GB (+200MB) |
| 最小インスタンス | 1（推奨） |
| 月額コスト（CloudRun） | $30-50 |
| ディスク使用量 | +113MB |

## トラブルシューティング

### CLI版でagrr実行が遅い

**対処法**:
1. キャッシュを活用
2. 非同期ジョブ化
3. Daemon版への移行を検討

### Daemon版でメモリ不足

**対処法**:
```bash
# CloudRunメモリを増やす
gcloud run services update agrr-app-daemon --memory 2.5Gi

# App Runner
# apprunner.yaml で Memory: 2560 に変更
```

### Daemon版でdaemon起動失敗

**確認ポイント**:
1. agrr binaryがビルドされているか
   ```bash
   ls -lh lib/core/agrr
   ```

2. Dockerイメージに含まれているか
   ```bash
   docker run --rm agrr-app:daemon ls -lh /usr/local/bin/agrr
   ```

3. パーミッション
   ```bash
   docker run --rm agrr-app:daemon /usr/local/bin/agrr daemon status
   ```

## 推奨設定

### 小規模プロジェクト（<1000リクエスト/日）

**推奨**: CLI版
- 最小インスタンス: 0
- 最大インスタンス: 3
- メモリ: 1.5Gi

### 中規模プロジェクト（1000-10000リクエスト/日）

**推奨**: CLI版 + キャッシュ
- 最小インスタンス: 1
- 最大インスタンス: 10
- メモリ: 2Gi
- Redis cache有効化

### 大規模プロジェクト（>10000リクエスト/日）

**検討**: Daemon版 or 専用マイクロサービス
- 最小インスタンス: 1-3
- 最大インスタンス: 10
- メモリ: 2-3Gi
- 専用agrrサービスの分離も検討

## まとめ

### デフォルトはCLI版を使用

ほとんどのケースでCLI版で十分です。

### Daemon版は特殊ケースのみ

以下を**すべて満たす**場合のみ検討：
- 最小インスタンス=1で運用
- 高頻度アクセス
- コスト増が許容できる

### 迷ったらCLI版から始める

まずCLI版でデプロイし、必要に応じてDaemon版に移行するのが安全です。

## 関連ドキュメント

- [DAEMON_CLOUDRUN_ANALYSIS.md](DAEMON_CLOUDRUN_ANALYSIS.md) - 詳細分析
- [AGRR_DAEMON_INTEGRATION.md](AGRR_DAEMON_INTEGRATION.md) - Daemon版実装手順
- [DAEMON_SUMMARY.md](DAEMON_SUMMARY.md) - 要約

