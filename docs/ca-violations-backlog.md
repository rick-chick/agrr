# CA Violations Backlog

最終通し走査: 未実施 / 直近裏取り: none

## 修正単位

1. **`ARCHITECTURE.md` の `## What we require` と禁止 1〜30 の通し走査** — 全対象レイヤーを `Glob` / `Read` で意味読み照合し、違反を修正単位に切って列挙する（`rg` の一致のみを根拠にしない）。空到達時の裏取りとして必須。
2. **Application edge 禁止3（`rescue` 主スイッチ）** — `app/controllers/api` に AgrrService・JSON パース・`PolicyPermissionDenied` 相当の広い `rescue` が残るコントローラを、Interactor + Presenter + Gateway 正規化で個別に排除する（代表: `api/v1/pests_controller.rb`, `api/v1/crops_controller.rb`, `api/v1/fertilizes_controller.rb`, `api/v1/cultivation_plan_rest_base_controller.rb`, `api/v1/public_plans/entry_schedule_controller.rb`, `auth_controller.rb` 等。一覧は禁止3の意味読みで都度確定すること）。

## スキャン補足

- 2026-05-06: `InteractionRulesController` destroy を `InteractionRuleDestroyInteractor` + HTML/API Presenter に統一（ゲートウェイ preload・controller `rescue` 撤去）。`InteractionRuleDeletePresenter` の JSON `redirect_path` は HTML コントローラが `interaction_rules_path` を返すフックに変更。
- 2026-05-06: `PublicPlansController#create` の `create_job_instances_for_public_plans` を削除し、`PublicPlanOptimizationJobChainGateway#enqueue_after_create!`（`redirect_path` 引数）経由に集約。
- 2026-05-06: `PestsController#destroy` の HTML を `PestDestroyInteractor` + `PestDestroyHtmlPresenter` に統一（`HtmlMasterScheduleInvoker` と `PolicyPermissionDenied` の `rescue` 撤去）。`AgriculturalTasksController#destroy` の JSON からデッドな `rescue PolicyPermissionDenied` を削除。
- 2026-05-06: `Api::V1::Plans::FieldCultivationsController` / `PublicPlans::FieldCultivationsController` の show・update から `rescue PolicyPermissionDenied` を除去。`FieldCultivationClimateGateway#authorized_field_cultivation` で拒否を `Domain::Shared::Exceptions::RecordNotFound` に正規化し、`FieldCultivationApiShowInteractor` / `FieldCultivationApiUpdateInteractor` + API Presenter に委譲。気象系 `fetch_*` も同ゲートウェイ経由に統一。
- 2026-05-06: `Api::WeatherController` の historical / forecast から `begin/rescue AgrrService`・`JSON::ParserError` を除去。`Adapters::ApiWeather::Gateways::AgrrServiceWeatherQueryActiveGateway` が `AgrrService` と JSON パースを境界で処理しドメイン例外に写す。`Domain::ApiWeather::Interactors::*` + `Presenters::Api::Weather::*` + `CompositionRoot` 配線。`status` はゲートウェイの `daemon_running?` のみ。
