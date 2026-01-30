# Rails HTML Clean Architecture 化 - 残り確認メモ

## 実施した修正（本確認時）

1. **CropsController#show**  
   `render plain: 'success'` をやめ、`CropDetailInteractor` + `CropDetailHtmlPresenter` に変更。  
   `PolicyPermissionDenied` / `StandardError` の rescue を追加。

2. **FertilizesController**  
   - create/update の DTO を `{ fertilize: fertilize_params.to_h.symbolize_keys }` で組み立て（strong params 準拠）。
   - create/update に `rescue StandardError` を追加し、`render :new` / `render :edit` + `flash.now[:alert]` でフォーム再表示。

3. **FieldsController**  
   `set_farm` 内の `FarmPolicy.find_owned!` の引数を  
   `(Farm, current_user, params[:farm_id])` に修正。

4. **CropsController#destroy**  
   `respond_to` を追加。  
   - `format.html`: 既存どおり Interactor + CropDestroyHtmlPresenter。  
   - `format.json`: `schedule_deletion_with_undo` で undo 用 JSON（undo_token 等）を返却。

## 現状の移行状況

| コントローラ | index | show | create | update | destroy | 備考 |
|-------------|-------|------|--------|--------|---------|------|
| FarmsController | Interactor+Presenter | 同左 | 同左 | 同左 | HTML + JSON 分岐 | 完了 |
| FertilizesController | Policy 直接 | 同左 | Interactor+Presenter | 同左 | Interactor+Presenter | index/show は未移行 |
| CropsController | Interactor+Presenter | Interactor+Presenter | 同左 | 同左 | HTML + JSON 分岐 | 完了 |
| PestsController | Interactor+Presenter | 同左 | 同左 | 同左 | 同左 | create/update は raw params のまま |
| PesticidesController | Interactor+Presenter | 同左 | 同左 | 同左 | 同左 | 同左 |
| AgriculturalTasksController | AR 直接 | Interactor+Presenter | 同左 | 同左 | 同左 | index は未移行 |
| FieldsController | Interactor+Presenter | 同左 | 同左 | 同左 | HTML+JSON | 完了 |
| InteractionRulesController | Interactor+Presenter | 同左 | 同左 | 同左 | 同左 | 完了 |

## 任意で対応するとよい点

- **FertilizesController**  
  index: `FertilizeListInteractor` + `FertilizeListHtmlPresenter` に寄せる。  
  show: `FertilizeDetailInteractor` + `FertilizeDetailHtmlPresenter` に寄せる。
- **AgriculturalTasksController**  
  index: 現状のフィルタ・スコープを維持しつつ、ListInteractor に寄せるかどうか検討。
- **PestsController**  
  create/update の DTO を `pest_params.to_h.symbolize_keys` から組み立て、create/update に `rescue StandardError` で `render :new` / `:edit` を追加。
- **InteractionRulesController**  
  create/update の rescue で `flash.now[:alert] = e.message` を設定し、エラー内容を表示。

## テスト確認で実施した修正

1. **PestDetailHtmlPresenter**: `to_model` 廃止。Interactor から `pest_model` を DTO で渡し、Presenter は `pest_detail_dto.pest_model` を使用。
2. **PestsController**: `set_pest` に `:update`, `:destroy` を追加。`destroy` に `respond_to`（format.json で schedule_deletion_with_undo）を追加。`pest_params` に管理者用 `:pest_id` を追加。
3. **PestsControllerTest**: `includes HtmlCrudResponder` を `does not include HtmlCrudResponder (Clean Architecture)` に変更。

## テスト結果（要約）

- **PestsController**: 92 runs, 23 failures, 6 errors（crop_ids の Interactor 対応・::Pest 参照・Presenter 用 public メソッド対応済み。「ユーザー害虫は参照作物と関連付けできない」はパス。残りは reference pest 系・destroy 期待差など）。
- **InteractionRulesController**: 14 runs, 5 failures（Create のリダイレクト先を show に変更済み。index の Entity 対応済み。残りは region 更新等の期待差）。
- **FertilizesController / AgriculturalTasksController**: 個別実行で要確認。

## 実施した修正（PestsController / InteractionRule）

1. **PestCreateInputDto / PestUpdateInputDto**: `crop_ids` を追加。Controller から `params[:crop_ids]` を渡し、Interactor 内で `PestCropAssociationService.associate_crops` / `update_crop_associations` を実行。
2. **PestCreateInteractor / PestUpdateInteractor**: `::Pest` を明示（`Domain::Pest` モジュールと混同しないよう）。create 成功後に crop_ids があれば関連付け。
3. **PestsController**: Presenter の on_failure から呼ばれるため `render_form`, `normalize_crop_ids_for`, `prepare_crop_selection_for` を public に変更。
4. **InteractionRuleCreateHtmlPresenter**: 成功時のリダイレクト先を `interaction_rule_path(rule.id)` に変更。
5. **interaction_rules/index.html.erb**: `@interaction_rules`（Entity の配列）用に `dom_id(rule)` を `interaction_rule_<%= rule.id %>`、path を `interaction_rule_path(rule.id)` に変更。

## テスト

- `test/controllers/crops_controller_test.rb` の destroy JSON 関連は実施済みでパス。
- 全体テストは npm 権限で失敗する環境の場合は、対象コントローラのみ実行するか、Docker 等で実行して確認すること。
