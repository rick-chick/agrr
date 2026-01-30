# ほ場（Fields）農場詳細内 CRUD 実装（cursor-agent 用プロンプト）

## 参照
- `docs/implementation/MASTER_MANAGEMENT_FRONTEND_TODO.md` の「2.8 ほ場」「TODO 7」「3. Rails API パラメータ fields」「5. 削除のトースト＋Undo」「6. 共通実装パターン」
- Rails: `app/controllers/api/v1/masters/fields_controller.rb` — index(farm_id), show(id), create(farm_id), update(id), destroy(id)。destroy は 200 + DeletionUndoResponse。
- 既存: farm-detail（control.fields 一覧表示のみ）、FarmGateway#listFieldsByFarm、LoadFarmDetailUseCase
- スキル: usecase-frontend, gateway-frontend, presenter-frontend, controller-frontend（`.cursor/skills/`）

## API
- POST `/api/v1/masters/farms/:farm_id/fields` body: `{ field: { name, area, daily_fixed_cost, region } }` → Field
- PATCH `/api/v1/masters/fields/:id` body: `{ field: { name, area, daily_fixed_cost, region } }` → Field
- DELETE `/api/v1/masters/fields/:id` → 200 + DeletionUndoResponse

MastersClientService は先頭に `/api/v1/masters` を付与するので、Gateway では `post('/farms/' + farmId + '/fields', { field: payload })`、`patch('/fields/' + fieldId, { field: payload })`、`delete('/fields/' + fieldId)` でよい。

## やること

### 1. Gateway
- **FarmGateway** に追加: `createField(farmId: number, payload: FieldCreatePayload): Observable<Field>`、`updateField(fieldId: number, payload: FieldCreatePayload): Observable<Field>`、`destroyField(fieldId: number): Observable<DeletionUndoResponse>`。
- **FieldCreatePayload**（または FieldUpdatePayload）: `{ name: string; area: number | null; daily_fixed_cost: number | null; region: string | null }`。domain/farms/field.ts の Field と整合させる。
- **FarmApiGateway** に上記3メソッドを実装（client.post/patch/delete）。

### 2. UseCases
- **create-field**: CreateFieldUseCase。Input: farmId, payload, onSuccess, onError。FarmGateway#createField を呼び、成功時は OutputPort.present({ field })、失敗時は onError。作成後に一覧を更新するため、成功時に farmId を返すか、呼び出し元で load(farmId) を実行。
- **update-field**: UpdateFieldUseCase。Input: fieldId, payload, onSuccess, onError。FarmGateway#updateField。成功時 present({ field })、失敗時 onError。
- **delete-field**: DeleteFieldUseCase。Input: fieldId, farmId（再取得用）, onSuccess(dto: { undo?: DeletionUndoResponse }), onError。FarmGateway#destroyField。成功時は OutputPort に undo を渡し、Presenter で UndoToastService.showWithUndo(..., onRestored: () => view.load?.(farmId))。
- 各 UseCase 用の DTOs・InputPort・OutputPort を定義。

### 3. Presenters
- 農場詳細内で使う Field 用 Presenter: CreateFieldPresenter（作成成功時に view の load?.(farmId) または list 更新）、UpdateFieldPresenter、DeleteFieldPresenter（削除成功時に undo があれば UndoToastService.showWithUndo(..., onRestored: () => view.load?.(farmId))）。
- FarmDetailView に `load?(farmId: number): void` を追加し、Undo 復元後や作成・更新後に再取得できるようにする。

### 4. 農場詳細 UI（farm-detail）
- **一覧**: 既存の `<ul><li *ngFor="let field of control.fields">` を維持。
- **追加**: 「ほ場を追加」ボタン。クリックでインラインフォームまたはモーダルで name, area, daily_fixed_cost, region を入力し、CreateFieldUseCase 実行。成功後は load(farmId) で再取得。
- **各行**: 編集ボタン・削除ボタン。編集はインラインまたはモーダルで UpdateFieldUseCase。削除は confirm 後 DeleteFieldUseCase、成功時は Undo トースト表示と onRestored で load(farmId)。
- FarmDetailComponent に CreateFieldUseCase, UpdateFieldUseCase, DeleteFieldUseCase と各 Presenter を inject。View インターフェースに load?(farmId) を追加し、Presenter の onRestored で this.view?.load?.(farmId) を呼ぶ。

### 5. 子コンポーネント（任意）
- 作成・編集フォームを `field-form.component` などとして切り出してもよい。その場合は FarmDetail から @Input farmId、@Output saved / cancelled で連携。

## 注意
- Field の domain は既に `domain/farms/field.ts` にある。description が Rails の strong params にないが、Rails の field_params は `name, area, daily_fixed_cost, region` のみ。必要なら Field 型と API を合わせる。
- 削除は必ず Undo トースト対応（DeletionUndoResponse を Presenter で UndoToastService に渡す）。
