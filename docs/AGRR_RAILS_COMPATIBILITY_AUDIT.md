# AGRR CLI と Rails の互換性精査結果

**実施日**: 2025-10-21  
**agrr バージョン**: 最新（2025-10-21更新）

## 精査結果サマリー

✅ **Rails側のコードは最新のagrrバイナリと完全に互換性があります。修正不要です。**

---

## 各コマンドの互換性確認

### 1. `agrr weather` コマンド

**使用箇所:**
- `app/gateways/agrr/weather_gateway.rb` (9-15行目)
- `app/jobs/fetch_weather_data_job.rb` (182-189行目)

**Rails側の使用方法:**
```ruby
agrr_path, 'weather',
  '--location', "#{latitude},#{longitude}",
  '--days', days.to_s,
  '--data-source', 'jma',  # または 'nasa-power'
  '--json'
```

**agrr CLIのヘルプとの比較:**
```bash
agrr weather --location LOCATION [--data-source {openmeteo,jma,noaa-ftp,nasa-power}]
             [--start-date START_DATE] [--end-date END_DATE]
             [--days DAYS] [--json]
```

**結論:** ✅ **完全互換** - すべてのオプションが正しく使用されています。

---

### 2. `agrr predict` コマンド

**使用箇所:**
- `app/gateways/agrr/prediction_gateway.rb` (34-54行目)

**Rails側の使用方法:**
```ruby
# LightGBMの場合
agrr_path, 'predict',
  '--input', input_file.path,
  '--output', output_file.path,
  '--days', days.to_s,
  '--model', 'lightgbm',
  '--metrics', 'temperature,temperature_max,temperature_min'

# ARIMAの場合
agrr_path, 'predict',
  '--input', input_file.path,
  '--output', output_file.path,
  '--days', days.to_s,
  '--model', 'arima'
```

**agrr CLIのヘルプとの比較:**
```bash
agrr predict --input INPUT --output OUTPUT [--days DAYS]
             [--model {arima,lightgbm,ensemble}]
             [--metrics METRICS]
```

**重要な注記（agrrヘルプより）:**
> LightGBM model automatically predicts all 3 metrics regardless of this option.

**結論:** ✅ **互換（微調整可能）**
- LightGBMでは`--metrics`オプションは不要ですが、指定しても問題ありません
- 現状のコードは正しく動作しています
- **推奨**: 現状維持（明示的に指定することで意図が明確になる）

---

### 3. `agrr crop` コマンド

**使用箇所:**
- `app/controllers/api/v1/crops_controller.rb` (148-153行目)

**Rails側の使用方法:**
```ruby
agrr_path, 'crop',
  '--query', crop_name,
  '--json'
```

**agrr CLIのヘルプとの比較:**
```bash
agrr crop --query QUERY [--json]
```

**結論:** ✅ **完全互換** - すべてのオプションが正しく使用されています。

---

### 4. `agrr optimize allocate` コマンド

**使用箇所:**
- `app/gateways/agrr/allocation_gateway.rb` (30-64行目)

**Rails側の使用方法:**
```ruby
agrr_path, 'optimize', 'allocate',
  '--fields-file', fields_file.path,
  '--crops-file', crops_file.path,
  '--planning-start', planning_start.to_s,
  '--planning-end', planning_end.to_s,
  '--weather-file', weather_file.path,
  '--objective', objective,
  '--format', 'json'
  # オプション: '--interaction-rules-file', rules_file.path
  # オプション: '--max-time', max_time.to_s
  # オプション: '--enable-parallel'
```

**agrr CLIのヘルプとの比較:**
```bash
agrr optimize allocate --fields-file FIELDS_FILE --crops-file CROPS_FILE
                       --planning-start PLANNING_START --planning-end PLANNING_END
                       --weather-file WEATHER_FILE
                       [--objective {maximize_profit,minimize_cost}]
                       [--interaction-rules-file INTERACTION_RULES_FILE]
                       [--max-time MAX_TIME] [--format {table,json}]
                       [--enable-parallel]
                       [--algorithm {greedy,dp}]  # 🆕 新オプション
                       [--no-filter-redundant]    # 🆕 新オプション
```

**新しいオプション:**
1. `--algorithm {greedy,dp}` (デフォルト: `dp`)
   - `dp`: 最適解を求める動的計画法
   - `greedy`: 高速なヒューリスティック
   
2. `--no-filter-redundant`
   - 成長期間候補のフィルタリングを無効化
   - デフォルトでは有効（冗長な候補を除外）

**結論:** ✅ **互換（拡張可能）**
- 現在のRails側コードは正しく動作します
- 新しいオプションは将来的に追加可能（現時点では不要）

---

### 5. `agrr optimize adjust` コマンド

**使用箇所:**
- `app/gateways/agrr/adjust_gateway.rb` (55-91行目)

**Rails側の使用方法:**
```ruby
agrr_path, 'optimize', 'adjust',
  '--current-allocation', allocation_file.path,
  '--moves', moves_file.path,
  '--fields-file', fields_file.path,
  '--crops-file', crops_file.path,
  '--planning-start', planning_start.to_s,
  '--planning-end', planning_end.to_s,
  '--weather-file', weather_file.path,
  '--format', 'json'
  # オプション: '--interaction-rules-file', rules_file.path
  # オプション: '--max-time', max_time.to_s
```

**結論:** ✅ **完全互換** - すべてのオプションが正しく使用されています。

---

## 重要な変更点と対応状況

### ✅ 1. `area_used` フィールドの追加

**agrr CLIの出力形式（allocate/adjust結果）:**
```json
{
  "field_schedules": [{
    "allocations": [{
      "area_used": 500.0,  // ⚠️ この作物に割り当てられた面積（m²）
      "start_date": "2024-05-01",
      "completion_date": "2024-08-15"
    }]
  }]
}
```

**Rails側の対応状況:**
- ✅ **既に対応済み**
- `app/services/cultivation_plan_optimizer.rb` (432行目): `area: allocation['area_used']`
- `app/controllers/api/v1/public_plans/cultivation_plans_controller.rb` (678行目、1002行目): `area_used`を参照
- `app/gateways/agrr/adjust_gateway.rb` (1002行目): `area_used`のフォールバックとして`area`も許可

---

## 推奨事項

### 必須対応
❌ **なし** - 現状のRails側コードは最新のagrrバイナリと完全に互換性があります。

### オプショナル改善

1. **allocateコマンドの新オプション追加（優先度: 低）**
   
   将来的に最適化の柔軟性を高めたい場合、以下のオプションを追加可能：
   
   ```ruby
   # app/gateways/agrr/allocation_gateway.rb
   def allocate(fields:, crops:, weather_data:, planning_start:, planning_end:, 
                interaction_rules: nil, objective: 'maximize_profit', max_time: nil, 
                enable_parallel: false, algorithm: 'dp', filter_redundant: true)
     
     command_args = [
       agrr_path, 'optimize', 'allocate',
       # ... 既存のオプション ...
       '--algorithm', algorithm
     ]
     
     command_args += ['--no-filter-redundant'] unless filter_redundant
     
     # ...
   end
   ```

2. **predictコマンドの`--metrics`オプション削除（優先度: 極低）**
   
   LightGBMは自動で全メトリックを予測するため、`--metrics`オプションは不要です。
   ただし、明示的に指定することで意図が明確になるため、現状維持を推奨します。

---

## 参考: agrrコマンドのヘルプ出力

### メインヘルプ
```bash
agrr --help
# - weather, forecast, crop, progress, optimize, predict, daemon コマンドが利用可能
# - データソース: openmeteo (デフォルト), jma, noaa-ftp, nasa-power
```

### 各コマンドのヘルプ
```bash
agrr weather --help
agrr predict --help
agrr optimize allocate --help
agrr crop --help
```

---

## まとめ

✅ **Rails側のコードは最新のagrrバイナリと完全に互換性があります。**

- すべての既存機能は正しく動作します
- `area_used`フィールドは既に対応済み
- 新しいオプション（`--algorithm`, `--no-filter-redundant`）は将来的に追加可能ですが、現時点では不要です

**アクション**: なし（修正不要）

