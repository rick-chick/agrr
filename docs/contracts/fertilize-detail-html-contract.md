# 肥料詳細（HTML）契約

## スコープ

- **ルート**: `GET /fertilizes/:id`（`format.html`）→ **`Domain::Fertilize::Interactors::FertilizeDetailInteractor#call`**
- **`on_success`**: `FertilizeDetailOutputDto`（`fertilize` に **`Domain::Fertilize::Entities::FertilizeEntity`**）。テンプレは `@fertilize`（entity）のみ参照。**ActiveRecord は Port を越えない**

## Output Port

- **HTML 実装**: `Presenters::Html::Fertilize::FertilizeDetailHtmlPresenter`（`FertilizeDetailOutputPort`）
- **`on_failure`**: **`redirect_to fertilizes_path, alert:`**（一覧へ戻す。`render :show` や proc は使わない）。**`Domain::Shared::Exceptions::RecordNotFound`** は Interactor が **`translator.t("fertilizes.flash.not_found")`** を `ErrorDto` に載せて `on_failure` へ（旧 `FertilizeLoadForViewHtmlPresenter#on_not_found` と同じ文言）

## Gateway

- **`find_by_id(id)`** → entity（Interactor が `ReferenceRecordAuthorization.assert_view_allowed!` で認可）

## Controller

- **`set_fertilize` は show に使わない**（詳細は Interactor + Presenter のみ）
- **`PolicyPermissionDenied`**: Interactor は **再raise**。HTML は `FertilizesController#show` で `redirect_to fertilizes_path` + `I18n.t("fertilizes.flash.no_permission")`。API は `Api::V1::Masters::BaseController` の `rescue_from` で 403
- **注入**: `CompositionRoot.fertilize_gateway` / **`translator`** / `user_lookup` を Interactor のみへ。Presenter に gateway / proc を渡さない
