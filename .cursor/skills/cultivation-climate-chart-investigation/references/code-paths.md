# 気象・チャートのコード経路

## ジョブチェーン（allocate 前の予測）

```
FetchWeatherDataJob → WeatherPredictionJob → OptimizationJob (allocate)
```

| 段階 | クラス | 気象の扱い |
|------|--------|------------|
| 予測 | `WeatherPredictionInteractor#predict_for_cultivation_plan` | 学習 DB + **当年観測** + agrr predict → `CultivationPlan#predicted_weather_data` に保存 |
| allocate | `CultivationPlanOptimizeInteractor` | **`get_existing_prediction` のみ**（再 predict しない）→ `allocation_weather_*` debug |

`prepare_weather_data` のマージ: `merge_weather_data(current_year_formatted, future)`。  
`prediction_start_date` メタは `max(training_end+1, today)`。

## 進捗チャート（progress）

```
FieldCultivationClimateDataInteractor
  → fetch_primary_weather_payload (plan cached + 観測マージ)
  → FieldCultivationClimateAgrrWeatherAssembler（観測マージ）
  → climate_progress_gateway.calculate_progress → progress_weather_* debug
  → FieldCultivationClimateDataMapper.build_daily_gdd
  → apply_display_range (ガント交差)
```

観測マージ範囲: `FieldCultivationClimateObservedMergeRangePolicy` — **栽培期間**（表示窓ではない）。

## adjust / add_crop

```
PlanAllocationAdjustInteractor#fetch_and_merge_weather_data
  → キャッシュ予測 + historical_rows（AdjustObservedWeatherWindowMapper の窓）
  → AdjustHistoricalPredictionMapper.merge_historical_series_with_prediction
  → adjust_weather_* debug
```

allocate **とは別経路**で気象を再構成する。DB 観測が古いと **allocate 時より欠損が大きい** adjust weather になる。

## agrr CLI 再現

```bash
lib/core/agrr progress \
  --crop-file tmp/debug/progress_crop_<ts>.json \
  --start-date <栽培開始> \
  --weather-file tmp/debug/progress_weather_<ts>.json \
  --format json
```

`progress_records` の最初の日付が **栽培開始より後**なら、weather にその日が無い。

## ドメイン修正の所在（栽培期間ズレ対策）

| コンポーネント | 役割 |
|----------------|------|
| `FieldCultivationClimateObservedMergeRangePolicy` | 観測取得を栽培期間に固定 |
| `FieldCultivationClimateAgrrWeatherAssembler` | キャッシュ予測 + 観測 DTO をマージ |
| `AdjustObservedWeatherWindowMapper` | adjust 観測窓に当年 1/1 を含める |
| `FieldCultivationClimateDataMapper#build_daily_gdd` | `completion_date` で progress を切る |
| `truncate_daily_gdd_at_requirement!` | 要求 GDD **以上**で系列を切る（未達では伸ばさない） |
