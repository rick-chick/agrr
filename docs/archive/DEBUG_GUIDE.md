# デバッグガイド

agrrの結果がおかしい場合の問題切り分け方法

## 🎯 目的

以下を切り分ける：
1. agrrコマンド自体の問題
2. Railsアプリケーション側の問題
3. データベース保存の問題

## 📝 ログレベルの変更

### 開発環境（Docker）

1. `config/environments/development.rb` を編集：

```ruby
config.log_level = :debug  # :info から :debug に変更
```

2. コンテナを再起動：

```bash
docker-compose restart web
```

### 本番環境（AWS App Runner）

環境変数で設定：

```bash
RAILS_LOG_LEVEL=debug
```

## 🔍 デバッグ手順

### ステップ1: agrrコマンド単体のテスト

```bash
# Docker環境で実行
docker-compose exec web bash /app/scripts/debug_agrr.sh

# カスタムパラメータで実行
docker-compose exec web bash /app/scripts/debug_agrr.sh 35.68 139.77 2024-01-01 2024-01-31
```

**確認ポイント:**
- ✅ agrrコマンドが正常に実行されるか
- ✅ JSONが正しくパースできるか
- ✅ データ件数が期待通りか
- ✅ 温度・降水量・日照時間などの値が妥当か

### ステップ2: Railsログの確認

```bash
# 開発環境のログを監視
docker-compose logs -f web

# 特定のログのみフィルタ
docker-compose logs -f web | grep -E "(AGRR|Weather|💾|📊|🔧)"
```

**確認すべきログ:**

1. **agrrコマンドの実行ログ:**
```
🔧 [AGRR Command] /app/lib/core/agrr weather --location 35.68,139.77 ...
```

2. **agrrコマンドの出力:**
```
📥 [AGRR Output] {"success":true,"data":{...}}
```

3. **データ検証ログ:**
```
📊 [AGRR Data] success: true
📊 [AGRR Data] data_count: 31
📊 [AGRR Sample] First record: {...}
```

4. **データ保存ログ:**
```
💾 [Weather Data #1] date=2024-01-01, temp=-5.0~10.0°C, precip=0.0mm, sunshine=5.5h, new_record=true
💾 [Weather Data Summary] Total: 31, New: 31, Updated: 0
```

### ステップ3: データベースの確認

```bash
# Dockerコンテナに入る
docker-compose exec web rails console

# コンソールで確認
```

```ruby
# 農場を取得
farm = Farm.first

# 天気データの件数を確認
farm.weather_location.weather_data.count

# 最近のデータを確認
farm.weather_location.weather_data.order(:date).last(5).each do |data|
  puts "#{data.date}: #{data.temperature_min}~#{data.temperature_max}°C, #{data.precipitation}mm, #{data.sunshine_hours}h"
end

# 特定の日付のデータを確認
data = farm.weather_location.weather_data.find_by(date: '2024-01-01')
puts data.inspect

# データの統計を確認
WeatherDatum.where(weather_location: farm.weather_location)
  .where("date >= ?", Date.new(2024, 1, 1))
  .average(:temperature_mean)
```

## 🐛 よくある問題と対処法

### 問題1: agrrコマンドが失敗する

**症状:**
```
❌ [AGRR Error] Command failed: ...
```

**確認:**
```bash
# agrrコマンドが存在するか
docker-compose exec web ls -la /app/lib/core/agrr

# 実行権限があるか
docker-compose exec web /app/lib/core/agrr --version
```

**対処:**
```bash
# 権限を付与
docker-compose exec web chmod +x /app/lib/core/agrr
```

### 問題2: データが保存されない

**症状:**
```
💾 [Weather Data Summary] Total: 31, New: 0, Updated: 0
```

**確認:**
- データベースのロック状態
- ディスク容量
- バリデーションエラー

```ruby
# Railsコンソールで確認
farm = Farm.first
location = farm.weather_location

# 手動でデータを作成してみる
data = WeatherDatum.new(
  weather_location: location,
  date: Date.today,
  temperature_max: 20.0,
  temperature_min: 10.0,
  temperature_mean: 15.0
)
data.valid?
data.errors.full_messages
```

### 問題3: 値が期待と異なる

**確認項目:**

1. **agrrコマンドの出力を確認:**
```bash
docker-compose exec web bash /app/scripts/debug_agrr.sh 35.68 139.77 2024-01-01 2024-01-31 > agrr_output.txt
```

2. **データベースの値と比較:**
```ruby
# 特定の日付で比較
date = Date.new(2024, 1, 15)
data = farm.weather_location.weather_data.find_by(date: date)

puts "DB: temp=#{data.temperature_min}~#{data.temperature_max}°C"
puts "DB: precip=#{data.precipitation}mm"
puts "DB: sunshine=#{data.sunshine_hours}h"
```

3. **agrrコマンドを直接実行して比較:**
```bash
docker-compose exec web /app/lib/core/agrr weather \
  --location 35.68,139.77 \
  --start-date 2024-01-15 \
  --end-date 2024-01-15 \
  --json | python3 -m json.tool
```

## 📊 ログの読み方

### 正常なログの例

```
🌤️  [Farm#1] Fetching weather data for 2024 (35.68, 139.77)
🔧 [AGRR Command] /app/lib/core/agrr weather --location 35.68,139.77 --start-date 2024-01-01 --end-date 2024-12-31 --json
📥 [AGRR Output] {"success":true,"data":{"location":{"latitude":35.68,"longitude":139.77...
📊 [AGRR Data] success: true
📊 [AGRR Data] data_count: 366
📊 [AGRR Sample] First record: {"time"=>"2024-01-01", "temperature_2m_max"=>10.5, ...}
💾 [Weather Data #1] date=2024-01-01, temp=-2.0~10.5°C, precip=0.0mm, sunshine=8.5h, new_record=true
💾 [Weather Data #366] date=2024-12-31, temp=-5.0~8.0°C, precip=2.5mm, sunshine=5.0h, new_record=true
💾 [Weather Data Summary] Total: 366, New: 366, Updated: 0
✅ [Farm#1] Saved 366 weather records for 2024
```

### エラーログの例

```
❌ [AGRR Error] Command failed: /app/lib/core/agrr weather ...
   stderr: Error: Invalid coordinates
```

## 🛠️ トラブルシューティング・チェックリスト

- [ ] agrrコマンドが実行可能か
- [ ] agrrコマンドの出力が正しいJSONか
- [ ] データ件数が期待通りか
- [ ] 温度・降水量などの値が妥当な範囲か
- [ ] データベースに正しく保存されているか
- [ ] ログレベルが DEBUG に設定されているか
- [ ] ディスク容量は十分か
- [ ] データベースのロックはないか

## 💡 問題報告時に必要な情報

問題を報告する際は、以下の情報を含めてください：

1. **実行したコマンド:**
   ```bash
   docker-compose exec web bash /app/scripts/debug_agrr.sh
   ```

2. **agrrコマンドの出力:**
   - 成功/失敗
   - JSONの構造
   - データ件数

3. **Railsログ:**
   - 🔧 AGRR Command
   - 📥 AGRR Output
   - 📊 AGRR Data
   - 💾 Weather Data

4. **データベースの状態:**
   - 保存されたレコード数
   - サンプルデータ

5. **期待される結果と実際の結果の違い**

