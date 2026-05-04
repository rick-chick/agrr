# プライベート計画・農場選択ウィザード（HTML new）契約

## スコープ

- **ユースケース**: `GET .../plans/new` → **`Domain::CultivationPlan::Interactors::PrivatePlanNewPageInteractor#call`**
- **`on_success` に渡すもの（一文）**: **`PrivatePlanNewPageDto`**（`farm_choices`: **`Array<PrivatePlanNewFarmChoiceDto>`**（各要素に **`id`**, **`display_name`**, **`latitude`**, **`longitude`**, **`fields_count`**, **`fields_total_area`**）、`default_plan_name`: **String**（`plans.default_plan_name` の翻訳結果））。**ActiveRecord は Port を越えない**。

## Output Port

- **HTML**: `Presenters::Html::Plans::PrivatePlanNewHtmlPresenter`（`PrivatePlanNewPageOutputPort`）
- **`on_failure`**: `redirect_to plans_path` + `alert`（文言は **`session_invalid` / `not_found` / `restart`** 等。恒久的失敗は Gateway / Interactor の修正が必要）

## Gateway

- **`FarmGateway#private_plan_new_farm_choices(user:)`** — **`user_owned_records(user)` と同等のスコープ**で農場を **`id` 昇順**に読み、圃場は **`Field`** を農場 ID で **`GROUP BY`** し、**`COUNT(*)` / `SUM(area)`**（欠損は 0）で件数・面積を **`PrivatePlanNewFarmChoiceDto`** の配列に詰める。**`PrivatePlanNewPageDto`**（`default_plan_name` を含む）は Interactor 成功時に **`PrivatePlanNewPageAssembler`**（`translator.t("plans.default_plan_name")` を含む）で組み立てる。

## Controller

- **注入**: `farm_gateway` / `translator` / `logger` / `user_lookup` は **Interactor のみ**。
- **`on_failure` で redirect した場合**は `return if performed?` する。

## テンプレ（`plans/new`）

- **`@private_plan_new_page`** の **`farm_choices`** / **`empty?`** / **`default_plan_name`** のみ参照（`@vm` / AR は使用しない）。
- **`default_plan_name`**: DTO に必ず含める。テンプレでは**ヒント表示などで参照する**（未使用とする意図はない）。作物選択以降の命名とは独立。

## Interactor（失敗時）

- **`user_lookup.find` が `Domain::Shared::Exceptions::RecordNotFound`**: セッション無効として `plans.errors.session_invalid` を `on_failure`（**`restart` にしない**）。logger は **warn**（`user_record_not_found`）。
- **上記以外の `Domain::Shared::Exceptions::RecordNotFound`**（例: Gateway）: `plans.errors.not_found` を `on_failure`。logger は **warn**。
- **その他 `StandardError`（`on_failure` 扱い）**: logger に **先頭20行の backtrace** を含める（`/backtrace:` 以下）。
