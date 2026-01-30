# 契約: 農薬（Pesticide）

マスタAPIの農薬CRUD。フロント UseCase とサーバー API の契約。

## 1. 機能名・スコープ

- **機能**: 農薬の一覧・詳細・作成・更新・削除
- **スコープ**: `/api/v1/masters/pesticides`。認証は API キーまたはセッション。

## 2. フロント UseCase 一覧

| UseCase 名 | トリガー（ユーザー操作） | Input DTO |
|------------|--------------------------|-----------|
| LoadPesticideListUseCase | 農薬一覧画面の初期表示 | （なし） |
| LoadPesticideDetailUseCase | 農薬詳細画面の初期表示 | LoadPesticideDetailInputDto |
| LoadPesticideForEditUseCase | 農薬編集画面の初期表示 | LoadPesticideForEditInputDto |
| CreatePesticideUseCase | 農薬新規作成フォームの送信 | CreatePesticideInputDto |
| UpdatePesticideUseCase | 農薬編集フォームの送信 | UpdatePesticideInputDto |
| DeletePesticideUseCase | 農薬削除の実行 | DeletePesticideInputDto |

### 2.1 Payload（Create/Update）

- **Payload**: `{ name: string; active_ingredient?: string | null; description?: string | null; crop_id?: number | null; pest_id?: number | null; region?: string | null }`
- **Delete 成功 Output**: `{ undo?: DeletionUndoResponse }`

## 3. API 一覧

| メソッド | パス | 説明 |
|----------|------|------|
| GET | /api/v1/masters/pesticides | 農薬一覧 |
| GET | /api/v1/masters/pesticides/:id | 農薬詳細 |
| POST | /api/v1/masters/pesticides | 農薬作成 |
| PATCH | /api/v1/masters/pesticides/:id | 農薬更新 |
| DELETE | /api/v1/masters/pesticides/:id | 農薬削除（Undo 用 JSON） |

### 3.1 GET /api/v1/masters/pesticides

- **Response** (200): `Pesticide[]`
- **Error** (401): `{ error: string }`

### 3.2 GET /api/v1/masters/pesticides/:id

- **Request**: Params: `id` (path)
- **Response** (200): `Pesticide`
- **Error** (403/404): `{ error: string }`

### 3.3 POST /api/v1/masters/pesticides

- **Request**: Body: `{ pesticide: { name: string; active_ingredient?, description?, crop_id?, pest_id?, region? } }`
- **Response** (201): `Pesticide`
- **Error** (422): `{ errors: string[] }`

### 3.4 PATCH /api/v1/masters/pesticides/:id

- **Request**: Body: `{ pesticide: { name?, active_ingredient?, description?, crop_id?, pest_id?, region? } }`
- **Response** (200): `Pesticide`
- **Error** (403/404/422): `{ error: string }` または `{ errors: string[] }`

### 3.5 DELETE /api/v1/masters/pesticides/:id

- **Response** (200): `DeletionUndoResponse`
- **Error** (403/404/422): `{ error: string }`

## 4. フロント UseCase ↔ API マッピング

| フロント UseCase | 呼び出す API（順序） |
|------------------|----------------------|
| LoadPesticideListUseCase | `GET /api/v1/masters/pesticides` |
| LoadPesticideDetailUseCase | `GET /api/v1/masters/pesticides/:id` |
| LoadPesticideForEditUseCase | `GET /api/v1/masters/pesticides/:id` |
| CreatePesticideUseCase | `POST /api/v1/masters/pesticides` |
| UpdatePesticideUseCase | `PATCH /api/v1/masters/pesticides/:id` |
| DeletePesticideUseCase | `DELETE /api/v1/masters/pesticides/:id` |

## 5. 共有 DTO / 型定義

### TypeScript

- **Pesticide**: `frontend/src/app/domain/pesticides/pesticide.ts`
- **DeletionUndoResponse**: `frontend/src/app/domain/shared/deletion-undo-response.ts`

### Ruby

- strong params: `pesticide: { name, active_ingredient, description, crop_id, pest_id, region }`

## 6. 実装チェックリスト

- [ ] フロント: PesticideGateway のメソッドが契約の API と一致
- [ ] フロント: レスポンス型が契約の Response スキーマと一致
- [ ] サーバー: ルート・Controller が契約のパス・メソッドと一致
- [ ] サーバー: レスポンス JSON が契約の Response スキーマと一致
- [ ] エラー形式が契約と一致
- [ ] 削除は 200 + DeletionUndoResponse
