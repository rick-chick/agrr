# CA Violations Backlog

最終全量スキャン: 2026-05-06T00:00:00Z / 直近裏取り: 2026-05-06（AI Pest 作物関連付けは `PestMemoryGateway` へ移管しコントローラから `rescue ActiveRecord::ActiveRecordError` を除去）。2026-05-06: 計画系バックグラウンド Job の `rescue StandardError` を整理（例外集合はアプリ縁側 `app/jobs/cultivation_plan_job_exceptions.rb`、`CultivationPlanJobExceptions`、監視 Job は `ActiveRecord::ActiveRecordError`、チェーンランナーは冗長 rescue 削除）。`MonitorMigrationStatusJob` は Rails 8 の `pending_migration_versions` に合わせ、ジョブテストは DB 破壊をやめスタブ化。

## 修正単位

- [ ] **その他 API の広い `rescue` 棚卸し** — `AgrrService` + `RuntimeError` / JSON パース / システムコール例外 等を `ARCHITECTURE.md` 禁止 3（Application edge 3）の意味で個別評価。許容となる狭い境界翻訳と、`on_failure` 二重路を区別する。@ `app/controllers/api/v1/fertilizes_controller.rb`, `app/controllers/api/v1/crops_controller.rb`, `app/controllers/api/v1/cultivation_plan_rest_base_controller.rb` 他

## スキャン補足

- `lib/domain` における `Date.current` / `CompositionRoot` はコメント参照のみで実コード違反ではなかった。
- `lib/presenters` に `CompositionRoot` / `Gateway.default` の実呼び出しはスキャン上ヒットなし。
- フロント `usecase` → `adapters` 直 import、`domain` → `@angular/*` の機械検出はヒットなし（フロントは設計変更時に再確認）。
- `AgrrOptimization` controller concern は本番未使用のため削除済み（2026-05-06）。統合テストは `CompositionRoot` 経由。
- `DeletionUndoFlow` concern は削除済み（2026-05-06）。HTML マスタ削除は各コントローラから `DeletionUndo::HtmlMasterScheduleInvoker.call` を直接呼び出し。
- 削除 Undo の HTML/JSON 二形式応答は `DeletionUndoScheduleSuccessPayloadInteractor`・`Presenters::DeletionUndo::DualFormatResponder`・`ApplicationController#render_deletion_undo_dual_success` / `#render_deletion_undo_dual_failure` に整理済み（2026-05-06）。
- `JobExecution` concern を削除し、ジョブチェーン非同期投入は `Adapters::Application::JobChainAsyncDispatcher`（`CompositionRoot.job_chain_async_dispatcher`）へ集約（2026-05-06）。
- `CultivationPlanApi` モジュールを `Api::V1::CultivationPlanRestBaseController` に置換し `app/controllers/concerns/cultivation_plan_api.rb` を削除（2026-05-06）。
- 栽培計画 REST 基底: ワークベンチ／adjust／add_crop コーディネータの具象組み立てを `CompositionRoot` に集約し、`add_crop` の冗長ログを除去（2026-05-06）。
- 公開計画 optimizing: `PublicPlanOptimizingInteractor`・`public_plan_optimizing_read_model`・`ManageablePublicPlanLookup`。基底から `handle_optimizing` を削除、`public_plans/optimizing` は `@public_plan_optimizing` DTO のみ参照（2026-05-06）。
- 天気取得レンジ／予測日数は `Domain::WeatherData::Policies::{WeatherDataFetchWindowPolicy,WeatherPredictionHorizonPolicy}` に移し、concern は `Time.zone` を clock として注入（2026-05-06）。
- `CultivationPlanManageable` を `CultivationPlanHtmlBaseController` に置換し `app/controllers/concerns/cultivation_plan_manageable.rb` を削除（2026-05-06）。
- `DeletionUndoResponder` を `ApplicationController` のメソッドへインライン化し `app/controllers/concerns/deletion_undo_responder.rb` を削除（2026-05-06）。応答ペイロード組み立ては上記 PayloadInteractor / DualFormatResponder へ後続移管済み。
- エントリ作物スケジュール API の ETag 応答は `EntryScheduleJsonRendering` concern を廃止し、`Presenters::Api::PublicPlans::EntryScheduleEtagJsonRendering` に集約（2026-05-06）。
- OAuth 成功リダイレクトの `_agrr_oauth` クエリ付与は `Adapters::Application::OauthConversionUrlAppender`（`CompositionRoot.oauth_conversion_url_appender`）へ集約（2026-05-06）。
