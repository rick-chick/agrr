# AWS CLI デプロイガイド

AWS CLIを使用してApp Runnerにアプリケーションをデプロイする完全ガイドです。

## 📋 目次

- [クイックスタート](#クイックスタート)
- [開発環境セットアップ](#開発環境セットアップ)
- [AWS認証情報の設定](#aws認証情報の設定)
- [AWSリソースの作成](#awsリソースの作成)
- [環境変数の設定](#環境変数の設定)
- [デプロイ実行](#デプロイ実行)
- [コマンドリファレンス](#コマンドリファレンス)
- [詳細手順](#詳細手順)
- [設定ファイル](#設定ファイル)
- [トラブルシューティング](#トラブルシューティング)
- [コスト最適化](#コスト最適化)
- [セキュリティ設定](#セキュリティ設定)
- [監視とメトリクス](#監視とメトリクス)
- [CI/CD統合](#cicd統合)
- [AWSプロファイル設定](#awsプロファイル設定)
- [ECRベースデプロイ](#ecrベースデプロイ)
- [参考資料](#参考資料)

## 🚀 クイックスタート

### 1. 前提条件

```bash
# 必要なツールをインストール
# AWS CLI
aws --version  # v2.x 推奨

# Docker
docker --version

# jq (JSONパーサー)
jq --version
```

## 🔧 開発環境セットアップ

### Method 1: GitHub Codespaces ⭐ (最推奨)

```bash
# GitHubリポジトリで:
Code → Codespaces → Create codespace on main

# 自動的に全てセットアップされます！
# ターミナルで即座に実行:
bundle exec rails test
rails server
```

### Method 2: Docker Compose

```bash
# 開発サーバー起動
docker-compose up

# 別のターミナルでコマンド実行
docker-compose exec web bundle exec rails console
docker-compose exec web bundle exec rails test
```

## 🔐 AWS認証情報の設定

### 方法1: デフォルトプロファイル

```bash
# AWS CLIの設定
aws configure

# または環境変数で設定
export AWS_ACCESS_KEY_ID=your_access_key
export AWS_SECRET_ACCESS_KEY=your_secret_key
export AWS_REGION=ap-northeast-1
```

### 方法2: プロファイルを使用（推奨）

```bash
# プロファイルを作成
aws configure --profile agrr-admin

# プロファイルを環境変数で指定
export AWS_PROFILE=agrr-admin
```

詳細は [AWSプロファイル設定](#awsプロファイル設定) セクションを参照してください

## 🏗 AWSリソースの作成

```bash
# 必要なAWSリソースとIAM権限を自動作成
AWS_IAM_USER=agrr-admin ./scripts/setup-aws-resources.sh setup

# これにより以下が作成されます:
# - IAM権限の設定 (S3, App Runner, EFS, IAM)
# - S3バケット (production/test)
# - IAMロール
# - EFS (永続ストレージ)
# - .env.aws 設定ファイル
```

## ⚙️ 環境変数の設定

`.env.aws`ファイルを編集して必要な値を設定:

```bash
# .env.aws の例
AWS_REGION=ap-northeast-1
AWS_ACCOUNT_ID=123456789012

# S3バケット設定
AWS_S3_BUCKET=agrr-123456789012-production
AWS_S3_BUCKET_TEST=agrr-123456789012-test

# ECR設定
ECR_REPOSITORY_NAME=agrr
ECR_REPOSITORY_URI=123456789012.dkr.ecr.ap-northeast-1.amazonaws.com/agrr

# App Runner設定
SERVICE_NAME_PRODUCTION=agrr-production
SERVICE_NAME_TEST=agrr-test
IAM_ROLE_ARN=arn:aws:iam::123456789012:role/AppRunnerServiceRole
ECR_ACCESS_ROLE_ARN=arn:aws:iam::123456789012:role/AppRunnerECRAccessRole

# 本番環境用の追加設定
RAILS_MASTER_KEY=your_rails_master_key_here
ALLOWED_HOSTS=your-app-runner-url.awsapprunner.com
```

## 🚀 デプロイ実行

```bash
# 本番環境にデプロイ（プロファイル使用）
AWS_PROFILE=agrr-admin AWS_IAM_USER=agrr-admin ./scripts/aws-deploy.sh production deploy

# テスト環境にデプロイ
AWS_PROFILE=agrr-admin AWS_IAM_USER=agrr-admin ./scripts/aws-deploy.sh aws_test deploy

# または環境変数で事前設定
export AWS_PROFILE=agrr-admin
export AWS_IAM_USER=agrr-admin
./scripts/aws-deploy.sh production deploy
```

## 📚 コマンドリファレンス

### aws-deploy.sh

```bash
# 基本的な使用方法
./scripts/aws-deploy.sh [environment] [command]

# 使用例
./scripts/aws-deploy.sh production deploy    # 本番環境にデプロイ
./scripts/aws-deploy.sh aws_test deploy      # テスト環境にデプロイ
./scripts/aws-deploy.sh production info      # サービス情報表示
./scripts/aws-deploy.sh production delete    # サービス削除
```

**環境**: `production`（デフォルト）, `aws_test`  
**コマンド**: `deploy`（デフォルト）, `list`, `info`, `delete`

### setup-aws-resources.sh

```bash
# 基本的な使用方法
./scripts/setup-aws-resources.sh [command]

# 使用例
./scripts/setup-aws-resources.sh setup         # 全リソース作成（初回推奨）
./scripts/setup-aws-resources.sh permissions   # IAM権限設定
./scripts/setup-aws-resources.sh s3            # S3バケット作成
```

**コマンド**: `setup`, `permissions`, `fix`, `s3`, `iam`, `efs`

## 📝 詳細手順

### AWSリソースの個別作成

```bash
# 必要なリソースを個別に作成
./scripts/setup-aws-resources.sh s3      # S3バケット
./scripts/setup-aws-resources.sh iam     # IAMロール
./scripts/setup-aws-resources.sh efs     # EFS
```

### デプロイコマンド

```bash
# サービスの管理
./scripts/aws-deploy.sh production deploy    # デプロイ
./scripts/aws-deploy.sh production list      # 一覧表示
./scripts/aws-deploy.sh production info      # 情報表示
./scripts/aws-deploy.sh production delete    # 削除
```

## ⚙️ 設定ファイル

### ECRベースデプロイメント

このプロジェクトはECRベースのデプロイメント方式を使用しています。YAMLファイルによる設定は非推奨です。

**推奨方法:**
```bash
# 本番環境デプロイ
./scripts/aws-deploy.sh production deploy

# テスト環境デプロイ
./scripts/aws-deploy.sh aws_test deploy
```

**非推奨方法:**
- `apprunner.yaml` や `apprunner-test.yaml` を使用した設定
- GitHub連携による自動デプロイ
- ソースコードベースのデプロイ

## 🔧 トラブルシューティング

### よくあるエラー

```bash
# AWS認証エラー
aws configure

# S3バケットが存在しない
./scripts/setup-aws-resources.sh s3

# IAM権限不足
# 管理者権限を持つユーザーで実行

# Dockerイメージビルドエラー
# Dockerfile.productionの存在確認
```

### デバッグ方法

```bash
# デプロイ状況の確認
./scripts/aws-deploy.sh production info

# ヘルスチェック
curl https://your-app-runner-url.awsapprunner.com/api/v1/health
```

## 💰 コスト最適化

**月額コスト見積もり**: $2.35-5.35

- App Runner: $2-5
- EFS: $0.30
- S3: $0.023

**コスト削減のポイント**:
- App Runnerの自動スケーリング
- EFSの最適化
- S3のライフサイクル設定

## 🔒 セキュリティ設定

### 1. IAMポリシー

最小権限の原則に基づいてIAMポリシーを設定:

```json
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "apprunner:*"
            ],
            "Resource": "*"
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:GetObject",
                "s3:PutObject",
                "s3:DeleteObject",
                "s3:ListBucket"
            ],
            "Resource": [
                "arn:aws:s3:::your-bucket-name",
                "arn:aws:s3:::your-bucket-name/*"
            ]
        }
    ]
}
```

### 2. 環境変数の管理

```bash
# 機密情報は環境変数で管理
export RAILS_MASTER_KEY=$(openssl rand -base64 32)
export AWS_SECRET_ACCESS_KEY=your_secret_key

# App Runnerの環境変数設定で使用
```

## 📈 監視とメトリクス

### 1. CloudWatchメトリクス

- **CPU使用率**: App RunnerのCPU使用状況
- **メモリ使用率**: メモリの使用状況
- **リクエスト数**: HTTPリクエストの数
- **レスポンス時間**: レスポンス時間の分布

### 2. アラート設定

```bash
# CloudWatchアラームの作成例
aws cloudwatch put-metric-alarm \
    --alarm-name "High-CPU-Usage" \
    --alarm-description "Alert when CPU usage is high" \
    --metric-name CPUUtilization \
    --namespace AWS/AppRunner \
    --statistic Average \
    --period 300 \
    --threshold 80 \
    --comparison-operator GreaterThanThreshold
```

## 🔄 CI/CD統合

### GitHub Actionsでの自動デプロイ

```yaml
# .github/workflows/deploy.yml
name: Deploy to AWS App Runner

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Configure AWS credentials
        uses: aws-actions/configure-aws-credentials@v2
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: ap-northeast-1
      
      - name: Deploy to App Runner
        run: ./scripts/aws-deploy.sh production deploy
```

## 📚 参考資料

- [AWS App Runner Documentation](https://docs.aws.amazon.com/apprunner/)
- [AWS CLI Reference](https://docs.aws.amazon.com/cli/latest/reference/)
- [Docker Documentation](https://docs.docker.com/)
- [Rails Deployment Guide](https://guides.rubyonrails.org/deployment.html)

---

## 🔐 AWSプロファイル設定

### プロファイルの作成

```bash
# 新しいプロファイルを作成
aws configure --profile agrr-admin

# プロンプトに従って入力:
# AWS Access Key ID: [your-access-key]
# AWS Secret Access Key: [your-secret-key]
# Default region name: ap-northeast-1
# Default output format: json
```

### プロファイルの確認

```bash
# 設定されたプロファイルを確認
aws configure list-profiles

# 特定のプロファイルの設定を確認
aws configure list --profile agrr-admin

# プロファイルでの認証確認
aws sts get-caller-identity --profile agrr-admin
```

### 環境変数での使用

```bash
# プロファイルを環境変数で指定
export AWS_PROFILE=agrr-admin

# デプロイスクリプトを実行
./scripts/aws-deploy.sh production deploy
```

### デプロイでの使用例

#### 基本的な使用方法

```bash
# 環境変数でプロファイルを指定
AWS_PROFILE=agrr-admin ./scripts/aws-deploy.sh production deploy

# テスト環境へのデプロイ
AWS_PROFILE=agrr-admin ./scripts/aws-deploy.sh aws_test deploy
```

#### AWSリソース作成での使用

```bash
# プロファイルを指定してAWSリソースを作成
AWS_PROFILE=agrr-admin ./scripts/setup-aws-resources.sh setup
```

#### 複数プロファイルの管理

```bash
# 本番環境用プロファイル
AWS_PROFILE=agrr-prod ./scripts/aws-deploy.sh production deploy

# テスト環境用プロファイル
AWS_PROFILE=agrr-test ./scripts/aws-deploy.sh aws_test deploy

# 開発環境用プロファイル
AWS_PROFILE=agrr-dev ./scripts/setup-aws-resources.sh setup
```

### プロファイル設定のベストプラクティス

#### 1. プロファイル命名規則

```
agrr-prod     # 本番環境
agrr-test     # テスト環境
agrr-dev      # 開発環境
agrr-admin    # 管理者権限
```

#### 2. 権限の分離

```bash
# 本番環境用（最小権限）
aws configure --profile agrr-prod
# - App Runner サービス作成/更新権限
# - S3 バケットアクセス権限

# 管理者用（全権限）
aws configure --profile agrr-admin
# - IAM ロール作成権限
# - S3 バケット作成権限
```

#### 3. セキュリティ設定

```bash
# プロファイルの権限確認
aws iam get-user --profile agrr-admin
aws iam list-attached-user-policies --user-name your-username --profile agrr-admin

# アクセスキーのローテーション
aws iam create-access-key --profile agrr-admin
aws iam delete-access-key --access-key-id old-key-id --profile agrr-admin
```

### プロファイルのトラブルシューティング

#### プロファイルが見つからない

```bash
# エラー: The config profile (agrr-admin) could not be found
# 解決方法:
aws configure list-profiles  # プロファイル一覧確認
aws configure --profile agrr-admin  # プロファイル作成
```

#### 権限不足エラー

```bash
# エラー: User is not authorized to perform: apprunner:CreateService
# 解決方法:
# 1. IAMユーザーに必要な権限を追加
# 2. 管理者プロファイルを使用
AWS_PROFILE=agrr-admin ./scripts/aws-deploy.sh production deploy
```

#### リージョン不一致エラー

```bash
# エラー: An error occurred (InvalidRegion) when calling the CreateService operation
# 解決方法:
aws configure --profile agrr-admin  # リージョンを ap-northeast-1 に設定
# または環境変数で指定
AWS_REGION=ap-northeast-1 AWS_PROFILE=agrr-admin ./scripts/aws-deploy.sh production deploy
```

---

## 📦 ECRベースデプロイ

このプロジェクトはECRベースのデプロイメント方式を使用しています。ローカルでビルドしたDockerイメージをECRにプッシュし、App Runnerでデプロイします。

### デプロイメントフロー

```
1. setup-aws-resources.sh
   ├─ IAMポリシー作成（S3, IAM, AppRunner, ECR）
   ├─ IAMロール作成（AppRunnerServiceRole）
   ├─ S3バケット作成（production, test）
   ├─ ECRリポジトリ作成
   └─ .env.aws 設定ファイル生成

2. aws-deploy.sh
   ├─ Dockerイメージビルド（Dockerfile.production）
   ├─ ECRへログイン
   ├─ イメージをECRへプッシュ
   └─ App Runnerサービス作成/更新
```

### ビルドプロセス

#### 1. Dockerイメージのビルド

```bash
docker build -f Dockerfile.production -t agrr:production-20241004-143000 .
```

#### 2. ECRへのログイン

```bash
aws ecr get-login-password | docker login --username AWS --password-stdin \
  ${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com
```

#### 3. イメージのタグ付けとプッシュ

```bash
docker tag agrr:production-20241004-143000 \
  ${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/agrr:production-20241004-143000

docker tag agrr:production-20241004-143000 \
  ${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/agrr:latest

docker push ${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/agrr:production-20241004-143000
docker push ${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/agrr:latest
```

#### 4. App Runnerサービスの作成/更新

ECRイメージURIを指定してApp Runnerサービスを作成します:

```json
{
  "SourceConfiguration": {
    "ImageRepository": {
      "ImageIdentifier": "${ACCOUNT_ID}.dkr.ecr.${REGION}.amazonaws.com/agrr:production-20241004-143000",
      "ImageRepositoryType": "ECR",
      "ImageConfiguration": {
        "Port": "3000",
        "RuntimeEnvironmentVariables": [
          {"Name": "RAILS_ENV", "Value": "production"},
          {"Name": "AWS_S3_BUCKET", "Value": "agrr-{account-id}-production"}
        ]
      }
    }
  },
  "InstanceConfiguration": {
    "Cpu": "1024",
    "Memory": "2048",
    "InstanceRoleArn": "arn:aws:iam::{account-id}:role/AppRunnerServiceRole"
  }
}
```

### デフォルト値について

`aws-deploy.sh`は以下のデフォルト値を使用します：

| 項目 | デフォルト値 |
|------|-------------|
| ECRリポジトリ名 | `agrr` |
| IAMロール | `arn:aws:iam::{account-id}:role/AppRunnerServiceRole` |
| S3バケット（production） | `agrr-{account-id}-production` |
| S3バケット（test） | `agrr-{account-id}-test` |
| サービス名（production） | `agrr-production` |
| サービス名（test） | `agrr-test` |

これらは`setup-aws-resources.sh`が作成するリソース名と一致しているため、**追加設定なしでデプロイ可能**です。

### ECRデプロイのメリット

| 項目 | 旧方式（YAML/GitHub） | 新方式（ECR） |
|------|---------------------|-------------|
| ソース | GitHubリポジトリ | ECRコンテナレジストリ |
| ビルド場所 | App Runner内 | ローカル |
| デプロイ方法 | yamlファイル | CLIパラメータ |
| 自動デプロイ | GitHub push時 | 手動実行 |
| ビルド時間 | 遅い | 速い（事前ビルド済み） |
| コスト | ビルド時間課金 | ストレージ課金 |
| ロールバック | 困難 | イメージタグ指定で簡単 |

### セキュリティのベストプラクティス

1. **IAMロールの最小権限原則**
   - すべてのポリシーがリソーススコープ（`agrr-*`, `AppRunnerServiceRole*`）に制限されています

2. **ECRイメージスキャン**
   - イメージプッシュ時に自動的に脆弱性スキャンが実行されます

3. **イメージライフサイクル管理**
   - 最新10個のイメージのみ保持し、古いイメージは自動削除されます

4. **環境変数の管理**
   - `.env.aws`ファイルは`.gitignore`に追加し、リポジトリにコミットしないでください
   - 本番環境の`RAILS_MASTER_KEY`は厳重に管理してください

---

## 🔧 関連ドキュメント

- **[TEST_GUIDE.md](TEST_GUIDE.md)** - テスト実行ガイド
- **[README.md](../README.md)** - プロジェクト概要

---

**次のステップ**: デプロイが完了したら、[TEST_GUIDE.md](TEST_GUIDE.md)を参照してアプリケーションのテストを実行してください。
