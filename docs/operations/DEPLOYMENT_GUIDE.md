# デプロイガイド

## 🚀 デプロイ方法

### 通常デプロイ

```bash
cd /home/akishige/projects/agrr
source .env.gcp
./scripts/gcp-deploy.sh deploy
```

**所要時間**: 2-3分

---

## 📋 必要な環境変数（.env.gcp）

```bash
# GCP設定
PROJECT_ID=agrr-475323
REGION=asia-northeast1
SERVICE_NAME=agrr-production
GCS_BUCKET=agrr-production-db
REGISTRY=asia-northeast1-docker.pkg.dev
IMAGE_NAME=agrr

# Rails設定
RAILS_MASTER_KEY=<config/master.keyの内容>
SECRET_KEY_BASE=<rails secretで生成>
ALLOWED_HOSTS=agrr.net,www.agrr.net,.run.app
```

### RAILS_MASTER_KEYの取得

```bash
cat config/master.key
```

### SECRET_KEY_BASEの生成

```bash
rails secret
```

---

## 🔄 デプロイフロー

### 1. コード変更
```bash
git add .
git commit -m "Feature: ..."
```

### 2. ローカルテスト
```bash
docker-compose run --rm test
```

### 3. デプロイ
```bash
source .env.gcp
./scripts/gcp-deploy.sh deploy
```

### 4. 動作確認
```bash
curl https://agrr-production-czyu2jck5q-an.a.run.app/up
```

---

## 🔙 ロールバック

### 前のリビジョンに戻す

```bash
# リビジョン一覧を確認
gcloud run revisions list --service=agrr-production \
  --region=asia-northeast1 --project=agrr-475323

# トラフィックを切り替え
gcloud run services update-traffic agrr-production \
  --to-revisions <revision-name>=100 \
  --region=asia-northeast1 \
  --project=agrr-475323
```

---

## 🗄️ データベース管理

### バックアップ確認

```bash
# Litestreamの自動バックアップを確認
gsutil ls -lh gs://agrr-production-db/
```

### 手動バックアップ

```bash
# 重要な変更前に実行
gsutil -m cp -r \
  gs://agrr-production-db/production.sqlite3 \
  gs://agrr-production-db/production_queue.sqlite3 \
  gs://agrr-production-db/production_cache.sqlite3 \
  gs://agrr-production-db/manual-backup-$(date +%Y%m%d)/
```

### データ復元

```bash
# 特定のバックアップから復元
gsutil cp -r gs://agrr-production-db/manual-backup-YYYYMMDD/ \
  gs://agrr-production-db/

# サービスを再起動（次回起動時に復元される）
gcloud run services update agrr-production \
  --region=asia-northeast1 --project=agrr-475323
```

---

## 🧹 メンテナンス

### 古いDockerイメージ削除

```bash
./scripts/cleanup-images.sh
```

### 古いリビジョン削除

```bash
# 古いリビジョンを削除（最新3つ以外）
gcloud run revisions list --service=agrr-production \
  --region=asia-northeast1 --project=agrr-475323 | \
  tail -n +4 | awk '{print $2}' | \
  xargs -I {} gcloud run revisions delete {} \
  --region=asia-northeast1 --project=agrr-475323 --quiet
```

---

## ⚙️ パフォーマンス調整

### 常時稼働にする（応答速度重視）

**理由**: コールドスタートを排除し、即座にレスポンスを返す

```bash
gcloud run services update agrr-production \
  --min-instances=1 \
  --region=asia-northeast1 \
  --project=agrr-475323
```

**コスト影響**: +$40-60/月

### アイドル停止に戻す（コスト重視）

**理由**: アクセスがない時は自動停止してコスト削減

```bash
gcloud run services update agrr-production \
  --min-instances=0 \
  --region=asia-northeast1 \
  --project=agrr-475323
```

**コスト影響**: 月額$1-6に戻る

---

## 🔍 ログ確認

### GCPコンソール（推奨）

```
https://console.cloud.google.com/run/detail/asia-northeast1/agrr-production/logs?project=agrr-475323
```

### CLIでログ確認

```bash
# 最新50件
gcloud logging read "resource.labels.service_name=agrr-production" \
  --limit=50 --project=agrr-475323

# エラーのみ
gcloud logging read "resource.labels.service_name=agrr-production AND severity>=ERROR" \
  --limit=30 --project=agrr-475323
```

---

## 🚨 トラブルシューティング

### デプロイが失敗する

**症状**: `ERROR: Container failed to start`

**対処**:
1. ログでエラー内容を確認
2. 前のリビジョンにロールバック
3. 問題を修正して再デプロイ

### 500エラーが出る

**症状**: ページアクセス時に500エラー

**対処**:
1. ログでスタックトレースを確認
2. データベースの整合性を確認
3. 必要に応じてバックアップから復元

### データが消えた

**症状**: 再起動後にデータがない

**対処**:
1. Litestreamバックアップから自動復元される（通常）
2. 復元されない場合は手動バックアップから復元
3. ログで復元処理を確認

---

## 📞 サポートリンク

- [Cloud Run Console](https://console.cloud.google.com/run?project=agrr-475323)
- [Cloud Storage](https://console.cloud.google.com/storage/browser/agrr-production-db?project=agrr-475323)
- [Artifact Registry](https://console.cloud.google.com/artifacts?project=agrr-475323)
- [IAM](https://console.cloud.google.com/iam-admin/iam?project=agrr-475323)

---

**最終更新**: 2025-10-17

