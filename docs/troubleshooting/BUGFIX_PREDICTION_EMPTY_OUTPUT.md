# バグ修正: AGRR予測出力ファイルが空になる問題

## 問題の概要

`OptimizeCultivationPlanJob`が実行時に以下のエラーで失敗していました：

```
[ActiveJob] [OptimizeCultivationPlanJob] ❌ [AGRR] Output file is empty
Prediction output file is empty
```

## 根本原因

調査の結果、複数の問題が連鎖していることが判明しました：

### 1. NULL温度データの問題 ✅ 修正済み

**問題**: 気象データベースに`temperature_mean`がNULLのレコードが含まれており、AGRR予測コマンドがこれを拒否していました。

**詳細**:
- 20年分のデータ（7305レコード）中、11レコードで`temperature_mean`がNULL
- そのうち3レコードは`temperature_max`と`temperature_min`もNULLで計算不可能
- AGRR予測コマンドは必須フィールドとして`temperature_2m_mean`を要求

**修正内容** (`app/services/cultivation_plan_optimizer.rb`):
```ruby
def format_weather_data_for_agrr(weather_location, weather_data)
  {
    # ...
    'data' => weather_data.filter_map do |datum|
      # 温度データが欠損しているレコードをスキップ
      next if datum.temperature_max.nil? || datum.temperature_min.nil?
      
      # temperature_meanがNULLの場合は max/min から計算
      temp_mean = datum.temperature_mean
      if temp_mean.nil?
        temp_mean = (datum.temperature_max + datum.temperature_min) / 2.0
      end
      
      # ...
    end
  }
end
```

**結果**: 7291レコード（14レコードをフィルタリング）で予測コマンドが正常に実行されるようになりました。

### 2. AGRR予測出力形式の不一致 ✅ 修正済み

**問題**: AGRR CLIの`predict`コマンドの出力形式が変更されており、コードが古い形式を期待していました。

**旧形式（期待していた）**:
```json
{
  "data": [
    {
      "time": "2025-10-13",
      "temperature_2m_max": 25.0,
      "temperature_2m_min": 15.0,
      // ... 全天気変数
    }
  ]
}
```

**新形式（実際の出力）**:
```json
{
  "predictions": [
    {
      "date": "2025-10-13T00:00:00",
      "predicted_value": -0.28,
      "confidence_lower": -4.13,
      "confidence_upper": 2.83
    }
  ],
  "total_predictions": 30,
  "metadata": { "model_type": "ARIMA" }
}
```

**問題点**:
- `predictions`キーの代わりに`data`を探していた
- 単一変数（temperature_2m_mean）のみが予測されていた
- 最適化には全天気変数（temperature_max, temperature_min, precipitation, sunshine_duration等）が必要

**修正内容** (`app/gateways/agrr/prediction_gateway.rb`):

新しい`transform_predictions_to_weather_data`メソッドを追加：

```ruby
def transform_predictions_to_weather_data(prediction_result, historical_data)
  # 履歴データから統計値を計算
  stats = calculate_historical_stats(historical_data['data'])
  
  # 予測データを完全な天気データ形式に変換
  weather_data = prediction_result['predictions'].map do |prediction|
    predicted_temp_mean = prediction['predicted_value']
    
    # 平均気温から最高気温・最低気温を推定
    temp_max = predicted_temp_mean + stats[:temp_range_half]
    temp_min = predicted_temp_mean - stats[:temp_range_half]
    
    {
      'time' => prediction['date'].split('T').first,
      'temperature_2m_max' => temp_max.to_f.round(2),
      'temperature_2m_min' => temp_min.to_f.round(2),
      'temperature_2m_mean' => predicted_temp_mean.to_f.round(2),
      'precipitation_sum' => stats[:avg_precipitation].to_f.round(2),
      'sunshine_duration' => stats[:avg_sunshine].to_f.round(2),
      'wind_speed_10m_max' => stats[:avg_wind_speed].to_f.round(2),
      'weather_code' => 0
    }
  end
  
  { 'data' => weather_data }
end
```

**結果**: AGRR予測コマンドの出力が最適化コマンドの入力形式に正しく変換されるようになりました。

### 3. ARIMA予測の負荷問題 ✅ 修正済み

**問題**: 20年分のデータ（7305レコード）で365日の予測を実行すると、メモリ不足でプロセスがキルされていました（exit code 137）。

**ARIMA推奨**: 7-30日の予測が推奨されているが、365日は範囲外。

**修正内容** (`app/services/cultivation_plan_optimizer.rb`):
```ruby
# 過去3年分の実績データをARIMAモデルのトレーニング用に取得
# (20年分は予測に時間がかかりすぎるため、3年分に制限)
training_start_date = Date.current - 3.years  # 変更前: - 20.years
training_end_date = Date.current - 1.day
training_data = weather_location.weather_data_for_period(training_start_date, training_end_date)

# 来年分の予測データ（90日に制限してARIMAモデルの負荷を軽減）
# ARIMAは7-30日が推奨だが、最適化には最低90日必要
next_year_days = 90  # 変更前: 365
future = @prediction_gateway.predict(
  historical_data: training_formatted,
  days: next_year_days
)
```

**結果**: 
- トレーニングデータ: ~1095日（3年分）
- 予測期間: 90日
- 合計気象データ: 約375日（今年285日 + 予測90日）

予測コマンドが正常に完了するようになり、実行時間が大幅に短縮されました（77.9秒）。

### 4. OptimizationGatewayのフィールド設定 ✅ 修正済み

**問題**: Ruby symbolsをJSON文字列キーに明示的に変換。

**修正内容** (`app/gateways/agrr/optimization_gateway.rb`):
```ruby
def build_field_config(area, daily_fixed_cost)
  {
    'name' => "Field-#{SecureRandom.hex(4)}",  # 変更前: name:
    'field_id' => SecureRandom.uuid,
    'area' => area,
    'daily_fixed_cost' => daily_fixed_cost
  }
end
```

### 5. 気象データ不足による最適化失敗 ⚠️ 要検討

**現状の問題**: 
```
Error calculating optimal growth period: No candidate reached 100% growth completion. 
Consider extending weather data or choosing different start dates.
```

**原因**:
- 評価期間: 2025-10-13 〜 2027-10-13（730日）
- 利用可能な気象データ: 375日（今年285日 + 予測90日）
- とうもろこしの栽培期間: おそらく90日以上必要
- 90日の予測データだけでは、評価期間内のどの開始日からでも栽培を完了できない

**解決策の選択肢**:

1. **予測期間を延長** (推奨度: 中)
   - 90日 → 180日に延長
   - リスク: ARIMAモデルの負荷増加、予測精度低下
   
2. **評価期間を短縮** (推奨度: 高)
   - 2年 → 1年に短縮
   - より現実的な最適化期間
   
3. **複数回の予測を実行** (推奨度: 低)
   - 90日ずつ複数回予測して結合
   - 実装が複雑になる
   
4. **予測データなしで最適化** (推奨度: 中)
   - 今年のデータのみを使用
   - 過去データから seasonal patterns を活用
   
5. **予測モデルの変更** (推奨度: 低)
   - ARIMAから他のモデルへ（Prophet等）
   - AGRR CLIの変更が必要

## 推奨される次のステップ

### 短期的対応（immediate）

```ruby
# app/services/cultivation_plan_optimizer.rb

# Option A: 評価期間を1年に短縮（最もシンプル）
def optimize_field_cultivation(field_cultivation, weather_data)
  result = @optimization_gateway.optimize(
    # ...
    evaluation_start: Date.current,
    evaluation_end: Date.current + 1.year  # 変更: + 2.years → + 1.year
  )
end

# Option B: 予測期間を180日に延長（データ重視）
def prepare_weather_data
  next_year_days = 180  # 変更: 90 → 180
  future = @prediction_gateway.predict(
    historical_data: training_formatted,
    days: next_year_days
  )
end
```

### 中期的対応（recommended）

1. **動的な評価期間の設定**:
   ```ruby
   # 利用可能な気象データに基づいて評価期間を調整
   available_days = current_year_data.count + predicted_days
   max_evaluation_days = available_days - crop_cultivation_days_estimate
   evaluation_end = [Date.current + 1.year, Date.current + max_evaluation_days.days].min
   ```

2. **作物ごとの最低必要データ期間を定義**:
   ```ruby
   # app/models/crop.rb
   def minimum_weather_data_days
     # 作物の栽培期間 + マージン
     self.typical_cultivation_days + 30
   end
   ```

3. **予測パラメータの最適化**:
   - トレーニングデータ: 2-5年（作物や季節によって調整）
   - 予測期間: 90-180日（必要に応じて）
   - メモリ使用量のモニタリング

### 長期的対応（future consideration）

1. **予測モデルの改善**:
   - 複数モデルのアンサンブル
   - 季節性を考慮したモデル選択
   
2. **キャッシング機構**:
   - 予測結果のキャッシュ
   - 同じ座標・期間の予測を再利用
   
3. **非同期処理の最適化**:
   - 予測とoptimization を分離
   - バックグラウンドでの事前予測

## テスト

修正後の動作確認：

```bash
# Docker環境で
docker-compose exec web bundle exec rails runner "
plan = CultivationPlan.find(24)
plan.update!(status: 'pending', error_message: nil)
plan.field_cultivations.update_all(status: 'pending')

optimizer = CultivationPlanOptimizer.new(plan)
result = optimizer.call

puts 'Result: ' + result.to_s
puts 'Status: ' + plan.reload.status
"
```

## 関連ファイル

- `app/services/cultivation_plan_optimizer.rb` - メインロジック
- `app/gateways/agrr/prediction_gateway.rb` - 予測データ変換
- `app/gateways/agrr/optimization_gateway.rb` - 最適化実行
- `app/gateways/agrr/base_gateway.rb` - AGRR CLIインターフェース
- `app/jobs/optimize_cultivation_plan_job.rb` - バックグラウンドジョブ

## まとめ

### 修正完了
✅ NULL温度データの処理
✅ AGRR予測出力形式の変換
✅ ARIMA予測の負荷軽減
✅ フィールド設定のJSON形式

### 残課題
⚠️ 気象データ不足による最適化失敗 → 評価期間の調整が必要

**推奨**: 評価期間を2年から1年に短縮することで、現在の気象データ（375日）で最適化が実行できるようになります。

