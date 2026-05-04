# 契約: 無料作付け計画の保存（Public Plan Save）

## 1. 機能名・スコープ

- **機能**: 無料作付け計画の結果画面から、ログイン済みユーザーが計画を「自分の計画」に保存する。
- **スコープ**: Angular 結果画面（`/public-plans/results?planId=...`）の「保存」ボタンから呼ばれる API およびフロントの UseCase/Gateway/Controller。

## 2. フロント UseCase 一覧

| UseCase 名 | トリガー（ユーザー操作） | Input DTO |
|------------|--------------------------|-----------|
| SavePublicPlanUseCase | 結果画面で「保存」クリック（ログイン済み） | `{ planId: number }` |

### 2.1 SavePublicPlanUseCase 詳細

- **Input DTO**: `{ planId: number }`（クエリまたは Store から取得した計画 ID）
- **Output**: 成功時は `/plans` へ遷移＋成功メッセージ。失敗時はエラーメッセージ表示。
- **未ログイン時**: 本 UseCase は呼ばず、既存どおりログイン画面へリダイレクトする。

## 3. API 一覧

| メソッド | パス | 説明 | 認証 |
|----------|------|------|------|
| POST | /api/v1/public_plans/save_plan | 公開計画をログイン中のユーザーの計画にコピー | 必須 |

### 3.1 POST /api/v1/public_plans/save_plan

- **Request**
  - Content-Type: `application/json`
  - Body: `{ "plan_id": number }`（保存対象の CultivationPlan ID）
- **Response** (200)
  - `{ "success": true }`
- **Response** (4xx/5xx)
  - `{ "success": false, "error": string }`
- **認証**: 未認証の場合は 401 を返す。

## 4. 既存サーバー側との関係

- `Domain::CultivationPlan::Interactors::PlanSaveSession`（アダプタ `lib/adapters/cultivation_plan/sessions/plan_save_session.rb`）がオーケストレータ。マスタコピーは `lib/domain/cultivation_plan/mappers/*`、計画コピー・タスクスケジュール複製は `lib/adapters/cultivation_plan/plan_copy_gateway.rb`、ブループリント複製は `lib/adapters/cultivation_plan/crop_task_schedule_blueprint_gateway.rb`、日付計算は `lib/domain/cultivation_plan/calculators/planning_date_calculator.rb`。
- 保存のユースケース境界は **`Domain::CultivationPlan::Interactors::PublicPlanSaveFromSessionInteractor`**（`output_port` + `PublicPlanSaveGateway#save_from_session`）。成功・失敗（想定／想定外）は **出力ポート経由**で HTML / API Presenter が HTTP 応答を決める（コントローラの `rescue` で結果を組み立てない）。
- [docs/contracts/public-plan-save-contract.md](docs/contracts/public-plan-save-contract.md) の API 失敗時は **`{ "success": false, "error": string }`**。400（`plan_id` 欠落）、404（計画なし）、422（保存処理の業務失敗）、500（想定外）を Presenter が付与する。

## 5. 実装チェックリスト

- [x] Rails: `config/routes.rb` に `post 'public_plans/save_plan'` と `get 'public_plans/process_saved_plan'` を追加（HTML 用）
- [x] Rails: `POST /api/v1/public_plans/save_plan` を追加（JSON、認証必須）。`PublicPlanSaveFromSessionInteractor` + `PublicPlanSaveFromSessionApiPresenter` で JSON を返す（`Api::V1::PublicPlansController#save_plan`）
- [x] Angular: SavePublicPlanUseCase で上記 API を呼ぶ
- [x] Angular: PublicPlanApiGateway に `savePlan(planId: number)` を追加
- [x] Angular: 結果画面の `savePlan()` で、ログイン済みなら API 呼び出し→成功時は `/plans` へ遷移＋メッセージ、失敗時はエラー表示
