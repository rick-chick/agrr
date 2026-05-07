# CA Violations Backlog

最終通し走査: 2026-05-06（セクション0 継続） / 2026-05-07（通し走査増分: `lib/domain`・`lib/presenters`・`app/controllers/api` grep、`Plans::TaskSchedulesController` 修正） / 直近補足: 2026-05-07（フロント adapters 意味読み）

## 修正単位

- **解消済み（2026-05-07）**: **HTML** `Crops::AgriculturalTasksController` の `index` / `new` / `create` / `update` / `destroy` から AR 直叩き・コントローラ内業務分岐を除去。`CropMastersTaskTemplateIndex/Create/Update/DestroyInteractor` を API マスタと共有、`CropNestedCropTaskTemplatesNewInteractor` と `CropGateway#selectable_agricultural_task_picklist_rows_for_nested_templates` を追加。`create` で `agricultural_task_id` が空のときの `redirect_to` のみコントローラに残置（DTO 成立前のガード）。Application edge 禁止 3・4。
- **解消済み（2026-05-07・セクション0）**: バックログ先頭の「HTML/API マスタで参照・admin 早期分岐の再サンプリング」— 列挙済みマスタに同パターンの残りなし。上記 `Crops::AgriculturalTasksController` は別種のエッジ肥大（AR）として扱い解消。
- **解消済み（2026-05-06）**: `Api::V1::Masters::Crops::AgriculturalTasksController` の `index` / `update` / `destroy` を Interactor + Presenter 経路に統一（Application edge 禁止 3・4）。ゲートウェイ IF は変更なし。
- **解消済み（2026-05-06）**: **HTML** `FertilizesController` の `create` / `update` 先頭の参照データ・admin 分岐（`Application edge` 禁止 4）を削除。`FertilizeCreateInteractor` / `FertilizeUpdateInteractor` の既存判定に一本化し、HTML Presenter で当該失敗メッセージ時の `redirect_to`（従来 UX）を再現。
- **解消済み（2026-05-06）**: **HTML** `PestsController` の `update` 先頭の `is_reference` / admin 早期 `redirect_to` を削除（`Application edge` 禁止 4）。`PestUpdateInteractor` と既存の `PestUpdateHtmlPresenter`（参照フラグ失敗時のリダイレクト）に一本化。**create** は元々コントローラ二重チェックなし。
- **解消済み（2026-05-06）**: **HTML** `AgriculturalTasksController` の `create` / `update` 先頭の参照・admin 分岐を削除。`AgriculturalTaskCreateInteractor` / `AgriculturalTaskUpdateInteractor` に `translator` を注入し参照ルールを明示、**create** は `is_reference` をゲートウェイへ渡すよう修正。HTML Presenter で既存のリダイレクト UX を再現。API マスタ `AgriculturalTasksController` も同じ Interactor 引数に合わせる。
- **解消済み（2026-05-06）**: **HTML** `PesticidesController` の `create` / `update` 先頭の `is_reference` 早期 `redirect_to` を削除。`PesticideCreateInteractor` / `PesticideUpdateInteractor` に `translator` を注入し、`PesticideUpdateInputDto` に `is_reference` を追加。HTML / API Presenter で参照失敗時の UX・403 を再現。
- **解消済み（2026-05-06）**: **HTML** `InteractionRulesController` の `create` / `update` 先頭の参照・admin 早期 `redirect_to` を削除。`InteractionRuleCreateInteractor` / `InteractionRuleUpdateInteractor` に `translator` を注入し、`InteractionRuleUpdateInputDto` に `is_reference` を追加。HTML / API Presenter で参照失敗時の UX・403 を再現。
- **解消済み（2026-05-07）**: **HTML** `Crops::TaskScheduleBlueprintsController` の `update_position` / `destroy` を `CropTaskScheduleBlueprintUpdatePositionInteractor` / `CropTaskScheduleBlueprintDestroyInteractor` と HTML プレゼンタに寄せ、`CompositionRoot` 直呼び・`can_edit_crop?`・`Rails.logger` を除去。`CropGateway#update_task_schedule_blueprint_position_for_user` で編集認可＋ID 解決をゲートウェイに集約（Application edge 禁止 3・4）。
- **解消済み（2026-05-07・セクション0）**: HTML `app/controllers/crops/*` の再サンプリング — `TaskScheduleBlueprints` / `AgriculturalTasks` / `Pests` に AR 直叩き・参照/admin 早期分岐なし（`agricultural_tasks#create` の `agricultural_task_id` 空ガードは ARCHITECTURE の DTO 成立前ガードとして既知許容）。
- **解消済み（2026-05-07）**: **HTML** `PublicPlansController` の `select_farm_size` / `select_crop` / `create` から `Farm` / `Crop` の AR 直叩きを除去。ウィザード段は `PublicPlanWizardLoadFarmInteractor` / `PublicPlanWizardPrepareCropStepInteractor` と HTML プレゼンタ、`create` は既存 `PublicPlanCreateInteractor` + `PublicPlanCreateHtmlPresenter` に統一。`PublicPlanCreateInputDto#redirect_path` とジョブチェーン `redirect_path` 引き回し、`PublicPlanActiveRecordGateway#find_crops` で参照作物＋任意地域絞り込み。作物ゼロ時は `PublicPlanCreateFailureDto` + `public_plan_render_create_no_crops_failure!` で 422 再描画（Application edge 禁止 **4**）。
- **解消済み（2026-05-07）**: **HTML** `AgriculturalTasksController` の作物選択データを `CropGateway#list_reference_crop_entities` / `list_non_reference_crops_for_user_id_ordered`、テンプレート紐付け ID を `AgriculturalTaskGateway#linked_crop_ids_for_task_templates` に移行。`CropEntity#is_reference?` をビュー互換のため追加（Application edge 禁止 **4**）。
- **解消済み（2026-05-07・セクション0）**: フロント `frontend/src/app` の **Angular 層境界の機械点検**（`components`・`services`・`domain` の `adapters/` 直 import、`usecase` の非 `*.providers.ts` からの `adapters/`、`usecase` / `domain` の `HttpClient`）。**違反なし**（`adapters/` 参照は `*.providers.ts` と `app.config.ts` のみ。`gantt-chart.component.ts` の `@angular/common/http` は `HttpErrorResponse` 型のみ）。
- **解消済み（2026-05-07・セクション0）**: フロント `adapters/**/*.ts` の **意味読み点検**（辞書順で `agricultural-tasks`〜`public-plans` を Read、404→`null` 等の境界変換・複合プレゼンタを確認、`grep` で `usecase/` import がゲートウェイ／出力ポート／DTO に限定されることを確認）。ゲートウェイは HTTP・クエリ組み立て・境界変換に収まり、`PrivatePlanCreateApiGateway#fetchFarm` の `totalArea` は API レスポンスの正規化。プレゼンターは DTO→view・flash／undo／Router／i18n のみ。**ARCHITECTURE.md「Frontend: Angular layers」および Gateway boundary（表現非依存）に照らす新規違反なし**。補足: `PublicPlanResultsPresenter` は `LoadPublicPlanResultsOutputPort` と `SavePublicPlanOutputPort` の両実装のため `present` がユニオン分岐になるが、成功／失敗の判断は各 UseCase 内。
- **解消済み（2026-05-07・セクション0）**: **HTML** `Plans::TaskSchedulesController` の `before_action :set_cultivation_plan`（`current_user.cultivation_plans.plan_type_private.find`）を除去。認可・読込は既存の `CultivationPlanActiveRecordGateway#task_schedule_timeline_read_model`（`PlanPolicy.private_scope`）に一本化。ページヘッダ用の農場名・総面積は `TaskScheduleTimelineReadModel::PlanRead` に追加し、`TaskScheduleHtmlShellPlan` を HTML プレゼンタが組み立てて `@cultivation_plan` に渡す（AR 非依存）。ルートヘルパは id 明示に変更。Application edge 禁止 **4**。
- **解消済み（2026-05-07）**: **HTML** `CropsController` の `new` / `edit` / `after_crop_create_failure` / `after_crop_update_failure` にあった **ActiveRecord の直接生成・ネスト補助・assign_attributes** をやめ、`CropGateway` の `build_blank_crop_for_html_form` / `prepare_crop_record_for_edit_html_form!` / `build_new_crop_with_attributes_for_html_form` / `merge_edit_crop_params_for_html_form!` に集約（`Adapters::Crop::Gateways::CropMemoryGateway`）。コントローラはゲートウェイ呼び出しと `@crop.valid?` のみ。Application edge 禁止 **4**。
- **解消済み（2026-05-07）**: **`CropsController#destroy` の format.json** — `DeletionUndo::HtmlMasterScheduleInvoker` に AR を渡さず `resource_type` / `resource_id` のみ（`DeletionUndoScheduleInputDto` と整合）。`toast_message: nil` で Undo ゲートウェイの `default_toast_message` を利用（文言キーは `crops.undo.toast` から `deletion_undo.toast_message` 側に寄る）。`destroy` を `set_crop` から外し、JSON/HTML とも削除時に事前の作物読込を不要化。Application edge 禁止 **4**。
- **解消済み（2026-05-07）**: **`DeletionUndo::HtmlMasterScheduleInvoker` の `record:` 依存除去** — HTML `destroy` の **JSON** 枝で、`AgriculturalTasksController` / `PestsController` / `PesticidesController` / `FertilizesController` が作物削除と同様に `resource_type` / `resource_id` のみを渡すよう統一。存在しない ID の HTML 削除では、`soft_destroy_with_undo` の `rescue StandardError` が `Domain::Shared::Exceptions::RecordNotFound` を飲み込まないよう各ゲートウェイで再送出し、DestroyInteractor は `translator.t("*.flash.not_found")` で flash を揃える。
- **解消済み（2026-05-07）**: **`Farms::WeatherDataController`** — AR 直叩き・`WeatherDataGatewayFactory`・予測分岐の主スイッチを除去。`FarmWeatherDataAccessInteractor` + `FarmWeatherDataAccessPresenter`（Interactor／DTO／ポート名に Json を含めず禁止 **4** 準拠）、`FarmGateway` の所有農場／管理者 id 解決（分岐は Interactor）、`PredictWeatherStandaloneEnqueueActiveJobAdapter` で `ActiveJob::EnqueueError` を modeled 結果へ、`FarmWeatherPredictionPayloadParseAdapter` で時刻・日付境界。`index` の Hash 行はシンボルキー参照に修正。Application edge 禁止 **3**・**4**。`lib/domain` の期間算術は `Date#<<` と秒差（禁止 **4** の duration 回避）。
- **次に先頭で固定する修正単位（未着手）**: 通し走査の継続 — `app/controllers/**/*_controller.rb` の HTML エッジで、Interactor 未到達の AR／業務分岐の有無を意味読みで先頭候補から固定（辞書順）。

## セクション0 通し走査メモ（2026-05-06 継続）

`ARCHITECTURE.md` 本文を手動再読しつつ、次を **Glob / Grep / 代表ファイル Read** で照合（1 パス全捕捉ではない。外側ループの再訪を前提）。

| 観点 | 結果（当該イテレーション） |
|------|---------------------------|
| `lib/domain` の `Rails.` / `CompositionRoot` / `Adapters::` **実コード参照** | 検出なし（コメント・ポート説明のみ） |
| `lib/presenters` の `CompositionRoot` / ゲートウェイ再取得 | 検出なし |
| `app/controllers/api/v1` の `rescue` / `rescue_from` | 該当なし |
| `frontend` `components/**/*.component.ts` の `adapters/` 直 import | 該当なし |
| HTML `Plans::TaskSchedulesController` の `before_action` AR 読込 | **解消**（2026-05-07・上記修正単位） |
| 既知の意図的 `rescue`（天気・Health・Auth） | 下記「残置」のまま |

## スキャン補足

- 2026-05-07: **HTML `app/controllers/crops/`** — ネスト作物系コントローラを `grep` / Read で再確認。Interactor＋`CompositionRoot` 注入パターンで Application edge 3・4 の新規違反なし。`Crops::AgriculturalTasksController#create` の空 ID `redirect_to` のみ既知ガード。
- 2026-05-07: **HTML 公開プラン・農業タスク** — `PublicPlansController` / `AgriculturalTasksController` のコントローラ内 AR をゲートウェイ＋Interactor＋Presenter に移し、バックログ該当項目を解消。
- 2026-05-06: **Angular 全コンポーネント（`components/**/*.component.ts`）** — `adapters/` 直 import を廃止し、各 feature の `usecase/**/\*.providers.ts` に DI 配線を集約（plans / public-plans / api-key / マスタ各種 / 既存の農業タスク・contact 等を含む）。`inject(CROP_GATEWAY)` のように**注入トークン**は引き続き usecase から import。
- 2026-05-06: **Angular お問い合わせフォーム** — `contact-form.component.ts` の `CONTACT_GATEWAY_PROVIDER`（adapters）直 import を廃止し、`usecase/contact/contact-form.providers.ts` に集約（`SEND_CONTACT_MESSAGE_OUTPUT_PORT` の `useExisting: ContactFormComponent` は循環回避のためコンポーネントに残置）。
- 2026-05-06: **Angular 農業タスク詳細・編集** — detail / edit コンポーネントの adapters 直 import を廃止し、`agricultural-task-detail.providers.ts` / `agricultural-task-edit.providers.ts` に集約（edit の spec は Presenter import を providers 経由に変更）。
- 2026-05-06: **Angular 農業タスク新規** — `agricultural-task-create.component.ts` の adapters 直 import を廃止し、`agricultural-task-create.providers.ts` に集約。
- 2026-05-06: **Angular 農業タスク一覧** — `agricultural-task-list.component.ts` の adapters 直 import を廃止し、`usecase/agricultural-tasks/agricultural-task-list.providers.ts` に DI 配線を集約（Presenter の型用再エクスポートは usecase ファイルのみ）。
- 2026-05-06: **API 作物 AI** — `CropAiUpsertService` を廃止し、`CropApiAiCreateInteractor` + `Adapters::Crop::CropAiUpsertActiveRecordPersistence`（ポート `CropAiUpsertPersistencePort`）に分割。`ApiJsonResult#success?` を追加。匿名ユーザーは害虫・肥料 AI と同様に 401（テスト追加）。
- 2026-05-06: **Frontend（Angular）サンプリング（経過）** — 当初サンプルでは `components/` から `adapters/` への直 import が残っていたが、配線は `usecase/**/*.providers.ts` へ集約済み。**2026-05-06 再確認**: `frontend/src/app/components/**/*.ts` からの `adapters/` 直 import は検出されず。レイヤ境界の維持は引き続き契約テスト・通し走査で確認する。
- 2026-05-06: **API 害虫・肥料 AI** — `PestsController` / `FertilizesController` の `ai_create` / `ai_update` を `PestApiAiCreateInteractor` / `PestApiAiUpdateInteractor` / `FertilizeApiAiCreateInteractor` / `FertilizeApiAiUpdateInteractor` に集約。agrr 応答の解釈は `PestAiDaemonResponseInterpreter`、肥料ペイロード正規化は `FertilizeAiAgrrPayloadNormalizer`。匿名ユーザー判定は `UserDto#anonymous?`（Mapper で `User` から付与）。作物関連付けは `CompositionRoot` が注入する runner で AR `User` を閉じ込める。
- 2026-05-06: **Application edge 禁止4（API）** — `app/controllers/api/v1` の AR / ActiveStorage / User 直叩きをゲートウェイ・Interactor・Presenter に寄せた（Plans 一覧・詳細、PublicPlans `save_plan`、Wizard `crops`、公開 cultivation_plans `get_crop_for_add_crop`、マスタ Base のセッション/APIキー解決、作物×農業タスク API、作物×害虫 destroy、API キー生成、Files CRUD、Backdoor users/db_stats、作物 AI の既存検索は Pest/Fertilize ゲートウェイへ）。
- 2026-05-06: `Adapters::ActiveStorage` 名前空間が Rails の `ActiveStorage` と衝突したため、Blob API アダプタは `Adapters::StoredBlobs` に変更。`plan_copy_gateway` の `ActiveStorage::Attachment` 参照は `::ActiveStorage` に明示。
- 2026-05-07: **フロント層境界（機械点検）** — 上記「解消済み（2026-05-07・セクション0）」のとおり。`adapters/**/*.ts` の意味読みは同バックログ項で完了。
- 2026-05-07: **通し走査（増分・grep）** — `lib/domain` の `Rails.` / `CompositionRoot.` / `ActiveRecord::`（実コード）、`lib/presenters` の `CompositionRoot`、`app/controllers/api` の `rescue` / `rescue_from`。**該当実コードなし**（`lib/domain` の一致はコメントのみ）。禁止 1〜30 の全項の意味読み・Glob 網羅はバックログ先頭の通し走査で継続。
- 2026-05-07: **通し走査（HTML コントローラ grep）** — `app/controllers/**/*_controller.rb` で `Crop\.|Farm\.|\.cultivation_plans` 等。**債務候補**: `CropsController` の AR フォーム周りは `CropGateway` HTML 用 API で解消済み。`Farms::WeatherDataController` は **2026-05-07 解消**（Interactor＋Presenter）。`Plans::TaskSchedulesController` は当イテレーションで解消。
- 2026-05-06: フロントの**全 `*.ts` 意味読み通し走査**は未完了（当時）。`components` から `adapters/` への直 import はスポットでゼロ。

## 残置（意図・別単位）

- `Farms::WeatherDataController` の `PredictWeatherDataJob.perform_later` 周りの `rescue ActiveJob::EnqueueError`（キュー投入失敗のユーザー向けレスポンス）。
- `HealthController` の DB 例外のみを拾う `rescue *HEALTH_DB_EXCEPTIONS`（ファイル内コメントのとおり意図的）。
- `AuthController#allowed_return_to?` 等の `URI::InvalidURIError` rescue（URL 検証の局所ガード）。
