# Gateway ネーミング規約違反の洗い出し

## 判定基準 (ARCHITECTURE.md より)

### ファイル命名規約
- **アダプター接尾辞**: 7つのみ許可 (`_active_record_gateway`, `_http_gateway`, `_cli_gateway`, `_daemon_gateway`, `_memory_gateway`, `_action_cable_gateway`, `_active_job_gateway`)
- **禁止接尾辞**: `_gateway_adapter`, `_active_gateway`, `_through_host_gateway`, 接尾辞なし
- **禁止中接辞**: `*_rest_*_gateway`, `*_html_*_gateway`, `*_json_*_gateway` (プレゼンテーションチャネル名)
- GCS/S3 は `_http_gateway`

### メソッド命名規約 (5つの動詞)
- `find_by_*(criteria)` → Entity | nil
- `list_by_*(criteria)` → Array<Entity>
- `create(...)` → 永続化済みEntity
- `update(...)` → 永続化済みEntity
- `delete(id)` → 結果
- **許可例外**: `get_<state>` (スカラーのみ), `fetch_*` (外部I/Oのみ), `upsert_*`, `soft_delete_with_undo`
- **禁止**: `get_<entity>`, `load_<entity>`, `find_<entity>_by_*`, `list_<entity>_by_*`, `query_*`, `by_*`, `save`, `destroy`

### ゲートウェイ境界
- ゲートウェイは狭い永続化/HTTP/プロセスI/Oのみ
- 認可・バリデーション・マルチエンティティオーケストレーションは禁止
- プレゼンター形状の複合DTOのアセンブリは禁止

---

## A. ファイル命名違反（未解消 2件 + 部分 1件、解消済み 7件）

### ~~A-1. `entry_schedule_cursor_decode_gateway.rb`~~（解消済み）
| 項目 | 値 |
|---|---|
| 旧クラス | `EntryScheduleCursorDecodeGateway`（ゲートウェイ不適格） |
| 解消 | `app/adapters/public_plan/entry_schedule_cursor_decoder.rb` / `EntryScheduleCursorDecoder`（I/O なしのデコーダ） |

### ~~A-2. `shell_stdout_capture_gateway.rb`~~（解消済み）
| 項目 | 値 |
|---|---|
| 旧クラス | `ShellStdoutCaptureGateway` |
| 解消 | `app/adapters/backdoor/gateways/shell_stdout_capture_cli_gateway.rb` / `ShellStdoutCaptureCliGateway` |

### ~~A-3. `field_cultivation_climate_gateway.rb`~~（解消済み）

| 項目 | 値 |
|---|---|
| 旧クラス | `FieldCultivationClimateGateway`（単一巨大 gateway） |
| 解消 | `FieldCultivationClimateSourceActiveRecordGateway` / `FieldCultivationClimateProgress*Gateway` + `FieldCultivationClimateDataInteractor`。委譲のみの `FieldCultivationClimateActiveRecordGateway` は削除（2026-05-28） |
| 残（§P4） | なし（field_cultivation: sync read / climate_progress、2026-05-29）。climate source read は移行済み（`plan_access` / `climate_source` / `api_summary`） |

### ~~A-4. `agrr_prediction_gateway_adapter.rb`~~（解消済み）
| 項目 | 値 |
|---|---|
| 旧クラス | `AgrrPredictionGatewayAdapter`（禁止接尾辞 `_gateway_adapter`） |
| 解消 | ラッパー削除。呼び出し側は `PredictionDaemonGateway` を直接参照 |

### ~~A-5. `masters_api_session_resolve_*`~~（解消済み）
| 項目 | 値 |
|---|---|
| 旧クラス | `MastersApiSessionResolveActiveRecordGateway`（削除） |
| 解消 | `Domain::Shared::Interactors::MastersApiCredentialsResolveInteractor` + `ApiKeyPrincipalActiveRecordGateway` + `SessionCookiePrincipalActiveRecordGateway`。`Api::V1::Masters::BaseController` は配線のみ |

### ~~A-6. `sql_like_active_record_gateway.rb`~~（解消済み）
| 項目 | 値 |
|---|---|
| 旧クラス | `SqlLikeActiveRecordGateway`（ゲートウェイ誤配置） |
| 解消 | `app/adapters/shared/ports/sql_like_active_record_adapter.rb` / `SqlLikeActiveRecordAdapter`（`SqlLikeSanitizePort` 実装） |

### ~~A-7. `plan_copy_gateway.rb`~~（命名解消済み・境界は残）
| 項目 | 値 |
|---|---|
| 旧クラス | `PlanCopyGateway` |
| 解消（命名） | `plan_copy_active_record_gateway.rb` / `PlanCopyActiveRecordGateway` + `PlanCopyInteractor` |
| 残 | マルチエンティティ永続化の境界整理は [gateway-domain-logic-migration.md](./gateway-domain-logic-migration.md) §P3 等 |

### ~~A-8. `crop_task_schedule_blueprint_gateway.rb`~~（命名解消済み・境界は残）
| 項目 | 値 |
|---|---|
| 旧クラス | `CropTaskScheduleBlueprintGateway` |
| 解消（命名） | `crop_task_schedule_blueprint_active_record_gateway.rb` / `CropTaskScheduleBlueprintActiveRecordGateway` + `CropTaskScheduleBlueprintCopyInteractor` |
| 残 | 同上（オーケストレーションの domain 寄せは別タスク） |

### ~~A-9, A-10. `plan_data_available_crop_rows_*`~~（命名解消済み・DTO は残課題）
| 項目 | 値 |
|---|---|
| 旧クラス | `PlanDataAvailableCropRowsPrivateActiveRecordGateway` / `PlanDataAvailableCropRowsPublicActiveRecordGateway` |
| 解消（命名） | `crop_rows_available_private_active_record_gateway.rb` / `CropRowsAvailablePrivateActiveRecordGateway`<br>`crop_rows_available_public_active_record_gateway.rb` / `CropRowsAvailablePublicActiveRecordGateway` + `CropRowsAvailableRow` DTO |
| 残 | 返却型の Hash 排除などは境界・DTO 整備タスクで継続 |

---

## B. メソッド命名違反 (32件)

### B-1. `find_<entity>_by_*` 違反 (メソッド名にエンティティ名を含む)

| # | ファイル | 違反メソッド | 修正後 |
|---|---|---|---|
| B-1.1 | `lib/domain/pest/gateways/pest_gateway.rb` | `find_user_owned_non_reference_pest_by_name` | `find_by_name` |
| B-1.2 | `lib/domain/fertilize/gateways/fertilize_gateway.rb` | `find_user_owned_non_reference_fertilize_record_by_name` | `find_by_name` |
| B-1.3 | `lib/domain/field_cultivation/gateways/field_cultivation_gateway.rb` | `find_climate_data_by_field_cultivation` | （廃止）`FieldCultivationClimateDataInteractor` + climate source gateway |
| B-1.4 | `lib/domain/field_cultivation/gateways/field_cultivation_gateway.rb` | `find_api_summary_by_field_cultivation_id` | （廃止）一括 preload bundle → `find_api_summary_by_field_cultivation_id`（snapshot） |
| B-1.5 | `lib/domain/crop/gateways/crop_gateway.rb` | `list_crop_stages_by_crop_id` | `list_by_crop_id` |
| B-1.6 | `lib/domain/crop/gateways/crop_gateway.rb` | `find_crop_stage_by_id` | `find_by_id` |
| B-1.7 | `lib/domain/weather_data/gateways/weather_data_gateway.rb` | `find_weather_location_by_coordinates` | `find_by_coordinates` |
| B-1.8 | `lib/domain/cultivation_plan/gateways/cultivation_plan_gateway.rb` | `find_plan_crop_id_by_crop_id!` | `find_crop_id!` |

### B-2. `destroy` → `delete` 違反

| # | ファイル | 違反メソッド | 修正後 |
|---|---|---|---|
| B-2.1 | `lib/domain/crop/gateways/crop_gateway.rb` | `destroy_temperature_requirement` | `delete_temperature_requirement` |
| B-2.2 | `lib/domain/crop/gateways/crop_gateway.rb` | `destroy_thermal_requirement` | `delete_thermal_requirement` |
| B-2.3 | `lib/domain/crop/gateways/crop_gateway.rb` | `destroy_sunshine_requirement` | `delete_sunshine_requirement` |
| B-2.4 | `lib/domain/crop/gateways/crop_gateway.rb` | `destroy_nutrient_requirement` | `delete_nutrient_requirement` |
| B-2.5 | `lib/domain/crop/gateways/crop_gateway.rb` | `destroy_masters_crop_task_template_for_api!` | `delete_masters_crop_task_template_for_api!` |
| B-2.6 | `lib/domain/farm/gateways/farm_gateway.rb` | `destroy` | `delete` |
| B-2.7 | `lib/domain/cultivation_plan/gateways/cultivation_plan_gateway.rb` | `destroy` | `delete` |

### B-3. `find_<entity>` 違反 (get_の例外条件に合致しないエンティティ取得)

| # | ファイル | 違反メソッド | 修正後 |
|---|---|---|---|
| B-3.1 | `lib/domain/crop/gateways/crop_gateway.rb` | `find_temperature_requirement` | `find_temperature_requirement_by_crop_stage_id` |
| B-3.2 | `lib/domain/crop/gateways/crop_gateway.rb` | `find_thermal_requirement` | `find_thermal_requirement_by_crop_stage_id` |
| B-3.3 | `lib/domain/crop/gateways/crop_gateway.rb` | `find_sunshine_requirement` | `find_sunshine_requirement_by_crop_stage_id` |
| B-3.4 | `lib/domain/crop/gateways/crop_gateway.rb` | `find_nutrient_requirement` | `find_nutrient_requirement_by_crop_stage_id` |
| B-3.5 | `lib/domain/crop/gateways/crop_gateway.rb` | `find_model` | `find_by_id` |

### B-4. `create_<entity>` / `update_<entity>` 違反 (エンティティ名をメソッド名に含む)

| # | ファイル | 違反メソッド | 修正後 |
|---|---|---|---|
| B-4.1 | `lib/domain/crop/gateways/crop_gateway.rb` | `create_crop_stage` | `create` |
| B-4.2 | `lib/domain/crop/gateways/crop_gateway.rb` | `update_crop_stage` | `update` |
| B-4.3 | `lib/domain/crop/gateways/crop_gateway.rb` | `delete_crop_stage` | `delete` |
| B-4.4 | `lib/domain/crop/gateways/crop_gateway.rb` | `create_temperature_requirement` | `create` |
| B-4.5 | `lib/domain/crop/gateways/crop_gateway.rb` | `update_temperature_requirement` | `update` |
| B-4.6 | `lib/domain/crop/gateways/crop_gateway.rb` | `create_thermal_requirement` | `create` |
| B-4.7 | `lib/domain/crop/gateways/crop_gateway.rb` | `update_thermal_requirement` | `update` |
| B-4.8 | `lib/domain/crop/gateways/crop_gateway.rb` | `create_sunshine_requirement` | `create` |
| B-4.9 | `lib/domain/crop/gateways/crop_gateway.rb` | `update_sunshine_requirement` | `update` |
| B-4.10 | `lib/domain/crop/gateways/crop_gateway.rb` | `create_nutrient_requirement` | `create` |
| B-4.11 | `lib/domain/crop/gateways/crop_gateway.rb` | `update_nutrient_requirement` | `update` |

**注意**: B-4の違反は`CropGateway`がサブエンティティ（CropStage, TemperatureRequirement等）のCRUDを包含していること自体が**ゲートウェイ境界違反**（1つのゲートウェイが複数のドメインエンティティを扱う）。修正は別タスクでゲートウェイを分割する。

---

## C. ゲートウェイ境界違反 (6件)

**adapter 実装の残存ドメインロジック一覧（ファイルパス・優先度 P1–P5）**は [gateway-domain-logic-migration.md — adapter 残存ドメインロジック](./gateway-domain-logic-migration.md#adapter-残存ドメインロジック洗い出し) を正とする。本節は **interface / 旧構成** の境界違反メモ。

| # | ファイル | 違反内容 | 修正方針 |
|---|---|---|---|
| C-1 | `lib/domain/crop/gateways/crop_gateway.rb` | 認可チェック(`find_authorized_*`)、HTMLフォーム準備(`prepare_*_for_edit_form!`)、マルチエンティティ関連付け(`link_pest_to_crop`等)、プレゼンター形状複合(`find_*_loaded_bundle!`) | インタラクターに分割。ゲートウェイは純粋な永続化I/Oのみ |
| C-2 | `lib/domain/farm/gateways/farm_gateway.rb` | 認可チェック(`find_authorized_*`)、プレゼンター形状複合(`find_authorized_farm_loaded_bundle!`, `farm_list_rows_bundle`) | インタラクターに分割 |
| C-3 | `lib/domain/pest/gateways/pest_gateway.rb` | 認可チェック、HTMLフォーム準備、マルチエンティティ関連付け | インタラクターに分割 |
| C-4 | `lib/domain/cultivation_plan/gateways/cultivation_plan_gateway.rb` | 認可チェック、プレゼンター形状複合(`find_*_bundle!`, `*_snapshot`)、マルチエンティティ操作 | インタラクターに分割 |
| C-5 | ~~`field_cultivation_climate_gateway.rb`~~ → `field_cultivation_climate_source_active_record_gateway.rb` 等 | **解消**: climate source read + `climate_progress`（crop requirement は Interactor + builder）+ sync plan read 3 分割（2026-05-29 §P4） | — |
| ~~C-6~~ | ~~`masters_api_session_resolve_*`~~ | **解消**: `MastersApiCredentialsResolveInteractor` + 狭い principal gateway 2 本 | — |

---

## 対応優先度

| 優先度 | カテゴリ | 件数 | 内容 |
|---|---|---|---|
| **P1** | ファイル命名違反 | 部分 1 | A-1〜10 命名解消済み（A-3: ファサード・`field_cultivation_climate_gateway_for` 削除含む、2026-05-28）。C-5 climate source read は §P4 移行済み |
| **P2** | メソッド命名違反 | 32 | `find_<entity>_by_*`, `destroy`, `create_<entity>` |
| **P3** | ゲートウェイ境界違反 | 5 | 認可・フォーム準備・マルチエンティティ・プレゼンター形状複合（C-6 解消済み） |

**P1（ファイル命名）**はリネーム+参照更新で対応可能。
**P2（メソッド命名）**はインターフェース+全アダプター+全インタラクターの更新が必要。
**P3（境界違反）**はアーキテクチャ再設計が必要（別エピック）。

---

## 解消済み: `_memory_gateway` 接尾辞誤用（AR のみでインメモリではない）

`ARCHITECTURE.md` の `_memory_gateway` はインメモリ実装用。次は **ActiveRecord 実装のため `_active_record_gateway` にリネーム済み**（2026-05-24）。

| 旧 | 新 |
|---|---|
| `CropMemoryGateway` | `CropActiveRecordGateway` |
| `CropStageMemoryGateway` | `CropStageActiveRecordGateway` |
| `TemperatureRequirementMemoryGateway` | `TemperatureRequirementActiveRecordGateway` |
| `ThermalRequirementMemoryGateway` | `ThermalRequirementActiveRecordGateway` |
| `SunshineRequirementMemoryGateway` | `SunshineRequirementActiveRecordGateway` |
| `NutrientRequirementMemoryGateway` | `NutrientRequirementActiveRecordGateway` |
| `FertilizeMemoryGateway`（AI 用サブクラス） | `FertilizeAiActiveRecordGateway` |

**規約どおりの `_memory_gateway`（変更なし）**: `FieldCultivationClimateProgressMemoryGateway`（テスト環境のみ・モック progress、DB なし）。

---

## D. Models → Domain 移行: 五動詞外 Gateway メソッド（モデル委譲）

`app/models` の業務ロジックを domain（Interactor / Policy / Calculator）へ移す際、次は **廃止対象**（Interactor が `update(id, attrs)` のみ呼ぶ）。

| Gateway | メソッド | 現状 | 移行先 |
|---|---|---|---|
| `FarmGateway` | `increment_weather_data_progress` | `Farm#increment_weather_data_progress!` | `FarmWeatherProgressCalculator` + `update` |
| `FarmGateway` | `get_weather_data_progress` 等 | モデル計算 | `find_by_id` → Entity / Calculator |
| `FarmGateway` | `mark_weather_data_failed` | モデル | `MarkFarmWeatherDataFailedInteractor` + `update` |
| `CultivationPlanGateway` | `update_phase` | `public_send("phase_*!")` | `AdvanceCultivationPlanPhaseInteractor` + `update` + Events Port |
| agrr daemon gateways | 内部 `CropAgrrRequirementMapper` | adapter mapper | `CropAgrrRequirementBuilderPort`（Job/Interactor 注入） |

### モデル public メソッド分類（抜粋）

| 分類 | 例 |
|---|---|
| **Policy** | `user_must_be_nil_for_reference`, `name_uniqueness_scope`, `reference_farm_must_belong_to_anonymous_user` |
| **Calculator** | `weather_data_progress`, `calculate_planning_dates`, `optimization_progress` |
| **Interactor / domain module** | `start_weather_data_fetch!`, `phase_*!`（完了判定は `CultivationPlan::OptimizationCompletion`） |
| **Infrastructure Port** | `broadcast_*`, `to_agrr_format`（wire format は Builder Port + adapter mapper） |
| **AR 安全網** | `validates` / `presence` / DB 整合 |
