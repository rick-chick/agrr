# CA Violations Backlog

最終全量スキャン: 2026-05-06T00:00:00Z / 直近裏取り: 2026-05-06（AI Pest 作物関連付けは `PestMemoryGateway` へ移管しコントローラから `rescue ActiveRecord::ActiveRecordError` を除去）。2026-05-06: 計画系バックグラウンド Job の `rescue StandardError` を整理（例外集合はアプリ縁側 `app/jobs/cultivation_plan_job_exceptions.rb`、`CultivationPlanJobExceptions`、監視 Job は `ActiveRecord::ActiveRecordError`、チェーンランナーは冗長 rescue 削除）。`MonitorMigrationStatusJob` は Rails 8 の `pending_migration_versions` に合わせ、ジョブテストは DB 破壊をやめスタブ化。

## 修正単位

- [ ] **HTML / concerns の横断ロジック（deletion_undo_flow, agrr_optimization 等）** — Application edge 1（Sideways escape・Concern 負債） @ `app/controllers/concerns/`

- [ ] **その他 API の広い rescue（AgrrService+RuntimeError、JSON パース、システムコール等）** — 禁止 3 の意味読みで個別に棚卸し @ `app/controllers/api/v1/fertilizes_controller.rb`, `app/controllers/api/v1/crops_controller.rb`, `app/controllers/concerns/cultivation_plan_api.rb`, 他

## スキャン補足

- `lib/domain` における `Date.current` / `CompositionRoot` はコメント参照のみで実コード違反ではなかった。
- `lib/presenters` に `CompositionRoot` / `Gateway.default` の実呼び出しはスキャン上ヒットなし。
- フロント `usecase` → `adapters` 直 import、`domain` → `@angular/*` の機械検出はヒットなし（フロントは設計変更時に再確認）。
