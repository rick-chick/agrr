# Cultivation plan optimization (allocate) contract

## Scope

- **Initialize**: `Domain::CultivationPlan::Interactors::CultivationPlanInitializeInteractor` — builds `CultivationPlan`, `CultivationPlanCrop`, `CultivationPlanField` from farm, total area, and crop selection (旧 `CultivationPlanCreator`)。
- **Optimize**: `Domain::CultivationPlan::Interactors::CultivationPlanOptimizeInteractor` — loads existing weather prediction, calls agrr **allocate** via `Adapters::Agrr::PlanAllocationGatewayAdapter` → `Agrr::AllocationGateway`, persists `FieldCultivation` rows and plan totals (旧 `CultivationPlanOptimizer`)。

## Ports / adapters

| Role | Implementation |
|------|----------------|
| Multi-field allocation CLI | `lib/adapters/agrr/plan_allocation_gateway_adapter.rb` wrapping `Agrr::AllocationGateway#allocate` |
| Weather (existing prediction) | `Domain::WeatherData::Interactors::WeatherPredictionInteractor#get_existing_prediction` |

## WeatherPredictionInteractor 依存注入（時間境界）

- `clock` と `anchors_resolver` は **CompositionRoot**（または明示的に両方を用意するテスト）からのみ渡す。**`clock`** は `#today` / `#now`。**`anchors_resolver`** は `Domain::WeatherData::Ports::WeatherPredictionAnchorsPort` に従い、呼び出しごとの `@clock.today` に対して訓練窓・当年履歴・既定予測終了を返すこと（旧 `Date.current` の都度評価と同等に揃える）。
- **`clock` が `ActiveSupport::TimeZone` でないとき**は `anchors_resolver` を省略できない（ゾーン推測で境界がズレないようにする）。
- 本番既定の境界計算実装は `Adapters::WeatherData::RailsWeatherPredictionAnchorsResolver`（Rails の `- 20.years` / `- 2.days` / `+ 6.months` と旧 `Date.current` 由来の動作を整合）。

## Errors

- `Domain::CultivationPlan::Interactors::CultivationPlanOptimizeInteractor::WeatherDataNotFoundError` — farm に `WeatherLocation` がない、または既存予測がない。
- `Agrr::BaseGatewayV2::NoAllocationCandidatesError` / `ExecutionError` — ジョブ層へ再送出。

## Callers

- `OptimizationJob`
- HTML/API controllers that create plans（InitializeInteractor のみ直接または Gateway 経由）

## Status

- [x] T-031: `app/services/cultivation_plan_{creator,optimizer}.rb` 削除、`lib/domain` + allocation adapter へ移行。**現行**: [`cultivation_plan_initialize_interactor.rb`](../../lib/domain/cultivation_plan/interactors/cultivation_plan_initialize_interactor.rb) / [`cultivation_plan_optimize_interactor.rb`](../../lib/domain/cultivation_plan/interactors/cultivation_plan_optimize_interactor.rb)（本契約 Scope と一致）。
