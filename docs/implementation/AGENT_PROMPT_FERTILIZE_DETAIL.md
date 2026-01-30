# 肥料 詳細表示ルート実装（cursor-agent 用プロンプト）

## 参照
- `docs/implementation/MASTER_MANAGEMENT_FRONTEND_TODO.md` の「2.3 肥料」「TODO 2」
- 既存: crop-detail, pest-detail（LoadXxxDetailUseCase + XxxDetailPresenter + detail.view / component）
- スキル: usecase-frontend, presenter-frontend, controller-frontend（`.cursor/skills/`）

## やること
1. **ルート**: `app.routes.ts` に `path: 'fertilizes/:id'` を追加（`fertilizes/:id/edit` の**後**に配置し、編集ルートと衝突しないようにする）。
2. **UseCase**: `LoadFertilizeDetailUseCase` を追加。Input: `{ fertilizeId: number }`。FertilizeGateway の `show(fertilizeId)` を呼び、成功時は OutputPort に `present({ fertilize })`、失敗時は `onError({ message })`。
3. **OutputPort**: `LoadFertilizeDetailOutputPort`（`present({ fertilize })`, `onError({ message })`）、DTO は `load-fertilize-detail.dtos.ts`。
4. **Presenter**: `FertilizeDetailPresenter`。OutputPort を実装し、View の `control` を更新。
5. **View/Component**: `fertilize-detail.view.ts`（`FarmDetailViewState` 相当: `loading`, `error`, `fertilize`）、`fertilize-detail.component.ts`。テンプレートでは肥料の名前・N/P/K・説明等を表示し、「編集」リンクを `fertilizes/:id/edit` へ。
6. **一覧からのリンク**: fertilize-list で「名前」をクリックしたときに `fertilizes/:id` へ遷移するようにする（現状は編集に飛んでいればそのままでも可。必要なら routerLink を追加）。

## 注意
- FertilizeGateway には既に `show(fertilizeId)` があるので Gateway の変更は不要。
- 既存の fertilize-edit はそのまま利用。詳細は「表示専用＋編集リンク」でよい。
