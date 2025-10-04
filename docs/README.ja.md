# AGRR - Rails 8 + SQLite + S3 + App Runner

**Rails 8の最新機能を活用したコストパフォーマンスに優れたアプリケーション構成**

PostgreSQLやRedis不要！SQLiteとDockerだけで本番環境に耐えられるRailsアプリケーションです。

## 🚀 クイックスタート（2025年推奨）

### 推奨方法1: GitHub Codespaces ⭐（最も簡単）

```bash
# GitHubリポジトリページで:
Code → Codespaces → Create codespace on main

# 自動的にブラウザで開発環境が起動
# ターミナルで即座に実行可能:
bundle exec rails test
rails server
```

**メリット:**
- ゼロインストール
- どのOSからでもアクセス可能
- 月60時間まで無料
- すべての依存関係が自動セットアップ

### 推奨方法2: Dev Containers（VS Code）

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

### 推奨方法3: Docker Compose

```bash
# サーバー起動
docker-compose up

# テスト実行
docker-compose exec web bundle exec rails test

# コンソール
docker-compose exec web rails console
```

## 📊 技術スタック

### フレームワーク・言語
- **Ruby 3.3.x** - 最新の安定版
- **Rails 8.0.x** - 最新のRailsフレームワーク

### データベース・ストレージ
- **SQLite 3.x** - 開発から本番まで全環境で使用
- **Solid Queue** - SQLiteベースのバックグラウンドジョブ
- **Solid Cache** - SQLiteベースのキャッシュ
- **Solid Cable** - SQLiteベースのAction Cable（WebSocket）
- **Active Storage + S3** - ファイル保存

### インフラ
- **Docker** - コンテナ化
- **AWS App Runner** - サーバーレスデプロイ
- **Amazon S3** - ファイルストレージ
- **Amazon EFS** - 永続化ストレージ（SQLite用）

## 💰 コスト削減のポイント

| 従来構成 | この構成 | 削減額 |
|---------|---------|--------|
| RDS PostgreSQL | SQLite | $15-50/月 |
| ElastiCache Redis | Solid Queue/Cache | $15-30/月 |
| **合計削減** | | **$30-80/月** |

**実際のコスト（月額概算）:**
- App Runner: $2-5
- EFS: $0.30
- S3: $0.15-1
- **合計: $2.45-6.30/月** 🎯

## 🧪 テスト実行

### Dev Containers / Codespaces内で

```bash
# 全テストを実行
bundle exec rails test

# 特定のテストを実行
bundle exec rails test test/controllers/api/v1/base_controller_test.rb

# 並列実行（高速化）
bundle exec rails test -j

# カバレッジ付き
COVERAGE=true bundle exec rails test
```

### ローカル（Docker使用）

```bash
# テスト実行
docker-compose exec web bundle exec rails test

# またはスクリプト使用
chmod +x scripts/test-docker.sh
./scripts/test-docker.sh
```

### CI/CD（GitHub Actions）

```bash
# プッシュすると自動実行
git add .
git commit -m "テスト追加"
git push origin main

# 結果はGitHubのActionsタブで確認
```

## 📁 プロジェクト構成

```
.
├── .devcontainer/              # Dev Containers設定 ⭐
│   ├── devcontainer.json
│   ├── docker-compose.yml
│   ├── Dockerfile
│   └── README.md
├── .github/
│   └── workflows/
│       └── test.yml            # GitHub Actions CI/CD ⭐
├── app/
│   ├── controllers/
│   │   └── api/v1/
│   └── models/
├── config/
│   ├── environments/
│   │   ├── development.rb
│   │   ├── test.rb
│   │   ├── aws_test.rb
│   │   └── production.rb
│   ├── database.yml            # SQLite設定
│   └── storage.yml             # S3設定
├── test/                       # Minitestテスト ⭐
│   ├── controllers/
│   ├── integration/
│   ├── system/
│   └── test_helper.rb
├── docker-compose.yml          # Docker Compose設定
├── Dockerfile                  # 開発用Dockerfile
├── Dockerfile.production       # 本番用Dockerfile
├── apprunner.yaml              # AWS App Runner設定
└── README.ja.md                # このファイル
```

## 🏗 環境構成

| 環境 | 用途 | データベース | ファイル保存 | 推奨アクセス方法 |
|------|------|--------------|--------------|------------------|
| **development** | ローカル開発 | SQLite | ローカルディスク | Dev Containers |
| **test** | テスト | SQLite | 一時ディスク | GitHub Actions |
| **docker** | Docker開発 | SQLite | Docker Volume | docker-compose |
| **aws_test** | AWSテスト | SQLite + EFS | S3 | App Runner |
| **production** | AWS本番 | SQLite + EFS | S3 | App Runner |

## 🌐 API エンドポイント

### ヘルスチェック

```bash
GET /api/v1/health

# レスポンス例
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

## ☁️ AWS デプロイ

### 必要なAWSリソース

1. **S3 バケット** - ファイル保存用
2. **App Runner サービス** - アプリケーション実行
3. **EFS（Elastic File System）** - SQLiteデータベースの永続化

### デプロイ手順

詳細は **[AWS_DEPLOY.md](AWS_DEPLOY.md)** を参照してください。

## 📚 ドキュメント

- **[README.md](README.md)** - 英語版（詳細）
- **[TEST_GUIDE.md](TEST_GUIDE.md)** - テスト詳細ガイド
- **[AWS_DEPLOY.md](AWS_DEPLOY.md)** - AWS CLIデプロイガイド
- **[.devcontainer/README.md](.devcontainer/README.md)** - Dev Containers ガイド

## 🔧 トラブルシューティング

### Dev Containersが起動しない

```bash
# Docker Desktopが起動していることを確認
# VSCodeのDev Containers拡張機能がインストール済みか確認
# F1 → "Dev Containers: Rebuild Container"
```

### テストが失敗する

```bash
# データベースをリセット
rails db:reset

# 依存関係を再インストール
bundle install

# Solid Queue/Cacheのセットアップ
rails solid_queue:install
rails solid_cache:install
rails db:migrate
```

### Docker Composeでエラー

```bash
# コンテナとボリュームを削除して再ビルド
docker-compose down -v
docker-compose build --no-cache
docker-compose up
```

## 💡 ベストプラクティス

### 開発フロー（2025年推奨）

1. **GitHub Codespaces または Dev Containers で開発** ⭐
   - 環境の一貫性が保証される
   - セットアップ不要
   
2. **テストを書いてからコミット**
   ```bash
   bundle exec rails test
   ```

3. **プッシュ後に自動CI/CD**
   - GitHub Actionsが自動実行
   - テストが通ったら自動デプロイ（設定次第）

### なぜこの構成なのか？

1. **MSYS2不要** - Windows環境でのネイティブビルド問題を回避
2. **環境の一貫性** - 全開発者が同じコンテナ環境を使用
3. **クラウドネイティブ** - GitHub Codespacesで場所を問わず開発可能
4. **CI/CD統合** - GitHub Actionsで自動テスト・デプロイ
5. **コスト効率** - SQLiteベースで外部サービス不要

## 🤝 コントリビューション

プルリクエストを歓迎します！

1. Fork the repository
2. GitHub Codespacesで開く（推奨）
3. Feature branchを作成
4. テストを書く
5. Pull Requestを作成

## 📄 ライセンス

MIT License

---

**2025年のモダンなRails開発を体験してください！** 🚀





