# 予測機能の制限事項

## 概要

farmの詳細画面の天気予測機能に関する制限事項と対応策をまとめています。

## 現在の制限

### 1. 予測期間の制限

**問題**: AGRRコマンド（`agrr predict`）が180日以上の予測で出力ファイルを生成できない

**テスト結果**:
- ✅ 30日の予測: 成功
- ✅ 90日の予測: 成功
- ❌ 180日の予測: 失敗（出力ファイルが空）
- ❌ 365日の予測: 失敗（出力ファイルが空）

**現在の対応**:
- `PredictWeatherDataJob`のデフォルト予測日数を90日に設定
- `WeatherDataController`でも90日を指定

**コード箇所**:
```ruby
# app/controllers/farms/weather_data_controller.rb
PredictWeatherDataJob.perform_later(
  farm_id: @farm.id,
  days: 90,  # 365から90に変更
  model: 'lightgbm'
)
```

### 2. 履歴データの古さ

**問題**: 一部の農場で天気データの最終日が古い（例: Farm ID 87は2025-08-25まで）

**影響**:
- 予測は履歴データの翌日から開始される
- 古いデータからの予測の場合、現在日以降の未来データが限られる
- 例: 8月25日までのデータで90日予測すると11月23日までとなり、10月21日以降は約34日分のみ

**原因**:
- 天気データソース（NASA POWER / Open-Meteo）が最新データを提供していない
- データ更新ジョブが正常に動作していない

## 実装された修正

### PredictWeatherDataJob の改善

1. **利用可能な最新データを使用**:
   ```ruby
   latest_available_date = weather_location.weather_data.maximum(:date)
   end_date = latest_available_date
   start_date = end_date - 2.years
   ```

2. **予測開始日の自動調整**:
   ```ruby
   prediction_start_date = [Date.today, end_date + 1.day].max
   ```

3. **過去データのフィルタリング**:
   ```ruby
   prediction_data = prediction_result['data'].filter_map do |datum|
     datum_date = Date.parse(datum['time'])
     next if datum_date < prediction_start_date  # 過去のデータはスキップ
     # ...
   end
   ```

## トラブルシューティング

### 予測データが少ない場合

1. **履歴データの確認**:
   ```ruby
   farm = Farm.find(farm_id)
   wl = farm.weather_location
   latest = wl.weather_data.maximum(:date)
   puts "Latest weather data: #{latest}"
   ```

2. **天気データの更新**:
   ```ruby
   FetchWeatherDataJob.perform_now(
     farm_id: farm.id,
     latitude: farm.latitude,
     longitude: farm.longitude,
     start_date: Date.new(2025, 1, 1),
     end_date: Date.today
   )
   ```

3. **予測の再実行**:
   ```ruby
   farm.update!(predicted_weather_data: nil)
   PredictWeatherDataJob.perform_now(
     farm_id: farm.id,
     days: 90,
     model: 'lightgbm'
   )
   ```

### AGRRコマンドのデバッグ

1. **デバッグファイルの確認**:
   ```bash
   # 最新の入力ファイルを確認
   ls -lt tmp/debug/prediction_input_*.json | head -1
   
   # 最新の出力ファイルを確認
   ls -lt tmp/debug/prediction_output_*.json | head -1
   ```

2. **直接実行してテスト**:
   ```bash
   docker compose exec web /app/lib/core/agrr predict \
     --input /app/tmp/debug/prediction_input_XXXXX.json \
     --output /tmp/test_output.json \
     --days 90 \
     --model lightgbm
   ```

## 今後の対応

### 優先度: 高

1. **AGRRコマンドの180日以上予測の修正**
   - Pythonコードを調査
   - メモリまたはファイルサイズの問題を特定
   - 長期予測のサポートを実装

2. **天気データの自動更新**
   - 定期的なバッチジョブの確認
   - データソースAPIの状態確認
   - エラーハンドリングの改善

### 優先度: 中

3. **ユーザーインターフェースの改善**
   - 予測可能な期間をユーザーに明示
   - 「次の○○日間の予測」というラベルを追加
   - 履歴データの最終日を表示

4. **予測精度の向上**
   - より長い履歴データの使用（3年以上）
   - モデルのパラメータチューニング
   - アンサンブルモデルの実装

## 参考資料

- AGRRコマンドヘルプ: `docker compose exec web /app/lib/core/agrr predict --help`
- 天気データフロー: `docs/features/WEATHER_DATA_FLOW.md`
- バグ修正履歴: `docs/troubleshooting/BUGFIX_PREDICTION_EMPTY_OUTPUT.md`

