# CA Violations Backlog

最終通し走査: 未実施 / 直近裏取り: none

## 修正単位

1. **`ARCHITECTURE.md` の `## What we require` と禁止 1〜30 の通し走査** — 全対象レイヤーを `Glob` / `Read` で意味読み照合し、違反を修正単位に切って列挙する（`rg` の一致のみを根拠にしない）。空到達時の裏取りとして必須。

## スキャン補足

- 2026-05-06: `InteractionRulesController` destroy を `InteractionRuleDestroyInteractor` + HTML/API Presenter に統一（ゲートウェイ preload・controller `rescue` 撤去）。`InteractionRuleDeletePresenter` の JSON `redirect_path` は HTML コントローラが `interaction_rules_path` を返すフックに変更。
- 2026-05-06: `PublicPlansController#create` の `create_job_instances_for_public_plans` を削除し、`PublicPlanOptimizationJobChainGateway#enqueue_after_create!`（`redirect_path` 引数）経由に集約。
- 2026-05-06: `PestsController#destroy` の HTML を `PestDestroyInteractor` + `PestDestroyHtmlPresenter` に統一（`HtmlMasterScheduleInvoker` と `PolicyPermissionDenied` の `rescue` 撤去）。`AgriculturalTasksController#destroy` の JSON からデッドな `rescue PolicyPermissionDenied` を削除。
- 探索ヒント（未確定・READ 要）: `app/controllers` に `PolicyPermissionDenied` 等の controller 側 `rescue` が残るアクションがある（例: マスタ以外・API の `AgrrService` 周り）。各件は Application edge と禁止 3 の観点で個別に判定すること。
