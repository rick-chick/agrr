# 作付け計画ガントチャート実装ガイド

## 📋 概要

作付け計画完成画面を、カード表示からガントチャート形式に刷新しました。

### 主な機能

1. **ガントチャート一覧表示** - 圃場×作物×カレンダーの3次元表示
2. **詳細パネル** - クリックで詳細情報を展開表示
3. **気温分析グラフ** - Chart.jsによる気温・積算温度の可視化
4. **レスポンシブ対応** - モバイル・タブレット・PCで統一された操作感

---

## 🗂️ ファイル構成

### ビュー（パーシャル）

```
app/views/public_plans/
├── results.html.erb                     # メインビュー
└── results/
    ├── _header.html.erb                 # ヘッダー・サマリー
    ├── _gantt_chart.html.erb            # ガントチャート全体
    ├── _gantt_row.html.erb              # ガントチャート1行
    ├── _detail_panel.html.erb           # 詳細パネル枠組み
    ├── _detail_info_tab.html.erb        # 基本情報タブ
    ├── _detail_temperature_tab.html.erb # 気温分析タブ
    └── _detail_stages_tab.html.erb      # ステージ詳細タブ
```

### スタイル

```
app/assets/stylesheets/
└── public_plans_results.css             # ガントチャート専用CSS
```

### JavaScript

```
app/javascript/
└── cultivation_results.js               # インタラクション制御
```

### API

```
app/controllers/api/v1/public_plans/
└── field_cultivations_controller.rb     # 詳細データAPI
```

---

## 🎯 パーシャル仕様

### 1. `_header.html.erb`

**入力:**
- `cultivation_plan` (CultivationPlan)

**出力:**
- タイトル
- サマリー情報（地域、総面積、圃場数、推定総コスト）

### 2. `_gantt_chart.html.erb`

**入力:**
- `cultivation_plan` (CultivationPlan)

**出力:**
- テーブル形式のガントチャート
- 24ヶ月のヘッダー（2024年・2025年）
- 各行を`_gantt_row.html.erb`で描画
- 今日のマーカー
- 凡例

### 3. `_gantt_row.html.erb`

**入力:**
- `field_cultivation` (FieldCultivation)
- `plan_start_date` (Date): 基準日
- `plan_end_date` (Date): 終了日

**出力:**
- 圃場名・作物名・面積（固定列）
- 栽培期間バー（ステージごとのグラデーション）
- 播種日・収穫日のマーカー

**ヘルパーメソッド:**
- `calculate_month_index(date, plan_start)` - 日付を月インデックス(1-24)に変換
- `crop_emoji(crop_name)` - 作物に応じた絵文字を返す
- `render_stage_gradient(fc)` - ステージごとの色でグラデーションCSS生成

### 4. `_detail_panel.html.erb`

**入力:**
- `cultivation_plan` (CultivationPlan)

**出力:**
- モーダル/パネル枠組み
- タブナビゲーション（3つ）
- コンテンツエリア（動的に切り替え）

**JavaScriptで制御:**
- 表示/非表示
- タブ切り替え
- データ注入

### 5. `_detail_info_tab.html.erb`

**JavaScriptから注入されるデータ:**
```javascript
{
  field_name: "第1圃場",
  crop_name: "トマト",
  area: 100,
  start_date: "2024-04-15",
  completion_date: "2024-08-20",
  cultivation_days: 127,
  gdd: 2456,
  estimated_cost: 85000,
  stages: [...]
}
```

**出力:**
- 8項目のグリッド表示
- ステージタイムライン

### 6. `_detail_temperature_tab.html.erb`

**JavaScriptから注入されるデータ:**
```javascript
{
  weather_data: [...],           // 気温データ
  optimal_temperature_range: {}, // 最適温度範囲
  temperature_stats: {},         // 統計情報
  gdd_data: [...],               // GDD推移データ
  gdd_info: {}                   // GDD達成情報
}
```

**出力:**
- Chart.js 気温グラフ（最高/最低/平均 + 最適範囲帯）
- 統計カード（3つ）
- Chart.js GDDグラフ
- GDDサマリー

### 7. `_detail_stages_tab.html.erb`

**JavaScriptから注入されるデータ:**
```javascript
{
  stages: [
    {
      name: "発芽",
      start_date: "4/15",
      end_date: "4/30",
      days: 15,
      gdd_required: 200,
      gdd_actual: 205,
      avg_temp: 16.2,
      optimal_temp_min: 15,
      optimal_temp_max: 25,
      risks: []
    },
    // ...
  ]
}
```

**出力:**
- ステージカード（各ステージ）
- 詳細統計情報

---

## 🔄 データフロー

```
1. ユーザーがガントチャート行をクリック
   ↓
2. JavaScript: ガントチャート行のdata属性から field_cultivation_id を取得
   ↓
3. fetch('/api/v1/public_plans/field_cultivations/:id')
   ↓
4. FieldCultivationsController#show が呼ばれる
   ↓
5. 以下のデータを取得して返却:
   - field_cultivation の基本情報
   - weather_data（栽培期間中の気温データ）
   - stages（ステージ詳細）
   - temperature_stats（統計情報）
   - gdd_info, gdd_data（積算温度情報）
   ↓
6. JavaScript: 受け取ったデータを各タブに注入
   ↓
7. Chart.js: グラフを描画
   ↓
8. 詳細パネルを表示
```

---

## 🎨 CSS設計

### レスポンシブブレークポイント

- **モバイル** (< 768px): 横スクロール、詳細パネルは画面下部固定
- **タブレット** (768px - 1024px): 横スクロール、詳細パネルは画面下部
- **デスクトップ** (> 1024px): 詳細パネルは通常フロー

### 主要クラス

- `.gantt-table` - ガントチャートのテーブル
- `.gantt-sticky-col` - 左側固定列（圃場・作物情報）
- `.gantt-cultivation-bar` - 栽培期間バー
- `.detail-panel` - 詳細パネル全体
- `.detail-tab-btn` - タブボタン
- `.info-card`, `.stat-card`, `.stage-card` - 各種カード

---

## 📡 API エンドポイント

### GET `/api/v1/public_plans/field_cultivations/:id`

**認証:** 不要

**レスポンス例:**
```json
{
  "id": 1,
  "field_name": "第1圃場",
  "crop_name": "トマト",
  "area": 100.0,
  "start_date": "2024-04-15",
  "completion_date": "2024-08-20",
  "cultivation_days": 127,
  "gdd": 2456.0,
  "estimated_cost": 85000.0,
  "stages": [
    {
      "name": "発芽",
      "start_date": "2024-04-15",
      "end_date": "2024-04-30",
      "days": 15,
      "gdd_required": 200,
      "gdd_actual": 205,
      "gdd_achieved": true,
      "avg_temp": 16.2,
      "optimal_temp_min": 15,
      "optimal_temp_max": 25,
      "risks": []
    }
  ],
  "weather_data": [
    {
      "date": "2024-04-15",
      "temperature_max": 18.5,
      "temperature_min": 8.2,
      "temperature_mean": 13.3
    }
  ],
  "temperature_stats": {
    "total_days": 127,
    "optimal_days": 98,
    "optimal_percentage": 77.2,
    "high_temp_days": 12,
    "low_temp_days": 0
  },
  "gdd_info": {
    "target": 2400,
    "actual": 2456,
    "percentage": 2.3,
    "achievement_date": "2024-08-18"
  },
  "gdd_data": [
    {
      "date": "2024-04-15",
      "accumulated_gdd": 10.5,
      "target_gdd": 2400
    }
  ],
  "optimal_temperature_range": {
    "min": 15.0,
    "max": 30.0
  }
}
```

---

## 🚀 セットアップ

### 1. アセットのビルド

```bash
# JavaScriptのビルド（esbuild）
npm run build

# 開発モードで自動ビルド
npm run build:dev
```

### 2. サーバー起動

```bash
# Docker環境
docker compose up web

# ローカル環境
rails server
```

### 3. 動作確認

1. 作付け計画を作成: http://localhost:3000/public_plans
2. 完成画面でガントチャートを確認
3. 行をクリックして詳細パネルを確認
4. タブを切り替えてグラフを確認

---

## 🐛 トラブルシューティング

### Chart.jsが読み込まれない

results.html.erbでCDNから読み込んでいることを確認：

```erb
<script src="https://cdn.jsdelivr.net/npm/chart.js@4.4.0/dist/chart.umd.min.js" defer></script>
<script src="https://cdn.jsdelivr.net/npm/chartjs-adapter-date-fns@3.0.0/dist/chartjs-adapter-date-fns.bundle.min.js" defer></script>
```

### JavaScriptが動作しない

ブラウザのコンソールでエラーを確認：

```javascript
// cultivation_results.js が読み込まれているか確認
console.log('cultivation_results.js loaded');
```

### APIエラー

ルートが正しく設定されているか確認：

```bash
rails routes | grep field_cultivations
# => api_v1_public_plans_field_cultivation GET  /api/v1/public_plans/field_cultivations/:id
```

### CSSが適用されない

Propshaftでpublic_plans_results.cssが読み込まれているか確認：

```erb
<%= stylesheet_link_tag "public_plans_results", "data-turbo-track": "reload" %>
```

---

## 📝 今後の拡張案

1. **PDF エクスポート** - 計画をPDFでダウンロード
2. **印刷最適化** - CSS `@media print` でレイアウト調整
3. **ズーム機能** - ガントチャートの時間軸を拡大/縮小
4. **フィルター機能** - 作物や期間でフィルタリング
5. **比較機能** - 複数の計画を並べて比較
6. **リマインダー** - 播種日・収穫日の通知機能

---

## 📚 参考リンク

- [Chart.js Documentation](https://www.chartjs.org/docs/latest/)
- [Rails 8 Propshaft](https://github.com/rails/propshaft)
- [Rails 8 jsbundling-rails](https://github.com/rails/jsbundling-rails)

