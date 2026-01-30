# デッドコード調査レポート

**調査日**: 2026-01-30  
**対象**: バックエンド（Rails）を中心に、既存ドキュメントとコード参照からデッドコード候補を特定。

---

## 1. 確実にデッドコード（削除推奨）

### 1.1 AgriculturalTaskCrop モデル

| 項目 | 内容 |
|------|------|
| **ファイル** | `app/models/agricultural_task_crop.rb` |
| **理由** | `agricultural_task_crops` テーブルはマイグレーション `20251111120000_drop_agricultural_task_crops.rb` で削除済み。schema.rb にテーブルなし。 |
| **参照状況** | アプリケーションコードで `AgriculturalTaskCrop` クラスを参照している箇所は**なし**（マイグレーション内の `TempAgriculturalTaskCrop` は別クラス）。`PlanSaveService#copy_agricultural_task_crop_relationships` はメソッド名のみ「agricultural_task_crop」で、実装は `CropTaskTemplate` を使用。 |
| **リスク** | モデルが残っていると、誰かが誤って `AgriculturalTaskCrop` を参照した際に `ActiveRecord::StatementInvalid` が発生する。 |
| **推奨** | **モデルファイルを削除**する。 |

---

### 1.2 GenerateFreeCropPlanJob

| 項目 | 内容 |
|------|------|
| **ファイル** | `app/jobs/generate_free_crop_plan_job.rb` |
| **理由** | 本 Job を enqueue するコードが**存在しない**（`GenerateFreeCropPlanJob.perform_later` や `perform` の呼び出しを検索してもヒットなし）。 |
| **補足** | `FreeCropPlan` モデル・テーブルは以下でまだ参照されているため、モデル削除は別扱い。 |
|  | • `Farm` / `Crop` の `has_many :free_crop_plans` |
|  | • `FarmsController#destroy` の削除可否チェック（`@farm.free_crop_plans.any?`） |
|  | • `DeletionUndo::FarmPreparationService` の `farm.free_crop_plans.destroy_all` |
|  | • `test/services/deletion_undo/farm_preparation_service_test.rb` の FreeCropPlan 利用 |
| **Job 内の不整合** | `generate_plan` 内で `free_crop_plan.region` を参照しているが、`free_crop_plans` テーブルに `region` カラムはない（schema 上は `farm_id`, `crop_id`, `session_id`, `area_sqm`, `status`, `plan_data` のみ）。実行されれば `NoMethodError` または nil 参照の可能性。 |
| **推奨** | **Job クラスを削除**する。FreeCropPlan のレガシーデータ・関連は「非推奨だが互換のため保持」として、Job だけデッドコードとして整理する。 |

---

## 2. 既に削除済み（ドキュメントのみ古い）

### 2.1 CropTaskTemplateBackfillService

| 項目 | 内容 |
|------|------|
| **状況** | `app/services/` に **存在しない**（既に削除済み）。 |
| **参照** | `db/migrate/20251111091500_add_agricultural_task_to_crop_task_templates.rb` のコメント内に「CropTaskTemplateBackfillServiceは移行完了後、削除されました」と記載あり。 |
| **推奨** | 対応不要。`docs/analysis/drop_agricultural_task_crops_*.md` などで「サービスを削除する」と書いてある場合は、現状に合わせて「削除済み」にドキュメント更新可。 |

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
| **ARCHITECTURE.md** | 「`agricultural_task` domain code exists but is unused」と記載あり。 |
| **実態** | **使用されている**。 |
|  | • `app/controllers/agricultural_tasks_controller.rb` で `AgriculturalTaskListInteractor`, `AgriculturalTaskDetailInteractor`, `AgriculturalTaskCreateInteractor`, `AgriculturalTaskUpdateInteractor`, `AgriculturalTaskDestroyInteractor` を利用。 |
|  | • `app/controllers/api/v1/masters/agricultural_tasks_controller.rb` でも上記 Interactor を利用。 |
| **推奨** | **ARCHITECTURE.md の該当 Note を削除または「使用中」に修正**する。 |

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

| 優先度 | アクション | 対象 |
|--------|------------|------|
| 高 | モデルファイル削除 | `app/models/agricultural_task_crop.rb` |
| 高 | Job クラス削除 | `app/jobs/generate_free_crop_plan_job.rb` |
| 中 | ドキュメント修正 | `ARCHITECTURE.md` の agricultural_task に関する「unused」記述を削除または修正 |
| 低 | ドキュメント更新 | `docs/analysis/drop_agricultural_task_crops_*.md` 等で CropTaskTemplateBackfillService / Rake を「削除済み」と明記 |

---

## 6. 呼び出し関係メモ（検証用）

- **AgriculturalTaskCrop**: アプリコードでクラス参照なし。マイグレーションのみ `agricultural_task_crops` テーブル名を参照。
- **GenerateFreeCropPlanJob**: `perform_later` / `perform` の呼び出しなし。
- **PlanSaveService**: `copy_agricultural_task_crop_relationships` は `reference_task.crop_task_templates` と `ensure_crop_task_template!` で **CropTaskTemplate** のみ使用。AgriculturalTaskCrop は未使用。
