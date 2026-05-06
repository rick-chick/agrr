# CA Violations Backlog

最終通し走査: 2026-05-06（Rails バックエンド中心・禁止条項の要点サンプリング） / 直近補足: 2026-05-06（作物 AI・Angular サンプリング）

## 修正単位

- **解消済み（2026-05-06）**: `Api::V1::Masters::Crops::AgriculturalTasksController` の `index` / `update` / `destroy` を Interactor + Presenter 経路に統一（Application edge 禁止 3・4）。ゲートウェイ IF は変更なし。
- **次イテレーションで先頭に固定する作業**: `ARCHITECTURE.md` の `## What we require` と `## Prohibited practices`（1〜30）による**通し走査**をセクション0として実行し、検出した逸脱をこのファイルの修正単位リストに書き出してから先頭を選ぶ（増分のみの代替は [`references/agent-operational-canonical.md`](../.cursor/skills/clean-architecture-violation-fix-workflow/references/agent-operational-canonical.md) に従う）。

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
- 2026-05-06: フロントの**全ファイル機械走査**は未実施。上記サンプリングでレイヤ逸脱の傾向を記録済み。フルイテレーションでは各 feature の usecase ファサード化と import 境界の修正を検討する。

## 残置（意図・別単位）

- `Farms::WeatherDataController` の `PredictWeatherDataJob.perform_later` 周りの `rescue ActiveJob::EnqueueError`（キュー投入失敗のユーザー向けレスポンス）。
- `HealthController` の DB 例外のみを拾う `rescue *HEALTH_DB_EXCEPTIONS`（ファイル内コメントのとおり意図的）。
- `AuthController#allowed_return_to?` 等の `URI::InvalidURIError` rescue（URL 検証の局所ガード）。
