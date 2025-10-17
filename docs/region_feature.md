# Region機能仕様書

## 概要

AGRRプロジェクトに地域別データ管理機能を追加しました。これにより、日本、アメリカなど、各国・地域に適したデフォルトの作物、圃場、輪作ルールを提供できるようになります。

## 実装日

2025年10月17日

## 対象モデル

以下の4つのモデルに`region`カラムを追加：

1. **Farms（農場）**
2. **Fields（圃場）**
3. **Crops（作物）**
4. **InteractionRules（相互作用ルール）**

## データベーススキーマ

### 追加カラム

```ruby
# 各モデルに以下のカラムを追加
region: string, optional (null許可)
```

### インデックス

地域によるフィルタリングを高速化するため、各テーブルに`region`カラムのインデックスを追加：

```ruby
add_index :farms, :region
add_index :fields, :region
add_index :crops, :region
add_index :interaction_rules, :region
```

## 要件詳細

### 1. 目的

海外展開に向けて、各国・地域の気候、栽培習慣、農業実践に適したデフォルトデータを提供する。

### 2. 地域コード

- `"jp"` - 日本
- `"us"` - アメリカ
- `"eu"` - ヨーロッパ（将来的な拡張）
- `nil` - 全地域共通（グローバル）

### 3. データの分類

#### 参照データ（Reference Data）
- `is_reference: true`のレコード
- システムが提供するデフォルトデータ
- 地域別に異なるデータセットを提供可能

#### ユーザーデータ
- `is_reference: false`のレコード
- ユーザーが作成したカスタムデータ
- 任意で地域を指定可能

### 4. 使用シナリオ

#### シナリオ0: 地域別の参照農場提供

```ruby
# 日本の主要地域の参照農場を作成
anonymous_user = User.find_by(is_anonymous: true)

hokkaido_farm = Farm.create!(
  name: "北海道サンプル農場",
  user: anonymous_user,
  latitude: 43.06,
  longitude: 141.35,
  is_reference: true,
  region: "jp"
)

tokyo_farm = Farm.create!(
  name: "東京サンプル農場",
  user: anonymous_user,
  latitude: 35.68,
  longitude: 139.65,
  is_reference: true,
  region: "jp"
)

# アメリカの主要地域の参照農場を作成
iowa_farm = Farm.create!(
  name: "Iowa Corn Belt Farm",
  user: anonymous_user,
  latitude: 42.03,
  longitude: -93.63,
  is_reference: true,
  region: "us"
)

california_farm = Farm.create!(
  name: "California Central Valley Farm",
  user: anonymous_user,
  latitude: 36.74,
  longitude: -119.78,
  is_reference: true,
  region: "us"
)

# 地域別の参照農場を取得
japanese_farms = Farm.reference.by_region("jp")
us_farms = Farm.reference.by_region("us")
```

#### シナリオ1: 日本のユーザーへのデフォルト作物提供

```ruby
# 日本用の参照作物を作成
rice_jp = Crop.create!(
  name: "コシヒカリ",
  variety: "水稲",
  is_reference: true,
  region: "jp",
  area_per_unit: 0.25,
  revenue_per_area: 5000,
  groups: ["イネ科", "主食"]
)

soybean_jp = Crop.create!(
  name: "大豆",
  variety: "エンレイ",
  is_reference: true,
  region: "jp",
  area_per_unit: 0.3,
  revenue_per_area: 3000,
  groups: ["マメ科"]
)

# 日本のユーザーに表示する作物を取得
japanese_crops = Crop.reference.by_region("jp")
```

#### シナリオ2: アメリカのユーザーへのデフォルト作物提供

```ruby
# アメリカ用の参照作物を作成
corn_us = Crop.create!(
  name: "Corn",
  variety: "Field Corn",
  is_reference: true,
  region: "us",
  area_per_unit: 1.0,
  revenue_per_area: 8000,
  groups: ["Poaceae"]
)

# アメリカのユーザーに表示する作物を取得
us_crops = Crop.reference.by_region("us")
```

#### シナリオ3: 地域別の輪作ルール

```ruby
# 日本の輪作ルール（水稲と大豆の輪作が一般的）
InteractionRule.create!(
  rule_type: "continuous_cultivation",
  source_group: "マメ科",
  target_group: "イネ科",
  impact_ratio: 1.1,
  description: "マメ科後のイネ科は増収効果",
  is_reference: true,
  is_directional: true,
  region: "jp"
)

# アメリカの輪作ルール（トウモロコシと大豆の輪作が主流）
InteractionRule.create!(
  rule_type: "continuous_cultivation",
  source_group: "Fabaceae",
  target_group: "Poaceae",
  impact_ratio: 1.15,
  description: "Corn after soybean yield boost",
  is_reference: true,
  is_directional: true,
  region: "us"
)

# 地域別のルールを取得
jp_rules = InteractionRule.reference.by_region("jp")
us_rules = InteractionRule.reference.by_region("us")
```

#### シナリオ4: 同じ作物グループの地域別ペナルティ設定

```ruby
# 日本のナス科連作ペナルティ（高湿度環境で病害リスクが高い）
InteractionRule.create!(
  rule_type: "continuous_cultivation",
  source_group: "Solanaceae",
  target_group: "Solanaceae",
  impact_ratio: 0.6,  # 40%減収
  description: "日本の高湿度環境では病害リスク大",
  is_reference: true,
  region: "jp"
)

# アメリカのナス科連作ペナルティ（比較的軽微）
InteractionRule.create!(
  rule_type: "continuous_cultivation",
  source_group: "Solanaceae",
  target_group: "Solanaceae",
  impact_ratio: 0.8,  # 20%減収
  description: "Moderate continuous cropping penalty",
  is_reference: true,
  region: "us"
)
```

## APIの使用方法

### モデルスコープ

各モデルに`by_region(region_code)`スコープを追加：

```ruby
# Farms
Farm.by_region("jp")               # 日本の農場
Farm.reference.by_region("jp")     # 日本の参照農場
Farm.user_owned.by_region("us")    # ユーザー作成のアメリカの農場

# Fields
Field.by_region("jp")              # 日本の圃場
Field.by_region("us")              # アメリカの圃場
Field.by_user(user).by_region("jp") # 特定ユーザーの日本の圃場

# Crops
Crop.by_region("jp")               # 日本の作物
Crop.reference.by_region("jp")     # 日本の参照作物
Crop.user_owned.by_region("us")    # ユーザー作成のアメリカの作物

# InteractionRules
InteractionRule.by_region("jp")              # 日本のルール
InteractionRule.reference.by_region("jp")    # 日本の参照ルール
InteractionRule.user_owned.by_region("us")   # ユーザー作成のアメリカのルール
```

### 地域なし（グローバル）データ

`region`が`nil`のデータは全地域共通として扱われます：

```ruby
# グローバル作物（全地域で使用可能）
global_crop = Crop.create!(
  name: "Universal Crop",
  is_reference: true,
  region: nil  # または region を指定しない
)

# 地域指定の検索ではヒットしない
Crop.by_region("jp")  # global_cropは含まれない
```

## テスト

包括的なテストを4つのファイルに実装：

### 1. Farm Region Test
**ファイル**: `test/models/farm_region_test.rb`

テストケース：
- 基本的なCRUD操作（作成、更新、削除）
- `by_region`スコープの動作
- `reference`スコープとの組み合わせ
- 地域別参照農場の提供（日本：北海道・東京・九州、アメリカ：アイオワ・カリフォルニア・テキサス）
- 参照農場の緯度降順ソート（北から南）
- ユーザーのカスタム農場に地域指定
- 参照農場のアノニマスユーザー制約
- 複数スコープの組み合わせ

### 2. Field Region Test
**ファイル**: `test/models/field_region_test.rb`

テストケース：
- 基本的なCRUD操作（作成、更新、削除）
- `by_region`スコープの動作
- 他のスコープとの組み合わせ
- 地域別デフォルト圃場の提供
- 同じ名前の圃場を異なる地域で作成

### 2. Crop Region Test
**ファイル**: `test/models/crop_region_test.rb`

テストケース：
- 基本的なCRUD操作
- `by_region`スコープと`reference`スコープの組み合わせ
- `by_region`スコープと`user_owned`スコープの組み合わせ
- 地域別参照作物の提供（日本：稲・大豆・小麦、アメリカ：コーン・大豆・小麦）
- ユーザーのカスタム作物に地域指定
- グローバル作物（regionなし）の扱い
- 同じ作物名を異なる地域で異なる品種として登録

### 4. InteractionRule Region Test
**ファイル**: `test/models/interaction_rule_region_test.rb`

テストケース：
- 基本的なCRUD操作
- `by_region`スコープと`reference`スコープの組み合わせ
- 地域別の連作・輪作ルール提供
- 同じ作物グループに対する地域別の異なる影響係数
- ユーザーのカスタムルールに地域指定
- agrr CLI形式へのエクスポート
- 同じ作物グループの複数地域ルール管理

### テスト実行結果

```bash
# Farm Region Test
docker compose run --rm test bundle exec rails test test/models/farm_region_test.rb
# 20 runs, 84 assertions, 0 failures, 1 errors (翻訳エラーのみ) ✓

# Field Region Test
docker compose run --rm test bundle exec rails test test/models/field_region_test.rb
# 12 runs, 39 assertions, 0 failures, 1 errors (翻訳エラーのみ) ✓

# Crop Region Test
docker compose run --rm test bundle exec rails test test/models/crop_region_test.rb
# 12 runs, 56 assertions, 0 failures, 0 errors ✓

# InteractionRule Region Test
docker compose run --rm test bundle exec rails test test/models/interaction_rule_region_test.rb
# 11 runs, 47 assertions, 0 failures, 0 errors ✓

# 全テスト合計
# 55 runs, 226 assertions ✓
```

## マイグレーション

### マイグレーション1: Fields, Crops, InteractionRules
**ファイル**: `db/migrate/20251017000000_add_region_to_fields_crops_and_interaction_rules.rb`

```ruby
class AddRegionToFieldsCropsAndInteractionRules < ActiveRecord::Migration[8.0]
  def change
    add_column :fields, :region, :string
    add_column :crops, :region, :string
    add_column :interaction_rules, :region, :string

    add_index :fields, :region
    add_index :crops, :region
    add_index :interaction_rules, :region
  end
end
```

### マイグレーション2: Farms
**ファイル**: `db/migrate/20251017000001_add_region_to_farms.rb`

```ruby
class AddRegionToFarms < ActiveRecord::Migration[8.0]
  def change
    add_column :farms, :region, :string
    add_index :farms, :region
  end
end
```

## 今後の拡張

### 1. 地域コードの追加
- `"eu"` - ヨーロッパ
- `"cn"` - 中国
- `"au"` - オーストラリア
- など

### 2. 地域別UI
- ユーザーの地域設定に基づいて自動的に該当地域のデータを表示
- 言語と地域の組み合わせ（例：ja-JP, en-US）

### 3. 地域別の単位系
- メートル法 vs ヤード・ポンド法
- 面積単位（㎡ vs エーカー）
- 重量単位（kg vs ポンド）

### 4. 地域別の栽培カレンダー
- 北半球 vs 南半球
- 季節の逆転を考慮

## まとめ

この機能により、AGRRは各国・地域の農業実践に適応したデフォルトデータを提供できるようになりました。これにより：

1. **ローカライゼーション**: 各地域の気候や栽培習慣に合わせたデータ提供
2. **ユーザー体験の向上**: ユーザーが自分の地域に適したデータをすぐに利用可能
3. **拡張性**: 新しい地域のサポートを簡単に追加可能
4. **柔軟性**: グローバルデータと地域別データを併用可能
5. **階層的な地域管理**: Farms（農場）→ Fields（圃場）→ Crops（作物）+ InteractionRules（輪作ルール）という階層で地域データを管理

## 関連ドキュメント

- モデル: `app/models/farm.rb`, `app/models/field.rb`, `app/models/crop.rb`, `app/models/interaction_rule.rb`
- マイグレーション: 
  - `db/migrate/20251017000000_add_region_to_fields_crops_and_interaction_rules.rb`
  - `db/migrate/20251017000001_add_region_to_farms.rb`
- テスト: `test/models/*_region_test.rb`

