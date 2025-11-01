# Fertilizeモデル化の詳細検討

## 📊 現状分析

### AGRR CLIから取得できる情報の完全な構造

#### 1. fertilize_list（肥料一覧）

**基本形（area指定なし）**:
```ruby
# パラメータ: language, limit, area（オプション）
# 戻り値: 肥料名の配列
{
  "fertilizers": ["尿素", "リン酸一安", "硫安", "過リン酸石灰", "塩化カリ"],
  "count": 5
}
```

**area指定あり**:
```ruby
# areaが指定されても戻り値形式は同じ（肥料名のみ）
{
  "fertilizers": ["尿素", "リン酸一安", "硫安", "過リン酸石灰", "塩化カリ"],
  "count": 5
}
```

**データ構造**:
- `fertilizers`: 肥料名の文字列配列
- `count`: 返された肥料の数
- `area`パラメータがあっても戻り値形式は変わらない
- NPK情報や詳細情報は含まれない。詳細が必要な場合は`fertilize_get`を使用

#### 2. fertilize_get（肥料詳細）

```ruby
# パラメータ: name
# 戻り値: 肥料の詳細情報
{
  'name' => '尿素',
  'n' => 46,
  'p' => nil,  # 含まれない場合もある
  'k' => nil,  # 含まれない場合もある
  'description' => '窒素肥料として広く使用される',
  'package_size' => '25kg'
}
```

**重要な認識**:
- `description`, `package_size`は`fertilize_get`でのみ取得可能
- `fertilize_list`では肥料名の文字列のみを返す
- 詳細情報（NPK, description, package_sizeなど）が必要な場合は`fertilize_get`を個別に呼び出す必要がある

#### 3. fertilize_recommend（肥料推奨）

```ruby
# パラメータ: crop_file（JSONファイル）
# 戻り値: 作物と肥料施用段階ごとの推奨情報
{
  'crop' => 'tomato',  # 作物名（文字列）
  'recommendations' => [
    {
      'stage' => 'base',  # 元肥（基肥）- 必須
      'n' => 15,          # 推奨窒素量（数値）
      'p' => 10,           # 推奨リン量（数値）
      'k' => 12,           # 推奨カリ量（数値）
      'fertilizer' => '配合肥料',  # 推奨肥料名（文字列）
      'amount' => 100      # 推奨肥料量（数値）
    },
    {
      'stage' => 'topdress',   # 追肥 - 必須
      'n' => 10,
      'p' => 5,
      'k' => 8,
      'fertilizer' => '尿素',
      'amount' => 50
    }
  ]
}
```

**データ構造**: 
- `stage`: 必須。値は`'base'`（元肥/基肥）または`'topdress'`（追肥）
- `fertilizer`: 肥料名（文字列）。fertilize_idではない
- `amount`: 推奨肥料量（数値）

### 既存のモデルパターンとの詳細比較

#### Crop ↔ CropStage の関係パターン

```ruby
# Crop: 独立したエンティティ（マスターデータ）
class Crop < ApplicationRecord
  belongs_to :user, optional: true
  has_many :crop_stages, dependent: :destroy
  
  validates :is_reference, inclusion: { in: [true, false] }
  validates :user, presence: true, unless: :is_reference?
  validate :user_crop_count_limit, unless: :is_reference?
  
  scope :reference, -> { where(is_reference: true) }
  scope :user_owned, -> { where(is_reference: false) }
end

# CropStage: Cropに属する子エンティティ
class CropStage < ApplicationRecord
  belongs_to :crop
  has_one :temperature_requirement, dependent: :destroy
  has_one :sunshine_requirement, dependent: :destroy
  has_one :thermal_requirement, dependent: :destroy
  
  validates :name, presence: true
  validates :order, presence: true, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
end
```

**パターンの特徴**:
1. **親子関係**: `has_many / belongs_to`の関係
2. **依存関係**: 子エンティティは親なしでは存在できない（dependent: :destroy）
3. **参照データパターン**: `is_reference`フラグで参照データとユーザーデータを区別
4. **リソース制限**: ユーザーデータには件数制限（Crop: 20件、Farm: 4件）

#### Fertilizeのモデル化における考慮点

**Fertilizeモデル**:
- Cropと同様に独立したエンティティ
- `is_reference`パターンを適用する必要がある
- ただし、肥料は基本的に参照データのみ（ユーザーが独自の肥料を作成する必要性は低い）
- したがって、`is_reference`は必須だが、デフォルトは`true`とし、基本的に参照データのみ扱う

**CropFertilizeモデル**:
- 関係テーブル（中間テーブル）の性質
- Crop ↔ CropStageとは異なり、独立した概念を持つ関係データ
- `fertilize_recommend`で返される`fertilizer`名に対して`fertilize_get`を呼び出し、`FertilizeEntity`（id付き）を取得してから`fertilize_id`として使用

### fertilize_recommendの使用ケース分析

#### 現在の実装状況

- `FertilizeGateway`に`recommend`メソッドは存在（```app/gateways/agrr/fertilize_gateway.rb```）
- `AgrrService`に`fertilize_recommend`メソッドは存在（```app/services/agrr_service.rb```）
- しかし、コントローラーやサービスで`fertilize_recommend`を使用している箇所は見当たらない
- **結論**: 現時点では実装されていない機能

#### 想定される使用ケース

**ケース1: 作物選択時の肥料推奨表示**
- ユーザーが作物を選択
- その作物に推奨される肥料施用計画を表示
- リアルタイムでAGRR CLIから取得

**ケース2: 栽培計画への肥料計画の組み込み**
- 栽培計画作成時に、作物ごとの肥料施用計画を自動生成
- 推奨情報を保存して計画に含める

**ケース3: 肥料施用履歴の管理**
- 実際に施用した肥料の記録
- 推奨情報との比較

#### 永続化の方針

**CropFertilizeは永続化する**:
- ✅ パフォーマンス向上（AGRR CLI呼び出しを減らす）
- ✅ ユーザーが推奨情報をカスタマイズ・保存可能
- ✅ 履歴管理が可能（推奨情報の変更履歴を追跡）
- ✅ データの再利用が可能

**データ同期について**:
- AGRR CLIから取得した推奨情報を永続化する

## 🎯 モデル化の方針（詳細設計）

### 1. Fertilize モデル（肥料マスタ）

**役割**: 肥料の基本情報を保持する参照データ

**属性**:
```ruby
- id (integer): プライマリキー
- name (string): 肥料名（一意、必須）
- n (float): 窒素含有率（%）
- p (float): リン含有率（%）
- k (float): カリ含有率（%）
- description (text): 説明文
- usage (text): 使用方法
- application_rate (string): 適用率（例: "1㎡あたり10-30g"）
- is_reference (boolean): 参照肥料フラグ（デフォルト: true）
- created_at, updated_at
```

**データソース**: `fertilize_list` / `fertilize_get` から取得

**永続化**: ✅ **必要**
- 理由: 肥料は独立したマスタデータとして永続化すべき
- 参照頻度: 高（一覧表示、詳細表示）
- 更新頻度: 低（マスタデータ）

**実装パターン**:
```ruby
# app/models/fertilize.rb
class Fertilize < ApplicationRecord
  # 関連
  has_many :crop_fertilizes, dependent: :destroy  # Phase 2で使用
  
  # バリデーション
  validates :name, presence: true, uniqueness: true
  validates :is_reference, inclusion: { in: [true, false] }
  validates :n, numericality: { greater_than_or_equal_to: 0, allow_nil: true }
  validates :p, numericality: { greater_than_or_equal_to: 0, allow_nil: true }
  validates :k, numericality: { greater_than_or_equal_to: 0, allow_nil: true }
  
  # スコープ
  scope :reference, -> { where(is_reference: true) }
  
  # ヘルパーメソッド
  def has_nutrient?(nutrient)
    case nutrient.to_sym
    when :n
      n.present? && n > 0
    when :p
      p.present? && p > 0
    when :k
      k.present? && k > 0
    else
      false
    end
  end
  
  def npk_summary
    [n, p, k].compact.map { |v| v.to_i }.join('-')
  end
end
```

### 2. CropFertilize モデル（作物×肥料×肥料施用段階）

**役割**: 作物と肥料施用段階ごとの肥料推奨情報

**データ構造**:
- `fertilize_recommend`の`stage`: 肥料施用の段階。値は`'base'`（元肥）または`'topdress'`（追肥）
- `CropStage`（生育段階）とは異なる概念
- `CropFertilize`は`fertilize_id`（外部キー）で`Fertilize`モデルと紐づく
- `fertilize_recommend`で返される`fertilizer`（文字列）に対して`fertilize_get`で取得し、`create`することで`FertilizeEntity`（id付き）を取得し、その`id`を`fertilize_id`として使用

**属性の詳細検討**:

```ruby
# 必須属性
- crop_id (integer): 作物ID（外部キー）
  # 理由: 推奨情報は作物に紐づく
  # 参照先: crops.id
  # 関連: belongs_to :crop

- fertilize_id (integer): 肥料ID（外部キー）
  # 理由: 推奨される肥料を特定
  # 参照先: fertilizes.id
  # 関連: belongs_to :fertilize
  # 注意: fertilize_recommendで返されるfertilizer名に対してfertilize_getを呼び出し、FertilizeEntity（id付き）を取得してからfertilize_idとして使用

- stage (string): 肥料施用段階（必須）
  # 値: 'base'（元肥）、'topdress'（追肥）
  # 理由: fertilize_recommendのstageをそのまま保存
  # 制約: 必須、enum的な値の検証が必要

- n (float): 推奨窒素量（数値）

- p (float): 推奨リン量（数値）

- k (float): 推奨カリ量（数値）

- amount (float): 推奨肥料量（数値）

# オプション属性
- crop_stage_id (integer, nullable): 生育段階ID（外部キー）
  # 理由: 特定の生育段階で推奨される肥料施用を関連付け
  # 注意: 肥料施用段階（stage）と生育段階（crop_stage）は異なる概念
  # 例: "定植期"（CropStage）で元肥（base）を推奨する場合

- is_reference (boolean, default: true): 参照推奨情報フラグ
  # 理由: AGRR CLIから生成された参照データか、ユーザーカスタマイズか
  # デフォルト: true（AGRR CLIから生成）

- user_id (integer, nullable): ユーザーID
  # 理由: ユーザーがカスタマイズした推奨情報の場合
  # 参照先: users.id
  # 注意: is_reference=trueの場合はnull

- created_at, updated_at
```

**モデルの実装例**:
```ruby
# app/models/crop_fertilize.rb
class CropFertilize < ApplicationRecord
  # 関連（IDで紐づく）
  belongs_to :crop
  belongs_to :fertilize  # fertilize_idでFertilizeモデルと紐づく
  
  belongs_to :crop_stage, optional: true  # オプション（肥料施用段階と生育段階の関連付け用）
  
  # バリデーション
  validates :stage, presence: true
  validates :stage, inclusion: { 
    in: [STAGE_BASE, STAGE_TOP_DRESSING], 
    message: "有効な肥料施用段階を指定してください"
  }
  validates :n, numericality: { greater_than_or_equal_to: 0, allow_nil: true }
  validates :p, numericality: { greater_than_or_equal_to: 0, allow_nil: true }
  validates :k, numericality: { greater_than_or_equal_to: 0, allow_nil: true }
  validates :amount, numericality: { greater_than: 0, allow_nil: true }
  
  # ユニーク制約: crop + stage + fertilize の組み合わせ
  validates :crop_id, uniqueness: { 
    scope: [:stage, :fertilize_id],
    message: "この作物・肥料施用段階・肥料の組み合わせは既に登録されています"
  }
  
  # 定数定義
  STAGE_BASE = 'base'  # 元肥（基肥）
  STAGE_TOP_DRESSING = 'topdress'  # 追肥
  
  # fertilize_recommendのデータからCropFertilizeを作成する際のファクトリーメソッド
  # 注意: fertilize_recommendで返されるfertilizer名に対してfertilize_getを呼び出し、FertilizeEntity（id付き）を取得してからfertilize_idとして使用
  def self.from_recommendation(crop_id, fertilize_id, recommendation_data)
    new(
      crop_id: crop_id,
      fertilize_id: fertilize_id,
      stage: recommendation_data['stage'],
      n: recommendation_data['n'],
      p: recommendation_data['p'],
      k: recommendation_data['k'],
      amount: recommendation_data['amount'],
      is_reference: true
    )
  end
end
```

**Fertilizeモデル側の関連定義**:
```ruby
# app/models/fertilize.rb（既存に追加）
class Fertilize < ApplicationRecord
  # 関連
  has_many :crop_fertilizes, dependent: :destroy  # Phase 2で使用
  
  # ... 既存のコード ...
end
```

**Cropモデル側の関連定義**:
```ruby
# app/models/crop.rb（既存に追加）
class Crop < ApplicationRecord
  # 関連（Phase 2で追加）
  has_many :crop_fertilizes, dependent: :destroy
  
  # ... 既存のコード ...
end
```

**fertilize_recommendの処理フロー**:
```ruby
# 1. fertilize_recommendから返ってくるデータ例
{
  'crop' => 'tomato',
  'recommendations' => [
    {
      'stage' => 'base',
      'fertilizer' => '配合肥料',  # ← 肥料名（文字列）
      'n' => 15,
      'p' => 10,
      'k' => 12,
      'amount' => 100
    }
  ]
}

# 2. fertilize_recommendの戻り値から、必要なfertilizer名を抽出
fertilizer_names = recommendations.map { |rec| rec['fertilizer'] }.uniq

# 3. 各fertilizer名に対して、fertilize_getで取得してcreateすることでFertilizeEntity（id付き）を取得
fertilizer_entities = []
fertilizer_names.each do |name|
  begin
    detail = agrr_gateway.get(name: name)
    entity = fertilize_gateway.create(detail)
    fertilizer_entities << entity
  rescue StandardError => e
    # nameがuniqueなので、既に存在する場合はunique制約違反エラーが発生
    # nameでの検索は想定しないため、エラーをスキップ
    Rails.logger.warn "Fertilize '#{name}' creation failed or already exists: #{e.message}"
  end
end

# 4. 推奨情報を保存
recommendations.each do |rec|
  # fertilizer_entitiesからnameで検索（配列内検索）
  fertilize_entity = fertilizer_entities.find { |e| e.name == rec['fertilizer'] }
  
  unless fertilize_entity
    Rails.logger.warn "Fertilize '#{rec['fertilizer']}' not found, skipping recommendation"
    next
  end
  
  CropFertilize.create!(
    crop_id: crop.id,
    fertilize_id: fertilize_entity.id,  # ← IDで紐づく
    stage: rec['stage'],
    n: rec['n'],
    p: rec['p'],
    k: rec['k'],
    amount: rec['amount'],
    is_reference: true
  )
end
```

**ユニーク制約**:
```ruby
# crop + stage + fertilize の組み合わせをユニーク
validates :crop_id, uniqueness: { 
  scope: [:stage, :fertilize_id],
  message: "この作物・肥料施用段階・肥料の組み合わせは既に登録されています"
}
```

**stageの値の検証**:
```ruby
# 定数定義
STAGE_BASE = 'base'  # 元肥（基肥）
STAGE_TOP_DRESSING = 'topdress'  # 追肥

# 検証
validates :stage, presence: true
validates :stage, inclusion: { 
  in: [STAGE_BASE, STAGE_TOP_DRESSING], 
  message: "有効な肥料施用段階を指定してください"
}
```

**データソース**: `fertilize_recommend` から取得

**永続化**: ✅ **永続化する**
- 理由: 
  - ✅ ユーザーが推奨情報を保存・参照できる
  - ✅ パフォーマンス向上（AGRR CLI呼び出しを減らす）
  - ✅ 履歴管理（推奨情報の変更履歴を追跡）
  - ✅ データの再利用が可能

**データ同期**:
- AGRR CLIから取得した推奨情報を永続化する

### 3. CropFertilizeとCropStageの関係（重要）

**重要な認識**: 
- `fertilize_recommend`の`stage`は**肥料施用の段階**（'base'=元肥、'topdress'=追肥）
- 既存の`CropStage`は**作物の生育段階**（"播種〜発芽"、"発芽〜成長"など）
- **これらは異なる概念**

**検討**:
- `fertilize_recommend`の`stage`: 'base'（元肥）、'topdress'（追肥）
- 既存の`CropStage.name`: "播種〜発芽"、"発芽〜成長"、"育苗期"、"定植期"など
- これらは直接対応しない

**設計**:
- `CropFertilize`は`stage`（string）を必須属性として持つ
- `crop_stage_id`はオプション属性として持つ

## 🏗️ Clean Architectureでの実装設計

### Domain層の実装パターン

#### Entity

```ruby
# lib/domain/fertilize/entities/fertilize_entity.rb
module Domain
  module Fertilize
    module Entities
      class FertilizeEntity
        attr_reader :id, :name, :n, :p, :k, :description, :usage, 
                    :application_rate, :is_reference, :created_at, :updated_at
        
        def initialize(attributes)
          @id = attributes[:id]
          @name = attributes[:name]
          @n = attributes[:n]
          @p = attributes[:p]
          @k = attributes[:k]
          @description = attributes[:description]
          @usage = attributes[:usage]
          @application_rate = attributes[:application_rate]
          @is_reference = attributes[:is_reference]
          @created_at = attributes[:created_at]
          @updated_at = attributes[:updated_at]
          
          validate!
        end
        
        def reference?
          !!is_reference
        end
        
        def has_nutrient?(nutrient)
          case nutrient.to_sym
          when :n
            n.present? && n > 0
          when :p
            p.present? && p > 0
          when :k
            k.present? && k > 0
          else
            false
          end
        end
        
        def npk_summary
          [n, p, k].compact.map { |v| v.to_i }.join('-')
        end
        
        private
        
        def validate!
          raise ArgumentError, "Name is required" if name.blank?
        end
      end
    end
  end
end
```

#### Gateway

```ruby
# lib/domain/fertilize/gateways/fertilize_gateway.rb
module Domain
  module Fertilize
    module Gateways
      class FertilizeGateway
        def find_by_id(id)
          raise NotImplementedError, "Subclasses must implement find_by_id"
        end
        
        def find_all(language:, limit: 5, area: nil)
          raise NotImplementedError, "Subclasses must implement find_all"
        end
        
        def create(fertilize_data)
          raise NotImplementedError, "Subclasses must implement create"
        end
        
        def update(id, fertilize_data)
          raise NotImplementedError, "Subclasses must implement update"
        end
      end
    end
  end
end
```

#### Interactors

```ruby
# lib/domain/fertilize/interactors/fertilize_list_interactor.rb
module Domain
  module Fertilize
    module Interactors
      class FertilizeListInteractor
        def initialize(agrr_gateway, fertilize_gateway)
          @agrr_gateway = agrr_gateway
          @fertilize_gateway = fertilize_gateway  # 抽象的なGatewayインターフェース
        end
        
        def call(language:, limit: 5, area: nil)
          # AGRR Gatewayから取得
          agrr_data = @agrr_gateway.list(language: language, limit: limit, area: area)
          
          # 不足している肥料をAGRRから取得して保存
          # fertilize_getで取得してcreateすることで、FertilizeEntity（id付き）を取得
          fertilize_entities = []
          
          agrr_data.each do |item|
            begin
              # fertilize_getで取得して、createメソッドで保存
              detail = @agrr_gateway.get(name: item['name'])
              entity = @fertilize_gateway.create(detail)
              fertilize_entities << entity
            rescue StandardError => e
              # nameがuniqueなので、既に存在する場合はunique制約違反エラーが発生
              # この場合、既存レコードのidを取得する必要があるが、
              # nameでの検索は想定しないため、エラーをスキップする
              # （既に存在する場合、fertilize_listで取得済みとみなす）
              Rails.logger.debug "Fertilize '#{item['name']}' creation failed: #{e.message}"
            end
          end
          
          Domain::Shared::Result.success(fertilize_entities)
        rescue StandardError => e
          Domain::Shared::Result.failure(e.message)
        end
      end
    end
  end
end
```

**重要な設計原則**:
- Interactorは抽象的な`FertilizeGateway`インターフェースに依存
- 具体的な実装（`FertilizeMemoryGateway`や`FertilizeActiveRecordGateway`）はControllerやDIコンテナで注入
- Interactor内で`memory_gateway`や`activerecord_gateway`などの具体的な実装を参照しない

### Adapter層の実装パターン

#### FertilizeMemoryGateway

```ruby
# lib/adapters/fertilize/gateways/fertilize_memory_gateway.rb
module Adapters
  module Fertilize
    module Gateways
      class FertilizeMemoryGateway < Domain::Fertilize::Gateways::FertilizeGateway
        def find_by_id(id)
          record = ::Fertilize.find_by(id: id)
          return nil unless record
          entity_from_record(record)
        end
        
        def find_all(language:, limit: 5, area: nil)
          # このメソッドは使わない（InteractorでAGRR Gatewayと組み合わせる）
          raise NotImplementedError
        end
        
        def create(fertilize_data)
          record = ::Fertilize.new(
            name: fertilize_data['name'],
            n: fertilize_data['n'],
            p: fertilize_data['p'],
            k: fertilize_data['k'],
            description: fertilize_data['description'],
            usage: fertilize_data['usage'],
            application_rate: fertilize_data['application_rate'],
            is_reference: true  # デフォルトは参照データ
          )
          
          unless record.save
            error_message = record.errors.full_messages.join(', ')
            raise StandardError, error_message
          end
          
          entity_from_record(record)
        end
        
        def update(id, fertilize_data)
          record = ::Fertilize.find(id)
          update_attributes = {}
          update_attributes[:name] = fertilize_data[:name] if fertilize_data.key?(:name)
          update_attributes[:n] = fertilize_data[:n] if fertilize_data.key?(:n)
          update_attributes[:p] = fertilize_data[:p] if fertilize_data.key?(:p)
          update_attributes[:k] = fertilize_data[:k] if fertilize_data.key?(:k)
          update_attributes[:description] = fertilize_data[:description] if fertilize_data.key?(:description)
          update_attributes[:usage] = fertilize_data[:usage] if fertilize_data.key?(:usage)
          update_attributes[:application_rate] = fertilize_data[:application_rate] if fertilize_data.key?(:application_rate)
          record.update!(update_attributes)
          entity_from_record(record.reload)
        end
        
        private
        
        def entity_from_record(record)
          Domain::Fertilize::Entities::FertilizeEntity.new(
            id: record.id,
            name: record.name,
            n: record.n,
            p: record.p,
            k: record.k,
            description: record.description,
            usage: record.usage,
            application_rate: record.application_rate,
            is_reference: record.is_reference,
            created_at: record.created_at,
            updated_at: record.updated_at
          )
        end
      end
    end
  end
end
```

#### FertilizeActiveRecordGateway

```ruby
# lib/adapters/fertilize/gateways/fertilize_activerecord_gateway.rb
module Adapters
  module Fertilize
    module Gateways
      class FertilizeActiveRecordGateway < Domain::Fertilize::Gateways::FertilizeGateway
        def find_by_id(id)
          record = ::Fertilize.find_by(id: id)
          return nil unless record
          entity_from_record(record)
        end
        
        def find_all(language:, limit: 5, area: nil)
          # このメソッドは使わない（InteractorでAGRR Gatewayと組み合わせる）
          raise NotImplementedError
        end
        
        def create(fertilize_data)
          record = ::Fertilize.new(
            name: fertilize_data['name'],
            n: fertilize_data['n'],
            p: fertilize_data['p'],
            k: fertilize_data['k'],
            description: fertilize_data['description'],
            usage: fertilize_data['usage'],
            application_rate: fertilize_data['application_rate'],
            is_reference: true  # デフォルトは参照データ
          )
          
          unless record.save
            error_message = record.errors.full_messages.join(', ')
            raise StandardError, error_message
          end
          
          entity_from_record(record)
        end
        
        def update(id, fertilize_data)
          record = ::Fertilize.find(id)
          update_attributes = {}
          update_attributes[:name] = fertilize_data[:name] if fertilize_data.key?(:name)
          update_attributes[:n] = fertilize_data[:n] if fertilize_data.key?(:n)
          update_attributes[:p] = fertilize_data[:p] if fertilize_data.key?(:p)
          update_attributes[:k] = fertilize_data[:k] if fertilize_data.key?(:k)
          update_attributes[:description] = fertilize_data[:description] if fertilize_data.key?(:description)
          update_attributes[:usage] = fertilize_data[:usage] if fertilize_data.key?(:usage)
          update_attributes[:application_rate] = fertilize_data[:application_rate] if fertilize_data.key?(:application_rate)
          record.update!(update_attributes)
          entity_from_record(record.reload)
        end
        
        private
        
        def entity_from_record(record)
          Domain::Fertilize::Entities::FertilizeEntity.new(
            id: record.id,
            name: record.name,
            n: record.n,
            p: record.p,
            k: record.k,
            description: record.description,
            usage: record.usage,
            application_rate: record.application_rate,
            is_reference: record.is_reference,
            created_at: record.created_at,
            updated_at: record.updated_at
          )
        end
      end
    end
  end
end
```


**Controllerでの使用例**:
```ruby
# app/controllers/api/v1/fertilizes_controller.rb
class Api::V1::FertilizesController < Api::V1::BaseController
  before_action :set_interactors
  
  private
  
  def set_interactors
    agrr_gateway = Agrr::FertilizeGateway.new
    fertilize_gateway = Adapters::Fertilize::Gateways::FertilizeActiveRecordGateway.new  # 具体的な実装を注入
    
    @list_interactor = Domain::Fertilize::Interactors::FertilizeListInteractor.new(
      agrr_gateway, 
      fertilize_gateway  # 抽象的なGatewayインターフェースとして渡す
    )
  end
end
```

## 📋 実装チェックリスト

### Phase 1: Fertilizeモデルの実装

#### Database
- [x] `fertilizes` テーブルのマイグレーション作成
  - [x] name (string, unique, not null)
  - [x] n, p, k (float, nullable)
  - [x] description, usage, application_rate (text, nullable)
  - [x] is_reference (boolean, default: true)
  - [x] created_at, updated_at

#### Domain層
- [x] `lib/domain/fertilize/entities/fertilize_entity.rb`
- [x] `lib/domain/fertilize/gateways/fertilize_gateway.rb`
- [x] `lib/domain/fertilize/interactors/fertilize_list_interactor.rb`
- [x] `lib/domain/fertilize/interactors/fertilize_get_interactor.rb`
- [x] `lib/domain/fertilize/interactors/fertilize_find_interactor.rb`
- [x] `lib/domain/fertilize/interactors/fertilize_create_interactor.rb`
- [x] `lib/domain/fertilize/interactors/fertilize_update_interactor.rb`

#### Adapter層
- [x] `lib/adapters/fertilize/gateways/fertilize_memory_gateway.rb`

#### Model層
- [x] `app/models/fertilize.rb`

#### Gateway層（既存）
- [x] `app/gateways/agrr/fertilize_gateway.rb`（既存）

#### テスト
- [x] `test/models/fertilize_test.rb`
- [x] `test/domain/fertilize/entities/fertilize_entity_test.rb`
- [x] `test/domain/fertilize/interactors/fertilize_list_interactor_test.rb`
- [x] `test/adapters/fertilize/gateways/fertilize_memory_gateway_test.rb`
- [x] `test/factories/fertilizes.rb`

### Phase 2: CropFertilizeモデルの実装

#### Database
- [ ] `crop_fertilizes` テーブルのマイグレーション作成
  - [ ] crop_id (integer, foreign key → crops.id)
  - [ ] fertilize_id (integer, foreign key → fertilizes.id) **重要: IDで紐づく**
  - [ ] stage (string, not null)
  - [ ] n, p, k (float, nullable)
  - [ ] amount (float, nullable)
  - [ ] crop_stage_id (integer, nullable, foreign key → crop_stages.id)
  - [ ] is_reference (boolean, default: true)
  - [ ] user_id (integer, nullable)
  - [ ] created_at, updated_at
  - [ ] unique index on (crop_id, stage, fertilize_id)
  - [ ] foreign key constraint on fertilize_id → fertilizes.id

**マイグレーションファイルの例**:
```ruby
# db/migrate/XXXXXX_create_crop_fertilizes.rb
class CreateCropFertilizes < ActiveRecord::Migration[8.0]
  def change
    create_table :crop_fertilizes do |t|
      t.references :crop, null: false, foreign_key: true
      t.references :fertilize, null: false, foreign_key: true  # fertilize_idで紐づく
      t.string :stage, null: false
      t.float :n
      t.float :p
      t.float :k
      t.float :amount
      t.references :crop_stage, null: true, foreign_key: true
      t.boolean :is_reference, default: true, null: false
      t.references :user, null: true, foreign_key: true
      
      t.timestamps
    end
    
    # ユニーク制約: crop + stage + fertilize の組み合わせ
    add_index :crop_fertilizes, [:crop_id, :stage, :fertilize_id], 
              unique: true, 
              name: 'index_crop_fertilizes_on_crop_stage_fertilize'
    
    # インデックス追加（検索性能向上）
    add_index :crop_fertilizes, :fertilize_id
    add_index :crop_fertilizes, [:crop_id, :is_reference]
  end
end
```

#### Domain層
- [ ] `lib/domain/fertilize/entities/crop_fertilize_entity.rb`
- [ ] `lib/domain/fertilize/gateways/crop_fertilize_gateway.rb`
- [ ] `lib/domain/fertilize/interactors/fertilize_recommend_interactor.rb`
  - [ ] `fertilize_recommend`の戻り値から`fertilizer`名を抽出
  - [ ] 各`fertilizer`名に対して`fertilize_get`で取得して`create`することで`FertilizeEntity`（id付き）を取得
  - [ ] `fertilize_id`として使用して`CropFertilize`を作成
  - [ ] 見つからない場合のエラーハンドリング

**FertilizeRecommendInteractorの実装例**:
```ruby
# lib/domain/fertilize/interactors/fertilize_recommend_interactor.rb
module Domain
  module Fertilize
    module Interactors
      class FertilizeRecommendInteractor
        def initialize(agrr_gateway, fertilize_gateway)
          @agrr_gateway = agrr_gateway
          @fertilize_gateway = fertilize_gateway  # 抽象的なGatewayインターフェース
        end
        
        def call(crop_entity)
          # CropをAGRR CLI形式に変換
          crop_file = create_temp_crop_file(crop_entity)
          
          # AGRR CLIから推奨情報を取得
          result = @agrr_gateway.recommend(crop_file: crop_file)
          
          # 推奨情報から必要なfertilizer名を抽出
          fertilizer_names = result['recommendations'].map { |rec| rec['fertilizer'] }.uniq
          
          # 各fertilizer名に対して、fertilize_getで取得してcreateすることでFertilizeEntityを取得
          # fertilize_getで取得した時に、FertilizeEntity（id付き）として返される
          fertilizer_entities = []
          fertilizer_names.each do |name|
            begin
              detail = @agrr_gateway.get(name: name)
              entity = @fertilize_gateway.create(detail)
              fertilizer_entities << entity
            rescue StandardError => e
              # nameがuniqueなので、既に存在する場合はunique制約違反エラーが発生
              # nameでの検索は想定しないため、スキップする
              Rails.logger.warn "Fertilize '#{name}' creation failed or already exists: #{e.message}"
            end
          end
          
          # 推奨情報を変換（fertilizer名からFertilizeEntityを検索してidを取得）
          recommendations = result['recommendations'].map do |rec|
            # fertilizer_entitiesからnameで検索（配列内検索）
            fertilize_entity = fertilizer_entities.find { |e| e.name == rec['fertilizer'] }
            
            unless fertilize_entity
              Rails.logger.warn "Fertilize '#{rec['fertilizer']}' not found, skipping recommendation"
              next
            end
            
            {
              fertilize_id: fertilize_entity.id,  # ← IDで紐づく
              stage: rec['stage'],
              n: rec['n'],
              p: rec['p'],
              k: rec['k'],
              amount: rec['amount']
            }
          end.compact
          
          Domain::Shared::Result.success({
            crop: result['crop'],
            recommendations: recommendations
          })
        rescue StandardError => e
          Domain::Shared::Result.failure(e.message)
        ensure
          # 一時ファイルの削除
          File.delete(crop_file) if crop_file && File.exist?(crop_file)
        end
        
        def create_temp_crop_file(crop_entity)
          # CropをAGRR CLI形式のJSONファイルに変換
          # (crop_entity.to_agrr_requirementを使用)
          # ...
        end
      end
    end
  end
end
```

#### Model層
- [ ] `app/models/crop_fertilize.rb`
- [ ] `app/models/crop.rb` に `has_many :crop_fertilizes` を追加
- [ ] `app/models/crop_stage.rb` に `has_many :crop_fertilizes` を追加（optional）
- [ ] `app/models/fertilize.rb` に `has_many :crop_fertilizes` を追加

## 🔍 データ同期戦略

### Fertilizeモデルの同期方法

**同期方法**:
- `fertilize_list`呼び出し時に、存在しない肥料を自動的に取得・保存

### CropFertilizeモデルの同期方法

**永続化する**:
- AGRR CLIから取得した推奨情報を永続化

**同期戦略**:
- 初回取得時: AGRR CLIから取得して永続化

## ✅ 最終結論

### 1. Fertilizeモデル: ✅ **必須で実装**

**理由**:
- 肥料は独立したマスタデータとして永続化すべき
- `fertilize_list` / `fertilize_get` から取得可能
- 既存のCropモデルと同様のパターンで実装可能
- 参照データとして`is_reference=true`をデフォルトにする

**実装内容**:
- ActiveRecordモデル（is_referenceパターンを適用）
- Domain層（Entity, Gateway, Interactor）
- Adapter層（FertilizeMemoryGateway, FertilizeActiveRecordGateway）
- AGRR Gateway（既存）を活用

### 2. CropFertilizeモデル: ✅ **実装する**

**理由**:
- `fertilize_recommend`から取得した推奨情報を永続化する
- ユーザーが推奨情報をカスタマイズ・保存できるようにする
- パフォーマンス向上のため

**設計**:
- `stage`は必須属性（'base'=元肥、'topdress'=追肥）
- `fertilize_id`で`Fertilize`モデルと紐づく
- `crop_stage_id`はオプション属性（肥料施用段階と生育段階の関連付け用）
- `fertilize_recommend`で返される`fertilizer`名に対して`fertilize_get`を呼び出し、`FertilizeEntity`（id付き）を取得してから`fertilize_id`として使用

### 3. 実装順序

**Phase 1: Fertilizeモデルの実装**
1. マイグレーション作成（fertilizesテーブル）
2. Fertilizeモデル実装
3. Domain層実装（Entity, Gateway, Interactor）
4. Adapter層実装（FertilizeMemoryGateway, FertilizeActiveRecordGateway）
5. Interactorの実装（AGRR Gatewayと抽象的なFertilizeGatewayを組み合わせ）
6. テスト実装

**Phase 2: CropFertilizeモデルの実装**
1. マイグレーション作成（crop_fertilizesテーブル）
2. CropFertilizeモデル実装
3. Domain層実装（CropFertilizeEntity, Gateway, Interactor）
4. fertilize_recommend Interactor実装
5. テスト実装

## 📝 次のステップ

1. **Phase 1の実装を開始**
   - FertilizeモデルとDomain層の実装
   - AGRR Gatewayとの統合

2. **Phase 2の実装**
   - CropFertilizeモデルを実装
   - fertilize_recommend Interactorの実装
   - AGRR CLIから取得した推奨情報を永続化する処理を実装

