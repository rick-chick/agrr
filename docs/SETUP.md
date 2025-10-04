# セットアップガイド

このドキュメントでは、Rails 8 + SQLite + S3 + App Runnerアプリケーションのセットアップ手順を詳しく説明します。

## 📋 前提条件

### 必須

- Ruby 3.3.6 以上
- SQLite 3.8.0 以上
- Git
- Bundler

### オプション（環境に応じて）

- Docker & Docker Compose（Docker環境を使用する場合）
- AWS CLI（AWSデプロイ時）
- AWS アカウント（AWSデプロイ時）

## 🚀 ローカル開発環境のセットアップ

### 1. リポジトリのクローン

```bash
git clone <your-repository-url>
cd agrr
```

### 2. Rubyのインストール確認

```bash
ruby --version
# Ruby 3.3.6以上が必要
```

Rubyがインストールされていない場合は、以下のいずれかを使用してインストール：

- [rbenv](https://github.com/rbenv/rbenv)
- [rvm](https://rvm.io/)
- [asdf](https://asdf-vm.com/)

```bash
# rbenvの場合
rbenv install 3.3.6
rbenv local 3.3.6

# rvmの場合
rvm install 3.3.6
rvm use 3.3.6
```

### 3. 依存関係のインストール

```bash
# Gemをインストール
bundle install
```

### 4. 環境変数の設定

```bash
# .envファイルを作成
cp env.example .env

# .envファイルを編集（開発環境ではAWS設定は不要）
# RAILS_MASTER_KEYのみ設定が必要な場合があります
```

### 5. マスターキーの生成（必要な場合）

```bash
# config/master.keyが存在しない場合
rails credentials:edit
# エディタが開くので、保存して閉じる
```

### 6. データベースのセットアップ

```bash
# データベースの作成とマイグレーション
rails db:prepare

# Solid Queue/Cache/Cableのインストール
rails solid_queue:install
rails solid_cache:install
rails solid_cable:install

# マイグレーションの実行
rails db:migrate
```

### 7. 開発サーバーの起動

```bash
# Railsサーバーを起動
rails server

# または
bin/rails server
```

ブラウザで http://localhost:3000 にアクセスして動作確認。

### 8. Solid Queueワーカーの起動（バックグラウンドジョブを使用する場合）

別のターミナルで：

```bash
bundle exec rails solid_queue:start
```

## 🐳 Docker開発環境のセットアップ

### 1. Dockerのインストール確認

```bash
docker --version
docker-compose --version
```

### 2. Docker Composeでアプリケーションを起動

```bash
# イメージのビルドとコンテナの起動
docker-compose up --build

# バックグラウンドで起動する場合
docker-compose up -d
```

### 3. データベースのセットアップ

```bash
# コンテナ内でコマンドを実行
docker-compose exec web rails db:prepare
docker-compose exec web rails solid_queue:install
docker-compose exec web rails solid_cache:install
docker-compose exec web rails solid_cable:install
docker-compose exec web rails db:migrate
```

### 4. アクセス

ブラウザで http://localhost:3000 にアクセス。

### 5. 停止

```bash
# コンテナを停止
docker-compose down

# データも削除する場合
docker-compose down -v
```

## ☁️ AWS環境のセットアップ

### 前提条件

- AWSアカウント
- AWS CLI設定済み
- S3バケット作成済み
- （オプション）独自ドメイン

### 1. S3バケットの作成

```bash
# S3バケットを作成
aws s3 mb s3://your-app-bucket-name --region ap-northeast-1

# CORS設定を適用
aws s3api put-bucket-cors \
  --bucket your-app-bucket-name \
  --cors-configuration file://cors.json

# パブリックアクセスをブロック（推奨）
aws s3api put-public-access-block \
  --bucket your-app-bucket-name \
  --public-access-block-configuration \
  "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
```

### 2. IAMユーザーの作成とポリシーの設定

```bash
# IAMユーザーを作成（AWS Consoleから推奨）
# 以下のポリシーをアタッチ：
```

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:PutObject",
        "s3:GetObject",
        "s3:DeleteObject",
        "s3:ListBucket"
      ],
      "Resource": [
        "arn:aws:s3:::your-app-bucket-name",
        "arn:aws:s3:::your-app-bucket-name/*"
      ]
    }
  ]
}
```

アクセスキーとシークレットキーを取得してメモ。

### 3. EFS（Elastic File System）の作成

1. AWS Console → EFS → ファイルシステムの作成
2. VPCを選択（App Runnerと同じVPC）
3. ファイルシステムを作成
4. アクセスポイントを作成（オプション）:
   - パス: `/agrr`
   - POSIX ユーザー: 1000
   - ルートディレクトリの作成権限: 755

### 4. App Runnerサービスの作成

#### テスト環境

```bash
# apprunner-test.yamlを編集して環境変数を設定
# 以下のコマンドでサービスを作成（または AWS Console から）
```

AWS Consoleから作成する場合：

1. AWS Console → App Runner → サービスの作成
2. ソースタイプ: ソースコードリポジトリ（GitHub等）
3. ビルド設定: `apprunner-test.yaml`を使用
4. サービス設定:
   - サービス名: `agrr-test`
   - CPU: 0.25 vCPU
   - メモリ: 0.5 GB
   - ポート: 3000
5. 環境変数を設定（apprunner-test.yamlを参照）
6. ファイルシステム設定:
   - EFSファイルシステムID: （作成したEFS）
   - コンテナパス: `/app/storage`
   - アクセスポイントID: （作成したアクセスポイント）

#### 本番環境

テスト環境と同様に、`apprunner.yaml`を使用して作成。

### 5. デプロイの確認

```bash
# App Runnerのログを確認
aws apprunner describe-service --service-arn <your-service-arn>

# デプロイが完了したら、サービスURLにアクセス
curl https://your-app-runner-url.ap-northeast-1.awsapprunner.com/up
```

### 6. データベースのマイグレーション

App Runnerでは、Dockerfile.productionのCMDで自動的に`rails db:prepare`が実行されます。

手動で実行する場合：

```bash
# App Runnerのタスク定義で実行、またはSSH接続して実行
# （App Runnerは直接SSHできないため、別途設定が必要）
```

## 🔐 セキュリティ設定

### 1. RAILS_MASTER_KEYの管理

- **絶対に**リポジトリにコミットしない
- 環境変数として設定
- AWS Secrets Managerの使用を検討

### 2. AWS認証情報の管理

- IAMロールの使用を推奨（可能な場合）
- 最小権限の原則に従う
- 定期的なキーローテーション

### 3. S3バケットのセキュリティ

- パブリックアクセスをブロック
- バケットポリシーで適切な権限設定
- 暗号化を有効化（AES-256）

## 🧪 テストの実行

```bash
# 全テストを実行
rails test

# システムテストを実行
rails test:system

# 特定のテストを実行
rails test test/controllers/api/v1/files_controller_test.rb
```

## 📊 モニタリング

### App Runnerのログ

```bash
# AWS CloudWatch Logsでログを確認
aws logs tail /aws/apprunner/agrr-production/service --follow
```

### パフォーマンスモニタリング

- AWS CloudWatch メトリクス
- App Runner ダッシュボード
- SQLite データベースサイズの監視

## 🔄 更新とデプロイ

### コードの更新

1. ローカルで変更をコミット
2. GitHubにプッシュ
3. App Runnerが自動的に検出してデプロイ（自動デプロイ設定時）

### 手動デプロイ

```bash
# App Runner CLIを使用
aws apprunner start-deployment --service-arn <your-service-arn>
```

## ❓ トラブルシューティング

詳細は [README.md のトラブルシューティングセクション](README.md#-トラブルシューティング) を参照してください。

### よくある質問

**Q: SQLiteは本番環境で本当に使えるの？**

A: Rails 8とLitestackの組み合わせで、中小規模のアプリケーションには十分対応できます。ただし、以下の場合はPostgreSQLを検討してください：
- 複数のアプリケーションサーバーからの同時アクセスが必要
- 非常に高い書き込み頻度
- 100GB以上のデータベースサイズ

**Q: EFSのコストが心配です**

A: 小規模アプリケーションの場合、データベースサイズは通常1GB以下で、月額約$0.30程度です。S3へのバックアップも検討できます。

**Q: スケーリングはどうするの？**

A: App Runnerが自動的にスケーリングしますが、SQLiteの制約により、読み取りは複数インスタンスで対応できますが、書き込みは単一インスタンスが推奨です。

## 📚 次のステップ

1. [API ドキュメントの確認](README.md#api-エンドポイント)
2. カスタムコントローラーの追加
3. バックグラウンドジョブの実装
4. テストの追加
5. CI/CD パイプラインの設定

## 🤝 サポート

問題が発生した場合は、GitHubのIssueで報告してください。



