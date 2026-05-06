# CA Violations Backlog

最終全量スキャン: 2026-05-06T08:20:00Z / 直近裏取り: 2026-05-06（`rg` 表＋コントローラ／ジョブ／Presenter の rescue・時刻の spot read。リポジトリに新規 backlog 項目なし）。コミット `b32388af`: `DeletionUndoFlow` 削除・`RecordInvalid` から AR `record` 除去・`ContactMessage` エンティティの `ActiveModel` 依存除去をマージ済み。

## 修正単位

（なし）

## スキャン補足

- `lib/domain` における `Date.current` / `CompositionRoot` はコメント参照のみで実コード違反ではなかった。
- `lib/presenters` に `CompositionRoot` / `Gateway.default` の実呼び出しはスキャン上ヒットなし。
- フロント `usecase` → `adapters` 直 import、`domain` → `@angular/*` の機械検出はヒットなし（フロントは設計変更時に再確認）。
- `AgrrOptimization` controller concern は本番未使用のため削除済み（2026-05-06）。統合テストは `CompositionRoot` 経由。
- 削除 Undo の HTML/JSON 二形式応答は `DeletionUndoScheduleSuccessPayloadInteractor`・`Presenters::DeletionUndo::DualFormatResponder`・`ApplicationController#render_deletion_undo_dual_success` / `#render_deletion_undo_dual_failure` に整理済み（2026-05-06）。
- `JobExecution` concern を削除し、ジョブチェーン非同期投入は `Adapters::Application::JobChainAsyncDispatcher`（`CompositionRoot.job_chain_async_dispatcher`）へ集約（2026-05-06）。
- 2026-05-06: `DeletionUndoFlow` concern を削除し、HTML マスタ削除は各コントローラから `DeletionUndo::HtmlMasterScheduleInvoker` を直接呼び出し（Application edge 1 の concern 判断増殖を削減）。`Domain::Shared::Exceptions::RecordInvalid` は `ValidationErrors` のみ運び AR インスタンスを載せない。`ContactMessage` エンティティは純 Ruby バリデーションに置換（domain 1）。
- `CultivationPlanApi` モジュールを `Api::V1::CultivationPlanRestBaseController` に置換し `app/controllers/concerns/cultivation_plan_api.rb` を削除（2026-05-06）。
- 栽培計画 REST 基底: ワークベンチ／adjust／add_crop コーディネータの具象組み立てを `CompositionRoot` に集約し、`add_crop` の冗長ログを除去（2026-05-06）。
- 公開計画 optimizing: `PublicPlanOptimizingInteractor`・`public_plan_optimizing_read_model`・`ManageablePublicPlanLookup`。基底から `handle_optimizing` を削除、`public_plans/optimizing` は `@public_plan_optimizing` DTO のみ参照（2026-05-06）。
- 天気取得レンジ／予測日数は `Domain::WeatherData::Policies::{WeatherDataFetchWindowPolicy,WeatherPredictionHorizonPolicy}` に移し、concern は `Time.zone` を clock として注入（2026-05-06）。
- `CultivationPlanManageable` を `CultivationPlanHtmlBaseController` に置換し `app/controllers/concerns/cultivation_plan_manageable.rb` を削除（2026-05-06）。
- `DeletionUndoResponder` を `ApplicationController` のメソッドへインライン化し `app/controllers/concerns/deletion_undo_responder.rb` を削除（2026-05-06）。応答ペイロード組み立ては上記 PayloadInteractor / DualFormatResponder へ後続移管済み。
- エントリ作物スケジュール API の ETag 応答は `EntryScheduleJsonRendering` concern を廃止し、`Presenters::Api::PublicPlans::EntryScheduleEtagJsonRendering` に集約（2026-05-06）。
- OAuth 成功リダイレクトの `_agrr_oauth` クエリ付与は `Adapters::Application::OauthConversionUrlAppender`（`CompositionRoot.oauth_conversion_url_appender`）へ集約（2026-05-06）。
- AI 肥料 `FertilizesController#ai_*` のフォールバック `rescue` は `AgrrService::AgrrError` に限定（`ArgumentError` / `RuntimeError` の広域マッピングをやめた）。AI 作物 `CropsController#ai_create` は agrr 取得失敗を `fetch_crop_info_from_agrr_with_handled_errors` に閉じ、メインの HTTP 応答経路を分割（2026-05-06）。
- `CultivationPlanRestBaseController#parse_display_date` の `rescue ArgumentError` は表示範囲パラメータのガードのみ（ARCHITECTURE.md「Modeled HTTP outcomes」の「DTO 前のガード」として許容。Application edge 3 の主スイッチではない）。
