# CA Violations Backlog

最終通し走査: 2026-05-06（禁止 1〜30 の全文スキャンは未実施）

## 修正単位

1. **次優先**: `InteractionRulesController` の rescue をエッジの振る分けに整理する（現状の rescue-as-edge-switch の扱いを契約に沿って見直す）。
2. `PublicPlansController` の `create_job_instances_for_public_plans` 重複（Wizard 側はゲートウェイへ移済み。HTML 経路の重複は別修正単位）。
3. `ARCHITECTURE.md` 禁止 1〜30 の全文スキャン未実施（バックログとして残す）。

## スキャン補足

- 2026-05-06: HTML `DELETE /farms/:id` の JSON は `FarmDestroyInteractor` + `FarmDestroyJsonPresenter`。`free_crop_plans` ブロックは `FarmActiveRecordGateway#soft_destroy_with_undo` に集約（HTML / JSON 共通）。
- 2026-05-06: `PublicPlanCreatePresenter` のジョブエンキュー / `Rails.logger` を撤去し、`PublicPlanOptimizationJobChainGateway` + AR アダプタ + Interactor 注入に移行（Presenter 禁止4 解消）。
