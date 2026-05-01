# プライベート計画・一覧（HTML）契約

## スコープ

- **ユースケース**: `GET .../plans` → **`Domain::CultivationPlan::Interactors::PrivatePlanIndexPageInteractor#call`**
- **`on_success` に渡すもの（一文）**: **`PrivatePlanIndexPageDto`**（`plan_rows`: **`Array<PrivatePlanIndexPlanRowDto>`**（各要素に **`id`**, **`farm_display_name`**, **`total_area`**, **`crops_count`**, **`fields_count`**, **`status`**（文字列）, **`display_name`**（**削除 undo トースト等用**。カード見出し・詳細には使わない。`CultivationPlan#display_name` と整合する文字列）, **`created_at`**））。表示順は従来の **`plans.group_by(&:farm_id).values.flatten`** と同じ。**ActiveRecord は Port を越えない**。

## Output Port

- **HTML**: `Presenters::Html::Plans::PrivatePlanIndexHtmlPresenter`（`PrivatePlanIndexPageOutputPort`）
- **`on_failure`**: `redirect_to plans_path` + `alert`（文言は **`session_invalid` / `not_found` / `restart`** 等。**恒久的に一覧だけが失敗し続ける場合はインターラクタ／Gateway の修正が必要**）

## Gateway

- **`CultivationPlanGateway#private_plan_index_page(user:)`** — ログインユーザーの **private 計画**を列挙し、作物数・圃場数を集計して DTO を組み立てる。

## Controller

- **注入**: `gateway` / `translator` / `logger` / `user_lookup` は **Interactor のみ**。
- **`on_failure` で redirect した場合**は `return if performed?` する。

## Interactor（失敗時）

- **`user_lookup.find` が `Domain::Shared::Exceptions::RecordNotFound`**: **`plans.errors.session_invalid`** を `on_failure`（logger **warn**、`user_record_not_found`）。
- **上記以外の `Domain::Shared::Exceptions::RecordNotFound`**（例: Gateway）: **`plans.errors.not_found`** を `on_failure`（logger **warn**）。
- **その他 `StandardError`（`on_failure` 扱い）**: logger に **先頭20行の backtrace**（`/backtrace:` 以下）。

## テンプレ（`plans/index`）

- **`@private_plan_index_page`** の **`plan_rows`** / **`empty?`** のみ参照（`@vm` / `@plans_by_farm` / AR は使用しない）。
