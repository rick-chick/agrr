# AGRR - Rails 8 農業計画支援システム

**Rails 8 + SQLite + Litestream + Google Cloud Run**

PostgreSQLやRedis不要！SQLiteとLitestreamだけで本番環境に耐えられる、コストパフォーマンスに優れたRailsアプリケーションです。

📖 **[ドキュメント一覧](docs/README.md)** | 📖 **[デプロイガイド](docs/operations/DEPLOYMENT_GUIDE.md)** | 📖 **[コマンド集](docs/operations/QUICK_REFERENCE.md)**

---

## 🚀 主な特徴

### Rails 8の最新機能
- **Solid Queue** - SQLiteベースのバックグラウンドジョブ
- **Solid Cache** - SQLiteベースのキャッシュ
- **Solid Cable** - SQLiteベースのWebSocket（Action Cable）

### インフラ構成
- **Google Cloud Run** - サーバーレスコンテナ実行環境
- **Litestream** - SQLiteのCloud Storageへのリアルタイムレプリケーション
- **Cloud Storage** - データベースバックアップ
- **Artifact Registry** - Dockerイメージ保存

### コスト最適化
- ✅ PostgreSQL/Cloud SQL不要
- ✅ Redis/Memorystore不要
- ✅ SQLiteで全て実現（DB、キャッシュ、ジョブキュー）
- ✅ アイドル時自動停止（min-instances=0）

**推定コスト**: 月額 **$1-6** （小規模トラフィック時）

---

## 🏗 アーキテクチャ

```
ユーザー
  ↓
Google Cloud Run
  └─ Rails 8 アプリケーション
      ├─ SQLite (/tmp)
      │   ├─ production.sqlite3 (メインDB)
      │   ├─ production_queue.sqlite3 (Solid Queue)
      │   └─ production_cache.sqlite3 (Solid Cache)
      ├─ Solid Queue (バックグラウンドジョブ)
      ├─ Solid Cache (キャッシュ)
      └─ Litestream (レプリケーション)
           ↓ リアルタイム同期（10-30秒間隔）
      Cloud Storage (gs://agrr-production-db)
```

---

## 📦 クイックスタート

### 開発環境

```bash
# 1. リポジトリをクローン
git clone <repository-url>
cd agrr

# 2. Docker環境を起動
docker-compose up

# 3. データベースセットアップ
docker-compose run --rm web rails db:setup

# 4. ブラウザで確認
open http://localhost:3000
```

詳細は **[開発ガイド](#開発環境)** を参照

---

### 本番環境デプロイ

```bash
# 1. 環境変数を設定
cp env.gcp.example .env.gcp
# .env.gcpを編集

# 2. デプロイ
source .env.gcp
./scripts/gcp-deploy.sh deploy
```

詳細は **[運用ガイド](docs/OPERATIONS_SUMMARY.md)** を参照

---

## 🌐 本番環境

### サービス情報
- **URL**: https://agrr-production-czyu2jck5q-an.a.run.app
- **プラットフォーム**: Google Cloud Run
- **リージョン**: asia-northeast1（東京）
- **データベース**: SQLite + Litestream

### リソース
- **メモリ**: 2GB
- **CPU**: 2コア
- **インスタンス**: 0-1（自動スケール）
- **タイムアウト**: 600秒

---

## ✨ 機能

### 認証
- Google OAuth 2.0認証
- セッション管理

### 作付け計画
- 圃場管理
- 作物管理
- 栽培計画の最適化
- ガントチャート表示

### 気象データ
- 過去の気象データ取得
- 将来予測
- 気候グラフ表示

### バックグラウンド処理
- Solid Queueによる非同期ジョブ
- 気象データ更新
- AI予測処理

---

## 🛠 開発環境

### 必要なもの
- Docker & Docker Compose
- Git

### セットアップ

```bash
# 1. 依存関係のインストール
docker-compose build

# 2. データベース作成
docker-compose run --rm web rails db:create db:migrate

# 3. データベースセットアップ（マイグレーション実行で自動的にデータも投入される）
# db:migrate により参照データも自動投入されます

# 4. サーバー起動
docker-compose up
```

### テスト実行

```bash
# 全テスト実行
docker-compose run --rm test

# 特定のテスト実行
docker-compose run --rm test bundle exec rails test test/controllers/public_plans_controller_test.rb
```

---

## 🚀 デプロイ

### 前提条件
- Google Cloud Platform アカウント
- gcloud CLI インストール済み
- サービスアカウント設定済み

### デプロイ手順

```bash
# 1. 環境変数設定
source .env.gcp

# 2. デプロイ実行
./scripts/gcp-deploy.sh deploy
```

所要時間: 2-3分

詳細は **[運用ガイド](docs/OPERATIONS_SUMMARY.md)** を参照

---

## 📊 運用

### 日常運用

```bash
# デプロイ
./scripts/gcp-deploy.sh deploy

# ログ確認
gcloud logging read "resource.type=cloud_run_revision" \
  --limit=50 --project=agrr-475323

# バックアップ確認
gsutil ls -lh gs://agrr-production-db/
```

### メンテナンス

```bash
# 古いイメージ削除
./scripts/cleanup-images.sh

# 手動バックアップ
gsutil -m cp -r gs://agrr-production-db/production.sqlite3 \
  gs://agrr-production-db/manual-backup-$(date +%Y%m%d)/
```

詳細は **[クイックリファレンス](docs/QUICK_REFERENCE.md)** を参照

---

## 🔧 設定ファイル

### 環境変数（.env.gcp）
```bash
PROJECT_ID=agrr-475323
REGION=asia-northeast1
SERVICE_NAME=agrr-production
GCS_BUCKET=agrr-production-db
RAILS_MASTER_KEY=<your-key>
SECRET_KEY_BASE=<your-secret>
ALLOWED_HOSTS=agrr.net,www.agrr.net,.run.app
```

### データベース（config/database.yml）
```yaml
production:
  primary:
    database: /tmp/production.sqlite3
  queue:
    database: /tmp/production_queue.sqlite3
  cache:
    database: /tmp/production_cache.sqlite3
```

### Litestream（config/litestream.yml）
```yaml
dbs:
  - path: /tmp/production.sqlite3
    replicas:
      - type: gcs
        bucket: ${GCS_BUCKET}
        sync-interval: 10s
```

---

## 📁 ファイル構成

```
agrr/
├── app/                    # Railsアプリケーション
│   ├── controllers/
│   ├── models/
│   ├── views/
│   ├── channels/          # Action Cable (WebSocket)
│   └── javascript/
├── config/
│   ├── database.yml       # 3ファイル分離構成
│   ├── litestream.yml     # Litestream設定
│   └── environments/
│       └── production.rb  # Cloud Run用設定
├── db/
│   ├── migrate/          # メインDBマイグレーション
│   ├── queue_migrate/    # Solid Queueマイグレーション
│   └── cache_migrate/    # Solid Cacheマイグレーション
├── scripts/
│   ├── gcp-deploy.sh     # Cloud Runデプロイ
│   ├── cleanup-images.sh # イメージクリーンアップ
│   └── start_app.sh      # コンテナ起動スクリプト
├── docs/
│   ├── OPERATIONS_SUMMARY.md  # 運用ガイド
│   ├── QUICK_REFERENCE.md     # コマンド集
│   ├── GOOGLE_OAUTH_SETUP.md  # OAuth設定
│   └── archive/              # 古いドキュメント
├── Dockerfile.production  # 本番用Dockerfile
├── docker-compose.yml    # 開発環境
└── README.md            # このファイル
```

---

## 🔍 トラブルシューティング

### サービスが起動しない
```bash
# ログ確認
gcloud logging read "resource.labels.service_name=agrr-production" \
  --limit=100 --project=agrr-475323

# 前のリビジョンにロールバック
gcloud run services update-traffic agrr-production \
  --to-revisions <previous-revision>=100 \
  --region asia-northeast1
```

### データが消えた
```bash
# Litestreamバックアップから復元
gsutil ls gs://agrr-production-db/

# 手動バックアップから復元
gsutil cp -r gs://agrr-production-db/manual-backup-YYYYMMDD/ \
  gs://agrr-production-db/production.sqlite3/
```

---

## 📚 ドキュメント

### 運用関連
- **[運用ガイド](docs/OPERATIONS_SUMMARY.md)** - 詳細な運用手順
- **[クイックリファレンス](docs/QUICK_REFERENCE.md)** - よく使うコマンド集

### 開発関連
- **[Google OAuth設定](docs/GOOGLE_OAUTH_SETUP.md)** - 認証設定
- **[開発履歴](docs/archive/)** - 過去のドキュメント

---

## 💰 コスト見積もり

### 現在の構成（min-instances=0）
```
Cloud Run: $0.50-5.00/月
Cloud Storage: $0.02-0.50/月
Artifact Registry: $0.10/月
──────────────────────────
合計: $1-6/月
```

### 常時稼働（min-instances=1）
```
Cloud Run: $40-60/月
Cloud Storage: $0.50/月
──────────────────────────
合計: $41-61/月
```

---

## 📈 スケーリング

### 現在の制約
- **最大1インスタンス**（Litestream制約）
- 同時接続: ~80リクエスト

### スケールアップが必要な場合
- **Cloud SQL（PostgreSQL）への移行**を検討
- 月間PV > 10万、または同時接続 > 50が目安

---

## 🤝 コントリビューション

プルリクエストを歓迎します！

### 開発フロー
1. ブランチ作成
2. テスト作成・実装
3. `docker-compose run --rm test` でテスト実行
4. プルリクエスト作成

---

## 📄 ライセンス

MIT License

---

## 📚 データ管理ドキュメント

### Region Data（地域別データ）

AGRRは複数の地域（region）をサポートしています：
- 🇯🇵 Japan (jp) - 47農場、15作物、442,501天気レコード
- 🇺🇸 United States (us) - 50農場、30作物、430,361天気レコード

**データ管理:**
- 📖 [Data Migration Guide](docs/DATA_MIGRATION_GUIDE.md) - マイグレーションによるデータ管理方法
- 📖 [Region Data Creation Guide](docs/region/DATA_CREATION_GUIDE.md) - 新しい地域データ作成手順
- 📊 [US Region Summary](docs/region/US_SUMMARY.md) - US region実装の詳細
- 📚 [Region Documentation](docs/region/README.md) - Region機能の全体ドキュメント

すべての参照データ（マスターデータ）はデータベースマイグレーションで管理されます。`rails db:migrate`を実行するだけで、スキーマ構築とデータ投入が自動的に完了します。

---

## 📞 リンク

- [Cloud Run Console](https://console.cloud.google.com/run?project=agrr-475323)
- [Cloud Storage](https://console.cloud.google.com/storage/browser/agrr-production-db?project=agrr-475323)
- [本番環境URL](https://agrr-production-czyu2jck5q-an.a.run.app)

**最終更新**: 2025-10-17
