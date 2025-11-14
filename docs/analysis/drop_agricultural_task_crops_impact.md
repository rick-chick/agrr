# DropAgriculturalTaskCrops マイグレーションの影響範囲

## 概要
`agricultural_task_crops`テーブルが削除され、代わりに`crop_task_templates`テーブルが使用されるようになりました。

## 影響範囲

### 1. モデルファイル（削除が必要）
- `app/models/agricultural_task_crop.rb` - このモデル自体が不要

### 2. サービスファイル（修正が必要）
- `app/services/crop_task_template_backfill_service.rb`
  - 9行目: `AgriculturalTaskCrop.includes(:crop, :agricultural_task)` を使用
  - `CropTaskTemplate`を使用するように修正が必要

### 3. テストファイル（修正が必要）

#### コントローラーテスト
- `test/controllers/agricultural_tasks_controller_test.rb`
  - 85行目: `AgriculturalTaskCrop.create!`
  - 106行目: `AgriculturalTaskCrop.create!`
  - 124行目: `AgriculturalTaskCrop.create!`
  - 142行目: `AgriculturalTaskCrop.create!`
  - 160-161行目: `AgriculturalTaskCrop.create!` (2箇所)
  - 235行目: `AgriculturalTaskCrop.create!`

- `test/controllers/crops/agricultural_tasks_controller_test.rb`
  - 27行目: `AgriculturalTaskCrop.exists?` のアサーション
  - このアサーションは不要（CropTaskTemplateで確認すべき）

#### サービステスト
- `test/services/plan_save_service_test.rb`
  - 582行目: `AgriculturalTaskCrop.create!`
  - 591行目: `AgriculturalTaskCrop.create!`
  - 600行目: `AgriculturalTaskCrop.create!`
  - 666行目: `AgriculturalTaskCrop.create!`
  - 1428行目: `AgriculturalTaskCrop.create!`
  - 1536行目: `AgriculturalTaskCrop.create!`

- `test/services/crop_task_template_backfill_service_test.rb`
  - 7行目: `AgriculturalTaskCrop.create!`
  - 38行目: `AgriculturalTaskCrop.create!`
  - このテスト自体が`CropTaskTemplateBackfillService`をテストしているため、修正が必要

#### タスクテスト
- `test/tasks/crop_task_templates_rake_test.rb`
  - 17-18行目: `AgriculturalTaskCrop.create!` (2箇所)

#### マイグレーションテスト
- `test/migrations/data_migration_japan_reference_tasks_test.rb`
  - 10行目: `AgriculturalTaskCrop.delete_all`
  - 48行目: `AgriculturalTaskCrop.count` のアサーション

- `test/migrations/data_migration_india_reference_tasks_test.rb`
  - 10行目: `AgriculturalTaskCrop.delete_all`
  - 48行目: `AgriculturalTaskCrop.count` のアサーション

- `test/migrations/data_migration_united_states_reference_tasks_test.rb`
  - 10行目: `AgriculturalTaskCrop.delete_all`
  - 48行目: `AgriculturalTaskCrop.count` のアサーション

### 4. スキーマファイル（修正が必要）
- `db/cable_schema.rb`
  - 42-48行目: `agricultural_task_crops`テーブル定義
  - 655-656行目: 外部キー制約

### 5. マイグレーションファイル（影響なし）
以下のマイグレーションファイル内で一時的に`TempAgriculturalTaskCrop`クラスが使用されていますが、これはマイグレーション内の一時クラスなので問題ありません：
- `db/migrate/20251107191500_data_migration_japan_reference_tasks.rb`
- `db/migrate/20251107193000_data_migration_united_states_reference_tasks.rb`
- `db/migrate/20251107194500_data_migration_india_reference_tasks.rb`

## 修正方針

### AgriculturalTaskCrop → CropTaskTemplate への置き換え

`AgriculturalTaskCrop`は`agricultural_task`と`crop`の中間テーブルでしたが、`CropTaskTemplate`は以下の違いがあります：
- `CropTaskTemplate`は`crop`に属し、`agricultural_task`への参照を持つ
- `name`、`description`などの属性を持つ（AgriculturalTaskのコピー）
- `source_agricultural_task_id`で元のAgriculturalTaskを参照

### テストでの置き換え方法

1. **関連付けの作成**:
   ```ruby
   # 旧: AgriculturalTaskCrop.create!(agricultural_task: task, crop: crop)
   # 新: CropTaskTemplate.create!(crop: crop, agricultural_task: task, name: task.name, ...)
   ```

2. **存在確認**:
   ```ruby
   # 旧: AgriculturalTaskCrop.exists?(crop: crop, agricultural_task: task)
   # 新: CropTaskTemplate.exists?(crop: crop, agricultural_task: task)
   ```

3. **カウント確認**:
   ```ruby
   # 旧: AgriculturalTaskCrop.count
   # 新: CropTaskTemplate.count
   ```

## エラー件数
- テストエラー: 39件
- テスト失敗: 1件
- 合計: 40件のテストが`agricultural_task_crops`テーブル削除の影響を受けている

