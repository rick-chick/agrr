# プライベート計画・詳細（HTML show）契約

## スコープ

- **ユースケース**: `GET .../plans/:id`（詳細） → **`Domain::CultivationPlan::Interactors::PrivatePlanShowPageInteractor#call`**
- **`on_success` に渡すもの（一文）**: **`PrivatePlanShowPageDto`**（`id`, `display_name`, `farm_display_name`, `total_area`, `field_cultivations_count`, `cultivation_plan_fields_count`, `planning_start_date`, `planning_end_date`, `status`, **`gantt_cultivation_rows`** / **`gantt_field_rows`**（`Domain::CultivationPlan::GanttChartRowHashes` が組み立てる、`shared/_gantt_chart` の `data-*` と同一キー）, **`palette_used_crop_ids`**, **`palette_crops`**: **`Array<PrivatePlanShowPaletteCropDto>`**（`id`, `name`, `variety`））。**ActiveRecord は Port を越えない**。

## Output Port

- **HTML**: `Presenters::Html::Plans::PrivatePlanShowHtmlPresenter`（`PrivatePlanShowPageOutputPort`）
- **`on_success`**: Rails では **`@view.instance_variable_set(:@private_plan_show_page, dto)`** で `@private_plan_show_page` をセットする（Presenter はマッピング＋HTTP 整形のみ）。テンプレートは **DTO の読み取り専用属性** のみ参照する。
- **`on_failure`**: `redirect_to plans_path` + `alert`（`session_invalid` / `not_found` / `restart` など既存方針に準ずる）

## Gateway

- **`CultivationPlanGateway#find_private_cultivation_plan_detail(user:, plan_id:)`** — **`PlanPolicy.private_scope(user)`** で認可つき 1 件取得し、**読み取り専用スナップショット** **`PrivateCultivationPlanDetailDto`** を返す（`MapArPersistenceErrors` 内）。**ガント用 Hash・Partial 名・View に依存しない。** 見つからない場合は **`Domain::Shared::Exceptions::RecordNotFound`**。

## Assembler

- **`Domain::CultivationPlan::Assemblers::PrivatePlanShowPageAssembler.call(detail)`** — `PrivateCultivationPlanDetailDto` → **`PrivatePlanShowPageDto`**（ガント行は **`GanttChartRowHashes`** で `detail` の読み取り行から生成）。

## Interactor

- **注入**: `gateway` / `translator` / `logger` / `user_lookup`。**`plan_id` は正の整数にパースした値**のみ渡す（Controller 側）。
- **`PersistenceFailed`**: **ログ出力のうえ再 raise**。ユーザー向け `on_failure` やフラッシュには回さず、**通常は Rails が 500 を扱う**（恒久方針）。
- **`on_failure` で redirect した場合**は Controller で `return if performed?` する。
- **`PlanStatus.optimizing?(status)`** が真の場合、Interactor **成功後**に Controller が **`optimizing_plan_path`** へリダイレクトする。

## Controller

- **注入**: Interactor に `gateway` / `translator` / `logger` / `user_lookup`（**Interactor のみ**が利用）。

## テンプレ（`plans/show`）

- **`@private_plan_show_page`** の属性および **`render 'shared/gantt_chart', gantt_embed: ...`** のみ。**`@vm` / AR は使用しない**。
- **`shared/gantt_chart`**: **`gantt_embed`** または従来の **`cultivation_plan`**（公開計画等レガシー）。レガシー AR 枝でも栽培行・圃場行は **`GanttChartRowHashes`** で Hash 化する（単一のキー定義）。

## テンプレ（`shared/crop_palette`）

- **`crop_palette_embed`**（`used_crop_ids`, `crops`）または **`cultivation_plan`**（レガシー）。
