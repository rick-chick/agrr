# マスタモデル一覧

AGRRアプリケーションにおけるマスタデータモデルの一覧です。

## 🔍 マスタモデルの分類

マスタモデルは以下の2つのタイプに分類されます：

### 1. 参照マスタ（is_reference = true）
システムが提供する参照用データ。全てのユーザーが参照可能。

### 2. ユーザー所有マスタ（is_reference = false）
ユーザーが作成した個人的なデータ。

---

## 📊 マスタモデル一覧

### 1. **Crop（作物）** `crops`
- **説明**: 栽培対象となる作物のマスタ
- **テーブル**: `crops`
- **is_referenceデフォルト**: `false`
- **主要属性**:
  - `name`: 作物名（必須）
  - `variety`: 品種名
  - `area_per_unit`: 単位あたりの栽培面積（㎡）
  - `revenue_per_area`: 面積あたりの収益（円/㎡）
  - `groups`: 作物グループ（JSON配列）
  - `region`: 地域
- **関連モデル**:
  - `CropStage`: 生育ステージ
  - `CropPest`: 作物-害虫の関連
- **リソース制限**: ユーザー所有は20件まで
- **モデルファイル**: `app/models/crop.rb`

### 2. **Fertilize（肥料）** `fertilizes`
- **説明**: 肥料のマスタ
- **テーブル**: `fertilizes`
- **is_referenceデフォルト**: `true`
- **主要属性**:
  - `name`: 肥料名（必須、一意）
  - `n`: 窒素含有率（%）
  - `p`: リン含有率（%）
  - `k`: カリ含有率（%）
  - `description`: 説明文
  - `package_size`: 容量（kg）
  - `region`: 地域
- **機能**: Clean Architecture（AI機能）で実装
- **モデルファイル**: `app/models/fertilize.rb`

### 3. **Pest（害虫）** `pests`
- **説明**: 農作物の害虫のマスタ
- **テーブル**: `pests`
- **is_referenceデフォルト**: `false`
- **主要属性**:
  - `name`: 害虫名（必須）
  - `name_scientific`: 学名
  - `family`: 科
  - `order`: 目
  - `description`: 説明
  - `occurrence_season`: 発生時期
  - `region`: 地域
- **関連モデル**:
  - `PestTemperatureProfile`: 温度プロファイル
  - `PestThermalRequirement`: 熱量要件
  - `PestControlMethod`: 防除方法
  - `CropPest`: 作物-害虫の関連
- **モデルファイル**: `app/models/pest.rb`

### 4. **Pesticide（農薬）** `pesticides`
- **説明**: 農薬のマスタ
- **テーブル**: `pesticides`
- **is_referenceデフォルト**: `false`
- **主要属性**:
  - `name`: 農薬名（必須）
  - `active_ingredient`: 有効成分名
  - `description`: 説明文
  - `region`: 地域
- **関連モデル**:
  - `Crop`: 対象作物
  - `Pest`: 対象害虫
  - `PesticideUsageConstraint`: 使用制約
  - `PesticideApplicationDetail`: 施用詳細
- **モデルファイル**: `app/models/pesticide.rb`

### 5. **AgriculturalTask（農業タスク）** `agricultural_tasks`
- **説明**: 農業作業タスクのマスタ
- **テーブル**: `agricultural_tasks`
- **is_referenceデフォルト**: `true`
- **主要属性**:
  - `name`: タスク名（必須、一意）
  - `description`: 説明文
  - `time_per_sqm`: 単位面積あたりの所要時間
  - `weather_dependency`: 天候依存度
  - `required_tools`: 必要な工具（JSON配列）
  - `skill_level`: スキルレベル
  - `region`: 地域
- **モデルファイル**: `app/models/agricultural_task.rb`

### 6. **InteractionRule（相互作用ルール）** `interaction_rules`
- **説明**: 作物間の相互作用（連作・輪作など）のルールマスタ
- **テーブル**: `interaction_rules`
- **is_referenceデフォルト**: `false`
- **主要属性**:
  - `rule_type`: ルールタイプ（continuous_cultivation など）
  - `source_group`: 影響を与える元のグループ名
  - `target_group`: 影響を受ける対象のグループ名
  - `impact_ratio`: 影響係数
  - `is_directional`: 方向性の有無
  - `description`: ルールの説明文
  - `region`: 地域
- **モデルファイル**: `app/models/interaction_rule.rb`

### 7. **Farm（農場）** `farms`
- **説明**: 農場（栽培地域）のマスタ
- **テーブル**: `farms`
- **is_referenceデフォルト**: `false`
- **主要属性**:
  - `name`: 農場名（必須）
  - `latitude`: 緯度
  - `longitude`: 経度
  - `region`: 地域
  - `weather_data_status`: 気象データ取得ステータス
  - `weather_location_id`: 気象データの参照先
- **関連モデル**:
  - `Field`: 圃場
  - `WeatherLocation`: 気象データの場所
- **リソース制限**: ユーザー所有は4件まで
- **モデルファイル**: `app/models/farm.rb`

---

## 📌 補足：関連マスタモデル

以下のモデルは`is_reference`フラグを持ちませんが、マスタデータとして機能します：

### **CropStage（生育ステージ）** `crop_stages`
- **説明**: 作物の生育ステージのマスタ（Cropに紐づく）
- **テーブル**: `crop_stages`
- **is_reference**: なし（親のCropに従う）
- **主要属性**:
  - `name`: ステージ名（必須）
  - `order`: 順序（必須）
- **関連モデル**:
  - `TemperatureRequirement`: 温度要件
  - `ThermalRequirement`: 熱量要件
  - `SunshineRequirement`: 日照要件
  - `NutrientRequirement`: 栄養素要件
- **モデルファイル**: `app/models/crop_stage.rb`

### **WeatherLocation（気象データの場所）** `weather_locations`
- **説明**: 気象データを取得する位置情報のマスタ
- **テーブル**: `weather_locations`
- **is_reference**: なし（緯度経度で一意に特定される）
- **主要属性**:
  - `latitude`: 緯度（必須）
  - `longitude`: 経度（必須）
  - `elevation`: 標高
  - `timezone`: タイムゾーン（必須）
- **関連モデル**:
  - `WeatherDatum`: 気象データ
- **モデルファイル**: `app/models/weather_location.rb`

---

## 🔗 関連マスタモデル

以下のモデルは他のマスタに関連付けられた詳細情報を保持します：

### Pest関連
- **PestTemperatureProfile** (`pest_temperature_profiles`): 害虫の温度プロファイル
- **PestThermalRequirement** (`pest_thermal_requirements`): 害虫の熱量要件
- **PestControlMethod** (`pest_control_methods`): 害虫防除方法

### Pesticide関連
- **PesticideUsageConstraint** (`pesticide_usage_constraints`): 農薬の使用制約
- **PesticideApplicationDetail** (`pesticide_application_details`): 農薬の施用詳細

### CropStage関連
- **TemperatureRequirement** (`temperature_requirements`): 温度要件
- **ThermalRequirement** (`thermal_requirements`): 熱量要件
- **SunshineRequirement** (`sunshine_requirements`): 日照要件
- **NutrientRequirement** (`nutrient_requirements`): 栄養素要件

### 中間テーブル
- **CropPest** (`crop_pests`): 作物-害虫の関連

---

## 📋 特徴的なマスタ

### 1. region属性の有無

#### ✅ region属性があるモデル
以下のマスタは`region`属性を持ち、地域ごとのデータ管理が可能です：

| モデル | テーブル | regionスコープ | 用途 |
|--------|----------|---------------|------|
| **Crop** | `crops` | `by_region(region)` | 地域別の作物データ管理 |
| **Farm** | `farms` | `by_region(region)` | 地域別の農場データ管理 |
| **Field** | `fields` | `by_region(region)` | 地域別の圃場データ管理 |
| **InteractionRule** | `interaction_rules` | `by_region(region)` | 地域別の相互作用ルール管理 |
| **Fertilize** | `fertilizes` | `by_region(region)` | 地域別の肥料データ管理 |
| **Pest** | `pests` | `by_region(region)` | 地域別の害虫データ管理 |
| **Pesticide** | `pesticides` | `by_region(region)` | 地域別の農薬データ管理 |
| **AgriculturalTask** | `agricultural_tasks` | `by_region(region)` | 地域別の農業タスクデータ管理 |

**実装例**:
```ruby
# 日本の参照作物を取得
Crop.reference.by_region('jp')

# アメリカの相互作用ルールを取得
InteractionRule.reference.by_region('us')

# 日本の参照害虫を取得
Pest.reference.by_region('jp')

# 日本の参照肥料を取得
Fertilize.reference.by_region('jp')
```

**マイグレーション履歴**:
- `20251017000000_add_region_to_fields_crops_and_interaction_rules.rb`: Field, Crop, InteractionRuleに追加
- `20251017000001_add_region_to_farms.rb`: Farmに追加
- `20251103112702_add_region_to_pests_pesticides_fertilizes_agricultural_tasks.rb`: Pest, Pesticide, Fertilize, AgriculturalTaskに追加

#### ❌ region属性がないモデル
以下のモデルは地域情報を持たず、グローバルに利用可能です：

| モデル | テーブル | 理由 |
|--------|----------|------|
| **CropStage** | `crop_stages` | 親のCropが地域を持つ |
| **WeatherLocation** | `weather_locations` | 緯度経度で位置を特定 |

### 2. データソース
- **agrr CLI**: Crop, Pest, Pesticideはagrr CLIから取得・更新可能
- **手動入力**: Fertilize, AgriculturalTask, InteractionRuleは手動登録
- **自動生成**: WeatherLocationは自動的に作成される

### 3. リソース制限
- **Crop**: ユーザー所有は20件まで
- **Farm**: ユーザー所有は4件まで
- 参照データ（is_reference = true）は制限対象外

---

## 🔄 参照マスタとユーザー所有マスタの使い分け

### 参照マスタ（is_reference = true）の特徴
- システムが提供する標準データ
- 全ユーザーが参照可能
- 管理者が管理
- user_idはnull

### ユーザー所有マスタ（is_reference = false）の特徴
- ユーザーが作成した個人的なデータ
- 作成したユーザーのみが管理可能
- user_idが設定される
- リソース制限の対象

---

## 📝 備考

- すべてのマスタモデルは`ApplicationRecord`を継承
- `is_reference`フラグを持つマスタは、`scope :reference`と`scope :user_owned`を提供
- agrr CLI連携が可能なマスタは、`to_agrr_output`や`from_agrr_output`メソッドを実装
- マスタデータの管理画面は管理者のみがアクセス可能（参照データの編集・削除）

