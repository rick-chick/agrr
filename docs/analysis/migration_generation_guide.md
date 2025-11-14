# マイグレーション生成スクリプト一覧

## 既存のマイグレーション生成スクリプト

### 1. generate_pest_data_migration.rb
**場所**: `bin/generate_pest_data_migration.rb`

**用途**: 害虫データのマイグレーションを生成（agrrコマンドを使用）

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

**スクリプトの構造**:
1. agrrコマンドから害虫データを取得
2. `build_migration_content`メソッドでマイグレーションコンテンツを生成
3. `File.open`でマイグレーションファイルを作成
4. タイムスタンプは`Time.now.strftime('%Y%m%d%H%M%S')`で生成

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

**スクリプトの構造**:
1. `BlueprintMigrationWriter`クラスでマイグレーションファイルを生成
2. `render`メソッドでマイグレーションコンテンツを生成
3. `write!`メソッドでファイルに書き込み
4. タイムスタンプは`Time.now.utc.strftime('%Y%m%d%H%M%S')`で生成

## 新しいマイグレーション作成方法

### 方法1: Railsコマンドを使用（推奨）

```bash
rails generate migration MigrationName
```

例:
```bash
rails generate migration UpdateDataMigrationJapanReferenceTasks
```

生成されるファイル:
- `db/migrate/YYYYMMDDHHMMSS_update_data_migration_japan_reference_tasks.rb`

### 方法2: 手動でファイルを作成

```bash
# タイムスタンプを生成
timestamp=$(date +%Y%m%d%H%M%S)

# ファイルを作成
touch db/migrate/${timestamp}_migration_name.rb
```

### 方法3: 既存スクリプトを参考に新しいスクリプトを作成

既存の`generate_pest_data_migration.rb`や`generate_crop_task_schedule_blueprints.rb`を参考に、新しいスクリプトを作成できます。

## マイグレーションファイルのテンプレート

### 基本的な構造

```ruby
# frozen_string_literal: true

class MigrationName < ActiveRecord::Migration[8.0]
  # 一時モデル定義（マイグレーション内でのみ使用）
  class TempModel < ActiveRecord::Base
    self.table_name = 'table_name'
  end

  def up
    say "処理を開始しています..."
    # マイグレーション処理
    say "✅ 処理が完了しました"
  end

  def down
    say "ロールバック処理を開始しています..."
    # ロールバック処理
    say "✅ ロールバックが完了しました"
  end
end
```

### データマイグレーションの例

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
      # 処理を実装
    end

    say "✅ 日本の参照タスクのCropTaskTemplate更新が完了しました"
  end

  def down
    say "🗑️ ロールバック処理..."
    # 必要に応じてロールバック処理を実装
  end
end
```

## タイムスタンプ生成

### Rubyで生成
```ruby
timestamp = Time.now.utc.strftime('%Y%m%d%H%M%S')
# 例: 20251113200000
```

### コマンドラインで生成
```bash
date +%Y%m%d%H%M%S
# 例: 20251113200000
```

## 注意事項

1. **既に実行済みのマイグレーションは変更しない**
   - 本番環境で既に実行されているマイグレーションを変更すると、データの不整合が発生する可能性があります

2. **新しいマイグレーションを作成する**
   - 既存のマイグレーションを修正するのではなく、新しいマイグレーションを作成してデータを更新します

3. **マイグレーションは冪等性を保つ**
   - 何度実行しても同じ結果になるように実装します

4. **一時モデルを使用する**
   - マイグレーション内では、アプリケーションモデルではなく一時モデル（TempModel）を使用します
   - これにより、スキーマ変更に強いマイグレーションになります

