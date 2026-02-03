 # 契約: Plan Delete without Confirmation
 
 **作成日**: 2026-02-03
 **作成者**: AIアシスタント
 **機能概要**: プラン一覧から削除ボタンを押すと確認ダイアログを表示せず直接削除処理へ進み、Undo トーストで取り消しを可能にする
 **ステータス**: draft
 
 ## ビジネス要件
 - プラン一覧画面で削除をもっとスムーズにするため、削除確認ダイアログは不要とし、ボタン押下で即座に削除リクエストを送信する
 - ユーザーが誤って削除した場合に備えて、Undo トーストを表示して取り消し操作ができる
 - サーバー側 Undo API との契約に従い、レスポンスで Undo トークンを受け取りトーストを出す
 
 ## 技術要件
 - フロントエンドの `PlanListComponent`/`PlanListPresenter` は confirm ダイアログを廃止し、`DeletePlanUseCase` へ直接 `planId` を渡す
 - Undo トースト表示のロジックは変更せず、削除成功時に `DeletionUndoResponse` を受け取ると既存処理でトーストを表示
 - リクエスト/レスポンスの API スキーマ (`DELETE /api/v1/plans/:id`) には変更はないが、フロント側はダイアログなしで即時呼び出す
 
 ## Use Case: DeletePlanWithoutConfirmation
 
 ### 概要
 プラン一覧で削除ボタンを押すと、確認ダイアログを挟まず即座に `DeletePlanUseCase` が呼び出され、Undo トーストを表示して削除を完了する。
 
 ### アクター
 - **Primary Actor**: 管理者ユーザー
 - **Supporting Actors**: `PlanListPresenter`, `DeletePlanUseCase`, `PlanGateway`, Undo トーストサービス
 
 ### 事前条件
 - ユーザーは認証されており、該当プランを削除する権限を持つ
 - 削除対象のプランが存在し、API から削除レスポンスを取得できる
 
 ### 基本フロー
 1. `PlanListComponent` の削除ボタン押下で `PlanListPresenter.confirmDeletePlan` ではなく直接 `DeletePlanUseCase.execute({ planId })` を呼ぶ
 2. `DeletePlanUseCase` が `PlanGateway.deletePlan(planId)` を実行し、`DELETE /api/v1/plans/:id` を呼ぶ
 3. 成功レスポンスとして `DeletionUndoResponse` を受け取り `PlanListPresenter` に `onSuccess` を通知
 4. Presenter は表示中のプラン一覧から対象プランを除去し、Undo トーストを表示して `onAfterUndo`/`onSuccess` を処理する
 
 ### 代替フロー
 - **Alt-1**: ユーザーが誤って連打した場合でも `DeletePlanUseCase` は適切に複数リクエストを処理し、充足できない結果は Presenter が吸収しエラーメッセージを通知する
 
 ### 例外フロー
 - **Exc-1**: API 404/422/500 などエラーが返った場合、`DeletePlanOutputPort#onError` でエラーハンドリングし、トースト表示を行わず該当プランを維持する
 
 ### 事後条件
 - 対象プランがフロント画面から除外される
 - Undo トーストが表示され、ユーザーは一定時間以内に削除を取り消せる
 
 ## API Specification
 
 ### Endpoint: DELETE /api/v1/plans/:id
 
 **説明**: 栽培計画を論理削除し、Undo トークンを含むレスポンスを返す。フロントは確認ダイアログなしで呼び出す。
 
 #### Request
 **Headers**:
 ```
 Content-Type: application/json
 Authorization: Bearer <token>
 ```
 
 **Path Parameters**:
 | Parameter | Type | Required | Description |
 |-----------|------|----------|-------------|
 | id | integer | true | 削除する栽培計画の ID |
 
 **Request Body**: なし
 
 #### Response
 **Success Response (200)**:
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
 
 **Error Responses**:
 - 404 Not Found: `{ "error": "Not found" }`
 - 422/500: `{ "error": string }`
 
 ## Data Models
 - `DeletePlanInputDto`: `{ planId: number; onSuccess?: () => void; onAfterUndo?: () => void }`
 - `DeletePlanSuccessDto`: `frontend/src/app/usecase/plans/delete-plan.dtos.ts`
 - `DeletionUndoResponse`: `frontend/src/app/domain/shared/deletion-undo-response.ts`
 
 ## 実装タスク
 
 ### Phase 1: UseCase層実装
 - [ ] `DeletePlanUseCase` を調整し、confirm ダイアログを要求せず常に `PlanGateway.deletePlan` を呼ぶパターンを動作させる
 - [ ] `DeletePlanUseCase` のユニットテストで、confirm 処理を経由せずに `planId` だけで動作するよう更新
 
 ### Phase 2: Adapter層実装
 - [ ] `PlanListPresenter`/`PlanListComponent` を修正して、`confirmDeletePlan` を取り除き `executeConfirmedDelete` を直接呼ぶ
 - [ ] `plan-list.component.spec.ts` と Presenter テストを更新し、confirm ダイアログに依存しないチェックにする
 - [ ] `PlanGateway` が現行 API を呼ぶことを確認（変更不要だが整合性チェック）
 
 ### Phase 3: テスト実装
 - [ ] フロントの Unit Test で confirm dialog なしの削除フローを検証
 - [ ] 影響範囲の E2E/統合テストがあれば `plan-list` 系のフローを再確認
 
 ### Phase 4: 検証
 - [ ] API 仕様通り `DELETE /api/v1/plans/:id` から `DeletionUndoResponse` を受け取りトーストが表示されるか確認
 - [ ] エラーケース（404/422/500）に対してプランが残るか確認
 
 ## レビューポイント
 
 ### 機能要件
 - [ ] 確認ダイアログを経由せずに即時削除されたこと
 - [ ] Undo トースト表示と取り消しが継続して動作すること
 
 ### 技術要件
 - [ ] API に変更がないことを確認し、`PlanGateway` 呼び出しが正しいか
 - [ ] エラー時の Presenter/Component でリストが復元されること
 
 ### 設計品質
 - [ ] Clean Architecture に従い、UseCase/Presenter/Component の責務を分離できているか
 - [ ] 测试容易性が保たれているか
 
 ## 変更履歴
 | Date | Version | Author | Changes |
 |------|---------|--------|---------|
 | 2026-02-03 | 1.0 | AIアシスタント | 確認ダイアログを省略した削除フローを定義 |
