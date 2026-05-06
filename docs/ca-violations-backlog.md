# CA Violations Backlog

最終全量スキャン: 2026-05-06T00:00:00Z / 直近裏取り: 2026-05-06（AI Pest 作物関連付けは `PestMemoryGateway` へ移管しコントローラから `rescue ActiveRecord::ActiveRecordError` を除去）。2026-05-06: 計画系バックグラウンド Job の `rescue StandardError` を整理（例外集合はアプリ縁側 `app/jobs/cultivation_plan_job_exceptions.rb`、`CultivationPlanJobExceptions`、監視 Job は `ActiveRecord::ActiveRecordError`、チェーンランナーは冗長 rescue 削除）。`MonitorMigrationStatusJob` は Rails 8 の `pending_migration_versions` に合わせ、ジョブテストは DB 破壊をやめスタブ化。

## 修正単位

- [ ] **天気データ取得期間・予測日数の算出をドメインへ** — `WeatherDataManagement#calculate_weather_data_params` / `#calculate_predict_days` は業務判断（取得幅・予測終端）。Interactor または domain policy に切り出し、controller / job は Interactor の出力 DTO を受け取るだけにする。`CompositionRoot.calendar_today` への依存は注入された clock に置き換える。@ `app/controllers/concerns/weather_data_management.rb` — Application edge 1 / domain 4
- [ ] **エントリ作物スケジュールの ETag 応答を Presenter / 薄い HTTP ヘルパへ** — `EntryScheduleJsonRendering#render_entry_json_with_etag` は payload→ETag→`If-None-Match` 比較を controller mixin で行う。payload 生成は Interactor に置き、ETag 計算と分岐は Presenter または HTTP edge ヘルパに移し、controller は呼び分けない。@ `app/controllers/concerns/entry_schedule_json_rendering.rb` — Application edge 1
- [ ] **OAuth コンバージョンクエリ付与を adapter へ** — `OauthConversionRedirect#append_oauth_conversion_query` は OAuth 計測の振る舞い。adapter（純粋 Ruby の URL ビルダ）に切り出し、controller は注入された adapter を呼ぶだけにする。@ `app/controllers/concerns/oauth_conversion_redirect.rb` — Application edge 1
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
- `CultivationPlanManageable` を `CultivationPlanHtmlBaseController` に置換し `app/controllers/concerns/cultivation_plan_manageable.rb` を削除（2026-05-06）。
- `DeletionUndoResponder` を `ApplicationController` のメソッドへインライン化し `app/controllers/concerns/deletion_undo_responder.rb` を削除（2026-05-06）。応答ペイロード組み立ては上記 PayloadInteractor / DualFormatResponder へ後続移管済み。
