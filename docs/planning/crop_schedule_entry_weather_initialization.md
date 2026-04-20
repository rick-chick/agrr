# 作物スケジュール（エントリ）— 気象初期化の実装メモ

**ステータス**: 実装準拠（コードと同期すること）  
**関連契約**: [docs/contracts/entry-schedule-contract.md](../contracts/entry-schedule-contract.md)

参照農場（`Farm`）から予測気象 JSON を得るまでの**固定手順**。ここを外すと 422/503 や不要な予測実行につながる。

## 1. 前提チェック（必須）

1. リクエストの `farm_id` で `Farm` を取得する。
2. **`farm.reference?`** が真であること（参照農場以外は 404）。
3. **`farm.weather_location` が nil でないこと**  
   - `weather_location_id` が未設定の参照農場は、エントリ API では**予測不能**として扱う。  
   - この時点で **`WeatherPredictionService` を new しない**。  
   - レスポンス: **422**（`api.entry_schedule.errors.weather_location_required`）。

実装: `Api::V1::PublicPlans::EntryScheduleController#find_reference_farm!` → `#load_or_predict_weather!` 先頭で `WeatherLocationMissingError`。

## 2. WeatherPredictionService の初期化（固定形）

```ruby
service = WeatherPredictionService.new(
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

1. `service.get_existing_prediction(target_end_date: target_end)` を呼ぶ。
2. 戻り値に **`cached[:data]` が Hash** かつ、その中身が `predicted_weather_data` 相当（少なくとも `'data'` 配列を持つ）なら、**それを `CropSchedule::WindowService` へ渡すペイロード**として使用する。
3. 無ければ **`service.predict_for_farm(target_end_date: target_end)`** を実行し、**`farm.reload` 後の `farm.predicted_weather_data`** をペイロードとする。

## 5. ペイロード検証

- 上記いずれかの方法で得た Hash に **`'data'` が空でない配列**であること。  
- 満たさない場合は **422**（共通 `no_weather_data`）。

## 6. 予測例外

`WeatherPredictionService::WeatherDataNotFoundError` および `InsufficientPredictionDataError` は **`WeatherPredictionFailedError` にラップし 503**（学習データ不足・外部要件未充足など）。

## 7. 参照ファイル

| 項目 | パス |
|------|------|
| エントリ API | `app/controllers/api/v1/public_plans/entry_schedule_controller.rb` |
| 予測サービス | `app/services/weather_prediction_service.rb` |
| 帯計算 | `app/services/crop_schedule/window_service.rb` |
