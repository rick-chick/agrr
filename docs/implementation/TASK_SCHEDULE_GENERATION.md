# 作業予定（GDD換算）生成の実装メモ

## 背景

- AGRR CLI の `schedule --json` で一般作業（基肥・追肥除く）の GDD トリガーを取得できるようになった。
- `fertilize plan --json --use-harvest-start` で基肥・追肥の GDD 配列を取得できるが、CLI 出力には種別が含まれない。
- `CultivationPlan` 側には最適化時に保存した `predicted_weather_data` があり、`agrr progress` を通して「日付 ↔ 累積 GDD」の対応を得られる。
- 上記 3 つを組み合わせ、GDD ベースの作業予定を日付に変換して保存する仕組みを整備した。

## データフロー概要

1. `TaskScheduleGeneratorService#generate!(cultivation_plan_id:)` を呼び出す。
   - `CultivationPlan` の `predicted_weather_data` を前提とする。未保存の場合は `WeatherDataMissingError` を送出。
2. `field_cultivations` 単位で処理。
   1. 対象作物の AGRR フォーマット（`Crop#to_agrr_requirement`）と登録済みタスク（`AgriculturalTask.to_agrr_format_array`）を生成。
   2. `Agrr::ProgressGateway` で `progress_records` を取得し、GDD と日付のマッピング表とする。空の場合は `ProgressDataMissingError` を送出。
   3. `Agrr::ScheduleGateway` で一般作業を取得し、GDD トリガーから日付を算出して `TaskScheduleItem`（`task_type = field_work`）に保存。
   4. `Agrr::FertilizeGateway#plan` で施肥タイミングを取得。配列先頭を基肥（`basal_fertilization`）、2 件目以降を追肥（`topdress_fertilization`）として分類し、同様に日付へ変換。
3. 作成したタスクは `TaskSchedule`（親）と `TaskScheduleItem`（子）に永続化する。再生成時は対象スコープを削除してから再作成。

### モデル構造

```
TaskSchedule (親)
  - belongs_to :cultivation_plan
  - belongs_to :field_cultivation (任意)
  - has_many :task_schedule_items
  - category: general | fertilizer
  - status: active / archived
  - source: agrr
TaskScheduleItem (子)
  - belongs_to :task_schedule
  - task_type: field_work / basal_fertilization / topdress_fertilization
  - gdd_trigger / gdd_tolerance / scheduled_date
  - amount / amount_unit（施肥量などがある場合に使用）
```

## 実装の要点

- **GDD→日付換算**: progress の `progress_records` から、指定 GDD を初めて上回る日を選択。見つからない場合はエラー。
- **施肥分類**: `fertilize plan` の結果は内部で type を保持しているが CLI には露出していないため、配列先頭を基肥、それ以降を追肥として扱う。
- **冪等性**: `TaskSchedule.where(...).delete_all` で同一スコープを削除してから新規作成。
- **例外**: 気象データ欠如・進捗データ欠如・GDD に対応する日が無い場合はいずれも例外送出で停止。

## 使い方（現状）

画面からの導線は未実装。検証時は Rails コンソール等から手動で呼び出す。

```ruby
# 例: 計画ID = 123
TaskScheduleGeneratorService.new.generate!(cultivation_plan_id: 123)
```

サービスは AGRR デーモンが稼働していることを前提とする。必要に応じて `schedule_gateway` / `fertilize_gateway` / `progress_gateway` を差し替えてテスト可能。

## テスト

- `test/services/task_schedule_generator_service_test.rb`
  - Stub Gateway を用いて GDD→日付換算と基肥・追肥分類を検証。
  - progress にレコードが存在しないパターンで例外を確認。
  - Factory を拡充して `CultivationPlan` + `FieldCultivation` エンティティを組み立て。

## 未対応事項・今後の課題

- UI / API / バックグラウンドジョブなど、ユーザーから実行する導線の実装。
- 作業予定表示や編集機能、ログおよび再生成ポリシーの設計。
- `TaskScheduleItem` の `weather_dependency` や `priority` を活かしたフロントエンドでの表示整備。
- ステージ名などに基づく追肥回数調整や、施肥以外の LLN 判定ロジックのパラメータ化。

