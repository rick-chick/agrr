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
2. **削除 + Undo 処理のConcern統一**
   - パターンが揃っており、UI/UX上も重要な機能。
3. **CRUD 成功/失敗レスポンスのテンプレート化（HTML/JSON別Concern）**
   - APIのレスポンス仕様とHTMLのバリデーションエラー挙動を揃えられる。

### 4.2 中期的に整理したいポイント

4. **Pest–Crop / Pesticide–Crop/Pest 関連ポリシー**
   - ドメインルールが複雑なため、controller外に出す価値が大きい。
5. **Farm / Field / Plan のAccessPolicy**
   - 将来的に新規API/画面追加があっても、Policyの利用で安全にスケールできる。

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
    - `FarmPolicy`
      - `app/controllers/farms_controller.rb`
      - `app/controllers/api/v1/masters/farms_controller.rb`
    - `FieldPolicy`
      - `app/controllers/fields_controller.rb`
      - `app/controllers/farms/weather_data_controller.rb`
      - `app/controllers/api/v1/masters/fields_controller.rb`
      - `app/controllers/api/v1/plans/field_cultivations_controller.rb`
      - `app/controllers/api/v1/public_plans/field_cultivations_controller.rb`
    - `PlanPolicy`
      - `app/controllers/plans_controller.rb`
      - `app/controllers/public_plans_controller.rb`
      - `app/controllers/planning_schedules_controller.rb`
      - `app/controllers/api/v1/plans/cultivation_plans_controller.rb`
      - `app/controllers/api/v1/public_plans/cultivation_plans_controller.rb`
    - （必要に応じて）`FieldCultivationPolicy`
      - `app/controllers/api/v1/plans/field_cultivations_controller.rb`
      - `app/controllers/api/v1/public_plans/field_cultivations_controller.rb`

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
