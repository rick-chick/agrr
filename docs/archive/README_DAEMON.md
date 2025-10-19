# AGRR - Daemon版クイックスタート

## CLI版 vs Daemon版

AGRRプロジェクトは2つのバリエーションを提供します：

| 項目 | CLI版（デフォルト） | Daemon版 |
|------|------------------|----------|
| **ファイル** | `Dockerfile` | `Dockerfile.with-agrr-daemon` |
| **スクリプト** | `scripts/start_app.sh` | `scripts/start_app_with_agrr_daemon.sh` |
| **agrr起動時間** | 2.4s（毎回） | 初回: 2.4s、2回目以降: 0.5s |
| **メモリ使用量** | 1.5GB | 1.7GB (+200MB) |
| **推奨最小インスタンス** | 0 | 1 |
| **月額コスト** | $0-10 | $30-50 |
| **推奨ケース** | ほとんどの場合 | 高頻度アクセス |

**詳細**: [docs/DEPLOYMENT_VARIANTS.md](docs/DEPLOYMENT_VARIANTS.md)

## クイックスタート

### CLI版（デフォルト、推奨）

```bash
# 開発環境
docker compose up web

# 本番デプロイ（CloudRun）
docker build -t agrr-app:cli .
gcloud run deploy agrr-app --image gcr.io/.../agrr-app:cli

# 本番デプロイ（AWS App Runner）
./scripts/aws-deploy.sh
```

### Daemon版（高頻度アクセス向け）

#### 1. 事前準備：agrr binaryをビルド

```bash
cd lib/core/agrr_core
./build_standalone.sh --onefile
cp dist/agrr ../agrr
cd ../../..
```

#### 2. ローカルでテスト

```bash
# Docker Composeでdaemon版を起動
docker compose --profile daemon up web-daemon

# ブラウザで確認
# http://localhost:3001

# ログで確認（daemon起動の確認）
# "✓ agrr daemon started (PID: xxxx)" が表示されればOK
```

#### 3. 本番デプロイ

```bash
# CloudRun
docker build -f Dockerfile.with-agrr-daemon -t agrr-app:daemon .
gcloud run deploy agrr-app-daemon \
  --image gcr.io/.../agrr-app:daemon \
  --min-instances=1 \
  --memory 2Gi

# AWS App Runner
./scripts/aws-deploy-daemon.sh
```

## どちらを使うべきか？

### ✅ CLI版を使うべきケース（ほとんどの場合）

- コスト最適化が優先
- リクエスト頻度が低い（1日数回〜数百回）
- シンプルな運用を優先

### Daemon版を使うべきケース

以下を**すべて満たす**場合のみ：
- 最小インスタンス=1で運用している
- リクエスト頻度が高い（1時間10回以上）
- agrr実行が頻繁（リクエストの50%以上）
- 常時稼働のコストが許容できる

### 🔄 迷ったら

**CLI版から始めてください。** 必要に応じてDaemon版に移行できます。

## ファイル構成

```
agrr/
├── Dockerfile                              # CLI版（デフォルト）
├── Dockerfile.with-agrr-daemon            # Daemon版
├── scripts/
│   ├── start_app.sh                       # CLI版起動スクリプト
│   ├── start_app_with_agrr_daemon.sh     # Daemon版起動スクリプト
│   ├── aws-deploy.sh                      # AWS App Runner（CLI版）
│   └── aws-deploy-daemon.sh               # AWS App Runner（Daemon版）
├── docker-compose.yml                      # 両方をサポート
└── lib/core/
    └── agrr                                # agrr binary（要ビルド）
```

## よくある質問

### Q1: CLI版とDaemon版の切り替えは簡単？

**A**: はい、Dockerfileとスクリプトが分かれているので簡単に切り替えられます。

```bash
# CLI版
docker build -t agrr-app:cli .

# Daemon版
docker build -f Dockerfile.with-agrr-daemon -t agrr-app:daemon .
```

### Q2: 両方同時にデプロイできる？

**A**: はい、別々のサービスとしてデプロイできます。

```bash
# CloudRunで両方デプロイ
gcloud run deploy agrr-app-cli --image ...
gcloud run deploy agrr-app-daemon --image ...

# URL別々
# https://agrr-app-cli-xxx.run.app
# https://agrr-app-daemon-xxx.run.app
```

### Q3: Daemon版でagrr binaryのビルドが必要なのはなぜ？

**A**: Daemon版はagrr binaryをコンテナに含める必要があるためです。CLI版はagrrを外部で実行するため不要です。

### Q4: 開発環境でDaemon版を使うメリットは？

**A**: 開発環境ではほぼメリットなし。本番環境と同じ構成でテストしたい場合のみ使用してください。

### Q5: CLI版からDaemon版への移行は簡単？

**A**: はい、agrr binaryをビルドすれば移行できます。データベースなどは共通です。

## パフォーマンス測定

Daemon版の効果を測定できます：

```bash
# Daemon版コンテナ内で
docker compose --profile daemon exec web-daemon bash

# 1回目（遅い）
time agrr weather --location 35.6762,139.6503 --days 1 --json
# → 約2.4s

# 2回目（速い、daemonのおかげ）
time agrr weather --location 35.6762,139.6503 --days 1 --json
# → 約0.5s（4.8倍高速）
```

## トラブルシューティング

### agrr binary not found

```bash
# ビルドされているか確認
ls -lh lib/core/agrr

# ビルド実行
cd lib/core/agrr_core
./build_standalone.sh --onefile
cp dist/agrr ../agrr
```

### daemon起動失敗

```bash
# ログ確認
docker compose --profile daemon logs web-daemon | grep daemon

# 手動で確認
docker compose --profile daemon exec web-daemon /usr/local/bin/agrr daemon status
```

### メモリ不足

```bash
# CloudRunでメモリを増やす
gcloud run services update agrr-app-daemon --memory 2.5Gi
```

## 関連ドキュメント

- [DEPLOYMENT_VARIANTS.md](docs/DEPLOYMENT_VARIANTS.md) - 詳細な使い分けガイド
- [AGRR_DAEMON_INTEGRATION.md](docs/AGRR_DAEMON_INTEGRATION.md) - 実装詳細
- [DAEMON_CLOUDRUN_ANALYSIS.md](docs/DAEMON_CLOUDRUN_ANALYSIS.md) - 技術分析
- [DAEMON_SUMMARY.md](docs/DAEMON_SUMMARY.md) - 要約

## まとめ

- **デフォルトはCLI版**を使用（`Dockerfile`、`scripts/start_app.sh`）
- **Daemon版は特殊ケース**のみ（`Dockerfile.with-agrr-daemon`、`scripts/start_app_with_agrr_daemon.sh`）
- 両方のファイルが独立しているため**いつでも切り替え可能**
- **迷ったらCLI版から始める**

詳細は [docs/DEPLOYMENT_VARIANTS.md](docs/DEPLOYMENT_VARIANTS.md) をご覧ください。

