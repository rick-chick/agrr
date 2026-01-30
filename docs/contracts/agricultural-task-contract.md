# 契約: 農作業（Agricultural Task）

マスタAPIの農作業CRUD。フロント UseCase とサーバー API の契約。

## 1. 機能名・スコープ

- **機能**: 農作業の一覧・詳細・作成・更新・削除
- **スコープ**: `/api/v1/masters/agricultural_tasks`。認証は API キーまたはセッション。

## 2. フロント UseCase 一覧

| UseCase 名 | トリガー（ユーザー操作） | Input DTO |
|------------|--------------------------|-----------|
| LoadAgriculturalTaskListUseCase | 農作業一覧画面の初期表示 | （なし） |
| LoadAgriculturalTaskDetailUseCase | 農作業詳細画面の初期表示 | LoadAgriculturalTaskDetailInputDto |
| LoadAgriculturalTaskForEditUseCase | 農作業編集画面の初期表示 | LoadAgriculturalTaskForEditInputDto |
| CreateAgriculturalTaskUseCase | 農作業新規作成フォームの送信 | CreateAgriculturalTaskInputDto |
| UpdateAgriculturalTaskUseCase | 農作業編集フォームの送信 | UpdateAgriculturalTaskInputDto |
| DeleteAgriculturalTaskUseCase | 農作業削除の実行 | DeleteAgriculturalTaskInputDto |

### 2.1 Payload（Create/Update）

- **Payload**: `{ name: string; description?: string | null; time_per_sqm?: number | null; weather_dependency?: string | null; required_tools?: string[] | null; skill_level?: string | null; region?: string | null; task_type?: string | null }`
- **Delete 成功 Output**: `{ undo?: DeletionUndoResponse }`

## 3. API 一覧

| メソッド | パス | 説明 |
|----------|------|------|
| GET | /api/v1/masters/agricultural_tasks | 農作業一覧 |
| GET | /api/v1/masters/agricultural_tasks/:id | 農作業詳細 |
| POST | /api/v1/masters/agricultural_tasks | 農作業作成 |
| PATCH | /api/v1/masters/agricultural_tasks/:id | 農作業更新 |
| DELETE | /api/v1/masters/agricultural_tasks/:id | 農作業削除（Undo 用 JSON） |

### 3.1 GET /api/v1/masters/agricultural_tasks

- **Response** (200): `AgriculturalTask[]`
- **Error** (401): `{ error: string }`

### 3.2 GET /api/v1/masters/agricultural_tasks/:id

- **Request**: Params: `id` (path)
- **Response** (200): `AgriculturalTask`
- **Error** (403/404): `{ error: string }`

### 3.3 POST /api/v1/masters/agricultural_tasks

- **Request**: Body: `{ agricultural_task: { name: string; description?, time_per_sqm?, weather_dependency?, required_tools?, skill_level?, region?, task_type? } }`
- **Response** (201): `AgriculturalTask`
- **Error** (422): `{ errors: string[] }`

### 3.4 PATCH /api/v1/masters/agricultural_tasks/:id

- **Request**: Body: `{ agricultural_task: { name?, description?, time_per_sqm?, weather_dependency?, required_tools?, skill_level?, region?, task_type? } }`
- **Response** (200): `AgriculturalTask`
- **Error** (403/404/422): `{ error: string }` または `{ errors: string[] }`

### 3.5 DELETE /api/v1/masters/agricultural_tasks/:id

- **Response** (200): `DeletionUndoResponse`
- **Error** (403/404/422): `{ error: string }`

## 4. フロント UseCase ↔ API マッピング

| フロント UseCase | 呼び出す API（順序） |
|------------------|----------------------|
| LoadAgriculturalTaskListUseCase | `GET /api/v1/masters/agricultural_tasks` |
| LoadAgriculturalTaskDetailUseCase | `GET /api/v1/masters/agricultural_tasks/:id` |
| LoadAgriculturalTaskForEditUseCase | `GET /api/v1/masters/agricultural_tasks/:id` |
| CreateAgriculturalTaskUseCase | `POST /api/v1/masters/agricultural_tasks` |
| UpdateAgriculturalTaskUseCase | `PATCH /api/v1/masters/agricultural_tasks/:id` |
| DeleteAgriculturalTaskUseCase | `DELETE /api/v1/masters/agricultural_tasks/:id` |

## 5. 共有 DTO / 型定義

### TypeScript

- **AgriculturalTask**: `frontend/src/app/domain/agricultural-tasks/agricultural-task.ts`
- **DeletionUndoResponse**: `frontend/src/app/domain/shared/deletion-undo-response.ts`

### Ruby

- strong params: `agricultural_task: { name, description, time_per_sqm, weather_dependency, required_tools, skill_level, region, task_type }`

## 6. 実装チェックリスト

- [ ] フロント: AgriculturalTaskGateway のメソッドが契約の API と一致
- [ ] フロント: レスポンス型が契約の Response スキーマと一致
- [ ] サーバー: ルート・Controller が契約のパス・メソッドと一致
- [ ] サーバー: レスポンス JSON が契約の Response スキーマと一致
- [ ] エラー形式が契約と一致
- [ ] 削除は 200 + DeletionUndoResponse
