# Region機能 - 要件定義書

## 背景

AGRRは農業計画最適化システムとして、日本から海外展開（特にアメリカ）を目指しています。各国・地域には独自の農業環境と実践があり、それぞれに適したデータセットを提供する必要があります。

### 地域による違い

| 項目 | 日本 | アメリカ |
|------|------|----------|
| **気候** | 温帯・モンスーン気候<br>高温多湿 | 大陸性気候<br>乾燥した大陸内部 |
| **主要作物** | 米、大豆、小麦<br>野菜類 | コーン、大豆、小麦<br>大規模穀物 |
| **栽培習慣** | 水田農業<br>集約的栽培 | 畑作農業<br>大規模・機械化 |
| **輪作パターン** | 米→大豆<br>大豆→麦 | コーン→大豆<br>大豆→コーン |
| **病害リスク** | 高湿度で高リスク | 比較的低リスク |
| **農地規模** | 小規模（0.25ha～） | 大規模（数十～数百ha） |

## 要件

### R1: 基本データ操作

**目的**: 各モデルで地域情報を管理できるようにする

**対象モデル**:
- Farm（農場）
- Field（圃場）
- Crop（作物）
- InteractionRule（相互作用ルール）

**仕様**:
- 各モデルに`region`カラム（文字列型、オプショナル）を追加
- `region`は以下の値を取る：
  - `"jp"` - 日本
  - `"us"` - アメリカ
  - `nil` - 全地域共通（グローバル）
  - 将来的に`"eu"`、`"cn"`なども追加可能
- CRUD操作で地域を指定・変更可能
- データベースインデックスを設定してフィルタリングを高速化

**受入基準**:
- [ ] 各モデルで`region`属性の作成・更新・削除が可能
- [ ] `region`にnilを設定可能（デフォルト値）
- [ ] 地域情報がデータベースに永続化される

### R2: 地域別フィルタリング

**目的**: 地域ごとに適切なデータを取得できるようにする

**仕様**:
- 各モデルに`by_region(region_code)`スコープを実装
- `region: nil`のデータは地域フィルタリングで含まれない
- 既存のスコープ（`reference`, `user_owned`, `by_user`など）と組み合わせ可能
- チェーン可能なActiveRecordスコープとして実装

**使用例**:
```ruby
# 日本の参照作物を取得
Crop.reference.by_region("jp")

# ユーザーのアメリカの農場を取得
Farm.user_owned.by_user(current_user).by_region("us")

# 日本の輪作ルールを取得
InteractionRule.reference.by_region("jp")
```

**受入基準**:
- [ ] `by_region(code)`スコープが4つのモデルすべてに実装されている
- [ ] `region: nil`のデータはフィルタリングで除外される
- [ ] 複数のスコープと組み合わせて使用可能

### R3: 地域別参照データ提供

**目的**: 各地域のユーザーに適切なデフォルトデータを提供する

**仕様**:

#### 参照データの定義
- `is_reference: true`のレコード
- システムが提供するデフォルトデータ
- 管理者が作成・管理
- 一般ユーザーは閲覧のみ

#### 参照Farmの制約
- アノニマスユーザーにのみ所属可能
- 地域ごとに複数の参照Farmを作成可能
- 緯度降順（北から南）でソートされる

#### 地域別データセット

**日本（`region: "jp"`）**:
- 参照Farm: 北海道、東京、九州などの気候サンプル
- 参照Crop: コシヒカリ（水稲）、大豆、小麦など
- 参照InteractionRule: 水稲・大豆の輪作効果

**アメリカ（`region: "us"`）**:
- 参照Farm: アイオワ、カリフォルニア、テキサスなどの気候サンプル
- 参照Crop: コーン、大豆、冬小麦など
- 参照InteractionRule: コーン・大豆の輪作効果

**使用例**:
```ruby
# 日本のユーザーに表示するデータセット
jp_dataset = {
  farms: Farm.reference.by_region("jp"),
  crops: Crop.reference.by_region("jp"),
  rules: InteractionRule.reference.by_region("jp")
}

# アメリカのユーザーに表示するデータセット
us_dataset = {
  farms: Farm.reference.by_region("us"),
  crops: Crop.reference.by_region("us"),
  rules: InteractionRule.reference.by_region("us")
}
```

**受入基準**:
- [ ] 参照Farmはアノニマスユーザーにのみ作成可能
- [ ] 日本とアメリカでそれぞれ完全なデータセットを提供可能
- [ ] 参照Farmは緯度降順でソートされる

### R4: 地域別ビジネスロジック

**目的**: 地域ごとに異なる農業実践を反映する

**仕様**:

#### 同名作物の地域別差異
- 同じ作物名でも地域によって品種が異なる
- 栽培面積、収益性が地域の実態を反映

**例**: 米（Rice）
```ruby
# 日本の米
rice_jp = Crop.create!(
  name: "Rice",
  variety: "Koshihikari (Japonica)",
  region: "jp",
  area_per_unit: 0.25,      # 小規模
  revenue_per_area: 5000    # 高品質・高価格
)

# アメリカの米
rice_us = Crop.create!(
  name: "Rice", 
  variety: "Long Grain",
  region: "us",
  area_per_unit: 1.0,       # 大規模
  revenue_per_area: 7000    # 機械化・効率重視
)
```

#### 同一作物グループの地域別影響係数

**例**: ナス科（Solanaceae）の連作ペナルティ
```ruby
# 日本（高湿度環境で病害リスク大）
rule_jp = InteractionRule.create!(
  source_group: "Solanaceae",
  target_group: "Solanaceae",
  impact_ratio: 0.6,  # 40%減収
  region: "jp"
)

# アメリカ（比較的軽微）
rule_us = InteractionRule.create!(
  source_group: "Solanaceae",
  target_group: "Solanaceae",
  impact_ratio: 0.8,  # 20%減収
  region: "us"
)
```

**受入基準**:
- [ ] 同名作物を地域ごとに独立して管理可能
- [ ] 同一作物グループに地域別の影響係数を設定可能
- [ ] 地域の実態を反映したデータ提供が可能

### R5: データの独立性

**目的**: 地域間でデータを独立して管理する

**仕様**:
- 異なる地域で同じ名前のデータを独立して存在させる
- 地域間でデータが干渉しない
- ユーザーは任意の地域のカスタムデータを作成可能

**使用例**:
```ruby
# 両方とも有効
farm_jp = Farm.create!(name: "Sample Farm", region: "jp", ...)
farm_us = Farm.create!(name: "Sample Farm", region: "us", ...)

# ユーザーが日本向けカスタムデータを作成
user_crop = Crop.create!(
  name: "特殊品種イチゴ",
  user: current_user,
  is_reference: false,
  region: "jp"
)
```

**受入基準**:
- [ ] 同名データを異なる地域で独立して作成可能
- [ ] ユーザーは任意の地域のデータを作成可能
- [ ] 地域フィルタリングで正しくデータが分離される

## データモデル

### ER図

```
User (ユーザー)
  ├─ is_anonymous: boolean
  │
  ├─ Farm (農場)
  │   ├─ region: string
  │   ├─ is_reference: boolean
  │   ├─ latitude/longitude: decimal
  │   └─ Field (圃場)
  │       └─ region: string
  │
  ├─ Crop (作物)
  │   ├─ region: string
  │   ├─ is_reference: boolean
  │   ├─ variety: string
  │   ├─ area_per_unit: float
  │   └─ revenue_per_area: float
  │
  └─ InteractionRule (輪作ルール)
      ├─ region: string
      ├─ is_reference: boolean
      ├─ source_group: string
      ├─ target_group: string
      └─ impact_ratio: decimal
```

### カラム定義

```ruby
# 全モデル共通
region: string, optional, indexed

# 特定モデル
Farm:
  - is_reference: boolean (参照農場フラグ)
  - user_id: 参照農場の場合はアノニマスユーザー

Crop, InteractionRule:
  - is_reference: boolean (参照データフラグ)
  - user_id: 参照データの場合はnull
```

## 実装計画

### Phase 1: データベース層 ✅
- [x] マイグレーション作成
  - [x] Fields, Crops, InteractionRulesにregionカラム追加
  - [x] Farmsにregionカラム追加
- [x] インデックス作成

### Phase 2: モデル層 ✅
- [x] スコープ実装
  - [x] `by_region(code)`スコープを4モデルに追加
- [x] バリデーション
  - [x] 参照Farmのアノニマスユーザー制約

### Phase 3: テスト ✅
- [x] ユニットテスト
  - [x] Farm Region Test (20テスト)
  - [x] Field Region Test (12テスト)
  - [x] Crop Region Test (12テスト)
  - [x] InteractionRule Region Test (11テスト)
- [x] 統合テスト
  - [x] Region Feature Integration Test (18テスト)

### Phase 4: データ投入（次フェーズ）
- [ ] 日本の参照データ作成
  - [ ] 参照Farm（北海道、東京、九州）
  - [ ] 参照Crop（コシヒカリ、大豆、小麦など）
  - [ ] 参照InteractionRule（水稲・大豆輪作など）
- [ ] アメリカの参照データ作成
  - [ ] 参照Farm（アイオワ、カリフォルニア、テキサス）
  - [ ] 参照Crop（コーン、大豆、小麦など）
  - [ ] 参照InteractionRule（コーン・大豆輪作など）

### Phase 5: UI対応（次フェーズ）
- [ ] 地域選択UI
- [ ] 地域別データ表示
- [ ] 言語と地域の連携

## テスト戦略

### テストカバレッジ

| 要件 | テスト数 | 状態 |
|------|---------|------|
| R1: 基本データ操作 | 2テスト | ✅ 完了 |
| R2: 地域別フィルタリング | 2テスト | ✅ 完了 |
| R3: 地域別参照データ提供 | 4テスト | ✅ 完了 |
| R4: 地域別ビジネスロジック | 3テスト | ✅ 完了 |
| R5: データの独立性 | 2テスト | ✅ 完了 |
| シナリオテスト | 2テスト | ✅ 完了 |
| **合計** | **18テスト** | **✅ 完了** |

### テスト実行

```bash
# 統合テスト実行
docker compose run --rm test bundle exec rails test test/integration/region_feature_integration_test.rb

# 全地域関連テスト実行
docker compose run --rm test bundle exec rails test test/models/*_region_test.rb test/integration/region_feature_integration_test.rb
```

## 今後の拡張

### 地域の追加
- ヨーロッパ（`"eu"`）
- 中国（`"cn"`）
- オーストラリア（`"au"`）

### 地域別機能
- 地域別の単位系（メートル法 vs ヤード・ポンド法）
- 地域別の栽培カレンダー（北半球 vs 南半球）
- 地域別の祝日・休日

### 多言語対応
- 地域コードと言語コードの連携
- 地域別のデフォルト言語設定
- 地域別の通貨表示

## まとめ

この要件により、AGRRは以下を実現します：

1. **グローバル対応**: 各国・地域に適したデータ提供
2. **ローカライゼーション**: 地域の農業実践を正確に反映
3. **スケーラビリティ**: 新しい地域の追加が容易
4. **データ品質**: 地域別の専門知識を活用した高品質データ
5. **ユーザー体験**: ユーザーの地域に最適化された情報提供

これにより、日本の農家もアメリカの農家も、それぞれの地域に適した農業計画を立てることができます。

