# Feature Contract: Crop Stages Management

**作成日**: 2026-01-31
**作成者**: AI Assistant
**機能概要**: 作物編集画面で生育ステージの追加・一覧・詳細・更新・削除機能をAPIで提供
**ステータス**: draft

## ビジネス要件

作物編集画面で生育ステージを管理するAPIを提供する。
- 生育ステージの一覧取得
- 生育ステージの詳細取得
- 生育ステージの追加
- 生育ステージの更新
- 生育ステージの削除

## 技術要件

- RESTful API設計
- JSONレスポンス
- エラーハンドリング
- 認証必須
- 作物IDによるフィルタリング

## Use Case: 生育ステージ管理

### 概要
作物に紐づく生育ステージのCRUD操作を提供

### アクター
- **Primary Actor**: 認証済みユーザー

### 事前条件 (Pre-conditions)
- ユーザーが認証されている
- 指定された作物が存在し、ユーザーがアクセス権を持つ

### 基本フロー (Basic Flow)
1. ユーザーが作物編集画面にアクセス
2. システムが既存の生育ステージ一覧を表示
3. ユーザーが生育ステージを追加/編集/削除
4. システムがAPI経由で操作を実行
5. 操作結果を画面に反映

### 代替フロー (Alternative Flows)
- **Alt-1**: 作物が存在しない場合 -> 404エラーを返す

### 例外フロー (Exception Flows)
- **Exc-1**: 認証失敗 -> 401エラーを返す
- **Exc-2**: パラメータ不正 -> 400エラーを返す
- **Exc-3**: 権限不足 -> 403エラーを返す

### 事後条件 (Post-conditions)
- データベースが適切に更新される
- クライアントに操作結果が返される

## API Specification

### Endpoint: GET /api/v1/masters/crops/{crop_id}/crop_stages

**説明**: 指定作物の生育ステージ一覧を取得

#### Request

**Headers**:
```
Authorization: Bearer {token}
```

**Path Parameters**:
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| crop_id | integer | true | 作物ID |

#### Response

**Success Response (200)**:
```json
[
  {
    "id": 1,
    "crop_id": 1,
    "name": "種まき",
    "order": 1,
    "created_at": "2026-01-31T00:00:00.000Z",
    "updated_at": "2026-01-31T00:00:00.000Z"
  }
]
```

**Error Responses**:

**401 Unauthorized**:
```json
{
  "error": "Authentication required"
}
```

**404 Not Found**:
```json
{
  "error": "Crop not found"
}
```

### Endpoint: GET /api/v1/masters/crops/{crop_id}/crop_stages/{id}

**説明**: 指定生育ステージの詳細を取得

#### Request

**Headers**:
```
Authorization: Bearer {token}
```

**Path Parameters**:
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| crop_id | integer | true | 作物ID |
| id | integer | true | 生育ステージID |

#### Response

**Success Response (200)**:
```json
{
  "id": 1,
  "crop_id": 1,
  "name": "種まき",
  "order": 1,
  "created_at": "2026-01-31T00:00:00.000Z",
  "updated_at": "2026-01-31T00:00:00.000Z"
}
```

### Endpoint: POST /api/v1/masters/crops/{crop_id}/crop_stages

**説明**: 新しい生育ステージを追加

#### Request

**Headers**:
```
Content-Type: application/json
Authorization: Bearer {token}
```

**Path Parameters**:
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| crop_id | integer | true | 作物ID |

**Request Body**:
```json
{
  "crop_stage": {
    "name": "種まき",
    "order": 1
  }
}
```

#### Response

**Success Response (201)**:
```json
{
  "id": 1,
  "crop_id": 1,
  "name": "種まき",
  "order": 1,
  "created_at": "2026-01-31T00:00:00.000Z",
  "updated_at": "2026-01-31T00:00:00.000Z"
}
```

**422 Unprocessable Entity**:
```json
{
  "errors": ["Name can't be blank"]
}
```

### Endpoint: PATCH /api/v1/masters/crops/{crop_id}/crop_stages/{id}

**説明**: 生育ステージを更新

#### Request

**Headers**:
```
Content-Type: application/json
Authorization: Bearer {token}
```

**Path Parameters**:
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| crop_id | integer | true | 作物ID |
| id | integer | true | 生育ステージID |

**Request Body**:
```json
{
  "crop_stage": {
    "name": "発芽",
    "order": 2
  }
}
```

#### Response

**Success Response (200)**:
```json
{
  "id": 1,
  "crop_id": 1,
  "name": "発芽",
  "order": 2,
  "created_at": "2026-01-31T00:00:00.000Z",
  "updated_at": "2026-01-31T00:00:00.000Z"
}
```

### Endpoint: DELETE /api/v1/masters/crops/{crop_id}/crop_stages/{id}

**説明**: 生育ステージを削除

#### Request

**Headers**:
```
Authorization: Bearer {token}
```

**Path Parameters**:
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| crop_id | integer | true | 作物ID |
| id | integer | true | 生育ステージID |

#### Response

**Success Response (200)**:
```json
{
  "success": true
}
```

## Data Models

### CropStage (Request/Response)
```typescript
// frontend/src/app/domain/crop/entities/crop-stage.entity.ts
export interface CropStage {
  id?: number;
  crop_id: number;
  name: string;
  order: number;
  created_at?: string;
  updated_at?: string;
}
```

```ruby
# lib/domain/crop/entities/crop_stage_entity.rb
module Domain
  module Crop
    module Entities
      class CropStageEntity
        attr_reader :id, :crop_id, :name, :order, :created_at, :updated_at

        def initialize(attributes = {})
          @id = attributes[:id]
          @crop_id = attributes[:crop_id]
          @name = attributes[:name]
          @order = attributes[:order]
          @created_at = attributes[:created_at]
          @updated_at = attributes[:updated_at]
        end
      end
    end
  end
end
```

## Implementation Tasks

### Phase 1: UseCase層実装
- [ ] usecase-serverスキルでRails UseCase層を実装
- [ ] usecase-frontendスキルでAngular UseCase層を実装

### Phase 2: Adapter層実装
- [ ] presenter-serverスキルでRails Presenterを実装
- [ ] gateway-serverスキルでRails Gatewayを実装
- [ ] controller-serverスキルでRails Controllerを実装
- [ ] presenter-frontendスキルでAngular Presenterを実装
- [ ] gateway-frontendスキルでAngular Gatewayを実装
- [ ] controller-frontendスキルでAngular Controllerを実装

### Phase 3: テスト実装
- [ ] Rails UseCaseテストを実装
- [ ] Angular UseCaseテストを実装
- [ ] 統合テストを実装

### Phase 4: 検証
- [ ] API契約通りの動作確認
- [ ] エラーケースの動作確認

## Review Points

### 機能要件
- [ ] ビジネス要件を満たしているか
- [ ] エラーケースが適切に処理されているか

### 技術要件
- [ ] API仕様がRESTfulか
- [ ] エラーハンドリングが適切か
- [ ] 認証・認可が適切か

### 設計品質
- [ ] Clean Architecture原則を守っているか
- [ ] テスト容易性を考慮しているか