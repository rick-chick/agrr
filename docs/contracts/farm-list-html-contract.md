# 農場一覧（HTML）契約

## スコープ

- **ユースケース**: `GET /farms`（`format.html`）→ `Domain::Farm::Interactors::FarmListHtmlInteractor#call`
- **API 一覧**（`/api/v1/masters/farms`）は別契約（`FarmListInteractor` + `FarmEntity`）

## Output Port

- **実装**: `Presenters::Html::Farm::FarmListHtmlPresenter`（`FarmListHtmlOutputPort`）
- **`on_success`**: 引数は **`Domain::Farm::Dtos::FarmListHtmlSuccessDto` のみ**
  - `farm_rows`: `Array<FarmListRowDto>` — メイン一覧（管理者時は「自分の農場∪参照農場」に相当するスコープの行）
  - `reference_farm_rows`: `Array<FarmListRowDto>` — 参照農場ブロック用（管理者のみ中身あり、非管理者は空）
- **境界**: DTO に **ActiveRecord を渡さない**

## FarmListRowDto（カード1件）

テンプレ `farms/_farm_card` が参照する属性:

- 識別・基本: `id`, `display_name`, `latitude`, `longitude`, `region`, `user_id`, `is_reference`
- 圃場: `field_count`
- 天気: `weather_data_status`, `weather_data_progress`, `weather_data_total_years`, `weather_data_status_text`, `weather_data_last_error`
- 派生: `has_coordinates?`, `fetching?`, `failed?`, `reference?`

表示名・天気ラベルの i18n キーは **`app/models/farm.rb` の `display_name` / `weather_data_status_text` と揃える**（アダプタ内 `@translator`）。

## Gateway

- **HTML インデックス一式**: `farm_list_html_index(input_dto)` → `FarmListHtmlSuccessDto`（`includes(:fields)` で圃場件数取得、**list + 再 fetch の二重化を避ける**）
- **補助**: `farm_list_html_rows_from_entities` — entity 順で行 DTO を再構築。DB に無い id は **`Rails.logger.warn`** のうえスキップ

## Controller

- **注入**: `CompositionRoot.farm_gateway` を Interactor にのみ渡す。**Presenter に gateway / proc を渡さない**

## ビュー

- パスヘルパーは `farm_path(farm.id)` 等、**DTO の `id` を使う**
- Turbo: `turbo_stream_from Farm, farm.id` — **Farm 更新時の Action Cable 購読とストリーム名を一致させる**
