# AWS CLI デプロイガイド

AWS CLIを使用してApp Runnerにアプリケーションをデプロイする方法を説明します。

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

# 詳細は [AWS_PROFILE_SETUP.md](AWS_PROFILE_SETUP.md) を参照
```

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

## 🔧 関連ドキュメント

- **[AWS_PROFILE_SETUP.md](AWS_PROFILE_SETUP.md)** - AWSプロファイル設定ガイド
- **[TEST_GUIDE.md](TEST_GUIDE.md)** - テスト実行ガイド

---

**次のステップ**: デプロイが完了したら、[TEST_GUIDE.md](TEST_GUIDE.md)を参照してアプリケーションのテストを実行してください。
