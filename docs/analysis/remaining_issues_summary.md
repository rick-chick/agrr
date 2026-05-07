# 残りの問題サマリー（アーカイブ）

**2026-05-07（デッドコード削除ワークフロー整理）**

当時のスナップショットでは `CropTaskTemplateBackfillService`・`lib/tasks/crop_task_templates.rake`・`CropTaskTemplatesRakeTest` を「残課題」として列挙していた。現行リポジトリでは当該サービス・Rake・テストクラスは **存在しない**（削除済み）。以降のデッドコード・移行状況の要点は **`docs/analysis/dead_code_investigation.md`** を参照すること。

---

## 当時の記録（参照用・現状保証なし）

以下は過去のテスト実行サマリーおよび「当時残っていたと記録された項目」のメモである。行番号・ファイルパスは旧版に基づく。

- 実行数: 636 / アサーション: 2719 / 失敗: 0 / エラー: 3 / スキップ: 7（いずれも過去時点）
- `PlanSaveSessionTest` の `agricultural_task_crops` 参照は **現行テストでは対応済み** と過去メモにあった
- `CropTaskTemplateBackfillService` 系のコード上の残課題は **コード削除によりクローズ**

*2026-04-20: 公開プラン保存フローの E2E テストのファイル名・クラス名を `plan_save_session_test` / `PlanSaveSessionTest` に追随して参照を更新。*（歴史的注記）
