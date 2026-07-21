# 農場詳細: 気温チャート（観測のみ）

作成日: 2026-07-21  
状態: 設計（必須スコープのみ・未実装）

## 0. スコープ（必須 3 点）

| # | 必須要件 | 本設計での扱い |
|---|----------|----------------|
| 1 | 観測のみ・期間指定 API・デフォルト 90 日 | §2 API、`period` クエリ、予測なし |
| 2 | 取得完了までチャート非表示 | §4 UI 状態マトリクス、`completed` 以外はチャート領域を出さない |
| 3 | 栽培計画チャートと役割分離 | §1 ユーザー価値、§4 文言・レイアウト、GDD/ステージ帯なし |

**初版で含めない**: 予測（`period_next_365`）、全期間（20 年超）、部分データの段階表示、農場詳細 API へのチャート同梱。

## 1. ユーザー価値と役割分離

### 1.1 農場チャートが答える問い

> **この農場の座標で、最近どんな気温だったか？**

- 対象: 実測（観測）の日次気温（最高・平均・最低）
- 文脈: 作物・栽培期間・GDD は**含めない**

### 1.2 栽培計画チャートとの棲み分け

| 画面 | 問い | データ |
|------|------|--------|
| **農場詳細**（本機能） | 場所の気温履歴は？ | 観測のみ、ユーザー選択期間 |
| **作付け計画**（既存 `plan-field-climate`） | この栽培の進捗と気温・GDDは？ | 栽培期間、ステージ帯、GDD、agrr progress |

農場チャート下部に補足文を常時表示する（§6 i18n）。

## 2. API 設計

### 2.1 エンドポイント

```
GET /api/v1/masters/farms/{farm_id}/temperature_chart?period=90d
```

- 認可: `FarmDetailInteractor` と同一（所有者 + 参照農場の `reference_record_authorization`）
- レスポンス: チャート描画に必要な最小 JSON（農場メタは詳細 API から既に取得済みのため重複しない）

### 2.2 クエリ `period`

| 値 | 意味 | 日数上限 |
|----|------|----------|
| `30d` | 過去 30 日 | 30 |
| `90d` | 過去 90 日（**デフォルト**） | 90 |
| `180d` | 過去 180 日 | 180 |
| `365d` | 過去 1 年 | 365 |

- 未指定・不正値 → `90d` に正規化
- `end_date` = サーバー今日（`ClockPort`）
- `start_date` = `end_date - period + 1 day`
- **予測期間は受け付けない**（`period_next_365` は 400 または正規化で拒否）

### 2.3 成功レスポンス（200）

```json
{
  "farm_id": 12,
  "period": "90d",
  "start_date": "2026-04-23",
  "end_date": "2026-07-21",
  "observed_only": true,
  "data_quality": {
    "expected_days": 90,
    "present_days": 88,
    "missing_days": 2
  },
  "points": [
    {
      "date": "2026-04-23",
      "temperature_min": 8.2,
      "temperature_mean": 14.5,
      "temperature_max": 21.0
    }
  ]
}
```

- `points`: 日付昇順。欠損日は**行を含めない**（クライアントは `spanGaps: false`）
- `temperature_*`: `null` のフィールドは JSON から省略可（その日は点を描かない）
- `data_quality.missing_days > 0` のときフロントで軽い注意文（§4.4）

### 2.4 エラーレスポンス

| HTTP | 条件 | フロント表示 |
|------|------|--------------|
| 404 | 農場なし / 権限なし | 既存詳細エラーと同様 |
| 409 | `weather_data_status != completed` | 進捗 UI（チャート領域は出さない） |
| 422 | 座標未設定・`weather_location` なし | 「気象データを準備できません」 |
| 500 | ストレージエラー | 再試行ボタン |

**409 の body 例**（チャート要求に対する明示的拒否）:

```json
{
  "error": "weather_data_not_ready",
  "weather_data_status": "fetching",
  "weather_data_progress": 42
}
```

フロントは詳細画面の ActionCable 更新と整合させ、`completed` になったらチャートを遅延ロードする。

### 2.5 再取得（失敗時）

既存の農場作成・更新フローで `StartFarmWeatherDataFetchInteractor` が enqueue される。  
**専用のユーザー向け「再取得」POST は初版では設けない**（座標変更・作成時の自動取得に任せる）。  
`failed` 時は「農場を編集して保存し直す」またはサポート導線の文言のみ（運用で足りなければ Phase 2）。

## 3. バックエンド（Clean Architecture）

### 3.1 修正単位

`farm-temperature-chart` — 農場文脈の観測気温チャート取得

### 3.2 ドメイン

```
lib/domain/farm/  （または weather_data/ に Farm 向け read を追加）
├── dtos/
│   ├── farm_temperature_chart_input.rs      # farm_id, period, user_id
│   └── farm_temperature_chart_output.rs     # points, data_quality, dates
├── gateways/
│   └── farm_temperature_chart_gateway.rs    # 狭い read: status + period 内 WeatherData[]
├── interactors/
│   └── farm_temperature_chart_interactor.rs
└── ports/
    └── farm_temperature_chart_output_port.rs
```

**Interactor の責務（成功パスのみ）**:

1. `FarmGateway` で農場取得 + 認可（`FarmDetailInteractor` と同じ policy）
2. `weather_data_status == "completed"` でなければモデル化された失敗（409）
3. `weather_location_id` なし → 422
4. `FarmTemperatureChartGateway` で `[start_date, end_date]` の `WeatherData` 列取得
5. `data_quality` 集計（期待日数 vs 返却行数）
6. `output_port.on_success(dto)`

**禁止**: Interactor 内で GCS/SQLite 直叩き、agrr 呼び出し、予測マージ。

### 3.3 アダプター（agrr-server）

```
crates/agrr-server/src/masters_farm_temperature_chart.rs
```

- ルート: `masters_farms.rs` の Router に `.merge(masters_farm_temperature_chart::routes())`
- `MastersUserId` 抽出 → input DTO → Interactor → JSON Presenter
- Gateway 実装: `WeatherDataGatewayBundle` + 既存 `FarmSqliteGateway`

### 3.4 契約テスト

`test/contract/` に追加:

- 完了済み農場 + `period=90d` → 200、points 件数 ≤ 90
- 取得中農場 → 409
- 他ユーザー農場 → 404
- 参照農場（閲覧可）→ 200

## 4. フロントエンド設計

### 4.1 コンポーネント構成

```
farm-detail.component
└── farm-temperature-chart.component   # 新規・standalone
    ├── 期間セグメント（30/90/180/365）
    ├── 状態別テンプレート（§4.2）
    └── Chart.js 気温 3 系列（min/mean/max）
```

**新規 usecase 縦スライス**:

```
domain/farms/farm-temperature-chart.ts          # 型
usecase/farms/load-farm-temperature-chart.*     # DTO, gateway token, usecase, ports
adapters/farms/farm-temperature-chart-api.gateway.ts
adapters/farms/farm-temperature-chart.presenter.ts
components/masters/farms/farm-temperature-chart.component.ts
```

`plan-field-climate` は**流用しない**。共通化は Chart.js の軸・色定数のみ（`shared/chart/temperature-chart-theme.ts` 程度）。

### 4.2 UI 状態マトリクス（必須 #2）

| `weather_data_status` | チャート領域 | 表示内容 |
|-----------------------|-------------|----------|
| `pending` / `fetching` | **非表示**（セクション枠のみ） | 進捗バー + `fetching_progress` |
| `failed` | **非表示** | `fetch_failed` 文言（再試行ボタンなし） |
| `completed` | **表示** | 期間セレクタ + ロード → チャート |
| `completed` + API 409 | 非表示 | 進捗 UI にフォールバック（レース対策） |

**原則**: `completed` になるまで `<canvas>` を DOM に置かない。

### 4.3 ロード順序

```
1. LoadFarmDetailUseCase（既存）→ farm + fields
2. SubscribeFarmWeatherUseCase（既存）→ status/progress 更新
3. weather_data_status === 'completed' のときのみ
   LoadFarmTemperatureChartUseCase({ farmId, period: '90d' })
4. 期間変更 → 3 を再実行（デフォルト period を保持）
```

農場詳細 API にチャートを同梱しない（詳細は軽量・チャートは遅延）。

### 4.4 欠損日 UX

- チャート: `spanGaps: false`（線を切る）
- `data_quality.missing_days > 0`: チャート下に注意文 `farms.weather_section.data_gap_notice`

### 4.5 栽培計画との視覚的分離（必須 #3）

- セクション見出し: `farms.weather_section.temperature_chart_title`（「温度推移」）
- サブ見出し: `farms.weather_section.observed_subtitle`（新規 — 「実測データ（過去○日）」）
- 補足: `farms.weather_section.plan_chart_hint`（新規 — 計画画面への誘導文、リンクは張らない）
- **含めない**: GDD タブ、ステージ帯、作物名、予測ラベル

## 5. 画面レイアウト（農場詳細への挿入位置）

```
┌─ パンくず ─────────────────────────────────────┐
├─ 農場名・編集・削除 ────────────────────────────┤
├─ 天気データ取得状況（fetching/failed 時のみ）───┤  ← 既存
├─ 地図 ─────────────────────────────────────────┤  ← 既存
├─ ★ 温度推移（新規セクション）─────────────────┤  ← 地図の下・圃場一覧の上
│   [30日][90日][180日][1年]                      │
│   ┌ 気温チャート ─────────────────────────┐  │
│   └────────────────────────────────────────┘  │
│   ※ 栽培の進捗・予測は作付け計画で…            │
├─ 圃場一覧 ─────────────────────────────────────┤
└────────────────────────────────────────────────┘
```

地図の直後に置く理由: 「この場所の気温」という地理文脈と連続する。

## 6. i18n

### 6.1 既存キー（利用）

- `farms.weather_section.period_*`（`period_next_365` は**UI に出さない**）
- `farms.weather_section.temperature_chart_title`
- `farms.weather_section.chart_temp_*`
- `farms.weather_section.fetching_progress` / `fetch_failed` / `preparing`
- `farms.weather_data.no_weather_data`

### 6.2 新規キー（ja 例）

| キー | 文言 |
|------|------|
| `farms.weather_section.observed_subtitle` | 実測データ（{{period}}） |
| `farms.weather_section.plan_chart_hint` | 作物ごとの栽培期間・積算温度（GDD）・予測は、各作付け計画の気候チャートで確認できます。 |
| `farms.weather_section.data_gap_notice` | この期間に {{count}} 日分の気象データがありません。欠損日はグラフ上で途切れて表示されます。 |
| `farms.weather_section.chart_loading` | 気温データを読み込んでいます… |
| `farms.weather_section.chart_load_failed` | 気温データの読み込みに失敗しました。 |
| `farms.weather_section.retry_load` | 再読み込み |

`en` / `in` も同キーを追加（i18n-completion スキル手順）。

## 7. チャート仕様（Chart.js）

| 項目 | 値 |
|------|-----|
| ライブラリ | `chart.js/auto` + `chartjs-adapter-date-fns`（既存と同じ） |
| X 軸 | 時間軸（日付） |
| Y 軸 | 温度 °C |
| 系列 | max=赤系、mean=青系、min=緑系（`plan-field-climate` と同色系） |
| 高さ | `min-height: 220px`（モバイル）、`280px`（md 以上） |
| 凡例 | 上部、既存 `chart_temp_*` ラベル |
| tooltip | 日付 + 3 値（`plans.field_climate.chart.tooltip_format` と同形式でよい） |

## 8. モックデザイン

ビジュアルモック: [`docs/design/assets/farm-temperature-chart-mock.png`](assets/farm-temperature-chart-mock.png)

### 8.1 完了時（デフォルト 90 日）

```
┌──────────────────────────────────────────────────────────────┐
│ 農場一覧 > 田中農園                                            │
├──────────────────────────────────────────────────────────────┤
│ 田中農園                              [編集]  [削除]          │
│ 地域: 日本                                                    │
├──────────────────────────────────────────────────────────────┤
│ 地図                                                          │
│ ┌────────────────────────────────────────────────────────┐   │
│ │              [地図ピン @ 35.68, 139.65]                │   │
│ └────────────────────────────────────────────────────────┘   │
├──────────────────────────────────────────────────────────────┤
│ 温度推移                                                      │
│ 実測データ（過去90日）                                        │
│                                                               │
│ 期間選択  ( 30日 ) [ 90日 ] ( 180日 ) ( 1年 )                │
│                                                               │
│  ┌─ 凡例: ── 最高気温  ── 平均気温  ── 最低気温 ─────────┐   │
│  │ 25°C ┤                              ╭──╮              │   │
│  │      │           ╭──╮    ╭─╮      │  │              │   │
│  │ 15°C ┤────╮──────╯  ╰────╯ ╰──────╯  ╰──            │   │
│  │      │      ╰──╮                                      │   │
│  │  5°C ┤         ╰────────────────                      │   │
│  │      └────┬────┬────┬────┬────┬────                  │   │
│  │          4月   5月   6月   7月                         │   │
│  └────────────────────────────────────────────────────────┘   │
│  ℹ 作物ごとの栽培期間・積算温度（GDD）・予測は、各作付け計画の  │
│    気候チャートで確認できます。                                │
├──────────────────────────────────────────────────────────────┤
│ 圃場                                    [圃場を追加]          │
│ ・北側の田（1000㎡）  [編集] [削除]                           │
└──────────────────────────────────────────────────────────────┘
```

### 8.2 取得中（チャート非表示）

```
├──────────────────────────────────────────────────────────────┤
│ 天気データ取得状況                                              │
│ 天気データを取得中です... (42%)                                 │
│ [████████░░░░░░░░░░░░] 42%                                    │
├──────────────────────────────────────────────────────────────┤
│ 地図 …                                                        │
├──────────────────────────────────────────────────────────────┤
│ 温度推移                                                      │
│ 天気データを準備中です…                                       │
│ （プログレスバーのみ。canvas なし）                            │
├──────────────────────────────────────────────────────────────┤
```

### 8.3 取得失敗

```
│ 温度推移                                                      │
│ 天気データの取得に失敗しました。                               │
│ （canvas なし。農場編集で座標確認を促す短文を optional 表示）  │
```

## 9. テスト方針

| 層 | 内容 |
|----|------|
| Domain | period 正規化、data_quality 集計、status≠completed → 失敗 |
| Contract | §2.4 の HTTP 表 |
| Frontend unit | 状態マトリクス: fetching 時 canvas なし、completed で usecase 呼び出し |
| Frontend unit | period 変更で gateway 再呼び出し |
| E2E（任意） | 参照データ農場でチャート canvas 表示 smoke |

## 10. 実装フェーズ（推奨）

1. **Phase A**: API + domain + contract（TDD）
2. **Phase B**: `farm-temperature-chart.component` + farm-detail 組み込み
3. **Phase C**: i18n 3 言語 + 契約テスト GREEN

Phase 2 候補（本設計スコープ外）: ユーザー向け再取得 POST、欠損日の詳細一覧、計画画面からのディープリンク。
