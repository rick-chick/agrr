# 圃場詳細（HTML）契約

## スコープ

- **ユースケース**: `GET /farms/:farm_id/fields/:id`（`format.html`）→ **`Domain::Field::Interactors::FieldDetailInteractor#call`**（API 詳細と**同一 Interactor**）
- **API 詳細**（`/api/v1/masters/fields/:id`）も同じ `FieldDetailInteractor`。Output Port で `Domain::Field::Results::FieldWithFarm` を受け、API は **`field` のみ**使用

## Output Port

- **HTML 実装**: `Presenters::Html::Field::FieldDetailHtmlPresenter`（`FieldDetailOutputPort`）
- **`on_success`**: 引数は **`Domain::Field::Results::FieldWithFarm`**
  - `farm`: `Domain::Farm::Entities::FarmEntity`
  - `field`: `Domain::Field::Entities::FieldEntity`
- **`on_failure`**: `FieldDetailFailure` の `farm_id` があれば `farm_fields_path(farm_id)`、なければ `farms_path` + `alert`（`farm_id` は Controller が `FieldDetailInput` に載せたルートスコープ）
- **境界**: ActiveRecord は Port を越えない

## Gateway

- **`field_with_farm_for_user(field_id, user_id)`** → `FieldWithFarm`（圃場の取得・認可に加え、農場を `find_authorized_for_edit` で揃える）

## Controller

- **show**: `set_field` は **`edit` / `update` / `destroy` のみ**
- **注入**: Interactor のみへ `CompositionRoot.field_gateway`

## ビュー

- パスは `farm_path(@farm.id)`, `farm_field_path(@farm.id, @field.id)` 等
- DOM id: `"field_#{@field.id}"`
