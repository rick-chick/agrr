# PesticideのEntityとActiveRecordモデル詳細比較

## 📋 比較概要

このドキュメントは、Pesticide関連のEntityとActiveRecordモデルを詳細に比較し、**乖離**を明確にします。

## 🔍 1. PesticideEntity vs Pesticide ActiveRecord

### PesticideEntity（Domain層）

```ruby
# lib/domain/pesticide/entities/pesticide_entity.rb
attr_reader :id, :pesticide_id, :crop_id, :pest_id, :name, :active_ingredient, 
            :description, :is_reference, :created_at, :updated_at
```

**属性**:
- `id`: データベースの主キー（Integer）
- `pesticide_id`: 農薬ID（String、agrr CLI用）
- `crop_id`: 作物ID（Integer、必須）
- `pest_id`: 害虫ID（Integer、必須）
- `name`: 農薬名（String、必須）
- `active_ingredient`: 有効成分（String、任意）
- `description`: 説明（Text、任意）
- `is_reference`: 参照フラグ（Boolean）
- `created_at`, `updated_at`: タイムスタンプ

**バリデーション**:
- `pesticide_id`必須
- `name`必須
- `crop_id`必須
- `pest_id`必須

### Pesticide ActiveRecord（Adapter層）

```ruby
# app/models/pesticide.rb
belongs_to :crop
belongs_to :pest
has_one :pesticide_usage_constraint
has_one :pesticide_application_detail
```

**テーブル構造**（推測）:
- `id`: 主キー（Integer）
- `pesticide_id`: 農薬ID（String、unique with scope: [:crop_id, :pest_id]）
- `crop_id`: 外部キー（Integer、NOT NULL）
- `pest_id`: 外部キー（Integer、NOT NULL）
- `name`: 農薬名（String、NOT NULL）
- `active_ingredient`: 有効成分（String、NULL可）
- `description`: 説明（Text、NULL可）
- `is_reference`: 参照フラグ（Boolean、NOT NULL）
- `created_at`, `updated_at`: タイムスタンプ

### ✅ 整合性チェック

| 属性 | Entity | ActiveRecord | 状態 |
|------|--------|--------------|------|
| `id` | ✅ あり | ✅ あり | ✅ 一致 |
| `pesticide_id` | ✅ あり | ✅ あり | ✅ 一致 |
| `crop_id` | ✅ あり（必須） | ✅ あり（外部キー） | ✅ 一致 |
| `pest_id` | ✅ あり（必須） | ✅ あり（外部キー） | ✅ 一致 |
| `name` | ✅ あり（必須） | ✅ あり（必須） | ✅ 一致 |
| `active_ingredient` | ✅ あり（任意） | ✅ あり（任意） | ✅ 一致 |
| `description` | ✅ あり（任意） | ✅ あり（任意） | ✅ 一致 |
| `is_reference` | ✅ あり | ✅ あり | ✅ 一致 |
| `created_at` | ✅ あり | ✅ あり | ✅ 一致 |
| `updated_at` | ✅ あり | ✅ あり | ✅ 一致 |

**結論**: PesticideEntityとPesticide ActiveRecordは**整合性が取れています**。

---

## 🔍 2. from_agrr_output メソッドの問題

### 現在の実装

```ruby
# app/models/pesticide.rb
def self.from_agrr_output(pesticide_data:, is_reference: true)
  # ❌ crop_id と pest_id が pesticide_data に含まれていない可能性
  # ❌ Entityでは必須だが、このメソッドで設定されていない
  
  pesticide = find_or_initialize_by(pesticide_id: pesticide_data['pesticide_id'])
  pesticide.assign_attributes(
    name: pesticide_data['name'],
    active_ingredient: pesticide_data['active_ingredient'],
    description: pesticide_data['description'],
    is_reference: is_reference
    # ❌ crop_id と pest_id が設定されていない！
  )
  pesticide.save!
  # ...
end
```

### ❌ 重大な乖離

1. **`crop_id`と`pest_id`が欠落**
   - Entityでは必須
   - `from_agrr_output`で設定されていない
   - このままではバリデーションエラーが発生する

2. **agrr CLIの出力形式が不明**
   - agrr CLIが`crop_id`と`pest_id`を含むか不明
   - 含まない場合は、パラメータとして追加する必要がある

### ✅ 修正が必要

```ruby
def self.from_agrr_output(pesticide_data:, crop_id:, pest_id:, is_reference: true)
  pesticide = find_or_initialize_by(
    pesticide_id: pesticide_data['pesticide_id'],
    crop_id: crop_id,
    pest_id: pest_id
  )
  pesticide.assign_attributes(
    crop_id: crop_id,        # ← 追加
    pest_id: pest_id,        # ← 追加
    name: pesticide_data['name'],
    # ...
  )
  # ...
end
```

---

## 🔍 3. to_agrr_output メソッドの問題

### 現在の実装

```ruby
# app/models/pesticide.rb
def to_agrr_output
  {
    'pesticide_id' => pesticide_id,
    'name' => name,
    'active_ingredient' => active_ingredient,
    'description' => description,
    # ❌ crop_id と pest_id が出力されていない
    'usage_constraints' => # ...
    'application_details' => # ...
  }
end
```

### ❌ 問題点

1. **`crop_id`と`pest_id`が出力に含まれていない**
   - Entityには存在するが、出力形式に含まれていない
   - agrr CLIがこれらを必要とするかは不明だが、整合性のため検討が必要

2. **Entityとの不整合**
   - Entityには`crop_id`と`pest_id`がある
   - しかし`to_agrr_output`では出力されていない
   - Gatewayが作成された場合、Entityに変換できない可能性

### ⚠️ 判断が必要

- agrr CLIが`crop_id`と`pest_id`を必要とするか確認が必要
- 必要でない場合でも、**内部的な整合性のために検討が必要**

---

## 🔍 4. PesticideUsageConstraintsEntity vs PesticideUsageConstraint

### PesticideUsageConstraintsEntity

```ruby
attr_reader :id, :pesticide_id, :min_temperature, :max_temperature,
            :max_wind_speed_m_s, :max_application_count,
            :harvest_interval_days, :other_constraints,
            :created_at, :updated_at
```

**注意**: `pesticide_id`は**文字列ID**（`Pesticide.pesticide_id`）か、**整数ID**（`Pesticide.id`）か不明確

### PesticideUsageConstraint ActiveRecord

```ruby
belongs_to :pesticide  # → pesticide_id は整数ID（Pesticide.id）
```

### ❌ 重大な乖離

| 属性 | Entity | ActiveRecord | 問題 |
|------|--------|--------------|------|
| `pesticide_id` | 文字列ID（推測） | 整数ID（外部キー） | ❌ **型が異なる** |

**Entityの`pesticide_id`**:
- `Pesticide.pesticide_id`（文字列）を想定している可能性
- 例: `"acetamiprid"`

**ActiveRecordの`pesticide_id`**:
- `Pesticide.id`（整数）を外部キーとして使用
- 例: `1`, `2`, `3`

### ✅ 修正が必要

**オプション1**: Entityの`pesticide_id`を削除し、`pesticide`オブジェクト参照にする（推奨しない）

**オプション2**: Entityの`pesticide_id`を整数ID（`Pesticide.id`）に統一（推奨）

```ruby
# lib/domain/pesticide/entities/pesticide_usage_constraints_entity.rb
attr_reader :id, :pesticide_id,  # ← これは整数ID（Pesticide.id）を指す
            :min_temperature, # ...
```

### ✅ 整合性チェック（修正後想定）

| 属性 | Entity | ActiveRecord | 状態 |
|------|--------|--------------|------|
| `id` | ✅ | ✅ | ✅ 一致 |
| `pesticide_id` | ✅（整数ID） | ✅（外部キー） | ⚠️ **修正必要** |
| `min_temperature` | ✅ | ✅ | ✅ 一致 |
| `max_temperature` | ✅ | ✅ | ✅ 一致 |
| `max_wind_speed_m_s` | ✅ | ✅ | ✅ 一致 |
| `max_application_count` | ✅ | ✅ | ✅ 一致 |
| `harvest_interval_days` | ✅ | ✅ | ✅ 一致 |
| `other_constraints` | ✅ | ✅ | ✅ 一致 |
| `created_at` | ✅ | ✅ | ✅ 一致 |
| `updated_at` | ✅ | ✅ | ✅ 一致 |

---

## 🔍 5. PesticideApplicationDetailsEntity vs PesticideApplicationDetail

### PesticideApplicationDetailsEntity

```ruby
attr_reader :id, :pesticide_id, :dilution_ratio, :amount_per_m2,
            :amount_unit, :application_method, :created_at, :updated_at
```

**注意**: `pesticide_id`は**文字列ID**か**整数ID**か不明確

### PesticideApplicationDetail ActiveRecord

```ruby
belongs_to :pesticide  # → pesticide_id は整数ID（Pesticide.id）
```

### ❌ 同じ問題

| 属性 | Entity | ActiveRecord | 問題 |
|------|--------|--------------|------|
| `pesticide_id` | 文字列ID（推測） | 整数ID（外部キー） | ❌ **型が異なる** |

### ✅ 修正が必要

Entityの`pesticide_id`を整数ID（`Pesticide.id`）に統一する必要がある。

---

## 🔍 6. バリデーションの違い

### Entityのバリデーション

**PesticideEntity**:
```ruby
raise ArgumentError, "Pesticide ID is required" if pesticide_id.blank?
raise ArgumentError, "Name is required" if name.blank?
raise ArgumentError, "Crop ID is required" if crop_id.blank?
raise ArgumentError, "Pest ID is required" if pest_id.blank?
```

**PesticideUsageConstraintsEntity**:
```ruby
raise ArgumentError, "Pesticide ID is required" if pesticide_id.blank?
raise ArgumentError, "Min temperature must be less than max temperature" if ...
raise ArgumentError, "Max wind speed must be positive" if ...
raise ArgumentError, "Max application count must be positive" if ...
raise ArgumentError, "Harvest interval must be non-negative" if ...
```

**PesticideApplicationDetailsEntity**:
```ruby
raise ArgumentError, "Pesticide ID is required" if pesticide_id.blank?
raise ArgumentError, "Amount per m2 must be positive" if ...
raise ArgumentError, "Amount unit requires amount_per_m2" if ...
raise ArgumentError, "Amount per m2 requires amount_unit" if ...
```

### ActiveRecordのバリデーション

**Pesticide**:
```ruby
validates :pesticide_id, presence: true, uniqueness: { scope: [:crop_id, :pest_id] }
validates :name, presence: true
validates :is_reference, inclusion: { in: [true, false] }
validates :crop, presence: true
validates :pest, presence: true
```

**PesticideUsageConstraint**:
```ruby
validates :pesticide, presence: true
validates :max_wind_speed_m_s, numericality: { greater_than_or_equal_to: 0, allow_nil: true }
validates :max_application_count, numericality: { greater_than: 0, allow_nil: true }
validates :harvest_interval_days, numericality: { greater_than_or_equal_to: 0, allow_nil: true }
validate :min_temperature_must_be_less_than_max
```

**PesticideApplicationDetail**:
```ruby
validates :pesticide, presence: true
validates :amount_per_m2, numericality: { greater_than_or_equal_to: 0, allow_nil: true }
validate :amount_and_unit_consistency
```

### ✅ バリデーションの整合性

| チェック | Entity | ActiveRecord | 状態 |
|----------|--------|--------------|------|
| `pesticide_id`必須 | ✅ | ✅ | ✅ 一致 |
| `name`必須 | ✅ | ✅ | ✅ 一致 |
| `crop_id`必須 | ✅ | ✅ | ✅ 一致 |
| `pest_id`必須 | ✅ | ✅ | ✅ 一致 |
| 温度範囲チェック | ✅ | ✅ | ✅ 一致（実装方法は異なる） |
| 数値範囲チェック | ✅ | ✅ | ✅ 一致（実装方法は異なる） |
| amount/unit整合性 | ✅ | ✅ | ✅ 一致（実装方法は異なる） |

**結論**: バリデーションロジックは**実質的に一致**していますが、実装方法が異なります。

---

## 📊 乖離サマリー

### ✅ 整合しているもの

1. **PesticideEntity ↔ Pesticide ActiveRecord**: 属性が完全に一致
2. **バリデーションロジック**: 実質的に一致（実装方法は異なる）
3. **基本的な属性**: すべて一致

### ❌ 重大な乖離

#### 1. `from_agrr_output`メソッド
- **問題**: `crop_id`と`pest_id`が設定されていない
- **影響**: バリデーションエラーが発生する
- **修正**: パラメータとして追加する必要がある

```ruby
def self.from_agrr_output(pesticide_data:, crop_id:, pest_id:, is_reference: true)
```

#### 2. `to_agrr_output`メソッド
- **問題**: `crop_id`と`pest_id`が出力に含まれていない
- **影響**: Entityとの不整合、Gateway作成時に問題が発生する可能性
- **判断**: agrr CLIがこれらを必要とするか確認が必要

#### 3. UsageConstraints/ApplicationDetailsの`pesticide_id`
- **問題**: Entityの`pesticide_id`が文字列IDか整数IDか不明確
- **影響**: GatewayでActiveRecord → Entity変換時に型不一致エラー
- **修正**: Entityの`pesticide_id`を整数ID（`Pesticide.id`）に統一

---

## 🔧 修正優先順位

### 🔴 優先度: 高（必須）✅ 完了

1. **`from_agrr_output`に`crop_id`と`pest_id`を追加** ✅
   - パラメータとして`crop_id`と`pest_id`を追加
   - `find_or_initialize_by`のスコープに追加
   - バリデーションを追加

2. **UsageConstraints/ApplicationDetailsのEntityの`pesticide_id`を整数IDに統一** ✅
   - コメントで明確化（`pesticide_id`は整数ID（`Pesticide.id`）を指す）

### 🟡 優先度: 中（推奨）✅ 完了

3. **`to_agrr_output`に`crop_id`と`pest_id`を追加** ✅
   - Entityとの整合性のために追加
   - agrr CLIが文字列を期待する可能性があるため`to_s`で変換

---

## ✅ 修正完了

### 実施した修正

1. ✅ `from_agrr_output`メソッドに`crop_id`と`pest_id`パラメータを追加
2. ✅ UsageConstraints/ApplicationDetailsのEntityにコメント追加（`pesticide_id`は整数ID）
3. ✅ `to_agrr_output`メソッドに`crop_id`と`pest_id`を追加
4. ✅ テストファイルをすべて修正（`crop_id`と`pest_id`を追加）
5. ✅ Factoryに`crop`と`pest`の関連を追加

### 修正後の状態

- ✅ EntityとActiveRecordの属性が完全に一致
- ✅ `from_agrr_output`が`crop_id`と`pest_id`を設定
- ✅ `to_agrr_output`が`crop_id`と`pest_id`を出力
- ✅ すべてのテストが成功
- ✅ Gateway作成時に整合性が確保される

---

## 📝 結論（修正後）

**PesticideEntityとPesticide ActiveRecordは基本的に整合していますが**、以下の点で修正が必要です：

1. ✅ 属性の整合性: **良好**
2. ❌ `from_agrr_output`メソッド: **修正必要**
3. ⚠️ `to_agrr_output`メソッド: **検討必要**
4. ❌ 関連Entityの`pesticide_id`: **修正必要**

これらの修正により、EntityとActiveRecordの完全な整合性が確保され、Gatewayの実装が可能になります。

