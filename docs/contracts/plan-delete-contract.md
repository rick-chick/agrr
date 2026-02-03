# 契約: 栽培計画削除と Undo トースト（Plan Delete with Undo）

本契約はフロントエンドから「栽培計画を削除する」ユースケースと、それに対応する API との間を明文化し、サーバー・フロントエンドを並列開発できるようにするものです。削除に対応可能な API 、Undo トークン、トースト通知を含む一連の流れを明示します。

## 1. 機能名・スコープ
- **機能**: プラン一覧で栽培計画を削除し、Undo トーストを表示する
- **スコープ**: `PlanListComponent` から `DeletePlanUseCase` を呼び出す経路、`PlanGateway#deletePlan` → `DELETE /api/v1/plans/:id`、および `UndoToastService` の表示/復元 API

## 2. フロント UseCase 一覧
| UseCase 名 | トリガー（ユーザー操作） | Input DTO |
|------------|--------------------------|-----------|
| DeletePlanUseCase | カード上の「削除」ボタン押下 | `DeletePlanInputDto` |

### 2.1 DeletePlanUseCase 詳細
- **Input DTO**: `{ planId: number; onSuccess?: () => void; onAfterUndo?: () => void }`
- **Output DTO**: `DeletePlanSuccessDto`（`deletedPlanId: number`, `undo?: DeletionUndoResponse`, `refresh?: () => void`）を `DeletePlanOutputPort` に渡す
- **出力フロー**:
  1. `PlanGateway#deletePlan` を呼び出す
  2. 200 OK（Undo 対応 JSON）なら Presenter に `onSuccess`
  3. HTTP エラーなら `ErrorDto` で Presenter に `onError`

## 3. API 一覧
| メソッド | パス | 説明 |
|----------|------|------|
| `DELETE` | `/api/v1/plans/:id` | 栽培計画の論理削除。DeletionUndo をスケジュールし、Undo トークンを返す |
| `POST` | `/undo_deletion` | Undo ボタン押下時に Redis 的な UndoManager に対して復元 API を叩く（既存共通エンドポイント） |

### 3.1 `DELETE /api/v1/plans/:id`
- **Request**:
  - Params: `id` (number, path)
- **Response (200)**: `DeletionUndoResponse`
  ```json
  {
    "undo_token": "abc",
    "toast_message": "プラン Foo を削除しました",
    "undo_path": "/undo_deletion?undo_token=abc",
    "undo_deadline": "2026-02-03T12:00:00Z",
    "resource": "Foo",
    "resource_dom_id": "cultivation_plan_8",
    "redirect_path": "/plans",
    "auto_hide_after": 60000
  }
  ```
- **Error**:
  - 404 `{ "error": "Not found" }`
  - 422/500 `{ "error": string }`

### 3.2 `POST /undo_deletion`
- **Request**:
  - Body: `{ undo_token: string }`
- **Response (200)**: `{ "status": "restored" }`
- **Error**: 400/410/422 など

## 4. フロント UseCase ↔ API マッピング
| フロント UseCase | 呼び出す API（順序） |
|------------------|----------------------|
| DeletePlanUseCase | `DELETE /api/v1/plans/:id`（成功レスポンスの `DeletionUndoResponse` を Presenter に伝播） |

## 5. 共有 DTO / 型定義
### TypeScript（フロント）
- `DeletePlanInputDto`: `frontend/src/app/usecase/plans/delete-plan.dtos.ts`
- `DeletePlanSuccessDto`: 同上
- `DeletePlanOutputPort`: `frontend/src/app/usecase/plans/delete-plan.output-port.ts`
- `DeletionUndoResponse`: `frontend/src/app/domain/shared/deletion-undo-response.ts`
### Ruby（サーバー）
- `DelectionUndo::Manager.schedule` を利用し、`DeletionUndoResponse` 相当 JSON を `render_deletion_undo_response` で返却
- `Api::V1::PlansController#destroy`（名前空間: `Api::V1::PlansController`）を想定

## 6. 実装チェックリスト
- [ ] サーバー: `DELETE /api/v1/plans/:id` を `Api::V1::PlansController#destroy` で実装（`DeletionUndo::Manager` 利用、`render_deletion_undo_response` で JSON 返却）
- [ ] サーバー: `test/controllers/api/v1/plans_controller_test.rb` に削除・404・422 のユースケースを追加
- [ ] フロント: `DeletePlanUseCase` のユニットを作成し、成功/失敗時の Presenter への出力を検証
- [ ] フロント: `plan-list.presenter.spec.ts` でプレゼンターがプランを除外し Undo トーストを呼び出すことを確認
- [ ] フロント: `plan-list.component.spec.ts`（または `plan-list` 試験） で削除ボタンを押すと `DeletePlanUseCase` が呼ばれることを確認
- [ ] フロント: `PlanGateway` と API URL `/api/v1/plans/:id` の整合性を保つ
- [ ] 全体: `docs/contracts/plan-delete-contract.md` を契約として共有
