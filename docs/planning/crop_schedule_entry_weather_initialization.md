# 作物スケジュール（エントリ）— 気象初期化の実装メモ

> **配置メモ（2026-05）**: 旧 `WeatherPredictionService` / `app/services/crop_schedule/window_service.rb` は削除済み。予測は **`Domain::WeatherData::Interactors::WeatherPredictionInteractor`**（`CompositionRoot.weather_prediction_interactor`）、帯計算は **`Domain::CultivationPlan::Interactors::EntrySchedule::WindowService`**（[`window_service.rb`](../../lib/domain/cultivation_plan/interactors/entry_schedule/window_service.rb)）。HTTP 境界は `Api::V1::PublicPlans::EntryScheduleController` が各 **`CompositionRoot.entry_schedule_*_interactor`** に委譲。

**ステータス**: 実装準拠（コードと同期すること）  
**関連契約**: [docs/contracts/entry-schedule-contract.md](../contracts/entry-schedule-contract.md)

参照農場（`Farm`）から予測気象 JSON を得るまでの**固定手順**。ここを外すと 422/503 や不要な予測実行につながる。

## 1. 前提チェック（必須）

1. リクエストの `farm_id` で `Farm` を取得する。
2. **`farm.reference?`** が真であること（参照農場以外は 404）。
3. **`farm.weather_location` が nil でないこと**  
   - `weather_location_id` が未設定の参照農場は、エントリ API では**予測不能**として扱う。  
   - この時点で **`WeatherPredictionInteractor` を組み立てない**。  
   - レスポンス: **422**（`api.entry_schedule.errors.weather_location_required`）。

実装: `EntryScheduleController` → `CompositionRoot.entry_schedule_*_interactor`（参照農場解決・気象は Interactor/Gateway 内）。旧メソッド名 `find_reference_farm!` は現行コードと異なる場合があるため **コントローラ実装を正**とする。

## 2. WeatherPredictionInteractor の組み立て（固定形）

```ruby
interactor = CompositionRoot.weather_prediction_interactor(
  weather_location: farm.weather_location,
  farm: farm
)
```

- **`weather_location:`** — 必須（地点・キャッシュキー）。
- **`farm:`** — 任意だが**付与推奨**（`predicted_weather_data` の保存先・`get_existing_prediction` が Farm キャッシュを参照する流儀のため）。

## 3. 予測終端日（`target_end_date`）

- API クエリ `prediction_end_date` を **`Date`** にパースした値を `target_end_date` として渡す。
- **未指定・パース失敗**: **`Date.current.end_of_year`**（当年末まで。年間比較に十分な終端をデフォルト固定）。

実装: `EntryScheduleController#parse_prediction_end_date`。

## 4. 既存キャッシュ優先 → 不足時のみ予測実行

1. `interactor.get_existing_prediction(...)` またはドメインゲートウェイ経由の同等処理でキャッシュを読む（実装は [`weather_prediction_interactor.rb`](../../lib/domain/weather_data/interactors/weather_prediction_interactor.rb) を参照）。
2. 戻り値に **`cached[:data]` が Hash** かつ、その中身が `predicted_weather_data` 相当（少なくとも `'data'` 配列を持つ）なら、**それを `Domain::CultivationPlan::Interactors::EntrySchedule::WindowService` へ渡すペイロード**として使用する。
3. 無ければ **`interactor.predict_for_farm(...)`** を実行し、**`farm.reload` 後の `farm.predicted_weather_data`** をペイロードとする。

## 5. ペイロード検証

- 上記いずれかの方法で得た Hash に **`'data'` が空でない配列**であること。  
- 満たさない場合は **422**（共通 `no_weather_data`）。

## 6. 予測例外

`WeatherPredictionInteractor` / ゲートウェイが送出する予測データ欠損系は、エントリ境界で **`WeatherPredictionFailedError` 等として 503** にマッピング（詳細はエントリ Interactor/Gateway を参照）。

## 7. 参照ファイル

| 項目 | パス |
|------|------|
| エントリ API | `app/controllers/api/v1/public_plans/entry_schedule_controller.rb` |
| 予測・キャッシュ | [`lib/domain/weather_data/interactors/weather_prediction_interactor.rb`](../../lib/domain/weather_data/interactors/weather_prediction_interactor.rb)（`CompositionRoot.weather_prediction_interactor`） |
| 帯計算 | [`lib/domain/cultivation_plan/interactors/entry_schedule/window_service.rb`](../../lib/domain/cultivation_plan/interactors/entry_schedule/window_service.rb) |
