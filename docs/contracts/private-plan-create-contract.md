# 契約: 個人計画の新規作成（Private Plan Create）

## 1. 機能名・スコープ

- **機能**: ログイン済みユーザーが個人計画（private plan）を Angular 上で新規作成する。
- **スコープ**: 「計画」一覧からの「新規計画」→ 農場選択 → 作物選択 → 作成 → 最適化進捗画面へ遷移。既存の plans#index/show（HTML）および API GET /api/v1/plans はそのまま利用する。本契約は **新規作成フロー** の API と Angular UseCase/画面に限定する。

## 2. フロント UseCase 一覧

| UseCase 名 | トリガー（ユーザー操作） | Input DTO |
|------------|--------------------------|-----------|
| LoadPrivatePlanFarmsUseCase | 新規計画画面の初期表示 | なし（認証ユーザーで農場一覧取得） |
| LoadPrivatePlanSelectCropContextUseCase | 作物選択画面の初期表示（農場選択後） | `{ farmId: number }` |
| CreatePrivatePlanUseCase | 作物選択画面で「作成」クリック | `CreatePrivatePlanInputDto` |

### 2.1 LoadPrivatePlanFarmsUseCase 詳細

- **Input**: なし（または空オブジェクト）
- **Output**: 農場一覧 `Farm[]`（Presenter に渡す）

### 2.2 LoadPrivatePlanSelectCropContextUseCase 詳細

- **Input DTO**: `{ farmId: number }`
- **Output DTO**: `{ farm: Farm; totalArea: number; crops: Crop[] }`（作物はユーザー所有・非参照の一覧。totalArea は農場の圃場面積合計）

### 2.3 CreatePrivatePlanUseCase 詳細

- **Input DTO**: `CreatePrivatePlanInputDto` = `{ farmId: number; planName?: string; cropIds: number[] }`
- **Output**: 成功時は `/plans/:id/optimizing` へ遷移＋成功メッセージ。失敗時はエラーメッセージ表示。

## 3. API 一覧

| メソッド | パス | 説明 | 認証 |
|----------|------|------|------|
| GET | /api/v1/farms | ユーザー所有の農場一覧（新規計画の農場選択用） | 必須 |
| GET | /api/v1/farms/:id | 農場詳細（圃場含む。total_area 算出に利用） | 必須 |
| GET | /api/v1/crops | ユーザー所有・非参照の作物一覧（作物選択用） | 必須 |
| POST | /api/v1/plans | 個人計画の新規作成 | 必須 |

### 3.1 GET /api/v1/farms

- **既存 API を利用**。Response は `Farm[]`（既存のマスタ農場一覧と同じ形式でよい）。
- **認証**: 必須。未認証は 401。

### 3.2 GET /api/v1/farms/:id

- **既存 API を利用**。Response に農場情報および圃場（fields）を含め、フロントで total_area（圃場面積合計）を算出可能にする。既存仕様で fields が含まれていなければ、本機能用に total_area をレスポンスに含めてもよい。
- **認証**: 必須。

### 3.3 GET /api/v1/crops

- **既存 API を利用**。ユーザー所有かつ is_reference: false の作物一覧。Response は `Crop[]`。
- **認証**: 必須。

### 3.4 POST /api/v1/plans（新規）

- **Request**
  - Content-Type: `application/json`
  - Body: `{ "farm_id": number, "plan_name"?: string, "crop_ids": number[] }`
  - `plan_name` は省略時は農場名を使用。
- **Response** (201)
  - `{ "id": number }` または `{ "id": number, "name": string, "status": string }`（作成された計画の ID および必要ならサマリ）
- **Response** (422)
  - 既存計画が同じ farm×user で存在する場合: `{ "error": string }`
  - 作物未選択など: `{ "error": string }` または `{ "errors": string[] }`
- **Response** (401): 未認証
- **認証**: 必須。サーバーは `current_user` と `CultivationPlanCreator`（既存）を用いて計画を作成し、最適化ジョブをキックする。既存の PlansController#create と同等ロジックを API に持つ。

## 4. フロント UseCase ↔ API マッピング

| フロント UseCase | 呼び出す API（順序） |
|------------------|----------------------|
| LoadPrivatePlanFarmsUseCase | `GET /api/v1/farms` |
| LoadPrivatePlanSelectCropContextUseCase | `GET /api/v1/farms/:id`, `GET /api/v1/crops`（並列可） |
| CreatePrivatePlanUseCase | `POST /api/v1/plans` |

## 5. 共有 DTO / 型定義

### TypeScript（フロント）

- **Farm**: 既存 `frontend/src/app/domain/farms/farm.ts`
- **Crop**: 既存 `frontend/src/app/domain/crops/crop.ts`
- **CreatePrivatePlanInputDto**: `{ farmId: number; planName?: string; cropIds: number[] }`
- **CreatePrivatePlanResponse**: `{ id: number }` または `{ id: number; name?: string; status?: string }`

### Ruby（サーバー）

- POST /api/v1/plans の Request: `farm_id` (integer), `plan_name` (string, optional), `crop_ids` (array of integer)
- Response: `{ id: plan.id }` または既存 serialize_plan に合わせる

## 6. 画面・ルート

- **新規計画**: `/plans/new` — 農場選択（＋任意で計画名）。選択後「次へ」で `/plans/select-crop?farmId=:id` へ。
- **作物選択**: `/plans/select-crop?farmId=:id` — 作物チェックボックス、計画名（任意）、「作成」で CreatePrivatePlanUseCase 実行。成功時 `/plans/:id/optimizing` へ。
- **計画一覧**: 既存 `/plans`（PlanListComponent）に「新規計画」リンクを追加し、`/plans/new` へ誘導。

## 7. 実装チェックリスト

- [ ] Rails: `config/routes.rb` に `POST /api/v1/plans` を追加（Api::V1::PlansController#create または専用エンドポイント）
- [ ] Rails: POST で farm_id, plan_name, crop_ids を受け取り、CultivationPlanCreator と既存ジョブチェーンで計画作成・最適化キック。既存計画が同一 farm×user の場合は 422。
- [x] Angular: LoadPrivatePlanFarmsUseCase / LoadPrivatePlanSelectCropContextUseCase / CreatePrivatePlanUseCase を定義（input/output port, gateway interface）
- [x] Angular: PlanGateway（または PrivatePlanCreateGateway）に `createPlan(farmId, planName?, cropIds)` を追加。POST /api/v1/plans を呼ぶ。
- [ ] Angular: コンポーネント plan-new（農場選択）、plan-select-crop（作物選択）を追加。ルート `/plans/new`, `/plans/select-crop` を追加。
- [ ] Angular: 計画一覧（plan-list）に「新規計画」ボタン/リンクを追加し、`/plans/new` へ遷移。
- [x] Angular: LoadPrivatePlanFarmsPresenter / LoadPrivatePlanSelectCropContextPresenter / CreatePrivatePlanPresenter を実装・テスト
- [ ] ナビ: 必要に応じて Angular ナビの「計画」から「新規計画」を案内（既存「計画」が一覧なので、一覧内の CTA で十分ならナビ変更は任意）。
- [ ] エラー形式: 契約どおり `{ error }` または `{ errors }` で統一。

## 8. 既存サーバー側との関係

- `PlansController#create`（HTML）および `CultivationPlanCreator`、ジョブチェーン（最適化→作業予定生成→PlanFinalizeJob）は既存のまま利用する。
- 新規 API `POST /api/v1/plans` は、PlansController#create と同等のパラメータ（farm_id, plan_name, crop_ids）を JSON で受け、同じ Creator とジョブを呼ぶ。セッションは使わず、リクエスト body のみで完結させる。
