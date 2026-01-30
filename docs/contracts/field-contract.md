# 契約: ほ場（Field）

マスタAPIのほ場CRUD。農場に紐づくサブリソース。フロント UseCase とサーバー API の契約。

## 1. 機能名・スコープ

- **機能**: ほ場の一覧（農場単位）・詳細・作成・更新・削除
- **スコープ**: `/api/v1/masters/farms/:farm_id/fields`（一覧・作成）、`/api/v1/masters/fields/:id`（詳細・更新・削除）。認証は API キーまたはセッション。

## 2. フロント UseCase 一覧

| UseCase 名 | トリガー（ユーザー操作） | Input DTO |
|------------|--------------------------|-----------|
| LoadFarmDetailUseCase | 農場詳細画面の初期表示（ほ場一覧を含む） | LoadFarmDetailInputDto |
| CreateFieldUseCase | 農場詳細画面で「ほ場を追加」実行 | CreateFieldInputDto |
| UpdateFieldUseCase | 農場詳細画面でほ場の編集実行 | UpdateFieldInputDto |
| DeleteFieldUseCase | 農場詳細画面でほ場の削除実行 | DeleteFieldInputDto |

### 2.1 CreateFieldUseCase / UpdateFieldUseCase

- **Create Input DTO**: `{ farmId: number; payload: { name: string; area?: number | null; daily_fixed_cost?: number | null; region?: string | null } }`
- **Update Input DTO**: `{ fieldId: number; payload: FieldCreatePayload }`
- **Delete 成功 Output**: `{ undo?: DeletionUndoResponse; farmId: number }`（Presenter が Undo トースト表示後、farmId で一覧再取得）

## 3. API 一覧

| メソッド | パス | 説明 |
|----------|------|------|
| GET | /api/v1/masters/farms/:farm_id/fields | 農場に属するほ場一覧 |
| GET | /api/v1/masters/fields/:id | ほ場詳細 |
| POST | /api/v1/masters/farms/:farm_id/fields | ほ場作成 |
| PATCH | /api/v1/masters/fields/:id | ほ場更新 |
| DELETE | /api/v1/masters/fields/:id | ほ場削除（Undo 用 JSON） |

### 3.1 GET /api/v1/masters/farms/:farm_id/fields

- **Request**: Params: `farm_id` (path)
- **Response** (200): `Field[]`
- **Error** (404): `{ error: string }`（農場が見つからない）

### 3.2 GET /api/v1/masters/fields/:id

- **Request**: Params: `id` (path)
- **Response** (200): `Field`
- **Error** (404): `{ error: string }`

### 3.3 POST /api/v1/masters/farms/:farm_id/fields

- **Request**: Params: `farm_id` (path). Body: `{ field: { name: string; area?: number; daily_fixed_cost?: number; region?: string } }`
- **Response** (201): `Field`
- **Error** (404/422): `{ error: string }` または `{ errors: string[] }`

### 3.4 PATCH /api/v1/masters/fields/:id

- **Request**: Params: `id` (path). Body: `{ field: { name?, area?, daily_fixed_cost?, region? } }`
- **Response** (200): `Field`
- **Error** (404/422): `{ error: string }` または `{ errors: string[] }`

### 3.5 DELETE /api/v1/masters/fields/:id

- **Request**: Params: `id` (path)
- **Response** (200): `DeletionUndoResponse`
- **Error** (404/422): `{ error: string }`

## 4. フロント UseCase ↔ API マッピング

| フロント UseCase | 呼び出す API（順序） |
|------------------|----------------------|
| LoadFarmDetailUseCase | `GET /api/v1/masters/farms/:id`, `GET /api/v1/masters/farms/:farm_id/fields`（forkJoin） |
| CreateFieldUseCase | `POST /api/v1/masters/farms/:farm_id/fields` |
| UpdateFieldUseCase | `PATCH /api/v1/masters/fields/:id` |
| DeleteFieldUseCase | `DELETE /api/v1/masters/fields/:id` |

## 5. 共有 DTO / 型定義

### TypeScript

- **Field**: `frontend/src/app/domain/farms/field.ts`
- **FieldCreatePayload**: `frontend/src/app/usecase/farms/farm-gateway.ts`（createField/updateField の payload）
- **DeletionUndoResponse**: `frontend/src/app/domain/shared/deletion-undo-response.ts`

### Ruby

- strong params: `field: { name, area, daily_fixed_cost, region }`
- 作成は `farms/:farm_id/fields`、更新・削除は `fields/:id`

## 6. 実装チェックリスト

- [ ] フロント: FarmGateway の createField / updateField / destroyField が契約の API と一致
- [ ] フロント: レスポンス型が契約の Response スキーマと一致
- [ ] サーバー: ルート・Controller が契約のパス・メソッドと一致
- [ ] サーバー: レスポンス JSON が契約の Response スキーマと一致
- [ ] エラー形式が契約と一致
- [ ] 削除は 200 + DeletionUndoResponse
