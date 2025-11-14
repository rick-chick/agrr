# CropTaskTemplate の利用方法

## 概要
`CropTaskTemplate`は、作物（Crop）と農業タスク（AgriculturalTask）の関連付けを管理する中間テーブルです。`AgriculturalTaskCrop`の後継として、作物ごとにカスタマイズされた作業テンプレート情報を保持します。

## モデル定義

### CropTaskTemplate モデル
```ruby
# app/models/crop_task_template.rb
class CropTaskTemplate < ApplicationRecord
  belongs_to :crop
  belongs_to :agricultural_task, optional: true
  
  # 属性:
  # - name: テンプレート名（必須）
  # - description: 説明
  # - time_per_sqm: 単位面積あたりの所要時間
  # - weather_dependency: 天候依存度
  # - required_tools: 必要な工具（JSON配列）
  # - skill_level: スキルレベル
  # - agricultural_task_id: 元のAgriculturalTaskへの参照
  # - source_agricultural_task_id: 元のAgriculturalTaskのID（参照用）
  # - crop_id: 関連するCrop
end
```

### 関連付け
```ruby
# Crop モデル
has_many :crop_task_templates, dependent: :destroy
has_many :agricultural_tasks, through: :crop_task_templates

# AgriculturalTask モデル
has_many :crop_task_templates, dependent: :destroy
has_many :crops, through: :crop_task_templates
```

## 主要な利用箇所

### 1. コントローラーでの利用

#### CropsController
**用途**: 作物詳細画面で、作物に関連付けられた作業テンプレートを表示・管理

```ruby
# app/controllers/crops_controller.rb

# 作物詳細画面（show）
def show
  # 既にテンプレートとして登録されているタスクIDを取得
  template_task_ids = @crop.crop_task_templates.pluck(:agricultural_task_id).compact
  template_source_ids = @crop.crop_task_templates.pluck(:source_agricultural_task_id).compact
  @selected_task_ids = (template_task_ids + template_source_ids).uniq
end

# テンプレートの追加・削除（toggle_task_template）
def toggle_task_template
  agricultural_task = AgriculturalTask.find(params[:agricultural_task_id])
  
  existing_template = @crop.crop_task_templates.where(
    agricultural_task: agricultural_task
  ).or(
    @crop.crop_task_templates.where(source_agricultural_task_id: agricultural_task.id)
  ).first
  
  if existing_template
    existing_template.destroy  # 削除
  else
    @crop.crop_task_templates.create!(...)  # 作成
  end
end
```

#### Crops::AgriculturalTasksController
**用途**: 作物に紐づく作業テンプレートの一覧表示・編集・削除

```ruby
# app/controllers/crops/agricultural_tasks_controller.rb

def index
  @templates = @crop.crop_task_templates.includes(:agricultural_task).order(:name)
end

def create
  # 既存の作業を選択してテンプレートを作成
  template = @crop.crop_task_templates.create!(
    agricultural_task: existing_task,
    name: existing_task.name,
    description: existing_task.description,
    # ... その他の属性
  )
end
```

#### AgriculturalTasksController
**用途**: 作業編集画面で、作業に関連付けられた作物を管理

```ruby
# app/controllers/agricultural_tasks_controller.rb

def update
  # 作業と作物の紐付けをCropTaskTemplateで更新
  current_template_crop_ids = CropTaskTemplate.where(agricultural_task: @agricultural_task).pluck(:crop_id)
  
  # 追加する作物
  crops_to_add.each do |crop_id|
    crop = Crop.find(crop_id)
    unless CropTaskTemplate.exists?(crop: crop, agricultural_task: @agricultural_task)
      crop.crop_task_templates.create!(
        agricultural_task: @agricultural_task,
        name: @agricultural_task.name,
        # ... その他の属性
      )
    end
  end
  
  # 削除する作物
  crops_to_remove.each do |crop_id|
    template = CropTaskTemplate.find_by(crop: crop, agricultural_task: @agricultural_task)
    template&.destroy
  end
end

def prepare_crop_cards
  # CropTaskTemplateから選択済み作物を取得
  selected_ids ||= CropTaskTemplate.where(agricultural_task: @agricultural_task).pluck(:crop_id)
end
```

#### Plans::TaskScheduleItemsController
**用途**: 作業予定の作成時に、テンプレートから情報を取得

```ruby
# app/controllers/plans/task_schedule_items_controller.rb

def create
  template = find_task_template(attrs[:crop_task_template_id])
  if template
    build_create_attributes(attrs.except(:crop_task_template_id), template: template)
  end
end

private

def find_task_template(template_id)
  return nil unless template_id.present?
  CropTaskTemplate.includes(:agricultural_task, :crop).find(template_id)
end
```

### 2. サービスでの利用

#### CropTaskScheduleBlueprintCreateService
**用途**: 作物の作業スケジュールブループリントを生成する際に、テンプレートから作業情報を取得

```ruby
# app/services/crop_task_schedule_blueprint_create_service.rb

def regenerate!(crop:)
  templates = crop.crop_task_templates.includes(:agricultural_task).order(:id)
  
  if templates.empty?
    raise MissingCropTaskTemplatesError, "作業テンプレート生成には作物の作業テンプレート登録が必要です"
  end
  
  # agrr CLI形式に変換
  agricultural_tasks = CropTaskTemplate.to_agrr_format_array(templates)
  # ...
end
```

#### TaskScheduleGeneratorService
**用途**: 作業スケジュールを生成する際に、テンプレートから作業情報を取得

```ruby
# app/services/task_schedule_generator_service.rb

crop.crop_task_templates.includes(:agricultural_task).each do |template|
  # テンプレートから作業情報を取得してスケジュールを生成
end
```

#### PlanSaveService
**用途**: 参照計画を保存する際に、参照作業のテンプレートをコピー

```ruby
# app/services/plan_save_service.rb

def copy_reference_agricultural_tasks
  reference_task.crop_task_templates.each do |template|
    # ユーザー作物に対してテンプレートを作成
    ensure_crop_task_template!(crop_id: user_crop_id, task: new_task)
  end
end

def ensure_crop_task_template!(crop_id:, task:)
  crop = Crop.find(crop_id)
  template = crop.crop_task_templates.find_or_initialize_by(agricultural_task_id: task.id)
  # ...
end
```

### 3. プレゼンターでの利用

#### TaskScheduleTimelinePresenter
**用途**: タイムライン表示用に、作物のテンプレート情報を取得

```ruby
# app/presenters/task_schedule_timeline_presenter.rb

crop.crop_task_templates
# ...
{ crop_task_templates: :agricultural_task }
```

### 4. JavaScript/Frontendでの利用

#### task_schedule_timeline_controller.js
**用途**: フロントエンドで作業予定を作成する際に、テンプレートIDを送信

```javascript
// app/javascript/controllers/task_schedule_timeline_controller.js

const hiddenTemplateId = form.querySelector('input[name="crop_task_template_id"]')
// ...
payload.task_schedule_item.crop_task_template_id = templateId
```

### 5. ビューでの利用

#### crops/show.html.erb
**用途**: 作物詳細画面で、利用可能な作業と選択済み作業を表示

```erb
<!-- 既にテンプレートとして登録されているタスクを表示 -->
<% @selected_task_ids.each do |task_id| %>
  <!-- 選択済みマークを表示 -->
<% end %>
```

## データフロー

### 1. テンプレート作成フロー
```
AgriculturalTask (作業)
    ↓ (ユーザーが作物に紐付け)
CropTaskTemplate (テンプレート作成)
    ↓ (作物に保存)
Crop.crop_task_templates
```

### 2. 作業予定作成フロー
```
CropTaskTemplate (テンプレート)
    ↓ (ユーザーが作業予定を作成)
TaskScheduleItem (作業予定)
    - crop_task_template_id でテンプレートを参照
```

### 3. ブループリント生成フロー
```
Crop.crop_task_templates
    ↓ (CropTaskScheduleBlueprintCreateService)
CropTaskTemplate.to_agrr_format_array
    ↓ (agrr CLI形式に変換)
CropTaskScheduleBlueprint (ブループリント)
```

## 主な機能

### 1. 作物と作業の関連付け管理
- 作物ごとに利用可能な作業を定義
- 作業ごとに適用可能な作物を定義

### 2. 作業テンプレートのカスタマイズ
- 元の`AgriculturalTask`の情報をコピー
- 作物ごとにカスタマイズ可能（将来的な拡張）

### 3. 作業予定の作成
- テンプレートから作業予定を作成
- テンプレートIDで元の情報を参照

### 4. ブループリント生成
- 作物のテンプレートから作業スケジュールブループリントを生成
- agrr CLI形式に変換して最適化に使用

## AgriculturalTaskCrop からの移行

### 変更点
- **旧**: `AgriculturalTaskCrop` - 単純な中間テーブル（関連付けのみ）
- **新**: `CropTaskTemplate` - テンプレート情報を保持（名前、説明、時間など）

### 利点
1. 作物ごとに作業情報をカスタマイズ可能
2. 元の`AgriculturalTask`を削除しても、テンプレート情報は保持
3. `source_agricultural_task_id`で元の作業を追跡可能
4. 作業予定作成時にテンプレート情報を直接参照可能

## まとめ

`CropTaskTemplate`は以下の主要な役割を担っています：

1. **関連付け管理**: 作物と作業の多対多の関連付け
2. **テンプレート情報の保持**: 作業情報のスナップショット
3. **作業予定の作成**: テンプレートから作業予定を生成
4. **ブループリント生成**: 作物の作業スケジュールを生成
5. **参照計画のコピー**: 参照計画からユーザー計画へのコピー

システム全体で重要な役割を果たしており、`AgriculturalTaskCrop`の後継として、より柔軟で拡張性の高い設計になっています。

