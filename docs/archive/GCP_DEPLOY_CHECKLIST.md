# GCPデプロイチェックリスト - Region機能

## ⚠️ 重要な前提

- ✅ **マイグレーションは自動実行される** - `start_app.sh`で`rails db:prepare`
- ✅ **シードも自動実行される** - 初回起動時（User.count == 0）のみ
- ✅ **シードは冪等性がある** - 何度実行しても安全

## 🚀 デプロイ手順（所要時間：約15分）

### Step 1: デプロイ（15分）★マイグレーション＆シード自動実行

```bash
# 通常のデプロイ（すべて自動）
./scripts/gcp-deploy.sh deploy
```

**自動的に実行されること**:
1. ✅ GCSからデータベース復元
2. ✅ マイグレーション実行（`rails db:prepare`）
3. ✅ シード実行（データが空の場合のみ）
4. ✅ アプリケーション起動

**確認**:
- [ ] デプロイが成功
- [ ] 新しいリビジョンがデプロイされた
- [ ] ヘルスチェックが成功（`/up`）
- [ ] ログに「Database setup completed」が表示
- [ ] 初回の場合、ログに「Seed completed」が表示

### Step 2: 検証（2分）

```bash
# 検証スクリプトを実行
gcloud run jobs create agrr-verify \
  --image asia-northeast1-docker.pkg.dev/agrr-475323/agrr/agrr:latest \
  --region asia-northeast1 \
  --service-account cloud-run-agrr@agrr-475323.iam.gserviceaccount.com \
  --set-env-vars RAILS_ENV=production \
  --set-secrets RAILS_MASTER_KEY=RAILS_MASTER_KEY:latest \
  --command "bundle" \
  --args "exec,rails,runner,scripts/verify_region_data.rb"

gcloud run jobs execute agrr-verify --region asia-northeast1 --wait
```

**確認**:
- [ ] 検証スクリプトが成功（exit code 0）
- [ ] すべての項目が✅
- [ ] region=nilのデータが0件

### Step 3: 動作確認（3分）

ブラウザでアプリケーションにアクセス：

- [ ] トップページが表示される
- [ ] 参照農場一覧が表示される（47都道府県）
- [ ] 作物一覧が表示される（15種類）
- [ ] エラーログがない

**所要時間合計**: 約20分

## 🔄 既存環境へのシード再実行（必要な場合）

既存のデプロイ済み環境に対してシードを再実行する場合：

```bash
# Cloud Run Jobsでシード実行
gcloud run jobs create agrr-seed \
  --image asia-northeast1-docker.pkg.dev/agrr-475323/agrr/agrr:latest \
  --region asia-northeast1 \
  --service-account cloud-run-agrr@agrr-475323.iam.gserviceaccount.com \
  --set-env-vars RAILS_ENV=production \
  --set-secrets RAILS_MASTER_KEY=RAILS_MASTER_KEY:latest \
  --command "bundle" \
  --args "exec,rails,db:seed"

gcloud run jobs execute agrr-seed --region asia-northeast1 --wait
```

**いつ必要か**:
- 参照データの更新（作物情報、輪作ルールなど）
- region情報の一括更新
- データの修正・追加

**安全性**: ✅ 冪等性があるため何度実行してもOK

## ⚠️ ロールバック手順（問題発生時）

```bash
# 前のリビジョンにロールバック
gcloud run services update-traffic agrr-production \
  --to-revisions PREVIOUS_REVISION=100 \
  --region asia-northeast1

# マイグレーションのロールバックは通常不要
# 理由：regionカラムの追加は後方互換性がある（nullを許容）
```

## 📊 ログ確認コマンド

```bash
# Cloud Runのログ
gcloud run services logs tail agrr-production --region asia-northeast1

# エラーログのみ
gcloud run services logs tail agrr-production --region asia-northeast1 --log-filter="severity>=ERROR"

# 起動ログの確認（シード実行を確認）
gcloud run services logs tail agrr-production --region asia-northeast1 | grep -A 5 "Step 3:"
```

## ✅ 完了確認

- [ ] デプロイが成功（マイグレーション＆シード自動実行）
- [ ] 検証スクリプトがすべて✅
- [ ] ブラウザで動作確認完了
- [ ] ログにエラーがない
- [ ] 参照データにregion='jp'が設定されている

## 📝 重要ポイント

### シードの自動実行条件

```bash
# start_app.shのロジック
if User.count == 0; then
  # データが空の場合のみシード実行
  rails db:seed
fi
```

**つまり**:
- 初回デプロイ: シード自動実行 ✅
- 2回目以降: シードスキップ（データあり）✅
- 手動でシード実行: いつでもOK ✅

### 冪等性の保証

AGRRのシードは`find_or_create_by!`を使用しているため：
- ✅ データ重複なし
- ✅ 何度実行しても安全
- ✅ 既存データは保持または更新

---

**参考ドキュメント**:
- Rails 8の仕組み: `docs/rails8_database_commands.md`
- Region機能仕様: `docs/region_feature.md`
- 要件定義: `docs/region_requirements.md`
- シードデータ: `docs/region_seed_data.md`
