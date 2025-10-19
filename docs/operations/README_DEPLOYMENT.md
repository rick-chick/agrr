# AGRRデプロイ方法まとめ

## 🚀 推奨：スクリプトを使う

### CLI版（デフォルト）
```bash
./scripts/gcp-deploy.sh
```

### Daemon版（高頻度アクセス向け）
```bash
# 初回のみ：agrr binaryをビルド
cd lib/core/agrr_core && ./build_standalone.sh --onefile && cp dist/agrr ../agrr && cd ../../..

# デプロイ
USE_AGRR_DAEMON=true ./scripts/gcp-deploy.sh
```

---

## 📁 ファイル一覧

| ファイル | 用途 |
|---------|------|
| `scripts/gcp-deploy.sh` | GCPデプロイスクリプト（環境変数対応） |
| `Dockerfile.production` | プロダクション用Dockerfile（CLI/Daemon両対応） |
| `scripts/start_app.sh` | 起動スクリプト（環境変数で分岐） |

---

## 🎯 使い分け

### CLI版を使う（ほとんどの場合）
```bash
./scripts/gcp-deploy.sh
```

**推奨ケース**:
- コスト最適化が優先
- リクエスト頻度が低い
- シンプルな運用

### Daemon版を使う（特殊ケース）
```bash
USE_AGRR_DAEMON=true ./scripts/gcp-deploy.sh
```

**推奨ケース**:
- 最小インスタンス=1で運用
- 高頻度アクセス（1時間10回以上）
- レスポンス速度重視

---

## 📊 比較表

| 項目 | CLI版 | Daemon版 |
|------|-------|----------|
| **デプロイ** | `./scripts/gcp-deploy.sh` | `USE_AGRR_DAEMON=true ./scripts/gcp-deploy.sh` |
| **起動時間** | 2.4s | 初回: 2.4s、2回目以降: 0.5s |
| **メモリ** | 1.5GB | 1.7GB |
| **最小インスタンス** | 0（自動設定） | 1（自動設定） |
| **月額コスト** | $0-10 | $30-50 |

---

## 🔧 設定ファイル

### .env.gcp

```bash
# 必須
PROJECT_ID=your-project-id
RAILS_MASTER_KEY=xxx
SECRET_KEY_BASE=xxx
GCS_BUCKET=your-bucket

# オプション
REGION=asia-northeast1
SERVICE_NAME=agrr-production
USE_AGRR_DAEMON=false  # trueでDaemon版
```

---

## 📚 詳細ドキュメント

| ドキュメント | 説明 |
|------------|------|
| [DEPLOYMENT_GCP_SIMPLE.md](DEPLOYMENT_GCP_SIMPLE.md) | 最速スタートガイド |
| [DEPLOYMENT_GCP.md](DEPLOYMENT_GCP.md) | 詳細な手動デプロイ手順 |
| [docs/ENVIRONMENT_VARIABLES.md](docs/ENVIRONMENT_VARIABLES.md) | 環境変数リファレンス |
| [ENV_CONTROL_SUMMARY.md](ENV_CONTROL_SUMMARY.md) | 環境変数制御の仕組み |

---

## ✅ まとめ

- **デフォルト**: `./scripts/gcp-deploy.sh`
- **Daemon版**: `USE_AGRR_DAEMON=true ./scripts/gcp-deploy.sh`
- **迷ったら**: CLI版から始める

面倒な手動コマンドは不要です！スクリプト1行でデプロイできます。

