# CA 違反バックログ（`clean-architecture-violation-fix-workflow` セクション0 / 6）

全体スキャン: backlog 欠如時に実施（2026-05-06）。`rg` は補助。禁止番号は `ARCHITECTURE.md` に照合。

## 修正単位（先頭から処理）

1. **Application edge 3 — コントローラの `rescue StandardError` / `rescue_from` がユースケース結果の主スイッチ**
   - `rescue => e` は以下で撤去済み（2026-05-06）: `crops` / `pests` / `fertilizes` API、`internal_controller`、`internal/jobs_controller`、`backdoor_controller`、`farms/weather_data_controller`、`concerns/cultivation_plan_api`、`dev/client_logs_controller`、`health_controller`（いずれも例外型を列挙する形へ）。
   - **残**: Interactor + Presenter の一経路へ寄せるべき箇所（例: `api/v1/plans_controller.rb`、`contact_messages_controller.rb`、`api/v1/public_plans/entry_schedule_controller.rb`、HTML `plans/task_schedule_items_controller.rb` 等）。監査の索引用: `docs/ca-controller-rescue-audit.md`。

2. **Application edge 3 — `app/jobs/**` の `rescue => e`**
   - 例: `plan_finalize_job.rb`, `optimization_job.rb`, `task_schedule_generation_job.rb`, `weather_prediction_job.rb`, `chained_job_runner_job.rb`, `monitor_migration_status_job.rb`, `completion_notification_job.rb`。

3. **Application edge 1 / Sideways escape — `app/controllers/concerns/**` の `ActiveSupport::Concern` によるオーケストレーション共有**
   - レガシー負債。新規判断の追加禁止。段階的に `lib/domain` + 注入へ畳み込む。

4. **`lib/domain` 以外の `raise StandardError`（アダプター・モデル）**
   - `lib/adapters/**/gateways/*_active_record_gateway.rb`（境界で `StandardError` にラップ）
   - `app/models/crop.rb`, `app/models/pesticide.rb`
   - 個別照合: ドメイン例外へのマッピング可否。

## 解消済み（記録）

- **コントローラの `rescue => e`（バックログで列挙していた API / concern / dev / health 10 ファイル）**（2026-05-06）: 例外型を明示。作物・害虫 AI は agrr 失敗を `AgrrService::*` に寄せ、`internal` / `weather_data` は投入・永続化例外に限定。
- **weather_data — `FetchWeatherDataPerformInteractor` の裸 `raise StandardError`**（2026-05-06）: `InvalidWeatherApiResponseError` 等の名前付きサブクラスに置換。`FetchWeatherDataJob` の `retry_on StandardError` は維持。

## フロント（スキャン結果）

- `frontend/src/app/usecase` から `adapters/` への直 import、`domain/` からの `HttpClient`: **該当 grep なし**（現時点）。

## スキャンで空だったパターン（記録のみ）

- `lib/domain` / `app/jobs` / `lib/presenters` で `rescue StandardError|Exception`（表のパターン）: 当時ヒットなし。`app/controllers` は 2026-05-06 時点で `rescue StandardError` が複数残存（インフラ・補助境界の明示化）。一致のみで違反判定しない。
- `rescue ActiveRecord::`（上記パス）: ヒットなし
- `rescue_from`（`app/controllers`）: ヒットなし
- `CompositionRoot` / `Gateway.default` / `Port.default`（`lib/domain` 実コード、`lib/presenters`）: ヒットなし（コメントのみ可）
- `lib/presenters` の `Date.current` / `.where(` : ヒットなし
