# 契約: 農場（Farm）

マスタAPIの農場CRUD。フロント UseCase とサーバー API の契約。

## 1. 機能名・スコープ

- **機能**: 農場の一覧・詳細・作成・更新・削除（ほ場一覧は農場詳細で取得）
- **スコープ**: `/api/v1/masters/farms` および農場詳細内のほ場 API。認証は API キーまたはセッション。

## 2. フロント UseCase 一覧

| UseCase 名 | トリガー（ユーザー操作） | Input DTO |
|------------|--------------------------|-----------|
| LoadFarmListUseCase | 農場一覧画面の初期表示 | （なしまたは空） |
| LoadFarmDetailUseCase | 農場詳細画面の初期表示 | LoadFarmDetailInputDto |
| CreateFarmUseCase | 農場新規作成フォームの送信 | CreateFarmInputDto |
| UpdateFarmUseCase | 農場編集フォームの送信 | UpdateFarmInputDto |
| DeleteFarmUseCase | 農場削除の実行 | DeleteFarmInputDto |

### 2.1 LoadFarmDetailUseCase 詳細

- **Input DTO**: `{ farmId: number }`
- **Output DTO**: `{ farm: Farm; fields: Field[] }`

### 2.2 CreateFarmUseCase / UpdateFarmUseCase

- **Create Input DTO**: `{ payload: { name: string; region: string; latitude: number; longitude: number } }`
- **Update Input DTO**: `{ farmId: number; payload: FarmCreatePayload }`
- **Output DTO**: `{ farm: Farm }` または エラー時 `{ message: string }`

### 2.3 DeleteFarmUseCase

- **Input DTO**: `{ farmId: number }`
- **Output DTO** (成功): `{ undo?: DeletionUndoResponse }`（Presenter が Undo トースト表示）

## 3. API 一覧

| メソッド | パス | 説明 |
|----------|------|------|
| GET | /api/v1/masters/farms | 農場一覧 |
| GET | /api/v1/masters/farms/:id | 農場詳細 |
| POST | /api/v1/masters/farms | 農場作成 |
| PATCH | /api/v1/masters/farms/:id | 農場更新 |
| DELETE | /api/v1/masters/farms/:id | 農場削除（Undo 用 JSON を返す） |

### 3.1 GET /api/v1/masters/farms

- **Request**: Params なし（認証ヘッダーまたは Cookie）
- **Response** (200): `Farm[]`
- **Error** (401): `{ error: string }`

### 3.2 GET /api/v1/masters/farms/:id

- **Request**: Params: `id` (path)
- **Response** (200): `Farm`
- **Error** (404): `{ error: string }`

### 3.3 POST /api/v1/masters/farms

- **Request**: Body: `{ farm: { name: string; region: string; latitude: number; longitude: number } }`
- **Response** (201): `Farm`
- **Error** (422): `{ errors: string[] }`

### 3.4 PATCH /api/v1/masters/farms/:id

- **Request**: Body: `{ farm: { name?: string; region?: string; latitude?: number; longitude?: number } }`
- **Response** (200): `Farm`
- **Error** (404/422): `{ error: string }` または `{ errors: string[] }`

### 3.5 DELETE /api/v1/masters/farms/:id

- **Request**: Params: `id` (path)
- **Response** (200): `DeletionUndoResponse`（undo_token, toast_message, undo_path 等）
- **Error** (404/422): `{ error: string }`

## 4. フロント UseCase ↔ API マッピング

| フロント UseCase | 呼び出す API（順序） |
|------------------|----------------------|
| LoadFarmListUseCase | `GET /api/v1/masters/farms` |
| LoadFarmDetailUseCase | `GET /api/v1/masters/farms/:id`, `GET /api/v1/masters/farms/:id/fields`（forkJoin） |
| CreateFarmUseCase | `POST /api/v1/masters/farms` |
| UpdateFarmUseCase | `PATCH /api/v1/masters/farms/:id` |
| DeleteFarmUseCase | `DELETE /api/v1/masters/farms/:id` |

## 5. 共有 DTO / 型定義

### TypeScript（フロント）

- **Farm**: `frontend/src/app/domain/farms/farm.ts`
- **Field**: `frontend/src/app/domain/farms/field.ts`
- **DeletionUndoResponse**: `frontend/src/app/domain/shared/deletion-undo-response.ts`
- **FarmCreatePayload**: `frontend/src/app/usecase/farms/farm-gateway.ts` 等

### Ruby（サーバー）

- strong params: `farm: { name, latitude, longitude, region }`
- 削除成功時: DeletionUndoFlow により 200 + JSON（undo_token, toast_message, undo_path 等）

## 6. 実装チェックリスト

- [ ] フロント: FarmGateway のメソッドが契約の API と一致
- [ ] フロント: レスポンス型が契約の Response スキーマと一致
- [ ] サーバー: ルート・Controller が契約のパス・メソッドと一致（Clean Architecture 化時は Interactor/Presenter/View）
- [ ] サーバー: レスポンス JSON が契約の Response スキーマと一致
- [ ] エラー形式が契約と一致（`{ error }` または `{ errors }`）
- [ ] 削除は 200 + DeletionUndoResponse（204 ではない）
