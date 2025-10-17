# 運用サマリー

## ✅ 現在の構成（2025-10-17）

### プラットフォーム
```
Google Cloud Run
├─ プロジェクト: agrr-475323
├─ リージョン: asia-northeast1（東京）
├─ サービス: agrr-production
└─ URL: https://agrr-production-czyu2jck5q-an.a.run.app
```

### リソース
```
メモリ: 2GB
CPU: 2コア
最小インスタンス: 0（アイドル時自動停止）
最大インスタンス: 1（Litestream制約）
タイムアウト: 600秒
```

### データベース
```
種類: SQLite 3
場所: /tmp/production.sqlite3（コンテナ内）
永続化: Litestream → Cloud Storage
バケット: gs://agrr-production-db
同期間隔: 10秒
```

### アーキテクチャ
```
ユーザー
  ↓
Cloud Run（Rails 8アプリ）
  ├─ Solid Queue（バックグラウンドジョブ）
  ├─ Solid Cache（キャッシュ）
  ├─ Solid Cable（WebSocket）
  └─ SQLite (/tmp)
       ↓ Litestream
     Cloud Storage（バックアップ）
```

---

## 📊 コスト

### 現在の設定（min-instances=0）
```
Cloud Run: $0.50-5.00/月（使用量に応じて）
Cloud Storage: $0.02-0.50/月
Artifact Registry: $0.10/月
──────────────────────────────
合計: $1-6/月（予想）
```

### 常時稼働に変更する場合（min-instances=1）
```
Cloud Run: $40-60/月
Cloud Storage: $0.50/月
Artifact Registry: $0.10/月
──────────────────────────────
合計: $41-61/月
```

**推奨**: トラフィックが少ない間は `min-instances=0`、応答速度が重要になったら `min-instances=1` に変更

---

## 🔄 デプロイワークフロー

### 1. コード変更
```bash
# ローカルで開発
git add .
git commit -m "Add feature"
```

### 2. デプロイ
```bash
source .env.gcp
./scripts/gcp-deploy.sh deploy
```

### 3. 所要時間
```
ビルド: 30-60秒
Push: 10-20秒
デプロイ: 60-120秒
──────────────────
合計: 2-3分
```

---

## 🗄️ データ管理

### バックアップの確認
```bash
# Litestreamが自動バックアップ（10秒ごと）
gsutil ls -lh gs://agrr-production-db/
```

### 手動バックアップ
```bash
# 重要な変更前に手動バックアップ推奨
gsutil cp -r gs://agrr-production-db/production.sqlite3 \
  gs://agrr-production-db/manual-backup-$(date +%Y%m%d-%H%M%S)/
```

### データの復元
```bash
# 特定のバックアップから復元
gsutil cp -r gs://agrr-production-db/manual-backup-20251017-120000/ \
  gs://agrr-production-db/production.sqlite3/

# サービスを再起動（次回起動時に復元される）
gcloud run services update agrr-production \
  --region asia-northeast1 --project agrr-475323
```

---

## 🛡️ セキュリティ

### サービスアカウント
```
デプロイ実行: agrr-admin@agrr-475323.iam.gserviceaccount.com
サービス実行: cloud-run-agrr@agrr-475323.iam.gserviceaccount.com
```

### 認証情報
```bash
# .env.gcp（gitignore済み）
RAILS_MASTER_KEY: config/credentials.yml.encの暗号化キー
SECRET_KEY_BASE: セッション暗号化キー
```

### 許可ドメイン
```
agrr.net
www.agrr.net
*.run.app
```

---

## 🚨 トラブルシューティング

### よくある問題と解決策

#### 1. デプロイ失敗（タイムアウト）
**原因**: データベースseedが長すぎる
**解決**: seedを無効化して手動実行

#### 2. データが消える
**原因**: Litestreamの同期前に再起動
**解決**: 通常は10秒ごとに同期されているので問題なし

#### 3. 500エラー
**原因**: データベースが空
**解決**: 
```bash
# seedを手動実行（Cloud Run Jobsで）
# または GCSから適切なDBを復元
```

#### 4. ActionCable（WebSocket）接続エラー
**原因**: Solid Cableの設定
**解決**: 現在は正常に動作しています

---

## 📈 スケーリング

### 現在の制約
- **最大1インスタンス**（Litestream制約）
- 同時接続数: 約80リクエスト/インスタンス

### スケールアップが必要な場合
**トラフィックが増えたら：**
1. Cloud SQL（PostgreSQL）に移行
2. max-instancesを増やす
3. 水平スケール可能に

**移行の目安：**
- 同時接続 > 50
- 月間PV > 10万
- レスポンス遅延 > 2秒

---

## 🧹 定期メンテナンス

### 週次
- [ ] ログ確認（エラーの有無）
- [ ] バックアップ確認（GCSに存在するか）

### 月次
- [ ] コスト確認
- [ ] パフォーマンス分析
- [ ] 手動バックアップ作成

### 四半期
- [ ] セキュリティアップデート
- [ ] Railsバージョンアップデート
- [ ] データベースサイズ確認

---

## 🔮 今後の改善計画

### フェーズ1（現在）✅
- [x] Cloud Runデプロイ
- [x] Litestream永続化
- [x] Solid Queue/Cache稼働

### フェーズ2（1ヶ月以内）
- [ ] カスタムドメイン設定（agrr.net）
- [ ] Cloud CDN有効化
- [ ] 監視アラート設定

### フェーズ3（3ヶ月以内）
- [ ] CI/CD自動化（GitHub Actions）
- [ ] ステージング環境構築
- [ ] パフォーマンス最適化

### フェーズ4（6ヶ月以内）
- [ ] トラフィック増加時：Cloud SQL移行を検討
- [ ] マルチリージョン展開
- [ ] 負荷テスト実施

---

## 📞 連絡先・リソース

### GCPコンソール
- [Cloud Run](https://console.cloud.google.com/run?project=agrr-475323)
- [Cloud Storage](https://console.cloud.google.com/storage/browser/agrr-production-db?project=agrr-475323)
- [Artifact Registry](https://console.cloud.google.com/artifacts/docker/agrr-475323/asia-northeast1/agrr?project=agrr-475323)
- [IAM](https://console.cloud.google.com/iam-admin/iam?project=agrr-475323)

### ドキュメント
- [本番環境ガイド](./PRODUCTION_GUIDE.md)
- [クイックリファレンス](./QUICK_REFERENCE.md)

---

**最終更新**: 2025-10-17
**ステータス**: ✅ 本番稼働中

