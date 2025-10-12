# 🐛 デバッグ用ログ追加 - クイックスタート

agrrの結果がおかしい場合の問題切り分けのために、詳細なログを追加しました。

## 📝 追加されたログ

### 1. agrrコマンドの実行ログ
```
🔧 [AGRR Command] /app/lib/core/agrr weather --location 35.68,139.77 ...
```

### 2. agrrコマンドの生の出力
```
📥 [AGRR Output] {"success":true,"data":{...}}
```

### 3. データ検証ログ
```
📊 [AGRR Data] success: true
📊 [AGRR Data] data_count: 31
📊 [AGRR Sample] First record: {...}
```

### 4. データ保存の詳細
```
💾 [Weather Data #1] date=2024-01-01, temp=-5.0~10.0°C, precip=0.0mm, sunshine=5.5h, new_record=true
💾 [Weather Data Summary] Total: 31, New: 31, Updated: 0
```

## 🚀 クイックスタート

### ステップ1: ログレベルを変更（済み）

`config/environments/development.rb` で既に変更済み：
```ruby
config.log_level = :debug
```

### ステップ2: コンテナを再起動

```bash
docker-compose restart web
```

### ステップ3: agrrコマンドをテスト

```bash
# デバッグスクリプトを実行
docker-compose exec web bash /app/scripts/debug_agrr.sh

# カスタムパラメータでテスト
docker-compose exec web bash /app/scripts/debug_agrr.sh 35.68 139.77 2024-01-01 2024-01-31
```

### ステップ4: Railsログを監視

```bash
# すべてのログを監視
docker-compose logs -f web

# agrrログのみをフィルタ
docker-compose logs -f web | grep -E "(AGRR|Weather|💾|📊|🔧)"
```

### ステップ5: ログを確認

```bash
# ログサマリーを表示
docker-compose exec web bash /app/scripts/check_logs.sh
```

## 📖 詳細なデバッグガイド

完全なデバッグ手順は以下を参照：
- 📖 **[デバッグガイド](docs/DEBUG_GUIDE.md)**

## 🔍 問題の切り分け方

### ケース1: agrrコマンド自体の問題

**症状:**
- `🔧 [AGRR Command]` のログは出るが、`❌ [AGRR Error]` が出る

**確認:**
```bash
# agrrコマンドを直接実行
docker-compose exec web /app/lib/core/agrr weather \
  --location 35.68,139.77 \
  --start-date 2024-01-01 \
  --end-date 2024-01-31 \
  --json
```

**対処:**
- agrrコマンドのバグ
- 座標が不正
- APIがダウン

### ケース2: データ形式の問題

**症状:**
- `📥 [AGRR Output]` は出るが、`📊 [AGRR Data]` で異常な値

**確認:**
```bash
# JSONを整形して確認
docker-compose exec web bash /app/scripts/debug_agrr.sh | grep "Parsed Data" -A 50
```

**対処:**
- agrrコマンドの出力形式が変わった
- JSONパースエラー

### ケース3: データベース保存の問題

**症状:**
- `📊 [AGRR Data]` は正常だが、`💾 [Weather Data Summary]` で保存されない

**確認:**
```bash
# Railsコンソールで確認
docker-compose exec web rails console
```

```ruby
# データベースの状態を確認
WeatherDatum.count
WeatherLocation.count

# バリデーションエラーを確認
data = WeatherDatum.new(
  weather_location: WeatherLocation.first,
  date: Date.today,
  temperature_max: 20.0
)
data.valid?
data.errors.full_messages
```

**対処:**
- バリデーションエラー
- データベースロック
- ディスク容量不足

## 🛠️ 便利なコマンド

```bash
# ログをリアルタイム監視（agrrのみ）
docker-compose logs -f web | grep -E "(AGRR|Weather|💾|📊|🔧)"

# エラーログのみ表示
docker-compose logs -f web | grep -E "(ERROR|Error|❌)"

# 最近のログサマリー
docker-compose exec web bash /app/scripts/check_logs.sh

# agrrコマンドのテスト
docker-compose exec web bash /app/scripts/debug_agrr.sh

# Railsコンソールで確認
docker-compose exec web rails console
```

## 💡 トラブルシューティング

### ログが出ない場合

```bash
# ログレベルを確認
docker-compose exec web rails runner 'puts Rails.logger.level'

# 0 = debug, 1 = info, 2 = warn, 3 = error

# コンテナを再起動
docker-compose restart web
```

### 古いログをクリア

```bash
# ログファイルをクリア
docker-compose exec web bash -c "> log/development.log"

# 新しいログを監視
docker-compose logs -f web
```

## 📊 ログの見方

### 正常な場合
```
🌤️  [Farm#1] Fetching weather data for 2024 (35.68, 139.77)
🔧 [AGRR Command] /app/lib/core/agrr weather ...
📥 [AGRR Output] {"success":true,...}
📊 [AGRR Data] success: true
📊 [AGRR Data] data_count: 366
💾 [Weather Data #1] date=2024-01-01, temp=-2.0~10.5°C, ...
💾 [Weather Data Summary] Total: 366, New: 366, Updated: 0
✅ [Farm#1] Saved 366 weather records for 2024
```

### エラーの場合
```
🌤️  [Farm#1] Fetching weather data for 2024 (35.68, 139.77)
🔧 [AGRR Command] /app/lib/core/agrr weather ...
❌ [AGRR Error] Command failed: ...
   stderr: Error: Invalid coordinates
```

## 🔗 関連ドキュメント

- 📖 [デバッグガイド（詳細版）](docs/DEBUG_GUIDE.md)
- 📖 [テストガイド](docs/TEST_GUIDE.md)
- 📖 [AWSデプロイガイド](docs/AWS_DEPLOY.md)

## 📝 メモ

- ログレベルは既に `debug` に設定済み
- `scripts/debug_agrr.sh` でagrrコマンドを単体テスト可能
- `scripts/check_logs.sh` でログサマリーを確認可能
- すべてのデバッグ用ログには絵文字プレフィックスがあります
  - 🔧 = コマンド実行
  - 📥 = データ受信
  - 📊 = データ検証
  - 💾 = データ保存
  - ❌ = エラー
  - ✅ = 成功

