# CA Violations Backlog

最終通し走査: 2026-05-06（禁止 1〜30 の全文スキャンは未実施）

## 修正単位

- [ ] **FarmsController `destroy` の JSON** — ARCHITECTURE.md **Application edge and tests → 4** @ `app/controllers/farms_controller.rb`
  - `free_crop_plans` 判定と `DeletionUndo::HtmlMasterScheduleInvoker` 呼び出しがコントローラに残る（ドメイン結果の組み立てをインタラクターへ）

## スキャン補足

- 2026-05-06: HTML `GET/PATCH /farms` の JSON は `FarmDetailInteractor` / `FarmUpdateInteractor` と API 系 Presenter（`render_response`）に統一済み。
