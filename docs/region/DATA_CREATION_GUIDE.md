# Region Data Creation Guide

## 📖 目的

AGRRプロジェクトに新しい地域（region）の参照データを追加するための完全なガイド。このドキュメントに従うことで、US regionで行ったのと同様のプロセスを、他の国や地域（EU、中国、オーストラリアなど）に適用できます。

## 🎯 概要

各regionには以下のデータが必要です：

1. **Reference Farms（参照農場）** - 主要農業地域の座標と天気データ
2. **Reference Crops（参照作物）** - 主要作物とAI生成の栽培要件
3. **Interaction Rules（相互作用ルール）** - 連作障害などのルール

**所要時間:** 約3-4時間（農場数・作物数による）

---

## 📋 前提条件

### 必要な環境
- Docker & Docker Compose（起動済み）
- Rails 8環境
- agrrバイナリ（`lib/core/agrr`）
- OpenAI APIキー（作物AI情報取得用）

### 確認コマンド
```bash
# Dockerコンテナが起動しているか確認
docker compose ps

# agrrバイナリの存在確認
ls -l lib/core/agrr

# APIキーの確認
docker compose exec web bin/rails runner "puts ENV['OPENAI_API_KEY'].present? ? 'OK' : 'NG'"
```

---

## 🚀 Step-by-Step プロセス

### Phase 1: 地域コードの決定と農場リスト作成

#### 1.1 地域コード（region code）を決定

**形式:** 2文字の小文字（ISO 3166-1 alpha-2推奨）

**例:**
- `jp` - Japan
- `us` - United States
- `cn` - China
- `au` - Australia

**今回の例:** `us`

#### 1.2 主要農業地域をリストアップ

目標件数: **30-50地域**

**調査方法:**
1. Web検索で主要農業地域を調査
2. 各地域の中心都市の緯度・経度を取得
3. Google Maps、Wikipedia等で座標を確認

**US regionの例:**
```ruby
us_reference_farms = [
  { name: 'Kern County, CA', latitude: 35.3733, longitude: -119.0187 },
  { name: 'Fresno County, CA', latitude: 36.7378, longitude: -119.7871 },
  # ... 50件
]
```

**⚠️ 重要:** 座標の精度は小数点以下4桁程度で十分

---

### Phase 2: 天気データ取得スクリプト作成

#### 2.1 データソースの選択

agrrコマンドがサポートする天気データソース：

| データソース | 対象地域 | 履歴期間 | 特徴 |
|------------|---------|---------|------|
| `openmeteo` | 全世界 | 2-3年 | 無料、高速 |
| `jma` | 日本のみ | 最近数年 | 高品質、日本気象庁 |
| `noaa-ftp` | アメリカのみ | 1901-現在（2000年以降推奨） | 無料、194ステーション |

**選択基準:**
openmeteoは無料使用では耐えられないので、その都度確認すること

#### 2.2 天気データ取得スクリプト作成

**ファイル名:** `bin/fetch_<region>_reference_weather_data`

**テンプレート:** `bin/fetch_us_reference_weather_data`をコピーして以下を変更：

```ruby
# 変更箇所1: ヘッダー
ColorLogger.log("US Reference Farms Weather Data Fetching Script (NOAA-FTP)", :blue)
# ↓
ColorLogger.log("AU Reference Farms Weather Data Fetching Script (xxxxxxxxx)", :blue)

# 変更箇所2: region条件
farms = Farm.where(is_reference: true, region: 'us')
# ↓
farms = Farm.where(is_reference: true, region: 'eu')

# 変更箇所3: データソース
'--data-source', 'noaa-ftp',
# ↓
'--data-source', 'xxxxxx', 確認結果

# 変更箇所4: 出力パス
fixture_path = Rails.root.join('db/fixtures/us_reference_weather.json')
# ↓
fixture_path = Rails.root.join('db/fixtures/au_reference_weather.json')
```

**実行権限付与:**
```bash
chmod +x bin/fetch_<region>_reference_weather_data
```

#### 2.3 テスト実行（1農場のみ）

```bash
# コンテナ内で実行
docker compose exec web bin/fetch_<region>_reference_weather_data --farm-name "<農場名>"

# 例: US region
docker compose exec web bin/fetch_us_reference_weather_data --farm-name "Kern County, CA"
```

**期待される出力:**
```
✅ Fetched XXXX data records
📄 Saved to: /app/db/fixtures/<region>_reference_weather.json
```

**⚠️ トラブルシューティング:**

| エラー | 原因 | 解決方法 |
|-------|------|---------|
| `Temporary failure in name resolution` | Docker内からインターネット接続不可 | `docker compose exec web`経由で実行 |
| `No weather data found` | 座標が不正、またはデータソースが対応していない | 座標を確認、データソースを変更 |
| `HTTP request failed` | API制限、または一時的な障害 | 時間をおいて再実行 |

#### 2.4 全農場の天気データ取得

```bash
# 全農場分を取得（時間がかかる）
docker compose exec web bin/fetch_<region>_reference_weather_data 2>&1 | tee /tmp/<region>_weather.log

# 例: 50農場 × 2秒待機 = 約100分
```

**進捗確認:**
```
[1/50] Processing: ...
[2/50] Processing: ...
```

---

### Phase 3: 作物リスト作成とシード準備

#### 3.1 主要作物をリストアップ

目標件数: **20-30作物**

**調査方法:**
1. Web検索でその国の主要農産物を調査
2. 作物名（英語）、品種、科名を整理

**US regionの例:**
```ruby
us_reference_crops = [
  { name: 'Corn', variety: 'Field Corn', groups: ['Poaceae'] },
  { name: 'Soybeans', variety: 'Standard', groups: ['Fabaceae'] },
  { name: 'Wheat', variety: 'Winter Wheat', groups: ['Poaceae'] },
  # ... 30件
]
```

**⚠️ 科名（groups）の重要性:**
- 連作障害ルール（Interaction Rules）で使用
- 一般的な科名を使用（例: Poaceae, Solanaceae, Fabaceae）

#### 3.2 シードファイル作成

**ファイル名:** `db/seeds/<region>_seeds.rb`

**テンプレート:** `db/seeds/us_seeds.rb`をコピーして以下を変更：

```ruby
# region名を全て変更
region: 'us' → region: 'au'
region: "us" → region: "au"

# ファイルパスを変更
'db/fixtures/us_reference_weather.json' → 'db/fixtures/au_reference_weather.json'
'db/fixtures/us_reference_crops.json' → 'db/fixtures/au_reference_crops.json'

# メッセージを変更
"US Reference Farms" → "AU Reference Farms"
```

#### 3.3 メインシードファイルに統合

**ファイル:** `db/seeds.rb`

以下を追加：
```ruby
# Load EU region seeds
puts ""
puts "=" * 80
puts "Loading AU region seeds..."
puts "=" * 80
load Rails.root.join('db/seeds/au_seeds.rb')
```

---

### Phase 4: AI作物情報取得と日本語問題の解決

#### 4.1 作物AI情報取得スクリプト作成

**⚠️ 重要な問題:** agrrバイナリは内部で日本語プロンプトを使用しているため、**英語のクエリでもステージ名が日本語で返される**

**ファイル名:** `bin/fetch_<region>_crops_with_agrr`

**テンプレート:** `bin/fetch_us_crops_with_agrr`をコピーして変更：

```ruby
# region条件を変更
crops = Crop.where(is_reference: true, region: 'us')
# ↓
crops = Crop.where(is_reference: true, region: 'au')
```

**実行権限付与:**
```bash
chmod +x bin/fetch_<region>_crops_with_agrr
```

#### 4.2 全作物のAI情報取得（日本語込み）

```bash
# Webサーバーが起動していることを確認
docker compose up -d web

# AI情報を取得（時間がかかる）
docker compose exec web bin/fetch_<region>_crops_with_agrr 2>&1 | tee /tmp/<region>_crops.log

# 例: 30作物 × 2秒待機 = 約60分
```

**期待される出力:**
```
✅ Saved 4 stages
⚠️  Japanese stage names detected:
⚠️    - 播種〜発芽
⚠️    - 発芽〜成長
⚠️    - 成長〜成熟
⚠️    - 成熟〜収穫
```

**⚠️ 日本語が検出されることは正常です** → 次のステップで翻訳します

---

### Phase 5: 日本語→英語翻訳

#### 5.1 翻訳マッピングの作成

**手順:**
1. ログから全ての日本語ステージ名を収集
2. 各ステージ名の意味を理解
3. 適切な英語訳を作成

**US regionで使用した翻訳マッピング（20パターン）:**

```ruby
TRANSLATION_MAP = {
  # 穀物・野菜の一般的なステージ
  "播種〜発芽" => "Planting to Germination",
  "発芽〜成長" => "Germination to Growth",
  "成長〜成熟" => "Growth to Maturity",
  "成熟〜収穫" => "Maturity to Harvest",
  
  # 移植作物（トマト、キャベツなど）
  "育苗期" => "Seedling Stage",
  "定植期" => "Transplanting Stage",
  "生育期" => "Growing Stage",
  "収穫期" => "Harvest Stage",
  
  # 果樹（リンゴ、オレンジなど）
  "開花期" => "Flowering Stage",
  "果実成長期" => "Fruit Development Stage",
  "成熟期" => "Maturity Stage",
  
  # 糖料作物・多年生作物
  "成長期" => "Growth Stage",
  "肥大期" => "Bulking Stage",
  "発芽期" => "Germination Stage",
  
  # その他
  "苗期" => "Seedling Stage",
  "発芽〜成長初期" => "Germination to Early Growth",
  "成長中期" => "Mid Growth",
  "成長〜収穫" => "Growth to Harvest",
  "発芽〜生育初期" => "Germination to Early Growing",
  "生育初期〜収穫" => "Early Growing to Harvest"
}
```

**⚠️ 重要:** 
- 作物の特性に応じて適切な訳を選ぶ
- 同じ日本語でも作物によって意味が異なる場合がある
- 不明な場合はWeb検索で農業用語を調査

#### 5.2 翻訳スクリプト作成

**ファイル名:** `bin/translate_<region>_crop_stages`

**テンプレート:** `bin/translate_us_crop_stages`をコピーして変更：

```ruby
# region条件を変更
crops = Crop.where(is_reference: true, region: 'us')
# ↓
crops = Crop.where(is_reference: true, region: 'au')

# TRANSLATION_MAPを更新（ログから収集した日本語に対応）
```

**実行権限付与:**
```bash
chmod +x bin/translate_<region>_crop_stages
```

#### 5.3 翻訳実行

```bash
docker compose exec web bin/translate_<region>_crop_stages
```

**期待される出力:**
```
✅ Oats: Translated 4 stages
✅ Tomatoes: Translated 4 stages
...
✅ All stages successfully translated!
```

**⚠️ エラー対応:**

```
⚠️ Untranslated stages:
  <作物名>: <未翻訳の日本語>
```

→ `TRANSLATION_MAP`にその日本語の訳を追加して再実行

---

### Phase 6: JSON出力とシード統合

#### 6.1 JSONエクスポートスクリプト作成

**ファイル名:** `bin/export_<region>_crops_to_json`

**テンプレート:** `bin/export_us_crops_to_json`をコピーして変更：

```ruby
# region条件を変更
crops = Crop.where(is_reference: true, region: 'us').order(:name)
# ↓
crops = Crop.where(is_reference: true, region: 'au').order(:name)

# 出力パスを変更
fixture_path = Rails.root.join('db/fixtures/us_reference_crops.json')
# ↓
fixture_path = Rails.root.join('db/fixtures/au_reference_crops.json')
```

**実行権限付与:**
```bash
chmod +x bin/export_<region>_crops_to_json
```

#### 6.2 JSON出力

```bash
docker compose exec web bin/export_<region>_crops_to_json
```

**期待される出力:**
```
📄 Saved to: /app/db/fixtures/<region>_reference_crops.json
📊 Crops: 30
📊 Total stages: 118
```

#### 6.3 英語化の確認

```bash
# ステージ名がすべて英語か確認
cat db/fixtures/<region>_reference_crops.json | jq -r '.[] | .crop_stages[] | .name' | sort -u
```

**期待される出力（すべて英語）:**
```
Flowering Stage
Germination Stage
Growing Stage
Harvest Stage
...
```

---

### Phase 7: Interaction Rules（相互作用ルール）作成

#### 7.1 連作障害ルールの定義

**必要な情報:**
- 各科（family）の連作障害の強度
- impact_ratio（1.0未満で収益減少）

**US regionの例:**
```ruby
continuous_cultivation_impacts = {
  "Solanaceae" => {
    impact_ratio: 0.6,  # 40%減少
    description: "Solanaceae continuous cultivation (Very Strong, 40% revenue decrease)"
  },
  "Poaceae" => {
    impact_ratio: 0.95,  # 5%減少
    description: "Poaceae continuous cultivation (Almost None, 5% revenue decrease)"
  }
}
```

**一般的な連作障害の強度:**

| 科名 | impact_ratio | 影響度 | 例 |
|-----|-------------|-------|---|
| Solanaceae（ナス科） | 0.6 | 非常に強い | トマト、ジャガイモ |
| Cucurbitaceae（ウリ科） | 0.65 | 非常に強い | キュウリ、スイカ |
| Brassicaceae（アブラナ科） | 0.75 | 強い | キャベツ、ブロッコリー |
| Asteraceae（キク科） | 0.75 | 強い | レタス |
| Fabaceae（マメ科） | 0.9 | 軽い | 大豆、ピーナッツ |
| Poaceae（イネ科） | 0.95 | ほとんどなし | トウモロコシ、小麦 |

#### 7.2 シードファイルでの実装

`db/seeds/<region>_seeds.rb`の該当部分を更新：

```ruby
# Extract unique families from crops
unique_families = Crop.where(is_reference: true, region: '<region>').pluck(:groups).flatten.compact.uniq.sort

# Define continuous cultivation impacts
continuous_cultivation_impacts = {
  # 上記のマッピングを記述
}

# Create interaction rules
interaction_rules_data = []
unique_families.each do |family|
  if continuous_cultivation_impacts.key?(family)
    impact = continuous_cultivation_impacts[family]
    interaction_rules_data << {
      rule_type: "continuous_cultivation",
      source_group: family,
      target_group: family,
      impact_ratio: impact[:impact_ratio],
      is_directional: true,
      is_reference: true,
      description: impact[:description]
    }
  else
    # 未定義の科は中程度として扱う
    interaction_rules_data << {
      rule_type: "continuous_cultivation",
      source_group: family,
      target_group: family,
      impact_ratio: 0.8,
      is_directional: true,
      is_reference: true,
      description: "#{family} continuous cultivation (Moderate, 20% revenue decrease)"
    }
  end
end
```

---

### Phase 8: テストと検証

#### 8.1 データベースリセットとシード実行

```bash
# データベースをクリーンな状態に
docker compose exec web rm -f storage/development.sqlite3
docker compose exec web bin/rails db:schema:load

# シード実行
docker compose exec web bin/rails db:seed 2>&1 | tee /tmp/seed_test.log
```

**期待される出力:**
```
✅ Created XX <region> reference farms with weather data
   Total weather records: XXXXXX
✅ Created XX <region> reference crops with AI data
   Total crop stages: XXX
✅ Created XX <region> interaction rules
```

#### 8.2 データ検証

```bash
# 農場と天気データの確認
docker compose exec web bin/rails runner "
farms = Farm.where(region: '<region>').includes(:weather_location).limit(3)
farms.each do |farm|
  wl = farm.weather_location
  if wl
    count = WeatherDatum.where(weather_location_id: wl.id).count
    puts \"#{farm.name}: #{count} weather records\"
  end
end
"

# 作物とステージ名の確認（英語化チェック）
docker compose exec web bin/rails runner "
crops = Crop.where(region: '<region>').limit(3)
crops.each do |crop|
  puts \"#{crop.name}:\"
  crop.crop_stages.order(:order).each { |s| puts \"  #{s.order}. #{s.name}\" }
end
"
```

**⚠️ 確認ポイント:**
- [ ] 天気データが存在する
- [ ] ステージ名が全て英語になっている
- [ ] 日本語が混入していない

---

## 🔧 発生した問題と解決策

### 問題1: agrrコマンドが日本語でステージ名を返す

**原因:** agrrバイナリ内部で日本語プロンプトを使用

**解決策:** 
1. 日本語のまま取得
2. 翻訳マッピングを作成
3. スクリプトで一括翻訳

**教訓:** 完全に自動化できない部分があることを前提にする

### 問題2: WeatherLocationのtimezoneがnull

**原因:** NOAA-FTPはtimezone情報を提供しない

**解決策:** デフォルト値を設定
```ruby
wl.timezone = wl_data['timezone'] || 'America/New_York'
```

**教訓:** データソースごとに提供される情報が異なる

### 問題3: Docker内からインターネット接続失敗

**原因:** ホストのネットワーク設定

**解決策:** `docker compose exec web`経由で実行

**教訓:** コンテナ内部の実行環境を確認

### 問題4: スキーマロード時のFOREIGN KEY constraint

**原因:** SQLiteの外部キー制約

**解決策:** データベースファイルを削除してから再作成
```bash
rm -f storage/development.sqlite3
bin/rails db:schema:load
```

---

## 📊 成果物チェックリスト

### ファイル構成

```
db/
├── fixtures/
│   ├── <region>_reference_weather.json  # 天気データ
│   └── <region>_reference_crops.json    # 作物データ（英語）
└── seeds/
    └── <region>_seeds.rb                # シードスクリプト

bin/
├── fetch_<region>_reference_weather_data  # 天気取得
├── fetch_<region>_crops_with_agrr         # 作物取得
├── translate_<region>_crop_stages         # 翻訳
└── export_<region>_crops_to_json          # JSON出力
```

### データ内容

- [ ] Reference Farms: 30-50件
- [ ] Weather Data: 数十万レコード（25年分程度）
- [ ] Reference Crops: 20-30件
- [ ] Crop Stages: すべて英語
- [ ] Interaction Rules: 10-20件

---

## 🌍 他の地域への適用例

### EU (European Union)

**データソース:** `openmeteo`

**主要農業国:**
- フランス（小麦、ワイン）
- ドイツ（ビート、ジャガイモ）
- イタリア（オリーブ、トマト）
- スペイン（オレンジ、オリーブ）
- オランダ（花卉、野菜）

**主要作物例:**
- Wheat, Barley, Corn, Sugar Beets
- Grapes (Wine), Olives, Tomatoes, Potatoes
- Sunflowers, Rapeseed

### CN (China)

**データソース:** `openmeteo`

**主要農業地域:**
- 黒龍江省（大豆、米）
- 河南省（小麦、トウモロコシ）
- 四川省（米、茶）
- 山東省（野菜、果物）

**主要作物例:**
- Rice, Wheat, Corn, Soybeans
- Cotton, Sweet Potatoes, Peanuts
- Tea, Vegetables

### AU (Australia)

**データソース:** `openmeteo`

**主要農業地域:**
- New South Wales（小麦、羊）
- Victoria（乳製品、果物）
- Queensland（サトウキビ、牛）
- Western Australia（小麦、羊）

**主要作物例:**
- Wheat, Barley, Canola
- Sugarcane, Cotton, Grapes
- Beef, Wool, Dairy

---

## 💡 ベストプラクティス

### 1. データ収集

- **信頼できる情報源を使用:** 政府統計、農業省のデータ
- **座標の精度:** 小数点以下4桁で十分
- **作物の選定:** その国の主要輸出品を優先

### 2. スクリプト実行

- **段階的に実行:** 一度に全データを取得せず、1-2件でテスト
- **ログを保存:** `tee`コマンドでログファイルに記録
- **進捗確認:** 長時間実行の場合は定期的に確認

### 3. 翻訳作業

- **専門用語辞書を活用:** 農業用語は専門的なので注意
- **一貫性を保つ:** 同じ日本語には同じ英語訳を使用
- **レビュー:** 翻訳後、必ず農業の専門家に確認

### 4. テスト

- **段階的なテスト:** 各フェーズ後に必ず動作確認
- **データ検証:** SQLクエリで件数、内容を確認
- **クリーンな環境:** 本番前に新しいDBで最終テスト

---

## 📝 チェックシート

プロセス完了前に以下を確認：

### データ品質
- [ ] 農場の座標が正確（Google Mapsで確認）
- [ ] 天気データが期待される期間をカバー
- [ ] 作物のステージ名に日本語が含まれていない
- [ ] 科名（groups）が正しく設定されている
- [ ] Interaction Rulesが論理的に妥当

### ファイル
- [ ] フィクスチャJSONファイルが生成されている
- [ ] シードファイルが正しく動作する
- [ ] スクリプトに実行権限がある
- [ ] ドキュメントが更新されている

### 動作確認
- [ ] `rails db:seed`が正常に完了する
- [ ] データベースに正しい件数のレコードが存在
- [ ] 天気データが参照できる
- [ ] 作物情報が正しく表示される

---

## 🆘 トラブルシューティング

### よくある問題

1. **天気データが取得できない**
   - データソースを変更（`openmeteo` ↔ `jma` ↔ `noaa-ftp`）
   - 座標を確認
   - 日付範囲を調整

2. **翻訳マッピングが不足**
   - ログから未翻訳の日本語を抽出
   - Web検索で適切な英語訳を調査
   - TRANSLATION_MAPに追加

3. **シード実行時のエラー**
   - データベースをクリーンアップ
   - 外部キー制約をチェック
   - バリデーションエラーを確認

4. **パフォーマンス問題**
   - バッチサイズを調整
   - 待機時間を増やす
   - バックグラウンド実行を検討

---

## 📚 参考資料

### 農業データ
- FAO（国連食糧農業機関）: https://www.fao.org/
- World Bank Agriculture: https://data.worldbank.org/topic/agriculture-and-rural-development
- 各国の農業省統計

### 天気データ
- Open-Meteo: https://open-meteo.com/
- NOAA: https://www.noaa.gov/
- 気象庁: https://www.jma.go.jp/

### 農業用語
- Agricultural Glossary: https://www.fao.org/faoterm/
- Crop Science Terminology

---

## 📞 サポート

問題が発生した場合：

1. このドキュメントのトラブルシューティングセクションを確認
2. ログファイルを確認（`/tmp/*.log`）
3. エラーメッセージをWeb検索
4. プロジェクトのIssueを確認

---

**最終更新:** 2025-10-18  
**バージョン:** 1.0  
**作成者:** AGRR Development Team

