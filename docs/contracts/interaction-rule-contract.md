# 契約: 相互作用ルール（Interaction Rule）

マスタAPIの相互作用ルールCRUD。フロント UseCase とサーバー API の契約。

## 1. 機能名・スコープ

- **機能**: 相互作用ルールの一覧・詳細・作成・更新・削除
- **スコープ**: `/api/v1/masters/interaction_rules`。認証は API キーまたはセッション。

## 2. フロント UseCase 一覧

| UseCase 名 | トリガー（ユーザー操作） | Input DTO |
|------------|--------------------------|-----------|
| LoadInteractionRuleListUseCase | 相互作用ルール一覧画面の初期表示 | （なし） |
| LoadInteractionRuleDetailUseCase | 相互作用ルール詳細画面の初期表示 | LoadInteractionRuleDetailInputDto |
| LoadInteractionRuleForEditUseCase | 相互作用ルール編集画面の初期表示 | LoadInteractionRuleForEditInputDto |
| CreateInteractionRuleUseCase | 相互作用ルール新規作成フォームの送信 | CreateInteractionRuleInputDto |
| UpdateInteractionRuleUseCase | 相互作用ルール編集フォームの送信 | UpdateInteractionRuleInputDto |
| DeleteInteractionRuleUseCase | 相互作用ルール削除の実行 | DeleteInteractionRuleInputDto |

### 2.1 Payload（Create/Update）

- **Payload**: `{ rule_type?: string | null; source_group?: string | null; target_group?: string | null; impact_ratio?: number | null; is_directional?: boolean | null; description?: string | null; region?: string | null }`
- **Delete 成功 Output**: `{ undo?: DeletionUndoResponse }`

## 3. API 一覧

| メソッド | パス | 説明 |
|----------|------|------|
| GET | /api/v1/masters/interaction_rules | 相互作用ルール一覧 |
| GET | /api/v1/masters/interaction_rules/:id | 相互作用ルール詳細 |
| POST | /api/v1/masters/interaction_rules | 相互作用ルール作成 |
| PATCH | /api/v1/masters/interaction_rules/:id | 相互作用ルール更新 |
| DELETE | /api/v1/masters/interaction_rules/:id | 相互作用ルール削除（Undo 用 JSON） |

### 3.1 GET /api/v1/masters/interaction_rules

- **Response** (200): `InteractionRule[]`
- **Error** (401): `{ error: string }`

### 3.2 GET /api/v1/masters/interaction_rules/:id

- **Request**: Params: `id` (path)
- **Response** (200): `InteractionRule`
- **Error** (403/404): `{ error: string }`

### 3.3 POST /api/v1/masters/interaction_rules

- **Request**: Body: `{ interaction_rule: { rule_type?, source_group?, target_group?, impact_ratio?, is_directional?, description?, region? } }`
- **Response** (201): `InteractionRule`
- **Error** (422): `{ errors: string[] }`

### 3.4 PATCH /api/v1/masters/interaction_rules/:id

- **Request**: Body: `{ interaction_rule: { rule_type?, source_group?, target_group?, impact_ratio?, is_directional?, description?, region? } }`
- **Response** (200): `InteractionRule`
- **Error** (403/404/422): `{ error: string }` または `{ errors: string[] }`

### 3.5 DELETE /api/v1/masters/interaction_rules/:id

- **Response** (200): `DeletionUndoResponse`
- **Error** (403/404/422): `{ error: string }`

## 4. フロント UseCase ↔ API マッピング

| フロント UseCase | 呼び出す API（順序） |
|------------------|----------------------|
| LoadInteractionRuleListUseCase | `GET /api/v1/masters/interaction_rules` |
| LoadInteractionRuleDetailUseCase | `GET /api/v1/masters/interaction_rules/:id` |
| LoadInteractionRuleForEditUseCase | `GET /api/v1/masters/interaction_rules/:id` |
| CreateInteractionRuleUseCase | `POST /api/v1/masters/interaction_rules` |
| UpdateInteractionRuleUseCase | `PATCH /api/v1/masters/interaction_rules/:id` |
| DeleteInteractionRuleUseCase | `DELETE /api/v1/masters/interaction_rules/:id` |

## 5. 共有 DTO / 型定義

### TypeScript

- **InteractionRule**: `frontend/src/app/domain/interaction-rules/interaction-rule.ts`
- **DeletionUndoResponse**: `frontend/src/app/domain/shared/deletion-undo-response.ts`

### Ruby

- strong params: `interaction_rule: { rule_type, source_group, target_group, impact_ratio, is_directional, description, region }`

## 6. 実装チェックリスト

- [ ] フロント: InteractionRuleGateway のメソッドが契約の API と一致
- [ ] フロント: レスポンス型が契約の Response スキーマと一致
- [ ] サーバー: ルート・Controller が契約のパス・メソッドと一致
- [ ] サーバー: レスポンス JSON が契約の Response スキーマと一致
- [ ] エラー形式が契約と一致
- [ ] 削除は 200 + DeletionUndoResponse
