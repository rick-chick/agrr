# 契約: 作物ステージ編集（Crop Stage Edit）

作物編集画面内で、生育ステージ（CropStage）とその要件フィールド（温度、積算温度、日照、栄養素）を編集する機能。

## 1. 機能名・スコープ

- **機能**: 作物編集画面で、生育ステージの追加・編集・削除、および各ステージの要件フィールド（temperature_requirement, thermal_requirement, sunshine_requirement, nutrient_requirement）の編集
- **スコープ**: Angular の作物編集画面（`/crops/:id/edit`）内でのステージ編集機能。既存の `LoadCropForEditUseCase` で取得した作物データに含まれる `crop_stages` を編集対象とする。
- **本契約の対象外**: 作物自体の基本情報（name, variety等）の編集は既存の `crop-contract.md` に従う。

## 2. フロント UseCase 一覧

| UseCase 名 | トリガー（ユーザー操作） | Input DTO |
|------------|--------------------------|-----------|
| CreateCropStageUseCase | 「ステージ追加」ボタンクリック | CreateCropStageInputDto |
| UpdateCropStageUseCase | ステージ名・順序の変更 | UpdateCropStageInputDto |
| DeleteCropStageUseCase | 「ステージ削除」ボタンクリック | DeleteCropStageInputDto |
| UpdateTemperatureRequirementUseCase | 温度要件フォームの送信 | UpdateTemperatureRequirementInputDto |
| UpdateThermalRequirementUseCase | 積算温度要件フォームの送信 | UpdateThermalRequirementInputDto |
| UpdateSunshineRequirementUseCase | 日照要件フォームの送信 | UpdateSunshineRequirementInputDto |
| UpdateNutrientRequirementUseCase | 栄養素要件フォームの送信 | UpdateNutrientRequirementInputDto |

### 2.1 CreateCropStageUseCase 詳細

- **Input DTO**: `{ cropId: number; payload: { name: string; order: number } }`
- **Output DTO**: `{ stage: CropStage }`（Presenter に渡すデータ）

### 2.2 UpdateCropStageUseCase 詳細

- **Input DTO**: `{ cropId: number; stageId: number; payload: { name?: string; order?: number } }`
- **Output DTO**: `{ stage: CropStage }`

### 2.3 DeleteCropStageUseCase 詳細

- **Input DTO**: `{ cropId: number; stageId: number }`
- **Output DTO**: `{ success: boolean }`

### 2.4 UpdateTemperatureRequirementUseCase 詳細

- **Input DTO**: `{ cropId: number; stageId: number; payload: { base_temperature?: number; optimal_min?: number; optimal_max?: number; low_stress_threshold?: number; high_stress_threshold?: number; frost_threshold?: number; sterility_risk_threshold?: number; max_temperature?: number } }`
- **Output DTO**: `{ requirement: TemperatureRequirement }`
- **注意**: 要件が存在しない場合は作成、存在する場合は更新

### 2.5 UpdateThermalRequirementUseCase 詳細

- **Input DTO**: `{ cropId: number; stageId: number; payload: { required_gdd?: number } }`
- **Output DTO**: `{ requirement: ThermalRequirement }`
- **注意**: 要件が存在しない場合は作成、存在する場合は更新

### 2.6 UpdateSunshineRequirementUseCase 詳細

- **Input DTO**: `{ cropId: number; stageId: number; payload: { minimum_sunshine_hours?: number; target_sunshine_hours?: number } }`
- **Output DTO**: `{ requirement: SunshineRequirement }`
- **注意**: 要件が存在しない場合は作成、存在する場合は更新

### 2.7 UpdateNutrientRequirementUseCase 詳細

- **Input DTO**: `{ cropId: number; stageId: number; payload: { daily_uptake_n?: number; daily_uptake_p?: number; daily_uptake_k?: number; region?: string } }`
- **Output DTO**: `{ requirement: NutrientRequirement }`
- **注意**: 要件が存在しない場合は作成、存在する場合は更新

## 3. API 一覧

| メソッド | パス | 説明 |
|----------|------|------|
| GET | /api/v1/masters/crops/:crop_id/crop_stages | ステージ一覧取得 |
| GET | /api/v1/masters/crops/:crop_id/crop_stages/:id | ステージ詳細取得 |
| POST | /api/v1/masters/crops/:crop_id/crop_stages | ステージ作成 |
| PATCH | /api/v1/masters/crops/:crop_id/crop_stages/:id | ステージ更新 |
| DELETE | /api/v1/masters/crops/:crop_id/crop_stages/:id | ステージ削除 |
| GET | /api/v1/masters/crops/:crop_id/crop_stages/:crop_stage_id/temperature_requirement | 温度要件取得 |
| POST | /api/v1/masters/crops/:crop_id/crop_stages/:crop_stage_id/temperature_requirement | 温度要件作成 |
| PATCH | /api/v1/masters/crops/:crop_id/crop_stages/:crop_stage_id/temperature_requirement | 温度要件更新 |
| DELETE | /api/v1/masters/crops/:crop_id/crop_stages/:crop_stage_id/temperature_requirement | 温度要件削除 |
| GET | /api/v1/masters/crops/:crop_id/crop_stages/:crop_stage_id/thermal_requirement | 積算温度要件取得 |
| POST | /api/v1/masters/crops/:crop_id/crop_stages/:crop_stage_id/thermal_requirement | 積算温度要件作成 |
| PATCH | /api/v1/masters/crops/:crop_id/crop_stages/:crop_stage_id/thermal_requirement | 積算温度要件更新 |
| DELETE | /api/v1/masters/crops/:crop_id/crop_stages/:crop_stage_id/thermal_requirement | 積算温度要件削除 |
| GET | /api/v1/masters/crops/:crop_id/crop_stages/:crop_stage_id/sunshine_requirement | 日照要件取得 |
| POST | /api/v1/masters/crops/:crop_id/crop_stages/:crop_stage_id/sunshine_requirement | 日照要件作成 |
| PATCH | /api/v1/masters/crops/:crop_id/crop_stages/:crop_stage_id/sunshine_requirement | 日照要件更新 |
| DELETE | /api/v1/masters/crops/:crop_id/crop_stages/:crop_stage_id/sunshine_requirement | 日照要件削除 |
| GET | /api/v1/masters/crops/:crop_id/crop_stages/:crop_stage_id/nutrient_requirement | 栄養素要件取得 |
| POST | /api/v1/masters/crops/:crop_id/crop_stages/:crop_stage_id/nutrient_requirement | 栄養素要件作成 |
| PATCH | /api/v1/masters/crops/:crop_id/crop_stages/:crop_stage_id/nutrient_requirement | 栄養素要件更新 |
| DELETE | /api/v1/masters/crops/:crop_id/crop_stages/:crop_stage_id/nutrient_requirement | 栄養素要件削除 |

### 3.1 POST /api/v1/masters/crops/:crop_id/crop_stages

- **Request**:
  - Params: `crop_id` (path)
  - Body: `{ crop_stage: { name: string; order: number } }`
- **Response** (201):
  - `CropStage`（要件フィールドは含まない）
- **Error** (401/404/422):
  - `{ error: string }` または `{ errors: string[] }`

### 3.2 PATCH /api/v1/masters/crops/:crop_id/crop_stages/:id

- **Request**:
  - Params: `crop_id` (path), `id` (path)
  - Body: `{ crop_stage: { name?: string; order?: number } }`
- **Response** (200):
  - `CropStage`
- **Error** (401/404/422):
  - `{ error: string }` または `{ errors: string[] }`

### 3.3 DELETE /api/v1/masters/crops/:crop_id/crop_stages/:id

- **Request**:
  - Params: `crop_id` (path), `id` (path)
- **Response** (204):
  - ボディなし
- **Error** (401/404/422):
  - `{ error: string }` または `{ errors: string[] }`

### 3.4 POST /api/v1/masters/crops/:crop_id/crop_stages/:crop_stage_id/temperature_requirement

- **Request**:
  - Params: `crop_id` (path), `crop_stage_id` (path)
  - Body: `{ temperature_requirement: { base_temperature?: number; optimal_min?: number; optimal_max?: number; low_stress_threshold?: number; high_stress_threshold?: number; frost_threshold?: number; sterility_risk_threshold?: number; max_temperature?: number } }`
- **Response** (201):
  - `TemperatureRequirement`
- **Error** (401/404/422):
  - `{ error: string }` または `{ errors: string[] }`
- **注意**: 既に存在する場合は 422 を返す

### 3.5 PATCH /api/v1/masters/crops/:crop_id/crop_stages/:crop_stage_id/temperature_requirement

- **Request**:
  - Params: `crop_id` (path), `crop_stage_id` (path)
  - Body: `{ temperature_requirement: { base_temperature?: number; optimal_min?: number; optimal_max?: number; low_stress_threshold?: number; high_stress_threshold?: number; frost_threshold?: number; sterility_risk_threshold?: number; max_temperature?: number } }`
- **Response** (200):
  - `TemperatureRequirement`
- **Error** (401/404/422):
  - `{ error: string }` または `{ errors: string[] }`

### 3.6 POST /api/v1/masters/crops/:crop_id/crop_stages/:crop_stage_id/thermal_requirement

- **Request**:
  - Params: `crop_id` (path), `crop_stage_id` (path)
  - Body: `{ thermal_requirement: { required_gdd?: number } }`
- **Response** (201):
  - `ThermalRequirement`
- **Error** (401/404/422):
  - `{ error: string }` または `{ errors: string[] }`
- **注意**: 既に存在する場合は 422 を返す

### 3.7 PATCH /api/v1/masters/crops/:crop_id/crop_stages/:crop_stage_id/thermal_requirement

- **Request**:
  - Params: `crop_id` (path), `crop_stage_id` (path)
  - Body: `{ thermal_requirement: { required_gdd?: number } }`
- **Response** (200):
  - `ThermalRequirement`
- **Error** (401/404/422):
  - `{ error: string }` または `{ errors: string[] }`

### 3.8 POST /api/v1/masters/crops/:crop_id/crop_stages/:crop_stage_id/sunshine_requirement

- **Request**:
  - Params: `crop_id` (path), `crop_stage_id` (path)
  - Body: `{ sunshine_requirement: { minimum_sunshine_hours?: number; target_sunshine_hours?: number } }`
- **Response** (201):
  - `SunshineRequirement`
- **Error** (401/404/422):
  - `{ error: string }` または `{ errors: string[] }`
- **注意**: 既に存在する場合は 422 を返す

### 3.9 PATCH /api/v1/masters/crops/:crop_id/crop_stages/:crop_stage_id/sunshine_requirement

- **Request**:
  - Params: `crop_id` (path), `crop_stage_id` (path)
  - Body: `{ sunshine_requirement: { minimum_sunshine_hours?: number; target_sunshine_hours?: number } }`
- **Response** (200):
  - `SunshineRequirement`
- **Error** (401/404/422):
  - `{ error: string }` または `{ errors: string[] }`

### 3.10 POST /api/v1/masters/crops/:crop_id/crop_stages/:crop_stage_id/nutrient_requirement

- **Request**:
  - Params: `crop_id` (path), `crop_stage_id` (path)
  - Body: `{ nutrient_requirement: { daily_uptake_n?: number; daily_uptake_p?: number; daily_uptake_k?: number; region?: string } }`
- **Response** (201):
  - `NutrientRequirement`
- **Error** (401/404/422):
  - `{ error: string }` または `{ errors: string[] }`
- **注意**: 既に存在する場合は 422 を返す

### 3.11 PATCH /api/v1/masters/crops/:crop_id/crop_stages/:crop_stage_id/nutrient_requirement

- **Request**:
  - Params: `crop_id` (path), `crop_stage_id` (path)
  - Body: `{ nutrient_requirement: { daily_uptake_n?: number; daily_uptake_p?: number; daily_uptake_k?: number; region?: string } }`
- **Response** (200):
  - `NutrientRequirement`
- **Error** (401/404/422):
  - `{ error: string }` または `{ errors: string[] }`

## 4. フロント UseCase ↔ API マッピング

| フロント UseCase | 呼び出す API（順序） |
|------------------|----------------------|
| CreateCropStageUseCase | `POST /api/v1/masters/crops/:crop_id/crop_stages` |
| UpdateCropStageUseCase | `PATCH /api/v1/masters/crops/:crop_id/crop_stages/:id` |
| DeleteCropStageUseCase | `DELETE /api/v1/masters/crops/:crop_id/crop_stages/:id` |
| UpdateTemperatureRequirementUseCase | `GET /api/v1/masters/crops/:crop_id/crop_stages/:crop_stage_id/temperature_requirement`（存在確認）→ 存在しない場合は `POST`、存在する場合は `PATCH` |
| UpdateThermalRequirementUseCase | `GET /api/v1/masters/crops/:crop_id/crop_stages/:crop_stage_id/thermal_requirement`（存在確認）→ 存在しない場合は `POST`、存在する場合は `PATCH` |
| UpdateSunshineRequirementUseCase | `GET /api/v1/masters/crops/:crop_id/crop_stages/:crop_stage_id/sunshine_requirement`（存在確認）→ 存在しない場合は `POST`、存在する場合は `PATCH` |
| UpdateNutrientRequirementUseCase | `GET /api/v1/masters/crops/:crop_id/crop_stages/:crop_stage_id/nutrient_requirement`（存在確認）→ 存在しない場合は `POST`、存在する場合は `PATCH` |

## 5. 共有 DTO / 型定義

### TypeScript（フロント）

```typescript
// frontend/src/app/domain/crops/crop.ts（既存）
export interface CropStage {
  id: number;
  crop_id: number;
  name: string;
  order: number;
  temperature_requirement?: TemperatureRequirement;
  thermal_requirement?: ThermalRequirement;
  sunshine_requirement?: SunshineRequirement;
  nutrient_requirement?: NutrientRequirement;
}

export interface TemperatureRequirement {
  id: number;
  crop_stage_id: number;
  base_temperature?: number | null;
  optimal_min?: number | null;
  optimal_max?: number | null;
  low_stress_threshold?: number | null;
  high_stress_threshold?: number | null;
  frost_threshold?: number | null;
  sterility_risk_threshold?: number | null;
  max_temperature?: number | null;
}

export interface ThermalRequirement {
  id: number;
  crop_stage_id: number;
  required_gdd?: number | null;
}

export interface SunshineRequirement {
  id: number;
  crop_stage_id: number;
  minimum_sunshine_hours?: number | null;
  target_sunshine_hours?: number | null;
}

export interface NutrientRequirement {
  id: number;
  crop_stage_id: number;
  daily_uptake_n?: number | null;
  daily_uptake_p?: number | null;
  daily_uptake_k?: number | null;
  region?: string | null;
}
```

### Ruby（サーバー）

```ruby
# lib/domain/crop/entities/crop_stage_entity.rb（既存）
Domain::Crop::Entities::CropStageEntity

# app/models/crop_stage.rb（既存）
CropStage
TemperatureRequirement
ThermalRequirement
SunshineRequirement
NutrientRequirement
```

## 6. UI 実装方針

- **ネストしたフォーム**: 作物編集画面内に「生育ステージ」セクションを追加し、各ステージをカード形式で表示
- **ステージ追加**: 「ステージ追加」ボタンで新しいステージフォームを追加（name, order を入力）
- **ステージ編集**: 各ステージカード内で name, order を編集可能
- **ステージ削除**: 各ステージカードに「削除」ボタンを配置
- **要件フィールド編集**: 各ステージカード内に折りたたみ可能なセクションで各要件を編集
  - 温度要件: base_temperature, optimal_min/max, low_stress_threshold, high_stress_threshold, frost_threshold, sterility_risk_threshold, max_temperature
  - 積算温度要件: required_gdd
  - 日照要件: minimum_sunshine_hours, target_sunshine_hours
  - 栄養素要件: daily_uptake_n, daily_uptake_p, daily_uptake_k, region
- **保存タイミング**: 各ステージ・要件の編集は即座に保存（オプション: 一括保存ボタンも検討可能）

## 7. 実装チェックリスト

契約に従った実装時に照合するポイント。

- [ ] フロント: Gateway Interface のメソッドが契約の API と一致
- [ ] フロント: レスポンス型が契約の Response スキーマと一致
- [ ] サーバー: ルート・Controller が契約のパス・メソッドと一致（既存実装を確認）
- [ ] サーバー: レスポンス JSON が契約の Response スキーマと一致
- [ ] エラー形式が契約と一致（`{ error }` または `{ errors }`）
- [ ] 要件フィールドの作成/更新ロジックが正しく実装されている（存在確認 → POST/PATCH の分岐）
- [ ] ステージ削除時に要件フィールドも削除される（サーバー側の dependent: :destroy で自動削除される想定）
- [ ] 作物編集画面でステージ一覧が正しく表示される（既存の LoadCropForEditUseCase で取得した crop_stages を使用）

## 8. 参照

- 既存契約: `docs/contracts/crop-contract.md`（作物CRUD）
- 既存契約: `docs/contracts/crop-update-html-contract.md`（HTMLフォームでのネスト属性）
- API コントローラー: `app/controllers/api/v1/masters/crops/crop_stages_controller.rb`
- API コントローラー: `app/controllers/api/v1/masters/crops/crop_stages/temperature_requirements_controller.rb`
- API コントローラー: `app/controllers/api/v1/masters/crops/crop_stages/thermal_requirements_controller.rb`
- API コントローラー: `app/controllers/api/v1/masters/crops/crop_stages/sunshine_requirements_controller.rb`
- API コントローラー: `app/controllers/api/v1/masters/crops/crop_stages/nutrient_requirements_controller.rb`
- フロントコンポーネント: `frontend/src/app/components/masters/crops/crop-edit.component.ts`
- ドメインモデル: `frontend/src/app/domain/crops/crop.ts`

## 9. OpenAPI 連携

既存の `config/openapi.yml` に CropStage 関連の API が定義されている場合は、本契約の API 仕様と一致していることを確認する。必要に応じて OpenAPI 定義を更新する。
