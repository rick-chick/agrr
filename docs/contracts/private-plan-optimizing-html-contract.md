# プライベート計画・最適化進捗（HTML）契約

## スコープ

- **ユースケース**: `GET .../plans/:id/optimizing` → **`Domain::CultivationPlan::Interactors::PrivatePlanOptimizingInteractor#call`**
- **`on_success` に渡すもの（一文）**: **`PrivatePlanOptimizingDto`**（`id`: **Integer**、`plan_year`: **Integer または nil**、`farm_display_name`: **String**、`cultivation_plan_crops_count`: **Integer**、`optimization_phase_message`: **String または nil**、`status`: **String**（`CultivationPlan#status` と同値））。**ActiveRecord は Port を越えない**。

## Output Port

- **HTML**: `Presenters::Html::Plans::PrivatePlanOptimizingHtmlPresenter`（`PlanOptimizingStatusOutputPort`）
- **`on_failure`**: `redirect_to plans_path` + `alert`（未認可・不存在は `plans.errors.not_found`、想定外は `plans.errors.restart`＋logger）

## Gateway

- **`CultivationPlanGateway#private_plan_optimizing_read_model(plan_id:, user:)`** — **`PlanPolicy.private_scope(user)`** で所有 private 計画のみ取得し、**`includes(:farm, :cultivation_plan_crops)`** で N+1 を避けつつ **`PrivatePlanOptimizingReadModel`**（画面非依存の読み取り用スナップショット）を返す（他ユーザ・不存在は `RecordNotFound`）。**`PrivatePlanOptimizingDto`** は Interactor 成功時に **`PrivatePlanOptimizingAssembler`** で組み立てる。

## Controller

- **`:id`**: **正の整数**（`/[1-9]\d*/`）のみ受け付け。それ以外は `plans.errors.not_found` で `plans_path` へ。
- **完了／失敗時のリダイレクト**: **`PrivatePlanOptimizingHtmlPresenter#on_success`** が DTO の `status` を見て **`completed`** なら **`plan_path(dto.id)`**、**`failed`** なら同パスに **`plans.optimizing.error.title`** を `alert` 付きでリダイレクト（コントローラは Interactor 呼び出し後 **`return if performed?`** のみ）。
- **注入**: `gateway` / `translator` / `logger` / `user_lookup` は **Interactor のみ**。Presenter に gateway を渡さない。
- **`on_failure` または上記 `on_success` の redirect** 後は `performed?` が true になる。

## テンプレ（`plans/optimizing`）

- **`@private_plan_optimizing`** の属性のみ参照（`@vm` / 生の `@cultivation_plan` は使用しない）。
- **`plan_year` が nil** の通年計画では **`plans.optimizing.year_label_annual`** をヘッダに用いる。
