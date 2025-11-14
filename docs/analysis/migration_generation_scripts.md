# マイグレーション生成スクリプト

## 既存のマイグレーション生成スクリプト

### 1. generate_pest_data_migration.rb
**場所**: `bin/generate_pest_data_migration.rb`

**用途**: 害虫データのマイグレーションを生成

**使用方法**:
```bash
bin/generate_pest_data_migration.rb --region jp
bin/generate_pest_data_migration.rb --region us
bin/generate_pest_data_migration.rb --region in
```

**生成されるファイル**:
- `db/migrate/YYYYMMDDHHMMSS_data_migration_japan_reference_pests.rb`
- `db/migrate/YYYYMMDDHHMMSS_data_migration_united_states_reference_pests.rb`
- `db/migrate/YYYYMMDDHHMMSS_data_migration_india_reference_pests.rb`

### 2. generate_crop_task_schedule_blueprints.rb
**場所**: `bin/generate_crop_task_schedule_blueprints.rb`

**用途**: 作物の作業スケジュールブループリントのマイグレーションを生成

**使用方法**:
```bash
bin/generate_crop_task_schedule_blueprints.rb --region jp --crop-id 1
bin/generate_crop_task_schedule_blueprints.rb --region jp --crop-name "トマト"
```

**生成されるファイル**:
- `db/migrate/YYYYMMDDHHMMSS_data_migration_jp_crop_task_schedule_blueprints.rb`

## マイグレーションファイルの命名規則

### タイムスタンプ形式
```
YYYYMMDDHHMMSS_description.rb
```

例:
- `20251107191500_data_migration_japan_reference_tasks.rb`
- `20251111091500_add_agricultural_task_to_crop_task_templates.rb`

### 生成方法

#### 方法1: Railsコマンドを使用
```bash
rails generate migration MigrationName
```

例:
```bash
rails generate migration UpdateDataMigrationJapanReferenceTasks
```

#### 方法2: 手動でファイルを作成
```bash
# タイムスタンプを生成
timestamp=$(date +%Y%m%d%H%M%S)

# ファイルを作成
touch db/migrate/${timestamp}_migration_name.rb
```

## 新しいマイグレーション作成の例

### 既存のマイグレーションを修正する場合

既存のマイグレーション（`20251107191500_data_migration_japan_reference_tasks.rb`など）は既に実行済みなので、**新しいマイグレーションを作成**して、`TempAgriculturalTaskCrop`の代わりに`CropTaskTemplate`を使用するように修正する必要があります。

### 新しいマイグレーションのテンプレート

```ruby
# frozen_string_literal: true

class UpdateDataMigrationJapanReferenceTasks < ActiveRecord::Migration[8.0]
  class TempAgriculturalTask < ActiveRecord::Base
    self.table_name = 'agricultural_tasks'
  end

  class TempCrop < ActiveRecord::Base
    self.table_name = 'crops'
  end

  class TempCropTaskTemplate < ActiveRecord::Base
    self.table_name = 'crop_task_templates'
  end

  def up
    say "🌱 日本（jp）の参照タスクのCropTaskTemplateを更新しています..."

    # 既存の参照タスクを取得
    reference_tasks = TempAgriculturalTask.where(region: 'jp', is_reference: true)

    reference_tasks.find_each do |task|
      # このタスクに関連する作物を取得（CropTaskTemplateから）
      templates = TempCropTaskTemplate.where(agricultural_task_id: task.id)
      
      # または、既存の関連付けから作物を取得する必要がある場合
      # （既にCropTaskTemplateが存在する前提）
    end

    say "✅ 日本の参照タスクのCropTaskTemplate更新が完了しました"
  end

  def down
    say "🗑️ ロールバック処理..."
    # 必要に応じてロールバック処理を実装
  end
end
```

## スクリプトの構造

### generate_pest_data_migration.rb の構造

1. **データ取得**: agrrコマンドからデータを取得
2. **マイグレーションコンテンツ生成**: `build_migration_content`メソッド
3. **ファイル書き込み**: `File.open`でマイグレーションファイルを作成

### generate_crop_task_schedule_blueprints.rb の構造

1. **BlueprintMigrationWriterクラス**: マイグレーションファイルを生成
2. **renderメソッド**: マイグレーションコンテンツを生成
3. **write!メソッド**: ファイルに書き込み

## 新しいマイグレーション作成の手順

### 1. タイムスタンプを生成
```bash
date +%Y%m%d%H%M%S
# 例: 20251113200000
```

### 2. マイグレーションファイルを作成
```bash
touch db/migrate/20251113200000_update_data_migration_japan_reference_tasks.rb
```

### 3. マイグレーション内容を記述
既存のマイグレーションを参考に、`TempAgriculturalTaskCrop`の代わりに`CropTaskTemplate`を使用するように修正

### 4. マイグレーションを実行
```bash
rails db:migrate
```

## 注意事項

- **既に実行済みのマイグレーションは変更しない**
- 新しいマイグレーションを作成して、既存のデータを更新する
- マイグレーションは冪等性を保つ（何度実行しても同じ結果になる）

