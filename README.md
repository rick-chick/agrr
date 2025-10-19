# AGRR - 農業計画支援システム

Rails 8 + SQLite + Google Cloud Run

---

## デプロイ方法

```bash
./scripts/gcp-deploy.sh
```

詳細: [データ管理ガイド](docs/DATA_MIGRATION_GUIDE.md)

---

## データ管理

マスターデータ（参照農場・作物）は**データベースマイグレーション**で管理されています。

各地域は**ローカル言語**でステージ名を管理：

- 🇯🇵 Japan: 47農場、15作物（日本語）
- 🇺🇸 United States: 50農場、30作物（英語）
- 🇮🇳 India: 50農場、30作物（ヒンディー語 हिंदी）

詳細: [docs/DATA_MIGRATION_GUIDE.md](docs/DATA_MIGRATION_GUIDE.md)

---

## 開発環境

```bash
# 起動（自動的にマイグレーション実行）
docker-compose up

# テスト実行
docker-compose run --rm test

# データベースリセット
docker-compose down -v
docker-compose up

# 新機能を追加したら必ず実行（自動検証）
docker compose exec web ruby scripts/validate_feature.rb --feature 機能名
```

### 新機能を追加する前に必読
- **[docs/FEATURE_CHECKLIST.md](docs/FEATURE_CHECKLIST.md)** - 「動いているはずです！」と言う前に必ずチェック
- **[docs/ASSET_LOADING_GUIDE.md](docs/ASSET_LOADING_GUIDE.md)** - アセット（CSS/JS）の読み込み方法
- **[ASSET_MANAGEMENT.md](ASSET_MANAGEMENT.md)** - アセット管理の仕組み（esbuild/Propshaft）

---

## 本番環境

- **URL**: https://agrr.net
- **プラットフォーム**: Google Cloud Run
- **データベース**: SQLite + Litestream（Cloud Storageバックアップ）

---

## ドキュメント

### 運用
- [MIGRATION_DEPLOYMENT_GUIDE.md](MIGRATION_DEPLOYMENT_GUIDE.md) - デプロイ方法
- [docs/operations/](docs/operations/) - 運用詳細

### 開発
- [docs/DATA_MIGRATION_GUIDE.md](docs/DATA_MIGRATION_GUIDE.md) - データ管理方法
- [docs/region/](docs/region/) - 地域別データ作成ガイド
- [docs/features/](docs/features/) - 機能実装の詳細
- **[docs/FEATURE_CHECKLIST.md](docs/FEATURE_CHECKLIST.md) - 新機能実装チェックリスト（必読）**
- **[docs/ASSET_LOADING_GUIDE.md](docs/ASSET_LOADING_GUIDE.md) - アセット読み込みガイド（必読）**
- **[ASSET_MANAGEMENT.md](ASSET_MANAGEMENT.md) - アセット管理の仕組み（esbuild/Propshaft）**
- **[DOCKER_COMPOSE_GUIDE.md](DOCKER_COMPOSE_GUIDE.md) - Docker Compose使い方ガイド**
- [scripts/validate_feature.rb](scripts/validate_feature.rb) - 新機能の自動検証スクリプト

### その他
- [docs/README.md](docs/README.md) - ドキュメント一覧

---

## 技術スタック

- Rails 8
- SQLite（Solid Queue, Solid Cache, Solid Cable）
- Litestream（データベースバックアップ）
- Google Cloud Run
- Propshaft（アセット）
- jsbundling-rails + esbuild（JavaScript）

---

**最終更新**: 2025-10-18
