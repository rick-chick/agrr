# プライベート計画・作物選択（HTML）契約

## スコープ

- **ユースケース**: `GET .../plans/select_crop`（`farm_id` 必須）→ **`Domain::CultivationPlan::Interactors::PrivatePlanSelectCropContextInteractor#call`**
- **`on_success` に渡すもの（一文）**: **`PrivatePlanSelectCropContextDto`**（`farm`: **`FarmEntity`**、`plan_name`: **String**、`crops`: **`Array<CropEntity>`**（ユーザー非参照・名前順）、`total_area`: **数値（認可済み圃場の `area` 合計）**）。**ActiveRecord は Port を越えない**。

## Output Port

- **HTML**: `Presenters::Html::Plans::PrivatePlanSelectCropHtmlPresenter`
- **`on_failure`**: `redirect_to new_plan_path` + `alert`（未認可・不存在など。文言は `ErrorDto` / I18n）

## Gateway

- **`FieldGateway#farm_fields_list(farm_id)`** — **農場 entity ＋圃場 entity 一覧**を 1 経路で返す（`total_area` は圃場 `area` の合算）。認可は Interactor が `FieldAccess.assert_farm_fields_list_allowed!` で評価する。
- **`CropGateway#list_user_owned_non_reference_crops_ordered_by_name`**

## Controller

- **`farm_id`**: **正の整数**（`/[1-9]\d*/`）のみ受け付け。それ以外は `plans.errors.select_farm` で `new_plan` へ。
- **注入**: `field_gateway` / `crop_gateway` / `translator` / `logger` / `user_lookup` は **Interactor のみ**。Presenter に gateway を渡さない。
- **想定外例外**: Interactor は **`StandardError` を `plans.errors.restart` で通知**し、**logger に詳細を記録**（ユーザーに内部メッセージは出さない）。`RecordNotFound`（農場／圃場まわり）は **`plans.errors.farm_not_found`**。
- **`on_failure` で redirect した場合**は `performed?` が true になるため、**セッション保存前に `return if performed?`** する。

## テンプレ（`plans/select_crop`）

- **農場表示**: `FarmEntity#display_name`
- **作物一覧**: `id`, `name`, `variety`（`CropEntity`）
- **面積**: `total_area`（数値、`number_with_delimiter` 可）
