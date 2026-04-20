# Feature Contract: 作物スケジュール（エントリ）

**作成日**: 2026-04-15  
**最終更新**: 2026-04-16  
**ステータス**: MVP 拡張（並び・ページング・フェーズ・タイムライン）  
**関連**: [crop_schedule_entry_product_requirements.md](../planning/crop_schedule_entry_product_requirements.md)、[crop_schedule_stage_roles.md](../planning/crop_schedule_stage_roles.md)、**気象初期化メモ** [crop_schedule_entry_weather_initialization.md](../planning/crop_schedule_entry_weather_initialization.md)、**トラブルシュート** [crop_schedule_entry_troubleshooting.md](../planning/crop_schedule_entry_troubleshooting.md)

## 概要

参照農場（`Farm`・`reference`）と参照作物（`Crop`・`is_reference`）、`WeatherPredictionService` の予測気象 JSON から、まき帯・植え帯（連続日区間）と説明文（`reason_summary`）、**4 フェーズ表示用セグメント**、**月次ざっくり時系列**、**一覧用の並びメタデータ**を返す公開読み取り API と、Angular の一覧・詳細 UI（`/entry-schedule`）。**マイ作物・ユーザー作物連携は本契約の対象外**（実装しない）。

## 認証（公開エントリ）

- **`GET .../public_plans/entry_schedule/*`**（本節のパス）は **不要**（`skip_before_action :authenticate_user!`）。

## 気象初期化・前提

詳細は **[crop_schedule_entry_weather_initialization.md](../planning/crop_schedule_entry_weather_initialization.md)**。

- リクエスト対象の `Farm` は **参照農場**（`farm.reference?`）。
- **`farm.weather_location` が必須** → 欠落時 **422**（`api.entry_schedule.errors.weather_location_required`）。
- **`prediction_end_date`**（クエリ）未指定は当年 `Date.current.end_of_year`。
- 予測データ欠如 **422**（`no_weather_data`）。予測失敗 **503**（`api.entry_schedule.errors.prediction_failed`）。

### 最適化評価期間とチャート軸

- **AGRR `optimize period`** の評価期間は、暦年ベースの **昨年 6/1〜来年 6/30** と、予測気象 JSON の日次 `[min, max]` の **積集合**（両方に含まれる日のみ）。交差が空なら気象不足として失格扱い。
- 一覧・詳細の帯チャートの横軸は **`prediction.chart_calendar_year`**（通常はサーバの「今日」の年）に対する **1月〜12月** で、まき・植えの目安区間がその暦年のどこに当たるかを示す。帯の左端は開始の早い側の目安。

## 並び（一覧 `crops[]`）

サーバーが **複合キー**で降順ソートする（クライアントは返却順を表示するだけ）。

1. **`eligible`** が `true` の行を上に。
2. 次に **まき帯の開始日が今日に近い**順（近いほど上）。まき帯が無い・非 eligible は後方。
3. 同順位は **まき帯の日数幅が狭い**順（狭いほど上）。

並び用に各行にメタフィールド **`sort_meta`** を付与してもよい（デバッグ・一貫性確認用）。

## NFR-03: 一覧ページング・ETag

### クエリ（`GET .../entry_schedule/crops`）

| パラメータ | 説明 |
|------------|------|
| `farm_id` | **必須** |
| `prediction_end_date` | 任意・ISO 日付 |
| `locale` | 任意 |
| `limit` | 1 ページあたり件数。**既定 20**、**最大 50** |
| `cursor` | 次ページ取得用の不透明文字列。前レスポンスの `meta.next_cursor` をそのまま付与 |

### レスポンスの `meta`（一覧のみ）

| フィールド | 型 | 説明 |
|------------|-----|------|
| `total_count` | integer | 条件に合致する作物の総件数（ページング前） |
| `limit` | integer | 適用された 1 ページあたり件数 |
| `next_cursor` | string \| null | 次ページがあるときのみ非 null |
| `has_more` | boolean | さらに続きがあるか |

### ETag

- 一覧レスポンスに **`ETag`** ヘッダを付与する。
- クライアントが **`If-None-Match`** に同一値を送った場合、**本文が変わらなければ 304 Not Modified** を返してよい。

## フィールド仕様（`crops[]` 行・詳細 `crop` 共通の追加）

| フィールド | 型 | 説明 |
|------------|-----|------|
| `schedule_flow_summary` | string | 一覧の 1 行目用。育苗→定植→収穫の流れなど短文（口語・i18n） |
| `schedule_flow_detail` | string \| null | 行展開用の補足（月レンジの要約など） |
| `phase_segments` | array（長さ 4） | 固定ラベル **播種 / 育苗 / 定植 / 収穫** に対応。各要素は下表 |
| `rough_timeline` | array | 月単位のざっくり作業時系列（詳細中心）。要素は `{ "month": "YYYY-MM", "summary": "..." }` |
| `sort_meta` | object | `eligible`, `sowing_proximity_days`, `sowing_window_width_days` 等（並び根拠の可視化） |

### `phase_segments[]` 各要素

| フィールド | 型 | 説明 |
|------------|-----|------|
| `phase_key` | string | `sowing` \| `nursery` \| `transplant` \| `harvest` |
| `label` | string | 画面表示用（API 応答時点でロケール解決済み可） |
| `start_date` | string \| null | ISO8601 |
| `end_date` | string \| null | ISO8601 |
| `empty_reason` | string \| null | レンジが埋まらないときの理由（短い文言キーまたは本文） |

欠損時は **非表示にせず**、`empty_reason` で説明する。

## NFR-02（エラー・再試行・鮮度）

- 予測 **503** 時は JSON に `error` / `error_key`。**クライアントは再試行ボタン**を表示可能にする。
- 一覧・詳細で **`prediction.generated_at`** 等を表示し、**鮮度**が分かるようにする（詳細は UI 側）。

## ロケール

`before_action :apply_entry_locale`。クエリ `locale` → `Accept-Language` → デフォルト。

## レート制限

`Rack::Attack` の `/api/` 共通ルール（既存ドキュメントどおり）。

## API

ベースパス: `(/:locale)/api/v1/public_plans/entry_schedule/...`

### GET .../entry_schedule/farms

変更なし（参照農場の配列）。

### GET .../entry_schedule/crops

**Query**: `farm_id`（必須）、`prediction_end_date`、`locale`、`limit`、`cursor`

**Response**（抜粋）:

```json
{
  "farm": { "id", "name", "latitude", "longitude", "region" },
  "prediction": { "generated_at", "prediction_start_date", "prediction_end_date", "weather_location_id", "chart_calendar_year" },
  "meta": {
    "total_count": 120,
    "limit": 20,
    "next_cursor": "opaque_string_or_null",
    "has_more": true
  },
  "crops": [
    {
      "id": 1,
      "name": "...",
      "eligible": true,
      "sowing_summary": { "start_date": "...", "end_date": "..." },
      "transplant_summary": { ... },
      "reason_summary": "...",
      "labels": { "sowing": "...", "transplanting": "..." },
      "schedule_flow_summary": "...",
      "schedule_flow_detail": "...",
      "phase_segments": [ { "phase_key": "sowing", "label": "...", "start_date": "...", "end_date": "...", "empty_reason": null } ],
      "rough_timeline": [ { "month": "2026-04", "summary": "..." } ],
      "sort_meta": { "eligible": true, "sowing_proximity_days": 5, "sowing_window_width_days": 10 }
    }
  ]
}
```

### GET .../entry_schedule/crops/:id

**Query**: `farm_id`（必須）、`prediction_end_date`、`locale`

**Response** の `crop` に **`phase_segments`**, **`rough_timeline`**, 注記用に **`entry_disclaimer`**（固定文・i18n キーに基づく文字列）を含める。既存の `sowing_windows`, `transplant_windows`, `reason_parts`, `crop_stages` も維持。

### エラー

- **404**: `farm_id` 欠落・参照外農場・作物が参照スコープに無い。
- **422**: 気象地点なし、予測ペイロード欠如。
- **503**: 予測サービス例外。

---

## フロント（Angular）

- **ルート**: `/entry-schedule`（一覧）、`/entry-schedule/crop/:cropId`（クエリで `farmId`）。
- **Gateway**: `EntryScheduleApiGateway`、`domain/entry-schedule/entry-schedule.ts`。
- **i18n**: `assets/i18n` の `entrySchedule.*`。

### 詳細 `crop.next_task`（固定）

カタログ専用のため **`available: false`**, **`code: "catalog"`**, **`summary: null`**（プレースホルダ用。将来拡張で差し替え可）。

## 実装参照

- コントローラ: `app/controllers/api/v1/public_plans/entry_schedule_controller.rb`
- サービス: `app/services/crop_schedule/window_service.rb`, `stage_role_resolver.rb`, `entry_schedule_response_builder.rb`, `entry_schedule_phase_timeline.rb`（フェーズ・タイムライン生成）、`entry_schedule_show_payload.rb`（公開詳細）、`copy_reference_crop_stages.rb`（他機能からの作物複製用）
