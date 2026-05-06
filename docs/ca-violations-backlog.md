# CA 違反バックログ（`clean-architecture-violation-fix-workflow` セクション0 / 6）

全体スキャン: backlog 欠如時に実施（2026-05-06）。`rg` は補助。禁止番号は `ARCHITECTURE.md` に照合。

## 修正単位（先頭から処理）

1. **Application edge 1 / Sideways escape — `app/controllers/concerns/**` の `ActiveSupport::Concern` によるオーケストレーション共有**
   - レガシー負債。新規判断の追加禁止。段階的に `lib/domain` + 注入へ畳み込む。
   - **残り（優先）**: `AgrrOptimization` concern の `calculate_effective_planning_period`（`Date.current` 等エッジ依存）・他 API 経路の concern（`cultivation_plan_api` 等）。

## 解消済み（記録）

- **`agrr_optimization#adjust_with_db_weather` 主導線 — Interactor + Plan Gateway + CompositionRoot 配線**（2026-05-06）: オーケストレーションを `Domain::CultivationPlan::Interactors::AdjustWithDbWeatherInteractor` に集約。`AdjustWithDbWeatherPlanGateway` / `AdjustWithDbWeatherPlanActiveRecordGateway` / `AgrrOptimizationPayloadBuilder` でセッション・AR 写像をアダプターに閉じる。concern の `adjust_with_db_weather` は `CompositionRoot.adjust_with_db_weather_interactor` への委譲のみ。非本番デバッグ JSON は `CompositionRoot#adjust_with_db_weather_debug_dump`。
- **`raise StandardError` の削減 — Crop/Pesticide agrr 連携・削除 Undo アダプター**（2026-05-06）: `Crop#to_agrr_requirement` / `associate_pests_from_agrr_output`、`Pesticide.from_agrr_output` の入力不備は `ArgumentError` に統一。`Farm` / `AgriculturalTask` / `Fertilize` の `destroy` で `DeletionUndo::Error` を `StandardError` に変換せず伝播（Interactor が捕捉）。
- **`agrr_optimization` concern — adjust 時の実測＋予測気象の AGRR 形式化とマージ**（2026-05-06）: 観測行の整形・平均気温算出・日照秒変換・予測 `data` 連結を `Domain::WeatherData::Services::AdjustHistoricalPredictionMerger` に集約。concern は AR 行からプレーン Hash へ写像して委譲。項目 1（concern 本体の他メソッド・`CompositionRoot` 呼び出し等）は継続。
- **`agrr_optimization` — `save_adjusted_result` の Agrr adjust 結果永続化**（2026-05-06）: FieldCultivation 差分 upsert/insert・TaskSchedule の null 化・未使用 plan crop 削除・計画サマリ更新を `SaveAdjustedAgrrResultGateway`（IF）/`SaveAdjustedAgrrResultActiveRecordGateway`（AR）へ移動。`clock`・`LoggerGateway` を `CompositionRoot` から注入。`AgrrOptimization#save_adjusted_result` は `plan_id` 委譲のみ。項目 1 の残り: concern のエッジ依存・他 controller concerns。
- **`agrr_optimization` — 最適化完了の Action Cable 通知**（2026-05-06）: `Domain::CultivationPlan::Gateways::CultivationPlanRestOptimizationEventsGateway` に `broadcast_optimization_complete` を追加。実装は `CultivationPlanRestOptimizationEventsActionCableGateway`（channel 選択・`broadcast_to`・従来どおり狭い rescue）。`CompositionRoot.cultivation_plan_rest_optimization_events_gateway` を本番配線に追加し、`AgrrOptimization` / `CultivationPlanApi` から委譲。
- **`agrr_optimization` concern — fields / crops / interaction_rules のペイロード組み立て**（2026-05-06）: `build_fields_config`・`build_crops_config`・`build_interaction_rules` を `AgrrFieldsConfigCalculator` / `AgrrCropsConfigCalculator` / `AgrrInteractionRulesCalculator` に委譲。AR・ログ・乱数はエッジで組み立て・注入。`adjust_with_db_weather` 等は項目 1 に残る。
- **`agrr_optimization` concern — `build_current_allocation` の AGRR ペイロード集計**（2026-05-06）: `optimization_result` の純粋組み立てを `Domain::CultivationPlan::Calculators::AgrrCurrentAllocationCalculator` へ。Concern は AR 走査・フィルタ・`field_rows` 組み立てとログ。Interactor テストに相当する振る舞いはドメイン計算機の単体テストで固定。
- **`agrr_optimization` concern — 有効計画期間の算出**（2026-05-06）: `calculate_effective_planning_period` を `Domain::CultivationPlan::Calculators::EffectivePlanningPeriodCalculator` へ移動。`as_of` 注入・`lib/domain` では `Date.current` / ActiveSupport duration 不使用（禁止 4）。無効日付は `EffectivePlanningPeriodInvalidDateError`、concern で既存 I18n に写像。concern 本体・他 concern はバックログ項目 1 に残る。
- **Application edge 3 — `app/controllers/**`（および `app/controllers/concerns/**`）の `rescue StandardError` / 広い `rescue`**（2026-05-06）: `rg 'rescue StandardError' app/controllers` は一致なし。`get_or_predict_weather` はインフラ・アダプター例外のみで `nil` フォールバック。crops/pests の agrr リトライは `SystemCallError`/`IOError`/`SocketError`/`Timeout::Error` のみ。`associate_crops_from_api` は `ActiveRecord::ActiveRecordError` のみ。
- **`api/v1/internal/jobs#trigger_weather_update` / `dev/client_logs#create` / `cultivation_plan_api#run_candidates`**（2026-05-06）: スケジューラ投入は `ActiveJob::EnqueueError` と `ActiveRecord::ActiveRecordError` のみ。開発ログ受信は広い rescue を削除。候補実行は `Agrr::BaseGatewayV2::*` / `JSON::ParserError` / `SystemCallError` に限定。
- **`health_controller#show` / `api/v1/backdoor#status` の広い `rescue StandardError`**（2026-05-06）: DB 接続・クエリ由来のみ（`HEALTH_DB_EXCEPTIONS`）、バッククォートは `SystemCallError`。ユースケースの二重分岐ではなくインフラ境界に限定。
- **`ContactMessages` API — コントローラの `rescue`（reCAPTCHA / レート制限）**（2026-05-06）: `CreateContactMessageInteractor` が `verify` / `track` の結果で `on_failure`（種別: validation / recaptcha / rate_limit）。Presenter が HTTP ステータスを分担。
- **`app/jobs/**` の `rescue => e`（`optimization_job`, `weather_prediction_job`, `task_schedule_generation_job`, `plan_finalize_job`, `monitor_migration_status_job`, `completion_notification_job`, `chained_job_runner_job`）**（2026-05-06）: `rescue StandardError => e` に明示（挙動は従来どおり `raise` 継続）。
- **コントローラの `rescue => e`（バックログで列挙していた API / concern / dev / health 10 ファイル）**（2026-05-06）: 例外型を明示。作物・害虫 AI は agrr 失敗を `AgrrService::*` に寄せ、`internal` / `weather_data` は投入・永続化例外に限定。
- **weather_data — `FetchWeatherDataPerformInteractor` の裸 `raise StandardError`**（2026-05-06）: `InvalidWeatherApiResponseError` 等の名前付きサブクラスに置換。`FetchWeatherDataJob` の `retry_on StandardError` は維持。

## フロント（スキャン結果）

- `frontend/src/app/usecase` から `adapters/` への直 import、`domain/` からの `HttpClient`: **該当 grep なし**（現時点）。

## スキャンで空だったパターン（記録のみ）

- `lib/domain` / `lib/presenters` で `rescue StandardError|Exception`（表のパターン）: 当時ヒットなし。`app/controllers` / `app/jobs` は 2026-05-06 時点で `rescue StandardError` を複数で使用（`rescue => e` 撤去に伴う明示化）。一致のみで違反判定しない。
- `rescue ActiveRecord::`（上記パス）: ヒットなし
- `rescue_from`（`app/controllers`）: ヒットなし
- `CompositionRoot` / `Gateway.default` / `Port.default`（`lib/domain` 実コード、`lib/presenters`）: ヒットなし（コメントのみ可）
- `lib/presenters` の `Date.current` / `.where(` : ヒットなし
