# cultivation_plan bounded context — P5 設計（Wave-5 G1）

> 生成: Wave-5 G1。実装状況は [TRACKING.yaml](./TRACKING.yaml) を正とする。

## サマリー

| 指標 | 値 |
|------|-----|
| Ruby ファイル（`lib/domain/cultivation_plan/`） | 234（サブディレクトリ + ルート 4） |
| domain-lib テスト（`test/domain/cultivation_plan/`） | 54 |
| 依存 BC | **field_cultivation**, **crop**, **shared**, **agricultural_task**（定数）, **public_plan**（間接） |

### Ruby インベントリ（層別）

| 層 | ファイル数 | S1 | S2 | S3 | S4 |
|----|-----------|----|----|----|-----|
| entities | 2 | — | — | — | — |
| dtos | 108 | — | 108 | — | — |
| interactors | 38 | — | — | 29 tested | — |
| policies | 7 | **5** tested | 2 R0 | — | — |
| calculators | 9 | **8** tested | 1 R0 | — | — |
| mappers | 16 | — | 16 | — | — |
| ports | 15 | — | — | — | 15 |
| gateways | 28 | — | — | — | 28 |
| normalizers | 1 | — | 1 | — | — |
| errors | 6 | 1（calculator 用） | 5 | — | — |
| root（`fields_allocation.rb` 等） | 4 | 定数のみ S1 | 残 | — | — |

## 他 BC への依存

| 依存先 | 用途（cultivation_plan 側） |
|--------|------------------------------|
| **shared** | `User`, `PolicyPermissionDenied`, `RecordInvalid`, `present?`, `deep_dup`, `ValidationErrors` |
| **field_cultivation** | 気候・同期・圃場栽培アクセス（plan スナップショット経由） |
| **crop** | 作物要件・テンプレ・AGRR requirement |
| **agricultural_task** | `ScheduleItemTypes` 定数、作業テンプレ |
| **public_plan** | 公開計画作成フロー（間接） |

## スライス順（Rust 移植）

| スライス | 内容 | 出口基準 |
|---------|------|----------|
| **S1** | policies（domain-lib テストあり）+ calculators（同上）+ `MAX_FIELDS` + calculator 用 error | `cargo test -p agrr-domain cultivation_plan` GREEN |
| **S2** | mappers + dtos（domain-lib テストありの 7 mapper + 4 dto のみ。R0 なし dto は別バックログ） | 同上 + `run-test-domain-lib.sh test/domain/cultivation_plan/{mappers,dtos}/` |
| **S3** | interactors（**domain-lib テストがあるもののみ**）+ entities | インタラクター単位で R0 済みリストと一致 |
| **S4** | gateway **trait のみ**（実装は Rails 維持） | trait 定義 + 既存 adapter 契約不変 |

## Policies

| Ruby | domain-lib テスト | S1 |
|------|-------------------|-----|
| `cultivation_plan_field_policy.rb` | yes | **done** |
| `cultivation_plan_optimization_complete_policy.rb` | yes | **done** |
| `private_cultivation_plan_access_policy.rb` | yes | **done** |
| `plan_read_authorization.rb` | yes | **done** |
| `task_schedule_item_create_policy.rb` | yes | **done** |
| `cultivation_plan_phase_policy.rb` | **no** | R0-pending |
| `task_schedule_item_update_policy.rb` | **no** | R0-pending |

## Calculators

| Ruby | domain-lib テスト | S1 |
|------|-------------------|-----|
| `agrr_crops_config_calculator.rb` | yes | **done** |
| `agrr_current_allocation_calculator.rb` | yes | **done** |
| `agrr_fields_config_calculator.rb` | yes | **done** |
| `agrr_interaction_rules_calculator.rb` | yes | **done** |
| `amount_unit_conversion_calculator.rb` | yes | **done** |
| `effective_planning_period_calculator.rb` | yes | **done** |
| `entry_schedule_stage_gdd_scaler.rb` | yes | **done** |
| `planning_date_calculator.rb` | yes | **done** |
| `cultivation_plan_optimization_progress_calculator.rb` | **no** | R0-pending |

## Interactors — domain-lib テスト **あり**（S3 対象）

| Interactor（Ruby ファイル名） | テストファイル |
|------------------------------|----------------|
| `add_crop_interactor` | `add_crop_interactor_test.rb` |
| `advance_cultivation_plan_phase_interactor` | `advance_cultivation_plan_phase_interactor_test.rb` |
| `crop_task_schedule_blueprint_copy_interactor` | `crop_task_schedule_blueprint_copy_interactor_test.rb` |
| `cultivation_plan_destroy_interactor` | `cultivation_plan_destroy_interactor_test.rb` |
| `cultivation_plan_initialize_interactor` | `cultivation_plan_initialize_interactor_test.rb` |
| `cultivation_plan_optimize_interactor` | `cultivation_plan_optimize_interactor_test.rb` (+ `*_interaction_rules_test.rb`) |
| `plan_allocation_adjust_interactor` | `plan_allocation_adjust_interactor_test.rb` |
| `plan_copy_interactor` | `plan_copy_interactor_test.rb` |
| `plan_save_ensure_user_agricultural_tasks_interactor` | `plan_save_ensure_user_agricultural_tasks_interactor_test.rb` |
| `plan_save_ensure_user_crops_interactor` | `plan_save_ensure_user_crops_interactor_test.rb` |
| `plan_save_ensure_user_farm_interactor` | `plan_save_ensure_user_farm_interactor_test.rb` |
| `plan_save_ensure_user_fertilizes_interactor` | `plan_save_ensure_user_fertilizes_interactor_test.rb` |
| `plan_save_ensure_user_fields_interactor` | `plan_save_ensure_user_fields_interactor_test.rb` |
| `plan_save_ensure_user_interaction_rules_interactor` | `plan_save_ensure_user_interaction_rules_interactor_test.rb` |
| `plan_save_ensure_user_pesticides_interactor` | `plan_save_ensure_user_pesticides_interactor_test.rb` |
| `plan_save_ensure_user_pests_interactor` | `plan_save_ensure_user_pests_interactor_test.rb` |
| `plan_save_persist_orchestrator` | `plan_save_persist_orchestrator_test.rb` |
| `private_plan_initialize_from_selection_interactor` | `private_plan_initialize_from_selection_interactor_test.rb` |
| `public_plan_save_interactor` | `public_plan_save_interactor_test.rb` |
| `task_schedule_item_create_interactor` | `task_schedule_item_create_interactor_test.rb` |
| `task_schedule_item_schedule_deletion_undo_interactor` | `task_schedule_item_schedule_deletion_undo_interactor_test.rb` |
| `task_schedule_timeline_interactor` | `task_schedule_timeline_interactor_test.rb` |
| `entry_schedule_optimize_interactor` | `entry_schedule_optimize_interactor_test.rb` |
| `rest_plan_access` | `rest_plan_access_test.rb` |
| `task_schedule_private_plan_access` | `task_schedule_private_plan_access_test.rb` |
| `cultivation_plan_rest_interactors` | `cultivation_plan_rest_interactors_test.rb`（複数） |
| `entry_schedule/window_service` | `entry_schedule/window_service_test.rb` |
| `entry_schedule/entry_schedule_phase_timeline` | `entry_schedule/entry_schedule_phase_timeline_test.rb` |

## Interactors — **R0-pending**（domain-lib テストなし → S3 前に Ruby R0）

| Interactor |
|------------|
| `add_field_interactor` |
| `remove_field_interactor` |
| `plan_allocation_candidates_interactor` |
| `private_owned_plans_list_interactor` |
| `private_owned_plan_detail_interactor` |
| `retrieve_cultivation_plan_interactor` |
| `task_schedule_item_complete_interactor` |
| `task_schedule_item_update_interactor` |
| `entry_schedule/crop_stage_snapshot` |
| `entry_schedule/stage_role_resolver` |
| `entry_schedule/temperature_requirement_snapshot` |

## S1 実装（2026-05）

- `crates/agrr-domain/src/cultivation_plan/` — policies×5, calculators×8, `entities/`, `errors/`, `constants/`, policy 用最小 dto
- `pub mod cultivation_plan;` in `lib.rs`

## 次スライス

1. **S2**: domain-lib テスト付き mapper 7 + dto 4（`field_cultivation_create_attrs`, `public_plan_save_session_data`, `field_optimization_event_snapshot`, `task_schedule_item_complete_input`）
2. R0: `cultivation_plan_phase_policy`, `task_schedule_item_update_policy`, `cultivation_plan_optimization_progress_calculator`
3. **S3**: 上表「テストあり」interactor から依存の少ないもの（`rest_plan_access`, `plan_read` 系）順
