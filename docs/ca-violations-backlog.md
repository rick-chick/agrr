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
- 2026-05-06: 作物・害虫・肥料 API の Agrr 呼び出しを `CropAiDaemonQueryGateway` / `PestAiDaemonQueryGateway` / `FertilizeCliGateway` に集約し controller の広い `rescue` を除去。API 結合テストは `CompositionRoot` のゲートウェイを stub。
- 2026-05-06: `CultivationPlanRestBaseController#parse_display_date` を `Adapters::Shared::Iso8601CalendarDate` に委譲（無効日付は `Date.valid_date?` で nil）。`EntryScheduleController#decode_entry_cursor` を `EntryScheduleCursorDecodeGateway` + `CompositionRoot` に委譲。
- 2026-05-06: `AuthController` / `Api::V1::AuthController` / `AuthTestController` のセッション Cookie 削除で `request.cookie_domain` を `respond_to?` でガード（`NoMethodError` rescue 撤去）。
- 2026-05-06: `Api::V1::Backdoor::BackdoorController#status` のバッククォートを `ShellStdoutCaptureGateway`（`CompositionRoot.backdoor_shell_stdout_capture_gateway`）に移し `SystemCallError` を境界で処理。
- 2026-05-06: `Farms::WeatherDataController` のキャッシュ判定で `predicted_at` / `prediction_start_date` を `Iso8601TimeParse` / `Iso8601CalendarDate` で正規化（行末 `rescue nil`・非検証の `Date.parse` を撤去）。

## 残置（意図・別単位）

- `Farms::WeatherDataController` の `PredictWeatherDataJob.perform_later` 周りの `rescue ActiveJob::EnqueueError`（キュー投入失敗のユーザー向けレスポンス）。
- `HealthController` の DB 例外のみを拾う `rescue *HEALTH_DB_EXCEPTIONS`（ファイル内コメントのとおり意図的）。
- `AuthController#allowed_return_to?` 等の `URI::InvalidURIError` rescue（URL 検証の局所ガード）。
