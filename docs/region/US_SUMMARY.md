# US Region Data Creation Summary

## 📊 実施結果

**実施日:** 2025年10月18日  
**所要時間:** 約3時間  
**対象地域:** United States (region: `us`)

---

## 🎯 成果物

### データ量

| カテゴリ | 件数 | 詳細 |
|---------|-----|------|
| **Reference Farms** | 50件 | 10州の主要農業郡 |
| **Weather Records** | 430,361件 | 2000-2025年（約25年分） |
| **Reference Crops** | 30作物 | 穀物、野菜、果樹、ナッツ類 |
| **Crop Stages** | 118ステージ | 全て英語に翻訳済み |
| **Interaction Rules** | 16ルール | 9つの科の連作障害 |

### ファイル

```
db/fixtures/
├── us_reference_weather.json    (430,361レコード, ~150MB)
└── us_reference_crops.json      (30作物, 118ステージ)

db/seeds/
└── us_seeds.rb                  (976行)

bin/
├── fetch_us_reference_weather_data
├── fetch_us_crops_with_agrr
├── translate_us_crop_stages
└── export_us_crops_to_json
```

---

## 🏛️ Reference Farms（50件）

### 州別内訳

| 州 | 農場数 | 主要作物 |
|---|-------|---------|
| California (CA) | 5 | ブドウ、アーモンド、野菜 |
| Iowa (IA) | 5 | トウモロコシ、大豆 |
| Illinois (IL) | 5 | トウモロコシ、大豆 |
| Nebraska (NE) | 5 | トウモロコシ、牛肉 |
| Minnesota (MN) | 5 | トウモロコシ、大豆、乳製品 |
| Texas (TX) | 5 | 牛肉、綿花 |
| Kansas (KS) | 5 | 小麦 |
| North Dakota (ND) | 5 | 小麦、大豆 |
| South Dakota (SD) | 5 | トウモロコシ、牛肉 |
| Wisconsin (WI) | 5 | 乳製品 |

### 天気データソース

**NOAA-FTP** (National Oceanic and Atmospheric Administration)
- 194ステーション（全50州）
- 無料、登録不要
- 1901年から現在まで（2000年以降推奨）
- 年ごとに自動分割取得

**含まれるデータ:**
- temperature_max, temperature_min, temperature_mean
- wind_speed

**含まれないデータ:**
- precipitation (null)
- sunshine_hours (null)
- weather_code (null)

---

## 🌾 Reference Crops（30作物）

### カテゴリ別

#### 穀物（8作物）
1. Corn (Field Corn) - Poaceae
2. Wheat (Winter Wheat) - Poaceae
3. Soybeans (Standard) - Fabaceae
4. Rice (Long Grain) - Poaceae
5. Oats (Standard) - Poaceae
6. Barley (Standard) - Poaceae
7. Sorghum (Grain) - Poaceae
8. Rye (Standard) - Poaceae

#### 野菜（9作物）
9. Tomatoes (Processing) - Solanaceae
10. Potatoes (Russet) - Solanaceae
11. Lettuce (Iceberg) - Asteraceae
12. Broccoli (Standard) - Brassicaceae
13. Cabbage (Green) - Brassicaceae
14. Carrots (Standard) - Apiaceae
15. Onions (Yellow) - Amaryllidaceae
16. Bell Peppers (Green) - Solanaceae
17. Cucumbers (Slicing) - Cucurbitaceae

#### 果物（5作物）
18. Apples (Red Delicious) - Rosaceae
19. Oranges (Valencia) - Rutaceae
20. Grapes (Wine) - Vitaceae
21. Strawberries (June-bearing) - Rosaceae
22. Blueberries (Highbush) - Ericaceae
23. Watermelon (Seedless) - Cucurbitaceae

#### ナッツ類（3作物）
24. Almonds (Nonpareil) - Rosaceae
25. Pistachios (Kerman) - Anacardiaceae
26. Walnuts (Chandler) - Juglandaceae

#### 工芸作物・その他（5作物）
27. Cotton (Upland Cotton) - Malvaceae
28. Peanuts (Runner) - Fabaceae
29. Sugar Beets (Standard) - Amaranthaceae
30. Sugarcane (Standard) - Poaceae

### 詳細データ作成済み（5作物）

以下の5作物は`db/seeds/us_seeds.rb`で完全な栽培要件を定義：

1. **Corn** - 4ステージ（Planting, Vegetative Growth, Reproductive Growth, Harvest）
2. **Soybeans** - 4ステージ
3. **Wheat** - 4ステージ
4. **Cotton** - 4ステージ
5. **Rice** - 4ステージ

### AI生成データ（25作物）

残り25作物はagrrコマンド + AI生成：
- 各作物3-4ステージ
- 温度要件、日照要件、GDD要件を含む

---

## 🔄 Interaction Rules（16ルール）

### 連作障害の影響度

| 科名 | impact_ratio | 影響度 | 該当作物例 |
|-----|-------------|-------|----------|
| Solanaceae | 0.6 | 非常に強い（40%減） | Tomatoes, Potatoes, Bell Peppers |
| Cucurbitaceae | 0.65 | 非常に強い（35%減） | Cucumbers, Watermelon |
| Brassicaceae | 0.75 | 強い（25%減） | Broccoli, Cabbage |
| Asteraceae | 0.75 | 強い（25%減） | Lettuce |
| Apiaceae | 0.8 | 中程度（20%減） | Carrots |
| Amaryllidaceae | 0.85 | 軽い（15%減） | Onions |
| Amaranthaceae | 0.9 | 軽い（10%減） | Sugar Beets |
| Fabaceae | 0.9 | 軽い（10%減） | Soybeans, Peanuts |
| Poaceae | 0.95 | ほとんどなし（5%減） | Corn, Wheat, Rice, Oats, Barley |

その他の科（Rosaceae, Rutaceae, Vitaceae, Ericaceae, Malvaceae, Anacardiaceae, Juglandaceae）は中程度（0.8）として設定。

---

## 🔧 実施プロセス

### Phase 1: 天気データ取得

**スクリプト:** `bin/fetch_us_reference_weather_data`

```bash
# テスト（1農場）
docker compose exec web bin/fetch_us_reference_weather_data --farm-name "Kern County, CA"
# 結果: 9,366レコード（約3分）

# 全農場（50件）
docker compose exec web bin/fetch_us_reference_weather_data
# 結果: 430,361レコード（約100分）
```

**データソース:** NOAA-FTP

### Phase 2: 作物AI情報取得（日本語）

**スクリプト:** `bin/fetch_us_crops_with_agrr`

```bash
docker compose exec web bin/fetch_us_crops_with_agrr
# 結果: 25作物、98ステージ（日本語）（約60分）
```

**検出された日本語:** 20パターン

### Phase 3: 日本語→英語翻訳

**スクリプト:** `bin/translate_us_crop_stages`

**翻訳マッピング:** 20パターンを手動作成

```bash
docker compose exec web bin/translate_us_crop_stages
# 結果: 98ステージを英語化（即時）
```

**翻訳例:**
- 播種〜発芽 → Planting to Germination
- 育苗期 → Seedling Stage
- 開花期 → Flowering Stage

### Phase 4: JSON出力

**スクリプト:** `bin/export_us_crops_to_json`

```bash
docker compose exec web bin/export_us_crops_to_json
# 出力: db/fixtures/us_reference_crops.json
```

### Phase 5: シード統合

**ファイル:** `db/seeds/us_seeds.rb`

- 天気データフィクスチャの読み込み
- 作物データフィクスチャの読み込み
- Interaction Rules生成

### Phase 6: テスト

```bash
docker compose exec web rm -f storage/development.sqlite3
docker compose exec web bin/rails db:schema:load db:seed
# 結果: 成功
```

---

## ⚠️ 遭遇した問題と解決

### 問題1: agrrが日本語でステージ名を返す

**原因:** agrrバイナリ内部の日本語プロンプト

**解決:**
1. 日本語のまま取得
2. 翻訳マッピング作成（20パターン）
3. `bin/translate_us_crop_stages`で一括翻訳

### 問題2: WeatherLocationのtimezoneがnull

**原因:** NOAA-FTPはtimezone情報を提供しない

**解決:** デフォルト値を設定
```ruby
wl.timezone = wl_data['timezone'] || 'America/New_York'
```

### 問題3: Docker内からインターネット接続失敗

**原因:** ホストのネットワーク設定

**解決:** `docker compose exec web`経由で実行

---

## 📈 パフォーマンス

### 処理時間

| 処理 | 対象 | 所要時間 |
|-----|------|---------|
| 天気データ取得（1農場） | 9,366レコード | 約3分 |
| 天気データ取得（50農場） | 430,361レコード | 約100分 |
| 作物AI情報取得（25作物） | 98ステージ | 約60分 |
| 翻訳処理 | 98ステージ | <1分 |
| JSON出力 | 30作物 | <1分 |
| シード実行 | 全データ | 約5分 |

### ファイルサイズ

| ファイル | サイズ |
|---------|-------|
| us_reference_weather.json | ~150MB |
| us_reference_crops.json | ~100KB |
| us_seeds.rb | ~50KB |

---

## ✅ 検証結果

### データ整合性

```sql
-- 農場数
SELECT COUNT(*) FROM farms WHERE region = 'us' AND is_reference = true;
-- 結果: 50

-- 天気レコード数
SELECT COUNT(*) FROM weather_data 
WHERE weather_location_id IN (
  SELECT weather_location_id FROM farms WHERE region = 'us'
);
-- 結果: 430,361

-- 作物数
SELECT COUNT(*) FROM crops WHERE region = 'us' AND is_reference = true;
-- 結果: 30

-- ステージ数
SELECT COUNT(*) FROM crop_stages 
WHERE crop_id IN (
  SELECT id FROM crops WHERE region = 'us' AND is_reference = true
);
-- 結果: 118

-- 英語化確認（日本語が0件であることを確認）
SELECT name FROM crop_stages 
WHERE crop_id IN (
  SELECT id FROM crops WHERE region = 'us' AND is_reference = true
) AND name REGEXP '[一-龯ぁ-んァ-ン]';
-- 結果: 0件
```

### サンプルデータ

**農場:**
```
Kern County, CA: 9,366 weather records
Fresno County, CA: 9,368 weather records
Tulare County, CA: 9,366 weather records
```

**作物:**
```
Corn:
  1. Planting
  2. Vegetative Growth
  3. Reproductive Growth
  4. Harvest

Tomatoes:
  1. Seedling Stage
  2. Transplanting Stage
  3. Growing Stage
  4. Harvest Stage

Sugarcane:
  1. Germination Stage
  2. Growth Stage
  3. Maturity Stage
  4. Harvest Stage
```

---

## 🎓 教訓

### うまくいったこと

1. **段階的なアプローチ:** 1件でテスト → 全件取得
2. **ログ保存:** `tee`コマンドで進捗を記録
3. **翻訳マッピング:** 再利用可能なパターンを作成
4. **フィクスチャ分離:** JSON化でシード高速化

### 改善点

1. **天気データの完全性:** NOAA-FTPはprecipitation等を提供しない
   - 解決案: OpenMeteoと併用を検討
2. **AI生成の言語:** 日本語プロンプトを英語化すべき
   - 現状: 翻訳プロセスで対応
3. **エラーハンドリング:** より詳細なエラーメッセージ
4. **進捗表示:** 大量データ処理時のプログレスバー

---

## 📚 次のステップ

### 他の地域への展開

このプロセスは以下の地域にも適用可能：

1. **EU (European Union)**
   - 30-40農場（フランス、ドイツ、イタリア、スペイン等）
   - データソース: OpenMeteo
   - 主要作物: 小麦、ワイン、オリーブ

2. **CN (China)**
   - 30-40農場（黒龍江省、河南省、四川省等）
   - データソース: OpenMeteo
   - 主要作物: 米、小麦、茶

3. **AU (Australia)**
   - 20-30農場（NSW, VIC, QLD等）
   - データソース: OpenMeteo
   - 主要作物: 小麦、サトウキビ、牛肉

### 機能拡張

- [ ] 天気予測データの統合
- [ ] より詳細な土壌データ
- [ ] 病害虫情報
- [ ] 市場価格データ

---

**作成日:** 2025-10-18  
**作成者:** AGRR Development Team  
**関連ドキュメント:** [REGION_DATA_CREATION_GUIDE.md](./REGION_DATA_CREATION_GUIDE.md)

