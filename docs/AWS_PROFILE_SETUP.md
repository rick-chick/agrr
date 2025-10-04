# AWS Profile 設定ガイド

AWS CLIでプロファイルを使用してデプロイする方法を説明します。

## 🔧 AWS Profile の設定

### 1. プロファイルの作成

```bash
# 新しいプロファイルを作成
aws configure --profile agrr-admin

# プロンプトに従って入力:
# AWS Access Key ID: [your-access-key]
# AWS Secret Access Key: [your-secret-key]
# Default region name: ap-northeast-1
# Default output format: json
```

### 2. プロファイルの確認

```bash
# 設定されたプロファイルを確認
aws configure list-profiles

# 特定のプロファイルの設定を確認
aws configure list --profile agrr-admin

# プロファイルでの認証確認
aws sts get-caller-identity --profile agrr-admin
```

### 3. 環境変数での使用

```bash
# プロファイルを環境変数で指定
export AWS_PROFILE=agrr-admin

# デプロイスクリプトを実行
./scripts/aws-deploy.sh production deploy
```

## 🚀 デプロイでの使用例

### 基本的な使用方法

```bash
# 環境変数でプロファイルを指定
AWS_PROFILE=agrr-admin ./scripts/aws-deploy.sh production deploy

# テスト環境へのデプロイ
AWS_PROFILE=agrr-admin ./scripts/aws-deploy.sh aws_test deploy
```

### AWSリソース作成での使用

```bash
# プロファイルを指定してAWSリソースを作成
AWS_PROFILE=agrr-admin ./scripts/setup-aws-resources.sh setup
```

### 複数プロファイルの管理

```bash
# 本番環境用プロファイル
AWS_PROFILE=agrr-prod ./scripts/aws-deploy.sh production deploy

# テスト環境用プロファイル
AWS_PROFILE=agrr-test ./scripts/aws-deploy.sh aws_test deploy

# 開発環境用プロファイル
AWS_PROFILE=agrr-dev ./scripts/setup-aws-resources.sh setup
```

## 📋 プロファイル設定のベストプラクティス

### 1. プロファイル命名規則

```
agrr-prod     # 本番環境
agrr-test     # テスト環境
agrr-dev      # 開発環境
agrr-admin    # 管理者権限
```

### 2. 権限の分離

```bash
# 本番環境用（最小権限）
aws configure --profile agrr-prod
# - App Runner サービス作成/更新権限
# - S3 バケットアクセス権限
# - EFS アクセス権限

# 管理者用（全権限）
aws configure --profile agrr-admin
# - IAM ロール作成権限
# - S3 バケット作成権限
# - EFS 作成権限
```

### 3. セキュリティ設定

```bash
# プロファイルの権限確認
aws iam get-user --profile agrr-admin
aws iam list-attached-user-policies --user-name your-username --profile agrr-admin

# アクセスキーのローテーション
aws iam create-access-key --profile agrr-admin
aws iam delete-access-key --access-key-id old-key-id --profile agrr-admin
```

## 🔍 トラブルシューティング

### よくあるエラーと解決方法

#### 1. プロファイルが見つからない

```bash
# エラー: The config profile (agrr-admin) could not be found
# 解決方法:
aws configure list-profiles  # プロファイル一覧確認
aws configure --profile agrr-admin  # プロファイル作成
```

#### 2. 権限不足エラー

```bash
# エラー: User is not authorized to perform: apprunner:CreateService
# 解決方法:
# 1. IAMユーザーに必要な権限を追加
# 2. 管理者プロファイルを使用
AWS_PROFILE=agrr-admin ./scripts/aws-deploy.sh production deploy
```

#### 3. リージョン不一致エラー

```bash
# エラー: An error occurred (InvalidRegion) when calling the CreateService operation
# 解決方法:
aws configure --profile agrr-admin  # リージョンを ap-northeast-1 に設定
# または環境変数で指定
AWS_REGION=ap-northeast-1 AWS_PROFILE=agrr-admin ./scripts/aws-deploy.sh production deploy
```

## 📊 プロファイル管理スクリプト

### プロファイル切り替えスクリプト

```bash
#!/bin/bash
# switch-profile.sh

PROFILE=$1

if [ -z "$PROFILE" ]; then
    echo "Usage: $0 <profile-name>"
    echo "Available profiles:"
    aws configure list-profiles
    exit 1
fi

export AWS_PROFILE=$PROFILE
echo "Switched to profile: $AWS_PROFILE"

# 認証確認
aws sts get-caller-identity
```

使用方法:
```bash
chmod +x switch-profile.sh
./switch-profile.sh agrr-admin
```

### プロファイル情報表示スクリプト

```bash
#!/bin/bash
# show-profiles.sh

echo "=== AWS Profile Information ==="
echo ""

for profile in $(aws configure list-profiles); do
    echo "Profile: $profile"
    echo "Region: $(aws configure get region --profile $profile)"
    echo "User: $(aws sts get-caller-identity --profile $profile --query 'Arn' --output text 2>/dev/null || echo 'Not configured')"
    echo "---"
done
```

## 🔐 セキュリティ推奨事項

### 1. アクセスキーの管理

- **定期的なローテーション**: 90日ごとにアクセスキーを更新
- **最小権限の原則**: 必要最小限の権限のみ付与
- **MFA有効化**: 可能な場合は多要素認証を有効化

### 2. プロファイルの分離

- **環境別分離**: 本番・テスト・開発環境で異なるプロファイルを使用
- **権限別分離**: 管理者権限と運用権限を分離
- **個人別分離**: 複数人で作業する場合は個人別プロファイルを使用

### 3. 監査とログ

```bash
# CloudTrailでアクセスログを確認
aws logs describe-log-groups --profile agrr-admin
aws logs filter-log-events --log-group-name CloudTrail --profile agrr-admin
```

## 📚 参考資料

- [AWS CLI プロファイル設定](https://docs.aws.amazon.com/cli/latest/userguide/cli-configure-profiles.html)
- [AWS IAM ユーザー管理](https://docs.aws.amazon.com/IAM/latest/UserGuide/id_users.html)
- [AWS セキュリティベストプラクティス](https://aws.amazon.com/security/security-resources/)

---

**次のステップ**: プロファイル設定後、[AWS_DEPLOY.md](AWS_DEPLOY.md)を参照してデプロイを実行してください。

