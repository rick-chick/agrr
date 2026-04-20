# Cultivation plan optimization (allocate) contract

## Scope

- **Initialize**: `Domain::CultivationPlan::Interactors::CultivationPlanInitializeInteractor` — builds `CultivationPlan`, `CultivationPlanCrop`, `CultivationPlanField` from farm, total area, and crop selection (旧 `CultivationPlanCreator`)。
- **Optimize**: `Domain::CultivationPlan::Interactors::CultivationPlanOptimizeInteractor` — loads existing weather prediction, calls agrr **allocate** via `Adapters::Agrr::PlanAllocationGatewayAdapter` → `Agrr::AllocationGateway`, persists `FieldCultivation` rows and plan totals (旧 `CultivationPlanOptimizer`)。

## Ports / adapters

| Role | Implementation |
|------|----------------|
| Multi-field allocation CLI | `lib/adapters/agrr/plan_allocation_gateway_adapter.rb` wrapping `Agrr::AllocationGateway#allocate` |
| Weather (existing prediction) | `Domain::WeatherData::Interactors::WeatherPredictionInteractor#get_existing_prediction` |

## Errors

- `Domain::CultivationPlan::Interactors::CultivationPlanOptimizeInteractor::WeatherDataNotFoundError` — farm に `WeatherLocation` がない、または既存予測がない。
- `Agrr::BaseGatewayV2::NoAllocationCandidatesError` / `ExecutionError` — ジョブ層へ再送出。

## Callers

- `OptimizationJob`
- HTML/API controllers that create plans（InitializeInteractor のみ直接または Gateway 経由）

## Status

- [x] T-031: `app/services/cultivation_plan_{creator,optimizer}.rb` 削除、`lib/domain` + allocation adapter へ移行
