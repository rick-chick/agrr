# CA Violations Backlog

最終通し走査: 2026-05-06（Rails バックエンド中心・禁止条項の要点サンプリング） / 直近補足: 2026-05-06（作物 AI・Angular サンプリング）

## 修正単位

（現時点でバックログに固定する単位なし。次回フルスキャン時に `ARCHITECTURE.md` の What we require + 禁止 1〜30 を先頭から再走査する。）

## スキャン補足

- 2026-05-06: **API 作物 AI** — `CropAiUpsertService` を廃止し、`CropApiAiCreateInteractor` + `Adapters::Crop::CropAiUpsertActiveRecordPersistence`（ポート `CropAiUpsertPersistencePort`）に分割。`ApiJsonResult#success?` を追加。匿名ユーザーは害虫・肥料 AI と同様に 401（テスト追加）。
- 2026-05-06: **Frontend（Angular）サンプリング** — `ARCHITECTURE.md` の意図は `components → usecase → domain` でアダプタは usecase からのみ参照。`rg` で `frontend/src/app/components/**/*.ts` を確認したところ、**多数のコンポーネントが `adapters/` の Presenter・Gateway を直接 import** している（例: `plan-detail.component.ts`、`farm-list.component.ts`、`public-plan-create.component.ts`）。是正は機能単位で usecase 経由への配線寄せを別イテレーションとする。
- 2026-05-06: **API 害虫・肥料 AI** — `PestsController` / `FertilizesController` の `ai_create` / `ai_update` を `PestApiAiCreateInteractor` / `PestApiAiUpdateInteractor` / `FertilizeApiAiCreateInteractor` / `FertilizeApiAiUpdateInteractor` に集約。agrr 応答の解釈は `PestAiDaemonResponseInterpreter`、肥料ペイロード正規化は `FertilizeAiAgrrPayloadNormalizer`。匿名ユーザー判定は `UserDto#anonymous?`（Mapper で `User` から付与）。作物関連付けは `CompositionRoot` が注入する runner で AR `User` を閉じ込める。
- 2026-05-06: **Application edge 禁止4（API）** — `app/controllers/api/v1` の AR / ActiveStorage / User 直叩きをゲートウェイ・Interactor・Presenter に寄せた（Plans 一覧・詳細、PublicPlans `save_plan`、Wizard `crops`、公開 cultivation_plans `get_crop_for_add_crop`、マスタ Base のセッション/APIキー解決、作物×農業タスク API、作物×害虫 destroy、API キー生成、Files CRUD、Backdoor users/db_stats、作物 AI の既存検索は Pest/Fertilize ゲートウェイへ）。
- 2026-05-06: `Adapters::ActiveStorage` 名前空間が Rails の `ActiveStorage` と衝突したため、Blob API アダプタは `Adapters::StoredBlobs` に変更。`plan_copy_gateway` の `ActiveStorage::Attachment` 参照は `::ActiveStorage` に明示。
- 2026-05-06: フロントの**全ファイル機械走査**は未実施。上記サンプリングでレイヤ逸脱の傾向を記録済み。フルイテレーションでは各 feature の usecase ファサード化と import 境界の修正を検討する。

## 残置（意図・別単位）

- `Farms::WeatherDataController` の `PredictWeatherDataJob.perform_later` 周りの `rescue ActiveJob::EnqueueError`（キュー投入失敗のユーザー向けレスポンス）。
- `HealthController` の DB 例外のみを拾う `rescue *HEALTH_DB_EXCEPTIONS`（ファイル内コメントのとおり意図的）。
- `AuthController#allowed_return_to?` 等の `URI::InvalidURIError` rescue（URL 検証の局所ガード）。
