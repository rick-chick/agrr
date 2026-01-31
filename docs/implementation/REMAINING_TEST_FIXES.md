# 残りのテスト修正タスク一覧（TODO）

最終更新: 2026-01-31

## サマリー

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

- [ ] **FertilizeMemoryGatewayTest**（3 errors）  
  原因: find_by_id(9999) 期待値、Gateway.create が Policy 経由でない  
  対応: テストを現仕様に合わせる

### Controller 単体

- [ ] **AuthTestControllerTest**（2 failures）  
  原因: redirect 先が return_to で localhost:4200/dashboard を期待、実際は test.host/  
  対応: テストの期待を環境に合わせる

- [ ] **Api::V1::Masters::BaseControllerTest#test_should_reject_request_without_API_key**  
  原因: 期待メッセージ "API key is required"、実際 "このリソースにアクセスするにはログインしてください。"  
  対応: 認証順序（API key vs ログイン）に合わせて期待値を変更

- [ ] **PesticidesControllerTest**（複数）  
  - index: 本文に「管理者農薬」「ユーザー農薬」が含まれることを期待 → Entity を返しているため flash で to_model エラー、一覧が空  
  - HtmlCrudResponder 未 include  
  - PolicyPermissionDenied（edit/update の参照農薬）  
  - PesticideApplicationDetail / PesticideUsageConstraint の count 期待  
  - destroy: 2XX JSON を期待、実際は 302 redirect  
  - update 必須項目欠如: 422 を期待、実際は 302  
  - 参照農薬作成 is_reference 期待  
  対応: コントローラ/Presenter の戻り型（Model vs Entity）、undo レスポンス形式、テスト期待値を現仕様に合わせる

- [ ] **ApiCrudResponderTest**（4 failures）  
  原因: FarmsController が ApiCrudResponder を include していない、create/update/destroy のレスポンス形式・ステータスが期待と異なる  
  対応: include 確認、レスポンス形式またはテスト期待値の調整

- [x] **AgriculturalTasksControllerTest**（大半対応済: agricultural_task_path で id 抽出、Entity#to_model、destroy format.json で schedule_deletion_with_undo、HtmlCrudResponder include。残り 2 件は参照フラグ変更時の作物関連付けの期待値）

- [ ] **CropsControllerTest**（複数）  
  原因: HtmlCrudResponder、redirect 先、期待値  
  対応: 同上方針で個別に合わせる

- [ ] **FertilizesControllerTest**（複数）  
  原因: View/Entity、期待値  
  対応: 同上

### Integration / API

- [ ] **PestCropAssociationTest#test_should_complete_full_workflow**  
  原因: 2XX を期待、実際は 302 to /crops  
  対応: リダイレクト前提ならテストを 302 に合わせる

- [ ] **PublicPlansControllerTest**（errors）  
  対応: optimizing_public_plans_path 追加で解消見込み

- [ ] **PublicPlansFlowTest**（error）  
  対応: 同上

- [ ] **Api::V1::PublicPlans::CultivationPlansControllerTest**（error）  
  対応: 要調査

- [ ] **Api::V1::PublicPlans::WizardControllerTest**（failure）  
  対応: 要調査

- [ ] **Api::V1::Masters (crops, fertilizes, pests, farms)**  
  対応: Policy/権限・パラメータに合わせてテスト修正

### Job / Service / Domain

- [ ] **PlanFinalizeJobTest#test_finalizes_plan_by_setting_status_completed_and_broadcasting_completed_phase**  
  原因: 6 jobs enqueued を期待、0 件  
  対応: ジョブの enqueue 条件・スタブを確認

- [ ] **Domain::CultivationPlan::CultivationPlanCreateInteractorTest**  
  対応: 要調査

- [ ] **AgrrServiceTest**  
  対応: 要調査

---

## 優先度の目安

1. **ルート追加** (optimizing_public_plans_path) → 複数テストに波及
2. **AgriculturalTasksController** の redirect に id を渡す → 多数の失敗解消
3. **PesticidesController** の index/Presenter/undo 仕様の整理
4. **ApiCrudResponder / HtmlCrudResponder** の include とレスポンス
5. 上記以外の Controller / Integration / Job の個別合わせ
