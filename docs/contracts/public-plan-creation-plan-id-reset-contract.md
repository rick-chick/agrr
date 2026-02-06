# 契約: 無料作付計画作成の planId 管理改善（Public Plan Creation planId Reset）

## 1. 機能名・スコープ
- **機能**: 無料作付計画を新規作成するたびにフロントエンドで旧 planId を使い続けないようにし、常に API から返却された最新 planId を基準にする。
- **スコープ**: `/public-plans/new` → `/public-plans/select-…` → `/public-plans/optimizing` 等の Angular 公開プランフロー、および `POST /api/v1/public_plans/plans` の応答。フロントでは `PublicPlanStore` のセッション状態をリセット／更新し、最適化・結果画面で表示する planId と `planId` クエリパラメータが一致することを保証する。

## 2. フロント UseCase 一覧
| UseCase 名 | トリガー（ユーザー操作） | Input DTO |
|------------|--------------------------------|-----------|
| ResetPublicPlanCreationStateUseCase | `/public-plans/new` に遷移する・「もう一度作成」など流れを再開する | `{}`（なし） |
| CreatePublicPlanUseCase（既存） | 作付選択画面で「作付を作成」ボタンをクリック | `{ farmId: number, farmSizeId: string, cropIds: number[], onSuccess?: (response: { plan_id: number }) => void }` |

### 2.1 ResetPublicPlanCreationStateUseCase 詳細
- **責務**: `PublicPlanStore.reset()` を呼び出して `planId` を `null` にし、`agrr_public_plan_state` セッションキーを削除。過去の planId や選択中の農場／作物が残っているときはそれをクリアして新規計画の状態を担保する。
- **実行タイミング**: `PublicPlanCreateComponent.ngOnInit()` など `PublicPlan` フローを始めるタイミングで必ず呼ぶ。`PublicPlanSelectCropComponent` もこの UseCase を呼び出し新しい計画が開始済みであることを保証してよい。

### 2.2 CreatePublicPlanUseCase（既存）調整
- **変更点**: API 成功時に `PublicPlanStore.setPlanId(response.plan_id)` を呼び、セッションに保存される planId を強制的に最新の値で上書き。これにより後続画面でクエリパラメータが無い場合も新しい planId を参照できる。
- **追加責務**: `onSuccess` で `router.navigate(['/public-plans/optimizing'], { queryParams: { planId: response.plan_id } })` を呼ぶ直前に store を更新することで、最適化画面が queryParam + ストアのいずれからでも一致した planId を取得できる。

## 3. API 一覧
| メソッド | パス | 説明 | 認証 |
|----------|------|------|------|
| POST | /api/v1/public_plans/plans | 公開プラン作成。新しい `CultivationPlan` を作って `plan_id` を返す。 | なし（非ログインでも可） |

### 3.1 POST /api/v1/public_plans/plans
- **Request**
  - Content-Type: `application/json`
  - Body: `{ "farm_id": number, "farm_size_id": string, "crop_ids": number[] }`
- **Response** (200)
  - `{ "plan_id": number }`（DB の Auto Increment による新規 `CultivationPlan#id`）
- **Response** (4xx/5xx)
  - `{ "error": string }`
- **認証**: 未認証でも呼べる（`WizardController` は `skip_before_action :authenticate_user!`）。
- **重要**: 常に新しい row が挿入され、その `id` を `plan_id` にしていること。フロントは過去の planId を使わず、返却値を確実に store にセットする。

## 4. 既存サーバー側との関係
- `Api::V1::PublicPlans::WizardController#create` は `CultivationPlanCreator` を呼んで `CultivationPlan.create!` し、`render json: { plan_id: cultivation_plan.id }` を返す。すでに毎回新規 planId を発行しているため変更なし。
- ロジックの整合性を保証するため、この契約を受けたユースケース／ゲートウェイでは `plan_id` の値とステータスをログ出力し、連続で同じ値が返ってくる場合は運用で確認できるようにする。

## 5. 実装チェックリスト
- [ ] Angular: `/public-plans/new` 入口（`PublicPlanCreateComponent` など）で `ResetPublicPlanCreationStateUseCase` を実行し、`PublicPlanStore.reset()` により planId/選択状態をクリアする。
- [ ] Angular: `CreatePublicPlanUseCase` の成功ハンドラーに store 更新（`setPlanId`）を入れ、`planId` が最新に書き換わることを確認する。
- [ ] Angular: Optimizing/Results コンポーネントは queryParam なしでも `PublicPlanStore.state.planId` を使うケースを想定し、古い planId の残存ログが出ないことを確認する。
- [ ] Rails: `POST /api/v1/public_plans/plans` で常に新しい `CultivationPlan.id` を返すこと（既存）。必要に応じてログ出力を追加して planId 生成を追跡。
