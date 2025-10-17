# 気温・GDDチャート機能

作付け計画ガントチャートに統合された、気温とGDD（成長度日）を表示するインタラクティブなチャート機能です。

## 📊 機能概要

### 1. 気温チャート（上部）
- **3つの気温線グラフ**:
  - 🔴 最高気温（赤線）
  - 🟠 平均気温（オレンジ線、太め）
  - 🔵 最低気温（青線）
- **適正温度範囲**: 作物の適正温度範囲を緑色のボックスで表示
- **インタラクティブ**: マウスホバーで日付・気温・GDD値を表示

### 2. GDDチャート（下部）
- **3つのグラフを統合**:
  - 📊 日別GDD（青色棒グラフ、左Y軸）
  - 📈 積算GDD（緑色折れ線グラフ、右Y軸）
  - 🎯 要求GDD（赤色破線の階段状グラフ）
- **成長ステージ**: 各ステージの境界を可視化

## 🎯 使用方法

1. 作付け計画の結果ページに移動
2. ガントチャートで作物バーを**クリック**
3. 気温・GDDチャートが広告エリアの上に表示される
4. 閉じるボタン（×）でチャートを非表示

## 🏗️ 実装構成

### バックエンド（Rails）

#### APIエンドポイント
```
GET /api/v1/public_plans/field_cultivations/:id/climate_data
```

**レスポンス例**:
```json
{
  "success": true,
  "field_cultivation": {
    "id": 1,
    "field_name": "圃場1",
    "crop_name": "トマト（桃太郎）",
    "start_date": "2026-04-15",
    "completion_date": "2026-06-15"
  },
  "farm": {
    "id": 2,
    "name": "つくば",
    "latitude": 36.0833,
    "longitude": 140.1
  },
  "crop_requirements": {
    "base_temperature": 10.0,
    "optimal_temperature_range": {
      "min": 15,
      "max": 30
    }
  },
  "weather_data": [
    {
      "date": "2026-04-15",
      "temperature_max": 22.5,
      "temperature_min": 12.3,
      "temperature_mean": 17.4
    }
    // ...
  ],
  "gdd_data": [
    {
      "date": "2026-04-15",
      "gdd": 7.4,
      "cumulative_gdd": 7.4
    }
    // ...
  ],
  "stages": [
    {
      "name": "発芽期",
      "start_date": "2026-04-15",
      "end_date": "2026-04-25",
      "duration_days": 10,
      "gdd_required": 100.0,
      "cumulative_gdd_required": 100.0,
      "optimal_temperature_min": 15,
      "optimal_temperature_max": 25
    }
    // ...
  ]
}
```

#### コントローラー
`app/controllers/api/v1/public_plans/field_cultivations_controller.rb`
- `climate_data` アクション
- 栽培期間の気象データ取得
- **`agrr progress`コマンドでGDD計算**（日別GDD、積算GDD、成長ステージ）
- 作物DBから温度要件と要求GDDを取得

#### ゲートウェイ
`app/gateways/agrr/progress_gateway.rb`
- `agrr progress`コマンドのラッパー
- 気象データと作物プロファイルをCLIに渡す
- 成長進捗（daily_progress）を取得

### フロントエンド（JavaScript）

#### Climate Chart モジュール
`app/javascript/climate_chart.js`
- `ClimateChart` クラス
- Chart.jsを使用してチャート描画
- APIからデータ取得
- 動的なチャート表示・非表示

#### ガントチャート統合
`app/javascript/custom_gantt_chart.js`
- 作物バークリック時に `showClimateChart(cultivationId)` を呼び出し
- チャートコンテナを動的に作成・挿入

### スタイル（CSS）

#### Climate Chart CSS
`app/assets/stylesheets/features/climate_chart.css`
- モダンなデザイン（グラデーション、シャドウ、アニメーション）
- レスポンシブ対応
- 既存のガントチャートと統一されたデザイン言語

### ルーティング

```ruby
namespace :api do
  namespace :v1 do
    namespace :public_plans do
      resources :field_cultivations, only: [:show, :update] do
        member do
          get :climate_data
        end
      end
    end
  end
end
```

## 🧪 テスト

### システムテスト
`test/system/climate_chart_test.rb`
- JavaScriptモジュールの読み込み確認
- CSS読み込み確認
- ※完全なe2eテストはデータベースロック問題のため手動確認を推奨

### 手動テスト手順
1. Dockerコンテナを起動: `docker compose up`
2. ブラウザで http://localhost:3000/public_plans にアクセス
3. 作付け計画を作成（地域選択→農場サイズ選択→作物選択）
4. 結果ページでガントチャートの作物バーをクリック
5. 気温・GDDチャートが表示されることを確認
6. 閉じるボタン（×）でチャートが非表示になることを確認

## 📦 パッケージ

### 必要なnpmパッケージ
```json
{
  "chart.js": "^4.5.0",
  "chartjs-plugin-annotation": "^3.1.0"
}
```

インストール:
```bash
docker compose run --rm web npm install
docker compose run --rm web npm run build
```

## 🔧 技術スタック

- **Chart.js 4.5.0**: 気温・GDDチャートの描画
- **Rails 8 API**: 気象データとGDD計算
- **SVG**: ガントチャート
- **Turbo**: ページ遷移の高速化

## 🎨 デザイン特徴

- グラデーション背景
- ドロップシャドウ
- 角丸デザイン
- ホバーエフェクト
- アニメーション（フェードイン、スライドダウン）
- レスポンシブ対応（モバイルにも対応）

## 🌡️ データソース

### 1. 温度データ
- **ソース**: CLIに渡した気象データ（`WeatherDatum`）
- **期間**: 栽培期間（start_date〜completion_date）
- **データ**: 最高気温、最低気温、平均気温

### 2. 限界・適正温度
- **ソース**: 作物DB（`TemperatureRequirement`）
- **データ**:
  - `optimal_min`: 適正温度下限
  - `optimal_max`: 適正温度上限
  - `low_stress_threshold`: 低温ストレス閾値
  - `high_stress_threshold`: 高温ストレス閾値

### 3. GDD（成長度日）
- **ソース**: **`agrr progress`コマンド実行結果**
- **計算方法**: CLI側で作物の基準温度を使って計算
- **データ**:
  - `daily_gdd`: 日別GDD増加量（前日との差分）
  - `cumulative_gdd`: 積算GDD（栽培開始日からリセット）
  - `current_stage`: 現在の成長ステージ
- **注意**: `progress_records`が空の場合は手動計算にフォールバック

### 4. 要求GDD
- **ソース**: 作物DB（`ThermalRequirement`）
- **データ**: 各成長ステージの`required_gdd`を累積
- **表示**: 階段状の折れ線グラフ

## 💾 予測データの保存と再利用

### 最適化時
- `CultivationPlanOptimizer`が予測データを生成
- `CultivationPlan.predicted_weather_data`に保存（JSON形式）
- 保存内容: latitude, longitude, timezone, data（気温データ配列）, generated_at, target_end_date

### チャート表示時
- 保存済みデータが存在する場合: そのまま再利用（高速）
- 保存済みデータがない場合: その場で予測を生成（フォールバック）

### メリット
- ✅ パフォーマンス向上（予測を毎回実行しない）
- ✅ データの一貫性（最適化と同じ予測データを表示）
- ✅ ネットワーク負荷軽減

## 🚀 今後の拡張可能性

- [x] ステージごとの温度範囲をチャートに表示（annotationプラグイン使用）✅
- [x] 予測気温データの保存と再利用✅
- [ ] 降水量グラフの追加
- [ ] 日照時間グラフの追加
- [ ] チャートのPDF/画像エクスポート機能
- [ ] チャートデータのCSVダウンロード

## 📝 注意事項

- 栽培期間（`start_date`、`completion_date`）が設定されていない場合、エラーメッセージを表示
- 気象データ（`WeatherLocation`）が存在しない農場では、エラーメッセージを表示
- Chart.jsのannotationプラグインはv3.1.0を使用（温度範囲の表示に使用）

## 🐛 トラブルシューティング

### 「データの読み込みに失敗しました」エラー
- 栽培期間が設定されているか確認
- 農場に気象データが存在するか確認
- コンソールでAPIレスポンスを確認

### チャートが表示されない
- JavaScriptがビルドされているか確認: `docker compose run --rm web npm run build`
- CSSが読み込まれているか確認: ブラウザの開発者ツールで確認
- コンソールエラーを確認

### APIエラー
- Railsログを確認: `docker compose logs web --tail=100`
- データベースに気象データが存在するか確認

## 📚 関連ドキュメント

- [カスタムガントチャート](../app/javascript/custom_gantt_chart.js)
- [Chart.js公式ドキュメント](https://www.chartjs.org/)
- [chartjs-plugin-annotation](https://www.chartjs.org/chartjs-plugin-annotation/)

