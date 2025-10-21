# バグ修正: AGRR予測でBigDecimalが文字列化されて出力ファイルが空になる問題

## 問題の概要

AGRR予測機能が以下のエラーで失敗していました：

```
予測の実行に失敗しました: Prediction output file is empty (command succeeded but produced no output)
```

## 根本原因

### 1. BigDecimalのJSON文字列化

PostgreSQLの`DECIMAL`型カラムはRubyで`BigDecimal`クラスとして扱われます。`BigDecimal`をJSONに変換すると**文字列**になります：

```ruby
# データベースから取得
datum.temperature_max  # => #<BigDecimal:-0.7E0>

# JSONに変換すると文字列になる
{
  'temperature_2m_max' => datum.temperature_max
}.to_json
# => {"temperature_2m_max":"13.9"}  # ❌ 文字列
```

### 2. agrr CLIの入力要件

`lib/core/agrr predict`コマンドは、入力データの温度フィールドを**数値**として要求します：

```json
{
  "data": [
    {
      "time": "2024-10-01",
      "temperature_2m_max": 25.5,       // ✅ 数値
      "temperature_2m_min": 15.2,       // ✅ 数値
      "temperature_2m_mean": 20.3       // ✅ 数値
    }
  ]
}
```

文字列形式で送信すると、コマンドは正常終了（Exit code 0）しますが、**出力ファイルが空**になります：

```json
{
  "data": [
    {
      "time": "2024-10-01",
      "temperature_2m_max": "25.5",     // ❌ 文字列
      "temperature_2m_min": "15.2",     // ❌ 文字列
      "temperature_2m_mean": "20.3"     // ❌ 文字列
    }
  ]
}
```

## 修正内容

### 修正箇所

以下の3つのファイルで`BigDecimal`を明示的に`Float`に変換：

1. `app/controllers/farms/weather_data_controller.rb`
2. `app/controllers/api/v1/public_plans/field_cultivations_controller.rb`
3. `app/controllers/api/v1/public_plans/cultivation_plans_controller.rb`

### 修正詳細

#### 1. `app/controllers/farms/weather_data_controller.rb`

```diff
  formatted_data = {
    'data' => historical_data.map do |datum|
      {
        'time' => datum.date.to_s,
-       'temperature_2m_max' => datum.temperature_max,
+       'temperature_2m_max' => datum.temperature_max.to_f,
-       'temperature_2m_min' => datum.temperature_min,
+       'temperature_2m_min' => datum.temperature_min.to_f,
-       'temperature_2m_mean' => datum.temperature_mean,
+       'temperature_2m_mean' => datum.temperature_mean.to_f,
-       'precipitation_sum' => datum.precipitation || 0.0
+       'precipitation_sum' => (datum.precipitation || 0.0).to_f
      }
    end
  }
```

#### 2. `app/controllers/api/v1/public_plans/field_cultivations_controller.rb`

```diff
  training_formatted = {
    'latitude' => latitude,
    'longitude' => longitude,
    'timezone' => weather_location.timezone || 'Asia/Tokyo',
    'data' => training_data.filter_map do |datum|
      next if datum.temperature_max.nil? || datum.temperature_min.nil?
      
      temp_mean = datum.temperature_mean || ((datum.temperature_max + datum.temperature_min) / 2.0)
      
      {
        'time' => datum.date.to_s,
-       'temperature_2m_max' => datum.temperature_max,
+       'temperature_2m_max' => datum.temperature_max.to_f,
-       'temperature_2m_min' => datum.temperature_min,
+       'temperature_2m_min' => datum.temperature_min.to_f,
-       'temperature_2m_mean' => temp_mean,
+       'temperature_2m_mean' => temp_mean.to_f,
-       'precipitation_sum' => datum.precipitation || 0.0
+       'precipitation_sum' => (datum.precipitation || 0.0).to_f
      }
    end
  }
```

#### 3. `app/controllers/api/v1/public_plans/cultivation_plans_controller.rb`

同様の修正を適用。

## 検証方法

### 1. データベースの型確認

```ruby
WeatherDatum.columns_hash.each do |name, col|
  if ['temperature_max', 'temperature_min', 'temperature_mean'].include?(name)
    puts "#{name}: #{col.type} (SQL type: #{col.sql_type})"
  end
end
# => temperature_max: decimal (SQL type: decimal)
```

### 2. BigDecimalのクラス確認

```ruby
datum = WeatherDatum.first
datum.temperature_max.class
# => BigDecimal
datum.temperature_max.to_f
# => -0.7 (Float)
```

### 3. JSON出力形式の確認

**修正前:**
```json
{
  "temperature_2m_max": "13.9",  // 文字列
  "temperature_2m_min": "2.8",
  "temperature_2m_mean": "8.433333333333334"
}
```

**修正後:**
```json
{
  "temperature_2m_max": 13.9,  // 数値
  "temperature_2m_min": 2.8,
  "temperature_2m_mean": 8.433333333333334
}
```

### 4. 予測実行テスト

```bash
docker compose exec web bash -c 'cd /app && rails runner "
weather_location = WeatherLocation.find(87)
historical_data = weather_location.weather_data
  .where(date: 2.years.ago..Date.today)
  .order(:date)

formatted_data = {
  \"data\" => historical_data.map { |d| {
    \"time\" => d.date.to_s,
    \"temperature_2m_max\" => d.temperature_max.to_f,
    \"temperature_2m_min\" => d.temperature_min.to_f,
    \"temperature_2m_mean\" => d.temperature_mean.to_f,
    \"precipitation_sum\" => (d.precipitation || 0.0).to_f
  }}
}

prediction_gateway = Agrr::PredictionGateway.new
result = prediction_gateway.predict(
  historical_data: formatted_data,
  days: 30,
  model: \"lightgbm\"
)

puts \"✅ Prediction successful!\"
puts \"Predictions count: #{result[\"data\"]&.count}\"
"'
```

**期待される出力:**
```
✅ Prediction successful!
Predictions count: 30
```

## 教訓

### PostgreSQLのDECIMAL型とBigDecimal

- PostgreSQLの`DECIMAL`型はRubyで`BigDecimal`として扱われる
- `BigDecimal`をJSONに変換すると自動的に文字列になる
- 外部CLIツールに渡す前に、明示的に`.to_f`で変換する必要がある

### CLIツールとのインターフェース

- CLIツールの入力要件（データ型）を確認する
- コマンドが成功（Exit code 0）しても、出力が期待通りでない場合は入力データの型を疑う
- デバッグファイルで実際の入力形式を確認する

### 型安全性

- Rubyの動的型付けとJSONの型システムの違いに注意
- 数値を扱う場合は、明示的に型変換を行う
- データベースからのデータをJSONに変換する際は、型を意識する

## 関連ファイル

- `app/controllers/farms/weather_data_controller.rb`
- `app/controllers/api/v1/public_plans/field_cultivations_controller.rb`
- `app/controllers/api/v1/public_plans/cultivation_plans_controller.rb`
- `app/gateways/agrr/prediction_gateway.rb`
- `lib/core/agrr` (バイナリ)

## 修正日時

2025-10-21

