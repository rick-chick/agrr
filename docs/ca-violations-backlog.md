# CA 違反バックログ（`clean-architecture-violation-fix-workflow` セクション0 / 6）

全体スキャン: backlog 欠如時に実施（2026-05-06）。`rg` は補助。禁止番号は `ARCHITECTURE.md` に照合。

## 修正単位（先頭から処理）

1. **Application edge 3 — コントローラの `rescue StandardError` / 広い `rescue` がユースケース結果の主スイッチ**
   - `rescue => e` 撤去済み（コントローラ・jobs 列挙分）。`api/v1/contact_messages` は reCAPTCHA / レート制限を Interactor + Presenter `on_failure` に集約済み（2026-05-06）。
   - **残**: インフラ・AI 補助・Concern 内の `rescue StandardError`（`health_controller`、`internal/jobs_controller`、`backdoor`、`cultivation_plan_api`、`crops`/`pests` リトライ内等）の縮小またはドメイン結果型化。監査: `docs/ca-controller-rescue-audit.md`。

2. **Application edge 1 / Sideways escape — `app/controllers/concerns/**` の `ActiveSupport::Concern` によるオーケストレーション共有**
   - レガシー負債。新規判断の追加禁止。段階的に `lib/domain` + 注入へ畳み込む。

3. **`lib/domain` 以外の `raise StandardError`（アダプター・モデル）**
   - `lib/adapters/**/gateways/*_active_record_gateway.rb`（境界で `StandardError` にラップ）
   - `app/models/crop.rb`, `app/models/pesticide.rb`
   - 個別照合: ドメイン例外へのマッピング可否。

## 解消済み（記録）

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
