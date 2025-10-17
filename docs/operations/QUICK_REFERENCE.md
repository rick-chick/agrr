# クイックリファレンス

## 🚀 よく使うコマンド

### デプロイ
```bash
cd /home/akishige/projects/agrr
source .env.gcp
./scripts/gcp-deploy.sh deploy
```

### サイトURL
```
https://agrr-production-czyu2jck5q-an.a.run.app
```

### ログ確認
```
https://console.cloud.google.com/run/detail/asia-northeast1/agrr-production/logs?project=agrr-475323
```

---

## 🗄️ データベース

### バックアップ確認
```bash
gsutil ls -lh gs://agrr-production-db/
```

### 手動バックアップ
```bash
gsutil cp gs://agrr-production-db/production.sqlite3 \
  gs://agrr-production-db/backups/backup-$(date +%Y%m%d).sqlite3
```

### ローカルにダウンロード
```bash
gsutil cp gs://agrr-production-db/production.sqlite3 ./local-backup.sqlite3
```

---

## 🧹 メンテナンス

### 古いイメージ削除
```bash
./scripts/cleanup-images.sh
```

### サービス再起動
```bash
gcloud run services update agrr-production \
  --region asia-northeast1 --project agrr-475323
```

---

## ⚙️ 設定変更

### インスタンス数変更
```bash
# 常時稼働（応答速度重視）
gcloud run services update agrr-production \
  --min-instances 1 \
  --region asia-northeast1 \
  --project agrr-475323

# アイドル停止（コスト重視）
gcloud run services update agrr-production \
  --min-instances 0 \
  --region asia-northeast1 \
  --project agrr-475323
```

### メモリ/CPU変更
```bash
gcloud run services update agrr-production \
  --memory 4Gi \
  --cpu 2 \
  --region asia-northeast1 \
  --project agrr-475323
```

---

## 🔥 緊急時

### ロールバック
```bash
# 前のリビジョンに戻す
gcloud run services update-traffic agrr-production \
  --to-revisions agrr-production-00025-wov=100 \
  --region asia-northeast1 \
  --project agrr-475323
```

### サービス停止
```bash
gcloud run services delete agrr-production \
  --region asia-northeast1 \
  --project agrr-475323
```

---

## 📞 サポートリンク

- [Cloud Run Console](https://console.cloud.google.com/run?project=agrr-475323)
- [Artifact Registry](https://console.cloud.google.com/artifacts?project=agrr-475323)
- [Cloud Storage](https://console.cloud.google.com/storage/browser/agrr-production-db?project=agrr-475323)
- [IAM](https://console.cloud.google.com/iam-admin/iam?project=agrr-475323)

