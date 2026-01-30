# フロントエンド再構築 TODO（スキル準拠）

Clean Architecture（usecase / gateway / controller / presenter）に従い、Service 直接利用をやめて全画面を再構築するためのタスク一覧。

**参照スキル:** usecase-frontend, gateway-frontend, controller-frontend, presenter-frontend

**除外:** 静的ページ（about, contact, privacy, terms）、OAuth リンクのみの login、表示専用コンポーネント（gantt-chart, farm-map, temperature-chart 等）、共有 UI の状態表示のみ（navbar, footer, flash-message, undo-toast）

---

## 凡例（1 画面あたりの作業）

各画面で以下を実施する:

1. **usecase/<feature>**: Input Port, Output Port, Gateway(interface), DTOs, UseCase
2. **adapters/<feature>**: Gateway 実装（*-api.gateway.ts）, Presenter（*.presenter.ts）
3. **components/<feature>**: View（*.view.ts）, Component（View 実装 + アクション + control のみ）

---

## plans（plan-detail は済）

| # | 画面 | 現状 | タスク |
|---|------|------|--------|
| P1 | plan-list | PlanService.listPlans | usecase: LoadPlanList (Input/Output Port, PlanGateway 拡張, DTOs, UseCase). adapters: PlanApiGateway に list 追加, PlanListPresenter. components: plan-list.view.ts, plan-list.component を View+アクションに |
| P2 | plan-task-schedule | PlanService.getTaskSchedule | usecase: LoadPlanTaskSchedule (Port, Gateway 拡張, DTOs, UseCase). adapters: PlanApiGateway 拡張, PlanTaskSchedulePresenter. components: plan-task-schedule.view.ts, component を View+アクションに |
| P3 | plan-optimizing | OptimizationService (ActionCable) | usecase: SubscribePlanOptimization (Port, Gateway で Channel 契約, DTOs, UseCase). adapters: OptimizationGateway 実装, Presenter. components: plan-optimizing.view.ts, component を View+アクションに |

---

## masters/farms

| # | 画面 | 現状 | タスク |
|---|------|------|--------|
| F1 | farm-list | FarmService.list, destroy + AuthService.ensureApiKey | usecase: LoadFarmList, DeleteFarm (別 UseCase 可). FarmGateway, DTOs. adapters: FarmApiGateway, FarmListPresenter. components: farm-list.view.ts, farm-list.component |
| F2 | farm-detail | FarmService.show, destroy, FieldService.listByFarm, OptimizationService | usecase: LoadFarmDetail (farm+fields), DeleteFarm. FarmGateway, FieldGateway または FarmGateway に統合. adapters: FarmApiGateway, FarmDetailPresenter. components: farm-detail.view.ts, farm-detail.component |
| F3 | farm-create | FarmService.create | usecase: CreateFarm (Input DTO: payload). FarmGateway.create. adapters: FarmApiGateway 拡張, FarmCreatePresenter. components: farm-create.view.ts, farm-create.component |
| F4 | farm-edit | FarmService.show, update | usecase: LoadFarmDetail(1件), UpdateFarm. adapters: 同上. components: farm-edit.view.ts, farm-edit.component |

---

## masters/crops

| # | 画面 | 現状 | タスク |
|---|------|------|--------|
| C1 | crop-list | CropService | usecase: LoadCropList. CropGateway. adapters: CropApiGateway, CropListPresenter. components: crop-list.view.ts, crop-list.component |
| C2 | crop-detail | CropService.show | usecase: LoadCropDetail. CropGateway. adapters: CropApiGateway, CropDetailPresenter. components: crop-detail.view.ts, crop-detail.component |

---

## masters/fertilizes

| # | 画面 | 現状 | タスク |
|---|------|------|--------|
| Z1 | fertilize-list | FertilizeService | usecase: LoadFertilizeList. FertilizeGateway. adapters: FertilizeApiGateway, FertilizeListPresenter. components: fertilize-list.view.ts, fertilize-list.component |
| Z2 | fertilize-create | FertilizeService.create | usecase: CreateFertilize. FertilizeGateway.create. adapters: FertilizeApiGateway, FertilizeCreatePresenter. components: fertilize-create.view.ts, fertilize-create.component |
| Z3 | fertilize-edit | FertilizeService.show, update | usecase: LoadFertilizeDetail, UpdateFertilize. adapters: 同上. components: fertilize-edit.view.ts, fertilize-edit.component |

---

## masters/pests

| # | 画面 | 現状 | タスク |
|---|------|------|--------|
| E1 | pest-list | PestService | usecase: LoadPestList. PestGateway. adapters: PestApiGateway, PestListPresenter. components: pest-list.view.ts, pest-list.component |

---

## masters/pesticides

| # | 画面 | 現状 | タスク |
|---|------|------|--------|
| I1 | pesticide-list | PesticideService | usecase: LoadPesticideList. PesticideGateway. adapters: PesticideApiGateway, PesticideListPresenter. components: pesticide-list.view.ts, pesticide-list.component |

---

## masters/agricultural-tasks

| # | 画面 | 現状 | タスク |
|---|------|------|--------|
| A1 | agricultural-task-list | AgriculturalTaskService | usecase: LoadAgriculturalTaskList. AgriculturalTaskGateway. adapters: AgriculturalTaskApiGateway, AgriculturalTaskListPresenter. components: agricultural-task-list.view.ts, agricultural-task-list.component |

---

## masters/interaction-rules

| # | 画面 | 現状 | タスク |
|---|------|------|--------|
| R1 | interaction-rule-list | InteractionRuleService | usecase: LoadInteractionRuleList. InteractionRuleGateway. adapters: InteractionRuleApiGateway, InteractionRuleListPresenter. components: interaction-rule-list.view.ts, interaction-rule-list.component |

---

## public-plans

| # | 画面 | 現状 | タスク |
|---|------|------|--------|
| U1 | public-plan-create | PublicPlanService.getFarms, getFarmSizes | usecase: LoadPublicPlanFarms, LoadFarmSizes. PublicPlanGateway. adapters: PublicPlanApiGateway, Presenter. components: public-plan-create.view.ts, component |
| U2 | public-plan-select-crop | PublicPlanService.getCrops | usecase: LoadPublicPlanCrops. PublicPlanGateway 拡張. adapters: Presenter. components: public-plan-select-crop.view.ts, component |
| U3 | public-plan-optimizing | OptimizationService (ActionCable) | usecase: SubscribePublicPlanOptimization. adapters: OptimizationGateway, Presenter. components: public-plan-optimizing.view.ts, component |
| U4 | public-plan-results | PlanService.getPublicPlanData, AuthService | usecase: LoadPublicPlanResults. Gateway 拡張. adapters: Presenter. components: public-plan-results.view.ts, component |

---

## settings/api-key

| # | 画面 | 現状 | タスク |
|---|------|------|--------|
| K1 | api-key | ApiKeyService, AuthService | usecase: LoadApiKeys / EnsureApiKey 等. ApiKeyGateway. adapters: ApiKeyApiGateway, ApiKeyPresenter. components: api-key.view.ts, api-key.component |

---

## スキル適用しない（現状維持）

- **auth/login**: OAuth リンクのみ（API 駆動なし）
- **home**: AuthService 表示のみ（必要なら軽く UseCase 化可）
- **weather/weather-page**: 子がハードコードデータのみ
- **pages/about, contact, privacy, terms**: 静的
- **shared/navbar, footer, flash-message, undo-toast**: 表示・トースト用サービス参照のみ
- **plans/gantt-chart, task-schedule-timeline, farm-map, weather/temperature-chart**: 表示専用

---

## 実施順の提案

1. **plans** 残り（P1, P2, P3）— 既存 usecase/adapters を拡張しやすい
2. **masters/farms**（F1〜F4）— CRUD パターンのひな形になる
3. **masters** 一覧系（crops, fertilizes, pests, pesticides, agricultural-tasks, interaction-rules）
4. **masters** 詳細・作成・編集（crop-detail, fertilize-create, fertilize-edit）
5. **public-plans**（U1〜U4）
6. **settings/api-key**（K1）

---

## 集計

| カテゴリ | 画面数 |
|----------|--------|
| plans | 3 |
| farms | 4 |
| crops | 2 |
| fertilizes | 3 |
| pests | 1 |
| pesticides | 1 |
| agricultural-tasks | 1 |
| interaction-rules | 1 |
| public-plans | 4 |
| settings | 1 |
| **合計** | **21 画面** |
