# CA Violations Backlog

最終全量スキャン: 2026-05-06T00:00:00Z / 直近裏取り: none

## 修正単位

- [ ] **Backdoor `clear_database` が `ActiveRecord::*` rescue で JSON 応答を決めている** — Application edge 3 @ `app/controllers/api/v1/backdoor/backdoor_controller.rb`

- [ ] **Scheduler internal `trigger_weather_update` の `ActiveRecord::ActiveRecordError` rescue** — Application edge 3（投入境界の設計要） @ `app/controllers/api/v1/internal/jobs_controller.rb`

- [ ] **AI Pest 作物関連付けでの `ActiveRecord::ActiveRecordError` 捕捉** — Application edge 3 の意味読み要（HTTP 主経路ではないが二重境界） @ `app/controllers/api/v1/pests_controller.rb`

- [ ] **複数 Job の `rescue StandardError`** — Application edge 3 の意味読み要（再 raise ありのものは主スイッチ性の評価要） @ `app/jobs/monitor_migration_status_job.rb`, `chained_job_runner_job.rb`, `optimization_job.rb`, `plan_finalize_job.rb`, `weather_prediction_job.rb`, `task_schedule_generation_job.rb`

- [ ] **Gateway のプレゼン依存（PageDto 等）** — Gateway boundary（presentation-agnostic）/ Rationalizations 22 系 @ `lib/adapters/cultivation_plan/gateways/cultivation_plan_active_record_gateway.rb`, `lib/adapters/farm/gateways/farm_active_record_gateway.rb`（`docs/ca-controller-rescue-audit.md` 参照）

- [ ] **HTML / concerns の横断ロジック（deletion_undo_flow, agrr_optimization 等）** — Application edge 1（Sideways escape・Concern 負債） @ `app/controllers/concerns/`

- [ ] **その他 API の広い rescue（AgrrService+RuntimeError、JSON パース、システムコール等）** — 禁止 3 の意味読みで個別に棚卸し @ `app/controllers/api/v1/fertilizes_controller.rb`, `app/controllers/api/v1/crops_controller.rb`, `app/controllers/concerns/cultivation_plan_api.rb`, 他

## スキャン補足

- `lib/domain` における `Date.current` / `CompositionRoot` はコメント参照のみで実コード違反ではなかった。
- `lib/presenters` に `CompositionRoot` / `Gateway.default` の実呼び出しはスキャン上ヒットなし。
- フロント `usecase` → `adapters` 直 import、`domain` → `@angular/*` の機械検出はヒットなし（フロントは設計変更時に再確認）。
