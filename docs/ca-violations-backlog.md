# CA Violations Backlog

最終通し走査: 2026-05-06（セクション0 継続） / 2026-05-07（通し走査増分） / 2026-05-08（CA 対応計画: Gateway 命名リネーム＋裏取り grep/read） / **2026-05-09（§F Farm `find_authorized_model_*` 公開 API 除去）**: `FarmGateway` から `find_authorized_model_for_view` / `find_authorized_model_for_edit` を削除し、AR ロードは `FarmActiveRecordGateway` の private `authorized_farm_record_for_*!` のみ。`AuthorizedFarmLoadedDto#persisted_farm` は未処理（§F 別行）。 / **2026-05-08（CA ワークフロー再走査）**: `ARCHITECTURE.md` `## What we require` と禁止 1〜30 を再読し、代表 grep（`lib/domain` の `Rails.` / `CompositionRoot` / `Adapters::` / `ActiveRecord::` は実コード一致なし、コメント・例外説明のみ／`lib/presenters` の `CompositionRoot` なし／`app/controllers/api` の `rescue` / `rescue_from` なし／`frontend/.../components` の `adapters/` 直 import なし／`lib/presenters` の `perform_later` なし／`lib/domain` の `*Gateway.default` なし／`usecase` の `adapters/` import はすべて `*.providers.ts`）。**新規未処理の逸脱なし**。 / **2026-05-08（計画通し走査）**: `ARCHITECTURE.md` `## What we require` と禁止 1〜30 を再読し、`lib/domain`・`lib/presenters`・`app/controllers/api`・`frontend/src/app/components` を対象に Glob/grep による意味読み。**ブロッキング級の新規逸脱なし**（既存の許容 `rescue` は backlog「残置」のまま）。**2026-05-08（空 backlog 裏取り）**: 未処理キュー空を契機に走査し、`PrivatePlanHtmlCreateInteractor` 等の **Interactor/DTO/OutputPort 名の `Html`** を検出 → `PrivatePlanCreateFromSession*` にリネーム（Interactors 禁止 **4**）。**2026-05-08（チャネル語 grep 洗い出し）**: 下記「洗い出し一覧」と未処理 `[ ]` を追記（通し走査の代替ではなく候補一覧）。**2026-05-08（cultivation_plan add_crop）**: `ApiAddCropOutputPort`→`AddCropOutputPort`、`ApiAddCropPresenter`→`AddCropPresenter`（`CultivationPlanRestBaseController#add_crop`）。**2026-05-08（cultivation_plan add_field）**: `ApiAddFieldOutputPort`→`AddFieldOutputPort`、`ApiAddFieldPresenter`→`AddFieldPresenter`（`#add_field`）。**2026-05-08（cultivation_plan remove_field）**: `ApiRemoveField*`→`RemoveField*`。**2026-05-08（cultivation_plan manual adjust）**: `ApiPlanAdjust*`→`ManualPlanAdjust*`。**2026-05-08（cultivation_plan plan data）**: `ApiPlanData*`→`RetrieveCultivationPlan*`。**2026-05-08（private plan initialize API DTO/ポート）**: `ApiPrivatePlanCreate*`→`PrivatePlanInitializeFromSelection*`。**2026-05-08（shared HttpJsonEnvelope）**: `ApiJsonResult`→`HttpJsonEnvelope`。**2026-05-08（api_keys）**: `ApiUserApiKeyRotateInteractor`→`UserApiKeyRotateInteractor`。**2026-05-08（file_blob gateway）**: `ApiFileBlob*`→`FileBlob*` / `#file_blob_gateway`。**2026-05-08（plans API list presenter）**: `ApiV1PrivatePlansListPresenter`→`PrivateOwnedPlansListPresenter`。**2026-05-08（plans API show presenter）**: `ApiV1PrivatePlanShowPresenter`→`PrivateOwnedPlanDetailPresenter`。**2026-05-08（files JSON presenter）**: `ApiV1FilesJsonPresenter`→`FileBlobJsonPresenter`。**2026-05-08（ApiWeather BC）**: `[ADR 0010](adr/0010-domain-api-weather-bounded-context-naming.md)` で `Domain::ApiWeather` を外部気象連携 BC 名として固定—HTTP チャネル語の除去対象から除外（禁止 **4** の意味読み）。**2026-05-08（継続・空 backlog 通し走査）**: 代表 grep（`lib/domain` の `Rails.` / `CompositionRoot.` / `ActiveRecord::` 実コード、`lib/presenters` の `CompositionRoot`、`app/controllers/api` の `rescue`、`frontend` components の `adapters/` 直 import）—**新規 backlog 候補なし**（`lib/domain` 一致はコメントのみ）。`test-common` Rails 2053 runs / Frontend 375 GREEN。

**2026-05-09（Gateway／DTO の ActiveRecord 越境）**: コードベース横断の洗い出しを「洗い出し一覧 §F」と、その直下の **未処理 `[ ]` TODO** に記録（`ARCHITECTURE.md` Gateway 境界・`lib/domain/` 禁止 **3**・Rationalizations **4**）。 / **2026-05-12（§F Pest `pest_record:` AR 越境解消）**: `PestGateway` 公開メソッドの `pest_record:` を `pest_snapshot: PestCropNestSnapshotDto` に置換、`prepare_crop_nested_pest_for_edit_form!` を `find_pest_in_crop(for_edit_form:)` に統合、`find_user_owned_non_reference_pest_record_by_name`→`find_user_owned_non_reference_pest_by_name` リネーム。全追従ファイル（Interactors 3 + PestAiCreate + Presenters 3）を更新。`lib/domain/` 禁止 **3** の当該行解消。

## 洗い出し一覧（機械探索・2026-05-08／§F 増分 2026-05-09）

根拠: `ARCHITECTURE.md` **Prohibited practices → Interactors** 項 **4**（チャネル／画面形状を interactor・gateway の**名前・メソッド名**、およびポートを跨ぐ **DTO/型名** に載せない）。`rg` の一致のみを違反認定にしない—本一覧は探索ログ。除外は意味読みで各イテレーションに記録する。

### A. `lib/domain` — 型名に `Html` / `Json` / `Page`（ポート・DTO）


| 語    | ファイル（2026-05-08 解消後の現行パス）                                           |
| ---- | ------------------------------------------------------------------- |
| （解消） | `cultivation_plan/ports/public_plan_results_output_port.rb`         |
| （解消） | `cultivation_plan/dtos/task_schedule_timeline_shell_plan.rb`        |
| （解消） | `cultivation_plan/ports/task_schedule_item_mutation_output_port.rb` |
| （解消） | `cultivation_plan/dtos/public_plan_results_read_model.rb`           |


### B. `lib/composition_root.rb` と `lib/adapters/cultivation_plan/` — 私有計画まわりの `html`


| 識別子                                       | 所在                                                                         |
| ----------------------------------------- | -------------------------------------------------------------------------- |
| `private_plan_post_create_job_chain`      | `CompositionRoot`                                                          |
| `PrivatePlanPostCreateJobChain`           | `lib/adapters/cultivation_plan/private_plan_post_create_job_chain.rb`      |
| `private_plan_select_crop_context_runner` | `CompositionRoot`                                                          |
| `PrivatePlanSelectCropContextRunner`      | `lib/adapters/cultivation_plan/private_plan_select_crop_context_runner.rb` |


### C. `lib/adapters` — 表現由来パラメータ


| パターン                           | ファイル                                                                |
| ------------------------------ | ------------------------------------------------------------------- |
| `include_weather_data_fields:` | `lib/adapters/farm/mappers/farm_mapper.rb`（旧 `for_html_detail` は解消） |


### D. `lib/domain` — 型名に `Api` / `ApiV1`（チャネル想起の**要レビュー**）

`Domain::ApiWeather`（`lib/domain/api_weather/`**）— **除外方針は `[ADR 0010](adr/0010-domain-api-weather-bounded-context-naming.md)` に固定**（外部気象デーモン連携 BC; Rails HTTP API チャネル語ではない）。`Domain::ApiKeys`（ユーザー API キー認証）も **製品語**として機械一致のみでは違反にしない。それ以外の grep ヒット例（抜粋・重複あり）:

- （解消・2026-05-08）`file_blob/interactors/` — `ApiV1Files*` → `FileBlobListInteractor` / `FileBlobShowInteractor` / `FileBlobCreateInteractor` / `FileBlobDestroyInteractor`
- （解消・2026-05-08）`cultivation_plan/interactors/api_v1_private_plan_*` — `PrivateOwnedPlansListInteractor` / `PrivateOwnedPlanDetailInteractor` / `PrivatePlanInitializeFromSelectionInteractor`
- （解消・2026-05-08）`cultivation_plan/ports/api_*`、`cultivation_plan/dtos/api_private_plan_create_*` — REST 用ポート・DTO・Presenter を `Add*` / `Remove*` / `ManualPlanAdjust*` / `RetrieveCultivationPlan*` / `PrivatePlanInitializeFromSelection*` に統一（`ApiPrivatePlanCreate*` 除去）。
- （解消・2026-05-08）`crop/ports/masters_*_requirement_output_port.rb`（旧 `masters_*_requirement_api_output_port.rb` / `Masters*RequirementApiOutputPort`）
- （解消・2026-05-08）`field_cultivation/interactors/field_cultivation_api_*`（Interactor のみ）— `FieldCultivationShowInteractor` / `FieldCultivationUpdateInteractor`
- （解消・2026-05-08）`cultivation_plan/interactors/public_plan_api_save_plan_interactor.rb` — `PublicPlanSaveByPlanIdInteractor`
- （解消・2026-05-08）`crop/interactors/crop_api_ai_create_interactor.rb` — `CropAiCreateInteractor`（`CompositionRoot#crop_ai_create_interactor`）
- （解消・2026-05-08）`shared/dtos/http_json_envelope.rb`（旧 `api_json_result.rb` / `ApiJsonResult`）
- （解消・2026-05-08）`api_keys/interactors/user_api_key_rotate_interactor.rb`（旧 `api_user_api_key_rotate_interactor.rb`）
- （解消・2026-05-08）`public_plan/dtos/entry_schedule_failure_dto.rb`（旧 `entry_schedule_api_failure_dto.rb` / `EntryScheduleApiFailureDto`）
- （解消・2026-05-08）`crop/dtos/masters_crop_task_template_masters_failure_dto.rb`（旧 `masters_crop_task_template_masters_api_failure_dto.rb` / `MastersCropTaskTemplateMastersApiFailureDto`）

### E. `lib/presenters/html/`** — `*HtmlPresenter`

慣習命名。**禁止4の主戦場はドメイン側ポート**（例: A の ~~`PublicPlanResultsHtmlOutputPort`~~ → `PublicPlanResultsOutputPort` に解消）。プレゼンタの `Html` 接尾辞は本バックログでは**任意の後段**（ドメインリネームと同時に触るかはイテレーションで決める）。

### F. Gateway／DTO が ActiveRecord をユースケース境界へ返す（2026-05-09 洗い出し）

根拠: `ARCHITECTURE.md` **What we require**（Gateway は entities/DTOs を返す）、**Prohibited** `lib/domain/` **3**（ORM/came through gateway）、**Rationalizations** **4**（名目 Gateway が AR を返す）。以下は **未処理 `[ ]` TODO**（実装は契約・テスト・呼び出し更新とセット）。

#### Gateway 公開 API が AR を返す

- （解消済み・2026-05-09）`FarmGateway` / `FarmActiveRecordGateway`: 公開 IF から `find_authorized_model_for_view` / `find_authorized_model_for_edit` を削除。AR はアダプター private `authorized_farm_record_for_view!` / `authorized_farm_record_for_edit!` のみ（`find_authorized_for_*` / `find_authorized_farm_loaded_bundle!` は従来どおり）。`AuthorizedFarmLoadedDto#persisted_farm` の AR 同梱は下記「DTO」の行が未処理。
- （解消済み・2026-05-12）`CropGateway` / `CropMemoryGateway`: 公開 IF から `find_authorized_model_for_view` / `find_authorized_model_for_edit` を削除。`CropRegenerateTaskScheduleBlueprintsInteractor` は `find_authorized_for_edit`（Entity）に変更し、下流 `CropTaskScheduleBlueprintRegenerationGateway#regenerate_from_crop!` のシグネチャを `crop:` AR → `crop_id:` に変更（アダプタ内部でロード）。`CropToggleTaskTemplateInteractor` も `find_authorized_for_edit`（Entity）に変更し、`CropTaskTemplateToggleGateway#toggle_build_snapshot!` のシグネチャを `crop:, agricultural_task:` AR → `crop_id:, agricultural_task_id:` に変更（アダプタ内部でロード）。AR はアダプター private に集約。
- （解消済み・2026-05-12）`PestGateway` / `PestActiveRecordGateway`: 公開 IF から `find_authorized_model_for_view` / `find_authorized_model_for_edit` を削除。AR はアダプター private に集約（`find_authorized_for_edit` / `find_authorized_pest_loaded_bundle!` の内部ヘルパー）。`PestMemoryGateway` には元から実装なし。
- （解消済み・2026-05-12）`PesticideGateway` / `PesticideActiveRecordGateway`: 公開 IF から `find_authorized_model_for_view` / `find_authorized_model_for_edit` を削除。AR はアダプター private に集約。
- （解消済み・2026-05-12）`FertilizeGateway` / `FertilizeActiveRecordGateway`: 公開 IF から `find_authorized_model_for_view` / `find_authorized_model_for_edit` を削除。AR はアダプター private に集約。`FertilizeUpdateInteractor` の failure 経路を `FertilizeMasterFormSnapshot`（純 DTO）に変更したことで `find_authorized_model_for_edit` の呼び出し元がなくなり private 化完了。`AuthorizedFertilizeLoadedDto#persisted_fertilize` は同日別コミットで解消済み。
- （解消済み・2026-05-12）`InteractionRuleGateway` / `InteractionRuleActiveRecordGateway`: 公開 IF から `find_authorized_model_for_view` / `find_authorized_model_for_edit` を削除。AR はアダプター private に集約。
- （解消済み・2026-05-12）`AgriculturalTaskGateway` / `AgriculturalTaskActiveRecordGateway`: 公開 IF から `find_authorized_model_for_view` / `find_authorized_model_for_edit` を削除。`AgriculturalTaskEntity` に `is_reference?` alias を追加。`preview_agricultural_task_for_edit_crop_selection` のシグネチャを `base_task:` (AR) → `base_entity:` (Entity) に変更し戻り値も Entity に統一（差分があれば `to_hash.merge` で新 Entity を構築）。`AgriculturalTaskEditFormCropSelectionLoadInteractor` を `find_authorized_for_edit`（Entity）使用に更新。AR はアダプター private に集約。

#### `find_model` が AR を返す

- （解消済み・2026-05-12）`CropGateway#find_model` と `CropMemoryGateway#find_model` — `CropEntity` を返すよう変更。`CropEntity#to_param` を追加（path helpers 互換）。`CropsNestedPestsNewInteractor` を `crop_id:` シグネチャに変更し `pest_ids_linked_to_crop(crop_id:)` を新設ゲートウェイメソッドで代替（`CropPest.where(crop_id:).pluck(:pest_id)`）。`_form.html.erb` の `form_with(model: [crop, pest])` を `form_with(model: pest, url: ...)` に変更（entity は `to_model` 未実装のため）。`crop_path(@crop)` 等の path helpers は `to_param` で継続動作。
- （解消済み・2026-05-12）`AgriculturalTaskGateway#find_model` と `AgriculturalTaskActiveRecordGateway#find_model` — `AgriculturalTaskEntity` を返すよう変更。`CropToggleTaskTemplateInteractor` は entity を受け取り存在確認のみ（AR は `CropTaskTemplateToggleActiveRecordGateway` 内でロード）。`AgriculturalTaskEntity` に `is_reference?` alias 追加済み（`preview_agricultural_task_for_edit_crop_selection` との連携）。

#### `build_blank_*` が AR（未保存含む）を返す

- （**解消済み・2026-05-12**）`FarmGateway#build_blank_farm_for_master_form!` — ドメインゲートウェイ interface から stub を削除（アダプター実装は残存、コントローラが直接呼ぶため）。
- （**解消済み・2026-05-12**）`FieldGateway#build_blank_field_for_master_form!` — 同上。
- （**解消済み・2026-05-12**）`PestGateway#build_blank_pest_for_form` — 同上。`CropsNestedPestsNewInteractor` を `PestCropNestSnapshotDto.blank_for_nested_new` に移行し、`app/adapters/presenters/` 側と interface を統一（`lib/presenters/` 旧版を削除）。
- （**解消済み・2026-05-12**）`PesticideGateway#build_blank_pesticide_for_master_form` — 同上。
- （**解消済み・2026-05-12**）`FertilizeGateway#build_blank_fertilize_for_master_form` — 同上。
- （**解消済み・2026-05-12**）`AgriculturalTaskGateway#build_blank_agricultural_task_for_master_form` — 同上。
- （**解消済み・2026-05-12**）`CropGateway#build_blank_crop_for_master_form` — 同上。

#### Hash／メソッドで `pest_record` 等に AR を載せる

- ~~`PestGateway` 契約と実装: `create_pest_for_crop` / `update_pest_for_crop` / `find_pest_in_crop` の `pest_record:` を永続境界の DTO に置換（`PestActiveRecordGateway`・`PestMemoryGateway` の両方）。~~（**解消済み 2026-05-12**）
- ~~`PestGateway#find_user_owned_non_reference_pest_record_by_name` — 戻り値をエンティティ／DTO にし、メソッド名から `_record` を外す。~~（**解消済み 2026-05-12**）

#### セッション解決が User AR を返す

- `SessionCookieUserActiveRecordGateway#user_for_session_cookie` — `Domain::Shared::Dtos::UserDto`（または同等の非 AR 型）のみを返すよう変更し、`ApplicationController#current_user` との境界を更新（`lib/domain/shared/dtos/user_dto.rb` の方針と整合）。

#### `CultivationPlanActiveRecordGateway` 内の AR 第一級取り扱い

- （**解消済み・2026-05-12**）`normalize_farm_for_plan!` / `normalize_user_for_plan` / `normalize_crops_for_plan!` — `CultivationPlanActiveRecordGateway` の `private` セクションへ移動。アダプター内部限定の AR ヘルパーとして閉じた。
- `destroy` の `DeletionUndo::Manager.schedule(record: plan_model)` — Undo が要求する境界を `resource_type` / `resource_id` 等へ寄せ、`CultivationPlan` AR を渡さない（Undo 側契約と両立させる）。

#### ドメイン DTO／Port の `persisted_*`（プロパティで AR を保持）

- （**解消済み・2026-05-12**）`Domain::Farm::Dtos::AuthorizedFarmLoadedDto` の `persisted_farm` を `master_form_snapshot`（`FarmMasterFormSnapshot`）に置換。`FarmActiveRecordGateway#find_authorized_farm_loaded_bundle!` で `FarmMasterFormSnapshotMapper.from_record`。`FarmMasterFormSnapshotMapper` / `FieldMasterFormSnapshotMapper` を `app/adapters/farm/mappers/` から `lib/adapters/farm/mappers/` に移動（Zeitwerk 名前空間競合 `Adapters::Farm::Mappers::` の `lib/` 優先問題を解消）。
- （**解消済み・2026-05-12**）`Domain::Field::Dtos::AuthorizedFieldLoadedInFarmDto` の `persisted_field` を `master_form_snapshot`（`FieldMasterFormSnapshot`）に置換。`FieldActiveRecordGateway#find_authorized_field_loaded_in_farm!` を `Field.where(farm_id:)` スコープ＋`FieldMasterFormSnapshotMapper.from_record` に変更。`build_blank_field_for_master_form!` シグネチャを `farm_id:/farm_access_filter:` 返却 `FieldMasterFormSnapshot` に変更。`FieldsController#new` / `#set_field` を追従。`lib/presenters/html/farm/farm_load_for_edit_html_presenter.rb`（死コード）を削除。
- `Domain::Pesticide::Dtos::AuthorizedPesticideLoadedDto` の `persisted_pesticide` を同上。
- （**解消済み・2026-05-12**）`Domain::Fertilize::Dtos::AuthorizedFertilizeLoadedDto` の `persisted_fertilize` を `master_form_snapshot`（`FertilizeMasterFormSnapshot`）に置換。`FertilizeActiveRecordGateway#find_authorized_fertilize_loaded_bundle!` で `FertilizeMasterFormSnapshotMapper.from_record` を使用。
- `Domain::Crop::Dtos::AuthorizedCropLoadedDto` / `AuthorizedCropStageInCropContextDto` / `AuthorizedCropTaskTemplateInCropContextDto` の `persisted_crop` 等を同上。
- `Domain::Crop::Dtos::CropDetailOutputDto` の `crop` / `persisted_crop` を同上。
- （**解消済み・2026-05-12**）`Domain::AgriculturalTask::Dtos::AuthorizedAgriculturalTaskLoadedDto` の `persisted_agricultural_task` を `master_form_snapshot`（`AgriculturalTaskMasterFormSnapshot`）に置換。`AgriculturalTaskMasterFormSnapshotMapper` を `app/adapters/` から `lib/adapters/` に移動（Zeitwerk 競合解消）。
- `Domain::Pest::Ports::PestHtmlAuthorizedPestLoad` の `persisted_pest` を削除し、`pest_html_authorized_pest_load.rb` 内の暫定コメント（禁止 **3**）を解消する実装へ。

#### Interactor が `persisted_*`（AR）を返す

- （**解消済み・2026-05-12**）`FertilizeUpdateInteractor` — `FertilizeUpdateFailureDto` の `form_fertilize`（AR）を `master_form_snapshot`（`FertilizeMasterFormSnapshot` 純 DTO）に変更。failure 経路で `find_authorized_fertilize_loaded_bundle!` / `find_authorized_model_for_edit` を呼ばず、`call` 冒頭でキャプチャした `current` エンティティからスナップショットを構築。
- ~~`FertilizeAiUpdateInteractor` — `bundle.persisted_fertilize` 同上。~~（**解消済み 2026-05-12**: `find_authorized_for_edit`（エンティティ）に変更）

---

## 修正単位

- **解消済み（2026-05-12）**: **§F Pest: `find_authorized_model_*` をドメインゲートウェイ公開 API から除去** — `PestGateway` から `find_authorized_model_for_view` / `find_authorized_model_for_edit` を削除。`PestActiveRecordGateway` は private に集約（`find_authorized_for_edit` / `find_authorized_pest_loaded_bundle!` の内部ヘルパー）。`lib/domain/` 禁止 **3**。
- **解消済み（2026-05-12）**: **§F Pest: `pest_record:` AR 越境を DTO に置換** — `PestGateway` 公開メソッド `create_pest_for_crop` / `update_pest_for_crop` / `find_pest_in_crop` の戻り値キーを `pest_record:` から `pest_snapshot: PestCropNestSnapshotDto` に変更。`prepare_crop_nested_pest_for_edit_form!` をゲートウェイ公開 API から除去し `find_pest_in_crop(for_edit_form:)` に統合。`find_user_owned_non_reference_pest_record_by_name` → `find_user_owned_non_reference_pest_by_name`（戻り値 `PestEntity`）にリネーム。`PestActiveRecordGateway` に `pest_crop_nest_snapshot_from` private メソッドをインライン実装（`app/` 側 `PestCropNestSnapshotMapper` を lib 内から参照しない）。Interactors（`CropsNestedPestsCreate` / `Update` / `LoadPest` / `PestAiCreate`）・Presenters（`CropPestsCreate` / `Update` / `LoadPest`）を追従。`lib/domain/` 禁止 **3**。
- **解消済み（2026-05-09）**: **§F Farm: `find_authorized_model_*` をドメインゲートウェイ公開 API から除去** — `lib/domain/farm/gateways/farm_gateway.rb` から `find_authorized_model_for_view` / `find_authorized_model_for_edit` を削除。`FarmActiveRecordGateway` は private `authorized_farm_record_for_view!` / `authorized_farm_record_for_edit!` に集約。`lib/domain/` 禁止 **3**・Rationalizations **4**（名目 Gateway）の当該行を解消。`AuthorizedFarmLoadedDto#persisted_farm` は §F「DTO」の行が未処理。
- **解消済み（2026-05-08）**: **cultivation_plan: ポート／DTO から Html・Json・Page チャネル語を除去** — `PublicPlanResultsHtmlOutputPort`→`PublicPlanResultsOutputPort`、`PublicPlanResultsPageReadModel`→`PublicPlanResultsReadModel`、`TaskScheduleHtmlShellPlan`→`TaskScheduleTimelineShellPlan`、`TaskScheduleItemJsonOutputPort`→`TaskScheduleItemMutationOutputPort`；`TaskScheduleItemJsonPresenter`→`TaskScheduleItemMutationPresenter`；`TaskScheduleItemScheduleDeletionUndoInteractor` の `json_output_port`→`mutation_output_port`。Interactors 禁止 **4**。
- **解消済み（2026-05-08）**: **私有計画: `CompositionRoot` / Adapter の `html` 命名（ジョブチェーン・select_crop runner）** — `PrivatePlanHtmlPostCreateJobChain`→`PrivatePlanPostCreateJobChain`、`private_plan_html_post_create_job_chain`→`private_plan_post_create_job_chain`、`PrivatePlanSelectCropHtmlContextRunner`→`PrivatePlanSelectCropContextRunner`、`private_plan_select_crop_html_context_runner`→`private_plan_select_crop_context_runner`（ファイル名同様）。Interactors 禁止 **4** @ Application edge / `lib/adapters`。
- **解消済み（2026-05-08）**: **FarmMapper の `for_html_detail` を `include_weather_data_fields` へ** — 農場エンティティへの気象同期メタの付与をチャネル語から分離。禁止 **4** / Gateway boundary @ `lib/adapters`。
- **解消済み（2026-05-08）**: **file_blob: `ApiV1Files*` Interactors のチャネル語除去** — `ApiV1FilesIndexInteractor`→`FileBlobListInteractor`、`ApiV1FilesShowInteractor`→`FileBlobShowInteractor`、`ApiV1FilesCreateInteractor`→`FileBlobCreateInteractor`、`ApiV1FilesDestroyInteractor`→`FileBlobDestroyInteractor`（`app/controllers/api/v1/files_controller.rb` 参照更新）。**2026-05-08**: `ApiV1FilesJsonPresenter`→`FileBlobJsonPresenter`。Interactors 禁止 **4**。
- **解消済み（2026-05-08）**: `**cultivation_plan` の `ApiV1PrivatePlan*` Interactors 除去** — `ApiV1PrivatePlansListInteractor`→`PrivateOwnedPlansListInteractor`、`ApiV1PrivatePlanShowInteractor`→`PrivateOwnedPlanDetailInteractor`、`ApiV1PrivatePlanCreateInteractor`→`PrivatePlanInitializeFromSelectionInteractor`（`Api::V1::PlansController`・ドメインコメント・Interactor テストを追従）。Presenter 名 `ApiV1PrivatePlan*` は本サブバッチ対象外。Interactors 禁止 **4**。
- **解消済み（2026-05-08）**: `**PublicPlanApiSavePlanInteractor` → `PublicPlanSaveByPlanIdInteractor`** — チャネル語 `Api` をクラス名から除去（`Api::V1::PublicPlansController` / `PublicPlansController` の `save_plan` 経路）。Interactors 禁止 **4**。
- **解消済み（2026-05-08）**: `**field_cultivation` の `FieldCultivationApi*` Interactors 除去** — `FieldCultivationApiShowInteractor`→`FieldCultivationShowInteractor`、`FieldCultivationApiUpdateInteractor`→`FieldCultivationUpdateInteractor`（API コントローラ 2 系統＋ドメイン層テスト）。DTO／ゲートウェイの `Api` 語は本サブバッチ対象外。Interactors 禁止 **4**。
- **解消済み（2026-05-08）**: `**CropApiAiCreateInteractor` → `CropAiCreateInteractor`** — `CompositionRoot#crop_ai_create_interactor`、`Api::V1::CropsController` 追従。Interactors 禁止 **4**。
- **解消済み（2026-05-08）**: `**pest` の `PestApiAi*` Interactors 除去** — `PestAiCreateInteractor` / `PestAiUpdateInteractor`、`CompositionRoot#pest_ai_*`、`Api::V1::PestsController`。Interactors 禁止 **4**。
- **解消済み（2026-05-08）**: `**fertilize` の `FertilizeApiAi*` Interactors 除去** — `FertilizeAiCreateInteractor` / `FertilizeAiUpdateInteractor`、`CompositionRoot#fertilize_ai_*`、`Api::V1::FertilizesController`。Interactors 禁止 **4**。
- **解消済み（2026-05-08）**: `**add_crop` の `ApiAddCrop*` 除去** — `ApiAddCropOutputPort`→`AddCropOutputPort`、`ApiAddCropPresenter`→`AddCropPresenter`（`CultivationPlanRestBaseController#add_crop`）。ports / presenters のチャネル語。禁止 **4**。
- **解消済み（2026-05-08）**: `**add_field` の `ApiAddField*` 除去** — `ApiAddFieldOutputPort`→`AddFieldOutputPort`、`ApiAddFieldPresenter`→`AddFieldPresenter`（`CultivationPlanRestBaseController#add_field`）。禁止 **4**。
- **解消済み（2026-05-08）**: `**remove_field` の `ApiRemoveField*` 除去** — `ApiRemoveFieldOutputPort`→`RemoveFieldOutputPort`、`ApiRemoveFieldPresenter`→`RemoveFieldPresenter`（`CultivationPlanRestBaseController#remove_field`）。禁止 **4**。
- **解消済み（2026-05-08）**: `**manual plan adjust` の `ApiPlanAdjust*` 除去** — `ApiPlanAdjustOutputPort`→`ManualPlanAdjustOutputPort`、`ApiPlanAdjustPresenter`→`ManualPlanAdjustPresenter`（`#adjust`）。禁止 **4**。
- **解消済み（2026-05-08）**: `**retrieve plan data` の `ApiPlanData*` 除去** — `ApiPlanDataOutputPort`→`RetrieveCultivationPlanOutputPort`、`ApiPlanDataPresenter`→`RetrieveCultivationPlanPresenter`（`#data`）。禁止 **4**。
- **解消済み（2026-05-08）**: `**private plan initialize from selection` の `ApiPrivatePlanCreate*` 除去** — Output Port / Input・Success・Failure DTO / Presenter を `PrivatePlanInitializeFromSelection*` に改名（`PlansController#create`・Interactor テスト追従）。禁止 **4**。
- **解消済み（2026-05-08）**: `**ApiJsonResult` → `HttpJsonEnvelope`** — `lib/domain/shared/dtos/http_json_envelope.rb`。作物／害虫／肥料 AI・`CropAiUpsertActiveRecordPersistence`・`PestAiDaemonResponseInterpreter` 追従。禁止 **4**。
- **解消済み（2026-05-08）**: `**ApiUserApiKeyRotateInteractor` → `UserApiKeyRotateInteractor`** — `lib/domain/api_keys/interactors/user_api_key_rotate_interactor.rb`。HTML / API `*ApiKeysController`。禁止 **4**。
- **解消済み（2026-05-08）**: `**ApiFileBlobGateway` / `ApiFileBlobActiveRecordGateway` 除去** — `FileBlobGateway` / `FileBlobActiveRecordGateway`、`CompositionRoot#file_blob_gateway`（`FilesController`）。禁止 **4**。
- **解消済み（2026-05-08）**: `**ApiV1PrivatePlansListPresenter` → `PrivateOwnedPlansListPresenter`** — `PlansController#index`（Interactor 名 `PrivateOwnedPlansListInteractor` に整合）。禁止 **4**。
- **解消済み（2026-05-08）**: `**ApiV1PrivatePlanShowPresenter` → `PrivateOwnedPlanDetailPresenter`** — `PlansController#show`。禁止 **4**。
- **解消済み（2026-05-08）**: `**ApiV1FilesJsonPresenter` → `FileBlobJsonPresenter`** — `file_blob_json_presenter.rb`、`FilesController`。禁止 **4**。
- **解消済み（2026-05-08）**: `**EntryScheduleApiFailureDto` → `EntryScheduleFailureDto`** — `entry_schedule_failure_dto.rb`；`EntryScheduleCropsIndex` / `EntryScheduleShow` / `EntryScheduleResolveReferenceFarm` Interactor；Presenter 共通 `EntryScheduleFailureRendering`（旧 `EntryScheduleApiFailureRendering`）。禁止 **4**。
- **解消済み（2026-05-08）**: `**MastersCropTaskTemplateMastersApiFailureDto` → `MastersCropTaskTemplateMastersFailureDto`** — `masters_crop_task_template_masters_failure_dto.rb`；`CropMastersTaskTemplateIndex` / `Update` / `Destroy`、`CropNestedCropTaskTemplatesNew` Interactor；関連 Presenter テスト。禁止 **4**。
- **解消済み（2026-05-08）**: `**Masters*RequirementApiOutputPort` / `Masters*RequirementApiPresenter`** — `masters_*_requirement_output_port.rb`、`Masters*RequirementOutputPort`；`masters_*_requirement_presenter.rb`、`Masters*RequirementPresenter`；`Api::V1::Masters::Crops::CropStages::*RequirementsController` の `*_requirement_presenter`。禁止 **4**。
- **解消済み（2026-05-08・意味読み）**: `**lib/domain` の `Api` / `ApiV1` 型名の横断棚卸し** — `rg`＋ファイル一覧で `**ApiWeather` / `ApiKeys` 以外にチャネル想起の `Api`/`ApiV1` 型名なし**（上記セクション D の解消ログと整合）。`ApiWeather` は ADR 0010 で除外固定。禁止 **4**。
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
- **解消済み（2026-05-07）**: **HTML** `CropsController` の `new` / `edit` / `after_crop_create_failure` / `after_crop_update_failure` にあった **ActiveRecord の直接生成・ネスト補助・assign_attributes** をやめ、`CropGateway` の `build_blank_crop_for_master_form` / `prepare_crop_record_for_edit_master_form!` / `build_new_crop_with_attributes_for_master_form` / `merge_edit_crop_params_for_master_form!` に集約（`Adapters::Crop::Gateways::CropMemoryGateway`）。コントローラはゲートウェイ呼び出しと `@crop.valid?` のみ。Application edge 禁止 **4**。
- **解消済み（2026-05-07）**: `**CropsController#destroy` の format.json** — `DeletionUndo::HtmlMasterScheduleInvoker` に AR を渡さず `resource_type` / `resource_id` のみ（`DeletionUndoScheduleInputDto` と整合）。`toast_message: nil` で Undo ゲートウェイの `default_toast_message` を利用（文言キーは `crops.undo.toast` から `deletion_undo.toast_message` 側に寄る）。`destroy` を `set_crop` から外し、JSON/HTML とも削除時に事前の作物読込を不要化。Application edge 禁止 **4**。
- **解消済み（2026-05-07）**: `**DeletionUndo::HtmlMasterScheduleInvoker` の `record:` 依存除去** — HTML `destroy` の **JSON** 枝で、`AgriculturalTasksController` / `PestsController` / `PesticidesController` / `FertilizesController` が作物削除と同様に `resource_type` / `resource_id` のみを渡すよう統一。存在しない ID の HTML 削除では、`soft_destroy_with_undo` の `rescue StandardError` が `Domain::Shared::Exceptions::RecordNotFound` を飲み込まないよう各ゲートウェイで再送出し、DestroyInteractor は `translator.t("*.flash.not_found")` で flash を揃える。
- **解消済み（2026-05-07）**: `**Farms::WeatherDataController`** — AR 直叩き・`WeatherDataGatewayFactory`・予測分岐の主スイッチを除去。`FarmWeatherDataAccessInteractor` + `FarmWeatherDataAccessPresenter`（Interactor／DTO／ポート名に Json を含めず禁止 **4** 準拠）、`FarmGateway` の所有農場／管理者 id 解決（分岐は Interactor）、`PredictWeatherStandaloneEnqueueActiveJobAdapter` で `ActiveJob::EnqueueError` を modeled 結果へ、`FarmWeatherPredictionPayloadParseAdapter` で時刻・日付境界。`index` の Hash 行はシンボルキー参照に修正。Application edge 禁止 **3**・**4**。`lib/domain` の期間算術は `Date#<<` と秒差（禁止 **4** の duration 回避）。
- **解消済み（2026-05-07）**: **HTML `ApiKeysController`** の `generate` / `regenerate` — `@user.generate_api_key!` / `regenerate_api_key!` とコントローラ内成功／失敗分岐を除去。`Domain::ApiKeys::Interactors::UserApiKeyRotateInteractor`（API と同一）+ `Presenters::Html::ApiKeys::UserApiKeyRotateHtmlPresenter` + `CompositionRoot.user_api_key_rotation_gateway`。`show` は表示用 `@user = current_user` のみ。Application edge 禁止 **4**。
- **解消済み（2026-05-07）**: **HTML `AgriculturalTasksController`** の `#new` / 作成失敗フォーム再構築 / 更新失敗スナップショット / 編集時作物リスト用プレビュー — `AgriculturalTask.new`、`build`、`assign_attributes`、`dup`＋参照フラグ試行を `AgriculturalTaskGateway`（`build_blank_agricultural_task_for_master_form`、`build_after_create_failure_agricultural_task_for_master_form!`、`merge_update_form_snapshot_for_master_form!`、`preview_agricultural_task_for_edit_crop_selection`）と `AgriculturalTaskActiveRecordGateway` に集約。Application edge 禁止 **4**。
- **解消済み（2026-05-07）**: **HTML `FieldsController#new`** の `@farm.fields.build` を `FieldGateway#build_blank_field_for_master_form!(persisted_farm:)` に寄せる（認可済み農場は従来どおり `set_farm`）。Application edge 禁止 **4**。
- **解消済み（2026-05-07）**: **HTML `FarmsController#new`** の `current_user.farms.build` を除去。`FarmGateway#build_blank_farm_for_master_form!(user_id:)` と `FarmActiveRecordGateway` 実装に集約（`FieldGateway#build_blank_field_for_master_form!` と同型）。Application edge 禁止 **4**。
- **解消済み（2026-05-07）**: **HTML `PestsController#new`** の `Pest.new` と nested `build` を除去し、既存の `PestGateway#build_blank_pest_for_form`（`PestMemoryGateway` 実装）に一本化。Application edge 禁止 **4**。
- **解消済み（2026-05-08）**: **HTML `PlanningSchedulesController`** の `CultivationPlan` / `Farm` 直叩き・期間生成・作付集約を `CultivationPlanGateway` / `FarmGateway`、`PlanningScheduleFieldsSelectionInteractor` / `PlanningScheduleMatrixInteractor`、HTML プレゼンタに移行。セッション書き込みはマトリクス成功プレゼンタ、時刻は `Time.zone` 注入。Application edge 禁止 **3**・**4**。
- **解消済み（2026-05-08）**: **HTML `Plans::TaskScheduleItemsController`** の `before_action` による `CultivationPlan` / `TaskScheduleItem` の AR 読込と、`destroy` の `@task_schedule_item` 依存を除去。`TaskScheduleItemMutationGateway#deletion_undo_schedule_row_for_item!` と `TaskScheduleItemScheduleDeletionUndoInteractor`（Undo へ委譲、`translator` で toast）、`CompositionRoot.task_schedule_item_schedule_deletion_undo_interactor` で配線。Application edge 禁止 **3**・**4**。
- **解消済み（2026-05-08）**: **HTML `PublicPlansController`** の `results` での `task_schedules` / `task_schedule_items` 走査、`save_plan` JSON 枝の `CultivationPlan.find_by`・手組み session_data、セーブ用圃場スナップショットのコントローラ内 AR map を除去。`CultivationPlanGateway#public_plan_results_schedule_warning?` / `#public_plan_wizard_save_session_payload`、`PublicPlanSaveByPlanIdInteractor`（旧称 `PublicPlanApiSavePlanInteractor`）に集約。
- **解消済み（2026-05-08）**: **HTML `PublicPlansController`** の `**results` / HTML `save_plan**` から `ManageablePublicPlanLookup` による AR 返却（`find_cultivation_plan` オーバーライド）と `@cultivation_plan` を除去。`PublicPlanResultsPageReadModel`・`CultivationPlanGateway#public_plan_results_read_model` / `#public_plan_wizard_plan_exists?`、`PublicPlanResultsInteractor`、`PublicPlanResultsHtmlPresenter`、結果テンプレは `gantt_embed` / read model ベース。スケジュール警告判定はゲートウェイ内で read model と `public_plan_results_schedule_warning?` と共有。Application edge 禁止 **4**。
- **解消済み（2026-05-08）**: **HTML `FertilizesController#new`** の `Fertilize.new` を `FertilizeGateway#build_blank_fertilize_for_master_form` と `FertilizeActiveRecordGateway` に集約（アダプター層テストで未保存 `Fertilize` を検証）。Application edge 禁止 **4**。
- **解消済み（2026-05-08）**: **HTML `PesticidesController`** の `Pesticide.new` / nested `build` / `assign_attributes`、および `PesticideAssociationPolicy` 直参照を `PesticideGateway`（`build_blank_pesticide_for_master_form` 等）と `PesticideActiveRecordGateway` に集約。Application edge 禁止 **4**。
- **解消済み（2026-05-08）**: **HTML `PlansController#create`** — セッション起点の農場／作物／既存計画・`initialize_plan_from_selection`・最適化ジョブチェーン（`PrivatePlanOptimizationJobChainBuilder` と API 共有、`PrivatePlanHtmlPostCreateJobChain` で `JobChainAsyncDispatcher`）を `PrivatePlanCreateFromSessionInteractor`（当時は `PrivatePlanHtmlCreateInteractor`）と HTML プレゼンタ／アダプターに移行。コントローラの `CultivationPlan.find`・`current_user.farms` / `cultivation_plans`・`RecordInvalid` 主スイッチを除去。Application edge 禁止 **3**・**4**。
- **解消済み（2026-05-08・空 backlog 裏取り）**: `**PrivatePlanHtmlCreate*` 型名のチャネル語** — Interactor / 入力 DTO / Output Port / HTML Presenter / `CompositionRoot#private_plan_*_interactor` を `**PrivatePlanCreateFromSession*`** / `**private_plan_create_from_session_interactor`** に統一（`PlansController#create` の振る舞い不変）。Interactors 禁止 **4**。
- **解消済み（2026-05-08）**: **HTML `PlansController#optimize` / `#show`** — `optimize` の `status_optimizing?` 分岐と `before_action :set_plan`（optimize 用）を除去。`CultivationPlanGateway#private_plan_optimization_redirect_snapshot`・`PrivatePlanOptimizationRedirectInteractor`・`PrivatePlanOptimizationRedirectHtmlPresenter`・`CompositionRoot#private_plan_optimization_redirect_interactor` で集約（Interactor／DTO／ゲートウェイにチャネル名 `Html` を載せず Interactors 禁止 **4** に整合）。`show` は `PrivatePlanShowHtmlPresenter#on_success` で `dto.optimizing?` 時に `optimizing_plan_path` へリダイレクト。Application edge 禁止 **4**。
- **解消済み（2026-05-08）**: **HTML `PlansController#optimizing` / `PublicPlansController#optimizing`** — 完了／失敗時の `redirect_to` をコントローラから除去し、`PrivatePlanOptimizingHtmlPresenter` / `PublicPlanOptimizingHtmlPresenter` の `on_success` で DTO の `completed?` / `failed?` に応じて HTTP へ写像（Application edge 禁止 **4**）。契約 `docs/contracts/private-plan-optimizing-html-contract.md` を整合。
- **解消済み（2026-05-08）**: **HTML `PublicPlansController#save_plan`（HTML 枝）** — 計画存在・ペイロード・匿名時セッション退避／認証時 `PublicPlanSaveFromSessionInteractor` 委譲を `PublicPlanWizardSaveDispatchInteractor` + `PublicPlanWizardSaveDispatchHtmlPresenter` に集約。`logged_in?` 主分岐と `save_plan_to_user_account` / `save_plan_data_to_session` のコントローラオーケストレーションを除去（匿名ユーザーは `current_user.anonymous?`）。Application edge 禁止 **4**。
- **解消済み（2026-05-08）**: `**CultivationPlanHtmlBaseController#find_cultivation_plan`** および `**ManageablePrivatePlanLookup`** — リポジトリ全体に呼び出しがなく到達不能だった AR `includes` / `scope.find` 経路を削除。`PlansController` / `PublicPlansController` の `find_cultivation_plan_scope` フックも削除。HTML 公開／私有フローは既存のゲートウェイ＋Interactor 経路のみ。Application edge 禁止 **4**（死んだコントローラ内ユースケース相当の AR 残置の除去）。
- **解消済み（2026-05-08）**: `**AuthController#logout`** / `**Api::V1::AuthController#logout`** / `**AuthTestController#mock_logout`** — `current_user.sessions.destroy_all` をやめ、`Domain::Auth::Interactors::AuthUserLogoutInteractor` + `UserSessionRevocationActiveRecordGateway`（`Session.where(user_id:).delete_all`）+ HTML／API／テスト用 HTML プレゼンタに集約。`logged_in?` で匿名を除外。`clear_session_cookie` は HTML／API で `public` 化しプレゼンタから呼び出し。Application edge 禁止 **4**。
- **解消済み（2026-05-08）**: `**AuthTestController` モックログイン** — `User.find_or_create_by` / `Session.create_for_user` / リダイレクト分岐を `AuthTestMockLoginInteractor` + `AuthTestLoginActiveRecordGateway` + `AuthTestMockLoginHtmlPresenter` に移行。コントローラは OmniAuth モックから `AuthTestMockLoginInputDto` を組み立て、`return_to` 許可は既存 `allowed_return_to?`。セッション Cookie は `auth_test_assign_session_cookie!` フック（Rails 8 の private `cookies` 回避）。Application edge 禁止 **4**。
- **解消済み（2026-05-08）**: **HTML `Crops::PestsController#edit`** — `@pest.pest_control_methods.build` を除去。`PestGateway#prepare_crop_nested_pest_for_edit_form!`・`CropsNestedPestsLoadPestInteractor`（`for_edit_form:`）でゲートウェイに集約。Application edge 禁止 **4**。
- **解消済み（2026-05-08）**: **HTML `PlansController#copy`** — 無効化リダイレクトのみのため `before_action :set_plan` と `PlanPolicy.find_private_owned!` を除去。Application edge 禁止 **4**。
- **解消済み（2026-05-08）**: `**ApplicationController#current_user`** の `Session` / `User` 直参照を `Adapters::Shared::Gateways::SessionCookieUserActiveRecordGateway` に集約。`CompositionRoot#session_cookie_user_gateway` を追加し、`MastersApiSessionResolveGateway` は同一リゾルバを注入してセッション解決を共有。アダプター層テスト `session_cookie_user_active_record_gateway_test.rb` を追加。Application edge 禁止 **4**。
- **解消済み（2026-05-08・セクション0 機械点検）**: `**app/controllers` の HTML系（`api/` 配下除外）全 `*_controller.rb`** を辞書順で 1 件ずつ、`Session` / `User` / 主要ドメイン `Model.(find|where|create|new|build|find_by)` 相当のコントローラ直参照 grep。**該当ヒットなし**（`ApplicationController#current_user` は先行コミットでゲートウェイ化済み）。`SitemapsController` は `Dir.glob` のみ。`HealthController` の DB `rescue` は backlog「残置」既知。`AuthController#google_oauth2_callback` の `case` は OmniAuth ゲートウェイ戻り値の HTTP 写像。
- **解消済み（2026-05-08）**: **API マスタ** `Api::V1::Masters::Crops::CropStages::*RequirementsController` の `@crop_stage.*_requirement` および AR の `save` / `update` / `destroy` を除去。`CropGateway` に各要件の `destroy_*` を追加、`CropMemoryGateway` で永続化、`Masters*Requirement*`Interactor と `Masters*RequirementPresenter`（旧 `Masters*RequirementApiPresenter`）に集約。ルート未使用だった `**CropStagesMastersController`** を削除（`/masters/crops/:id/crop_stages` は既存の `crops/crop_stages` が担当）。Application edge 禁止 **4**。
- **解消済み（2026-05-08）**: **HTML `AgriculturalTasksController`** の `load_crop_selection_data` / `prepare_crop_cards*` / `selected_crop_ids_from_params` にあった作物一覧・プレビュー・カード組み立てのユースケース論理を `AgriculturalTaskEditFormCropSelectionLoadInteractor` + `AgriculturalTaskEditFormCropSelectionLoadHtmlPresenter` + `CompositionRoot#agricultural_task_edit_form_crop_selection_load_interactor` に移行。DTO／ポート名にチャネル名 `Html` を載せない（Interactors 禁止 **4**）。`apply_agricultural_task_update_form_snapshot` のカード再構築は `EditFormCropSelectionCards`。Application edge 禁止 **4**。
- **解消済み（2026-05-08）**: `**AgriculturalTasksController#index`** の `**resolve_filter`**（管理者／非管理者の一覧フィルタ正規化）を `AgriculturalTaskListInputDto` の `initialize` に集約。`index` は生の `params[:filter]` を DTO に渡すのみ。Application edge 禁止 **4**。
- **解消済み（2026-05-08）**: `**FarmsController#index`** の HTML / JSON で `**FarmListInteractor` と `FarmListRowsBundleInteractor` が二重化**していた問題を解消。両形式とも `**FarmListRowsBundleInteractor`** + `FarmListRowsBundleOutputPort`（`FarmListHtmlPresenter` / `FarmListJsonPresenter`）。`FarmListRowDto` に `created_at` / `updated_at` を追加し JSON 契約を維持。Application edge 禁止 **4**・Presenter 契約（同一ユースケース同一 Interactor）に整合。`docs/contracts/farm-list-rows-bundle-contract.md` 更新。
- **解消済み（2026-05-08）**: **HTML `PestsController#edit`** の `@pest.pest_control_methods.build` を `PestGateway#prepare_top_level_pest_for_edit_form!`（`PestMemoryGateway` で `prepare_crop_nested_pest_for_edit_form!` と共通の `ensure_pest_control_method_row_for_form!`）に集約。Application edge 禁止 **4**。
- **解消済み（2026-05-08）**: **HTML `Plans::TaskScheduleItemsController#complete`** — `Date.parse` / `Date.current` / `Time.current` をコントローラから除去。`TaskScheduleItemCompleteInputDto`（Strong params＋注入 `clock`）と `TaskScheduleItemCompleteInteractor`、`CompositionRoot` で `clock: Time.zone` を注入。不正日付は `RecordInvalid`→JSON 422。Application edge 禁止 **4**。
- **解消済み（2026-05-08）**: `**PlanningSchedulesController#get_crop_color_for_schedule`** — 表示専用の色決定を `PlanningSchedulesHelper` に移し、パレットを `CROP_SCHEDULE_DISPLAY_COLOR_PALETTE` に集約。コントローラの `helper_method` 定義を削除。Application edge 禁止 **4**（表示ロジックのコントローラ残置の除去）。
- **解消済み（2026-05-08・ADR）**: Gateway メソッド命名の方針を `[docs/adr/0009-gateway-interface-naming-presentation-agnostic.md](docs/adr/0009-gateway-interface-naming-presentation-agnostic.md)` に記録（プレゼン非依存の IF 名、`master_form` / ウィザード語の意図）。
- **解消済み（2026-05-08・CA 対応計画）**: **Gateway メソッド名の画面由来語** — `CultivationPlanGateway` の `public_plan_html_save_session_payload` → `public_plan_wizard_save_session_payload`、`public_plan_results_page_read_model` → `public_plan_results_read_model`。マスタ HTML CRUD 用の `*_for_html_form` / `*_pesticide_html_*` を `***_for_master_form`** に統一（crop / farm / field / fertilize / agricultural_task / pesticide の IF・`CropMemoryGateway`・各 AR ゲートウェイ・コントローラ・テスト）。**Gateway boundary（presentation-agnostic）**・**Interactors 禁止 4（チャネル名のエンコード）** に整合。
- **解消済み（2026-05-08・継続）**: **空 backlog 通し走査** — 上記代表 grep＋意味読み。**新規未処理項目なし**。
- **解消済み（2026-05-08・CA ワークフロー）**: **運用都度の通し走査（本セッション）** — 上記「最終通し走査」2026-05-08（CA ワークフロー再走査）と同一内容。**新規 `[ ]` 修正単位なし**。次回もキュー空なら同様の通し走査を先頭スコープに固定する。

## セクション0 通し走査メモ（2026-05-06 継続）

`ARCHITECTURE.md` 本文を手動再読しつつ、次を **Glob / Grep / 代表ファイル Read** で照合（1 パス全捕捉ではない。外側ループの再訪を前提）。


| 観点                                                                    | 結果（当該イテレーション）             |
| --------------------------------------------------------------------- | ------------------------- |
| `lib/domain` の `Rails.` / `CompositionRoot` / `Adapters::` **実コード参照** | 検出なし（コメント・ポート説明のみ）        |
| `lib/presenters` の `CompositionRoot` / ゲートウェイ再取得                      | 検出なし                      |
| `app/controllers/api/v1` の `rescue` / `rescue_from`                   | 該当なし                      |
| `frontend` `components/**/*.component.ts` の `adapters/` 直 import      | 該当なし                      |
| HTML `Plans::TaskSchedulesController` の `before_action` AR 読込         | **解消**（2026-05-07・上記修正単位） |
| 既知の意図的 `rescue`（天気・Health・Auth）                                       | 下記「残置」のまま                 |


## スキャン補足

- 2026-05-08: **CA ワークフロー（ユーザー依頼）** — `ARCHITECTURE.md` 全文再読（`## What we require`・禁止 1〜30）＋上記代表 grep横断。**新規 backlog 項目なし**。作業ツリーは当時点で差分なし（ゲートはドキュメントのみの想定更新）。
- 2026-05-08: **継続・空 backlog 通し走査** — 代表 grep のみの増分（ARCHITECTURE 全文再読は前項まで）。**新規項目なし**。Rails 全体 `test-common` 2053 runs / Frontend 375 tests GREEN。
- 2026-05-08: **CA 対応計画（通し走査）** — `ARCHITECTURE.md` 全文脈を再読し、`lib/domain`（`Rails.` / `CompositionRoot.` / 環境時刻）、`lib/presenters`（`CompositionRoot`）、`app/controllers/api`（`rescue` 主スイッチ）、`frontend` components の `adapters/` 直 import を grep。**新規 backlog 項目なし**。続けて Gateway `html`/`page` 含有メソッドをドメイン語へリネームし、全体 `test-common` GREEN（2056 runs, 0 failures）。
- 2026-05-07: **HTML `app/controllers/crops/`** — ネスト作物系コントローラを `grep` / Read で再確認。Interactor＋`CompositionRoot` 注入パターンで Application edge 3・4 の新規違反なし。`Crops::AgriculturalTasksController#create` の空 ID `redirect_to` のみ既知ガード。
- 2026-05-07: **HTML 公開プラン・農業タスク** — `PublicPlansController` / `AgriculturalTasksController` のコントローラ内 AR をゲートウェイ＋Interactor＋Presenter に移し、バックログ該当項目を解消。
- 2026-05-06: **Angular 全コンポーネント（`components/**/*.component.ts`）** — `adapters/` 直 import を廃止し、各 feature の `usecase/**/\*.providers.ts` に DI 配線を集約（plans / public-plans / api-key / マスタ各種 / 既存の農業タスク・contact 等を含む）。`inject(CROP_GATEWAY)` のように**注入トークン**は引き続き usecase から import。
- 2026-05-06: **Angular お問い合わせフォーム** — `contact-form.component.ts` の `CONTACT_GATEWAY_PROVIDER`（adapters）直 import を廃止し、`usecase/contact/contact-form.providers.ts` に集約（`SEND_CONTACT_MESSAGE_OUTPUT_PORT` の `useExisting: ContactFormComponent` は循環回避のためコンポーネントに残置）。
- 2026-05-06: **Angular 農業タスク詳細・編集** — detail / edit コンポーネントの adapters 直 import を廃止し、`agricultural-task-detail.providers.ts` / `agricultural-task-edit.providers.ts` に集約（edit の spec は Presenter import を providers 経由に変更）。
- 2026-05-06: **Angular 農業タスク新規** — `agricultural-task-create.component.ts` の adapters 直 import を廃止し、`agricultural-task-create.providers.ts` に集約。
- 2026-05-06: **Angular 農業タスク一覧** — `agricultural-task-list.component.ts` の adapters 直 import を廃止し、`usecase/agricultural-tasks/agricultural-task-list.providers.ts` に DI 配線を集約（Presenter の型用再エクスポートは usecase ファイルのみ）。
- 2026-05-06: **API 作物 AI** — `CropAiUpsertService` を廃止し、`CropAiCreateInteractor` + `Adapters::Crop::CropAiUpsertActiveRecordPersistence`（ポート `CropAiUpsertPersistencePort`）に分割。`HttpJsonEnvelope#success?`（当時 `ApiJsonResult#success?`）を追加。匿名ユーザーは害虫・肥料 AI と同様に 401（テスト追加）。
- 2026-05-06: **Frontend（Angular）サンプリング（経過）** — 当初サンプルでは `components/` から `adapters/` への直 import が残っていたが、配線は `usecase/**/*.providers.ts` へ集約済み。**2026-05-06 再確認**: `frontend/src/app/components/**/*.ts` からの `adapters/` 直 import は検出されず。レイヤ境界の維持は引き続き契約テスト・通し走査で確認する。
- 2026-05-06: **API 害虫・肥料 AI** — `PestsController` / `FertilizesController` の `ai_create` / `ai_update` を `PestAiCreateInteractor` / `PestAiUpdateInteractor` / `FertilizeAiCreateInteractor` / `FertilizeAiUpdateInteractor` に集約（2026-05-08 時点のクラス名）。agrr 応答の解釈は `PestAiDaemonResponseInterpreter`、肥料ペイロード正規化は `FertilizeAiAgrrPayloadNormalizer`。匿名ユーザー判定は `UserDto#anonymous?`（Mapper で `User` から付与）。作物関連付けは `CompositionRoot` が注入する runner で AR `User` を閉じ込める。
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