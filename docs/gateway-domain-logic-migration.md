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

- 読取: `RetrieveCultivationPlanInteractor` + `CultivationPlanWorkbenchSnapshotMapper`
- 認可 + count: `CropCreateInteractor` + `CropCreateLimitPolicy`
- PlanSave farm step: `PlanSaveEnsureUserFarmInteractor` + `FarmCreateLimitPolicy` + `PlanSaveFarmGateway`
- PlanSave pest step: `PlanSaveEnsureUserPestsInteractor` + `PublicPlanSaveReadGateway#list_pest_reference_rows` + `PlanSaveUserPestGateway`
- フェーズ更新: `AdvanceCultivationPlanPhaseInteractor` + `OptimizationCompletion`（Interactor 連鎖なし）

## フェーズ完了状況

| Phase | 内容 | 主な成果 |
|-------|------|----------|
| 0 | Advance から nested Interactor 除去 | `OptimizationCompletion` モジュール |
| 1 | CultivationPlan 読取 | `CultivationPlanPrivateReadGateway`（`find_plan_read_rows_by_plan_id` 等）+ Policy/Mapper |
| 2 | 計画初期化・コピー・公開保存 | `CultivationPlanInitializeInteractor`, `PlanCopyInteractor`, `PublicPlanSaveInteractor`（統合テスト: `test/integration/cultivation_plan/public_plan_save_test.rb`） |
| 3 | Crop 認可・テンプレ | Policy に gateway なし、`CropTaskTemplateGateway` |
| 4 | TaskScheduleItem | `TaskScheduleItemCreatePolicy`, `AmountUnitConversionCalculator` |
| 5 | Adjust 保存・ペイロード | `SaveAdjustedAgrrResultInteractor`, `AdjustResultSavePolicy` |
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
