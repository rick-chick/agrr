# agrr daemon機能のCloudRun/App Runner統合ガイド

## 概要

`lib/core/agrr`のdaemon機能をCloudRun/App Runnerで利用するための実装ガイドです。

**重要**: daemon機能は技術的に実装可能ですが、効果は限定的です。[DAEMON_CLOUDRUN_ANALYSIS.md](DAEMON_CLOUDRUN_ANALYSIS.md)を先にお読みください。

## 実装方法

### 1. Litestreamパターンでの統合

現在のプロジェクトでは`scripts/start_app.sh`でlitestreamをバックグラウンド起動しています。同じパターンでagrr daemonも起動できます。

#### ファイル構成

```
agrr/
├── Dockerfile.with-agrr-daemon           # daemon対応Dockerfile
├── scripts/
│   └── start_app_with_agrr_daemon.sh    # daemon自動起動スクリプト
└── lib/core/
    └── agrr                              # agrr binary (要ビルド)
```

### 2. agrr binaryのビルド

まず、agrr binaryをビルドする必要があります：

```bash
cd lib/core/agrr_core

# 単一バイナリ形式（シンプル、113MB）
./build_standalone.sh --onefile

# ビルド完了後、バイナリを配置
cp dist/agrr ../agrr
chmod +x ../agrr
```

### 3. Dockerイメージのビルド

```bash
# daemon対応版をビルド
docker build -f Dockerfile.with-agrr-daemon -t agrr-app:with-daemon .

# 動作確認（ローカル）
docker run --rm -p 3000:3000 \
  -e RAILS_ENV=production \
  -e SECRET_KEY_BASE=dummy_key_for_test \
  agrr-app:with-daemon
```

### 4. CloudRunへのデプロイ

```bash
# 1. GCRにプッシュ
PROJECT_ID="your-gcp-project-id"
IMAGE_NAME="agrr-app-daemon"

docker tag agrr-app:with-daemon gcr.io/${PROJECT_ID}/${IMAGE_NAME}:latest
docker push gcr.io/${PROJECT_ID}/${IMAGE_NAME}:latest

# 2. CloudRunにデプロイ（最小インスタンス=1推奨）
gcloud run deploy agrr-app \
  --image gcr.io/${PROJECT_ID}/${IMAGE_NAME}:latest \
  --platform managed \
  --region asia-northeast1 \
  --min-instances=1 \
  --max-instances=1 \
  --memory 2Gi \
  --cpu 1 \
  --set-env-vars "RAILS_ENV=production" \
  --allow-unauthenticated
```

**重要**: `--min-instances=1`を設定しないと、daemon起動の効果が得られません。

### 5. AWS App Runnerへのデプロイ

既存の`scripts/aws-deploy.sh`を使用する場合：

```bash
# 1. Dockerfileを一時的に切り替え
mv Dockerfile Dockerfile.original
cp Dockerfile.with-agrr-daemon Dockerfile

# 2. スタートアップスクリプトを切り替え
mv scripts/start_app.sh scripts/start_app.original.sh
cp scripts/start_app_with_agrr_daemon.sh scripts/start_app.sh

# 3. デプロイ実行
./scripts/aws-deploy.sh

# 4. 元に戻す（必要に応じて）
mv Dockerfile.original Dockerfile
mv scripts/start_app.original.sh scripts/start_app.sh
```

## 起動フロー

daemon対応版の起動フローは以下の通りです：

```
1. コンテナ起動
   ↓
2. Litestreamでデータベース復元
   ↓
3. データベースマイグレーション
   ↓
4. agrr daemon起動 ⭐ 追加
   ↓
5. Litestream replication開始
   ↓
6. Solid Queue worker起動
   ↓
7. Railsサーバー起動
   ↓
8. リクエスト受付開始
```

## ログ確認

### CloudRunの場合

```bash
# コンテナ起動ログを確認
gcloud logging read "resource.type=cloud_run_revision AND resource.labels.service_name=agrr-app" \
  --limit 50 \
  --format json

# agrr daemon起動を確認
gcloud logging read "resource.type=cloud_run_revision AND textPayload=~\"agrr daemon\"" \
  --limit 10
```

起動ログに以下のような出力が表示されます：

```
Step 3: Starting agrr daemon...
✓ agrr daemon started (PID: 1234)
```

### App Runnerの場合

AWS CloudWatch Logsで確認：

```bash
aws logs tail /aws/apprunner/agrr-app/application --follow
```

## パフォーマンス測定

daemon有無の効果を確認できます：

```bash
# Rails内からagrrを実行する時間を測定
# (app/controllers などで実装)

# daemon無し: 約2.4s
time agrr weather --location 35.6762,139.6503 --days 1 --json

# daemon有り: 約0.5s (2回目以降)
time agrr weather --location 35.6762,139.6503 --days 1 --json
```

## トラブルシューティング

### daemon起動に失敗する

**症状**: ログに「agrr daemon start failed」と表示

**原因と対処**:

1. **パーミッション不足**
   ```bash
   # Dockerfileで確認
   RUN chown -R appuser:appuser /tmp
   ```

2. **agrr binaryが存在しない**
   ```bash
   # ビルド済みか確認
   ls -lh lib/core/agrr
   
   # Dockerイメージ内で確認
   docker run --rm agrr-app:with-daemon ls -lh /usr/local/bin/agrr
   ```

3. **メモリ不足**
   ```bash
   # CloudRunメモリを増やす
   gcloud run services update agrr-app --memory 2Gi
   ```

### daemon起動しても効果がない

**症状**: 2回目以降も起動時間が変わらない

**考えられる原因**:

1. **最小インスタンス数=0になっている**
   ```bash
   # 確認
   gcloud run services describe agrr-app --format="value(spec.template.metadata.annotations['autoscaling.knative.dev/minScale'])"
   
   # 修正
   gcloud run services update agrr-app --min-instances=1
   ```

2. **新しいコンテナインスタンスが毎回起動している**
   - これはCloudRun/App Runnerの仕様
   - 同一コンテナが再利用されていない
   - → 最小インスタンス数を1以上に設定

3. **リクエスト間隔が長すぎる**
   - コンテナのタイムアウトでシャットダウンされている
   - CloudRunのデフォルト: リクエスト間15分でシャットダウン

### メモリ使用量が増加

**症状**: コンテナのメモリ使用量が200-300MB増加

**対処**:
- これは正常な動作です（daemon常駐のため）
- CloudRun/App Runnerのメモリ設定を調整：
  ```bash
  # CloudRun
  gcloud run services update agrr-app --memory 2Gi
  
  # App Runner (apprunner.yaml)
  InstanceConfiguration:
    Memory: 2048
  ```

## 効果測定の例

実際のプロダクション環境での測定例：

### シナリオ1: 低頻度アクセス（1日10リクエスト）

```
最小インスタンス=0の場合:
- 全リクエストでコールドスタート
- daemon効果: なし
- 推奨: daemon使用しない

最小インスタンス=1の場合:
- 初回のみコールドスタート
- daemon効果: 2-9回目で有効（約1.9s短縮）
- 推奨: コスト次第（常時稼働のコスト vs 効果）
```

### シナリオ2: 高頻度アクセス（1時間10リクエスト）

```
最小インスタンス=1の場合:
- コンテナ再利用率が高い
- daemon効果: ほぼ全リクエストで有効（約1.9s短縮）
- 推奨: daemon有効化の価値あり
```

## コスト影響

### CloudRunの場合

```
最小インスタンス=0（daemon無し）:
- 月額: $0（アイドル時）
- リクエスト時のみ課金

最小インスタンス=1（daemon有り）:
- 月額: 約$30-50（常時稼働）
- メモリ: 2GB
- CPU: 1vCPU
```

**損益分岐点**: 
- 1リクエストあたり2秒短縮で計算
- 月1000リクエスト以上で効果あり
- ただし、キャッシュ活用の方が効果的な場合が多い

## まとめ

### ✅ daemon有効化を推奨するケース

1. **最小インスタンス数=1で運用**している
2. **リクエスト頻度が高い**（1時間10回以上）
3. **agrr実行が頻繁**（リクエストの50%以上でagrr実行）
4. **常時稼働のコストが許容できる**

### ❌ daemon有効化を推奨しないケース

1. **最小インスタンス数=0で運用したい**
2. **リクエスト頻度が低い**（1日数回）
3. **agrr実行が稀**
4. **コスト最適化が優先**

### 🔄 代替アプローチを推奨するケース

ほとんどのケースでは以下の方が効果的：

1. **キャッシュ活用**（1時間キャッシュで十分な場合）
2. **非同期ジョブ化**（リアルタイム性が不要な場合）
3. **最小インスタンス数=1**（daemon無しでも効果あり）

詳細は[DAEMON_CLOUDRUN_ANALYSIS.md](DAEMON_CLOUDRUN_ANALYSIS.md)を参照してください。

