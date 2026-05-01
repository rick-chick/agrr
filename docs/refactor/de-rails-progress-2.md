# de-rails-complete-remaining 実行進捗

実行日: 2026-04-30

## 完了タスク (6 / 23)

| ID | タスク | 結果 |
|---|---|---|
| t20 | ベースライン記録 | ✅ 全テスト緑 (1613/0/0) を確認、`docs/refactor/de-rails-baseline-2.md` 作成 |
| t21 | Field Gateway 拡張 | ✅ `find_authorized_for_view/edit` / `create_for_user` / `update_for_user` / `soft_destroy_with_undo` を Domain interface + Adapter 実装に追加 |
| t22 | Adapter AR 例外翻訳 | ✅ 36 サイトで `StandardError`/`ActiveRecord::*` を `Domain::Shared::Exceptions::RecordNotFound` / `RecordInvalid` / `AssociationInUse` に翻訳。`lib/domain/shared/exceptions/record_invalid.rb` を新設（`errors`/`record` を保持できる構造）。ContactMessages の interactor + テストも追従。 |
| t24 | Logger/Translator Port 抽象化 | ✅ `Domain::Shared::Ports::LoggerPort` / `TranslatorPort` を新設し、`lib/domain` 配下 59+ 箇所の `Adapters::Logger::Gateways::RailsLoggerGateway.new` / `Adapters::Translators::RailsTranslator.new` 直 new を Port `default` 経由に置換 |
| t35 | 他 concerns cleanup | ✅ `deletion_undo_flow` で `AssociationInUse` rescue を追加、`cultivation_plan_manageable` の AR rescue に Domain 例外を追加、`job_execution` の `CultivationPlan.find` を `find_by(id:)` + nil ガードに変更（broadcast_to が AR を要求するため AR モデルは局所維持、コメントで明示） |
| t40 | Backdoor 除外宣言 | ✅ `docs/refactor/backdoor-exclusion.md` 作成。最終 audit クエリでの除外パターン明記 |

## 部分着手 / 後続作業に集約

| ID | タスク | 状態 |
|---|---|---|
| t23 | `find_authorized_model_for_*` private 降格 | t25–t32 (各ドメイン E2E) と統合実施。Form Object + Presenter + View 変更が前提のため、各ドメインの作業内で完結させる必要がある |
| t41 | テスト緑＋遅延テスト確認 | 各タスク完了時に `run-test-rails.sh` 緑を維持。最終確認は他タスク完了後に実施 |

## 未着手（規模順）

| ID | タスク | 推定工数 / リスク |
|---|---|---|
| t29 | Crop/CropStage/Requirements ドメイン E2E (深さ 2 段ネスト) | **最大規模**。Form Object × 2 (`crop_form` / `crop_stage_form`)、6+ controllers の 22+ 件、多テスト更新。1.5–2 日 |
| t33 | `cultivation_plan_api.rb` 解体 (40+ 件) | 6+ Interactor 新設、Adapter Gateway API 拡張、テスト追加。1–1.5 日 |
| t34 | `agrr_optimization.rb` 解体 (transaction/upsert_all/insert_all/delete_all) | Adapter `bulk_*` API 追加、トランザクション境界委譲。1 日 |
| t36 | Plan controllers cleanup (35+ 件) | 4 controllers、TaskScheduleItem 系 Interactor 追加多数。1.5 日 |
| t28 | AgriculturalTask ドメイン E2E (Form Object × 2 + 19 controller 件) | Form Object 設計 + view 書換多数。1 日 |
| t30 | Farm ドメイン E2E (17 件) | Form Object × 2、`weather_data_controller` の AR find を Interactor 化。1 日 |
| t37 | PublicPlan controllers cleanup (15 件) | 5 controllers、wizard / entry_schedule の find を Interactor 化。1 日 |
| t31 | Field ドメイン E2E (3 件 + Form Object × 2) | t21 の Gateway 拡張は完了済み、view 書換と controller 整理。0.5 日 |
| t25 | Pest ドメイン E2E (Form Object × 2 + 2 件) | nested attributes 含む。0.5 日 |
| t39 | api/v1 deep adapters cleanup (Pest/Fertilize/Crop の AI 系 Adapter 直接 new) | Interactor 経由 + Gateway 拡張。0.5 日 |
| t26 | Pesticide ドメイン E2E (Form Object × 1 + 2 件) | nested attributes。0.5 日 |
| t27 | Fertilize ドメイン E2E (Form Object × 1 + 3 件 + AR rescue 整理) | nested なし。0.5 日 |
| t32 | InteractionRule ドメイン E2E (Form Object × 1 + 2 件) | 最も小規模。0.3 日 |
| t38 | FieldCultivation controllers (3 件) | Gateway 拡張 + Interactor 追加。0.3 日 |
| t42 | 最終 rg 監査 | 全タスク完了後の確認。0.2 日 |

**残推定: 12–15 営業日**

## 違反箇所のベースライン比較

| 観点 | 着手前 | 現在 |
|---|---|---|
| `lib/domain` の AR 定数参照 | 0 | 0 |
| `lib/domain` の `ActiveRecord::` 参照 (実コード) | 0 | 0 |
| `lib/domain` の `rescue ActiveRecord::` | 0 | 0 |
| `lib/domain` の Adapter 直接 `.new` (Logger/Translator) | 59 | 0 (Port 経由のみ) |
| Adapter Gateway の `StandardError` raise | 36+ | 約 35 (主に validation メッセージ。AR 例外起源は Domain 例外に翻訳済み) |
| `find_authorized_model_for_*` public 数 | 14 | 14 (各ドメイン E2E と同時実施) |
| `form_with model:` view ファイル数 | 12 | 12 (各ドメイン E2E で順次置換) |
| concerns 内 AR rescue 漏れ | 6 | 0 (Domain 例外で受けるよう変更) |

## 次回セッションでの推奨アプローチ

1. ドメイン E2E (t25–t32) を **`feature-orchestrator` ルールに従いサブエージェント並列起動** で各ドメイン 1 メッセージで実装。`controller-server` / `usecase-server` / `presenter-server` / `gateway-server` を同時呼び出し。
2. concerns 解体 (t33–t34) は別セッションで集中実施（Adapter Gateway 拡張が広範囲）。
3. Plan/PublicPlan 系 controller (t36–t37) は concerns 解体完了後に実施（依存）。
4. 最終 audit (t42) は全完了後。

## 全テスト緑の維持

各タスク完了時に `.cursor/skills/test-common/scripts/run-test-rails.sh` 緑 (1613 runs, 0 failures, 0 errors, 9 skips) を継続して維持しているため、本進捗時点でリグレッションは無し。
