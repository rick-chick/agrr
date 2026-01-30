# 契約: 肥料（Fertilize）

マスタAPIの肥料CRUD。フロント UseCase とサーバー API の契約。

## 1. 機能名・スコープ

- **機能**: 肥料の一覧・詳細・作成・更新・削除
- **スコープ**: `/api/v1/masters/fertilizes`。認証は API キーまたはセッション。

## 2. フロント UseCase 一覧

| UseCase 名 | トリガー（ユーザー操作） | Input DTO |
|------------|--------------------------|-----------|
| LoadFertilizeListUseCase | 肥料一覧画面の初期表示 | （なし） |
| LoadFertilizeDetailUseCase | 肥料詳細画面の初期表示 | LoadFertilizeDetailInputDto |
| CreateFertilizeUseCase | 肥料新規作成フォームの送信 | CreateFertilizeInputDto |
| UpdateFertilizeUseCase | 肥料編集フォームの送信 | UpdateFertilizeInputDto |
| DeleteFertilizeUseCase | 肥料削除の実行 | DeleteFertilizeInputDto |

### 2.1 CreateFertilizeUseCase / UpdateFertilizeUseCase

- **Payload**: `{ name: string; n?: number | null; p?: number | null; k?: number | null; description?: string | null; package_size?: number | null; region?: string | null }`
- **Delete 成功 Output**: `{ undo?: DeletionUndoResponse }`

## 3. API 一覧

| メソッド | パス | 説明 |
|----------|------|------|
| GET | /api/v1/masters/fertilizes | 肥料一覧 |
| GET | /api/v1/masters/fertilizes/:id | 肥料詳細 |
| POST | /api/v1/masters/fertilizes | 肥料作成 |
| PATCH | /api/v1/masters/fertilizes/:id | 肥料更新 |
| DELETE | /api/v1/masters/fertilizes/:id | 肥料削除（Undo 用 JSON） |

### 3.1 GET /api/v1/masters/fertilizes

- **Response** (200): `Fertilize[]`
- **Error** (401): `{ error: string }`

### 3.2 GET /api/v1/masters/fertilizes/:id

- **Request**: Params: `id` (path)
- **Response** (200): `Fertilize`
- **Error** (404): `{ error: string }`

### 3.3 POST /api/v1/masters/fertilizes

- **Request**: Body: `{ fertilize: { name: string; n?: number; p?: number; k?: number; description?: string; package_size?: number; region?: string } }`
- **Response** (201): `Fertilize`
- **Error** (422): `{ errors: string[] }`

### 3.4 PATCH /api/v1/masters/fertilizes/:id

- **Request**: Body: `{ fertilize: { name?, n?, p?, k?, description?, package_size?, region? } }`
- **Response** (200): `Fertilize`
- **Error** (404/422): `{ error: string }` または `{ errors: string[] }`

### 3.5 DELETE /api/v1/masters/fertilizes/:id

- **Response** (200): `DeletionUndoResponse`
- **Error** (404/422): `{ error: string }`

## 4. フロント UseCase ↔ API マッピング

| フロント UseCase | 呼び出す API（順序） |
|------------------|----------------------|
| LoadFertilizeListUseCase | `GET /api/v1/masters/fertilizes` |
| LoadFertilizeDetailUseCase | `GET /api/v1/masters/fertilizes/:id` |
| CreateFertilizeUseCase | `POST /api/v1/masters/fertilizes` |
| UpdateFertilizeUseCase | `PATCH /api/v1/masters/fertilizes/:id` |
| DeleteFertilizeUseCase | `DELETE /api/v1/masters/fertilizes/:id` |

## 5. 共有 DTO / 型定義

### TypeScript

- **Fertilize**: `frontend/src/app/domain/fertilizes/fertilize.ts`
- **DeletionUndoResponse**: `frontend/src/app/domain/shared/deletion-undo-response.ts`

### Ruby

- strong params: `fertilize: { name, n, p, k, description, package_size, region }`

## 6. 実装チェックリスト

- [ ] フロント: FertilizeGateway のメソッドが契約の API と一致
- [ ] フロント: レスポンス型が契約の Response スキーマと一致
- [ ] サーバー: ルート・Controller が契約のパス・メソッドと一致
- [ ] サーバー: レスポンス JSON が契約の Response スキーマと一致
- [ ] エラー形式が契約と一致
- [ ] 削除は 200 + DeletionUndoResponse
