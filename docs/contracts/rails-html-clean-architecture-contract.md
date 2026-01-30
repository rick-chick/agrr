# 契約: Rails HTML コントローラの Clean Architecture 化

Rails の HTML コントローラを、既存の `lib/domain` の Interactor と新規の HTML 用 Presenter を使う形にリファクタする。新規 API 追加・フロント変更は含まない。

## 1. 機能名・スコープ

- **機能**: Rails HTML コントローラを Clean Architecture に寄せる（既存 Interactor を流用し、HTML 用 Presenter で redirect/render する）
- **スコープ**: 以下の Rails HTML コントローラおよび対応する lib/domain リソース。フロントエンド（Angular）・API パスは変更しない。
- **Phase 2/3 の適用**: 本契約はサーバー側リファクタのみ。
  - **Phase 2**: usecase-server のみ実行（既存 Interactor/DTO を Rails params から呼ぶ前提の確認。不足 DTO があれば追加）。
  - **Phase 3**: presenter-server と controller-server のみ実行（HTML Presenter の新規実装、Rails コントローラの Interactor 呼び出しへの変更）。gateway-server / フロント 3 体（presenter-frontend, gateway-frontend, controller-frontend）は対象外。

## 2. 対象リソース一覧

| Rails コントローラ | lib/domain | 既存 Interactor（流用） | 既存 Gateway（流用） | 新規 HTML Presenter |
|--------------------|------------|--------------------------|----------------------|----------------------|
| FarmsController | farm | FarmList, FarmDetail, FarmCreate, FarmUpdate, FarmDestroy | FarmActiveRecordGateway | FarmListHtmlPresenter, FarmDetailHtmlPresenter, FarmCreateHtmlPresenter, FarmUpdateHtmlPresenter, FarmDestroyHtmlPresenter |
| FertilizesController | fertilize | FertilizeList, FertilizeDetail, FertilizeCreate, FertilizeUpdate, FertilizeDestroy | FertilizeMemoryGateway（または ActiveRecord） | 同上パターン |
| CropsController | crop | CropList, CropDetail, CropCreate, CropUpdate, CropDestroy | CropActiveRecordGateway（等） | 同上パターン |
| PestsController | pest | PestList, PestDetail, PestCreate, PestUpdate, PestDestroy | PestMemoryGateway（等） | 同上パターン |
| PesticidesController | pesticide | 同様 | 同様 | 同上パターン |
| AgriculturalTasksController | agricultural_task | 同様 | 同様 | 同上パターン |
| FieldsController | field | 同様（Farm にネストされる場合は Farm 経由の Gateway 利用） | 同様 | 同上パターン |
| InteractionRulesController | interaction_rule | 同様 | 同様 | 同上パターン |

※ 実装順は 1 リソースずつ（例: Farm）進め、動作確認後に他リソースに展開することを推奨する。

## 3. HTML Presenter 契約（Output Port 実装）

既存の API 用 Presenter は `Domain::*::Ports::*OutputPort` を実装し、`on_success` / `on_failure` で `view.render_response(json:, status:)` を呼ぶ。HTML 用は同じ Output Port を実装し、代わりに **redirect_to** または **render** を行う。

### 3.1 View インターフェース（Rails コントローラが実装するメソッド）

HTML Presenter が呼び出す View メソッドは以下とする。

| メソッド | 用途 | 例 |
|----------|------|-----|
| `redirect_to(path, notice:, alert:)` | 成功時のリダイレクト | `redirect_to farm_path(farm), notice: I18n.t('farms.flash.created')` |
| `render( action, status:, locals: )` | 失敗時のフォーム再表示 | `render :new, status: :unprocessable_entity` |
| `undo_deletion_path(undo_token:)` | 削除 Undo 用（既存 DeletionUndoFlow と同様） | 既存ヘルパー利用 |

### 3.2 HTML Presenter の振る舞い（例: FarmCreateHtmlPresenter）

- **on_success(entity)**: `view.redirect_to resource_path(entity), notice: 作成完了メッセージ`
- **on_failure(error_dto)**: `view.render :new, status: :unprocessable_entity` かつ、エラーメッセージは `flash.now[:alert]` または `@errors` で View に渡す（既存 HtmlCrudResponder の失敗時と同等）。

### 3.3 配置

- **API 用 Presenter**: 既存どおり `lib/presenters/api/{resource}/` に配置。
- **HTML 用 Presenter**: `lib/presenters/html/{resource}/` に新規配置（例: `lib/presenters/html/farm/farm_create_html_presenter.rb`）。

## 4. Rails コントローラの振る舞い（リファクタ後）

### 4.1 例: FarmsController#create（リファクタ後）

1. `params` から `Domain::Farm::Dtos::FarmCreateInputDto.from_hash(...)` で DTO を組み立てる（strong_params の代わりに DTO を使用）。
2. `Presenters::Html::Farm::FarmCreateHtmlPresenter.new(view: self)` を生成。
3. `Domain::Farm::Interactors::FarmCreateInteractor.new(output_port: presenter, gateway: farm_gateway, user_id: current_user.id).call(input_dto)` を呼ぶ。
4. Interactor 内で成功時は `output_port.on_success(farm_entity)` → Presenter が `redirect_to`。失敗時は `output_port.on_failure(error_dto)` → Presenter が `render :new`。

### 4.2 Gateway の取得

- Rails コントローラでは、API と同様に `Adapters::Farm::Gateways::FarmActiveRecordGateway.new` などを private メソッドで返す。既存 Gateway をそのまま流用する。

### 4.3 権限・ポリシー

- Interactor 内で既に `Domain::Shared::Policies::FarmPolicy` 等を参照している場合はそのまま。Rails 側で `set_farm` などで `FarmPolicy.find_owned!` を呼んでいる箇所は、Interactor に委譲するか、コントローラで継続して呼ぶかは実装時に判断する（Interactor 内に権限チェックが含まれていればコントローラ側の重複は削除可能）。

## 5. 既存 Interactor / DTO の前提

- **Input DTO**: 既存の `Domain::*::Dtos::*CreateInputDto.from_hash(params.to_unsafe_h.deep_symbolize_keys)` 等が、Rails の `params`（HTML フォームから送られた params）でもそのまま使えること。必要に応じて key の変換（例: `farm[name]` → `name`）を DTO の `from_hash` で吸収する。
- **Output Port**: 既存の `Domain::*::Ports::*CreateOutputPort` 等のインターフェースは変更しない。HTML Presenter はそのまま実装する。

## 6. 実装チェックリスト

- [ ] 各リソースについて、HTML Presenter（`lib/presenters/html/{resource}/*_html_presenter.rb`）が対応する Output Port を実装している
- [ ] Rails コントローラが、直接 Model/Policy を呼ばず、Interactor + HTML Presenter + Gateway を呼んでいる
- [ ] 成功時: redirect_to と flash notice/alert が既存と同等
- [ ] 失敗時: render :new / :edit と status :unprocessable_entity、エラー表示が既存と同等
- [ ] 削除 Undo フロー（DeletionUndoFlow）を使っている場合は、Destroy Interactor + DestroyHtmlPresenter が undo 用 JSON または redirect を返す形で既存挙動を満たす
- [ ] Phase 2: usecase-server のみ実行（既存 DTO/Interactor の確認・不足分の追加）
- [ ] Phase 3: presenter-server と controller-server のみ実行（HTML Presenter 追加、Rails コントローラリファクタ）

## 7. 参照

- 既存 API Presenter: `lib/presenters/api/farm/farm_create_presenter.rb`
- 既存 Interactor: `lib/domain/farm/interactors/farm_create_interactor.rb`
- 既存 Rails コントローラ: `app/controllers/farms_controller.rb`
- HtmlCrudResponder: `app/controllers/concerns/html_crud_responder.rb`
