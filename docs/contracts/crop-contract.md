# 契約: 作物（Crop）

マスタAPIの作物CRUD。フロント UseCase とサーバー API の契約。

## 1. 機能名・スコープ

- **機能**: 作物の一覧・詳細・作成・更新・削除
- **スコープ**: `/api/v1/masters/crops`。認証は API キーまたはセッション。

## 2. フロント UseCase 一覧

| UseCase 名 | トリガー（ユーザー操作） | Input DTO |
|------------|--------------------------|-----------|
| LoadCropListUseCase | 作物一覧画面の初期表示 | （なし） |
| LoadCropDetailUseCase | 作物詳細画面の初期表示 | LoadCropDetailInputDto |
| LoadCropForEditUseCase | 作物編集画面の初期表示 | LoadCropForEditInputDto |
| CreateCropUseCase | 作物新規作成フォームの送信 | CreateCropInputDto |
| UpdateCropUseCase | 作物編集フォームの送信 | UpdateCropInputDto |
| DeleteCropUseCase | 作物削除の実行 | DeleteCropInputDto |

### 2.1 CreateCropUseCase / UpdateCropUseCase

- **Create Input DTO**: `{ payload: { name: string; variety?: string | null; area_per_unit?: number | null; revenue_per_area?: number | null; region?: string | null; groups?: string[] } }`
- **Update Input DTO**: `{ cropId: number; payload: CropUpdatePayload }`
- **Output DTO** (成功): `{ crop: Crop }`。削除: `{ undo?: DeletionUndoResponse }`

## 3. API 一覧

| メソッド | パス | 説明 |
|----------|------|------|
| GET | /api/v1/masters/crops | 作物一覧 |
| GET | /api/v1/masters/crops/:id | 作物詳細 |
| POST | /api/v1/masters/crops | 作物作成 |
| PATCH | /api/v1/masters/crops/:id | 作物更新 |
| DELETE | /api/v1/masters/crops/:id | 作物削除（Undo 用 JSON） |

### 3.1 GET /api/v1/masters/crops

- **Request**: 認証のみ
- **Response** (200): `Crop[]`
- **Error** (401): `{ error: string }`

### 3.2 GET /api/v1/masters/crops/:id

- **Request**: Params: `id` (path)
- **Response** (200): `Crop`（crop_stages 等を含む場合あり）
- **Error** (403/404): `{ error: string }`

### 3.3 POST /api/v1/masters/crops

- **Request**: Body: `{ crop: { name: string; variety?: string; area_per_unit?: number; revenue_per_area?: number; region?: string; groups?: string[] } }`
- **Response** (201): `Crop`
- **Error** (422): `{ errors: string[] }`

### 3.4 PATCH /api/v1/masters/crops/:id

- **Request**: Body: `{ crop: { name?, variety?, area_per_unit?, revenue_per_area?, region?, groups? } }`
- **Response** (200): `Crop`
- **Error** (403/404/422): `{ error: string }` または `{ errors: string[] }`

### 3.5 DELETE /api/v1/masters/crops/:id

- **Response** (200): `DeletionUndoResponse`
- **Error** (403/404/422): `{ error: string }`

## 4. フロント UseCase ↔ API マッピング

| フロント UseCase | 呼び出す API（順序） |
|------------------|----------------------|
| LoadCropListUseCase | `GET /api/v1/masters/crops` |
| LoadCropDetailUseCase | `GET /api/v1/masters/crops/:id` |
| LoadCropForEditUseCase | `GET /api/v1/masters/crops/:id` |
| CreateCropUseCase | `POST /api/v1/masters/crops` |
| UpdateCropUseCase | `PATCH /api/v1/masters/crops/:id` |
| DeleteCropUseCase | `DELETE /api/v1/masters/crops/:id` |

## 5. 共有 DTO / 型定義

### TypeScript

- **Crop**: `frontend/src/app/domain/crops/crop.ts`
- **DeletionUndoResponse**: `frontend/src/app/domain/shared/deletion-undo-response.ts`

### Ruby

- strong params: `crop: { name, variety, area_per_unit, revenue_per_area, region, groups: [] }`

## 6. 実装チェックリスト

- [ ] フロント: CropGateway のメソッドが契約の API と一致
- [ ] フロント: レスポンス型が契約の Response スキーマと一致
- [ ] サーバー: ルート・Controller が契約のパス・メソッドと一致
- [ ] サーバー: レスポンス JSON が契約の Response スキーマと一致
- [ ] エラー形式が契約と一致
- [ ] 削除は 200 + DeletionUndoResponse
