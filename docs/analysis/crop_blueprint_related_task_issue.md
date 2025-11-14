# 作物のblueprint図で関連作業が未設定になる問題の分析

## 概要

作物詳細ページのblueprint図で、一部の作業が「関連作業未設定」として表示される場合がある。この問題の原因と、項目間のデータ移送を調査した結果をまとめる。

## 問題の現象

- blueprint図で一部の作業カードに「関連作業未設定」と表示される
- 収穫などの作業は正しく表示される場合がある
- 肥料関連の作業は常に「関連作業未設定」として表示される

## データフロー図

### 1. Blueprint生成の全体フロー

```
┌─────────────────────────────────────────────────────────────────┐
│ CropTaskScheduleBlueprintCreateService#regenerate!              │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 1. crop.crop_task_templates を取得                              │
│    (includes(:agricultural_task))                               │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 2. AGRR Gateway を呼び出し                                       │
│    - schedule_gateway.generate(...)                             │
│    - fertilize_gateway.plan(...)                                │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│ 3. CropTaskScheduleBlueprintGenerator#build_from_responses      │
└─────────────────────────────────────────────────────────────────┘
                              │
                    ┌─────────┴─────────┐
                    │                   │
                    ▼                   ▼
    ┌───────────────────────┐  ┌───────────────────────┐
    │ build_general_blueprint│  │ build_fertilizer_      │
    │ (FIELD_WORK_TYPE)      │  │ blueprint              │
    │                        │  │ (肥料関連)             │
    └───────────────────────┘  └───────────────────────┘
```

### 2. build_general_blueprint のデータ移送（収穫などが表示される場合）

```
AGRR Schedule Response
  └─ task['task_id'] (例: 1234)
      │
      ▼
template_for_task(task_id)
  └─ template_lookup[task_id]
      │
      ├─ CropTaskTemplate
      │   ├─ agricultural_task_id: 5678 (設定されている)
      │   ├─ source_agricultural_task_id: 1234
      │   └─ agricultural_task: AgriculturalTask#5678
      │       └─ name: "収穫"
      │
      ▼
build_general_blueprint の処理:
  ├─ template = template_for_task(1234)  # テンプレートが見つかる
  ├─ agricultural_task = template.agricultural_task  # AgriculturalTask#5678
  └─ {
      agricultural_task_id: 5678,  # ✅ 設定される
      source_agricultural_task_id: 1234,
      ...
    }
      │
      ▼
CropTaskScheduleBlueprint
  ├─ agricultural_task_id: 5678
  ├─ agricultural_task: AgriculturalTask#5678
  └─ name: "収穫"  # ✅ 表示される
```

### 3. build_general_blueprint で関連作業が未設定になる場合

#### ケース1: テンプレートが存在しない

```
AGRR Schedule Response
  └─ task['task_id']: 9999
      │
      ▼
template_for_task(9999)
  └─ template_lookup[9999]
      └─ nil  # ❌ テンプレートが見つからない
      │
      ▼
build_general_blueprint の処理:
  ├─ template = nil
  ├─ agricultural_task = nil
  └─ {
      agricultural_task_id: nil,  # ❌ nilになる
      source_agricultural_task_id: 9999,  # task_idがそのまま設定される
      ...
    }
      │
      ▼
CropTaskScheduleBlueprint
  ├─ agricultural_task_id: nil
  ├─ agricultural_task: nil
  └─ name: "関連作業未設定"  # ❌ 表示される
```

#### ケース2: テンプレートは存在するが、agricultural_taskが設定されていない

```
AGRR Schedule Response
  └─ task['task_id']: 1234
      │
      ▼
template_for_task(1234)
  └─ template_lookup[1234]
      │
      ├─ CropTaskTemplate
      │   ├─ agricultural_task_id: nil  # ❌ 設定されていない
      │   ├─ source_agricultural_task_id: 1234  # ✅ 設定されている
      │   └─ agricultural_task: nil  # ❌ nil
      │
      ▼
build_general_blueprint の処理:
  ├─ template = CropTaskTemplate (存在する)
  ├─ agricultural_task = template.agricultural_task  # nil
  └─ {
      agricultural_task_id: nil,  # ❌ nilになる
      source_agricultural_task_id: 1234,
      ...
    }
      │
      ▼
CropTaskScheduleBlueprint
  ├─ agricultural_task_id: nil
  ├─ agricultural_task: nil
  └─ name: "関連作業未設定"  # ❌ 表示される
```

### 4. build_fertilizer_blueprint のデータ移送（肥料関連は常に未設定）

```
AGRR Fertilize Response
  └─ entry['task_id']: 3400 (例: 基肥)
      │
      ▼
build_fertilizer_blueprint の処理:
  └─ {
      agricultural_task_id: nil,  # ⚠️ 常にnil
      source_agricultural_task_id: 3400,
      task_type: BASAL_FERTILIZATION_TYPE または TOPDRESS_FERTILIZATION_TYPE,
      ...
    }
      │
      ▼
CropTaskScheduleBlueprint
  ├─ agricultural_task_id: nil  # ⚠️ 常にnil
  ├─ agricultural_task: nil
  └─ name: "関連作業未設定"  # ⚠️ 常に表示される
```

## コードの出処

### 1. Blueprint生成のエントリーポイント

```126:137:app/controllers/crops_controller.rb
  def generate_task_schedule_blueprints
    service = CropTaskScheduleBlueprintCreateService.new
    service.regenerate!(crop: @crop)
    redirect_to crop_path(@crop), notice: I18n.t('crops.flash.task_schedule_blueprints_generated')
  rescue CropTaskScheduleBlueprintCreateService::MissingAgriculturalTasksError,
         CropTaskScheduleBlueprintCreateService::GenerationFailedError => e
    redirect_to crop_path(@crop), alert: e.message
  rescue StandardError => e
    Rails.logger.error("❌ [CropsController] Failed to generate blueprints for Crop##{@crop.id}: #{e.class} #{e.message}")
    Rails.logger.error(e.full_message)
    redirect_to crop_path(@crop), alert: I18n.t('crops.flash.task_schedule_blueprints_failed')
  end
```

### 2. Blueprint生成サービス

```16:49:app/services/crop_task_schedule_blueprint_create_service.rb
  def regenerate!(crop:)
    templates = crop.crop_task_templates.includes(:agricultural_task).order(:id)

    if templates.empty?
      raise MissingCropTaskTemplatesError, "作業テンプレート生成には作物の作業テンプレート登録が必要です"
    end

    stage_requirements = crop.to_agrr_requirement.fetch('stage_requirements')
    agricultural_tasks = CropTaskTemplate.to_agrr_format_array(templates)

    schedule_response = schedule_gateway.generate(
      crop_name: crop.name,
      variety: crop.variety || 'general',
      stage_requirements: stage_requirements,
      agricultural_tasks: agricultural_tasks
    )

    fertilize_response = fertilize_gateway.plan(
      crop: crop,
      use_harvest_start: true
    )

    generator = CropTaskScheduleBlueprintGenerator.new(crop: crop, templates: templates)
    blueprints = generator.build_from_responses(
      schedule_response: schedule_response,
      fertilize_response: fertilize_response
    )

    if blueprints.empty?
      raise GenerationFailedError, "AGRRの応答から作業テンプレートを生成できませんでした"
    end

    persist_blueprints!(crop: crop, blueprint_attributes: blueprints)
  end
```

### 3. 一般作業Blueprint生成（収穫などが表示される場合）

```31:53:app/services/crop_task_schedule_blueprint_generator.rb
  def build_general_blueprint(task)
    task_id = integer_value(task['task_id'])
    template = template_for_task(task_id)
    agricultural_task = template&.agricultural_task

    {
      crop_id: crop.id,
      agricultural_task_id: agricultural_task&.id,
      source_agricultural_task_id: template&.source_agricultural_task_id || task_id,
      stage_order: integer_value(task['stage_order']),
      stage_name: task['stage_name'],
      gdd_trigger: decimal_value(task['gdd_trigger']),
      gdd_tolerance: decimal_value(task['gdd_tolerance']),
      task_type: TaskScheduleItem::FIELD_WORK_TYPE,
      source: 'agrr_schedule',
      priority: integer_value(task['priority']),
      description: task['description'] || template&.description,
      amount: nil,
      amount_unit: nil,
      weather_dependency: task['weather_dependency'] || template&.weather_dependency,
      time_per_sqm: decimal_value(task['time_per_sqm']) || template&.time_per_sqm
    }
  end
```

**重要なポイント:**
- `template = template_for_task(task_id)` でテンプレートを取得
- `agricultural_task = template&.agricultural_task` でagricultural_taskを取得
- `agricultural_task_id: agricultural_task&.id` で設定
- **テンプレートが存在しても、そのテンプレートに`agricultural_task`が設定されていない場合、`agricultural_task_id`はnilになる**

### 4. 肥料Blueprint生成（常にagricultural_task_idがnil）

```55:77:app/services/crop_task_schedule_blueprint_generator.rb
  def build_fertilizer_blueprint(entry, index)
    task_type = entry['task_type'] ||
      (index.zero? ? TaskScheduleItem::BASAL_FERTILIZATION_TYPE : TaskScheduleItem::TOPDRESS_FERTILIZATION_TYPE)
    task_id = integer_value(entry['task_id'])

    {
      crop_id: crop.id,
      agricultural_task_id: nil,
      source_agricultural_task_id: task_id,
      stage_order: integer_value(entry['stage_order']),
      stage_name: entry['stage_name'],
      gdd_trigger: decimal_value(entry['gdd_trigger']),
      gdd_tolerance: decimal_value(entry['gdd_tolerance']),
      task_type: task_type,
      source: 'agrr_fertilize_plan',
      priority: integer_value(entry['priority']),
      description: entry['description'],
      amount: decimal_value(entry['amount_g_per_m2']),
      amount_unit: entry['amount_unit'] || (entry['amount_g_per_m2'].present? ? 'g/m2' : nil),
      weather_dependency: entry['weather_dependency'],
      time_per_sqm: decimal_value(entry['time_per_sqm'])
    }
  end
```

**重要なポイント:**
- `agricultural_task_id: nil` と明示的にnilを設定
- `source_agricultural_task_id: task_id` のみ設定
- **肥料関連のblueprintは常に`agricultural_task_id`がnil**

### 5. テンプレート検索ロジック

```79:95:app/services/crop_task_schedule_blueprint_generator.rb
  def template_lookup
    @template_lookup ||= templates.each_with_object({}) do |template, memo|
      keys = []
      keys << template.source_agricultural_task_id if template.source_agricultural_task_id.present?
      keys << template.agricultural_task_id if template.agricultural_task_id.present?
      keys.compact.uniq.each do |key|
        memo[key] = template
        memo[key.to_s] = template
      end
    end
  end

  def template_for_task(task_id)
    return nil if task_id.nil?

    template_lookup[task_id] || template_lookup[task_id.to_s]
  end
```

**重要なポイント:**
- `source_agricultural_task_id`と`agricultural_task_id`の両方をキーとして使用
- テンプレートが見つかっても、そのテンプレートに`agricultural_task`が設定されていない場合がある

### 6. Blueprint表示処理

```164:166:app/views/crops/show.html.erb
                <div class="task-blueprint-card__title">
                  <%= blueprint.agricultural_task&.name || t('.task_schedule_blueprints_missing_task') %>
                </div>
```

**重要なポイント:**
- `blueprint.agricultural_task&.name` で表示
- `agricultural_task`がnilの場合、`t('.task_schedule_blueprints_missing_task')`（「関連作業未設定」）が表示される

## 収穫などが表示される場合との違い

### 表示される場合（収穫など）

1. **CropTaskTemplateが存在する**
   - `source_agricultural_task_id`または`agricultural_task_id`がAGRRの`task_id`と一致
2. **AgriculturalTaskが設定されている**
   - `CropTaskTemplate.agricultural_task`が存在する
3. **Blueprint生成時に設定される**
   - `build_general_blueprint`で`agricultural_task_id`が設定される
4. **表示時に名前が取得できる**
   - `blueprint.agricultural_task.name`で名前が表示される

### 未設定になる場合

#### ケース1: テンプレートが存在しない
- AGRRの`task_id`に対応する`CropTaskTemplate`が存在しない
- `template_for_task(task_id)`がnilを返す
- `agricultural_task_id`がnilになる

#### ケース2: テンプレートは存在するが、agricultural_taskが設定されていない
- `CropTaskTemplate`は存在するが、`agricultural_task_id`がnil
- `source_agricultural_task_id`のみ設定されている
- `template.agricultural_task`がnilを返す
- `agricultural_task_id`がnilになる

#### ケース3: 肥料関連（常に未設定）
- `build_fertilizer_blueprint`で常に`agricultural_task_id: nil`を設定
- 設計上、肥料関連は`agricultural_task`を持たない

## 解決策の検討

### 1. テンプレートが存在しない場合
- ユーザーが「利用可能な作業テンプレート」から該当する作業を選択する必要がある
- または、AGRRの`task_id`に対応する`AgriculturalTask`を自動的に検索して設定する

### 2. テンプレートは存在するが、agricultural_taskが設定されていない場合
- `CropTaskTemplate`に`agricultural_task`を設定する必要がある
- `source_agricultural_task_id`から`AgriculturalTask`を検索して設定する

### 3. 肥料関連の場合
- 設計上、肥料関連は`agricultural_task`を持たないため、別の表示方法を検討する必要がある
- 例: `source_agricultural_task_id`から`AgriculturalTask`を検索して表示する
- または、肥料専用の表示名を設定する

## CropTaskTemplateが存在するが、AgriculturalTaskが存在しないケースについて

### 理論的な考察

`CropTaskTemplate`は`Crop`と`AgriculturalTask`の関連マスタなので、理論的には：
- `CropTaskTemplate`が存在する = `agricultural_task_id`が設定されている
- しかし、実際のコードでは`agricultural_task_id`がnilでも良い設計になっている

### 実際のコード設計

#### 1. マイグレーションファイル

```3:7:db/migrate/20251111091500_add_agricultural_task_to_crop_task_templates.rb
    add_reference :crop_task_templates, :agricultural_task, foreign_key: true
    add_index :crop_task_templates,
              [:crop_id, :agricultural_task_id],
              unique: true,
              name: "idx_crop_task_templates_on_crop_and_agricultural_task"
```

- 外部キー制約が設定されている（`foreign_key: true`）
- しかし、`null: false`が明示的に指定されていない
- Railsのデフォルトでは、`add_reference`は`null: true`になる

#### 2. モデルの定義

```4:5:app/models/crop_task_template.rb
  belongs_to :crop
  belongs_to :agricultural_task, optional: true
```

- `optional: true`により、`agricultural_task_id`がnilでも良い設計

```26:27:app/models/agricultural_task.rb
  has_many :crop_task_templates, dependent: :destroy
  has_many :crops, through: :crop_task_templates
```

- `dependent: :destroy`により、`AgriculturalTask`が削除されると、関連する`CropTaskTemplate`も削除される

#### 3. 実際の作成処理

すべての`CropTaskTemplate`の作成箇所を確認した結果：

1. **`crops_controller.rb#toggle_task_template`**
   ```162:170:app/controllers/crops_controller.rb
      @crop.crop_task_templates.create!(
        agricultural_task: agricultural_task,
        name: agricultural_task.name,
        description: agricultural_task.description,
        time_per_sqm: agricultural_task.time_per_sqm,
        weather_dependency: agricultural_task.weather_dependency,
        required_tools: agricultural_task.required_tools,
        skill_level: agricultural_task.skill_level
      )
   ```
   - `agricultural_task`を指定して作成

2. **`crops/agricultural_tasks_controller.rb#create`**
   ```42:54:app/controllers/crops/agricultural_tasks_controller.rb
          template = @crop.crop_task_templates.create!(
            agricultural_task: existing_task,
            source_agricultural_task_id: existing_task.source_agricultural_task_id,
            name: existing_task.name,
            description: existing_task.description,
            time_per_sqm: existing_task.time_per_sqm,
            weather_dependency: existing_task.weather_dependency,
            required_tools: existing_task.required_tools,
            skill_level: existing_task.skill_level,
            task_type: existing_task.task_type,
            task_type_id: existing_task.task_type_id,
            is_reference: existing_task.is_reference
          )
   ```
   - `agricultural_task`を指定して作成

3. **`agricultural_tasks_controller.rb#update`**
   ```90:98:app/controllers/agricultural_tasks_controller.rb
          crop.crop_task_templates.create!(
            agricultural_task: @agricultural_task,
            name: @agricultural_task.name,
            description: @agricultural_task.description,
            time_per_sqm: @agricultural_task.time_per_sqm,
            weather_dependency: @agricultural_task.weather_dependency,
            required_tools: @agricultural_task.required_tools,
            skill_level: @agricultural_task.skill_level
          )
   ```
   - `agricultural_task`を指定して作成

### 結論

**`CropTaskTemplate`が存在するが、`AgriculturalTask`が存在しないという状況は、理論的には考えにくい：**

1. **外部キー制約により防止される**
   - `agricultural_task_id`が存在するが、その`AgriculturalTask`が存在しないという状況は、外部キー制約により防止される

2. **`dependent: :destroy`により削除される**
   - `AgriculturalTask`が削除されると、関連する`CropTaskTemplate`も削除される
   - したがって、`CropTaskTemplate`が存在するが、`AgriculturalTask`が存在しないという状況は発生しない

3. **`agricultural_task_id`がnilで作成される可能性**
   - すべての作成箇所で`agricultural_task`を指定しているため、通常は`agricultural_task_id`がnilで作成されることはない
   - しかし、設計上は`optional: true`により、`agricultural_task_id`がnilでも良い
   - この場合、`CropTaskTemplate`は存在するが、`agricultural_task`がnilになる

### 実際に発生する可能性があるケース

1. **`agricultural_task_id`がnilで作成された場合**
   - 現在のコードでは、すべての作成箇所で`agricultural_task`を指定しているため、通常は発生しない
   - しかし、将来的に`agricultural_task_id`をnilで作成する処理が追加された場合、発生する可能性がある

2. **データ移行時の不整合**
   - 過去のデータ移行時に、`agricultural_task_id`がnilで作成されたレコードが存在する可能性がある

3. **外部キー制約が緩い場合**
   - マイグレーションファイルで`foreign_key: true`が設定されているが、実際のデータベースで外部キー制約が正しく設定されていない場合、不整合が発生する可能性がある

## まとめ

- **関連作業が未設定になる主な原因:**
  1. `CropTaskTemplate`が存在しない（AGRRの`task_id`に対応するテンプレートがない）
  2. `CropTaskTemplate`は存在するが、`agricultural_task_id`がnil（設計上は可能だが、現在のコードでは通常発生しない）
  3. 肥料関連は設計上、常に`agricultural_task_id`がnil

- **収穫などが表示される場合との違い:**
  - 収穫などは`CropTaskTemplate`に`agricultural_task`が設定されている
  - 肥料関連は設計上、`agricultural_task_id`が常にnil

- **データ移送の流れ:**
  - `CropTaskTemplate` → `CropTaskScheduleBlueprintGenerator` → `CropTaskScheduleBlueprint`
  - `agricultural_task_id`は`CropTaskTemplate.agricultural_task.id`から設定される
  - `agricultural_task`がnilの場合、`agricultural_task_id`もnilになる

- **`CropTaskTemplate`が存在するが、`AgriculturalTask`が存在しないケース:**
  - 理論的には考えにくい（外部キー制約と`dependent: :destroy`により防止される）
  - しかし、`agricultural_task_id`がnilで作成された場合、`CropTaskTemplate`は存在するが、`agricultural_task`がnilになる可能性がある
  - 現在のコードでは、すべての作成箇所で`agricultural_task`を指定しているため、通常は発生しない

