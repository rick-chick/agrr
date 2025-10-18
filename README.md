# AGRR - 農業計画支援システム

Rails 8 + SQLite + Google Cloud Run

---

## デプロイ方法

```bash
./scripts/gcp-deploy.sh
```

詳細: [MIGRATION_DEPLOYMENT_GUIDE.md](MIGRATION_DEPLOYMENT_GUIDE.md)

---

## データ管理

マスターデータ（参照農場・作物）は**データベースマイグレーション**で管理されています。

- 🇯🇵 Japan: 47農場、15作物
- 🇺🇸 United States: 50農場、30作物

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
```

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
