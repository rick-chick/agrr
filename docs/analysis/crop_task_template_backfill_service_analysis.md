# CropTaskTemplateBackfillService の分析

## 機能の重複確認

### PlanSaveService の機能

`PlanSaveService`には、参照計画を保存する際に参照作業のテンプレートをユーザー作物にコピーする機能が既に実装されています。

#### 実装箇所

```ruby
# app/services/plan_save_service.rb

def copy_agricultural_task_crop_relationships(reference_task, new_task)
  reference_task.crop_task_templates.each do |template|
    user_crop_id = user_crop_id_for_reference_crop(template.crop_id)
    next unless user_crop_id

    ensure_crop_task_template!(crop_id: user_crop_id, task: new_task)
  end
end

def ensure_crop_task_template!(crop_id:, task:)
  crop = Crop.find_by(id: crop_id)
  return unless crop

  template = crop.crop_task_templates.find_or_initialize_by(agricultural_task_id: task.id)
  return if template.persisted?

  template.assign_attributes(
    name: task.name,
    description: task.description,
    source_agricultural_task_id: task.source_agricultural_task_id,
    time_per_sqm: task.time_per_sqm,
    weather_dependency: task.weather_dependency,
    required_tools: task.required_tools,
    skill_level: task.skill_level,
    task_type: task.task_type,
    task_type_id: task.task_type_id,
    is_reference: task.is_reference
  )
  template.save!
end
```

**機能**: 参照計画を保存する際に、参照作業の`CropTaskTemplate`をユーザー作物にコピー

### CropTaskTemplateBackfillService の機能

```ruby
# app/services/crop_task_template_backfill_service.rb

def call(crop_ids: nil)
  scope = AgriculturalTaskCrop.includes(:crop, :agricultural_task)
  scope = scope.where(crop_id: Array(crop_ids)) if crop_ids.present?

  scope.find_each do |link|
    crop = link.crop
    task = link.agricultural_task
    next unless crop && task

    template = CropTaskTemplate.find_or_initialize_by(
      crop_id: crop.id,
      source_agricultural_task_id: task.id
    )

    next if template.persisted?

    template.name = task.name
    template.description = task.description
    # ... その他の属性を設定
    template.save!
  end
end
```

**機能**: `AgriculturalTaskCrop`テーブルから情報を取得して、`CropTaskTemplate`を作成

## 機能の違い

### PlanSaveService
- **目的**: 参照計画をユーザー計画にコピーする際に、テンプレートもコピー
- **対象**: 参照計画に含まれる参照作業のテンプレート
- **タイミング**: 計画保存時（ユーザーが参照計画を保存する時）
- **対象作物**: 参照計画に含まれる参照作物に対応するユーザー作物

### CropTaskTemplateBackfillService
- **目的**: `AgriculturalTaskCrop`から`CropTaskTemplate`への移行
- **対象**: `AgriculturalTaskCrop`テーブルに存在する全ての関連付け
- **タイミング**: 移行作業時（一度だけ実行）
- **対象作物**: 指定された作物ID、または全ての作物

## 結論

### 機能の重複について

**重複していません**。両者は異なる目的で使用されます：

1. **PlanSaveService**: 
   - 参照計画を保存する際に、その計画に含まれる参照作業のテンプレートをユーザー作物にコピー
   - 計画保存の一部として実行される
   - 参照計画に含まれる特定の作業のみを対象

2. **CropTaskTemplateBackfillService**:
   - `AgriculturalTaskCrop`テーブルから`CropTaskTemplate`への一括移行
   - 移行作業として一度だけ実行される
   - 全ての既存の関連付けを対象

### ただし、移行完了後は不要

`AgriculturalTaskCrop`テーブルが削除され、移行が完了している場合：

- **CropTaskTemplateBackfillServiceは不要**
  - 移行が完了しているため、このサービスは実行できない（テーブルが存在しない）
  - サービスを削除するか、非推奨としてマークする

- **PlanSaveServiceは継続して必要**
  - 参照計画を保存する際に、テンプレートをコピーする機能は継続して使用される
  - これは計画保存の重要な機能の一部

## 推奨される対応

1. **CropTaskTemplateBackfillServiceを削除**
   - 移行が完了しているため不要
   - `lib/tasks/crop_task_templates.rake`も削除

2. **PlanSaveServiceはそのまま維持**
   - 参照計画保存時のテンプレートコピー機能は継続して必要

3. **テストの対応**
   - `CropTaskTemplateBackfillServiceTest`を削除
   - `CropTaskTemplatesRakeTest`を削除
   - `PlanSaveService`のテストは維持

## まとめ

- **PlanSaveService**: 参照計画保存時のテンプレートコピー機能（継続して必要）
- **CropTaskTemplateBackfillService**: 移行用サービス（移行完了後は不要）

機能は重複していませんが、`CropTaskTemplateBackfillService`は移行完了後は不要です。

