# AGRR - Rails 8 + SQLite + S3 + App Runner

**Rails 8の最新機能を活用したコストパフォーマンスに優れたアプリケーション構成**

PostgreSQLやRedis不要！SQLiteとDockerだけで本番環境に耐えられるRailsアプリケーションです。

📖 **[テストガイド](docs/TEST_GUIDE.md)** | 📖 **[AWSデプロイガイド](docs/AWS_DEPLOY.md)**

## 🚀 主な特徴

- **Rails 8.0** - 最新のRailsフレームワーク
- **SQLite** - 開発から本番まで全環境で使用（データベース）
- **Solid Queue** - SQLiteベースのバックグラウンドジョブ処理
- **Solid Cache** - SQLiteベースのキャッシュシステム
- **Solid Cable** - SQLiteベースのAction Cable（WebSocket）
- **Active Storage + S3** - 画像・ファイルの保存
- **AWS App Runner** - サーバーレスデプロイ
- **Litestack** - SQLiteの本番環境最適化

## 💰 コスト削減のポイント

- ❌ PostgreSQL/RDS不要
- ❌ Redis/ElastiCache不要
- ✅ SQLiteで全て実現（データベース、キャッシュ、ジョブキュー）
- ✅ AWS App Runnerのみ（自動スケーリング）
- ✅ S3（ファイル保存）

**推定コスト**: $5-10/月（小規模トラフィック時）

## 🏗 環境構成

このアプリケーションは4つの環境をサポートしています：

| 環境 | 用途 | データベース | ファイル保存 |
|------|------|--------------|--------------|
| **development** | ローカル開発（No Docker） | SQLite | ローカルディスク |
| **docker** | Docker開発環境 | SQLite | ローカルディスク |
| **aws_test** | AWSテスト環境 | SQLite + EFS | S3 |
| **production** | AWS本番環境 | SQLite + EFS | S3 |

## ✨ 機能

- Active Storageを使ったファイルアップロード
- S3へのファイル保存（AWS環境）
- ローカルファイル保存（開発環境）
- SQLiteベースのバックグラウンドジョブ（Solid Queue）
- SQLiteベースのキャッシュ（Solid Cache）
- RESTful API
- CORS対応
- ヘルスチェックエンドポイント

## 📦 セットアップ

### 🌟 推奨方法（2025年）

#### Method 1: GitHub Codespaces ⭐ (最も簡単)

```bash
# GitHubリポジトリで:
Code → Codespaces → Create codespace on main

# 自動的に全てセットアップされます！
# ターミナルで即座に実行:
bundle exec rails test
rails server
```

**メリット:**
- インストール不要
- どのOSからでもアクセス可能
- 月60時間まで無料
- 環境の一貫性が保証

#### Method 2: Dev Containers (VS Code)

**必要なもの:**
- Docker Desktop
- Visual Studio Code
- Dev Containers拡張機能

**手順:**
```
1. VSCodeでプロジェクトを開く
2. F1 → "Dev Containers: Reopen in Container"
3. 自動的にコンテナがビルド・起動
```

すべての依存関係が自動インストールされます！

#### Method 3: Docker Compose

```bash
# サーバー起動（自動セットアップ）
docker-compose up

# テスト実行
docker-compose exec web bundle exec rails test
```

### 📝 従来の方法（非推奨）

<details>
<summary>ローカルに直接インストールする場合（クリックして展開）</summary>

**必要要件:**
- Ruby 3.3.x以上
- SQLite 3.8.0以上
- 開発ツール（gcc, make等）

```bash
# Gemをインストール
bundle install

# 環境変数設定
cp env.example .env

# データベースセットアップ
rails db:prepare

# Solid Queue/Cacheのセットアップ
rails solid_queue:install
rails solid_cache:install
rails solid_cable:install
```

**注意:** Windows環境では**WSL2の使用を強く推奨**します。ネイティブWindowsでのビルドは複雑です。

</details>

## 🚀 開発環境での実行

### 推奨: Dev Containers / Codespaces

```bash
# 開発サーバー起動
rails server -b 0.0.0.0

# バックグラウンドジョブワーカー
rails solid_queue:start

# コンソール
rails console

# ブラウザで http://localhost:3000 にアクセス
```

### Docker Compose

```bash
# サーバー起動
docker-compose up

# 別のターミナルでコマンド実行
docker-compose exec web rails console
docker-compose exec web bundle exec rails test

# 停止
docker-compose down
```

## 🧪 テスト

このアプリケーションはRails公式推奨のMinitestを使用しています。

### テスト実行

```bash
# Docker Compose使用（推奨）
docker-compose run --rm -e RAILS_ENV=test web bundle exec rails test
```

詳細は [TEST_GUIDE.md](docs/TEST_GUIDE.md) を参照してください。

## API エンドポイント

### ヘルスチェック

```
GET /api/v1/health
```

レスポンス例:
```json
{
  "status": "ok",
  "timestamp": "2025-01-01T00:00:00Z",
  "environment": "development",
  "database_connected": true,
  "storage": "local"
}
```

### ファイル管理

```
GET    /api/v1/files          # ファイル一覧
GET    /api/v1/files/:id      # ファイル詳細
POST   /api/v1/files          # ファイルアップロード
DELETE /api/v1/files/:id      # ファイル削除
```

## ☁️ AWS デプロイ（クイックスタート）

### 最小ステップでデプロイ

#### 前提条件

- AWS CLIがインストール済み（`aws --version`）
- AWS認証情報が設定済み（`aws configure`）
- Dockerがインストール済み

#### 1. セットアップ（初回のみ）

```bash
# AWSリソースを自動作成（S3、IAM、App Runner用リソース）
./scripts/setup-aws-resources.sh setup
```

これだけで以下が自動作成されます：
- ✅ S3バケット（production/test）
- ✅ IAMロールとポリシー
- ✅ `.env.aws` 設定ファイル

#### 2. デプロイ

```bash
# 本番環境へデプロイ
./scripts/aws-deploy.sh production deploy

# テスト環境へデプロイ
./scripts/aws-deploy.sh aws_test deploy
```

**それだけです！** 🎉

詳細な手順は **[AWS_DEPLOY.md](docs/AWS_DEPLOY.md)** を参照してください

## 💡 コスト最適化のポイント

### App Runner の推奨設定

```yaml
# 最小構成（開発/テスト環境）
CPU: 0.25 vCPU
メモリ: 0.5 GB
最小インスタンス数: 0（一時停止可能）
最大インスタンス数: 1

# 本番環境（小規模）
CPU: 0.5 vCPU
メモリ: 1 GB
最小インスタンス数: 1
最大インスタンス数: 3
```

### S3 の推奨設定

- **ストレージクラス**: 
  - 新規アップロード: `STANDARD`
  - 30日後: `STANDARD_IA`（アクセス頻度が低い場合）
  - 90日後: `GLACIER`（アーカイブ）
- **ライフサイクルポリシー**: 上記に基づいて設定
- **バージョニング**: オフ（コスト削減）

### EFS の推奨設定

- **パフォーマンスモード**: 汎用
- **スループットモード**: バースト
- **ストレージクラス**: Standard（小規模の場合）
- **バックアップ**: AWS Backup（週次推奨）

### 月額コスト試算（ap-northeast-1）

| サービス | 構成 | 月額コスト（概算） |
|---------|------|-------------------|
| App Runner | 0.25vCPU/0.5GB, 最小0台 | $2-5 |
| EFS | 1GB標準ストレージ | $0.30 |
| S3 | 5GB標準 + 転送 | $0.15-1 |
| **合計** | | **$2.45-6.30** |

※ トラフィックやデータ量により変動します

## ファイル構成

```
├── app/
│   ├── controllers/
│   │   ├── api/v1/
│   │   │   ├── base_controller.rb
│   │   │   └── files_controller.rb
│   │   └── application_controller.rb
│   └── models/
│       └── application_record.rb
├── config/
│   ├── environments/
│   │   ├── development.rb
│   │   ├── docker.rb
│   │   ├── test.rb
│   │   └── production.rb
│   ├── initializers/
│   │   ├── active_storage.rb
│   │   └── aws.rb
│   ├── storage.yml
│   └── database.yml
├── .awsapprunner/
│   ├── Dockerfile
│   └── apprunner.yaml
├── scripts/
│   ├── deploy.sh
│   └── setup-dev.sh
├── Dockerfile
├── Dockerfile.production
├── docker-compose.yml
└── README.md
```

## 🔧 トラブルシューティング

### よくある問題と解決方法

#### 1. SQLite データベースエラー

**問題**: `SQLite3::BusyException: database is locked`

**解決方法**:
```ruby
# config/database.yml に以下を追加
default: &default
  adapter: sqlite3
  pool: <%= ENV.fetch("RAILS_MAX_THREADS") { 5 } %>
  timeout: 5000
  retries: 1000  # これを追加
```

#### 2. S3アクセスエラー

**問題**: `Aws::S3::Errors::AccessDenied`

**解決方法**:
- AWS認証情報が正しく設定されているか確認
- S3バケットのCORS設定を確認
- IAMポリシーでS3へのアクセス権限を確認

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject"
      ],
      "Resource": "arn:aws:s3:::your-bucket-name/*"
    }
  ]
}
```

#### 3. App Runner 起動エラー

**問題**: Health check failed

**解決方法**:
- `/up` エンドポイントが正しく応答しているか確認
- ログを確認: `aws apprunner list-operations --service-arn <your-service-arn>`
- 環境変数（特に `RAILS_MASTER_KEY`）が正しく設定されているか確認

#### 4. EFS マウントエラー

**問題**: SQLite databases not persisting

**解決方法**:
- EFSボリュームが正しくマウントされているか確認（`/app/storage`）
- EFSアクセスポイントの権限設定を確認
- App RunnerのVPC設定がEFSと同じか確認

#### 5. Solid Queue が動作しない

**問題**: Background jobs not processing

**解決方法**:
```bash
# Solid Queueのインストールを確認
rails solid_queue:install:migrations
rails db:migrate

# App Runnerで Solid Queue ワーカーが起動しているか確認
# Dockerfile.production の CMD を確認
```

## 📚 参考リソース

- [Rails 8 リリースノート](https://edgeguides.rubyonrails.org/8_0_release_notes.html)
- [Solid Queue](https://github.com/rails/solid_queue)
- [Solid Cache](https://github.com/rails/solid_cache)
- [Litestack](https://github.com/oldmoe/litestack)
- [AWS App Runner ドキュメント](https://docs.aws.amazon.com/apprunner/)

## 🤝 コントリビューション

プルリクエストを歓迎します！大きな変更の場合は、まずissueを開いて変更内容を議論してください。

## 📄 ライセンス

MIT License
