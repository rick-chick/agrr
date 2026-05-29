# Gateway ドメインロジック移行（境界）

命名違反の一覧は [gateway-naming-violations.md](./gateway-naming-violations.md)。**禁止の正解像は [ARCHITECTURE.md](../ARCHITECTURE.md) のみ**（Gateway boundary、五動詞、[Disallowed gateway public method name patterns](../ARCHITECTURE.md#disallowed-gateway-public-method-name-patterns)、R0 / R3 / R10）。本書は移行記録と PR 用チェックリスト（規約の二重定義はしない）。

## 正規フロー（コピー元）

1. Output port / 出力 DTO 契約
2. Interactor + `lib/domain` テスト（gateway は mock）
3. Gateway adapter（五動詞 I/O のみ）
4. Presenter / adapter mapper
5. Controller / Job（`CompositionRoot` 配線）
6. 旧 gateway メソッド削除（同一 PR または直後コミット）

参照実装:

- 読取: `RetrieveCultivationPlanInteractor`（`CultivationPlanGateway#find_by_id` → `RestPlanAccess` → `load_snapshot_by_plan_id`）+ `CultivationPlanRestPlanPreload#find_by_plan_id`
- REST 変更系: `AddFieldInteractor` 等 + `find_by_id` + `RestPlanAccess`（旧 `PlanScopes` / `find_by_id_for_rest` は廃止）
- REST add_crop / adjust: Input port nesting — [ARCHITECTURE.md — Composite use cases and Input port injection](../ARCHITECTURE.md#composite-use-cases-and-input-port-injection)（`AddCropCropResolveInputPort` + `PlanAllocationAdjustInputPort` + `build_*` at edge）
- adjust 後の field_cultivation 同期: `FieldCultivationSyncInteractor` + `FieldCultivationSyncPlanSnapshot` / `FieldCultivationSyncTargetSnapshot` + `FieldCultivationSyncApply`（未参照 plan crop 削除 ID は `FieldCultivationSyncUnreferencedPlanCropIds` → `sync_apply.cultivation_plan_crop_ids_to_delete`）；agrr JSON → `AgrrAdjustResultFieldCultivationSyncMapper`（adapter）；`FieldCultivationSyncGateway#sync_by_plan_id`
- 認可 + count: `CropCreateInteractor` + `CropCreateLimitPolicy`
- PlanSave farm step: `PlanSaveEnsureUserFarmInteractor` + `FarmCreateLimitPolicy` + `PlanSaveFarmGateway`（戻り値 `PlanSaveReferenceFarmSnapshot` / `PlanSaveUserFarmSnapshot`）
- PlanSave field step: `PlanSaveEnsureUserFieldsInteractor` + `PlanSaveFieldGateway`（戻り値 `PlanSaveFieldSnapshot`；template-copy は `PlanSaveTemplateCopyIntegrity#field_records_for_template_copy`）
- PlanSave crop/pest step: `PlanSaveEnsureUserCropsInteractor` / `PlanSaveEnsureUserPestsInteractor` + Read 行 DTO + User gateway（戻り値 `PlanSaveUserCropSnapshot` / `PlanSaveUserPestSnapshot`）；template-copy は `PlanSaveTemplateCopyIntegrity#crop_records_for_template_copy` / `#pest_records_for_template_copy`
- PlanSave fertilize step: `PlanSaveEnsureUserFertilizesInteractor` + `PublicPlanSaveReadGateway#list_fertilize_reference_rows` / `#exists_fertilize_name?` + `PlanSaveUserFertilizeGateway`（戻り値 `PlanSaveUserFertilizeSnapshot`；`list_by_ids` なし）
- PlanSave pesticide step: `PlanSaveEnsureUserPesticidesInteractor` + `PublicPlanSaveReadGateway#list_pesticide_reference_rows` + `PlanSaveUserPesticideGateway#create`（optional 子 kwargs；`PlanSaveUserPesticideSnapshot`）；template-copy は `PlanSaveTemplateCopyIntegrity#pesticide_records_for_template_copy`
- PlanSave agricultural_task step: `PlanSaveEnsureUserAgriculturalTasksInteractor` + `PublicPlanSaveReadGateway#list_agricultural_task_reference_rows` + `PlanSaveUserAgriculturalTaskGateway`（find/create + crop_task_template find/create；`PlanSaveUserAgriculturalTaskSnapshot`）；template-copy は `PlanSaveTemplateCopyIntegrity#agricultural_task_records_for_template_copy`（`user_id` スコープ）
- PlanSave interaction_rule step: `PlanSaveEnsureUserInteractionRulesInteractor` + `PublicPlanSaveReadGateway#list_interaction_rule_reference_rows` + `PlanSaveUserInteractionRuleGateway`（`find_by_*` / `create` / `update`；`PlanSaveUserInteractionRuleSnapshot`）；template-copy は `PlanSaveTemplateCopyIntegrity#interaction_rule_records_for_template_copy`（`user_id` スコープ）
- フェーズ更新: `AdvanceCultivationPlanPhaseInteractor` + `OptimizationCompletion`（Interactor 連鎖なし）

## フェーズ完了状況

| Phase | 内容 | 主な成果 |
|-------|------|----------|
| 0 | Advance から nested Interactor 除去 | `OptimizationCompletion` モジュール |
| 1 | CultivationPlan 読取 | `CultivationPlanPrivateReadGateway`（`find_plan_read_snapshot_by_plan_id` / `find_optimization_snapshot_by_plan_id`）+ Policy/Mapper |
| 2 | 計画初期化・コピー・公開保存 | `CultivationPlanInitializeInteractor`, `PlanCopyInteractor`, `PublicPlanSaveInteractor`（統合テスト: `test/integration/cultivation_plan/public_plan_save_test.rb`） |
| 3 | Crop 認可・テンプレ | Policy に gateway なし、`CropTaskTemplateGateway` |
| 4 | TaskScheduleItem | `TaskScheduleItemCreatePolicy`, `AmountUnitConversionCalculator` |
| 5 | Adjust 同期・ペイロード | **同期（移行済み）**: `FieldCultivationSyncInteractor` + `FieldCultivationSyncGateway`；agrr JSON → `AgrrAdjustResultFieldCultivationSyncMapper`（許容）。**read/adjust**: `PlanAllocationAdjustReadSnapshot` + `PlanAllocationAdjustReadSnapshotParts`（`*Snapshot` DTO、Row/Entity なし）。adapter mapper は AR 生値・weather のみ |
| 6 | Pest 関連・ステージ複製 | `CropPestGateway`, `CropStageCopyInteractor` |
| 7 | agrr wire / EntrySchedule | `InteractionRuleAgrrFormatBuilderPort`, `EntryScheduleOptimizeInteractor` |

## PR チェックリスト（再混入防止）

各 PR で ARCHITECTURE ゲートと併用すること。

| チェック | 参照 |
|----------|------|
| Gateway 新規 public メソッド | [ARCHITECTURE.md — Gateway method naming / Disallowed patterns](../ARCHITECTURE.md#disallowed-gateway-public-method-name-patterns) |
| Interactor | 別 Interactor の `call`；`CompositionRoot.*`；Policy への gateway 渡し |
| Policy | gateway / ActiveRecord / `find` / `count` |
| Presenter | gateway / `find_model` / 副作用 |
| 削除 | 旧メソッドを残したまま新 Interactor のみ追加（R8） |
| テスト | Interactor テストが output port へ届く型・必須フィールドを固定（R10） |

## 反パターン（追加禁止）

- `AdvanceCultivationPlanPhaseInteractor` が別 Interactor を注入して `call` する形の復活
- `CropMastersCropEditAccess` のように Policy が gateway を受け取る形
- `CultivationPlanActiveRecordGateway` に `find_private_*` / `initialize_*` のようなユースケース束ねメソッドを再追加

## 機械チェック

[`test/architecture/gateway_public_method_naming_test.rb`](../test/architecture/gateway_public_method_naming_test.rb) が ARCHITECTURE.md の Disallowed patterns と同一の正規表現を適用する。

**命名**は上記テストと [gateway-naming-violations.md](./gateway-naming-violations.md)。**メソッド本体のドメイン判断**（認可スコープ・検証・多段永続化など）は本節「adapter 残存ドメインロジック」を正とする。

---

## adapter 残存ドメインロジック（洗い出し）

**最終更新**: 2026-05-28。**対象**: `app/adapters`（`gateways` / `mappers` / `ports` / `sessions` / トップレベル `.rb`）。**基準**: [ARCHITECTURE.md — Gateway Boundary](../ARCHITECTURE.md#gateway-boundary)（R0 / R3）。禁止条項の二重定義はしない。

### 判定ラベル

| ラベル | 意味 |
|--------|------|
| **移行候補** | Policy / Interactor / `lib/domain/.../mappers` へ寄せる |
| **エッジ配線** | HTTP・Job 境界の `build_*` / Input port 注入に集約（adapter 内 `CompositionRoot`・Interactor 直 `call` は整理対象） |
| **許容** | ワイヤ正規化・AR→DTO 写像・インフラのみ（新規の業務判断を足さない） |

### 系統一覧（優先度）

| 優先 | 系統 | 移行の型 | 代表パス |
|------|------|----------|----------|
| **P1** | 認可・可視性のスコープ埋め込み | Interactor + Policy（`RestPlanAccess` / `PlanReadAuthorization` 等）→ Gateway は identity 済みの narrow `find` | 下表 §P1 |
| **P2** | agrr / 保存前の業務検証 | Policy または domain mapper（adapter は wire のみ） | 下表 §P2 |
| **P3** | ユースケース束ね（多段永続化） | 専用 Interactor + 狭い Gateway 五動詞 | 下表 §P3 |
| **P4** | 厚い read snapshot 組立 | `lib/domain/<context>/mappers` + Gateway は preload + `find` | 下表 §P4 |
| **P5** | adapter からの Interactor / `CompositionRoot` 起動 | Controller / Job / `CompositionRoot.build_*` のみ | 下表 §P5 |

```mermaid
flowchart LR
  P1[P1 認可スコープ] --> P2[P2 agrr 前検証]
  P2 --> P3[P3 PlanCopy PlanSave]
  P3 --> P4[P4 read snapshot]
  P4 --> P5[P5 edge 配線集約]
```

### §P1 — 認可・可視性（移行候補）

（2026-05 時点で下表「マスタ横断 §P1」および `resolve_crop_id_by_name` まで完了。残りは `public_plan_active_record_gateway` の farm/crop find 等 — 別エピック）

### §P1 — 移行済み（REST 計画 read / mutation）

| ファイル | 認可の所在 | Gateway |
|----------|------------|---------|
| `cultivation_plan/persistence/cultivation_plan_rest_plan_preload.rb` | `RetrieveCultivationPlanInteractor`（`plan_gateway` + `RestPlanAccess` を read 前） | `find_by_plan_id`（preload のみ） |
| `cultivation_plan/gateways/cultivation_plan_workbench_read_active_record_gateway.rb` | 同上 | `load_snapshot_by_plan_id` |
| `cultivation_plan/gateways/plan_allocation_adjust_read_active_record_gateway.rb` | `PlanAllocationAdjustInteractor` + `RestPlanAccess`（REST adjust） | `find_adjust_read_snapshot_by_plan_id` |
| `cultivation_plan/gateways/task_schedule_item_mutation_active_record_gateway.rb` | `TaskScheduleItem*Interactor` + `TaskSchedulePrivatePlanAccess` | `plan_id` narrow find / join |
| `cultivation_plan/gateways/cultivation_plan_private_read_active_record_gateway.rb`（timeline read） | `TaskScheduleTimelineInteractor` + `TaskSchedulePrivatePlanAccess`（read 前） | `find_task_schedule_timeline_by_plan_id` |

### §P1 — 移行済み（マスタ横断・私有計画初期化）

| ファイル | 認可の所在 | Gateway（narrow I/O のみ） |
|----------|------------|---------------------------|
| `pesticide/gateways/pesticide_active_record_gateway.rb` | `PesticideListInteractor` + `PesticidePolicy.index_list_filter`；`MastersCropPesticidesIndexInteractor` + `PesticidePolicy.masters_crop_pesticides_index_filter` | `list_index_for_filter` / `list_by_crop_id_for_filter`（`ReferenceIndexListFilterRelation` で VO 写像） |
| `cultivation_plan/interactors/private_plan_initialize_from_selection_interactor.rb` | `FarmPolicy.owned_visible?` + `CropPolicy.edit_allowed?`（全 ID 一致） | `FarmGateway#find_by_id`、`CropGateway#list_by_ids`、`FieldGateway#get_total_area_by_farm_id`（`CultivationPlanGateway` から farm/crop 横断 find 削除） |
| `crop/gateways/crop_active_record_gateway.rb` | `CropReferenceRecordPolicy` / `CropPolicy` / `CropMastersNestedAccess` / `CropResolveByNamePolicy` | `find_by_id`、`list_by_name`、`list_by_is_reference`、`list_by_user_id`、`find_crop_record_with_stages!`、`each_crop_record_with_stages_by_region` |
| `crop/interactors` + `pest/interactors` | `MastersCropPesticidesIndexInteractor` + `CropMastersNestedAccess`；`PestAssociateAffectedCropsInteractor` + `CropResolveByNamePolicy` | 旧 `resolve_crop_id_by_name`（Gateway 内 reference/owned スコープ）廃止 |

### §P2 — 業務検証・整合性（移行候補）

| ファイル | 内容 | 備考 |
|----------|------|------|
| `crop/mappers/crop_agrr_requirement_mapper.rb` | 生育ステージ・温度/積算の欠落で `ArgumentError` | `CropAgrrRequirementBuilderPort` 実装の本体。Phase 5 後も adapter に残存 |
| `cultivation_plan/gateways/cultivation_plan_active_record_gateway.rb` | `find_crop_id!` → `CultivationPlanCropMissingError` | 整合性メッセージ付き raise |
| `crop/crop_ai_upsert_active_record_persistence.rb` | `validate_stage_requirements!`、ステージ永続化オーケストレーション | AI 経路の永続化ブロック |
| `cultivation_plan/sessions/plan_save_template_copy_integrity.rb` | template-copy 用 ID の存在・user スコープ | domain 例外型へ（`PlanSaveTemplateCopyIntegrity` は domain モジュール名と揃える） |
| `contact_messages/services/contact_message_rate_limiter.rb` | IP 単位レート制限 | domain Policy + インフラ Port が理想 |
| `deletion_undo/manager.rb` | 期限・復元トランザクション・ドメイン例外 | Undo ユースケース Interactor へ（`CompositionRoot` デフォルト解決あり） |

### §P3 — ユースケース束ね（移行候補）

| ファイル | 内容 |
|----------|------|
| `cultivation_plan/gateways/plan_copy_active_record_gateway.rb` | `copy_plan_relations`, `copy_task_schedules`, `establish_master_data_relationships` 等 |
| `cultivation_plan/gateways/public_plan_template_copy_active_record_gateway.rb` | 公開 template copy の同種ステップ |
| `cultivation_plan/sessions/plan_save_session.rb` | 複数 `PlanSaveEnsureUser*` の連鎖・blueprint/stage copy | `PublicPlanSaveInteractor` と責務重複に注意 |

[gateway-naming-violations.md §C](./gateway-naming-violations.md#c-ゲートウェイ境界違反-6件) の **P3（境界）** と同エピック。

### §P4 — 厚い read snapshot 組立（移行候補）

| ファイル | 内容 |
|----------|------|
| `cultivation_plan/mappers/plan_allocation_adjust_read_snapshot_mapper.rb` | AR 走査・weather 写像・`PlanAllocationAdjustReadSnapshot` 組立（業務算出は `PlanAllocationAdjustReadSnapshotParts` / `*Snapshot` DTO に移行済み） |
| `field_cultivation/gateways/field_cultivation_climate_source_active_record_gateway.rb` | 残: preload なし `find`、認可 read と climate read の二重取得。plan access / climate source の Snapshot 組立は adapter `field_cultivation/mappers/field_cultivation_climate_source_snapshot_mapper.rb`（AR wire のみ）。**部分移行済み**: `find_api_summary` は `field_cultivation_api_summary_wire_mapper.rb` + `field_cultivation_api_summary_mapper.rb`；`update_field_cultivation_schedule` は `field_cultivation_api_update_output_wire_mapper.rb` + `field_cultivation_api_update_output_mapper.rb` |
| `cultivation_plan/gateways/cultivation_plan_private_read_active_record_gateway.rb` | `find_task_schedule_timeline_by_plan_id` の `build_task_schedule_*`、`list_private_plan_index_rows_by_user_id` の集計・並べ |
| `cultivation_plan/gateways/cultivation_plan_workbench_read_active_record_gateway.rb` | workbench snapshot 組立 |
| `cultivation_plan/mappers/task_schedule_generation_context_mapper.rb` | タスクスケジュール生成 context（agrr requirement 込み） |
| `cultivation_plan/gateways/public_plan_save_read_active_record_gateway.rb` | 参照マスタ行の業務フィルタ（例: `rule_type: "continuous_cultivation"`） |
| `crop/gateways/crop_active_record_gateway.rb` 等 | `find_*_show_detail`（`find_delete_usage` は crop/farm/pest で部分移行済み — 下記） |
| `farm` / `pest` / `agricultural_task` / `pesticide` gateways | 同上パターンの複合 read（`find_delete_usage` は master crop/farm/pest のみ部分移行済み） |

**部分移行済み（`find_delete_usage`）**: `crop_active_record_gateway` / `farm_active_record_gateway` / `pest_active_record_gateway` — adapter `*_delete_usage_wire_mapper.rb`（AR 件数）+ domain `*_delete_usage_mapper.rb`。`find_*_show_detail` は未移行。

**部分移行済み**: `TaskScheduleTimelineInteractor` + `lib/domain/cultivation_plan/mappers/task_schedule_timeline_mapper.rb` は read_model → 表示 DTO のみ。スナップショット構築は依然 `CultivationPlanPrivateReadActiveRecordGateway`。

### §P5 — adapter 内 Interactor / CompositionRoot（エッジ配線 → 整理）

| ファイル | 内容 |
|----------|------|
| `cultivation_plan/gateways/adjust_weather_prediction_active_record_gateway.rb` | `weather_prediction_interactor_factory.build` |
| `weather_data/weather_prediction_interactor_factory.rb` | `WeatherPredictionInteractor` 組立 |
| `public_plan/entry_schedule_optimization_runner_adapter.rb` | `CompositionRoot.entry_schedule_optimize_interactor(...).call` |
| `deletion_undo/manager.rb` | 省略時 `CompositionRoot.deletion_undo_gateway` |
| `fertilize/fertilize_ai_gateway_resolver.rb` | ~~`CompositionRoot.logger` / `translator`~~ **移行済み**: `CompositionRoot#fertilize_ai_query_gateway` が constructor 注入 |
| `cultivation_plan/ports/add_crop_crop_resolve_{private,public}.rb` | Crop find Interactor を port 実装から `call` |
| `crop|pest|fertilize/*_for_ai_adapter.rb` | AI 経路で Interactor 直起動 |
| `crop/crop_ai_upsert_active_record_persistence.rb` | create interactor 呼び出し含む |

**望ましい形**: [Composite use cases and Input port injection](../ARCHITECTURE.md#composite-use-cases-and-input-port-injection) — Controller / Job が `build_*_interactor` し、オーケストレータは Input port のみ `call`。

### 許容（新規業務判断を増やさない）

| ファイル | 理由 |
|----------|------|
| `cultivation_plan/adjust_moves_from_request.rb` | `params[:moves]` の HTTP 正規化 |
| `cultivation_plan/mappers/agrr_adjust_result_field_cultivation_sync_mapper.rb` | agrr JSON キー → `FieldCultivationSyncInput`（Phase 5 参照実装） |
| `public_plan/entry_schedule_cursor_decoder.rb` | cursor の Base64/JSON デコード |
| 各 `*_api_presenter.rb`（多く） | output port DTO → JSON |
| `shared/ports/*`, `shared/iso8601_*` | インフラ |
| agrr `*_daemon_gateway.rb` | 外部プロセス I/O |

### Presenter の注意（表示層）

| ファイル | 内容 |
|----------|------|
| `cultivation_plan/presenters/task_schedule_timeline_html_presenter.rb` | 週次バケット・肥料/一般の分類・ソート（domain timeline mapper と役割が重なる） |

### §Phase 5 — 移行済み（adjust 後 field_cultivation 同期）

| ファイル | ドメインの所在 | Gateway / adapter |
|----------|----------------|-------------------|
| `field_cultivation/gateways/field_cultivation_sync_active_record_gateway.rb` | `FieldCultivationSyncInteractor`, `FieldCultivationSyncApplyMapper`, `FieldCultivationSyncPlanCropResolver`, `FieldCultivationSyncUnreferencedPlanCropIds`, `FieldCultivationSyncPolicy` | `find_sync_plan_snapshot_by_plan_id`, `sync_by_plan_id`（preload + 永続化のみ） |
| `cultivation_plan/mappers/agrr_adjust_result_field_cultivation_sync_mapper.rb` | —（wire のみ） | agrr JSON → `FieldCultivationSyncInput`（上記 [許容](#許容新規業務判断を増やさない) 表） |
| （廃止）`SaveAdjustedAgrrResult*` 系 | `PlanAllocationAdjustInteractor` 配下の `field_cultivation_sync` Input port 注入 | コードベースから削除済み |

配線: `CompositionRoot#field_cultivation_sync_gateway` → `build_field_cultivation_sync_interactor`；`build_plan_allocation_adjust_interactor` が adjust 成功後に `FieldCultivationSyncInputPort#call`（`AgrrAdjustResultFieldCultivationSyncMapper.to_sync_input`）。

### Phase 5 との差分（進行中リファクタ）

**残**: adjust read の adapter 厚みは §P4（AR 走査・weather 写像）に近い。§P2 の業務算出は `PlanAllocationAdjustReadSnapshotParts` へ移行済み（2026-05-28）。

| 項目 | domain | adapter に残るもの |
|------|--------|-------------------|
| adjust read | `PlanAllocationAdjustReadSnapshot`, `PlanAllocationAdjustAgrrPayloadMapper`, `PlanAllocationAdjustReadSnapshotParts` | `PlanAllocationAdjustReadSnapshotMapper` の AR 走査・weather 写像・DTO 組立（`agrr_requirement` は Parts + edge 注入 builder） |
| climate source read | `FieldCultivationClimateSourceSnapshot`, `FieldCultivationPlanAccessSnapshot`, `FieldCultivationClimateContextSnapshotMapper`, `FieldCultivationApiSummaryMapper`, `FieldCultivationApiUpdateOutputMapper` 他 | `FieldCultivationClimateSourceActiveRecordGateway` の AR find；climate snapshot wire は `FieldCultivationClimateSourceSnapshotMapper`、`find_api_summary` wire は `FieldCultivationApiSummaryWireMapper`、`update_field_cultivation_schedule` wire は `FieldCultivationApiUpdateOutputWireMapper` |

### PR 時の追記ルール

移行 PR をマージしたら、本節の該当行を **削除または「移行済み」へ移動** し、上表「Phase 5 との差分」を更新する。新規 Gateway public メソッド追加時は [PR チェックリスト](#pr-チェックリスト再混入防止) と併用。
