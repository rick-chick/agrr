# HTML API / JSON API 統一方針（Concern / Policy 設計）

## 1. 目的・スコープ

### 1.1 目的

- HTML向けコントローラとJSON向けコントローラで重複している **ビジネスルール・権限・クエリ・レスポンス処理** を整理し、  
  **Concern / Policy / Service 層に統一する方針**を明文化する。

### 1.2 スコープ

- 対象ディレクトリ
  - `app/controllers` 全般
  - 特に以下の2系統:
    - HTML系: 通常のリソースコントローラ（例: `CropsController` など）
    - JSON系: `Api::V1::*`（特に `Api::V1::Masters::*`, `Api::V1::Plans::*`）

---

## 2. 現状構造の整理

### 2.1 HTML系コントローラの特徴

- 代表例
  - `CropsController`
  - `PestsController`
  - `FertilizesController`
  - `PesticidesController`
  - `InteractionRulesController`
  - `AgriculturalTasksController`
  - `PlansController`
- 特徴
  - 画面表示・フォーム処理・Turbo/HTMLレスポンスが主な責務。
  - ただし同時に、以下のような **ビジネスルールも内包**している:
    - `is_reference` と `user_id` の扱い（参照データ vs ユーザーデータ）
    - 管理者かどうかによる **アクセス制御 / 更新可否**
    - データ削除＋Undo（`DeletionUndo::Manager`）
    - モデル間関連付け（例: Pest と Crop の関連）

### 2.2 JSON系コントローラの特徴

- 代表例
  - `Api::V1::Masters::*Controller`（crops, pests, fertilizes, pesticides, interaction_rules, farms, fields, agricultural_tasks など）
  - `Api::V1::CropsController` / `PestsController` / `FertilizesController`（AI作成・更新系）
  - `Api::V1::Plans::CultivationPlansController`
  - `Api::V1::PublicPlans::CultivationPlansController`
- 特徴
  - 多くが **HTML側と同じモデルを扱うCRUD** を実装している。
  - `current_user.*.where(is_reference: false)` など、
    **所有権と参照フラグに関するルールを再実装**している箇所が多い。
  - レスポンスはJSON専用で、バリデーションエラー時に `{ errors: ... }` を返すパターンが共通。

---

## 3. 統一対象の分類（Concern vs Policy / Service）

### 3.1 Concern に寄せるべき「プレゼンテーションロジック」

#### 3.1.1 削除＋Undo＋例外ハンドリング

- 現状パターン
  - 各コントローラで以下のようなコードが繰り返されている:
    - `DeletionUndo::Manager.schedule(record: ..., actor: current_user, toast_message: ...)`
    - `render_deletion_undo_response(event, fallback_location: ...)`
    - 例外ハンドリング (`InvalidForeignKey`, `DeleteRestrictionError`, `DeletionUndo::Error`, `StandardError`) とメッセージ分岐。
- 対象コントローラ（例）
  - `CropsController`
  - `PestsController`
  - `FertilizesController`
  - `PesticidesController`
  - `InteractionRulesController`
  - `PlansController`
  - `DeletionUndosController`
- 方針
  - 既存 `DeletionUndoResponder` を拡張し、
    - `schedule_and_respond_deletion(record, fallback_location:, toast_message_key:, i18n_interpolations: {})`
    - `respond_deletion_failure(message_key:, fallback_location:, status: :unprocessable_entity)`
  - を提供する。
  - 各コントローラは **1〜2行呼び出しに縮小**し、例外種別やメッセージ分岐をConcern側に集約する。

#### 3.1.2 CRUD 成功/失敗レスポンス（HTML / JSON）

- 現状パターン
  - HTML:
    - 成功: `redirect_to ..., notice: ...`
    - 失敗: `render :new/:edit, status: :unprocessable_entity`
  - JSON:
    - 成功: `render json: resource, status: ...`
    - 失敗: `render json: { errors: resource.errors.full_messages }, status: :unprocessable_entity`
- 対象
  - HTML: HTML系リソースコントローラほぼすべて
  - JSON: `Api::V1::Masters::*`, `Api::V1::*` のCRUDエンドポイント
- 方針
  - `ApplicationController` 配下に、レスポンス用Concern（案）:
    - `HtmlCrudResponder`
    - `ApiCrudResponder`
  - もしくはフォーマット非依存な `CrudResponder` + API用BaseControllerでの上書き。
  - 提供メソッド例:
    - `respond_create(resource, html: {success_path:, failure_template:}, json: {serializer:, status:})`
    - `respond_update(resource, ...)`
    - `respond_destroy(success:, errors:, ...)`
  - これにより **HTML/JSONのエラーレスポンス仕様を1箇所に固定**できる。

#### 3.1.3 HTML/JSON 両対応アクションのテンプレート

- 現状
  - 一部コントローラ（`Plans::TaskSchedulesController`, `DeletionUndosController` 等）で
    - `respond_to do |format| ... format.html ... format.json ... end`
  - を個別実装している。
- 方針
  - 「HTML/JSON両対応」が必要な画面を限定し、
  - Concernメソッド例:
    - `render_html_and_json(html_template:, json_payload:, status: :ok)`
  - として、同じパターンをまとめる。

---

### 3.2 Policy / Service に寄せるべき「ビジネスルール・クエリ」

#### 3.2.1 `is_reference` + 所有権 (`current_user`) ルール

- 共通ルール
  - 一覧:
    - 管理者: 「自分の＋参照」  
      `Model.where("is_reference = ? OR user_id = ?", true, current_user.id)`
    - 一般ユーザー: 「自分ののみ & is_reference: false」
  - 作成:
    - 一般ユーザーは `is_reference` を立てられない（強制false、user_id付与）
    - 管理者のみ `is_reference` をtrueにでき、その場合は `user_id = nil`
  - 更新:
    - `is_reference` の変更可否は管理者のみ、
      それ以外は`user_id`と現在の`is_reference`に基づいて制限。
- 影響モデル/コントローラ
  - Crops: `CropsController`, `Api::V1::Masters::CropsController`, `Api::V1::CropsController` 等
  - Pests: `PestsController`, `Api::V1::Masters::PestsController`, `Api::V1::PestsController`
  - Fertilizes: `FertilizesController`, `Api::V1::Masters::FertilizesController`, `Api::V1::FertilizesController`
  - Pesticides: `PesticidesController`, `Api::V1::Masters::PesticidesController`
  - InteractionRules: `InteractionRulesController`, `Api::V1::Masters::InteractionRulesController`
  - AgriculturalTasks: `AgriculturalTasksController`, `Crops::AgriculturalTasksController`, `Api::V1::Masters::AgriculturalTasksController`
  - Farms/Fields: `FarmsController`, `FieldsController`, `Api::V1::Masters::FarmsController`, `Api::V1::Masters::FieldsController`
- 方針
  - モデル単位で **アクセス/参照ポリシーをクラスに切り出す**:
    - 例:
      - `CropPolicy` / `CropAccessPolicy`
      - `PestPolicy`
      - `FertilizePolicy`
      - `PesticidePolicy`
      - `InteractionRulePolicy`
      - `AgriculturalTaskPolicy`
  - 提供メソッド例:
    - スコープ系:
      - `visible_scope(user)` / `editable_scope(user)` / `reference_scope(user)`
    - 単体取得:
      - `find_visible!(user, id)` / `find_editable!(user, id)`
    - 作成・更新:
      - `build_for_create(user, params)`（is_referenceとuser_idの整合をとる）
      - `apply_update!(user, record, params)`（is_reference変更の可否を内包）

#### 3.2.2 Cross-model 関連付けとアクセス制約

- 代表例: Pest \u2194 Crop
  - `PestsController` のメソッド:
    - `associate_crops` / `update_crop_associations`
    - `accessible_crops_for_selection` / `crop_accessible_for_pest?`
  - ルール:
    - `pest.region` があれば、cropのregionと一致していないとNG。
    - 参照害虫は参照作物のみ関連付け可能。
    - ユーザー害虫は、そのユーザーの非参照作物のみ関連付け可能。
- 代表例: Pesticide \u2194 Crop/Pest
  - `PesticidesController` の一覧で、
    - `Crop` / `Pest` の選択候補を参照＋ユーザーデータから組み立てている。
- 方針
  - 関連単位でポリシー/サービスを設ける:
    - `PestCropAssociationPolicy` / `PestCropAssociationService`
    - `PesticideAssociationPolicy`
  - 責務例:
    - 「この pest と crop を関連付けてよいか?」
    - 「この user が選択できる crop/pest 一覧は?」
  - HTML/JSONの両方から利用することで、**関連付け条件のズレを防止**する。

#### 3.2.3 Farm / Field / Plan の所有権・公開/非公開ルール

- 対象
  - HTML:
    - `FarmsController`, `FieldsController`, `PlansController`, `PublicPlansController`
  - API:
    - `Api::V1::Masters::FarmsController`, `FieldsController`
    - `Api::V1::Plans::FieldCultivationsController`
    - `Api::V1::PublicPlans::FieldCultivationsController`
    - `Api::V1::Plans::CultivationPlansController`
    - `Api::V1::PublicPlans::CultivationPlansController`
- ルール
  - 「private plan」 vs 「public plan」でアクセス制約が異なる。
  - user に紐づく farm/field/plan にしか触れない、一部は公開読み取りのみ等。
- 方針
  - 例:
    - `FarmPolicy`, `FieldPolicy`, `PlanPolicy`
  - 責務例:
    - `visible_scope(user)`
    - `find_owned!(user, id)`
    - `ensure_belongs_to_user!(user, record)` など。

#### 3.2.4 AI 系APIと通常CRUDの整合性

- 対象
  - `Api::V1::CropsController#ai_create`
  - `Api::V1::FertilizesController#ai_create/#ai_update`
  - `Api::V1::PestsController#ai_create/#ai_update`
- ルール
  - 「同名レコードがあれば更新、なければ作成」的な upsert ロジック。
  - `is_reference: false` / `user_id` の付与ルールは **通常のCRUDと同じポリシーに従うべき**。
- 方針
  - 各モデル用の `AiUpsertService` をばらばらに作るのではなく、
    - 「通常の Policy を利用して作成/更新し、その上でAI特有の差分だけ載せる」設計に寄せる。
  - 可能であれば「名前から既存検索→policyを通して更新/作成」を共通化する。

---

## 4. 優先順位と段階的導入計画

### 4.1 優先度の高い統一ポイント

1. **`is_reference` + 所有権ルールのPolicy化**
   - 影響モデルが多く、HTML/JSON両方で頻出する。
   - ここをPolicy層に寄せることで、**仕様変更時の修正ポイントが一気に減る**。
   - 2025-11 時点の実装状況:
     - 共通モジュール `ReferencableResourcePolicy` を用意し、`visible_scope_for(user)` を定義。
     - `CropPolicy` / `FertilizePolicy` / `PesticidePolicy` / `PestPolicy` / `InteractionRulePolicy` / `AgriculturalTaskPolicy` から各モデルに `include` 済み。
     - HTML側の以下の `index` アクションは、すでに `*Policy.visible_scope(current_user)` に移行済み:
       - `CropsController#index`
       - `FertilizesController#index`
       - `PesticidesController#index`
       - `PestsController#index`
       - `InteractionRulesController#index`
       - `AgriculturalTasksController#index`（一般ユーザー側のスコープ）
     - モデルレベルで不変条件をバリデーションとして明文化:
       - `is_reference: false` のとき: `user` 必須（既存どおり）
       - `is_reference: true` のとき: `user_id` は必ず `nil`（参照データはシステム所有）
       - 対象モデル: `Crop`, `Fertilize`, `Pesticide`, `Pest`, `AgriculturalTask`, `InteractionRule`
     - 上記不変条件をテストで固定するため、各モデルの `*_test.rb` に **参照データに user を付けるとエラーになる** ことを確認するテストを追加済み。
2. **削除 + Undo 処理のConcern統一**
   - パターンが揃っており、UI/UX上も重要な機能。
   - 2025-11 時点の実装状況:
     - Concern `DeletionUndoFlow` を追加し、`schedule_deletion_with_undo(record:, toast_message:, fallback_location:, in_use_message_key:, delete_error_message_key:)` を提供。
     - 以下のHTMLコントローラで `destroy` アクションから共通フローを利用:
       - `CropsController`
       - `FertilizesController`
       - `PesticidesController`
       - `PestsController`
       - `InteractionRulesController`
       - `AgriculturalTasksController`
       - `FarmsController`
       - `FieldsController`
     - 既存の詳細なエラーメッセージ分岐が重要な箇所（例: `PlansController`, `Plans::TaskScheduleItemsController`）は、現時点では個別実装を維持。
3. **CRUD 成功/失敗レスポンスのテンプレート化（HTML/JSON別Concern）** ✅ **完了（2025-11-27）**
   - APIのレスポンス仕様とHTMLのバリデーションエラー挙動を揃えられる。
   - 実装状況:
     - `HtmlCrudResponder` と `ApiCrudResponder` を実装し、すべての対象コントローラに適用済み。
     - HTML: 8コントローラ、JSON: 8コントローラに適用完了。
     - 全体テスト通過（993 runs, 5881 assertions, 0 failures）。

### 4.2 中期的に整理したいポイント

4. **Pest–Crop / Pesticide–Crop/Pest 関連ポリシー**
   - ドメインルールが複雑なため、controller外に出す価値が大きい。
5. **Farm / Field / Plan のAccessPolicy（一部完了）**
   - 2025-11 時点の実装状況:
     - `FarmPolicy` / `FieldPolicy` / `PlanPolicy` を実装済み。
     - HTMLコントローラ（`FarmsController`, `FieldsController`, `PlansController`）と Masters API（`Api::V1::Masters::FarmsController`, `FieldsController`）、Plans API（`Api::V1::Plans::CultivationPlansController`）への適用が完了。
   - 残り:
     - `Api::V1::Plans::FieldCultivationsController` / `Api::V1::PublicPlans::FieldCultivationsController` / `Api::V1::PublicPlans::CultivationPlansController` / `PublicPlansController`（HTML側）への適用が未完了。

### 4.3 既に良い設計が進んでいる部分

- `PlansController` と `Api::V1::Plans::*` / `Api::V1::PublicPlans::*` の間で使われている Concern:
  - `CultivationPlanManageable`
  - `CultivationPlanApi`
  - `WeatherDataManagement`
  - `JobExecution`
- これらは「ユースケース共通ロジックをConcernに置き、HTML/APIで再利用する」という設計で、
  **今回のリファクタ方針と整合している**。他領域もこの方向に寄せていく。

---

## 5. 実装ガイドライン（共通方針）

- コントローラの責務
  - 可能な限り、
    - リクエストパラメータの受け取り
    - Policy/Serviceの呼び出し
    - Concernを使ったレスポンス返却
  - にとどめる。
- Policy/Service の責務
  - モデル単位・関連単位のビジネスルール（所有権、`is_reference`, 関連付け可否など）。
  - HTML/JSONの違いは持たず、**純粋なドメインロジック**に留める。
- Concern の責務
  - レスポンス形式（HTML/JSON/Turbo）や、共通のフロー（削除＋Undo）など、
  - **プレゼンテーション寄りの共通処理**を担当する。

---

## 6. 用意すべき Concern / Policy / Service の一覧とグルーピング

### 6.1 Concern（プレゼンテーションロジック）

- **CRUDレスポンス系**
  - `HtmlCrudResponder`
    - HTML向けの共通レスポンス。
    - `create` / `update` / `destroy` の成功・失敗時に、リダイレクト先や `render :new/:edit` + `422` をテンプレート化する。
  - `ApiCrudResponder`
    - JSON向けの共通レスポンス。
    - 成功時: `render json: resource, status: ...`
    - 失敗時: `render json: { errors: resource.errors.full_messages }, status: :unprocessable_entity`
  - （オプション）`CrudResponder`
    - 上記2つの共通インタフェースを定義するベースConcern。
  - **主な対象ファイル（想定適用先）**
    - HTML:
      - `app/controllers/crops_controller.rb`
      - `app/controllers/pests_controller.rb`
      - `app/controllers/fertilizes_controller.rb`
      - `app/controllers/pesticides_controller.rb`
      - `app/controllers/interaction_rules_controller.rb`
      - `app/controllers/agricultural_tasks_controller.rb`
      - `app/controllers/farms_controller.rb`
      - `app/controllers/fields_controller.rb`
      - `app/controllers/plans_controller.rb`
    - JSON:
      - `app/controllers/api/v1/masters/*.rb`
      - `app/controllers/api/v1/*.rb`（`crops_controller.rb`, `pests_controller.rb`, `fertilizes_controller.rb` など）

- **削除＋Undo系**
  - `DeletionUndoFlow`
    - 既存 `DeletionUndoResponder` を拡張 or ラップし、削除＋Undoフローを1〜2行で呼び出せるようにする。
    - 主な対象ファイル（grep: `DeletionUndo::Manager`）:
      - `app/controllers/crops_controller.rb`
      - `app/controllers/pests_controller.rb`
      - `app/controllers/fertilizes_controller.rb`
      - `app/controllers/pesticides_controller.rb`
      - `app/controllers/interaction_rules_controller.rb`
      - `app/controllers/agricultural_tasks_controller.rb`
      - `app/controllers/farms_controller.rb`
      - `app/controllers/fields_controller.rb`
      - `app/controllers/plans_controller.rb`
      - `app/controllers/plans/task_schedule_items_controller.rb`
      - `app/controllers/deletion_undos_controller.rb`

- **HTML/JSON両対応アクション系**
  - `DualFormatResponder`
    - `respond_to` パターンをテンプレート化するConcern。
    - 主な対象ファイル（grep: `respond_to do |format|`）:
      - `app/controllers/crops_controller.rb`
      - `app/controllers/crops/task_schedule_blueprints_controller.rb`
      - `app/controllers/deletion_undos_controller.rb`
      - `app/controllers/plans/task_schedules_controller.rb`
      - `app/controllers/sitemaps_controller.rb`
    - うち HTML/JSON/Turbo 混在の代表例:
      - `CropsController#toggle_task_template`
      - `Plans::TaskSchedulesController#show`
      - `DeletionUndosController#create`

### 6.2 Policy（アクセス権・所有権・`is_reference` ルール）

- **参照マスタ / ユーザーデータ系（共通の`is_reference` + 所有権ルール）**
  - 共通責務:
    - 一覧スコープ: `visible_scope(user)`, `editable_scope(user)`
    - 単体取得: `find_visible!(user, id)`, `find_editable!(user, id)`
    - 作成/更新:
      - `build_for_create(user, params)`（`is_reference` / `user_id` の正規化）
      - `apply_update!(user, record, params)`（`is_reference` の変更可否チェック）
  - 対象Policy と主な対象ファイル（grep: `is_reference` + `current_user.<model>`）:
    - `CropPolicy`
      - HTML系:
        - `app/controllers/crops_controller.rb`
        - `app/controllers/plans_controller.rb`（`current_user.crops.where(..., is_reference: false)`）
        - `app/controllers/crops/task_schedule_blueprints_controller.rb`
        - `app/controllers/crops/agricultural_tasks_controller.rb`
        - `app/controllers/crops/pests_controller.rb`
      - API系（マスタAPI本体と、そのネストリソース）:
        - `app/controllers/api/v1/masters/crops_controller.rb`
        - `app/controllers/api/v1/masters/crops/crop_stages_controller.rb`
        - `app/controllers/api/v1/masters/crops/crop_stages/temperature_requirements_controller.rb`
        - `app/controllers/api/v1/masters/crops/crop_stages/thermal_requirements_controller.rb`
        - `app/controllers/api/v1/masters/crops/crop_stages/sunshine_requirements_controller.rb`
        - `app/controllers/api/v1/masters/crops/crop_stages/nutrient_requirements_controller.rb`
        - `app/controllers/api/v1/masters/crops/pests_controller.rb`
        - `app/controllers/api/v1/masters/crops/agricultural_tasks_controller.rb`
        - `app/controllers/api/v1/masters/crops/pesticides_controller.rb`
      - AI系API:
        - `app/controllers/api/v1/crops_controller.rb`（`ai_create` でユーザー作物をupsert）
      - これらのコントローラで「どのCropにアクセスできるか」「参照フラグをどう扱うか」を `CropPolicy` に一元化する。
    - `PestPolicy`
      - HTML系:
        - `app/controllers/pests_controller.rb`
        - `app/controllers/pesticides_controller.rb`（害虫候補取得）
        - `app/controllers/crops/pests_controller.rb`
      - API系:
        - `app/controllers/api/v1/masters/pests_controller.rb`
        - `app/controllers/api/v1/pests_controller.rb`（AI害虫 upsert）
    - `FertilizePolicy`
      - HTML系:
        - `app/controllers/fertilizes_controller.rb`
      - API系:
        - `app/controllers/api/v1/masters/fertilizes_controller.rb`
        - `app/controllers/api/v1/fertilizes_controller.rb`（AI肥料 upsert）
    - `PesticidePolicy`
      - HTML系:
        - `app/controllers/pesticides_controller.rb`
      - API系:
        - `app/controllers/api/v1/masters/pesticides_controller.rb`
        - `app/controllers/api/v1/masters/crops/pesticides_controller.rb`
    - `InteractionRulePolicy`
      - HTML系:
        - `app/controllers/interaction_rules_controller.rb`
      - API系:
        - `app/controllers/api/v1/masters/interaction_rules_controller.rb`
    - `AgriculturalTaskPolicy`
      - HTML系:
        - `app/controllers/agricultural_tasks_controller.rb`
        - `app/controllers/crops/agricultural_tasks_controller.rb`
      - API系:
        - `app/controllers/api/v1/masters/agricultural_tasks_controller.rb`
  - 必要であれば、これらに共通する振る舞いを `ReferencableResourcePolicy`（仮）としてモジュール化してミックスインする。

- **農場・圃場・計画系（所有権 / 公開・非公開ルール）**
  - 共通責務:
    - ユーザー所有オブジェクトのみ操作可能にする。
    - private plan / public plan でアクセス制御を切り替える。
  - 対象Policy と主な対象ファイル（grep: `current_user.(farms|fields)` / plan系controller）:
    - `FarmPolicy`（実装済み）
      - 提供メソッド: `user_owned_scope(user)`, `find_owned!(user, id)`, `build_for_create(user, attrs)`, `reference_scope(region:)`
      - 適用済み:
        - `app/controllers/farms_controller.rb`（`create`, `set_farm`）
        - `app/controllers/fields_controller.rb`（`set_farm`）
        - `app/controllers/api/v1/masters/farms_controller.rb`（`index`, `create`, `set_farm`）
        - `app/controllers/public_plans_controller.rb`（`new` で参照農場取得）
      - 未適用:
        - `app/controllers/farms/weather_data_controller.rb`（必要に応じて）
    - `FieldPolicy`（実装済み）
      - 提供メソッド: `scope_for_farm(user, farm)`, `find_owned!(user, id)`, `build_for_create(user, farm, attrs)`
      - 適用済み:
        - `app/controllers/api/v1/masters/fields_controller.rb`（`index`, `create`, `set_field`）
      - 注: FieldCultivations 系は `PlanPolicy` 経由でアクセス制御（Field ではなく Plan の所有権で判定）
    - `PlanPolicy`（実装済み）
      - 提供メソッド: `private_scope(user)`, `find_private_owned!(user, id)`, `public_scope`, `find_public!(id)`
      - 適用済み:
        - `app/controllers/plans_controller.rb`（`set_plan`, `find_cultivation_plan_scope`）
        - `app/controllers/api/v1/plans/cultivation_plans_controller.rb`（`find_api_cultivation_plan`）
        - `app/controllers/api/v1/plans/field_cultivations_controller.rb`（`find_field_cultivation`）
        - `app/controllers/api/v1/public_plans/field_cultivations_controller.rb`（`show`, `climate_data`, `update`）
        - `app/controllers/api/v1/public_plans/cultivation_plans_controller.rb`（`find_api_cultivation_plan`）
      - 未適用:
        - `app/controllers/planning_schedules_controller.rb`（必要に応じて）

- **クロスモデル関連付けポリシー（関連可否ルール）**
  - 共通責務:
    - 「この組み合わせを関連付けてよいか？」を判定する。
  - 対象Policy と主な対象ファイル:
    - `PestCropAssociationPolicy`
      - ベースロジック:
        - region 一致
        - 参照害虫は参照作物のみ
        - ユーザー害虫は、そのユーザーの非参照作物のみ
      - 対象ファイル:
        - `app/controllers/pests_controller.rb`（`associate_crops`, `update_crop_associations`, `crop_accessible_for_pest?`）
        - `app/controllers/pesticides_controller.rb`（作物候補取得）
        - `app/controllers/crops/pests_controller.rb`（作物配下の害虫管理）
    - `PesticideAssociationPolicy`
      - pesticide ↔ crop/pest の関連付け条件を集約。
      - 対象ファイル:
        - `app/controllers/pesticides_controller.rb`
        - `app/controllers/api/v1/masters/pesticides_controller.rb`
        - `app/controllers/api/v1/masters/crops/pesticides_controller.rb`
    - （必要であれば）`CropTaskTemplatePolicy`, `CropTaskBlueprintPolicy`
      - crop に対するタスクテンプレート／ブループリント操作権限を判定。
      - 対象ファイル:
        - `app/controllers/crops_controller.rb`（`toggle_task_template`, `generate_task_schedule_blueprints`）
        - `app/controllers/crops/task_schedule_blueprints_controller.rb`

### 6.3 Service（ユースケース・操作実行ロジック）

- **CRUDオーケストレーション系（Policy利用側）**
  - `GenericCrudService`（任意）
    - `policy` を用いて create / update / destroy を一括実行する共通サービス。
    - コントローラからは `CrudService.new(policy: CropPolicy, params: ...).create(current_user)` のように呼び出す。
  - モデル別CRUDサービス（必要に応じて）
    - `CropCommandService`
      - 主な呼び出し元候補:
        - `CropsController`
        - `Api::V1::Masters::CropsController`
        - `Api::V1::CropsController`（AI作物 upsert）
    - `PestCommandService`
      - 主な呼び出し元候補:
        - `PestsController`
        - `Api::V1::Masters::PestsController`
        - `Api::V1::PestsController`（AI害虫 upsert）
    - `FertilizeCommandService`
      - 主な呼び出し元候補:
        - `FertilizesController`
        - `Api::V1::Masters::FertilizesController`
        - `Api::V1::FertilizesController`（AI肥料 upsert）
    - `PesticideCommandService`
      - 主な呼び出し元候補:
        - `PesticidesController`
        - `Api::V1::Masters::PesticidesController`
        - `Api::V1::Masters::Crops::PesticidesController`
    - `InteractionRuleCommandService`
      - 主な呼び出し元候補:
        - `InteractionRulesController`
        - `Api::V1::Masters::InteractionRulesController`
    - `AgriculturalTaskCommandService`
      - 主な呼び出し元候補:
        - `AgriculturalTasksController`
        - `Crops::AgriculturalTasksController`
        - `Api::V1::Masters::AgriculturalTasksController`

- **クロスモデル関連付けサービス**
  - `PestCropAssociationService`
    - `PestCropAssociationPolicy` を利用して、害虫と作物の関連付け/更新を行う。
    - 主な呼び出し元候補:
      - `PestsController`（`associate_crops`, `update_crop_associations`）
      - `Crops::PestsController`（作物配下の害虫関連付け）
      - `PesticidesController`（作物候補取得部分の一元化も検討対象）
  - `PesticideAssociationService`
    - pesticide と crop/pest の関連付け/更新を担当する。
    - 主な呼び出し元候補:
      - `PesticidesController`
      - `Api::V1::Masters::PesticidesController`
      - `Api::V1::Masters::Crops::PesticidesController`

- **AI向けUpsertサービス**
  - `CropAiUpsertService`
  - `PestAiUpsertService`
  - `FertilizeAiUpsertService`
  - 共通責務:
    - 名前等で既存レコードを検索し、見つかれば Policy 経由で更新、なければ Policy 経由で作成。
    - `is_reference: false` や `user_id` の扱いは通常の Policy に委譲する。

- **計画・ジョブ実行関連（既存Concernの補完）**
  - `CultivationPlanCreationService`
    - `PlansController#create_cultivation_plan_with_jobs` 周辺のロジックをService化。
    - 主な呼び出し元候補:
      - `PlansController#create`
      - 将来的に `Api::V1::Plans::CultivationPlansController` / `Api::V1::PublicPlans::CultivationPlansController` からも再利用可能。
  - `PlanJobChainBuilder`
    - `create_job_instances_for_plans` の中身を分離し、weather/prediction/optimization/schedule/finalize のジョブチェーン構築を担う。
    - 主な呼び出し元候補:
      - `PlansController`
      - `PublicPlansController`
      - `Api::V1::Plans::CultivationPlansController`
      - `Api::V1::PublicPlans::CultivationPlansController`

---

この一覧を前提に、実際の実装では「どのグループから着手するか（例: 参照マスタ系Policy + Html/Api CrudResponder）」を決めて段階的に導入していく。

---

## 7. 現在の進捗と今後の計画（2025-11-27 時点）

### 7.1 実装済みの統一ポイント

- **CRUDレスポンスConcern（`HtmlCrudResponder` / `ApiCrudResponder`）の導入** ✅ **完了（2025-11-27）**
  - `HtmlCrudResponder`: HTML向けの共通レスポンスConcernを実装
    - `respond_to_create`, `respond_to_update` を提供
    - 成功時: `redirect_to` + flashメッセージ、失敗時: `render :new/:edit, status: :unprocessable_entity`
    - `update_result` パラメータにより、元の動作（`update`メソッドの戻り値で判定）を維持
  - `ApiCrudResponder`: JSON向けの共通レスポンスConcernを実装
    - `respond_to_index`, `respond_to_show`, `respond_to_create`, `respond_to_update`, `respond_to_destroy` を提供
    - 成功時: `render json: resource, status: ...`、失敗時: `render json: { errors: ... }, status: :unprocessable_entity`
  - 適用済みコントローラ:
    - HTML: `FarmsController`, `CropsController`, `FieldsController`, `FertilizesController`, `PesticidesController`, `PestsController`, `AgriculturalTasksController`, `InteractionRulesController`
    - JSON: `Api::V1::Masters::*` のすべてのコントローラ（8コントローラ）
  - 各コントローラのテストにConcernの包含確認テストを追加
  - 全体テスト通過（993 runs, 5881 assertions, 0 failures）
- **削除 + Undo フロー**
  - Concern `DeletionUndoFlow` を実装し、代表的な参照マスタ系HTMLコントローラ（crops, fertilizes, pesticides, pests, interaction_rules, agricultural_tasks, farms, fields）の `destroy` に適用済み。
  - JSON/HTML両方のレスポンス形式は既存の `DeletionUndoResponder` に委譲しつつ、各コントローラではほぼ1〜2行で呼び出せる形に整理。
- **参照マスタ系の一覧スコープ共通化**
  - `ReferencableResourcePolicy` + `*Policy.visible_scope(user)` を導入し、以下のHTML `index` アクションをPolicy経由のスコープに統一:
    - `CropsController#index`
    - `FertilizesController#index`
    - `PesticidesController#index`
    - `PestsController#index`
    - `InteractionRulesController#index`
    - `AgriculturalTasksController#index`（一般ユーザー側）
  - それぞれのコントローラテストに、「どのレコードが含まれ・含まれないか」を HTML レスポンスのテキストレベルで検証するテストを追加し、挙動を固定。
- **モデルレベルの `is_reference` / `user_id` 不変条件の明文化**
  - 参照マスタ系モデルに以下の制約を追加:
    - `is_reference: false` → `user` 必須（一般ユーザー/管理者のユーザー所有レコード）
    - `is_reference: true` → `user_id` は必ず `nil`（システム所有参照レコード）
  - 対象モデル:
    - `Crop`, `Fertilize`, `Pesticide`, `Pest`, `AgriculturalTask`, `InteractionRule`
  - これらの制約を検証するモデルテストを追加し、今後のPolicy/Service実装の前提として仕様を固定。
  - `Pesticide.from_agrr_output` などのインポート系ロジックも、`is_reference: true` の場合は `user_id=nil` を強制するよう更新済み。
- **HTML 参照マスタ系コントローラの `set_*` アクセス制御のPolicy化**
  - `CropPolicy` / `FertilizePolicy` / `PesticidePolicy` / `PestPolicy` / `InteractionRulePolicy` / `AgriculturalTaskPolicy` に `find_visible!` / `find_editable!` を実装。
  - 対象HTMLコントローラの `before_action :set_*` を、これらのPolicy経由（`*Policy.find_visible!` / `find_editable!`）に統一。
  - `PolicyPermissionDenied` 例外を導入し、「レコードが存在しない（404）」と「存在するが権限がない（403相当）」を明確に分離。
  - 各コントローラで `rescue PolicyPermissionDenied` により `no_permission`、`rescue ActiveRecord::RecordNotFound` により `not_found` を返すよう統一し、テストも `no_permission` / `not_found` の双方を明示的に検証。
- **HTML 参照マスタ系コントローラの `create` / `update` における参照フラグ・所有者ロジックのPolicy化**
  - 対象コントローラ:
    - `PestsController`
    - `AgriculturalTasksController`
    - `CropsController`
    - `FertilizesController`
    - `PesticidesController`
    - `InteractionRulesController`
  - 各コントローラの `create` / `update` に散在していた以下のロジックを、対応する `*Policy` に移動済み:
    - `is_reference` パラメータのキャスト
    - `is_reference` と `current_user` に応じた `user_id` の決定（参照=システム所有、非参照=ユーザー所有）
    - `is_reference` フラグの変更に伴う `user_id` の更新（参照化/非参照化）
  - 各 `*Policy` に追加された主なインタフェース:
    - `build_for_create(user, params)`:
      - `CropPolicy`, `PestPolicy`, `FertilizePolicy`, `PesticidePolicy`, `InteractionRulePolicy`, `AgriculturalTaskPolicy`
      - HTMLコントローラの `create` は、`*Policy.build_for_create(current_user, params)` でモデルインスタンスを構築し、`save` するだけに簡素化。
    - `apply_update!(user, record, params)`:
      - 同上の各Policyに実装。
      - HTMLコントローラの `update` は、`*Policy.apply_update!(current_user, @record, params)` の戻り値（`update` の成否）で分岐し、成功時 `redirect` / 失敗時 `render :edit, status: :unprocessable_entity` を行う形に統一。
  - これらの変更に先立ち、`create` / `update` の全パス（一般ユーザー/管理者、参照/非参照、バリデーションエラー、groups/required_tools などの周辺ロジック）をカバーするコントローラテストを追加し、挙動をテストで固定したうえでリファクタを実施済み。
  - 参照まわりのロジックについては、HTML側は「参照フラグを操作しようとしたときのadminガード」を除き、Policy層に寄せ終わっている。
- **JSON 参照マスタ系コントローラの index / show / create / update のPolicy化**
  - 対象コントローラ（`Api::V1::Masters` 配下・参照マスタ系）:
    - `Api::V1::Masters::CropsController`
    - `Api::V1::Masters::PestsController`
    - `Api::V1::Masters::FertilizesController`
    - `Api::V1::Masters::PesticidesController`
    - `Api::V1::Masters::AgriculturalTasksController`
    - `Api::V1::Masters::InteractionRulesController`
  - `index`:
    - すべて `*Policy.visible_scope(current_user)` を利用するよう変更し、HTML側と同じ「管理者=参照+自分 / 一般ユーザー=自分の非参照のみ」のスコープに揃えた。
  - `show` / `update` / `destroy` 向けの `set_*`:
    - `*Policy.find_editable!(current_user, params[:id])`（一部 `find_visible!` を併用）を利用するよう変更。
    - 権限がない場合は `PolicyPermissionDenied` を発生させ、JSONでは `403 Forbidden` + `error: <no_permissionメッセージ>` を返す。
    - レコードが存在しない場合は `404 Not Found` + `"XXX not found"` を返す。
  - `create`:
    - HTML側と同じく、`*Policy.build_for_create(current_user, params)` を利用して `is_reference` / `user_id` の整合をとったうえで保存する形に統一。
    - JSONマスタAPIでは `is_reference` パラメータ自体は許可しておらず、常に「ユーザー所有・非参照」として扱う前提は維持。
  - `update`:
    - HTML側と同様に、`*Policy.apply_update!(current_user, record, params)` を利用して `is_reference` 変更時の `user_id` 調整を行う（実際にはJSONマスタAPIでは `is_reference` を受け取っていないため、現状の挙動は「ユーザー所有レコードの通常更新」のまま）。
  - コントローラテスト:
    - 各 `Api::V1::Masters::*ControllerTest` で以下を明示的に検証するテストを追加:
      - 一覧に含まれる/含まれないレコード（自分のレコード・参照レコード・他人のレコード）。
      - 他ユーザーのレコードに対する `show` / `update` / `destroy` が `403 Forbidden` + `no_permission` メッセージになること。
      - 自分のレコードの `create` / `update` / `destroy` が成功することと、`user_id` / `is_reference` の値。
- **AI向け upsert API（`ai_create` / `ai_update`）の Policy 統合（Crops/Fertilizes/Pests）**
  - 対象エンドポイント:
    - `Api::V1::CropsController#ai_create`
    - `Api::V1::FertilizesController#ai_create` / `#ai_update`
    - `Api::V1::PestsController#ai_create` / `#ai_update`
  - 所有権・参照フラグ:
    - いずれも「ユーザー所有・非参照」を前提としており、作成・更新時の `user_id` / `is_reference` の決定は既存の `*Policy.build_for_create` / `find_editable!` のルールに揃えた。
    - Crops/Fertilizes/Pests の AI upsert で作成・更新されたレコードは、HTML/JSON の通常 CRUD と同じ不変条件（`is_reference: false` → `user_id` 必須）を満たす。
  - 実装ポイント:
    - `CropsController#ai_create`:
      - 件数制限チェック用のダミー `Crop` を直接 new する代わりに、`CropPolicy.build_for_create(current_user, name: 'dummy')` を利用することで通常作成パスと同じ制約を通す。
      - AGRR 応答で `crop_id` が返ってきた場合は `CropPolicy.find_editable!(current_user, crop_id)` を利用して「編集可能な既存作物」のみを更新対象とし、権限がなければ新規作成にフォールバック。
      - 新規作成時の `user_id` / `is_reference` は `CropPolicy.build_for_create(current_user, base_attrs)` の結果から反映し、Interactor/Gateway には Policy 済みの属性だけを渡す。
    - `FertilizesController#ai_create`:
      - AGRR からの値を `base_attrs` にまとめた上で、`name + user_id + is_reference: false` で既存肥料を検索し、見つかれば `base_attrs` のみで更新（`user_id` / `is_reference` は維持）。
      - 見つからない場合は `FertilizePolicy.build_for_create(current_user, base_attrs)` で所有権フラグを決め、`attrs_for_create` として Interactor に渡す。
      - `ai_update` では、更新対象の取得を `FertilizePolicy.find_editable!` に委譲しつつ、レスポンス仕様（見つからないときに 404 を返す）自体は従来どおり維持。
    - `PestsController#ai_create`:
      - 既存害虫の探索を「`name` + `is_reference: false` + `user_id: current_user.id`」に限定し、他ユーザーのユーザー害虫を誤って更新しないようにする。
      - 新規作成時は Pest 本体の属性を `base_attrs` にまとめ、`PestPolicy.build_for_create(current_user, {})` で決めた `user_id` / `is_reference` だけを合成して Gateway に渡す（温度プロファイルや防除方法の構造は Gateway 側に委譲）。
    - `PestsController#ai_update`:
      - 更新対象の取得を `PestPolicy.find_editable!(current_user, params[:id])` に変更し、権限のない ID を指定した場合は従来どおり 404 を返すようにしつつ、内部的には「編集可能性」を Policy で判定。
  - コントローラテスト:
    - `test/controllers/api/v1/crops_controller_test.rb` を新設し、AI 経由の作成・更新で
      - 新規作成時に `Crop.count` が 1 増加すること
      - 既存作物の `area_per_unit` / `revenue_per_area` / `groups` は更新される一方、`user_id` / `is_reference` は Policy どおりに維持されること
      を検証。
    - `FertilizesControllerTest` / `PestsControllerTest` では、既存テストに
      - 新規作成時の `assert_difference "Fertilize.count", +1` / `assert_difference "Pest.count", +1`
      - 作成/更新後の `user_id` / `is_reference` の検証
      を追加し、AI upsert の所有者・参照フラグのふるまいを明示的に固定。
  - Service 化（Crops）:
    - `CropAiUpsertService` を `app/services` に追加し、`Api::V1::CropsController#ai_create` からは
      - AGRR 応答の取得（`fetch_crop_info_from_agrr`）と
      - `CropAiUpsertService` の呼び出し
      だけを行う形に整理。
    - `CropAiUpsertService` 側で
      - 件数制限の事前バリデーション（`CropPolicy.build_for_create`）
      - 既存作物の更新 / 新規作成（`@create_interactor` 経由）
      - 生育ステージ関連モデル（`CropStage` / `TemperatureRequirement` / `SunshineRequirement` / `ThermalRequirement` / `NutrientRequirement`）の保存
      を一括して担当。
    - `test/services/crop_ai_upsert_service_test.rb` を追加し、
      - AGRR 応答相当の `crop_info` を直接与えた場合の新規作成パス・既存更新パス
      - Interactor に渡される属性（`name` / `variety` / `area_per_unit` / `revenue_per_area` / `groups` / `user_id` / `is_reference`）
      を単体テストで固定。
    - `docker compose run --rm test bundle exec rails test test/services/crop_ai_upsert_service_test.rb test/controllers/api/v1/crops_controller_test.rb` で
      サービス単体＋コントローラの組み合わせテストを実行し、いずれも成功（SimpleCov の閾値 10% 未満による終了コード 2 は、全体テストを走らせていないことに起因する既存設定）。
- **Farm / Field / Plan 系の Policy 導入（HTML / Masters API / Plans API）**
  - 対象Policy:
    - `FarmPolicy`: `user_owned_scope(user)`, `find_owned!(user, id)`, `build_for_create(user, attrs)`
    - `FieldPolicy`: `scope_for_farm(user, farm)`, `find_owned!(user, id)`, `build_for_create(user, farm, attrs)`
    - `PlanPolicy`: `private_scope(user)`, `find_private_owned!(user, id)`
  - HTMLコントローラへの適用:
    - `FarmsController`:
      - `create`: `FarmPolicy.build_for_create(current_user, farm_params)` 経由で「ユーザー所有・非参照」Farmを作成。
      - `set_farm`: 一般ユーザー側を `FarmPolicy.find_owned!(current_user, params[:id])` 経由に変更（管理者は従来どおり全農場アクセス可）。
    - `FieldsController`:
      - `set_farm`: 一般ユーザー側を `FarmPolicy.find_owned!(current_user, params[:farm_id])` 経由に変更（管理者は従来どおり全農場アクセス可）。
    - `PlansController`:
      - `set_plan`: `PlanPolicy.find_private_owned!(current_user, params[:id])` 経由で「private plan かつ本人所有」のみ取得。
      - `find_cultivation_plan_scope`: `PlanPolicy.private_scope(current_user)` 経由に変更。
  - APIコントローラへの適用:
    - `Api::V1::Masters::FarmsController`:
      - `index`: `FarmPolicy.user_owned_scope(current_user)` 経由で「ユーザー所有・非参照農場」のみ返却。
      - `create`: `FarmPolicy.build_for_create(current_user, farm_params)` 経由で作成。
      - `set_farm`: `FarmPolicy.find_owned!(current_user, params[:id])` 経由に変更。権限なし/存在しない場合は `"Farm not found"` の 404 JSON を返す。
    - `Api::V1::Masters::FieldsController`:
      - `index`: `FarmPolicy.find_owned!` で所有農場を確認後、`FieldPolicy.scope_for_farm(current_user, farm)` 経由で圃場一覧を返却。
      - `create`: `FarmPolicy.find_owned!` で所有農場を確認後、`FieldPolicy.build_for_create(current_user, farm, field_params)` 経由で作成。
      - `set_field`: `params[:farm_id]` あり時は `FarmPolicy.find_owned!` → `FieldPolicy.scope_for_farm(...).find(params[:id])`、なし時は `FieldPolicy.find_owned!(current_user, params[:id])` を利用。いずれも権限なし/存在しない場合は `"Field not found"` の 404 JSON を返す。
    - `Api::V1::Plans::CultivationPlansController`:
      - `find_api_cultivation_plan`: `PlanPolicy.private_scope(current_user).includes(...).find(params[:id])` 経由に変更し、「private plan かつ本人所有」のみ取得するルールをPolicy側に集約。
  - テスト:
    - `Api::V1::Masters::FarmsControllerTest` に `cannot access other user's farm` を追加し、他ユーザー農場への `show/update/destroy` がすべて 404 になることを検証。
    - `Api::V1::Masters::FieldsControllerTest` に `cannot access field that belongs to other user's farm` を追加し、他ユーザー農場の圃場への `show/update/destroy` が 404 になることを検証。
  - 実装詳細:
    - `PolicyPermissionDenied` を `app/policies/policy_permission_denied.rb` に切り出し、Rails のオートロードで確実に読まれるようにした。
    - Farm/Field/Plan 系は「参照データ（`is_reference: true`）」を扱わないため、参照マスタ系Policyとは異なり、`user_owned_scope` / `find_owned!` という命名で「ユーザー所有のみ」を明確化。
    - `FieldPolicy.scope_for_farm` は「指定ユーザーが所有する farm に属する Field のみ」を返すスコープを提供し、`FieldPolicy.find_owned!` は「farm.user_id == user.id（または admin）」な Field のみ取得。
- **Farm / Field / Plan 系の Policy 導入（FieldCultivations / PublicPlans 系）**
  - 対象Policy:
    - `PlanPolicy`: `public_scope`, `find_public!` を追加（public plan 用）
    - `FarmPolicy`: `reference_scope(region:)` を追加（参照農場取得用）
    - `CropPolicy`: `reference_scope(region:)` を追加（参照作物取得用）
  - APIコントローラへの適用:
    - `Api::V1::Plans::FieldCultivationsController`: `find_field_cultivation` を `PlanPolicy.find_private_owned!` 経由に変更。`show`, `update`, `climate_data` のすべてのアクションで private plan の所有権チェックを Policy 経由に統一。
    - `Api::V1::PublicPlans::FieldCultivationsController`: `show`, `climate_data`, `update` で `PlanPolicy.find_public!` を使用し、public plan のアクセス制御を Policy で明文化（認証不要で全公開）。
    - `Api::V1::PublicPlans::CultivationPlansController`: `find_api_cultivation_plan` で `PlanPolicy.find_public!` を使用し、public plan のアクセス制御を Policy で明文化。
  - HTMLコントローラへの適用:
    - `PublicPlansController`: `new`, `select_crop`, `create` で `FarmPolicy.reference_scope(region:)` / `CropPolicy.reference_scope(region:)` を使用し、参照農場・参照作物の取得ロジックを Policy 経由に統一。
  - テスト:
    - `Api::V1::Plans::FieldCultivationsControllerTest` に `show` と `update` のテストを追加。
    - `Api::V1::PublicPlans::FieldCultivationsControllerTest` を新規作成（認証不要の public plan アクセス制御をテスト）。
    - `Api::V1::PublicPlans::CultivationPlansControllerTest` を新規作成（public plan の取得をテスト）。
- **Pest–Crop / Pesticide–Crop/Pest 関連付けの Policy/Service 化**
  - 対象Policy/Service:
    - `PestCropAssociationPolicy`: 害虫と作物の関連付け可否を判定するPolicy
      - `accessible_crops_scope(pest, user:)`: 害虫に対して選択可能な作物のスコープを返す
      - `crop_accessible_for_pest?(crop, pest, user:)`: 特定の作物が害虫と関連付け可能か判定
      - ルール: region一致、参照害虫は参照作物のみ、ユーザー害虫はそのユーザーの非参照作物のみ
    - `PestCropAssociationService`: 害虫と作物の関連付け・更新を実行するService
      - `associate_crops(pest, crop_ids, user:)`: 害虫と作物を関連付ける
      - `update_crop_associations(pest, crop_ids, user:)`: 関連付けを更新（差分更新）
      - `normalize_crop_ids(pest, raw_ids, user:)`: 作物IDを正規化（選択可能な作物IDのみを抽出）
    - `PesticideAssociationPolicy`: 農薬に対して選択可能な作物・害虫のスコープを提供するPolicy
      - `accessible_crops_scope(user)`: 農薬に対して選択可能な作物のスコープを返す
      - `accessible_pests_scope(user)`: 農薬に対して選択可能な害虫のスコープを返す
      - ルール: 管理者=参照データ+自分のデータ、一般ユーザー=自分の非参照データのみ
  - HTMLコントローラへの適用:
    - `PestsController`:
      - `associate_crops`: `PestCropAssociationService.associate_crops` 経由
      - `update_crop_associations`: `PestCropAssociationService.update_crop_associations` 経由
      - `prepare_crop_selection_for`: `PestCropAssociationPolicy.accessible_crops_scope` 経由
      - `normalize_crop_ids_for`: `PestCropAssociationService.normalize_crop_ids` 経由
    - `PesticidesController`:
      - `load_crops_and_pests`: `PesticideAssociationPolicy.accessible_crops_scope` / `accessible_pests_scope` 経由
    - `Crops::PestsController`:
      - `index`: `PestPolicy.selectable_scope` 経由（参照害虫も含む）
      - `new`: `PestPolicy.selectable_scope` 経由（参照害虫も含む）
  - JSON APIコントローラへの適用:
    - `Api::V1::PestsController`:
      - `associate_crops_from_api`: `PestCropAssociationPolicy.crop_accessible_for_pest?` 経由（参照作物は常にアクセス可能なAI API特有のロジックを維持）
    - `Api::V1::Masters::Crops::PesticidesController`:
      - `index`: `PesticidePolicy.selectable_scope` 経由（参照農薬も含む）
    - `Api::V1::Masters::Crops::PestsController`:
      - `index`: `PestPolicy.selectable_scope` 経由（参照害虫も含む）
      - `create`: `PestPolicy.selectable_scope` 経由（参照害虫も含む）
  - Policy拡張:
    - `PestPolicy` と `PesticidePolicy` に `selectable_scope` メソッドを追加
      - `visible_scope`: 一般ユーザーは自分の非参照データのみ（既存の動作を維持）
      - `selectable_scope`: 一般ユーザーでも参照データを含む（選択候補として使用）
  - 直接SQLの削除:
    - すべてのコントローラで `where("is_reference = ? OR user_id = ?", true, current_user.id)` を削除し、Policyメソッドを使用
  - テスト:
    - `PestCropAssociationPolicy` のテストを追加
    - `PestCropAssociationService` のテストを追加
    - `PesticideAssociationPolicy` のテストを追加
    - 既存のコントローラテストがすべて通過（966 runs, 5822 assertions, 0 failures）

### 7.2 まだコントローラに残っている「参照まわり」ロジック

- **作成/更新時の参照フラグ操作ロジック（HTML側）**
  - 上記 7.1 のとおり、参照マスタ系 HTML コントローラ（`Pests`, `AgriculturalTasks`, `Crops`, `Fertilizes`, `Pesticides`, `InteractionRules`）については、
    - `create` / `update` の `is_reference` と `user_id` に関するロジックを `*Policy.build_for_create` / `apply_update!` に集約済み。
    - コントローラに残っているのは、**「一般ユーザーが参照フラグを操作しようとした場合に 403 相当（`reference_only_admin` / `reference_flag_admin_only`）を返すガード」のみ**。
  - このため、HTML 側については「参照フラグ操作ロジックのPolicy化」は完了している。
- **参照まわり以外のJSON APIロジック**
  - 参照マスタ系 JSON API については、index/show/create/update のOwnership・PermissionまわりはPolicy化済み。
  - それ以外のJSON API（AI upsert系、Farms/Fields/Plans系など）では、まだ `current_user` 起点の所有権チェックや upsert ロジックがコントローラ側に残っているため、今後Policy/Serviceに寄せていく。
  - 進捗（AI upsert 系）:
    - Crops:
      - `Api::V1::CropsController#ai_create` の upsert ロジックを `CropAiUpsertService` に切り出し完了。
      - コントローラは AGRR 応答の取得とサービス呼び出しのみを担当し、ユースケース本体はサービス側に集約。
      - `test/services/crop_ai_upsert_service_test.rb` を追加し、サービス単体で新規作成／既存更新の両パスと属性組み立てをテスト済み。
      - `docker compose run --rm test bundle exec rails test test/services/crop_ai_upsert_service_test.rb test/controllers/api/v1/crops_controller_test.rb` を実行し、機能テストは成功（この時点での line coverage は約 2.3%）。
    - Fertilizes / Pests:
      - 依然として `Api::V1::FertilizesController#ai_create/#ai_update` と `Api::V1::PestsController#ai_create/#ai_update` に upsert ロジックが残っている。
      - 次のステップで `FertilizeAiUpsertService` / `PestAiUpsertService` を導入し、Crops と同様に
        - コントローラは AGRR 応答取得＋サービス呼び出し
        - サービス側で Policy＋Interactor＋関連モデル保存のオーケストレーション
        - サービス単体テスト＋コントローラテストの組み合わせ実行とカバレッジ測定
        を行う予定。
- **Pest–Crop / Pesticide–Crop/Pest 関連付けロジック**
  - 上記 7.1 のとおり、`PestCropAssociationPolicy` / `PestCropAssociationService` / `PesticideAssociationPolicy` を実装し、すべてのコントローラでPolicy/Service経由に統一済み。
  - 直接SQLを書いていた箇所（`where("is_reference = ? OR user_id = ?", true, current_user.id)`）をすべて削除し、Policyメソッド（`visible_scope`, `selectable_scope`）を使用。
  - このため、「Pest–Crop / Pesticide–Crop/Pest 関連付けの Policy/Service 化」は完了している。
- **Farm / Field / Plan 系の所有権チェック（一部残存）**
  - 2025-11 時点の実装状況:
    - `FarmPolicy` / `FieldPolicy` / `PlanPolicy` を実装済み。
    - HTMLコントローラ:
      - `FarmsController`: `create` と `set_farm` を `FarmPolicy.build_for_create` / `find_owned!` 経由に変更済み。
      - `FieldsController`: `set_farm` を `FarmPolicy.find_owned!` 経由に変更済み。
      - `PlansController`: `set_plan` と `find_cultivation_plan_scope` を `PlanPolicy.find_private_owned!` / `private_scope` 経由に変更済み。
    - APIコントローラ:
      - `Api::V1::Masters::FarmsController`: `index` / `create` / `set_farm` を `FarmPolicy.user_owned_scope` / `build_for_create` / `find_owned!` 経由に変更済み。
      - `Api::V1::Masters::FieldsController`: `index` / `create` / `set_field` を `FarmPolicy.find_owned!` / `FieldPolicy.scope_for_farm` / `build_for_create` / `find_owned!` 経由に変更済み。
      - `Api::V1::Plans::CultivationPlansController`: `find_api_cultivation_plan` を `PlanPolicy.private_scope` 経由に変更済み。
    - テスト:
      - `Api::V1::Masters::FarmsControllerTest` に「他ユーザーの農場へのアクセスが 404 になる」テストを追加済み。
      - `Api::V1::Masters::FieldsControllerTest` に「他ユーザー農場の圃場へのアクセスが 404 になる」テストを追加済み。
  - **Farm / Field / Plan 系の Policy 導入は完了**:
    - `Api::V1::Plans::FieldCultivationsController`: `PlanPolicy.find_private_owned!` 経由に変更済み。
    - `Api::V1::PublicPlans::FieldCultivationsController`: `PlanPolicy.find_public!` 経由に変更済み。
    - `Api::V1::PublicPlans::CultivationPlansController`: `PlanPolicy.find_public!` 経由に変更済み。
    - `PublicPlansController`（HTML側）: `FarmPolicy.reference_scope` / `CropPolicy.reference_scope` 経由に変更済み。

### 7.3 実装済みの統一ポイント（2025-11-27 更新）

- **CRUDレスポンスConcern（`HtmlCrudResponder` / `ApiCrudResponder`）の導入** ✅ **完了**
  - **実装内容**:
    - `HtmlCrudResponder`: HTML向けの共通レスポンスConcern
      - `respond_to_create(resource, notice:, alert:, redirect_path:, render_action:)`
      - `respond_to_update(resource, notice:, alert:, redirect_path:, render_action:, update_result:)`
      - 成功時: `redirect_to` + flashメッセージ
      - 失敗時: `render :new/:edit, status: :unprocessable_entity`
    - `ApiCrudResponder`: JSON向けの共通レスポンスConcern
      - `respond_to_index(resources, status:)`
      - `respond_to_show(resource, status:)`
      - `respond_to_create(resource, status:, error_serializer:)`
      - `respond_to_update(resource, status:, error_serializer:, update_result:)`
      - `respond_to_destroy(resource, status:, error_serializer:, destroy_result:)`
      - 成功時: `render json: resource, status: ...`
      - 失敗時: `render json: { errors: resource.errors.full_messages }, status: :unprocessable_entity`
  - **適用済みコントローラ**:
    - HTML:
      - `FarmsController`, `CropsController`, `FieldsController`, `FertilizesController`, `PesticidesController`, `PestsController`, `AgriculturalTasksController`, `InteractionRulesController`
    - JSON:
      - `Api::V1::Masters::FarmsController`, `CropsController`, `FieldsController`, `FertilizesController`, `PesticidesController`, `PestsController`, `AgriculturalTasksController`, `InteractionRulesController`
  - **実装のポイント**:
    - `HtmlCrudResponder#respond_to_update` に `update_result` パラメータを追加し、元の動作（`update`メソッドの戻り値で判定）を維持
    - 各コントローラのテストにConcernの包含確認テストを追加
    - 全体テスト通過（993 runs, 5881 assertions, 0 failures）
  - **コミット**: 2025-11-27 完了

### 7.4 今後の具体的なステップ（優先度順）

1. **AI向け upsert サービスの残り実装（Fertilizes / Pests）**
   - **目標**:
     - Crops と同様に、AI upsert ロジックをサービス層に集約し、JSON API コントローラからユースケース本体を排除する。
   - **対象**:
     - `Api::V1::FertilizesController#ai_create` / `#ai_update`
     - `Api::V1::PestsController#ai_create` / `#ai_update`
   - **実装方針**:
     - `FertilizeAiUpsertService` / `PestAiUpsertService` を `app/services` に追加。
     - 既存の Policy（`FertilizePolicy` / `PestPolicy`）と Interactor を利用して、
       所有権・参照フラグ・関連モデルの作成／更新をサービス側で一括実行。
   - **テスト戦略**:
     - 先にサービス単体テストを追加し、その後、既存の API コントローラテストを
       サービス利用版に対応させる（振る舞いが変わらないことを重視）。
     - `docker compose run --rm test bundle exec rails test` で、対象サービステスト＋コントローラテストの組み合わせを優先的に実行し、
       カバレッジの実測値を必ず記録する。

2. **HTML/JSON両対応アクションのテンプレート化（`DualFormatResponder`）**
   - **目標**:
     - `respond_to do |format| ... format.html ... format.json ... end` パターンを統一
     - HTML/JSON両対応が必要なアクションのレスポンス処理を簡素化
   - **現状パターン**:
     - `Plans::TaskSchedulesController#show`
     - `DeletionUndosController#create`
     - `CropsController#toggle_task_template`
     - `Crops::TaskScheduleBlueprintsController#update_position`
   - **実装方針**:
     - `DualFormatResponder` Concernを追加
     - `render_html_and_json(html_template:, json_payload:, status:)` メソッドを提供
   - **対象コントローラ**:
     - `Plans::TaskSchedulesController`
     - `DeletionUndosController`
     - `CropsController`
     - `Crops::TaskScheduleBlueprintsController`
     - `SitemapsController`
   - **実装手順**:
     1. `DualFormatResponder` を試作
     2. ドライラン: 1つのコントローラに適用して適合性を確認
     3. カバレッジの実測: テストを行いカバレッジを確認（SimpleCov の閾値を意識しつつ、段階的に対象を広げる）
     4. テストの追加: 不足しているテストケースを追加
     5. 実装: すべての対象コントローラに適用
     6. テスト: 全体テストを実行して確認
     7. コミット
