# 契約: Crop Update（HTML）— crop_stages_attributes / nutrients の反映

Rails HTML の作物編集（CropsController#update）において、Interactor が Rails のネストした属性（crop_stages_attributes / nutrient_requirement_attributes 等）を再現し、モデルに正しく反映するための契約。

## 1. 機能名・スコープ

- **機能**: 作物編集フォーム（HTML）の送信時に、作物のフラット属性に加え、生育ステージ（crop_stages）およびその配下の nutrient_requirement 等を保存する。
- **スコープ**: CropsController#update → CropUpdateInputDto → CropUpdateInteractor → CropPolicy.apply_update! → Crop#update。API（/api/v1/masters/crops/:id）は本契約の対象外（別契約: crop-contract.md）。
- **本契約の対象外**: 権限拒否時の flash 文言（「権限がありません。」vs「指定された作物が見つかりません。」）、バリデーション失敗時のステータス（422 vs 302）、一覧・表示の fixture/期待値は別途対応。

## 2. データフロー

```
[HTML フォーム] → crop_params（strong params）
  → CropUpdateInputDto.from_hash({ crop: crop_params }, crop_id)
  → CropUpdateInteractor#call(input_dto)
  → attrs に crop_stages_attributes を含める
  → CropPolicy.apply_update!(user, crop, attrs)
  → crop.update(attributes)
  → accepts_nested_attributes_for :crop_stages / :nutrient_requirement が適用される
```

## 3. CropUpdateInputDto 契約

### 3.1 必須フィールド

| フィールド | 型 | 説明 |
|------------|-----|------|
| crop_id | Integer | 更新対象の作物 ID |
| name | String, nil | 作物名 |
| variety | String, nil | 品種 |
| area_per_unit | Numeric, nil | 単位あたり面積 |
| revenue_per_area | Numeric, nil | 面積あたり収益 |
| region | String, nil | 地域（管理者のみ） |
| groups | Array<String>, nil | 作物グループ（カンマ区切り文字列は from_hash で配列に変換） |
| **crop_stages_attributes** | Hash/Array, nil | 生育ステージのネストした属性（Rails の nested attributes 形式） |

### 3.2 crop_stages_attributes の構造

コントローラの `crop_params` で許可する構造と一致すること。

- 各要素は `id`（既存）/ `name` / `order` / `_destroy` に加え、以下いずれかを含む:
  - `temperature_requirement_attributes`
  - `thermal_requirement_attributes`
  - `sunshine_requirement_attributes`
  - `nutrient_requirement_attributes`（`:id`, `:daily_uptake_n`, `:daily_uptake_p`, `:daily_uptake_k`, `:_destroy`）

DTO は `crop_params[:crop_stages_attributes]` をそのまま保持する（キーは文字列 "0", "1" 等でも可）。

## 4. CropUpdateInteractor 契約

- **入力**: CropUpdateInputDto（crop_stages_attributes を含む場合がある）。
- **振る舞い**:
  - `attrs` にフラット属性（name, variety, area_per_unit, revenue_per_area, region, groups）を設定する。
  - **crop_stages_attributes が present の場合、attrs[:crop_stages_attributes] にその値を設定する。**
  - `CropPolicy.find_editable!` で対象 Crop を取得し、`CropPolicy.apply_update!(user, crop_model, attrs)` を呼ぶ。
- **出力**: 成功時は `on_success(crop_entity)`、失敗時は `on_failure(error_dto)`。

## 5. CropPolicy.apply_update! 契約

- **入力**: user, crop（Crop モデル）, attrs（Hash、crop_stages_attributes を含み得る）。
- **振る舞い**: `attrs` をそのまま `crop.update(attributes)` に渡す。`crop_stages_attributes` を含めてもよい（Crop は `accepts_nested_attributes_for :crop_stages` により処理する）。
- **制約**: Policy は `attrs` から `crop_stages_attributes` を削除したり変換したりしない。

## 6. コントローラの strong params

CropsController#crop_params は以下を許可すること（既存どおり）。

- フラット: `:name`, `:variety`, `:is_reference`, `:area_per_unit`, `:revenue_per_area`, `:groups`, `:region`（管理者のみ）
- ネスト: `crop_stages_attributes: [ :id, :name, :order, :_destroy, temperature_requirement_attributes: [...], thermal_requirement_attributes: [...], sunshine_requirement_attributes: [...], nutrient_requirement_attributes: [ :id, :daily_uptake_n, :daily_uptake_p, :daily_uptake_k, :_destroy ] ]`

## 7. 実装チェックリスト

- [x] CropUpdateInputDto に `crop_stages_attributes` が定義され、`from_hash` で `crop_params[:crop_stages_attributes]` を渡している
- [x] CropUpdateInteractor が `attrs[:crop_stages_attributes] = input_dto.crop_stages_attributes` を present の場合に設定している
- [x] CropPolicy.apply_update! が受け取った `attrs` をそのまま `crop.update(attributes)` に渡している（crop_stages_attributes を除去していない）
- [x] CropsController の update テスト（nutrients 追加・更新・削除、ステージ名更新等）がすべてパスする（2026-01-31 確認）
- [ ] 必要に応じて CropUpdateInteractor の単体テストで crop_stages_attributes を渡した場合の成功パスを追加する

## 8. 参照

- CropsController: `app/controllers/crops_controller.rb`（crop_params, update）
- Crop モデル: `app/models/crop.rb`（accepts_nested_attributes_for :crop_stages）
- CropStage モデル: `app/models/crop_stage.rb`（accepts_nested_attributes_for :nutrient_requirement 等）
- CropUpdateInputDto: `lib/domain/crop/dtos/crop_update_input_dto.rb`
- CropUpdateInteractor: `lib/domain/crop/interactors/crop_update_interactor.rb`
- CropPolicy: `lib/domain/shared/policies/crop_policy.rb`
