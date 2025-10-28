# AGRR - 農業計画支援システム

Rails 8 + SQLite + Google Cloud Run で動く農業計画支援システム

## 🚀 クイックスタート

### 開発環境

```bash
# 起動（自動的にマイグレーション実行、アセットビルド）
docker compose up

# テスト実行
docker compose run --rm test

# メモリ監視レポート確認（必要時のみ有効化）
# デフォルトでは無効（起動時間短縮のため）
# 有効化: ENABLE_MEMORY_MONITOR=true docker compose up
./scripts/view_memory_report.sh
```

アクセス: http://localhost:3000

> 💡 **メモリ監視はデフォルトで無効**（起動時間短縮のため）。必要時は `ENABLE_MEMORY_MONITOR=true docker compose up` で有効化。詳細は [メモリ監視クイックスタート](docs/MEMORY_MONITORING_QUICKSTART.md) を参照。

### デプロイ

```bash
# Production環境
./scripts/gcp-deploy.sh

# Test環境（独立した環境）
./scripts/gcp-deploy-test.sh deploy
```

詳細:
- Production: [docs/operations/DEPLOYMENT_GUIDE.md](docs/operations/DEPLOYMENT_GUIDE.md)
- Test環境: [docs/GCP_TEST_ENVIRONMENT.md](docs/GCP_TEST_ENVIRONMENT.md) ⭐ New!

---

## 📚 主要ドキュメント

### 開発を始める前に（必読）

| ドキュメント | 用途 |
|------------|------|
| **[DOCKER_COMPOSE_GUIDE.md](DOCKER_COMPOSE_GUIDE.md)** | Docker使い方、起動確認 |
| **[ASSET_MANAGEMENT.md](ASSET_MANAGEMENT.md)** | アセット管理の仕組み（esbuild/Propshaft） |
| **[docs/AGRR_BINARY_MANAGEMENT.md](docs/AGRR_BINARY_MANAGEMENT.md)** | agrrバイナリ管理ガイド |
| **[docs/AGRR_SYNC_GUARANTEE.md](docs/AGRR_SYNC_GUARANTEE.md)** | agrrバイナリ同期の保証 |
| **[docs/FEATURE_CHECKLIST.md](docs/FEATURE_CHECKLIST.md)** | 新機能実装チェックリスト |
| **[docs/ASSET_LOADING_GUIDE.md](docs/ASSET_LOADING_GUIDE.md)** | アセットトラブルシューティング |

### アーキテクチャ

| ドキュメント | 用途 |
|------------|------|
| [ARCHITECTURE.md](ARCHITECTURE.md) | システムアーキテクチャ、設計思想 |
| [docs/DATA_MIGRATION_GUIDE.md](docs/DATA_MIGRATION_GUIDE.md) | データ管理方法（マイグレーション） |

---

## 💡 データ管理

マスターデータ（参照農場・作物）は**データベースマイグレーション**で管理されています。

各地域は**ローカル言語**でステージ名を管理：
- 🇯🇵 Japan: 47農場、15作物（日本語）
- 🇺🇸 United States: 50農場、30作物（英語）
- 🇮🇳 India: 50農場、30作物（ヒンディー語 हिंदी）

詳細: [docs/DATA_MIGRATION_GUIDE.md](docs/DATA_MIGRATION_GUIDE.md)

---

## 📖 詳細ドキュメント

<details>
<summary>開発ガイド</summary>

- [docs/development/TEST_GUIDE.md](docs/development/TEST_GUIDE.md) - テスト作成ガイド
- [docs/development/DEBUG_GUIDE.md](docs/development/DEBUG_GUIDE.md) - デバッグ方法
- [docs/development/ERROR_HANDLING_GUIDE.md](docs/development/ERROR_HANDLING_GUIDE.md) - エラーハンドリング
- [docs/development/GOOGLE_OAUTH_SETUP.md](docs/development/GOOGLE_OAUTH_SETUP.md) - Google OAuth設定
- [scripts/validate_feature.rb](scripts/validate_feature.rb) - 新機能の自動検証スクリプト

**メモリ監視・プロファイリング:**
- [docs/MEMORY_MONITORING_QUICKSTART.md](docs/MEMORY_MONITORING_QUICKSTART.md) - ⚡ クイックスタート（すぐ始める）
- [docs/MEMORY_LEAK_DETECTION.md](docs/MEMORY_LEAK_DETECTION.md) - 📊 詳細ガイド
- [docs/MEMORY_MONITORING.md](docs/MEMORY_MONITORING.md) - 🔧 実装詳細

</details>

<details>
<summary>機能実装</summary>

- [docs/features/](docs/features/) - 各機能の実装詳細
- [docs/region/](docs/region/) - 地域別データ作成ガイド

</details>

<details>
<summary>運用・デプロイ</summary>

- [docs/operations/DEPLOYMENT_GUIDE.md](docs/operations/DEPLOYMENT_GUIDE.md) - デプロイ方法
- [docs/operations/QUICK_REFERENCE.md](docs/operations/QUICK_REFERENCE.md) - クイックリファレンス
- [docs/operations/OPERATIONS_SUMMARY.md](docs/operations/OPERATIONS_SUMMARY.md) - 運用まとめ

</details>

<details>
<summary>トラブルシューティング</summary>

- [docs/troubleshooting/](docs/troubleshooting/) - トラブルシューティングガイド

</details>

<details>
<summary>すべてのドキュメント</summary>

- [docs/README.md](docs/README.md) - 全ドキュメント一覧

</details>

---

## 🌐 本番環境

- **URL**: https://agrr.net
- **プラットフォーム**: Google Cloud Run
- **データベース**: SQLite + Litestream（Cloud Storageバックアップ）

---

## 🛠 技術スタック

| カテゴリ | 技術 |
|---------|------|
| フレームワーク | Rails 8 |
| データベース | SQLite（Solid Queue, Solid Cache, Solid Cable） |
| バックアップ | Litestream |
| インフラ | Google Cloud Run |
| アセット | Propshaft + jsbundling-rails (esbuild) |
| フロントエンド | Hotwire (Turbo + Stimulus) |

---

**最終更新**: 2025-10-19
