# マスタ管理フロントエンド実装TODO

## 1. Rails側の既存機能（共通）

### API基盤
- **ベース**: `Api::V1::Masters::BaseController`
  - 認証: APIキー または セッション（SPAログイン）
  - CSRFスキップ、`authenticate_api_key_or_session!`
- **CRUD共通**: `ApiCrudResponder` を include
  - `respond_to_index`, `respond_to_show`, `respond_to_create`, `respond_to_update`, `respond_to_destroy`

### マスタAPI一覧（config/routes.rb）

| リソース | エンドポイント | アクション | 備考 |
|----------|----------------|------------|------|
| crops | `/api/v1/masters/crops` | index, show, create, update, destroy | ネスト: pests, agricultural_tasks, crop_stages, pesticides |
| fertilizes | `/api/v1/masters/fertilizes` | index, show, create, update, destroy | |
| pests | `/api/v1/masters/pests` | index, show, create, update, destroy | |
| pesticides | `/api/v1/masters/pesticides` | index, show, create, update, destroy | |
| farms | `/api/v1/masters/farms` | index, show, create, update, destroy | ネスト: fields |
| fields | `/api/v1/masters/farms/:farm_id/fields`, `/api/v1/masters/fields/:id` | index, show, create, update, destroy | |
| agricultural_tasks | `/api/v1/masters/agricultural_tasks` | index, show, create, update, destroy | |
| interaction_rules | `/api/v1/masters/interaction_rules` | index, show, create, update, destroy | |

### 実装すべき共通機能（Railsは既に提供済み）
- 各マスタの **index / show / create / update / destroy** はRails側で実装済み
- レスポンス: JSON（作成・更新はリソース、削除は 204 No Content）
- エラー: 422 + `{ errors: string[] }`、404/403 は各コントローラで render

---

## 2. Angular側の現状と不足一覧

### 2.1 農場 (Farms) — ✅ 完成
- 一覧・詳細・新規作成・編集・削除あり
- ほ場一覧は詳細画面で表示（作成・編集・削除UIは未実装）

### 2.2 作物 (Crops) — ✅ 完成
| 機能 | Rails | Angular | 備考 |
|------|-------|---------|------|
| 一覧 | ✅ | ✅ | crop-list（新規・編集・削除リンクあり） |
| 詳細 | ✅ | ✅ | crop-detail（編集・削除ボタンあり） |
| 新規作成 | ✅ | ✅ | crop-create（Clean Architecture） |
| 編集 | ✅ | ✅ | crop-edit（load-crop-for-edit + update-crop） |
| 削除 | ✅ | ✅ | Undoトースト対応 |
- **CropGateway**: `list`, `show`, `create`, `update`, `destroy`（DeletionUndoResponse）
- **UseCase**: load-crop-list, load-crop-detail, create-crop, update-crop, delete-crop, load-crop-for-edit
- **ルート**: `crops`, `crops/new`, `crops/:id/edit`, `crops/:id`

### 2.3 肥料 (Fertilizes) — ほぼ完成
| 機能 | Rails | Angular | 備考 |
|------|-------|---------|------|
| 一覧 | ✅ | ✅ | 新規・編集・削除リンクあり |
| 詳細 | ✅ | ❌ | ルート `fertilizes/:id` なし（編集は `:id/edit` で存在） |
| 新規作成 | ✅ | ✅ | fertilize-create |
| 編集 | ✅ | ✅ | fertilize-edit |
| 削除 | ✅ | ✅ | 一覧から削除可能 |
- 詳細専用ページは任意（一覧→編集で代替可能）

### 2.4 病害虫 (Pests) — ✅ 完成
| 機能 | Rails | Angular | 備考 |
|------|-------|---------|------|
| 一覧 | ✅ | ✅ | pest-list（新規・編集・削除リンクあり） |
| 詳細 | ✅ | ✅ | pest-detail（編集・削除ボタンあり） |
| 新規作成 | ✅ | ✅ | pest-create（Clean Architecture） |
| 編集 | ✅ | ✅ | pest-edit（load-pest-for-edit + update-pest） |
| 削除 | ✅ | ✅ | Undoトースト対応 |
- **PestGateway**: `list`, `show`, `create`, `update`, `destroy`（DeletionUndoResponse）
- **UseCase**: load-pest-list, load-pest-detail, create-pest, update-pest, delete-pest, load-pest-for-edit
- **ルート**: `pests`, `pests/new`, `pests/:id/edit`, `pests/:id`

### 2.5 農薬 (Pesticides) — ✅ 完成
| 機能 | Rails | Angular | 備考 |
|------|-------|---------|------|
| 一覧 | ✅ | ✅ | pesticide-list（新規・編集・削除リンクあり） |
| 詳細 | ✅ | ✅ | pesticide-detail（編集・削除ボタンあり） |
| 新規作成 | ✅ | ✅ | pesticide-create（Clean Architecture） |
| 編集 | ✅ | ✅ | pesticide-edit（load-pesticide-for-edit + update-pesticide） |
| 削除 | ✅ | ✅ | Undoトースト対応 |
- **PesticideGateway**: `list`, `show`, `create`, `update`, `destroy`（DeletionUndoResponse）
- **ルート**: `pesticides`, `pesticides/new`, `pesticides/:id/edit`, `pesticides/:id`

### 2.6 農作業 (Agricultural tasks) — ✅ 完成
| 機能 | Rails | Angular | 備考 |
|------|-------|---------|------|
| 一覧 | ✅ | ✅ | agricultural-task-list（新規・編集・削除リンクあり） |
| 詳細 | ✅ | ✅ | agricultural-task-detail（編集・削除ボタンあり） |
| 新規作成 | ✅ | ✅ | agricultural-task-create（Clean Architecture） |
| 編集 | ✅ | ✅ | agricultural-task-edit（load-for-edit + update） |
| 削除 | ✅ | ✅ | Undoトースト対応 |
- **AgriculturalTaskGateway**: `list`, `show`, `create`, `update`, `destroy`（DeletionUndoResponse）
- **ルート**: `agricultural_tasks`, `agricultural_tasks/new`, `agricultural_tasks/:id/edit`, `agricultural_tasks/:id`

### 2.7 相互作用ルール (Interaction rules) — ✅ 完成
| 機能 | Rails | Angular | 備考 |
|------|-------|---------|------|
| 一覧 | ✅ | ✅ | interaction-rule-list（新規・編集・削除リンクあり） |
| 詳細 | ✅ | ✅ | interaction-rule-detail（編集・削除ボタンあり） |
| 新規作成 | ✅ | ✅ | interaction-rule-create（Clean Architecture） |
| 編集 | ✅ | ✅ | interaction-rule-edit（load-for-edit + update） |
| 削除 | ✅ | ✅ | Undoトースト対応 |
- **InteractionRuleGateway**: `list`, `show`, `create`, `update`, `destroy`（DeletionUndoResponse）
- **ルート**: `interaction_rules`, `interaction_rules/new`, `interaction_rules/:id/edit`, `interaction_rules/:id`

### 2.8 ほ場 (Fields) — 一覧表示のみ
| 機能 | Rails | Angular | 備考 |
|------|-------|---------|------|
| 一覧 | ✅ | ✅ | 農場詳細で `control.fields` 表示 |
| 詳細 | ✅ | ❌ | 専用画面なし |
| 新規作成 | ✅ | ❌ | 農場詳細内のUIなし |
| 編集 | ✅ | ❌ | 同上 |
| 削除 | ✅ | ❌ | 同上 |
- **FarmGateway**: `listFieldsByFarm(farmId)` あり（一覧取得のみ）
- Field 単体の show/create/update/destroy 用 Gateway・UseCase・UI は未実装

---

## 3. Rails API パラメータ（作成・更新用）

実装時に参照する strong params:

- **crops**: `name`, `variety`, `area_per_unit`, `revenue_per_area`, `region`, `groups[]`
- **fertilizes**: （既存 fertilize-gateway / create-fertilize を参照）
- **pests**: `name`, `name_scientific`, `family`, `order`, `description`, `occurrence_season`, `region`
- **pesticides**: `name`, `active_ingredient`, `description`, `crop_id`, `pest_id`, `region`
- **agricultural_tasks**: `name`, `description`, `time_per_sqm`, `weather_dependency`, `required_tools`, `skill_level`, `region`, `task_type`
- **interaction_rules**: `rule_type`, `source_group`, `target_group`, `impact_ratio`, `is_directional`, `description`, `region`
- **fields**: `name`, `area`, `daily_fixed_cost`, `region`（create は `farms/:farm_id/fields`）

---

## 4. TODO 一覧（順次対応）

| # | タスク | 優先度 | 依存 |
|---|--------|--------|------|
| 1 | **作物 (Crops)** 作成・更新・削除: UseCase / Gateway / 画面（crop-create, crop-edit）、ルート | 高 | - |
| 2 | **肥料 (Fertilizes)** 詳細表示ルート `fertilizes/:id` の追加（任意） | 低 | - |
| 3 | **病害虫 (Pests)** 詳細・作成・更新・削除のフルCRUD（Gateway拡張、UseCase、画面、ルート） | 高 | - |
| 4 | **農薬 (Pesticides)** 詳細・作成・更新・削除のフルCRUD | 高 | - |
| 5 | **農作業 (Agricultural tasks)** 詳細・作成・更新・削除のフルCRUD | 高 | - |
| 6 | **相互作用ルール (Interaction rules)** 詳細・作成・更新・削除のフルCRUD | 高 | - |
| 7 | **ほ場 (Fields)** 農場詳細内でのほ場の作成・編集・削除UI（Gateway/UseCase/子コンポーネント） | 高 | Farm 詳細 |

推奨順: 1 → 3 → 4 → 5 → 6 → 7 → 2（肥料詳細は任意）

---

## 5. 削除のトースト＋Undo（REDO）対応

### Rails API
- **Api::V1::Masters::BaseController** に `DeletionUndoFlow` を include
- 各マスタの **destroy** は `schedule_deletion_with_undo` を使用し、**200 + JSON**（`undo_token`, `toast_message`, `undo_path` 等）を返す
- 復元は既存の `POST /:locale/undo_deletion`（`deletion_undos#create`）で実施

### フロント
- **DeletionUndoResponse**（`domain/shared/deletion-undo-response.ts`）: 削除APIのJSON型
- **UndoToastService**: `showWithUndo(message, undoPath, undoToken, onRestored?)`, `performUndo()` でトースト表示と復元API呼び出し
- **App**: `<app-undo-toast (undo)="performUndo()" />` で Undo クリック時に `performUndo()` を実行
- **削除フロー**: Gateway `destroy()` は `Observable<DeletionUndoResponse>` を返す。UseCase の success で `undo` を OutputPort に渡し、Presenter で `UndoToastService.showWithUndo(..., onRestored: () => view.load?.())` を呼ぶ
- 対応済み: **Farms**（一覧・詳細）, **Fertilizes**（一覧）。今後追加するマスタ（Crops, Pests 等）の削除も同パターンで Undo 対応する

---

## 6. 共通実装パターン（参照）

- **Gateway**: `MastersClientService` の `get/post/patch/delete` を使用。パスは `/farms`, `/crops` など（先頭スラッシュ、`/api/v1/masters` は client 側で付与済み）
- **削除**: `destroy()` は `Observable<DeletionUndoResponse>` を返し、成功時に Undo トーストを表示
- **UseCase**: 既存の farms / fertilizes の create, update, delete, load-detail, load-for-edit を参照
- **Presenter**: 既存の farm-create, farm-edit, fertilize-list 等を参照。削除成功時に `dto.undo` があれば `UndoToastService.showWithUndo(..., onRestored: () => this.view?.load?.())`
- **ルート**: `app.routes.ts` に `path: 'pests/new'`, `pests/:id`, `pests/:id/edit` などを追加
- **一覧画面**: 各マスタ一覧に「新規作成」リンクと「編集」「削除」ボタン/リンクを追加
