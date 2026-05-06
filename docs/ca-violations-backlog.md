# CA Violations Backlog

最終通し走査: 2026-05-06（セクション0 継続: `lib/`・`app/controllers/api/v1`・`frontend` サンプリング） / 直近補足: 2026-05-06

## 修正単位

- **解消済み（2026-05-06）**: `Api::V1::Masters::Crops::AgriculturalTasksController` の `index` / `update` / `destroy` を Interactor + Presenter 経路に統一（Application edge 禁止 3・4）。ゲートウェイ IF は変更なし。
- **解消済み（2026-05-06）**: **HTML** `FertilizesController` の `create` / `update` 先頭の参照データ・admin 分岐（`Application edge` 禁止 4）を削除。`FertilizeCreateInteractor` / `FertilizeUpdateInteractor` の既存判定に一本化し、HTML Presenter で当該失敗メッセージ時の `redirect_to`（従来 UX）を再現。
- **解消済み（2026-05-06）**: **HTML** `PestsController` の `update` 先頭の `is_reference` / admin 早期 `redirect_to` を削除（`Application edge` 禁止 4）。`PestUpdateInteractor` と既存の `PestUpdateHtmlPresenter`（参照フラグ失敗時のリダイレクト）に一本化。**create** は元々コントローラ二重チェックなし。
- **次に先頭で固定する修正単位（未着手）**: 同パターンの **HTML** `AgriculturalTasksController` / `CropsController` / `PesticidesController` / `InteractionRulesController` 等の `is_reference` 早期 `redirect_to` を確認し、Interactor + HTML Presenter に寄せる（1 リソースずつ）。

## セクション0 通し走査メモ（2026-05-06 継続）

`ARCHITECTURE.md` 本文を手動再読しつつ、次を **Glob / Grep / 代表ファイル Read** で照合（1 パス全捕捉ではない。外側ループの再訪を前提）。

| 観点 | 結果（当該イテレーション） |
|------|---------------------------|
| `lib/domain` の `Rails.` / `CompositionRoot` / `Adapters::` **実コード参照** | 検出なし（コメント・ポート説明のみ） |
| `lib/presenters` の `CompositionRoot` / ゲートウェイ再取得 | 検出なし |
| `app/controllers/api/v1` の `rescue` / `rescue_from` | 該当なし |
| `frontend` `components/**/*.component.ts` の `adapters/` 直 import | 該当なし |
| 既知の意図的 `rescue`（天気・Health・Auth） | 下記「残置」のまま |

## スキャン補足

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
- 2026-05-06: フロントの**全 `*.ts` 通し走査**は未実施。`components` から `adapters/` への直 import はスポットでゼロ。必要に応じ `usecase` / `services` / `components` の役割を契約に沿って点検する。

## 残置（意図・別単位）

- `Farms::WeatherDataController` の `PredictWeatherDataJob.perform_later` 周りの `rescue ActiveJob::EnqueueError`（キュー投入失敗のユーザー向けレスポンス）。
- `HealthController` の DB 例外のみを拾う `rescue *HEALTH_DB_EXCEPTIONS`（ファイル内コメントのとおり意図的）。
- `AuthController#allowed_return_to?` 等の `URI::InvalidURIError` rescue（URL 検証の局所ガード）。
