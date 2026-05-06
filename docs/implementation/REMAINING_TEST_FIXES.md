# Rails テスト状況・回帰用トラッカー（任意）

> **履歴**: 2026-01-31 時点に本ファイルに列挙されていた失敗・エラーは、現行スイートでは解消済みです。下記「過去スナップショット」に当時のメモを保管しています。

**目的**: フル Rails テストの現状を短く記録し、将来の回帰発生時にここへ追記できるようにする（必須の運用ドキュメントではない）。

最終更新: 2026-03-25

---

## テストの実行方法（ガード）

フルスイートは次のいずれかを使う（プロジェクト既定・スキル経由）。**`bundle exec rails test` をそのまま単独で回す前提にしない**（環境・パス・並列などのガードがスクリプト側にある）。

- `.cursor/skills/test-common/scripts/run-test-rails.sh`
- `./bin/test`（プロジェクトルートから）

---

## 現状サマリー（2026-03-25）

| 指標 | 値 |
|------|-----|
| runs | 1623 |
| failures | 0 |
| errors | 0 |
| skips | 9 |

取得元: 上記 `run-test-rails.sh` によるフル Rails テスト。

---

## 今後の回帰メモ（追記用）

ここに日付・失敗テスト名・原因メモを箇条書きで足す。

- （なし）

---

<details>
<summary>過去スナップショット（2026-01-31）— 当時の TODO / 失敗一覧（参照用・解消済み）</summary>

以下は **2026-01-31 時点**のメモ。現行ではグリーン（上記サマリー参照）。

## サマリー（当時）

- **現状**: 1305 runs, 約34 failures, 約10 errors, 9 skips（優先度対応後）
- 以下を一つずつ調査・対応する

---

## TODO 一覧（実施順）

### ルーティング

- [x] **optimizing_public_plans_path 未定義**（対応済: routes に追加）  
  影響: PublicPlansControllerTest, PublicPlansFlowTest  
  対応: `config/routes.rb` に `get 'public_plans/optimizing', to: 'public_plans#optimizing', as: 'optimizing_public_plans'` を追加

### Adapter / Gateway

- [x] **CultivationPlanMemoryGatewayTest#test_should_find_crops_by_ids_and_user**（対応済: Gateway で .to_a を返す）

- [x] **FertilizeMemoryGatewayTest**（3 errors）— 解消済み（当時: find_by_id(9999) 期待値、Gateway.create が Policy 経由でない 等）

### Controller 単体

- [x] **AuthTestControllerTest**（2 failures）— 解消済み（当時: redirect 先 return_to / test.host の不一致）

- [x] **Api::V1::Masters::BaseControllerTest#test_should_reject_request_without_API_key**— 解消済み（当時: API key メッセージとログイン案内の期待差）

- [x] **PesticidesControllerTest**（複数）— 解消済み（当時: Entity/Policy/JSON vs redirect 等）

- [x] **Api::V1::Masters::FarmsControllerTest**（当時別ファイル名の統合テスト）— 解消済み

- [x] **AgriculturalTasksControllerTest**（大半対応済、残り参照フラグ関連も含め解消）

- [x] **CropsControllerTest**（複数）— 解消済み

- [x] **FertilizesControllerTest**（複数）— 解消済み

### Integration / API

- [x] **PestCropAssociationTest#test_should_complete_full_workflow**— 解消済み

- [x] **PublicPlansControllerTest**（errors）— 解消済み

- [x] **PublicPlansFlowTest**（error）— 解消済み

- [x] **Api::V1::PublicPlans::CultivationPlansControllerTest**（error）— 解消済み

- [x] **Api::V1::PublicPlans::WizardControllerTest**（failure）— 解消済み

- [x] **Api::V1::Masters (crops, fertilizes, pests, farms)**— 解消済み

### Job / Service / Domain

- [x] **PlanFinalizeJobTest#test_finalizes_plan_by_setting_status_completed_and_broadcasting_completed_phase**— 解消済み

- [x] **Domain::CultivationPlan::CultivationPlanCreateInteractorTest**— 解消済み

- [x] **AgrrServiceTest**— 解消済み

---

## 優先度の目安（当時）

1. **ルート追加** (optimizing_public_plans_path) → 複数テストに波及
2. **AgriculturalTasksController** の redirect に id を渡す → 多数の失敗解消
3. **PesticidesController** の index/Presenter/undo 仕様の整理
4. 上記以外の Controller / Integration / Job の個別合わせ

</details>
