# 契約: 栽培計画詳細読み込み（Plan Detail Load）

本ドキュメントは既存実装を契約形式で記述したサンプル。機能追加スキルの出力例として参照する。

## 1. 機能名・スコープ

- **機能**: 栽培計画の詳細画面で、計画サマリと栽培データを表示する
- **スコープ**: LoadPlanDetailUseCase が呼び出す 2 つの API（plans#show, cultivation_plans#data）

## 2. フロント UseCase 一覧

| UseCase 名 | トリガー（ユーザー操作） | Input DTO |
|------------|--------------------------|-----------|
| LoadPlanDetailUseCase | 計画詳細画面の初期表示 | LoadPlanDetailInputDto |

### 2.1 LoadPlanDetailUseCase 詳細

- **Input DTO**: `{ planId: number }`
- **Output DTO** (Presenter に渡す): `{ plan: PlanSummary; planData: CultivationPlanData }`

## 3. API 一覧

| メソッド | パス | 説明 |
|----------|------|------|
| GET | /api/v1/plans/:id | 計画サマリ取得 |
| GET | /api/v1/plans/cultivation_plans/:id/data | 計画の栽培データ取得 |

### 3.1 GET /api/v1/plans/:id

- **Request**:
  - Params: `id` (number, path)
- **Response** (200):
  - `{ id: number; name: string; status?: string | null }`
- **Error** (404): `{ error: string }`

### 3.2 GET /api/v1/plans/cultivation_plans/:id/data

- **Request**:
  - Params: `id` (number, path)
- **Response** (200):
  - CultivationPlanData 型（fields, crops, cultivations 等を含む）
- **Error** (404): `{ error: string }`

## 4. フロント UseCase ↔ API マッピング

| フロント UseCase | 呼び出す API（順序） |
|------------------|----------------------|
| LoadPlanDetailUseCase | `GET /api/v1/plans/:id`, `GET /api/v1/plans/cultivation_plans/:id/data`（forkJoin で並列） |

## 5. 共有 DTO / 型定義

### TypeScript（フロント）

- **PlanSummary**: `frontend/src/app/domain/plans/plan-summary.ts`
- **CultivationPlanData**: `frontend/src/app/domain/plans/cultivation-plan-data.ts`
- **LoadPlanDetailInputDto**: `frontend/src/app/usecase/plans/load-plan-detail.dtos.ts`

### Ruby（サーバー）

- PlansController は Rails MVC パターン。JSON は `serialize_plan` で構築。
- CultivationPlanData は `CultivationPlanApi#data` で返却。

## 6. 実装チェックリスト

- [x] フロント: Gateway Interface のメソッドが契約の API と一致
- [x] フロント: レスポンス型が契約の Response スキーマと一致
- [x] サーバー: ルート・Controller が契約のパス・メソッドと一致
- [x] サーバー: レスポンス JSON が契約の Response スキーマと一致
- [x] エラー形式が契約と一致
