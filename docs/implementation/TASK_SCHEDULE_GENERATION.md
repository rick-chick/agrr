# 作業予定（GDD換算）生成フロー

## 背景

- これまで `TaskScheduleGeneratorService` は AGRR CLI のレスポンスに直接依存していた。
- GDD トリガーやタスク定義を CLI から都度取得すると、参照データの変更が予測困難で回帰リスクが高い。
- 新テーブル `crop_task_schedule_blueprints` に作業テンプレートを保持し、CLI はテンプレート生成時のみ利用する設計に変更した。

## コンポーネント概要

- `CropTaskScheduleBlueprint`
  - 作業テンプレートの永続化用モデル。
  - `task_type` は `field_work / basal_fertilization / topdress_fertilization` のいずれか。
  - `gdd_trigger`・`gdd_tolerance` など、`TaskScheduleItem` と同等の情報を保持する。
- `TaskScheduleGeneratorService`
  - テンプレートを優先的に読み込み、`CropTaskScheduleBlueprint` から `TaskScheduleItem` を生成する。
  - テンプレートが存在しない場合は `TemplateMissingError` を送出して停止する。
- `bin/generate_crop_task_schedule_blueprints.rb`
  - AGRR CLI (`schedule`, `fertilize plan`) を通じて参照作物のテンプレート JSON を取得し、データマイグレーションを出力するスクリプト。
  - CLI 呼び出し時には `AgriculturalTask.to_agrr_format_array` を使用し、`task_id` が既存 ID になるよう保証する。

## 生成フロー

1. `TaskScheduleGeneratorService#generate!(cultivation_plan_id:)` を呼び出す。
   - `CultivationPlan` に `predicted_weather_data` が無い場合は `WeatherDataMissingError`。
2. 栽培計画に紐づく各 `field_cultivation` を処理。
   1. 対象作物の作業テンプレート (`crop_task_schedule_blueprints`) を取得し、存在しなければ `TemplateMissingError`。
   2. `Agrr::ProgressGateway` で `progress_records` を取得し、GDD と日付の対応表を構築。空の場合は `ProgressDataMissingError`。
   3. テンプレートを `field_work` と `fertilizer` に分類し、それぞれ `TaskSchedule` を再生成。
   4. 各 `CropTaskScheduleBlueprint` から `TaskScheduleItem` を組み立てる。
      - GDD が未設定の場合は `GddTriggerMissingError`。
      - 作業名はテンプレート → 関連タスク → ステージ名の順で決定。
3. `TaskSchedule` / `TaskScheduleItem` は対象スコープを削除 (`delete_all`) してから再作成する。

### モデル構造

```
CropTaskScheduleBlueprint
  - belongs_to :crop
  - belongs_to :agricultural_task (optional)
  - columns:
      crop_id, stage_order, stage_name, task_type,
      gdd_trigger, gdd_tolerance, priority, source,
      agricultural_task_id, source_agricultural_task_id,
      description, amount, amount_unit,
      weather_dependency, time_per_sqm

TaskSchedule / TaskScheduleItem
  - 従来どおり。テンプレート採用に伴い生成元が DB 化された。
```

## テンプレート生成スクリプト

```
bin/generate_crop_task_schedule_blueprints.rb --region jp [--crop-id 42 | --crop-name トマト]
```

- 指定した参照作物に対して CLI を実行し、テンプレート用データマイグレーションを `db/migrate` に出力する。
- 出力されたマイグレーションでは一時モデル (`TempBlueprint`) を介して `insert_all` / `delete_all` を行う。
- CLI 呼び出しが失敗した場合は即座にエラー終了し、マイグレーションは生成されない。
- 既存データからテンプレートを補完する場合は `bundle exec rake agrr:backfill_crop_task_templates [CROP_IDS=1,2]` を実行。

## 例外と検証ポイント

- `WeatherDataMissingError` : `predicted_weather_data` が未保存。
- `ProgressDataMissingError` : `progress_records` が空、または指定 GDD に対応する日付が見つからない。
- `TemplateMissingError` : 対象作物にテンプレートが 1 件も存在しない。
- `GddTriggerMissingError` : テンプレート側の GDD 値が欠損。

## テスト

- `test/services/task_schedule_generator_service_test.rb`
  - テンプレート経路のスケジュール生成・例外送出を検証。
  - 進捗データのフィルタリングや GDD 日付マッピングを確認。
- `test/services/crop_task_schedule_blueprint_generator_test.rb`
  - CLI レスポンスからテンプレート属性へ変換するロジックを検証。
- `test/models/crop_task_schedule_blueprint_test.rb`
  - バリデーションとユニーク制約の確認。

## 今後の TODO

- テンプレートの管理 UI（編集・再生成・履歴管理）。
- `crops#show` 以外でのテンプレート活用（プラン作成画面など）を検討。
- CLI 停止時のリカバリ手順整備（スクリプトのリトライ戦略など）。

