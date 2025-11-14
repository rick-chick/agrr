# agrrコマンドのレスポンス構造の説明

## scheduleコマンドのレスポンス構造

agrrの`schedule`コマンドは、以下のようなJSONレスポンスを返します：

**注意**: ヘルプ（`--help`）の出力例には一部のフィールドが記載されていませんが、実際のレスポンスには以下のフィールドが含まれます。

```json
{
  "task_schedules": [
    {
      "task_id": "123",           // 作業ID（文字列）
      "description": "圃場を整える", // 作業の説明（実際のレスポンスに存在）
      "stage_name": "定植前整備",   // ステージ名（成長段階、実際のレスポンスに存在）
      "stage_order": 1,            // ステージ順序
      "gdd_trigger": 0,            // GDDトリガー値
      "gdd_tolerance": 10,         // GDD許容値
      "priority": 1,               // 優先度
      "weather_dependency": "low", // 天候依存性（実際のレスポンスに存在、ヘルプには記載なし）
      "time_per_sqm": "0.2"        // 単位面積あたりの時間（実際のレスポンスに存在、ヘルプには記載なし）
    }
  ]
}
```

**ヘルプとの違い**:
- ヘルプには`stage_name`が記載されていませんが、実際のレスポンスには存在します
- ヘルプには`weather_dependency`が記載されていませんが、実際のレスポンスには存在します
- ヘルプには`time_per_sqm`が記載されていませんが、実際のレスポンスには存在します
- ヘルプには`name`フィールドが記載されていませんが、実際のレスポンスにも存在しない可能性があります（テストデータでは`description`のみ）

### 各フィールドの説明

1. **`task_id`**: 農業作業のID（文字列形式）
2. **`description`**: 作業の詳細説明。例: "圃場を整える"、"土壌準備"（実際のレスポンスに存在）
3. **`stage_name`**: 成長ステージ名。例: "定植前整備"、"定植期"、"成長期"（実際のレスポンスに存在、ヘルプには記載なし）
4. **`stage_order`**: ステージの順序（数値）
5. **`gdd_trigger`**: GDD（積算温度）のトリガー値
6. **`gdd_tolerance`**: GDDの許容値
7. **`priority`**: 作業の優先度
8. **`weather_dependency`**: 天候依存性（"low", "medium", "high"）（実際のレスポンスに存在、ヘルプには記載なし）
9. **`time_per_sqm`**: 単位面積（m²）あたりの作業時間（実際のレスポンスに存在、ヘルプには記載なし）

**注意**: `name`フィールドはテストデータでは使用されていません。実際のレスポンスに存在するかどうかは要確認です。

## fertilizeコマンドのレスポンス構造

agrrの`fertilize plan`コマンドは、以下のようなJSONレスポンスを返します：

**注意**: ヘルプ（`--help`）の出力例には一部のフィールドが記載されていませんが、実際のレスポンスには以下のフィールドが含まれます。

```json
{
  "crop": {
    "crop_id": "rice",
    "name": "Rice",
    "variety": "Koshihikari"
  },
  "total_N_g_per_m2": 24.0,
  "schedule": [
    {
      "task_id": "456",           // 作業ID（文字列、ヘルプでは"fertilize"と記載）
      "stage_name": "定植前",      // ステージ名（ヘルプに記載あり）
      "stage_order": 0,           // ステージ順序
      "gdd_trigger": 0,           // GDDトリガー値
      "gdd_tolerance": 5,         // GDD許容値
      "priority": 1,              // 優先度
      "amount_g_per_m2": 3.5,     // 施肥量（g/m²、ヘルプに記載あり）
      "weather_dependency": "medium" // 天候依存性（実際のレスポンスに存在、ヘルプには記載なし）
    },
    {
      "task_id": "789",
      "stage_name": "追肥",        // ステージ名（この場合、作業名と同じ）
      "stage_order": 2,
      "gdd_trigger": 150,
      "gdd_tolerance": 12,
      "priority": 2,
      "amount_g_per_m2": 4.0,
      "weather_dependency": "high"
    }
  ],
  "use_harvest_start_gdd": true
}
```

**ヘルプとの違い**:
- ヘルプには`weather_dependency`が記載されていませんが、実際のレスポンスには存在します
- ヘルプには`description`フィールドが記載されていませんが、テストデータでは使用されていません（`stage_name`に作業名が入る場合がある）

### 各フィールドの説明

1. **`task_id`**: 農業作業のID（文字列形式、ヘルプでは"fertilize"と記載）
2. **`stage_name`**: 成長ステージ名。例: "定植前"、"追肥"（ヘルプに記載あり。作業名が入る場合もある）
3. **`stage_order`**: ステージの順序（数値）
4. **`gdd_trigger`**: GDD（積算温度）のトリガー値
5. **`gdd_tolerance`**: GDDの許容値
6. **`priority`**: 作業の優先度
7. **`amount_g_per_m2`**: 施肥量（g/m²、ヘルプに記載あり）
8. **`weather_dependency`**: 天候依存性（"low", "medium", "high"）（実際のレスポンスに存在、ヘルプには記載なし）

**注意**: 
- `description`フィールドはテストデータでは使用されていません。`stage_name`に作業名が入る場合があります。
- `amount_unit`フィールドはテストデータでは使用されていません。
- `time_per_sqm`フィールドはテストデータでは使用されていません。

## 問題点と解決策

### 現在の問題

作業予定の`name`フィールドに、`stage_name`（「定植期」「成長期」など）が設定されてしまっている可能性があります。

### 期待される動作

作業予定の`name`フィールドには、以下の優先順位で設定すべきです：

1. **`agricultural_task.name`**: 関連する農業作業が設定されている場合、その名前を優先
2. **`description`**: agrrが返した作業名（「追肥」「基肥」「土壌準備」など）
3. **デフォルト値**: 作業タイプに応じたデフォルト値（「基肥施用」「追肥施用」「field_task」）

**`stage_name`は使用しない**: 「定植期」「成長期」などのステージ名は、作業名として使用すべきではありません。

### 現在の実装

`app/services/task_schedule_generator_service.rb`の`name_for_blueprint`メソッドでは：

```ruby
def name_for_blueprint(blueprint, task)
  # 関連作業が設定されている場合は、その名前を優先
  return task.name if task&.name.present?
  # 関連作業が未設定の場合、agrrが返した作業名（description）を優先的に使用
  # agrrが返したnameを優先し、stage_nameは使用しない
  return blueprint.description if blueprint.description.present?
  
  # デフォルト値
  case blueprint.task_type
  when TaskScheduleItem::BASAL_FERTILIZATION_TYPE
    '基肥施用'
  when TaskScheduleItem::TOPDRESS_FERTILIZATION_TYPE
    '追肥施用'
  else
    'field_task'
  end
end
```

この実装により、`stage_name`は使用されず、`description`（agrrが返した作業名）が優先的に使用されます。

### データフロー

1. **agrrコマンド実行** → `schedule`または`fertilize plan`コマンドを実行
2. **レスポンス取得** → JSONレスポンスを取得
3. **Blueprint生成** → `CropTaskScheduleBlueprintGenerator`でblueprint属性を生成
   - `description`: `task['name'] || task['description']`（scheduleの場合）
   - `description`: `entry['description']`（fertilizeの場合）
   - `stage_name`: `task['stage_name']`または`entry['stage_name']`（保存されるが、nameには使用されない）
4. **TaskScheduleItem生成** → `TaskScheduleGeneratorService`でTaskScheduleItemを生成
   - `name`: `name_for_blueprint(blueprint, task)`で決定
   - `stage_name`: `blueprint.stage_name`（保存されるが、表示には使用されない）

## まとめ

- agrrが返す`name`または`description`フィールドに「追肥」「基肥」「土壌準備」などの具体的な作業名が入っています
- `stage_name`には「定植期」「成長期」などのステージ名が入っていますが、これは作業名として使用すべきではありません
- 現在の実装では、`name_for_blueprint`メソッドで`stage_name`をフォールバックとして使用しないように修正済みです

