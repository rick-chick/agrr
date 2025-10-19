# Region Data Creation Guide

## 📖 目的

AGRRプロジェクトに新しい地域（region）の参照データを追加するための完全なガイド。このドキュメントに従うことで、任意の国や地域（インド、中国、ブラジル、オーストラリアなど）にシステムを展開できます。

## 🌍 最重要原則

**その地域のユーザーが母国語で100%利用できるシステムを作る**

- ✅ 農場名・作物名・品種名・ステージ名 → **その地域の言語**
- ✅ UI翻訳（ボタン、メッセージ等） → **その地域の言語**
- ❌ 科名（groups）のみ → 国際学名（Poaceae等）

**例:** 日本→日本語、インド→ヒンディー語、中国→中国語、ブラジル→ポルトガル語

## 🎯 概要

各regionには以下のデータが必要です：

1. **Reference Farms（参照農場）** - 主要農業地域の座標と天気データ（地名はローカル言語）
2. **Reference Crops（参照作物）** - 主要作物とAI生成の栽培要件（作物名・品種名・ステージ名はローカル言語）
3. **Interaction Rules（相互作用ルール）** - 連作障害などのルール
4. **i18n翻訳ファイル** - 14個のYMLファイル（UIをローカル言語化）

**所要時間:** 約4-5時間（農場数・作物数による）

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

## 🚀 Step-by-Step プロセス（全10フェーズ）

### Phase 1: 地域コードの決定と農場リスト作成

#### 1.1 地域コード（region code）を決定

**形式:** 2文字の小文字（ISO 3166-1 alpha-2推奨）

**例:** `jp`(日本), `us`(米国), `in`(インド), `cn`(中国), `br`(ブラジル)

#### 1.2 主要農業地域をリストアップ（30-50地域）

Web検索で主要農業地域を調査し、緯度・経度を取得（Google Maps等）。**地名は地域の言語で記載**。

**農場リストの例:**

```ruby
<region>_reference_farms = [
  { name: '<地域の言語での地名>', latitude: XX.XXXX, longitude: XX.XXXX },
  # 30-50件
]
```

参考: 既存マイグレーション `db/migrate/*seed*.rb` を確認

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

参考: `bin/fetch_us_reference_weather_data` をコピーして `region`, データソース、出力パスを変更

**実行権限付与:**
```bash
chmod +x bin/fetch_<region>_reference_weather_data
```

#### 2.3 天気データ取得実行

```bash
# テスト（1農場のみ）
docker compose exec web bin/fetch_<region>_reference_weather_data --farm-name "<農場名>"

# 全農場（時間がかかる: 50農場 × 2秒 = 約100分）
docker compose exec web bin/fetch_<region>_reference_weather_data 2>&1 | tee /tmp/<region>_weather.log
```

---

### Phase 3: 作物リスト作成とシード準備

#### 3.1 主要作物のリストアップ（20-30作物）

Web検索でその地域の主要作物を調査。作物名・品種名は**その地域の言語**、科名（groups）は**国際学名**（Poaceae等）。

参考: 既存マイグレーション `db/migrate/*seed*.rb` を確認


---

### Phase 4: AI作物情報取得と日本語問題の解決

#### 4.1 作物AI情報取得スクリプト作成

**⚠️ 重要:**
1. **AI取得は英語の作物名を使用**（agrrの仕様）
2. **データベースにはその地域の言語で保存**（マイグレーション作成時）

**⚠️ 重要な問題:** agrrバイナリは内部で日本語プロンプトを使用しているため、**英語のクエリでもステージ名が日本語で返される**

**ファイル名:** `bin/fetch_<region>_crops_with_agrr`

参考: `bin/fetch_us_crops_with_agrr` をコピーして `region` を変更

**実行権限付与:**
```bash
chmod +x bin/fetch_<region>_crops_with_agrr
```

#### 4.2 AI情報取得実行

```bash
docker compose exec web bin/fetch_<region>_crops_with_agrr 2>&1 | tee /tmp/<region>_crops.log
```

**⚠️ 日本語ステージ名が生成される** → 次フェーズで翻訳

---

### Phase 5: 日本語→ローカル言語翻訳

**🌍 重要な方針:**
各地域は**その地域のローカル言語**を使用します。

**言語選択の原則:**
- その地域の人々が**最も読みやすい言語**を選択
- 多言語国家の場合は**主要言語または公用語**を選択

#### 5.1 翻訳マッピングの作成

**手順:**
1. ログから全ての日本語ステージ名を収集
2. 各ステージ名の意味を理解
3. **その地域の言語**で適切な訳を作成

**翻訳マッピングの形式:**

```ruby
TRANSLATION_MAP = {
  "日本語ステージ名" => "その地域の言語でのステージ名",
  # ログから抽出した全パターンを記載（通常15-20パターン）
}
```

参考: 既存の翻訳スクリプト `bin/translate_*_crop_stages` を確認


#### 5.2 翻訳スクリプト作成

**ファイル名:** `bin/translate_<region>_crop_stages`

参考: `bin/translate_us_crop_stages` をコピーして `region` と `TRANSLATION_MAP` を更新

**実行権限付与:**
```bash
chmod +x bin/translate_<region>_crop_stages
```

#### 5.3 翻訳実行

```bash
docker compose exec web bin/translate_<region>_crop_stages
```

未翻訳があれば `TRANSLATION_MAP` に追加して再実行

---

### Phase 6: JSON出力とシード統合

#### 6.1 JSONエクスポートスクリプト作成

**ファイル名:** `bin/export_<region>_crops_to_json`

参考: `bin/export_us_crops_to_json` をコピーして `region` と出力パスを変更

**実行権限付与:**
```bash
chmod +x bin/export_<region>_crops_to_json
```

#### 6.2 JSON出力と確認

```bash
docker compose exec web bin/export_<region>_crops_to_json

# ステージ名がローカル言語になっているか確認
cat db/fixtures/<region>_reference_crops.json | jq -r '.[] | .crop_stages[] | .name' | sort -u
```

---

### Phase 7: Interaction Rules（相互作用ルール）作成

マイグレーションで連作障害ルールを定義。

参考: 
- `db/migrate/*seed*_reference_data.rb`
- [docs/DATA_MIGRATION_GUIDE.md](../DATA_MIGRATION_GUIDE.md)

---

### Phase 8: テストと検証

#### 8.1 マイグレーション実行と検証

```bash
# データベースリセット
docker compose down -v
docker compose up

# データ確認
docker compose exec web bin/rails runner "
puts 'Farms: ' + Farm.where(region: '<region>').count.to_s
puts 'Crops: ' + Crop.where(region: '<region>').count.to_s
"
```

---

### Phase 9: UI対応（地域選択可能にする）

データの準備が完了したら、ユーザーがWebUIで地域を選択できるようにします。

#### 9.1 設定ファイル更新

以下のファイルに新しいlocaleを追加:

1. `config/routes.rb`: `scope "(:locale)", locale: /ja|us|in/`
2. `config/application.rb`: `config.i18n.available_locales = [:ja, :us, :in]`
3. `app/controllers/public_plans_controller.rb`: `locale_to_region` メソッドに追加
4. `app/controllers/application_controller.rb`: `available_locales` ヘルパーに追加

#### 9.2 動作確認

```bash
docker compose restart web
# http://localhost:3000/<locale>/public_plans
```

---

### Phase 10: i18n完全対応（UI翻訳）

データとUIの設定が完了したら、**全てのUI文言をターゲット言語に翻訳**します。

#### 10.1 i18n構造の理解

Rails i18nファイルは以下の構造で管理されています：

```
config/locales/
├── in.yml                           # メインロケール（共通語、日付フォーマット）
├── jobs.in.yml                      # ジョブメッセージ
├── models/
│   ├── activerecord.in.yml         # モデル名・属性名
│   └── cultivation_plan.in.yml     # 栽培計画
└── views/
    ├── home.in.yml                 # ホーム画面
    ├── auth.in.yml                 # 認証画面
    ├── meta.in.yml                 # メタタグ
    ├── shared.in.yml               # 共通UI
    ├── pages.in.yml                # ページ
    ├── public_plans.in.yml         # 公開計画画面（最重要）
    ├── farms.in.yml                # 農場画面
    ├── crops.in.yml                # 作物画面
    ├── fields.in.yml               # 圃場画面
    └── interaction_rules.in.yml    # ルール画面
```

#### 10.2 TODO形式で作業を進める

**⚠️ 重要:** 14個のファイルを作成する必要があるため、**必ずTODOリストを作成**してから作業を開始してください。

**TODOリスト例:**
```
✅ 1. config/locales/in.yml を作成（メインロケールファイル）
✅ 2. config/locales/jobs.in.yml を作成（ジョブメッセージ）
✅ 3. config/locales/models/activerecord.in.yml を作成（モデル名・属性名）
✅ 4. config/locales/models/cultivation_plan.in.yml を作成（栽培計画）
✅ 5. config/locales/views/home.in.yml を作成（ホーム画面）
✅ 6. config/locales/views/auth.in.yml を作成（認証画面）
✅ 7. config/locales/views/meta.in.yml を作成（メタタグ）
✅ 8. config/locales/views/shared.in.yml を作成（共通UI）
✅ 9. config/locales/views/pages.in.yml を作成（ページ）
✅ 10. config/locales/views/public_plans.in.yml を作成（公開計画画面）※最重要
✅ 11. config/locales/views/farms.in.yml を作成（農場画面）
✅ 12. config/locales/views/crops.in.yml を作成（作物画面）
✅ 13. config/locales/views/fields.in.yml を作成（圃場画面）
✅ 14. config/locales/views/interaction_rules.in.yml を作成（ルール画面）
```

#### 10.3 翻訳方法

1. 既存のロケールファイル（`config/locales/ja.yml`または`us.yml`）をコピー
2. その地域の言語に翻訳
3. 一つずつTODOを完了させる

参考: 既存i18nファイル `config/locales/**/*.yml`

#### 10.4 動作確認

```bash
docker compose restart web

# i18nテスト
docker compose exec web bin/rails runner "
I18n.with_locale(:<locale>) do
  puts I18n.t('common.save')
end
"

# ブラウザ確認: http://localhost:3000/<locale>/public_plans
```

---

## 🔧 トラブルシューティング

| 問題 | 解決方法 |
|------|---------|
| 日本語ステージ名が生成される | Phase 5で翻訳スクリプト実行 |
| UNIQUE制約エラー | `docker compose down -v && docker compose up` |
| i18nが反映されない | `docker compose restart web` |

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

### チェックリスト

**データ:**
- [ ] 農場: 30-50件（地域の言語）
- [ ] 作物: 20-30件（地域の言語）
- [ ] ステージ: 全て地域の言語
- [ ] 相互作用ルール: 10-20件

**UI対応:**
- [ ] ルーティング・I18n設定（Phase 9）
- [ ] 14個のi18nファイル作成（Phase 10）- **TODOリスト必須**

---

## 🌍 他の地域への適用

このガイドは任意の地域に適用可能です。

---

## 📚 参考

- [DATA_MIGRATION_GUIDE.md](../DATA_MIGRATION_GUIDE.md)
- 既存マイグレーション: `db/migrate/*seed*.rb`


