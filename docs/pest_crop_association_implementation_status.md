# Pest–Crop / Pesticide–Crop/Pest 関連付けの Policy/Service 化 - 実装状況

## ドキュメント方針との比較

### ドキュメントの方針（`docs/html_json_api_unification.md` 3.2.2節）

**目標:**
- `PestsController` / `PesticidesController` に散在する「関連付け可否」ロジックを `PestCropAssociationPolicy` / `PesticideAssociationPolicy` + Service に移動
- HTML/JSON 両方から同じルールを利用する

**責務:**
- 「この pest と crop を関連付けてよいか?」
- 「この user が選択できる crop/pest 一覧は?」

**ルール:**
- `pest.region` があれば、cropのregionと一致していないとNG
- 参照害虫は参照作物のみ関連付け可能
- ユーザー害虫は、そのユーザーの非参照作物のみ関連付け可能

---

## 実装状況

### ✅ 実装完了

#### 1. Policy の実装

**`PestCropAssociationPolicy`** (`app/policies/pest_crop_association_policy.rb`)
- ✅ `accessible_crops_scope(pest, user:)`: 害虫に対して選択可能な作物のスコープを返す
  - ルール: region一致、参照害虫は参照作物のみ、ユーザー害虫はそのユーザーの非参照作物のみ
- ✅ `crop_accessible_for_pest?(crop, pest, user:)`: 特定の作物が害虫と関連付け可能か判定
  - ルール: region一致チェック、参照/ユーザー害虫のルール適用

**`PesticideAssociationPolicy`** (`app/policies/pesticide_association_policy.rb`)
- ✅ `accessible_crops_scope(user)`: 農薬に対して選択可能な作物のスコープを返す
  - 管理者: 参照作物 + 自分の作物
  - 一般ユーザー: 自分の非参照作物のみ
- ✅ `accessible_pests_scope(user)`: 農薬に対して選択可能な害虫のスコープを返す
  - 管理者: 参照害虫 + 自分の害虫
  - 一般ユーザー: 自分の非参照害虫のみ

#### 2. Service の実装

**`PestCropAssociationService`** (`app/services/pest_crop_association_service.rb`)
- ✅ `associate_crops(pest, crop_ids, user:)`: 害虫と作物を関連付ける
  - Policy を利用して関連付け可否を判定し、許可されたもののみ関連付ける
- ✅ `update_crop_associations(pest, crop_ids, user:)`: 関連付けを更新（差分更新）
- ✅ `normalize_crop_ids(pest, raw_ids, user:)`: 作物IDを正規化（選択可能な作物IDのみを抽出）
- ✅ `accessible_crops_scope(pest, user:)`: Policy への委譲

#### 3. コントローラへの適用

**HTML コントローラ:**
- ✅ `PestsController` (`app/controllers/pests_controller.rb`)
  - `associate_crops`: `PestCropAssociationService.associate_crops` 経由
  - `update_crop_associations`: `PestCropAssociationService.update_crop_associations` 経由
  - `prepare_crop_selection_for`: `PestCropAssociationPolicy.accessible_crops_scope` 経由
  - `normalize_crop_ids_for`: `PestCropAssociationService.normalize_crop_ids` 経由
- ✅ `PesticidesController` (`app/controllers/pesticides_controller.rb`)
  - `load_crops_and_pests`: `PesticideAssociationPolicy.accessible_crops_scope` / `accessible_pests_scope` 経由
- ✅ `Crops::PestsController` (`app/controllers/crops/pests_controller.rb`)
  - `index`: `PestPolicy.selectable_scope` 経由（参照害虫も含む）
  - `new`: `PestPolicy.selectable_scope` 経由（参照害虫も含む）

**JSON API コントローラ:**
- ✅ `Api::V1::PestsController` (`app/controllers/api/v1/pests_controller.rb`)
  - `associate_crops_from_api`: `PestCropAssociationPolicy.crop_accessible_for_pest?` 経由（参照作物は常にアクセス可能なAI API特有のロジックを維持）
- ✅ `Api::V1::Masters::Crops::PesticidesController` (`app/controllers/api/v1/masters/crops/pesticides_controller.rb`)
  - `index`: `PesticidePolicy.selectable_scope` 経由（参照農薬も含む）
- ✅ `Api::V1::Masters::Crops::PestsController` (`app/controllers/api/v1/masters/crops/pests_controller.rb`)
  - `index`: `PestPolicy.selectable_scope` 経由（参照害虫も含む）
  - `create`: `PestPolicy.selectable_scope` 経由（参照害虫も含む）

#### 4. テスト

- ✅ `PestCropAssociationPolicy` のテスト (`test/policies/pest_crop_association_policy_test.rb`)
- ✅ `PestCropAssociationService` のテスト (`test/services/pest_crop_association_service_test.rb`)
- ✅ `PesticideAssociationPolicy` のテスト (`test/policies/pesticide_association_policy_test.rb`)
- ✅ 既存のコントローラテストがすべて通過

---

## ドキュメント方針との整合性

### ✅ 完全に一致

1. **Policy/Service の作成**: ✅ 完了
   - `PestCropAssociationPolicy` / `PestCropAssociationService` を作成
   - `PesticideAssociationPolicy` を作成

2. **責務の実装**: ✅ 完了
   - 「この pest と crop を関連付けてよいか?」→ `PestCropAssociationPolicy.crop_accessible_for_pest?`
   - 「この user が選択できる crop/pest 一覧は?」→ `PestCropAssociationPolicy.accessible_crops_scope` / `PesticideAssociationPolicy.accessible_crops_scope` / `accessible_pests_scope`

3. **ルールの実装**: ✅ 完了
   - region一致チェック: ✅ 実装済み
   - 参照害虫は参照作物のみ: ✅ 実装済み
   - ユーザー害虫はそのユーザーの非参照作物のみ: ✅ 実装済み

4. **HTML/JSON 両方からの利用**: ✅ 完了
   - HTMLコントローラ: `PestsController`, `PesticidesController`, `Crops::PestsController`
   - JSON APIコントローラ: `Api::V1::PestsController`, `Api::V1::Masters::Crops::PesticidesController`, `Api::V1::Masters::Crops::PestsController`

5. **直接SQLの削除**: ✅ 完了
   - すべてのコントローラで `where("is_reference = ? OR user_id = ?", true, current_user.id)` を削除
   - Policyメソッド（`visible_scope`, `selectable_scope`）を使用

---

## 追加実装（ドキュメントに明記されていないが実装したもの）

1. **`PestPolicy.selectable_scope` / `PesticidePolicy.selectable_scope`**
   - 一般ユーザーでも参照データを含むスコープ（選択候補として使用）
   - `visible_scope` は一般ユーザーは自分の非参照データのみ（既存の動作を維持）

2. **`Api::V1::PestsController#associate_crops_from_api` のAI API特有ロジック**
   - 参照作物は常にアクセス可能（AI API特有の要件）
   - Policy を利用しつつ、参照作物の特別扱いを維持

---

## テスト結果

- 全体テスト: 966 runs, 5822 assertions, 0 failures, 0 errors, 7 skips
- カバレッジ: 62.03% (5769 / 9300)

---

## 結論

**ドキュメントの方針と完全に一致しており、すべての要件を満たしています。**

- ✅ Policy/Service の作成
- ✅ 責務の実装
- ✅ ルールの実装
- ✅ HTML/JSON 両方からの利用
- ✅ 直接SQLの削除
- ✅ テストの追加

すべて完了しています。
