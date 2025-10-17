# 温度チャート機能のセットアップ

## 概要
農場の天気データを温度チャートで可視化する機能です。

## データベースの変更

### マイグレーション実行
```bash
rails db:migrate
```

これにより、`farms`テーブルに`weather_location_id`カラムが追加されます。

## 既存データの修正

既に天気データが取得済みの農場がある場合、以下のタスクで関連付けを行います：

```bash
rails weather:fix_associations
```

このタスクは：
- `weather_location_id`が`null`の農場を検索
- 座標が近い（±0.0001度以内）`WeatherLocation`を探す
- 見つかった場合、農場に関連付ける

## 動作の仕組み

### 1. 天気データ取得時（FetchWeatherDataJob）
```ruby
# WeatherLocationを作成
weather_location = WeatherLocation.find_or_create_by_coordinates(...)

# Farmに自動的に関連付け
farm.update_column(:weather_location_id, weather_location.id)
```

### 2. チャート表示時（WeatherDataController）
```ruby
# 直接関連を使用（高速・確実）
weather_location = @farm.weather_location

# データ取得
weather_data = weather_location.weather_data.where(date: start_date..end_date)
```

## トラブルシューティング

### チャートが表示されない場合

1. **農場の天気データステータスを確認**
   ```bash
   rails weather:list
   ```

2. **特定の農場を詳細確認**
   ```bash
   rails weather:debug[1]  # 農場ID=1の場合
   ```

3. **関連付けを確認・修正**
   ```bash
   rails weather:fix_associations
   ```

### Rails Consoleでの確認
```ruby
# Farmを取得
farm = Farm.find(1)

# WeatherLocationの確認
farm.weather_location  # => WeatherLocation or nil

# 関連付けがない場合、手動で設定
weather_location = WeatherLocation.first
farm.update(weather_location: weather_location)

# データ数を確認
farm.weather_location.weather_data.count
```

## APIエンドポイント

### GET /farms/:farm_id/weather_data

**パラメータ:**
- `start_date` (オプション): 開始日 (YYYY-MM-DD)
- `end_date` (オプション): 終了日 (YYYY-MM-DD)

**レスポンス例:**
```json
{
  "success": true,
  "farm": {
    "id": 1,
    "name": "テスト農場",
    "latitude": "35.6812",
    "longitude": "139.7671"
  },
  "period": {
    "start_date": "2024-01-01",
    "end_date": "2024-12-31"
  },
  "data": [
    {
      "date": "2024-01-01",
      "temperature_max": 10.5,
      "temperature_min": 2.3,
      "temperature_mean": 6.4,
      "precipitation": 0.0
    }
  ]
}
```

## フロントエンド

### 表示条件
- 農場の`weather_data_status`が`completed`のとき
- `@farm.id`が`data-farm-id`属性としてcanvas要素に設定される

### チャート機能
- **期間選択**: 過去30日/90日/180日/1年
- **温度表示**: 最高気温（赤）、平均気温（緑）、最低気温（青）
- **インタラクティブ**: ホバーで詳細データを表示

## テスト

```bash
# コントローラーテスト
rails test test/controllers/farms/weather_data_controller_test.rb

# 全テスト
rails test
```

