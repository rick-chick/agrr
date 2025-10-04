# AWS CLI デプロイガイド

AWS CLIを使用してApp Runnerにアプリケーションをデプロイする完全ガイドです。

## 📋 目次

- [クイックスタート](#クイックスタート)
- [コマンドリファレンス](#コマンドリファレンス)
- [AWSプロファイル設定](#awsプロファイル設定)
- [ECRベースデプロイ](#ecrベースデプロイ)
- [詳細手順](#詳細手順)
- [トラブルシューティング](#トラブルシューティング)

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

### 2. AWS認証情報の設定

#### 方法1: デフォルトプロファイル

```bash
# AWS CLIの設定
aws configure

# または環境変数で設定
export AWS_ACCESS_KEY_ID=your_access_key
export AWS_SECRET_ACCESS_KEY=your_secret_key
export AWS_REGION=ap-northeast-1
```

#### 方法2: プロファイルを使用（推奨）

```bash
# プロファイルを作成
aws configure --profile agrr-admin

# プロファイルを環境変数で指定
export AWS_PROFILE=agrr-admin
```

詳細は [AWSプロファイル設定](#awsプロファイル設定) セクションを参照してください

### 3. AWSリソースの作成

```bash
# 必要なAWSリソースとIAM権限を自動作成
AWS_IAM_USER=aggr-admin ./scripts/setup-aws-resources.sh setup

# これにより以下が作成されます:
# - IAM権限の設定 (S3, App Runner, EFS, IAM)
# - S3バケット (production/test)
# - IAMロール
# - EFS (永続ストレージ)
# - .env.aws 設定ファイル
```

### 4. 環境変数の設定

`.env.aws`ファイルを編集して必要な値を設定:

```bash
# .env.aws の例
AWS_REGION=ap-northeast-1
AWS_S3_BUCKET=agrr-123456789-production
AWS_S3_BUCKET_TEST=agrr-123456789-test

# 本番環境用の追加設定
RAILS_MASTER_KEY=your_rails_master_key_here
ALLOWED_HOSTS=your-app-runner-url.awsapprunner.com
```

### 5. デプロイ実行

```bash
# 本番環境にデプロイ（プロファイル使用）
AWS_PROFILE=agrr-admin AWS_IAM_USER=aggr-admin ./scripts/aws-deploy.sh production deploy

# テスト環境にデプロイ
AWS_PROFILE=agrr-admin AWS_IAM_USER=aggr-admin ./scripts/aws-deploy.sh aws_test deploy

# または環境変数で事前設定
export AWS_PROFILE=agrr-admin
export AWS_IAM_USER=aggr-admin
./scripts/aws-deploy.sh production deploy
```

## 📖 コマンドリファレンス

### aws-deploy.sh

デプロイスクリプトの完全なリファレンスです。

#### 使用方法

```bash
./scripts/aws-deploy.sh [environment] [command]
```

#### 引数

##### Environment（環境）

| 引数 | 説明 | サービス名 | S3バケット |
|------|------|-----------|-----------|
| `production` | 本番環境（**デフォルト**） | agrr-production | agrr-{ACCOUNT_ID}-production |
| `aws_test` | テスト環境 | agrr-test | agrr-{ACCOUNT_ID}-test |

##### Command（コマンド）

| コマンド | 説明 |
|---------|------|
| `deploy` | Dockerイメージをビルド、ECRにプッシュ、App Runnerにデプロイ（**デフォルト**） |
| `list` | 既存のApp Runnerサービス一覧を表示 |
| `info` | サービスの詳細情報（URL、ステータス、設定など）を表示 |
| `delete` | App Runnerサービスを削除 |
| `help` / `-h` / `--help` | ヘルプメッセージを表示 |

#### 使用例

```bash
# 本番環境にデプロイ（引数省略 = production deploy）
./scripts/aws-deploy.sh

# 本番環境にデプロイ（明示的）
./scripts/aws-deploy.sh production deploy

# テスト環境にデプロイ
./scripts/aws-deploy.sh aws_test deploy

# 本番環境のサービス情報を表示
./scripts/aws-deploy.sh production info

# サービス一覧を表示
./scripts/aws-deploy.sh production list

# 本番環境のサービスを削除
./scripts/aws-deploy.sh production delete

# ヘルプを表示
./scripts/aws-deploy.sh help
```

#### 環境変数

スクリプトは以下の環境変数を使用します（`.env.aws` またはシェルで設定）：

| 環境変数 | 説明 | デフォルト |
|---------|------|-----------|
| `AWS_PROFILE` | 使用するAWSプロファイル | default |
| `AWS_REGION` | デプロイ先のAWSリージョン | ap-northeast-1 |
| `RAILS_MASTER_KEY` | Rails暗号化キー（本番推奨） | - |
| `ALLOWED_HOSTS` | 許可するホスト（App Runner URL） | - |
| `ECR_REPOSITORY_NAME` | ECRリポジトリ名 | agrr |
| `IAM_ROLE_ARN` | App Runner用IAMロール | arn:aws:iam::{ACCOUNT_ID}:role/AppRunnerServiceRole |
| `SERVICE_NAME_PRODUCTION` | 本番環境のサービス名 | agrr-production |
| `SERVICE_NAME_TEST` | テスト環境のサービス名 | agrr-test |

#### プロファイルを使用した実行例

```bash
# プロファイルを指定してデプロイ
AWS_PROFILE=agrr-admin ./scripts/aws-deploy.sh production deploy

# 環境変数で事前設定
export AWS_PROFILE=agrr-admin
./scripts/aws-deploy.sh production deploy
```

### setup-aws-resources.sh

AWSリソース作成スクリプトのリファレンスです。

#### 使用方法

```bash
./scripts/setup-aws-resources.sh [command]
```

#### コマンド

| コマンド | 説明 |
|---------|------|
| `setup` | 全リソースを一括作成（IAM権限、S3、IAMロール、EFS、.env.aws） |
| `permissions` | IAM権限のみ設定（自動でfixも実行） |
| `fix` | 権限不足エラーのクイックフィックス |
| `s3` | S3バケットのみ作成 |
| `iam` | IAMロールとポリシーのみ作成 |
| `efs` | EFSのみ作成 |

#### 使用例

```bash
# 全リソースを作成（初回推奨）
./scripts/setup-aws-resources.sh setup

# IAM権限のみ設定
./scripts/setup-aws-resources.sh permissions

# S3バケットのみ作成
./scripts/setup-aws-resources.sh s3
```

#### 環境変数

| 環境変数 | 説明 | デフォルト |
|---------|------|-----------|
| `AWS_PROFILE` | 使用するAWSプロファイル | default |
| `AWS_REGION` | リソースを作成するリージョン | ap-northeast-1 |
| `AWS_IAM_USER` | IAMユーザー名（権限設定用） | 自動検出 |

## 📋 詳細手順

### AWSリソースの個別作成

```bash
# IAM権限設定（自動でfixも実行）
AWS_IAM_USER=aggr-admin ./scripts/setup-aws-resources.sh permissions

# 権限不足エラーのクイックフィックス（単体実行用）
AWS_IAM_USER=aggr-admin ./scripts/setup-aws-resources.sh fix

# S3バケットのみ作成
./scripts/setup-aws-resources.sh s3

# IAM権限とロールのみ作成
./scripts/setup-aws-resources.sh iam

# EFSのみ作成
./scripts/setup-aws-resources.sh efs
```

### デプロイコマンド

```bash
# 新しいサービスを作成
./scripts/aws-deploy.sh production deploy

# 既存サービスの一覧表示
./scripts/aws-deploy.sh production list

# サービス情報の表示
./scripts/aws-deploy.sh production info

# サービスの削除
./scripts/aws-deploy.sh production delete
```

## 🔧 設定ファイル

### apprunner.yaml (本番環境)

```yaml
version: 1.0
runtime: docker
build:
  dockerfile: Dockerfile.production
run:
  runtime-version: latest
  network:
    port: 3000
    env: PORT
  env:
    - name: RAILS_ENV
      value: production
    - name: RAILS_MASTER_KEY
      value: your_master_key_here
    - name: AWS_ACCESS_KEY_ID
      value: your_aws_access_key_id_here
    - name: AWS_SECRET_ACCESS_KEY
      value: your_aws_secret_access_key_here
    - name: AWS_REGION
      value: ap-northeast-1
    - name: AWS_S3_BUCKET
      value: your_s3_bucket_name_here
```

### apprunner-test.yaml (テスト環境)

```yaml
version: 1.0
runtime: docker
build:
  dockerfile: Dockerfile.production
run:
  runtime-version: latest
  network:
    port: 3000
    env: PORT
  env:
    - name: RAILS_ENV
      value: aws_test
    - name: AWS_S3_BUCKET_TEST
      value: your_s3_test_bucket_name_here
    # その他の設定は本番環境と同様
```

## 🛠 トラブルシューティング

### よくあるエラーと解決方法

#### 1. AWS認証エラー

```bash
# エラー: Unable to locate credentials
# 解決方法:
aws configure
# または環境変数を設定
export AWS_ACCESS_KEY_ID=your_key
export AWS_SECRET_ACCESS_KEY=your_secret
```

#### 2. S3バケットが存在しない

```bash
# エラー: The specified bucket does not exist
# 解決方法:
./scripts/setup-aws-resources.sh s3
```

#### 3. IAM権限不足

```bash
# エラー: User is not authorized to perform: apprunner:CreateService
# 解決方法: IAMユーザーにApp Runnerの権限を追加
# または管理者権限を持つユーザーで実行
```

#### 4. Dockerイメージビルドエラー

```bash
# エラー: Docker build failed
# 解決方法:
# 1. Dockerfile.productionの存在確認
# 2. 必要なファイルがコピーされているか確認
# 3. Dockerデーモンが起動しているか確認
```

### デバッグ方法

#### 1. デプロイ状況の確認

```bash
# サービスの詳細情報を表示
./scripts/aws-deploy.sh production info

# AWS CLIで直接確認
aws apprunner describe-service --service-arn your-service-arn
```

#### 2. ログの確認

```bash
# App Runnerのログを確認 (AWS Console)
# または CloudWatch Logs で確認
aws logs describe-log-groups --log-group-name-prefix /aws/apprunner
```

#### 3. ヘルスチェック

```bash
# デプロイ後のヘルスチェック
curl https://your-app-runner-url.awsapprunner.com/api/v1/health
```

## 💰 コスト最適化

### 月額コスト見積もり

| リソース | 使用量 | 月額コスト |
|----------|--------|------------|
| App Runner | 1 vCPU, 2 GB RAM | $2-5 |
| EFS | 1 GB | $0.30 |
| S3 | 1 GB | $0.023 |
| **合計** | | **$2.35-5.35** |

### コスト削減のポイント

1. **App Runnerの自動スケーリング**: 使用量に応じて自動的にスケールダウン
2. **EFSの最適化**: 必要最小限のストレージサイズ
3. **S3のライフサイクル**: 古いファイルの自動削除

## 🔐 セキュリティ設定

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

## 📊 監視とメトリクス

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

## 🚀 CI/CD統合

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

## 🔧 AWSプロファイル設定

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
