# 肥料一覧（HTML）契約

## スコープ

- **ユースケース**: `GET /fertilizes`（`format.html`）→ **`Domain::Fertilize::Interactors::FertilizeListInteractor#call`**（API 一覧 `/api/v1/masters/fertilizes` と同一 Interactor）
- **`on_success` に渡すもの（一文）**: 現在ユーザー向けスコープの **`Array<Domain::Fertilize::Entities::FertilizeEntity>` のみ**。**ActiveRecord は Port を越えない**。

## Output Port

- **HTML 実装**: `Presenters::Html::Fertilize::FertilizeListHtmlPresenter`（`FertilizeListOutputPort`）
- **`on_failure`**: `@fertilizes = []` のうえで `flash.now` + `render :index`（`status: :unprocessable_entity`）

## テンプレ（`fertilizes/index`）が参照する entity 属性

- **識別・表示**: `id`, `name`, `is_reference`, `npk_summary`（メソッド）
- **URL**: `fertilize_path(fertilize.id)` 等、`id` ベース
- **DOM**: `id="fertilize_<%= fertilize.id %>"`（`dom_id(AR)` に依存しない）

## Gateway

- **`list_index_for_filter(filter)`**（`filter` は Policy が組み立てる参照スコープ用値オブジェクト）→ entity の配列（Interactor が呼び出し、HTML 専用メソッドは増やさない）

## Controller

- **注入**: `CompositionRoot.fertilize_gateway` / `user_lookup` を **Interactor のみ**へ。**Presenter に gateway / proc を渡さない**
