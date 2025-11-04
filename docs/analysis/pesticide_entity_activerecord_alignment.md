# PesticideのEntityとActiveRecordの整合性分析

## 📋 概要

このドキュメントは、PesticideのDomain Entity（`lib/domain/pesticide/entities/pesticide_entity.rb`）とActiveRecordモデル（`app/models/pesticide.rb`）の整合性を分析し、修正すべき乖離を明確にします。

## 🏗️ Clean ArchitectureにおけるEntityとActiveRecordの関係

### 1. Entity（Domain層）の役割

- **ビジネスロジック**を含む純粋なRubyオブジェクト
- データベース非依存
- **真実の源（Single Source of Truth）**として、データ構造を定義
- バリデーションとビジネスメソッドを含む

### 2. ActiveRecordモデル（Adapter層）の役割

- データベースとのやり取りを担当
- Entityで定義された属性を**そのまま反映**する必要がある
- `belongs_to`, `has_many`などの関連定義はActiveRecord固有
- `to_agrr_output`, `from_agrr_output`などの変換メソッドを含む

### 3. Gateway（Adapter層）の役割

- ActiveRecordとEntityの間の変換を行う
- `entity_from_record(record)`メソッドでActiveRecord → Entity変換
- Entityの属性をActiveRecordの属性にマッピング

## 🔍 既存パターンの確認

### Cropの例

**CropEntity** (`lib/domain/crop/entities/crop_entity.rb`):
```ruby
attr_reader :id, :user_id, :name, :variety, :is_reference, 
            :area_per_unit, :revenue_per_area, :groups, 
            :created_at, :updated_at
```

**Crop ActiveRecord** (`app/models/crop.rb`):
```ruby
# 同じ属性がテーブルに存在
belongs_to :user, optional: true
# + Entityの属性すべて
```

**CropMemoryGateway** (`lib/adapters/crop/gateways/crop_memory_gateway.rb`):
```ruby
def entity_from_record(record)
  Domain::Crop::Entities::CropEntity.new(
    id: record.id,
    user_id: record.user_id,  # ← ActiveRecordの属性をEntityにマッピング
    name: record.name,
    # ... 他の属性も同様
  )
end
```

### Fertilizeの例

**FertilizeEntity** (`lib/domain/fertilize/entities/fertilize_entity.rb`):
```ruby
attr_reader :id, :name, :n, :p, :k, :description, 
            :package_size, :is_reference, :created_at, :updated_at
```

**Fertilize ActiveRecord** (`app/models/fertilize.rb`):
```ruby
# Entityの属性がそのままテーブルに存在
```

**FertilizeMemoryGateway** (`lib/adapters/fertilize/gateways/fertilize_memory_gateway.rb`):
```ruby
def entity_from_record(record)
  Domain::Fertilize::Entities::FertilizeEntity.new(
    id: record.id,
    name: record.name,
    # ... Entityの属性すべてをマッピング
  )
end
```

## ❌ 現在のPesticideの乖離

### PesticideEntityの現在の定義

```ruby
# lib/domain/pesticide/entities/pesticide_entity.rb
attr_reader :id, :pesticide_id, :name, :active_ingredient, :description,
            :is_reference, :created_at, :updated_at
```

### Pesticide ActiveRecordの現在の定義

```ruby
# app/models/pesticide.rb
belongs_to :crop      # ← Entityに存在しない！
belongs_to :pest      # ← Entityに存在しない！
# + Entityの属性すべて
```

### 問題点

1. **重大な乖離**: `PesticideEntity`に`crop_id`と`pest_id`が定義されていない
2. **Gatewayが作成できない**: Gatewayの`entity_from_record`でマッピングできない
3. **単一責任原則違反**: Entityが「真実の源」であるべきなのに、ActiveRecordにのみ属性が存在

## ✅ 修正すべき内容

### 1. PesticideEntityに`crop_id`と`pest_id`を追加

```ruby
# lib/domain/pesticide/entities/pesticide_entity.rb
class PesticideEntity
  attr_reader :id, :pesticide_id, :crop_id, :pest_id,  # ← 追加
              :name, :active_ingredient, :description,
              :is_reference, :created_at, :updated_at

  def initialize(attributes)
    @id = attributes[:id]
    @pesticide_id = attributes[:pesticide_id]
    @crop_id = attributes[:crop_id]      # ← 追加
    @pest_id = attributes[:pest_id]        # ← 追加
    @name = attributes[:name]
    # ... 他の属性
    
    validate!
  end

  private

  def validate!
    raise ArgumentError, "Pesticide ID is required" if pesticide_id.blank?
    raise ArgumentError, "Name is required" if name.blank?
    raise ArgumentError, "Crop ID is required" if crop_id.blank?        # ← 追加
    raise ArgumentError, "Pest ID is required" if pest_id.blank?        # ← 追加
  end
end
```

### 2. Gatewayの作成（将来的に必要）

```ruby
# lib/adapters/pesticide/gateways/pesticide_memory_gateway.rb
def entity_from_record(record)
  Domain::Pesticide::Entities::PesticideEntity.new(
    id: record.id,
    pesticide_id: record.pesticide_id,
    crop_id: record.crop_id,        # ← Entityに追加後、マッピング可能
    pest_id: record.pest_id,        # ← Entityに追加後、マッピング可能
    name: record.name,
    # ... 他の属性
  )
end
```

## 📝 まとめ

### 原則

1. **Entityが先**: Entityでデータ構造を定義する
2. **ActiveRecordが従**: Entityの属性をそのまま反映する
3. **Gatewayが変換**: ActiveRecord ↔ Entityの変換を行う

### 現在の状態

- ❌ Entityに`crop_id`と`pest_id`が定義されていない
- ❌ ActiveRecordにのみ`crop_id`と`pest_id`が存在
- ❌ Gatewayが作成できない（EntityとActiveRecordの不整合）

### 修正後の状態（期待）

- ✅ Entityに`crop_id`と`pest_id`が定義される
- ✅ ActiveRecordはEntityを反映（すでに実装済み）
- ✅ Gatewayが作成可能（将来的に必要になった場合）

## 🚨 影響範囲

1. **Entityのテスト**: `crop_id`と`pest_id`のテストを追加
2. **Gatewayの作成**: 将来的にGatewayが必要になった場合、整合性が取れている
3. **UseCase/Interactor**: Entityをベースに実装するため、整合性が必要




