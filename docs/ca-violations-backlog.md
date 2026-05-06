# CA 違反バックログ（`clean-architecture-violation-fix-workflow` セクション0 / 6）

全体スキャン: backlog 欠如時に実施（2026-05-06）。`rg` は補助。禁止番号は `ARCHITECTURE.md` に照合。

## 修正単位（先頭から処理）

1. **Application edge 3 — API/HTML コントローラの `rescue => e` / 広い `rescue` が主スイッチ化**
   - 例: `app/controllers/api/v1/crops_controller.rb`, `pests_controller.rb`, `fertilizes_controller.rb`, `internal_controller.rb`, `backdoor_controller.rb`, `dev/client_logs_controller.rb`, `farms/weather_data_controller.rb`, `concerns/cultivation_plan_api.rb` 等。
   - 個別に意味読みし、Interactor の `on_failure` 一経路に寄せるか明示ハンドリングに分割。

2. **Application edge 3 — `app/jobs/**` の `rescue => e`**
   - 例: `plan_finalize_job.rb`, `optimization_job.rb`, `task_schedule_generation_job.rb`, `weather_prediction_job.rb`, `chained_job_runner_job.rb`, `monitor_migration_status_job.rb`, `completion_notification_job.rb`。

3. **Application edge 1 / Sideways escape — `app/controllers/concerns/**` の `ActiveSupport::Concern` によるオーケストレーション共有**
   - レガシー負債。新規判断の追加禁止。段階的に `lib/domain` + 注入へ畳み込む。

4. **`lib/domain` 以外の `raise StandardError`（アダプター・モデル）**
   - `lib/adapters/**/gateways/*_active_record_gateway.rb`（境界で `StandardError` にラップ）
   - `app/models/crop.rb`, `app/models/pesticide.rb`
   - 個別照合: ドメイン例外へのマッピング可否。

## 解消済み（記録）

- **weather_data — `FetchWeatherDataPerformInteractor` の裸 `raise StandardError`**（2026-05-06）: `InvalidWeatherApiResponseError` 等の名前付きサブクラスに置換。`FetchWeatherDataJob` の `retry_on StandardError` は維持。

## フロント（スキャン結果）

- `frontend/src/app/usecase` から `adapters/` への直 import、`domain/` からの `HttpClient`: **該当 grep なし**（現時点）。

## スキャンで空だったパターン（記録のみ）

- `lib/domain` / `app/controllers` / `app/jobs` / `lib/presenters` で `rescue StandardError|Exception`（表のパターン）: ヒットなし
- `rescue ActiveRecord::`（上記パス）: ヒットなし
- `rescue_from`（`app/controllers`）: ヒットなし
- `CompositionRoot` / `Gateway.default` / `Port.default`（`lib/domain` 実コード、`lib/presenters`）: ヒットなし（コメントのみ可）
- `lib/presenters` の `Date.current` / `.where(` : ヒットなし
