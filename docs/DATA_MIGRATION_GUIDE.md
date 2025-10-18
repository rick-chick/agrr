# データ管理ガイド

## 概要

AGRRでは、すべてのマスターデータ（参照農場・作物など）を**データベースマイグレーション**で管理します。

```bash
# 開発環境
docker-compose up  # 自動的にマイグレーション実行

# 本番環境
./scripts/gcp-deploy.sh  # デプロイ時に自動実行
```

**特徴:**
- `db/seeds.rb`は使用しない
- スキーマとデータが一緒に管理される
- 環境間で一貫した動作

---

## デプロイ時の動作

### 開発環境（docker-compose up）
```
1. コンテナ起動
2. schema.rb削除（クリーンな状態）
3. rails db:migrate 実行
   → 未適用マイグレーションを実行
   → データ投入も自動
4. サーバー起動
```

### 本番環境（GCP Cloud Run）
```
1. Docker build（.dockerignoreでschema.rb除外）
2. Cloud Runデプロイ
3. コンテナ起動時：
   - GCSからDBリストア（あれば）
   - rails db:migrate 実行
   → 未適用マイグレーションを実行
   → データ投入も自動
4. サーバー起動
```

---

## 一時モデル方式（必須）

**重要:** マイグレーション内で一時的なActiveRecordクラスを定義します。

```ruby
class SeedJapanReferenceData < ActiveRecord::Migration[8.0]
  # ✅ 一時モデル定義（必須）
  class TempFarm < ActiveRecord::Base
    self.table_name = 'farms'
  end
  
  def up
    # ✅ 一時モデルでデータ投入
    TempFarm.create!(name: '北海道', region: 'jp', ...)
  end
end
```

### なぜ一時モデルが必要か

**❌ アプリケーションモデルを直接使うと:**
```ruby
# NG例
def up
  Farm.create!(name: '北海道', ...)  # ❌
end
```
→ Farmモデルが後で変更されると、古いマイグレーションが壊れる

**✅ 一時モデルを使うと:**
```ruby
# OK例
class TempFarm < ActiveRecord::Base
  self.table_name = 'farms'
end

def up
  TempFarm.create!(name: '北海道', ...)  # ✅
end
```
→ マイグレーション実行時点のテーブル構造のみに依存するため安全

---

## 実装されているデータマイグレーション

### 日本の参照データ
**ファイル:** `db/migrate/20251018075019_seed_japan_reference_data.rb`

**内容:**
- 47農場（都道府県）
- 15作物
- 442K天気データ

### 米国の参照データ
**ファイル:** `db/migrate/20251018075149_seed_united_states_reference_data.rb`

**内容:**
- 50農場
- 30作物
- 430K天気データ

---

## 新しい地域を追加

```bash
# 1. マイグレーション作成
rails generate migration SeedEuropeReferenceData

# 2. 一時モデルで実装（既存ファイルを参考に）

# 3. デプロイ
./scripts/gcp-deploy.sh
```

起動時に自動実行されます。

---

## データ更新

既存データを更新する場合も、新しいマイグレーションを作成します。

```ruby
# db/migrate/XXXXXX_update_crop_revenue.rb
class UpdateCropRevenue < ActiveRecord::Migration[8.0]
  class TempCrop < ActiveRecord::Base
    self.table_name = 'crops'
  end
  
  def up
    TempCrop.find_by(name: 'トマト', region: 'jp')
           &.update!(revenue_per_area: 6000.0)
  end
  
  def down
    TempCrop.find_by(name: 'トマト', region: 'jp')
           &.update!(revenue_per_area: 5000.0)
  end
end
```

---

---

## デプロイコマンド

### 開発環境
```bash
# 起動（自動的にマイグレーション実行）
docker-compose up

# データリセット
docker-compose down -v
docker-compose up
```

### 本番環境
```bash
# デプロイ
./scripts/gcp-deploy.sh

# データベースリセット（初回デプロイ時のみ）
gsutil rm -r gs://agrr-production-db/**
./scripts/gcp-deploy.sh
```

---

## 参考

詳細は [Region Data Creation Guide](region/DATA_CREATION_GUIDE.md) を参照してください。
