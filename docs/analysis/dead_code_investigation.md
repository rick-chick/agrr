# デッドコード調査レポート

**調査日**: 2026-01-30  
**対象**: バックエンド（Rails）を中心に、既存ドキュメントとコード参照からデッドコード候補を特定。

---

## 1. 既に削除済み（対応完了）

### 1.1 AgriculturalTaskCrop モデル

| 項目 | 内容 |
|------|------|
| **状況** | **削除済み**。`app/models/agricultural_task_crop.rb` は存在しない。 |
| **経緯** | `agricultural_task_crops` テーブルはマイグレーション `20251111120000_drop_agricultural_task_crops.rb` で削除済み。 |

### 1.2 GenerateFreeCropPlanJob

| 項目 | 内容 |
|------|------|
| **状況** | **削除済み**。`app/jobs/generate_free_crop_plan_job.rb` は存在しない。 |
| **経緯** | enqueue 呼び出しがなく、デッドコードとして削除済み。 |

---

## 2. 既に削除済み（ドキュメントのみ古い）

### 2.1 CropTaskTemplateBackfillService

| 項目 | 内容 |
|------|------|
| **状況** | `app/services/` に **存在しない**（既に削除済み）。 |
| **参照** | `db/migrate/20251111091500_add_agricultural_task_to_crop_task_templates.rb` のコメント内に「CropTaskTemplateBackfillServiceは移行完了後、削除されました」と記載あり。 |
| **推奨** | 対応不要。陳腐化していた `docs/analysis/drop_agricultural_task_crops_*.md` は削除済み（2026-05-08）。 |

### 2.2 crop_task_templates.rake

| 項目 | 内容 |
|------|------|
| **状況** | `lib/tasks/crop_task_templates.rake` は **存在しない**（一覧になし）。 |
| **推奨** | 対応不要。 |

---

## 3. ドキュメントの誤り（コードは使用中）

### 3.1 agricultural_task ドメイン

| 項目 | 内容 |
|------|------|
| **過去の調査メモ** | 以前、`ARCHITECTURE.md` に agricultural_task が未使用である旨の記述があったという報告があった。 |
| **現状（2026-05-07 確認）** | **ROOT の `ARCHITECTURE.md` に該当の「unused」記述はない**。ドメイン一覧では `agricultural_task` が他コンテキストと並列で列挙されているのみ。 |
| **実態** | **使用されている**。`app/controllers/agricultural_tasks_controller.rb`・`app/controllers/api/v1/masters/agricultural_tasks_controller.rb` 経由で各 AgriculturalTask Interactor が利用されている。 |
| **対応** | ARCHITECTURE の誤記修正タスクは **不要（解消済み／現行本文と整合）**。 |

---

## 4. 非推奨だが参照あり（デッドコードではない）

### 4.1 FreeCropPlan モデル

| 項目 | 内容 |
|------|------|
| **ファイル** | `app/models/free_crop_plan.rb` |
| **注釈** | モデル先頭に `@deprecated` と「CultivationPlan / FieldCultivation を使用すること」と記載あり。 |
| **参照** | Farm/Crop の関連、FarmsController、DeletionUndo::FarmPreparationService、テストで使用。 |
| **結論** | デッドコードではない。非推奨のまま互換性のために保持されている。 |

---

## 5. アクション一覧

| 優先度 | アクション | 状態 |
|--------|------------|------|
| ~~中~~ | ~~`ARCHITECTURE.md` の agricultural_task「unused」記述~~ | **完了**（現行本文に該当記述なし・2026-05-07） |
| ~~低~~ | ~~`docs/analysis/drop_agricultural_task_crops_*.md` の同期~~ | **完了**（ファイル削除・`docs/migration/crop_task_templates.md` 参照更新・2026-05-08） |

**削除済み**: AgriculturalTaskCrop モデル、GenerateFreeCropPlanJob、CropTaskTemplateBackfillService と `lib/tasks/crop_task_templates.rake`（コードベース上ファイルなし）

---

## 6. 呼び出し関係メモ（検証用）

- **AgriculturalTaskCrop**: モデル削除済み。テーブルはマイグレーションで削除済み。
- **GenerateFreeCropPlanJob**: Job 削除済み。
- **PlanSaveService**: `copy_agricultural_task_crop_relationships` は `reference_task.crop_task_templates` と `ensure_crop_task_template!` で **CropTaskTemplate** のみ使用。AgriculturalTaskCrop は未使用。
