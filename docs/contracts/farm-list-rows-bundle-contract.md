# 農場一覧（行 DTO 束）契約

## スコープ

- **ユースケース**: `GET /farms`（`format.html` および **`format.json`**）→ `Domain::Farm::Interactors::FarmListRowsBundleInteractor#call`（HTML / JSON で **同一 Interactor**、Presenter のみ差し替え）
- **API マスタ一覧**（`/api/v1/masters/farms`）は別契約（`FarmListInteractor` + `FarmEntity`）

## Output Port

- **実装（HTML）**: `Presenters::Html::Farm::FarmListHtmlPresenter`（`FarmListRowsBundleOutputPort`）。クラスは HTML レイアウト配下のため `Html` を含んでもよい（ドメインの型・Interactor 名にチャネル語を載せない）。
- **実装（JSON）**: `Presenters::Html::Farm::FarmListJsonPresenter`（同じ `FarmListRowsBundleOutputPort`）。`FarmListRowDto` から `{ farms:, reference_farms: }` を組み立てる。
- **`on_success`**: 引数は **`Domain::Farm::Dtos::FarmListRowsBundleDto` のみ**
  - `farm_rows`: `Array<FarmListRowDto>` — メイン一覧（管理者時は「自分の農場∪参照農場」に相当するスコープの行）
  - `reference_farm_rows`: `Array<FarmListRowDto>` — 参照農場ブロック用（管理者のみ中身あり、非管理者は空）
- **境界**: DTO に **ActiveRecord を渡さない**

## FarmListRowDto（カード1件）

テンプレ `farms/_farm_card` が参照する属性:

- 識別・基本: `id`, `display_name`, `latitude`, `longitude`, `region`, `user_id`, `is_reference`
- 一覧 JSON 用: `created_at`, `updated_at`（`GET /farms` の `format.json` で出力。未設定時は `null`）
- 圃場: `field_count`
- 天気: `weather_data_status`, `weather_data_progress`, `weather_data_total_years`, `weather_data_last_error`（ラベル文言はビューで **`FarmsHelper#farm_list_row_weather_status_text`** により生成。キーは `app/models/farm.rb#weather_data_status_text` と揃える）
- 派生: `has_coordinates?`, `fetching?`, `failed?`, `reference?`

`display_name` は永続化された農場名（`farms.name`）を運ぶ（ゲートウェイは i18n ・`@translator` を持たない）。

## Gateway

- **`farm_list_rows_bundle(input_dto)`** → `FarmListRowsBundleDto`（`includes(:fields)` で圃場件数取得、**list + 再 fetch の二重化を避ける**）

## Controller

- **注入**: `CompositionRoot.farm_gateway` を Interactor にのみ渡す。**Presenter に gateway / proc を渡さない**

## ビュー

- パスヘルパーは `farm_path(farm.id)` 等、**DTO の `id` を使う**
- Turbo: `turbo_stream_from Farm, farm.id` — **Farm 更新時の Action Cable 購読とストリーム名を一致させる**
