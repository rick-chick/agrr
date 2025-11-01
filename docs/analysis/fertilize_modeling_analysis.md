# Fertilizeモデル化の詳細検討

## 📊 現状分析

### AGRR CLIから取得できる情報

#### 1. fertilize_list（肥料一覧）
```ruby
# パラメータ: language, limit, area（オプション）
# 戻り値: 肥料の配列
[
  { 'name' => '尿素', 'n' => 46 },
  { 'name' => 'リン酸一安', 'n' => 16, 'p' => 20 },
  { 'name' => '硫安', 'n' => 21 },
  { 'name' => '過リン酸石灰', 'p' => 20 },
  { 'name' => '塩化カリ', 'k' => 60 }
]
# areaが指定された場合: recommended_amountが追加される
[
  { 'name' => '尿素', 'n' => 46, 'recommended_amount' => 200 }
]
```

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

#### 3. fertilize_recommend（肥料推奨）
```ruby
# パラメータ: crop_file（JSONファイル）
# 戻り値: 作物と肥料施用段階ごとの推奨情報
{
  'crop' => 'tomato',
  'recommendations' => [
    {
      'stage' => 'base',  # 元肥（基肥）
      'n' => 15,
      'p' => 10,
      'k' => 12,
      'fertilizer' => '配合肥料',
      'amount' => 100
    },
    {
      'stage' => '追肥',  # 追肥
      'n' => 10,
      'p' => 5,
      'k' => 8,
      'fertilizer' => '尿素',
      'amount' => 50
    }
  ]
}
```

**重要**: `stage`は必須で、以下が定義されています：
- `'base'`: 元肥（基肥）- 定植前に施す肥料
- `'追肥'`: 追肥 - 生育期間中に追加で施す肥料

### 既存のモデルパターンとの比較

#### Crop ↔ CropStage の関係
- `Crop`: 独立したエンティティ（作物マスタ）
- `CropStage`: `Crop`に属する子エンティティ（生育段階）
- 関係: `has_many :crop_stages`

#### Fertilizeの状況
- `Fertilize`: 独立したエンティティ（肥料マスタ）✅ 必要
- `CropFertilize`: 関係エンティティ（作物×肥料×生育段階）❓ 要検討

## 🎯 モデル化の方針

### 1. Fertilize モデル（肥料マスタ）

**役割**: 肥料の基本情報を保持する参照データ

**属性**:
- `name` (string): 肥料名（一意、必須）
- `n` (float): 窒素含有率（%）
- `p` (float): リン含有率（%）
- `k` (float): カリ含有率（%）
- `description` (text): 説明文
- `package_size` (string): 容量（例: "20kg"）
- `is_reference` (boolean): 参照肥料フラグ（将来の拡張用、デフォルト: true）
- `created_at`, `updated_at`

**データソース**: `fertilize_list` / `fertilize_get` から取得

**永続化**: ✅ **必要**
- 理由: 肥料は独立したマスタデータとして永続化すべき
- 参照頻度: 高（一覧表示、詳細表示）
- 更新頻度: 低（マスタデータ）

**関連**: 
- `has_many :crop_fertilizes`（将来の拡張用）

### 2. CropFertilize モデル（作物×肥料×肥料施用段階）

**役割**: 作物と肥料施用段階ごとの肥料推奨情報

**重要な認識**: 
- `fertilize_recommend`の`stage`は、**肥料施用の段階**を表す（'base'=元肥、'追肥'など）
- 既存の`CropStage`（生育段階）とは**異なる概念**
  - `CropStage`: 作物の成長段階（"播種〜発芽"、"発芽〜成長"など）
  - `fertilize_recommend`の`stage`: 肥料を施すタイミング（"base"=元肥、"追肥"など）

**属性の検討**:

#### オプションA: 永続化しない（動的生成のみ）
- `fertilize_recommend`の結果をそのまま返す
- 毎回AGRR CLIから生成
- **メリット**: データ整合性、最新情報の保証
- **デメリット**: パフォーマンス（毎回AGRR CLI呼び出し）、ユーザーが保存した推奨情報を保持できない

#### オプションB: 永続化する（推奨情報を保存）
以下の属性が必要:

```ruby
# 必須属性
- crop_id (integer): 作物ID（外部キー）
- stage (string): 肥料施用段階（必須）- 'base'（元肥）、'追肥'など
- fertilize_id (integer): 肥料ID（外部キー）
- n (float): 推奨窒素量
- p (float): 推奨リン量
- k (float): 推奨カリ量
- amount (float): 推奨肥料量（gまたはkg）

# 追加検討属性
- crop_stage_id (integer): 生育段階ID（外部キー、オプション）
  # 注: 肥料施用段階と生育段階は異なる概念だが、
  # 特定の生育段階で推奨される肥料施用を関連付ける場合に使用
- is_reference (boolean): 参照推奨情報フラグ
- user_id (integer): ユーザーID（カスタム推奨情報の場合、オプション）
- source (string): データソース（'agrr', 'manual', etc.）
- created_at, updated_at
```

**stageの扱い**:
- `stage`は文字列として保存（'base', '追肥'など）
- `crop_stage_id`はオプション（肥料施用段階と生育段階の関連付けが必要な場合のみ）

**データソース**: `fertilize_recommend` から取得

**永続化**: ⚠️ **条件付きで推奨**
- 理由: 
  - ✅ ユーザーが推奨情報を保存・参照したい場合がある
  - ✅ パフォーマンス向上（AGRR CLI呼び出しを減らす）
  - ✅ 履歴管理（推奨情報の変更履歴を追跡）
  - ❌ ただし、AGRR CLIが最新の推奨情報を返す可能性があるため、整合性の課題あり

**推奨設計**: 
- **初期実装**: 永続化しない（オプションA）
  - 理由: シンプル、データ整合性が保証される
- **将来の拡張**: 永続化に対応（オプションB）
  - ユーザーが推奨情報をカスタマイズ・保存したい場合
  - パフォーマンス最適化が必要な場合

## 🏗️ モデル設計

### Phase 1: Fertilizeモデルのみ実装（推奨）

#### 1. ActiveRecordモデル
```ruby
# app/models/fertilize.rb
class Fertilize < ApplicationRecord
  validates :name, presence: true, uniqueness: true
  validates :n, numericality: { greater_than_or_equal_to: 0, allow_nil: true }
  validates :p, numericality: { greater_than_or_equal_to: 0, allow_nil: true }
  validates :k, numericality: { greater_than_or_equal_to: 0, allow_nil: true }
  
  scope :reference, -> { where(is_reference: true) }
end
```

#### 2. Domain層（Clean Architecture）

##### Entity
```ruby
# lib/domain/fertilize/entities/fertilize_entity.rb
module Domain
  module Fertilize
    module Entities
      class FertilizeEntity
        attr_reader :id, :name, :n, :p, :k, :description, :usage, :application_rate, :is_reference
        
        def initialize(attributes)
          # ... validation ...
        end
      end
    end
  end
end
```

##### Gateway
```ruby
# lib/domain/fertilize/gateways/fertilize_gateway.rb
module Domain
  module Fertilize
    module Gateways
      class FertilizeGateway
        def find_by_id(id)
          raise NotImplementedError
        end
        
        def find_by_name(name)
          raise NotImplementedError
        end
        
        def find_all(language:, limit: 5, area: nil)
          raise NotImplementedError
        end
        
        def create(fertilize_data)
          raise NotImplementedError
        end
        
        def update(id, fertilize_data)
          raise NotImplementedError
        end
      end
    end
  end
end
```

##### Interactors
- `FertilizeListInteractor`: fertilize_listを実行
- `FertilizeGetInteractor`: fertilize_getを実行
- `FertilizeCreateInteractor`: 肥料マスタの作成
- `FertilizeUpdateInteractor`: 肥料マスタの更新

##### Adapter
```ruby
# lib/adapters/fertilize/gateways/fertilize_memory_gateway.rb
# ActiveRecordを使用した実装
```

##### AGRR Gateway
```ruby
# app/gateways/agrr/fertilize_gateway.rb（既存）
# AGRR CLIを呼び出す実装
```

### Phase 2: CropFertilizeモデルの追加（将来の拡張）

#### 1. ActiveRecordモデル
```ruby
# app/models/crop_fertilize.rb
class CropFertilize < ApplicationRecord
  belongs_to :crop
  belongs_to :fertilize
  belongs_to :crop_stage, optional: true  # オプション（肥料施用段階と生育段階の関連付け用）
  
  validates :stage, presence: true  # 必須: 'base'（元肥）、'追肥'など
  validates :n, numericality: { greater_than_or_equal_to: 0, allow_nil: true }
  validates :p, numericality: { greater_than_or_equal_to: 0, allow_nil: true }
  validates :k, numericality: { greater_than_or_equal_to: 0, allow_nil: true }
  validates :amount, numericality: { greater_than: 0, allow_nil: true }
  
  # ユニーク制約: crop + stage + fertilize の組み合わせ
  validates :crop_id, uniqueness: { 
    scope: [:stage, :fertilize_id],
    message: "この作物・肥料施用段階・肥料の組み合わせは既に登録されています"
  }
  
  # stageの値を定義（将来の拡張用）
  STAGE_BASE = 'base'  # 元肥（基肥）
  STAGE_TOP_DRESSING = '追肥'  # 追肥
end
```

## 📋 実装チェックリスト

### Phase 1: Fertilizeモデルのみ

#### Database
- [ ] `fertilizes` テーブルのマイグレーション作成
  - [ ] name (string, unique, not null)
  - [ ] n, p, k (float, nullable)
  - [ ] description, usage, application_rate (text, nullable)
  - [ ] is_reference (boolean, default: true)
  - [ ] created_at, updated_at

#### Domain層
- [ ] `lib/domain/fertilize/entities/fertilize_entity.rb`
- [ ] `lib/domain/fertilize/gateways/fertilize_gateway.rb`
- [ ] `lib/domain/fertilize/interactors/fertilize_list_interactor.rb`
- [ ] `lib/domain/fertilize/interactors/fertilize_get_interactor.rb`
- [ ] `lib/domain/fertilize/interactors/fertilize_create_interactor.rb`
- [ ] `lib/domain/fertilize/interactors/fertilize_update_interactor.rb`

#### Adapter層
- [ ] `lib/adapters/fertilize/gateways/fertilize_memory_gateway.rb`

#### Model層
- [ ] `app/models/fertilize.rb`

#### Gateway層（既存）
- [x] `app/gateways/agrr/fertilize_gateway.rb`（既存）

#### テスト
- [ ] `test/models/fertilize_test.rb`
- [ ] `test/domain/fertilize/entities/fertilize_entity_test.rb`
- [ ] `test/domain/fertilize/interactors/fertilize_list_interactor_test.rb`
- [ ] `test/domain/fertilize/interactors/fertilize_get_interactor_test.rb`
- [ ] `test/adapters/fertilize/gateways/fertilize_memory_gateway_test.rb`

### Phase 2: CropFertilizeモデル（将来の拡張）

#### Database
- [ ] `crop_fertilizes` テーブルのマイグレーション作成

#### Domain層
- [ ] `lib/domain/fertilize/entities/crop_fertilize_entity.rb`
- [ ] `lib/domain/fertilize/gateways/crop_fertilize_gateway.rb`
- [ ] `lib/domain/fertilize/interactors/fertilize_recommend_interactor.rb`

#### Model層
- [ ] `app/models/crop_fertilize.rb`
- [ ] `app/models/crop.rb` に `has_many :crop_fertilizes` を追加
- [ ] `app/models/crop_stage.rb` に `has_many :crop_fertilizes` を追加
- [ ] `app/models/fertilize.rb` に `has_many :crop_fertilizes` を追加

## 🔍 重要な検討事項

### 1. fertilize_recommendの扱い

**現状**: AGRR CLIから動的に生成される

**課題**: 
- 推奨情報を永続化するか？
- ユーザーが推奨情報をカスタマイズできるか？

**推奨**: 
- **Phase 1**: 永続化しない（動的生成のみ）
  - シンプル、データ整合性が保証される
- **Phase 2**: 永続化に対応（ユーザー要望に応じて）
  - ユーザーがカスタマイズ・保存したい場合に実装

### 2. CropFertilizeとCropStageの関係（重要）

**重要な認識**: 
- `fertilize_recommend`の`stage`は**肥料施用の段階**（'base'=元肥、'追肥'など）
- 既存の`CropStage`は**作物の生育段階**（"播種〜発芽"、"発芽〜成長"など）
- **これらは異なる概念**

**検討**:
- `fertilize_recommend`の`stage`: 'base'（元肥）、'追肥'など
- 既存の`CropStage.name`: "播種〜発芽"、"発芽〜成長"、"育苗期"、"定植期"など
- これらは直接対応しない

**推奨**: 
- `CropFertilize`は`stage`（string）を必須属性として持つ
- `crop_stage_id`はオプション属性として持つ
  - 特定の生育段階で推奨される肥料施用を関連付ける場合に使用
  - 例: "定植期"（CropStage）で元肥（base）を推奨する場合

### 3. データ同期

**課題**: AGRR CLIが更新された場合、ローカルのFertilizeマスタと同期が必要

**推奨**:
- 定期同期ジョブの実装（将来の拡張）
- または、常にAGRR CLIから取得（Phase 1の方針）

## ✅ 結論

1. **Fertilizeモデル**: ✅ **必須で実装**
   - 肥料マスタとして永続化
   - `fertilize_list` / `fertilize_get` から取得

2. **CropFertilizeモデル**: ⚠️ **Phase 1では不要、Phase 2で検討**
   - `fertilize_recommend`は動的生成として扱う
   - ユーザー要望に応じて永続化を検討
   - **重要**: `stage`は必須属性（'base'=元肥、'追肥'など）
   - **注意**: `stage`は肥料施用段階であり、`CropStage`（生育段階）とは異なる概念

3. **実装順序**:
   - **Phase 1**: Fertilizeモデルのみ実装（推奨）
   - **Phase 2**: CropFertilizeモデルの追加（将来の拡張）
     - `stage`を必須属性として実装
     - `crop_stage_id`はオプション属性として実装

## 📝 次のステップ

1. Phase 1の実装を開始
2. ユーザー要望を確認（CropFertilizeの永続化が必要か？）
3. Phase 2の実装を検討

