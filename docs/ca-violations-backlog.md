# CA Violations Backlog

最終通し走査: 2026-05-06（禁止 1〜30 の全文スキャンは未実施）

## 修正単位

（なし）

## スキャン補足

- 2026-05-06: HTML `DELETE /farms/:id` の JSON は `FarmDestroyInteractor` + `FarmDestroyJsonPresenter`。`free_crop_plans` ブロックは `FarmActiveRecordGateway#soft_destroy_with_undo` に集約（HTML / JSON 共通）。
