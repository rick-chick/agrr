# Feature Contract Template

## 概要

このテンプレートは、Angular フロントエンドと agrr-server（Rust API）間の API 契約を定義するための標準フォーマットです。Contract-First 開発により、並列開発を可能にします。

## テンプレート構造

### 1. 契約ヘッダー

```markdown
# Feature Contract: [機能名]

**作成日**: [YYYY-MM-DD]
**作成者**: [作成者名]
**機能概要**: [機能の簡単な説明]
**ステータス**: [draft | review | approved | implemented]

## ビジネス要件

[機能の目的、ユーザーストーリー、受け入れ条件]

## 技術要件

[非機能要件、パフォーマンス要件、セキュリティ要件]
```

### 2. Use Case定義

```markdown
## Use Case: [Use Case名]

### 概要
[Use Caseの目的と範囲]

### アクター
- **Primary Actor**: [主要アクター]
- **Supporting Actors**: [補助アクター]

### 事前条件 (Pre-conditions)
- [実行前の必須条件]

### 基本フロー (Basic Flow)
1. [ステップ1]
2. [ステップ2]
3. [ステップ3]

### 代替フロー (Alternative Flows)
- **Alt-1**: [条件] -> [代替処理]

### 例外フロー (Exception Flows)
- **Exc-1**: [エラー条件] -> [エラー処理]

### 事後条件 (Post-conditions)
- [実行後の結果状態]
```

### 3. API仕様

```markdown
## API Specification

### Endpoint: [HTTPメソッド] [パス]

**説明**: [エンドポイントの目的]

#### Request

**Headers**:
```
Content-Type: application/json
Authorization: Bearer [token]
```

**Path Parameters**:
| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| id | integer | true | [パラメータ説明] |

**Query Parameters**:
| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| page | integer | false | 1 | [パラメータ説明] |

**Request Body**:
```json
{
  "type": "object",
  "properties": {
    "name": {
      "type": "string",
      "description": "項目名",
      "maxLength": 100
    },
    "description": {
      "type": "string",
      "description": "説明",
      "maxLength": 500
    }
  },
  "required": ["name"]
}
```

#### Response

**Success Response (200)**:
```json
{
  "type": "object",
  "properties": {
    "id": {
      "type": "integer",
      "description": "作成されたリソースID"
    },
    "name": {
      "type": "string",
      "description": "項目名"
    },
    "created_at": {
      "type": "string",
      "format": "date-time",
      "description": "作成日時"
    }
  }
}
```

**Error Responses**:

**400 Bad Request**:
```json
{
  "type": "object",
  "properties": {
    "error": {
      "type": "string",
      "description": "エラーメッセージ"
    },
    "details": {
      "type": "object",
      "description": "フィールド別エラー詳細"
    }
  }
}
```

**401 Unauthorized**:
```json
{
  "error": "Authentication required"
}
```

**403 Forbidden**:
```json
{
  "error": "Insufficient permissions"
}
```

**404 Not Found**:
```json
{
  "error": "Resource not found"
}
```

**422 Unprocessable Entity**:
```json
{
  "type": "object",
  "properties": {
    "error": {
      "type": "string",
      "description": "バリデーションエラー"
    },
    "field_errors": {
      "type": "object",
      "description": "フィールド別バリデーションエラー"
    }
  }
}
```

**500 Internal Server Error**:
```json
{
  "error": "Internal server error"
}
```
```

### 4. データモデル

```markdown
## Data Models

### [モデル名] (Request)
```typescript
// frontend/src/app/domain/[feature]/[model].ts
export interface [Model] {
  id?: number;
  name: string;
  description?: string;
  created_at?: string;
  updated_at?: string;
}
```

### 5. 実装タスク

```markdown
## Implementation Tasks

- [ ] `crates/agrr-domain` に interactor / gateway trait / DTO を実装（`clean-architecture-violation-fix-workflow` + `tdd-on-edit`）
- [ ] `crates/agrr-server` に route / presenter 配線を実装
- [ ] `scripts/run-rust-contract-tests.sh` および該当 `cargo test` が GREEN
```

### 6. レビューポイント

```markdown
## Review Points

### 機能要件
- [ ] ビジネス要件を満たしているか
- [ ] ユーザーストーリーが実現されているか
- [ ] エッジケースが考慮されているか

### 技術要件
- [ ] API仕様がRESTfulか
- [ ] エラーハンドリングが適切か
- [ ] セキュリティ要件を満たしているか
- [ ] パフォーマンス要件を満たしているか

### 設計品質
- [ ] Clean Architecture原則を守っているか
- [ ] 適切な抽象化レベルか
- [ ] 再利用可能性を考慮しているか
- [ ] テスト容易性を考慮しているか
```

### 7. 変更履歴

```markdown
## Change History

| Date | Version | Author | Changes |
|------|---------|--------|---------|
| 2024-01-15 | 1.0 | [作成者] | Initial contract definition |
| 2024-01-16 | 1.1 | [レビュアー] | Added validation rules |
```

## 使用方法

1. このテンプレートをコピーして新しい契約ドキュメントを作成
2. `[機能名]`や`[作成者]`などのプレースホルダーを実際の値に置き換え
3. Use Case、API仕様、データモデルを要件に基づいて詳細化
4. 実装タスクをプロジェクトに合わせて調整
5. レビューポイントを確認しながら契約を洗練

## 注意事項

- APIレスポンスのJSONスキーマは厳密に定義すること
- エラーレスポンスも含めてすべてのHTTPステータスを定義すること
- データモデルの TypeScript 実装例を必ず含めること
- 並列開発を可能にするため、契約は実装前に確定させること