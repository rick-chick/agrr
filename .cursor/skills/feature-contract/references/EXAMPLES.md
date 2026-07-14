# 契約パターン参照

本プロジェクトにおける既存の契約パターン。機能追加スキルで契約を作成する際の参考にする。

## 1. Plan Gateway（Plans 機能）

フロント UseCase が複数 API を並列で呼び出す例。

- **フロント UseCase**: [frontend/src/app/usecase/plans/load-plan-detail.usecase.ts](/frontend/src/app/usecase/plans/load-plan-detail.usecase.ts) — `LoadPlanDetailUseCase` が `fetchPlan` と `fetchPlanData` を `forkJoin` で呼ぶ
- **Gateway Interface**: [frontend/src/app/usecase/plans/plan-gateway.ts](/frontend/src/app/usecase/plans/plan-gateway.ts)
- **Gateway 実装**: [frontend/src/app/adapters/plans/plan-api.gateway.ts](/frontend/src/app/adapters/plans/plan-api.gateway.ts)
- **サーバー**: Rails MVC（Plans API）。[app/controllers/api/v1/plans_controller.rb](/app/controllers/api/v1/plans_controller.rb)、[config/routes.rb](/config/routes.rb) の `plans` 関連

**マッピング**:
- `LoadPlanDetailUseCase` → `GET /api/v1/plans/:id`, `GET /api/v1/plans/cultivation_plans/:id/data`

## 2. Balloon CRUD（Clean Architecture フルスタック）

サーバー・フロントとも Clean Architecture を採用した CRUD 例。契約の型に近い。

- **ドキュメント**: [docs/verification/balloon_crud_skill_verification.md](/docs/verification/balloon_crud_skill_verification.md)
- **API**: `GET/POST /api/v1/balloons`, `PATCH/DELETE /api/v1/balloons/:id`
- **フロント**: usecase-frontend, gateway-frontend スキルに沿った List + Create
- **サーバー**: Input/Output Port, Gateway, Interactor, DTO を 1 アクション 1 クラスで定義

## 3. 振る舞い定義のサンプル（コードが正）

`docs/contracts/` は廃止。LoadPlanDetail の振る舞いは次を正とする。

- **フロント**: `LoadPlanDetailUseCase` と `plan-gateway.ts` / `plan-api.gateway.ts`（上記 §1）
- **サーバー**: `plans_controller` と関連 Interactor / Presenter / テスト
- **着手前**: [clean-architecture-goal-statement/SKILL.md](../../clean-architecture-goal-statement/SKILL.md) のゴール記述

## 4. OpenAPI スキーマ

マスタ管理 API の契約は OpenAPI で定義されている。

- **ファイル**: [config/openapi.yml](/config/openapi.yml)
- **含まれる API**: Crops, Fertilizes, Pests, Pesticides, Farms, Fields, AgriculturalTasks, InteractionRules
- **形式**: Request/Response のスキーマを YAML で記述。新規 API を追加する場合はこの形式での追記も検討する。
