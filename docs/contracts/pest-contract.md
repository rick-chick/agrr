# 契約: 病害虫（Pest）

マスタAPIの病害虫CRUD。フロント UseCase とサーバー API の契約。

## 1. 機能名・スコープ

- **機能**: 病害虫の一覧・詳細・作成・更新・削除
- **スコープ**: `/api/v1/masters/pests`。認証は API キーまたはセッション。

## 2. フロント UseCase 一覧

| UseCase 名 | トリガー（ユーザー操作） | Input DTO |
|------------|--------------------------|-----------|
| LoadPestListUseCase | 病害虫一覧画面の初期表示 | （なし） |
| LoadPestDetailUseCase | 病害虫詳細画面の初期表示 | LoadPestDetailInputDto |
| LoadPestForEditUseCase | 病害虫編集画面の初期表示 | LoadPestForEditInputDto |
| CreatePestUseCase | 病害虫新規作成フォームの送信 | CreatePestInputDto |
| UpdatePestUseCase | 病害虫編集フォームの送信 | UpdatePestInputDto |
| DeletePestUseCase | 病害虫削除の実行 | DeletePestInputDto |

### 2.1 Payload（Create/Update）

- **Payload**: `{ name: string; name_scientific?: string | null; family?: string | null; order?: string | null; description?: string | null; occurrence_season?: string | null; region?: string | null }`
- **Delete 成功 Output**: `{ undo?: DeletionUndoResponse }`

## 3. API 一覧

| メソッド | パス | 説明 |
|----------|------|------|
| GET | /api/v1/masters/pests | 病害虫一覧 |
| GET | /api/v1/masters/pests/:id | 病害虫詳細 |
| POST | /api/v1/masters/pests | 病害虫作成 |
| PATCH | /api/v1/masters/pests/:id | 病害虫更新 |
| DELETE | /api/v1/masters/pests/:id | 病害虫削除（Undo 用 JSON） |

### 3.1 GET /api/v1/masters/pests

- **Response** (200): `Pest[]`
- **Error** (401): `{ error: string }`

### 3.2 GET /api/v1/masters/pests/:id

- **Request**: Params: `id` (path)
- **Response** (200): `Pest`
- **Error** (403/404): `{ error: string }`

### 3.3 POST /api/v1/masters/pests

- **Request**: Body: `{ pest: { name: string; name_scientific?, family?, order?, description?, occurrence_season?, region? } }`
- **Response** (201): `Pest`
- **Error** (422): `{ errors: string[] }`

### 3.4 PATCH /api/v1/masters/pests/:id

- **Request**: Body: `{ pest: { name?, name_scientific?, family?, order?, description?, occurrence_season?, region? } }`
- **Response** (200): `Pest`
- **Error** (403/404/422): `{ error: string }` または `{ errors: string[] }`

### 3.5 DELETE /api/v1/masters/pests/:id

- **Response** (200): `DeletionUndoResponse`
- **Error** (403/404/422): `{ error: string }`

## 4. フロント UseCase ↔ API マッピング

| フロント UseCase | 呼び出す API（順序） |
|------------------|----------------------|
| LoadPestListUseCase | `GET /api/v1/masters/pests` |
| LoadPestDetailUseCase | `GET /api/v1/masters/pests/:id` |
| LoadPestForEditUseCase | `GET /api/v1/masters/pests/:id` |
| CreatePestUseCase | `POST /api/v1/masters/pests` |
| UpdatePestUseCase | `PATCH /api/v1/masters/pests/:id` |
| DeletePestUseCase | `DELETE /api/v1/masters/pests/:id` |

## 5. 共有 DTO / 型定義

### TypeScript

- **Pest**: `frontend/src/app/domain/pests/pest.ts`
- **DeletionUndoResponse**: `frontend/src/app/domain/shared/deletion-undo-response.ts`

### Ruby

- strong params: `pest: { name, name_scientific, family, order, description, occurrence_season, region }`

## 6. 実装チェックリスト

- [ ] フロント: PestGateway のメソッドが契約の API と一致
- [ ] フロント: レスポンス型が契約の Response スキーマと一致
- [ ] サーバー: ルート・Controller が契約のパス・メソッドと一致
- [ ] サーバー: レスポンス JSON が契約の Response スキーマと一致
- [ ] エラー形式が契約と一致
- [ ] 削除は 200 + DeletionUndoResponse
