# データ管理方法

## 現在の仕組み

すべてのマスターデータ（参照農場・作物など）は**データベースマイグレーション**で管理されています。

```bash
# データベースセットアップ
rails db:migrate  # スキーマ作成 + データ投入
```

`db/seeds.rb`は使用しません。

---

## マイグレーションファイル

### 日本の参照データ
- **ファイル:** `db/migrate/20251018075019_seed_japan_reference_data.rb`
- **内容:** 47農場、15作物、442K天気データ

### 米国の参照データ
- **ファイル:** `db/migrate/20251018075149_seed_united_states_reference_data.rb`
- **内容:** 50農場、30作物、430K天気データ

---

## デプロイ時の動作

```
1. Docker build（schema.rbは含まれない）
2. Cloud Run デプロイ
3. コンテナ起動時：
   - rails db:migrate 実行
   - 未適用のマイグレーション自動実行
   - データ投入も自動
4. サーバー起動
```

---

## 新しい地域を追加する場合

```bash
# 1. マイグレーション作成
rails generate migration SeedEuropeReferenceData

# 2. 一時モデルで実装（既存マイグレーションを参考に）
# db/migrate/XXXXXX_seed_europe_reference_data.rb

# 3. デプロイ
./scripts/gcp-deploy.sh
```

起動時に新しいマイグレーションが自動実行されます。

---

## 技術詳細

詳細は [データマイグレーションガイド](docs/DATA_MIGRATION_GUIDE.md) を参照してください。
