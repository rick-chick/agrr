# スキップしたテストのソース修正ガイド

## 1. CropTaskTemplateBackfillService の修正

### 現在の問題
`app/services/crop_task_template_backfill_service.rb`が`AgriculturalTaskCrop`テーブルを使用している

### 修正方法

#### オプション1: サービスを削除（推奨）
移行が既に完了しているため、サービス自体が不要です。

```ruby
# app/services/crop_task_template_backfill_service.rb を削除
# lib/tasks/crop_task_templates.rake も削除または非推奨化
```

#### オプション2: サービスを修正してCropTaskTemplateを直接操作
既存の`CropTaskTemplate`から情報を取得するように変更：

```ruby
# app/services/crop_task_template_backfill_service.rb
# 呼び出し側でロガーを注入する（例: CompositionRoot.logger またはテストダブル）
class CropTaskTemplateBackfillService
  def initialize(logger:)
    @logger = logger
  end

  def call(crop_ids: nil)
    # AgriculturalTaskCropの代わりに、AgriculturalTaskとCropの関連を直接確認
    # 既にCropTaskTemplateが存在する場合はスキップ
    scope = AgriculturalTask.includes(:crops)
    scope = scope.joins(:crops).where(crops: { id: Array(crop_ids) }) if crop_ids.present?

    scope.find_each do |task|
      task.crops.each do |crop|
        next if crop_ids.present? && !Array(crop_ids).include?(crop.id)
        
        template = CropTaskTemplate.find_or_initialize_by(
          crop_id: crop.id,
          source_agricultural_task_id: task.id
        )

        next if template.persisted?

        template.name = task.name
        template.description = task.description
        template.time_per_sqm = task.time_per_sqm
        template.weather_dependency = task.weather_dependency
        template.required_tools = normalized_required_tools(task.required_tools)
        template.skill_level = task.skill_level
        template.agricultural_task = task
        template.task_type = task.task_type
        template.task_type_id = task.task_type_id
        template.is_reference = task.is_reference

        template.save!
      end
    rescue ActiveRecord::RecordInvalid => e
      logger.error("❌ CropTaskTemplateBackfillService failed: #{e.message}")
      raise
    end
  end

  private

  attr_reader :logger

  def normalized_required_tools(value)
    case value
    when Array
      value
    when String
      begin
        parsed = JSON.parse(value)
        parsed.is_a?(Array) ? parsed : []
      rescue JSON::ParserError
        value.split(/\r?\n|,/).map(&:strip).reject(&:blank?)
      end
    else
      []
    end
  end
end
```

**注意**: この方法は`AgriculturalTask`と`Crop`の関連が`CropTaskTemplate`を通じてのみ存在するため、実質的には既に全ての関連が`CropTaskTemplate`として存在しているはずです。そのため、オプション1（削除）が推奨されます。

---

## 2. マイグレーションファイルの修正

### 現在の問題
以下のマイグレーションファイルが`agricultural_task_crops`テーブルを使用している：
- `db/migrate/20251107191500_data_migration_japan_reference_tasks.rb`
- `db/migrate/20251107194500_data_migration_india_reference_tasks.rb`
- `db/migrate/20251107193000_data_migration_united_states_reference_tasks.rb`

### 修正方法

#### オプション1: マイグレーションを修正（推奨）
`TempAgriculturalTaskCrop`の代わりに`CropTaskTemplate`を作成するように変更：

```ruby
# db/migrate/20251107191500_data_migration_japan_reference_tasks.rb
class DataMigrationJapanReferenceTasks < ActiveRecord::Migration[8.0]
  class TempAgriculturalTask < ActiveRecord::Base
    self.table_name = 'agricultural_tasks'
    # has_many :agricultural_task_crops を削除
  end

  # TempAgriculturalTaskCrop クラスを削除

  class TempCrop < ActiveRecord::Base
    self.table_name = 'crops'
  end

  # ... 既存の定数定義 ...

  def up
    say "🌱 日本（jp）の参照タスクを投入しています..."

    legacy_ids = TempAgriculturalTask.where(name: LEGACY_ENGLISH_NAMES, region: 'jp', is_reference: true).pluck(:id)
    if legacy_ids.any?
      # CropTaskTemplateから削除
      CropTaskTemplate.joins(:agricultural_task)
                     .where(agricultural_tasks: { id: legacy_ids })
                     .delete_all
      TempAgriculturalTask.where(id: legacy_ids).delete_all
    end

    TASK_DEFINITIONS.each do |name, attributes|
      task = TempAgriculturalTask.find_or_initialize_by(name: name, region: 'jp', is_reference: true)
      task.description = attributes[:description]
      task.time_per_sqm = attributes[:time_per_sqm]
      task.weather_dependency = attributes[:weather_dependency]
      task.required_tools = attributes[:required_tools].to_json
      task.skill_level = attributes[:skill_level]
      task.user_id = nil
      task.is_reference = true
      task.region = 'jp'
      task.save!

      # 既存のCropTaskTemplateを削除
      CropTaskTemplate.where(agricultural_task_id: task.id).delete_all

      attributes[:crops].each do |crop_name|
        crop = TempCrop.find_or_create_by!(name: crop_name, region: 'jp', is_reference: true) do |new_crop|
          new_crop.user_id = nil
          new_crop.variety ||= '一般'
        end

        # AgriculturalTaskCropの代わりにCropTaskTemplateを作成
        CropTaskTemplate.create!(
          crop_id: crop.id,
          agricultural_task_id: task.id,
          source_agricultural_task_id: task.id,
          name: task.name,
          description: task.description,
          time_per_sqm: task.time_per_sqm,
          weather_dependency: task.weather_dependency,
          required_tools: task.required_tools,
          skill_level: task.skill_level,
          task_type: task.task_type,
          task_type_id: task.task_type_id,
          is_reference: task.is_reference
        )
      end
    end

    say "✅ 日本の参照タスク投入が完了しました"
  end

  def down
    say "🗑️ 日本（jp）の参照タスクを削除しています..."

    task_ids = TempAgriculturalTask.where(name: TASK_DEFINITIONS.keys, region: 'jp', is_reference: true).pluck(:id)
    # CropTaskTemplateから削除
    CropTaskTemplate.where(agricultural_task_id: task_ids).delete_all if task_ids.any?
    TempAgriculturalTask.where(id: task_ids).delete_all if task_ids.any?

    legacy_ids = TempAgriculturalTask.where(name: LEGACY_ENGLISH_NAMES, region: 'jp', is_reference: true).pluck(:id)
    if legacy_ids.any?
      CropTaskTemplate.joins(:agricultural_task)
                     .where(agricultural_tasks: { id: legacy_ids })
                     .delete_all
      TempAgriculturalTask.where(id: legacy_ids).delete_all
    end

    say "✅ 日本の参照タスクを削除しました"
  end
end
```

#### オプション2: マイグレーションをそのまま残す（非推奨）
マイグレーションは既に実行済みなので、修正しない選択肢もあります。ただし、テストが実行できないため、将来的に問題になる可能性があります。

**注意**: マイグレーションファイルを修正する場合は、既に本番環境で実行済みのマイグレーションを変更することになるため、慎重に検討する必要があります。通常、既に実行済みのマイグレーションは変更しません。

---

## 3. テストファイルの修正

### CropTaskTemplateBackfillServiceTest
サービスを修正または削除した後、テストを有効化：

```ruby
# test/services/crop_task_template_backfill_service_test.rb
class CropTaskTemplateBackfillServiceTest < ActiveSupport::TestCase
  setup do
    @crop = create(:crop)
    @task = create(:agricultural_task, :user_owned, user: @crop.user)
    # AgriculturalTaskCropの代わりに、直接CropTaskTemplateを作成するか、
    # サービスがAgriculturalTaskとCropの関連を直接確認するように変更
  end

  # テストを有効化
end
```

### CropTaskTemplatesRakeTest
サービスを修正または削除した後、テストを有効化：

```ruby
# test/tasks/crop_task_templates_rake_test.rb
test 'backfills templates for specified crop ids only' do
  # skip文を削除
  ENV['CROP_IDS'] = @crop_included.id.to_s
  # ...
end
```

### マイグレーションテスト
マイグレーションファイルを修正した後、テストを有効化：

```ruby
# test/migrations/data_migration_japan_reference_tasks_test.rb
def test_up_creates_reference_tasks_and_assigns_crops
  # skip文を削除
  @migration.up
  # ...
end
```

---

## 推奨される修正順序

1. **CropTaskTemplateBackfillService**を削除または修正
   - 移行が完了しているため、削除が推奨
   - 削除する場合、`lib/tasks/crop_task_templates.rake`も削除

2. **マイグレーションファイル**は既に実行済みのため、修正しない（推奨）
   - テストのみスキップのままにする
   - または、新しいマイグレーションファイルを作成して、既存のマイグレーションを置き換える

3. **テストファイル**を修正
   - サービスを削除した場合、関連テストも削除
   - サービスを修正した場合、テストを有効化して修正

---

## 注意事項

- **既に実行済みのマイグレーションを変更するのは危険**です。本番環境で既に実行されているマイグレーションを変更すると、データの不整合が発生する可能性があります。
- **マイグレーションテスト**は、マイグレーションが正しく動作することを確認するためのものですが、既に実行済みのマイグレーションについては、テストをスキップするのが安全です。
- **CropTaskTemplateBackfillService**は移行用のサービスなので、移行が完了している場合は削除するのが適切です。

