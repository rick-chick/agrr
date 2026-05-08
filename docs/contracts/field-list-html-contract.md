# 圃場一覧（HTML）契約

## スコープ

- **ユースケース**: `GET /farms/:farm_id/fields`（`format.html`）→ **`Domain::Field::Interactors::FieldListInteractor#call`**（API 一覧と**同一 Interactor**。表現の違いは Presenter のみ）
- **API 一覧**（`/api/v1/masters/farms/:farm_id/fields`）も同じ `FieldListInteractor`。Output Port で `Domain::Field::Results::FarmFieldsList` を受け、API は `fields` のみ使用

## Output Port

- **HTML 実装**: `Presenters::Html::Field::FieldListHtmlPresenter`（`FieldListOutputPort`）
- **`on_success`**: 引数は **`Domain::Field::Results::FarmFieldsList`**
  - `farm`: `Domain::Farm::Entities::FarmEntity`
  - `fields`: `Array<Domain::Field::Entities::FieldEntity>`
- **`on_failure`**: **`farms_path` へリダイレクト** + `alert`
- **境界**: ActiveRecord は Port を越えない

## Controller

- **index**: `before_action :set_farm` は **`except: :index`**。`params[:farm_id]` を Interactor に渡す
- **注入**: `CompositionRoot.field_gateway` を Interactor のみへ。Presenter に gateway を渡さない

## Gateway

- **`authorized_farm_fields_list(farm_id, user_id)`** → `FarmFieldsList`（認可済み農場 + スコープ上の圃場 entities）。Interactor・API はこの結果から `fields` を利用する。

## テンプレが参照する属性

- **農場**: `id`, `display_name` ほか entity が提供するもの
- **圃場行**: `id`, `display_name`（`field.id` で URL・DOM id）

## ビュー

- パスヘルパーは `farm_path(@farm.id)` 等
- Turbo: `turbo_stream_from Farm, @farm.id`
- カードの DOM id: `"field_#{field.id}"`
