# 実装評価: 個人計画の新規作成（Private Plan Create）

評価日: 2026-01-31  
対象: 契約 `docs/contracts/private-plan-create-contract.md` に基づく Phase 1〜3 実装

---

## 1. 総合評価

| 観点 | 評価 | 備考 |
|------|------|------|
| 契約との整合性 | △ | API リクエスト形式の不整合あり |
| アーキテクチャ | ◎ | UseCase / Port / Gateway 分離が明確 |
| テスト | ◎ | サーバー・フロントともに UseCase/Presenter/Gateway のテストあり |
| 動作保証 | △ | 未修正の不整合により実機で失敗する可能性 |

**結論**: 設計・レイヤ分離は良好。**2 点の不整合は本評価後に修正済み**（下記 3.1 / 3.2）。

---

## 2. 良い点

### 2.1 契約とアーキテクチャ

- 契約で UseCase ↔ API の対応が明示され、Phase 2/3 の責務が分かれている。
- フロント: `LoadPrivatePlanFarmsUseCase` / `LoadPrivatePlanSelectCropContextUseCase` / `CreatePrivatePlanUseCase` が契約どおり存在。
- サーバー: `CultivationPlanCreator` を再利用し、ジョブチェーン（天気取得→予測→最適化→作業予定→Finalize）が HTML 版と同等。

### 2.2 サーバー実装

- `Api::V1::PlansController#create`: 農場・作物の取得、既存計画チェック、422/404/401 の返却が契約と一致。
- テスト: 正常作成・plan_name 省略・作物未選択・既存計画・農場なし・未認証など網羅されている。
- ルート: `POST /api/v1/plans` が追加済み。

### 2.3 フロント実装

- 計画一覧に「新規計画」リンク（`/plans/new`）が追加されている。
- `/plans/new`（農場選択）→ `/plans/select-crop?farmId=X`（作物選択）→ 作成 → `/plans/:id/optimizing` の流れが実装されている。
- View / Presenter の分離、フォームからの cropIds/planName 取得ロジックは妥当。
- 農場・作物取得に既存 API（`/api/v1/masters/farms`, `/api/v1/masters/crops`）を利用しており、契約の「既存 API を利用」に沿っている。

### 2.4 テスト

- サーバー: `test/controllers/api/v1/plans_controller_test.rb` で create の正常・異常系がカバーされている。
- フロント: UseCase / Presenter / Gateway の spec が用意されている。

---

## 3. 要修正事項

### 3.1 API リクエスト形式の不整合（重要）【対応済み】

**事象**: フロントは **フラットな JSON** を送信しているが、サーバーは **`plan` キーでネストした params** を要求している。

- **フロント**（`private-plan-create-api.gateway.ts`）:
  ```typescript
  const requestBody = {
    farm_id: dto.farmId,
    plan_name: dto.planName,
    crop_ids: dto.cropIds
  };
  this.apiClient.post('/api/v1/plans', requestBody);
  ```
  送信 body: `{ "farm_id": number, "plan_name": string, "crop_ids": number[] }`

- **サーバー**（`app/controllers/api/v1/plans_controller.rb`）:
  ```ruby
  def create_params
    params.require(:plan).permit(:farm_id, :plan_name, crop_ids: [])
  end
  ```
  期待: `params[:plan]` が存在すること（つまり body が `{ "plan": { "farm_id", "plan_name", "crop_ids" } }` であること）。

Rails の JSON リクエストでは body がそのまま `params` にマージされるため、現状のフロント送信だと `params[:plan]` が `nil` となり、`ActionController::ParameterMissing` が発生する。

**対応案（いずれか）**:

- **A) フロントを契約・サーバーに合わせる（推奨）**  
  Gateway で body を `{ plan: { farm_id, plan_name, crop_ids } }` に変更する。  
  契約の「Body: `{ "farm_id": number, ... }`」は「トップレベルで送る」と解釈されていたため、契約の「Request」を「`plan` でラップする」形に更新しておくとよい。

- **B) サーバーを契約のトップレベルに合わせる**  
  `create_params` を `params.permit(:farm_id, :plan_name, crop_ids: [])` に変更し、`params.require(:plan)` をやめる。  
  その場合、Rails のテストの `params: { plan: { ... } }` もトップレベルに合わせて修正する。

### 3.2 フロントで Gateway が provide されていない（重要）【対応済み】

**事象**: `PlanNewComponent` と `PlanSelectCropComponent` の `providers` に `PRIVATE_PLAN_CREATE_GATEWAY` / `PrivatePlanCreateApiGateway` が含まれていない。

- `LoadPrivatePlanFarmsUseCase` と `LoadPrivatePlanSelectCropContextUseCase`、`CreatePrivatePlanUseCase` はすべて `PRIVATE_PLAN_CREATE_GATEWAY` に依存している。
- 両コンポーネントはこれらの UseCase を `providers` で持つが、Gateway を provide していない。
- `PrivatePlanCreateApiGateway` は `providedIn: 'root'` ではないため、どこかで provide されていないと **実行時に DI エラー**（No provider for PRIVATE_PLAN_CREATE_GATEWAY）になる。

**対応**:

- `PlanNewComponent` と `PlanSelectCropComponent` の `providers` に次を追加する。  
  `{ provide: PRIVATE_PLAN_CREATE_GATEWAY, useClass: PrivatePlanCreateApiGateway }`
- または、`PrivatePlanCreateApiGateway` を `providedIn: 'root'` にし、アプリ全体で 1 インスタンスにする（他 Gateway の扱いと合わせて判断）。

---

## 4. 契約チェックリストとの対応

| 項目 | 状態 | 備考 |
|------|------|------|
| Rails: POST /api/v1/plans 追加 | ✅ | 実装済み |
| Rails: farm_id, plan_name, crop_ids で作成・ジョブ | ✅ | 実装済み（params 形式のみ要調整） |
| Angular: 3 UseCase 定義 | ✅ | 実装済み |
| Angular: Gateway に createPlan | ✅ | 実装済み（body 形式要修正） |
| Angular: plan-new / plan-select-crop とルート | ✅ | 実装済み |
| Angular: 計画一覧に「新規計画」 | ✅ | 実装済み |
| Presenter 実装・テスト | ✅ | 実装済み |
| エラー形式 { error } / { errors } | ✅ | サーバーは契約どおり |
| **フロント POST body 形式** | ✅ | Gateway で `plan` でラップするよう修正済み |
| **フロント Gateway の provide** | ✅ | PlanNewComponent / PlanSelectCropComponent に追加済み |

---

## 5. 推奨アクション

1. **必須（対応済み）**
   - **API リクエスト形式**: フロントの `createPlan` で body を `{ plan: { farm_id, plan_name, crop_ids } }` に変更済み。Gateway の spec も更新済み。
   - **DI**: `PlanNewComponent` と `PlanSelectCropComponent` の `providers` に `PRIVATE_PLAN_CREATE_GATEWAY` と `PrivatePlanCreateApiGateway` を追加済み。

2. **推奨**
   - 契約ドキュメントの「7. 実装チェックリスト」の未チェック項目を、上記修正後に完了に更新する。
   - 修正後、ブラウザで「計画一覧 → 新規計画 → 農場選択 → 作物選択 → 作成」の一連フローを実行して 201 と最適化画面への遷移を確認する。

3. **任意**
   - 計画一覧の「新規計画」や説明文を i18n（`nav.plans` 等）に寄せて他画面と表記を統一する。
   - ナビから「新規計画」への案内を追加するかは要件に応じて検討。

---

## 6. 参考: 修正例

### 6.1 Gateway の POST body（3.1 対応）

```typescript
// frontend/src/app/adapters/private-plan-create/private-plan-create-api.gateway.ts
createPlan(dto: CreatePrivatePlanInputDto): Observable<CreatePrivatePlanResponseDto> {
  const requestBody = {
    plan: {
      farm_id: dto.farmId,
      plan_name: dto.planName,
      crop_ids: dto.cropIds
    }
  };
  return this.apiClient.post<CreatePrivatePlanResponseDto>('/api/v1/plans', requestBody);
}
```

### 6.2 PlanNewComponent の providers（3.2 対応）

```typescript
import { PRIVATE_PLAN_CREATE_GATEWAY } from '../../usecase/private-plan-create/private-plan-create-gateway';
import { PrivatePlanCreateApiGateway } from '../../adapters/private-plan-create/private-plan-create-api.gateway';

// providers に追加:
{ provide: PRIVATE_PLAN_CREATE_GATEWAY, useClass: PrivatePlanCreateApiGateway }
```

`PlanSelectCropComponent` も同様に `PRIVATE_PLAN_CREATE_GATEWAY` と `PrivatePlanCreateApiGateway` を追加する。
