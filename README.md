# AGRR - Rails 8 + SQLite + S3 + App Runner

**Rails 8の最新機能を活用したコストパフォーマンスに優れたアプリケーション構成**

PostgreSQLやRedis不要！SQLiteとDockerだけで本番環境に耐えられるRailsアプリケーションです。

📖 **[テストガイド](docs/TEST_GUIDE.md)** | 📖 **[AWSデプロイガイド](docs/AWS_DEPLOY.md)** | 📖 **[Google OAuth設定ガイド](docs/GOOGLE_OAUTH_SETUP.md)**

## 📋 目次

- [主な特徴](#主な特徴)
- [コスト削減のポイント](#コスト削減のポイント)
- [環境構成](#環境構成)
- [機能](#機能)
- [セットアップ](#セットアップ)
  - [参照データの準備](#参照データreference-dataの準備)
- [開発環境での実行](#開発環境での実行)
- [開発プロセス](#開発プロセス)
- [テスト](#テスト)
- [API エンドポイント](#api-エンドポイント)
- [AWS デプロイ](#aws-デプロイ)
- [CI/CD パイプライン](#cicd-パイプライン)
- [コスト最適化のポイント](#コスト最適化のポイント)
- [ファイル構成](#ファイル構成)
- [トラブルシューティング](#トラブルシューティング)
- [参考リソース](#参考リソース)

## 🚀 主な特徴

- **Rails 8.0** - 最新のRailsフレームワーク
- **Google OAuth 2.0認証** - セキュアな認証システム
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

- **Google OAuth 2.0認証** - セキュアな認証システム
- Active Storageを使ったファイルアップロード
- S3へのファイル保存（AWS環境）
- ローカルファイル保存（開発環境）
- SQLiteベースのバックグラウンドジョブ（Solid Queue）
- SQLiteベースのキャッシュ（Solid Cache）
- RESTful API
- CORS対応
- ヘルスチェックエンドポイント

## 📦 セットアップ

詳細なセットアップ手順は以下のドキュメントを参照してください：

- 📖 **[AWSデプロイガイド](docs/AWS_DEPLOY.md#開発環境セットアップ)** - 開発環境の構築方法
- 📖 **[テストガイド](docs/TEST_GUIDE.md#推奨開発環境)** - テスト環境の構築方法

### 🌱 参照データ（Reference Data）の準備

AGRRでは、参照農場（全都道府県47地域）と参照作物（15種類）のデータを使用します。
これらのデータには天気情報とAI生成の作物情報が含まれますが、取得に時間がかかるため、**2段階のセットアップ**が必要です。

#### 通常の開発者向け（高速セットアップ）

既にフィクスチャファイルがリポジトリに含まれている場合、以下のコマンドだけで完了します：

```bash
# 基本シードを実行（数秒で完了）
docker compose run --rm web rails db:seed
```

このコマンドで以下がインポートされます：
- 管理者ユーザー
- 47都道府県の参照農場（位置情報 + 2000年以降の天気データ）
- 15種類の参照作物（基本情報 + AI生成の栽培情報）

#### 初回セットアップ（管理者・一度だけ実行）

フィクスチャファイルが存在しない場合、管理者が以下の手順でデータを生成します：

```bash
# 1. 基本シードを実行（基本情報のみ）
docker compose run --rm web rails db:seed

# 2. ターミナル1: Webサーバーを起動
docker compose up web

# 3. ターミナル2: Solid Queueを起動
docker compose run --rm web bundle exec rails solid_queue:start

# 4. ターミナル3: 参照農場の天気データを取得（10-30分）
docker compose run --rm web bin/fetch_reference_weather_data

# 5. ターミナル3: 参照作物のAI情報を取得（5-15分）
docker compose run --rm web bin/fetch_reference_crop_info

# 6. フィクスチャファイルをコミット
git add db/fixtures/
git commit -m "Add reference weather and crop data"
git push
```

以後、他の開発者は`rails db:seed`だけで完全なデータを取得できます。

**注意事項**:
- **Webサーバーが起動している必要があります**（スクリプトはAPI経由でデータ取得）
- 天気データ取得には Solid Queue が起動している必要があります
- AI作物情報取得には AI API キー（環境変数）が必要な場合があります
- 内部APIエンドポイント（`/api/v1/internal/*`）は開発・テスト環境のみ有効

## 🚀 開発環境での実行

詳細な開発環境での実行方法は **[テストガイド](docs/TEST_GUIDE.md)** を参照してください。


## 🔧 開発プロセス

### テスト駆動開発 (TDD)

```bash
# 1. テストを書く
# test/controllers/api/v1/example_controller_test.rb

# 2. テストを実行（失敗することを確認）
bundle exec rails test test/controllers/api/v1/example_controller_test.rb

# 3. 最小限のコードを実装
# app/controllers/api/v1/example_controller.rb

# 4. テストを再実行（成功することを確認）
bundle exec rails test test/controllers/api/v1/example_controller_test.rb

# 5. リファクタリング
```

### Git ワークフロー

```bash
# 1. ブランチ作成
git checkout -b feature/new-api-endpoint

# 2. 開発・テスト
# ... コードを書く ...
bundle exec rails test

# 3. コミット
git add .
git commit -m "Add new API endpoint with tests"

# 4. プッシュ
git push origin feature/new-api-endpoint

# 5. プルリクエスト作成
# GitHubでプルリクエストを作成
```

## 🧪 テスト

詳細なテスト方法は **[テストガイド](docs/TEST_GUIDE.md)** を参照してください。

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

### 認証

```
GET    /auth/login                    # ログインページ
GET    /auth/google_oauth2           # Google OAuth 開始
GET    /auth/google_oauth2/callback  # OAuth コールバック
DELETE /auth/logout                  # ログアウト
```

### ファイル管理（認証必要）

```
GET    /api/v1/files          # ファイル一覧
GET    /api/v1/files/:id      # ファイル詳細
POST   /api/v1/files          # ファイルアップロード
DELETE /api/v1/files/:id      # ファイル削除
```

## ☁️ AWS デプロイ

詳細なAWSデプロイ方法は **[AWSデプロイガイド](docs/AWS_DEPLOY.md)** を参照してください。

## 🔄 CI/CD パイプライン

詳細なCI/CD設定は以下のドキュメントを参照してください：

- 📖 **[AWSデプロイガイド](docs/AWS_DEPLOY.md#cicd統合)** - GitHub Actionsでの自動デプロイ
- 📖 **[テストガイド](docs/TEST_GUIDE.md#cicd統合)** - テスト実行のCI/CD設定


## 💡 コスト最適化のポイント

詳細なコスト最適化については **[AWSデプロイガイド](docs/AWS_DEPLOY.md#コスト最適化)** を参照してください。

## ファイル構成

```
├── app/
│   ├── controllers/
│   │   ├── api/v1/
│   │   │   ├── base_controller.rb
│   │   │   └── files_controller.rb
│   │   ├── auth_controller.rb          # OAuth認証
│   │   ├── home_controller.rb          # ダッシュボード
│   │   └── application_controller.rb   # 認証機能付きベース
│   ├── models/
│   │   ├── user.rb                     # ユーザーモデル
│   │   ├── session.rb                  # セッションモデル
│   │   └── application_record.rb
│   └── views/
│       ├── auth/
│       │   └── login.html.erb          # ログインページ
│       └── home/
│           └── index.html.erb          # ダッシュボード
├── config/
│   ├── environments/
│   │   ├── development.rb
│   │   ├── docker.rb
│   │   ├── test.rb
│   │   └── production.rb
│   ├── initializers/
│   │   ├── active_storage.rb
│   │   ├── aws.rb
│   │   ├── omniauth.rb                 # OAuth設定
│   │   └── security.rb                 # セキュリティ設定
│   ├── storage.yml
│   ├── database.yml
│   └── routes.rb                       # OAuthルーティング
├── db/migrate/
│   ├── 20250101000001_create_users.rb  # ユーザーテーブル
│   └── 20250101000002_create_sessions.rb # セッションテーブル
├── test/
│   ├── models/
│   │   ├── user_test.rb                # ユーザーモデルテスト
│   │   └── session_test.rb             # セッションモデルテスト
│   ├── controllers/
│   │   ├── auth_controller_test.rb     # 認証コントローラーテスト
│   │   └── security_test.rb            # セキュリティテスト
│   └── integration/
│       └── oauth_integration_test.rb   # OAuth統合テスト
├── scripts/
│   ├── aws-deploy.sh
│   ├── setup-aws-resources.sh
│   ├── setup-dev.sh
│   └── start_app.sh
├── docs/
│   └── GOOGLE_OAUTH_SETUP.md           # OAuth設定ガイド
├── Dockerfile
├── Dockerfile.production
├── docker-compose.yml
└── README.md
```

## 🔧 トラブルシューティング

詳細なトラブルシューティングは以下のドキュメントを参照してください：

- 📖 **[AWSデプロイガイド](docs/AWS_DEPLOY.md#トラブルシューティング)** - AWS関連の問題
- 📖 **[テストガイド](docs/TEST_GUIDE.md#トラブルシューティング)** - テスト関連の問題


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
