# 07: フロントエンドとバックエンドのエラー契約・i18n のずれ

本書は**対応計画のみ**であり、コード・文書・カタログの修正は含まない。記載する事実は 2026-09-29 時点のリポジトリを実際に読んで確認したものだけで、`file:line` を付ける。読んでいない・実行していないものは「未確認」と明記する。

参照した規約: [`ARCHITECTURE.md`](../../ARCHITECTURE.md)（Frontend 節）、[`docs/architecture/LAYER-RULES.md`](../architecture/LAYER-RULES.md)、[`docs/design/UI-COMPOSITION-RULES.md`](../design/UI-COMPOSITION-RULES.md)、[`tdd-on-edit`](../../.cursor/skills/tdd-on-edit/SKILL.md)、[`test-common`](../../.cursor/skills/test-common/SKILL.md)、[`i18n-completion-workflow`](../../.cursor/skills/i18n-completion-workflow/SKILL.md)、[`i18n-completion-orchestrator.mdc`](../../.cursor/rules/i18n-completion-orchestrator.mdc)、[`evidence-before-design-and-implementation.mdc`](../../.cursor/rules/evidence-before-design-and-implementation.mdc)。

### 調査の限界（先に明記）

- `frontend/node_modules` が無く、Angular / vitest / ngx-translate は実行していない。フロントの挙動は**コード読解**による。
- `cargo test` / `scripts/run-rust-contract-tests.sh` は実行していない。サーバーの挙動は**コード読解**による。
- i18n カタログの比較と、コード中のキー参照の静的抽出は Python スクリプトで機械的に実施した（付録 D に再現手順）。テンプレートリテラルなどで動的に組み立てるキーは検出できない（未確認）。

---

## 1. 概要と重大度

### 概要

フロントエンド（`frontend/src/app/usecase/**`）とサーバー（`crates/agrr-server/src/`）の間で、エラー本文の形と i18n キーの扱いが揃っていない。課題は次の 5 件である。依頼文の前提のうち、調査で**訂正・補足が必要だった点**を併記する。

| # | 課題 | 調査結果の要点（詳細は §2） | 依頼文の前提との差 |
|---|------|------------------------------|--------------------|
| 1 | Masters のエラー本文が `error` / `errors` で混在し、フロントが片方しか読まない | サーバーは create/update の検証失敗を `errors[]`、認可・destroy・一部 update を `error` で返す。フロントは usecase ごとに読む側がばらばら。**24 個の Masters 変更系 usecase のうち 20 個**が、少なくとも一方の形を読めない | crop / farm の update だけでなく、field の create/update/destroy、farm/field/fertilize/agricultural-task/interaction-rule の destroy、interaction-rule の update も**サーバーの形を読めない**。一方 pests / pesticides / fertilizes / agricultural-tasks の update は、サーバーが `errors[]` を返すため現状は整合している |
| 2 | `save-public-plan` が API のエラー文字列をそのまま返す | サーバーが返す文字列は**純粋な i18n キーではなく `record invalid: <key>` 形式**（コード読解による導出）。表示層の翻訳も、この形式では発火しない | 依頼文は「i18n キー文字列が入る」としているが、実際は `record invalid: ` という接頭辞が付く |
| 3 | Crop 上限（20）に事前チェックと専用 UI が無い | Farm は事前チェック + `limitBlocked` UI + サーバーエラー時のブロック表示がある。Crop は一切無い | 加えて、Crop は**管理者が参照作物を作る場合は上限対象外**（`crop_create_limit_policy.rs:5-10`）で、Farm と同じ実装をそのまま移植できない |
| 4 | `in.json` に `crop_limit_exceeded` が無い | 事実。加えて、サーバーが送出するキーやコードが参照するキーで、カタログに無いものが複数ある（§2.5） | ja/en/in の比較で、ja のみ 343 件・en のみ 246 件が `in` に無い。コードから静的に参照されているのに全言語で欠落しているキーが 7 件ある |
| 5 | `resolveActiverecordApiErrorI18nKey` が Farm のみ対応 | 事実。ただし現行サーバーは翻訳済み文言ではなくキーをそのまま返す（`PassthroughTranslator`）ため、Farm のリテラル対応表も現状では発火しない見込み（未確認: 他に翻訳済み文言を返す経路） | 機能不全ではなく、判定関数（`isCropLimitExceededMessage` 相当）が無いことが実質の欠落 |

### 重大度

| 項目 | 重大度 | 理由 |
|------|--------|------|
| #1 の不一致（crop/farm/field update、5 種の destroy、interaction-rule update） | 高 | サーバーが返す具体的な理由（権限なし・参照フラグ変更不可・検証エラー）が捨てられ、ユーザーには汎用エラーまたは Angular の生メッセージ（`Http failure response for ...`）が出る。Masters の主要な操作が広く影響を受ける |
| #2 の `record invalid: <key>` 露出 | 中 | Farm / Crop 上限超過時の公開プラン保存で、翻訳されない生文字列がトーストに出る（コード読解による導出、実行未確認）。発生条件が上限到達時に限られる |
| #3 Crop 上限の UX | 中 | 20 件到達後、フォーム入力後の送信で初めて失敗する。データ破壊は無い |
| #4 カタログ欠落 | 中 | `in` ロケールで生キーまたは ja 文言（ngx-translate のフォールバック次第。未確認）が出る。サーバー送出キーの欠落は全言語に及ぶものがある |
| #5 リゾルバ | 低 | 機能不全は無い |

セキュリティ上の露出は確認していない。

---

## 2. 現状（確認済み事実）

### 2.1 サーバー: Masters 各リソースのエラー本文（全数）

`json!({"error": ...})` は単一文字列、`json!({"errors": [...]})` は文字列配列である。`"internal"` を返す内部エラー（各 `internal_error()` 系）は表から除いた。

#### 主要 8 リソースの create / update / destroy

| リソース | 操作 | サーバーの形 | 根拠（file:line） | フロントの読み取り | 根拠（file:line） | 整合 |
|---------|------|--------------|-------------------|--------------------|-------------------|------|
| crops | create | `errors` | `masters_crops.rs:128`（入力検証）、`:283`（presenter。上限超過 `:340` も同じ） | `errors` のみ | `usecase/crops/create-crop.usecase.ts:33-36` | 整合 |
| crops | update | **`error`**（403 `:302`、422 `:306`、409 `stale_record` `:310`、検証 `:314`） | `masters_crops.rs:297-315` | `errors` のみ | `usecase/crops/update-crop.usecase.ts:34-37` | **不一致** |
| crops | destroy | `error` | `masters_crops.rs:366,368` | `error` → `errors` | `usecase/crops/delete-crop.usecase.ts:27-34` | 整合 |
| farms | create | `errors` | `masters_farms.rs:141`（入力検証）、`:429`（上限超過含む） | `errors` のみ + 上限リゾルバ | `usecase/farms/create-farm.usecase.ts:28-34` | 整合 |
| farms | update | **`error`** | `masters_farms.rs:436,438` | `errors` のみ | `usecase/farms/update-farm.usecase.ts:27-31` | **不一致** |
| farms | destroy | `error` | `masters_farms.rs:446,448` | `message` のみ | `usecase/farms/delete-farm.usecase.ts:25-26` | **不一致** |
| fields | create | `errors`（入力検証 `:87`）と `error`（`:317,319`）が**同一操作で混在** | `masters_fields.rs:87,317,319` | `message` のみ | `usecase/farms/create-field.usecase.ts:17` | **不一致** |
| fields | update | `error` | `masters_fields.rs:327,329` | `message` のみ | `usecase/farms/update-field.usecase.ts:17` | **不一致** |
| fields | destroy | `error`（"Field not found" は 404 `:341-345`） | `masters_fields.rs:337,345` | `message` のみ | `usecase/farms/delete-field.usecase.ts:17` | **不一致** |
| pests | create | `errors` | `masters_pests.rs:186`、入力検証 `:199` | `errors` のみ | `usecase/pests/create-pest.usecase.ts:33-36` | 整合 |
| pests | update | `errors`（403 も `errors: ["forbidden"]`） | `masters_pests.rs:246-255` | `errors` のみ | `usecase/pests/update-pest.usecase.ts:33-36` | 整合 |
| pests | destroy | `error` | `masters_pests.rs:322` | `error` → `errors` | `usecase/pests/delete-pest.usecase.ts:27-34` | 整合 |
| pesticides | create | `errors` | `masters_pesticides.rs:210`、入力検証 `:224` | `errors` のみ | `usecase/pesticides/create-pesticide.usecase.ts:32-35` | 整合 |
| pesticides | update | `errors` | `masters_pesticides.rs:269` | `errors` のみ | `usecase/pesticides/update-pesticide.usecase.ts:32-35` | 整合 |
| pesticides | destroy | `error` | `masters_pesticides.rs:320` | `error` → `errors` | `usecase/pesticides/delete-pesticide.usecase.ts:27-34` | 整合 |
| fertilizes | create | `errors` | `masters_fertilizes.rs:191`、入力検証 `:205` | `errors` のみ | `usecase/fertilizes/create-fertilize.usecase.ts:33-36` | 整合 |
| fertilizes | update | `errors` | `masters_fertilizes.rs:247` | `errors` のみ | `usecase/fertilizes/update-fertilize.usecase.ts:33-36` | 整合 |
| fertilizes | destroy | `error` | `masters_fertilizes.rs:299` | `message` のみ | `usecase/fertilizes/delete-fertilize.usecase.ts:25-26` | **不一致** |
| agricultural_tasks | create | `errors` | `masters_agricultural_tasks.rs:184` | `errors` のみ | `usecase/agricultural-tasks/create-agricultural-task.usecase.ts:34-37` | 整合 |
| agricultural_tasks | update | `errors`（認可失敗も 422 + `errors: ["forbidden"]`） | `masters_agricultural_tasks.rs:224-240` | `errors` のみ | `usecase/agricultural-tasks/update-agricultural-task.usecase.ts:34-37` | 整合 |
| agricultural_tasks | destroy | `error` | `masters_agricultural_tasks.rs:291` | `message` のみ | `usecase/agricultural-tasks/delete-agricultural-task.usecase.ts:27-28` | **不一致** |
| interaction_rules | create | `errors` | `masters_interaction_rules.rs:169` | `errors` → `error` | `usecase/interaction-rules/create-interaction-rule.usecase.ts:30-33` | 整合 |
| interaction_rules | update | `errors`（認可失敗も 422 + `errors: ["forbidden"]`） | `masters_interaction_rules.rs:211-226` | `message` のみ | `usecase/interaction-rules/update-interaction-rule.usecase.ts:30` | **不一致** |
| interaction_rules | destroy | `error` | `masters_interaction_rules.rs:276` | `message` のみ | `usecase/interaction-rules/delete-interaction-rule.usecase.ts:24` | **不一致** |

集計（24 usecase = create 8 + update 8 + destroy 8。crops / farms / fields / pests / pesticides / fertilizes / agricultural_tasks / interaction_rules）:

- 「フロントがサーバーの形を読める」内訳:
  - create: crop, farm, pest, pesticide, fertilize, agricultural_task, interaction_rule（7。field は不一致）
  - update: pest, pesticide, fertilize, agricultural_task（4）
  - destroy: crop, pest, pesticide（3）
  - 合計 14 件が「サーバーが実際に返す形を読めている」。残り **10 件が不一致**（crop update / farm update / farm destroy / field create / field update / field destroy / fertilize destroy / agricultural_task destroy / interaction_rule update / interaction_rule destroy）。
- 「両方の形（`error` と `errors`）を読める」ものは 4 件のみ（create-interaction-rule、delete-crop、delete-pest、delete-pesticide）。残り 20 件は片方または両方を読めない。この 20 件が §6 の RED 対象（サーバーが将来どちらの形で返しても壊れない、という基準）。

#### Crop の下位リソースと関連エンドポイント

| ファイル | 形 | 根拠 |
|----------|----|------|
| `masters_crop_stages.rs` | `error: "Invalid parameters"`（400 系入力）、`errors: ["invalid"]`（検証）、`error: "not found"` | `:184,190,205,211,224,326`、`:254,304,371`、`:75,122,402` |
| `masters_crop_requirements.rs` | 404/409 は `error`、検証は `errors` | `:160-168`, `:232-240`, `:332-340`, `:404-412`, `:504-512`, `:576-584`, `:676-684`, `:748-756`（各要件種別ごとに同型） |
| `masters_crop_task_schedule_blueprints.rs` | `error` + `error_code`、検証は `errors` + `error_code: "validation_failed"` | `:394-424`, `:446`, `:459-468` |
| `masters_crop_setup_proposal.rs` | `error`（`:52,118`）、検証は `errors` = `[{path, message}]`（オブジェクト配列） | `:52,94,118,144-154` |
| `masters_crop_pests.rs` / `masters_crop_pesticides.rs` | `error` のみ（英語リテラル） | `masters_crop_pests.rs:134-205`, `masters_crop_pesticides.rs:65` |
| `masters_auth.rs` / `masters_rate_limit.rs` | `error` + `error_code: "insufficient_scope"`、`error: "unauthorized"`、`error: "rate_limit"` | `masters_auth.rs:98,105`, `masters_rate_limit.rs:147` |

フロント側の読み取り（下位リソース）:

- `create-crop-stage` / `delete-crop-stage` / `create|update|delete-crop-task-schedule-blueprint` は `apiErrorI18nKey`（状態コードのみ、本文を読まない）: `usecase/crops/create-crop-stage.usecase.ts:18`, `delete-crop-stage.usecase.ts:18`, `create-crop-task-schedule-blueprint.usecase.ts:32`, `update-crop-task-schedule-blueprint.usecase.ts:44`, `delete-crop-task-schedule-blueprint.usecase.ts:26`。
- `update-crop-stage` と `update-{nutrient,sunshine,temperature,thermal}-requirement` は `err.message` のみ: `update-crop-stage.usecase.ts:17`, `update-nutrient-requirement.usecase.ts:22,28,32`（他 3 種も同型）。

#### `errors` の形は API 全体で 3 種類ある

| 形 | 例 | 根拠 |
|----|----|------|
| 文字列配列 | Masters の create/update | `masters_crops.rs:283` |
| オブジェクト（項目名 → 文字列配列） | task schedule / work record / photo | `task_schedules.rs:105-113`, `work_records.rs:189`, `work_record_photos.rs:202`。フロントは `usecase/plans/create-work-record.usecase.ts:12-14,30-35` が専用に読む |
| オブジェクト配列（`{path, message}`） | setup proposal dry-run | `masters_crop_setup_proposal.rs:144-154` |

OpenAPI の `Error` スキーマは `error: string` と `errors: array<object>` を定義しており（`docs/api/openapi.yaml:453-461`）、Masters が実際に返す**文字列配列**と一致しない（→ 課題 08）。

フロントの `err.error?.errors?.join(', ')` 系の実装は `errors` がオブジェクトのとき `join` が存在せず例外になり得る。Masters の対象エンドポイントは配列のため現状は問題ないが、共通ヘルパーは `Array.isArray` で防御する必要がある。

#### Masters 以外の Rust ルート（対象外・参考）

`"errors"` を返すルートは `plan_variance_learning.rs`（24 箇所）、`task_schedules.rs`（21）、`weather_reschedule_proposals.rs`（8）、`work_records.rs`（5）、`plan_vs_actual.rs`（4）、`work_record_photos.rs`（4）、`contact_messages.rs`（1）、`organizations.rs`（1）、`field_cultivations.rs`（1。`success: false` と併記）。`plans.rs` / `public_plans.rs` は `error` のみ（`plans.rs:132-221`、`public_plans.rs:252-338`）。**これらの網羅的な usecase 突合は行っていない（未確認）**。本書の全数表は Masters 系と `public_plan_save` を対象とする。

### 2.2 フロント: エラー読み取りパターンの分類

`grep` で `err.error` / `errors?.join` を全数抽出した結果（`frontend/src/app/usecase`、spec 除く）。

| パターン | 該当 usecase |
|----------|--------------|
| A. `errors` のみ | create-crop, update-crop, create-farm, update-farm, create/update-pest, create/update-pesticide, create/update-fertilize, create/update-agricultural-task |
| B. `error` → `errors` | delete-crop, delete-pest, delete-pesticide, delete-plan (`usecase/plans/delete-plan.usecase.ts:30-31`)、retry-farm-weather-fetch (`:27-28`)、load-field-climate (`usecase/plans/field-climate/load-field-climate.usecase.ts:89-90`) |
| C. `errors` → `error` | create-interaction-rule (`:32`)、create-public-plan (`usecase/public-plans/create-public-plan.usecase.ts:36-40`) |
| D. `message` のみ（本文を読まない） | create/update/delete-field、delete-farm、delete-fertilize、delete-agricultural-task、update/delete-interaction-rule、update-crop-stage、update-*-requirement |
| E. 状態コードのみ（`apiErrorI18nKey`） | create/delete-crop-stage、blueprint 3 種 |
| F. `error` を translate → `errors` → 状態コード | create-private-plan (`usecase/private-plan-create/create-private-plan.usecase.ts:31-45`) |
| G. `error` / `errors` を生のまま → 状態コード | save-public-plan (`usecase/public-plans/save-public-plan.usecase.ts:50-64`) |

**パターン D と、`HttpErrorResponse` にサーバー本文が付いた状態で `err.message` を返す実装は、ユーザーに Angular の標準メッセージ（`Http failure response for <url>: <status> ...`）を渡す。** この標準メッセージの形は Angular の仕様に基づくもので、`node_modules` が無いため本環境では未実行確認。ゲートウェイは `catchError` で変換しておらず（`adapters/farms/farm-api.gateway.ts:25-51`、`services/masters/masters-client.service.ts:25-63`、`services/api.service.ts` に `catchError` / `HttpErrorResponse` の記述なし）、HTTP インターセプタも無い（`provideHttpClient()` のみ: `app.config.ts:27`）。

### 2.3 presenter / 表示層で、メッセージがどう扱われるか

| 経路 | 挙動 | 根拠 |
|------|------|------|
| create 系 presenter（crop / pest / pesticide / fertilize / agricultural-task / interaction-rule / field） | `dto.message` をそのままフラッシュに渡す | `adapters/crops/crop-create.presenter.ts:18-27`、`adapters/pests/pest-create.presenter.ts:24` ほか |
| 一覧系 presenter（destroy 失敗の通知） | 同上 | `adapters/pests/pest-list.presenter.ts:51` ほか。destroy の経路と一致するか個別確認は**未実施** |
| edit / detail 系 presenter（crop / farm / pest / interaction-rule / agricultural-task） | 保存失敗時 `errorDtoI18nKey(dto)` に通す。キー形式でない文言は `not found` / `unauthorized` / `forbidden` を含む場合のみ専用キー、それ以外は `common.api_error.generic` に**丸められる** | `adapters/crops/crop-edit.presenter.ts:60-68`、`adapters/farms/farm-edit.presenter.ts:52-58`、`core/error-dto-i18n-key.ts:16-38` |
| `FlashMessageService.show` | `translateServerToastMessage` でキー形式（`/^[a-z][a-z0-9_.]*$/i`）なら翻訳、キーでなければ生文字列のまま | `services/flash-message.service.ts:30-34`、`core/i18n/translate-server-toast-message.ts:2,13-26,54-82` |
| `control.error \| translate`（公開プラン結果の全画面エラー） | 翻訳を試み、無ければ生文字列 | `components/public-plans/public-plan-results.component.ts:81`、`adapters/public-plans/public-plan-results.presenter.ts:67-74` |

含意:

- edit 系 presenter は、usecase が正しく検証メッセージを読めても（例: `update-pest` の `errors`）、キー形式でなければ汎用メッセージに丸める。**usecase だけ直しても、edit 画面ではサーバーの検証文言は見えない**。表示方針（丸めるか、キー / コードを渡すか）は §3.5 の確認事項。
- サーバーが返す英語リテラル（`"name is required"`、`"Invalid parameters"`、`"Crop not found"` など。`masters_crops.rs:128`、`masters_crop_stages.rs:184` ほか）は、create 系では生のまま表示される。

### 2.4 課題 2: `save-public-plan` の詳細

#### フロント

`usecase/public-plans/save-public-plan.usecase.ts:50-64` の `resolveErrorMessage` は、本文の `error`（trim 後）または `errors` を join した文字列を**翻訳せず**そのまま返す（`:51-56`）。本文が無い `HttpErrorResponse` のみ `apiErrorI18nKey` を `translate.instant` で翻訳する（`:57-59`）。同ファイル `:37-41`（HTTP 200 で `success: false` の場合）も生の `response.error?.trim()` を返す。

`create-private-plan.usecase.ts:31-36` は `error` を `translate.instant(serverKey)` に通し、翻訳できれば翻訳結果、できなければキーを返す。

既存 spec は `save-public-plan.usecase.spec.ts:115-143` で、`{ success: false, error: 'Crop limit exceeded' }` の 422 に対し**生文字列 `'Crop limit exceeded'` がそのまま返る**ことを期待している。

#### サーバー（伝播経路）

1. `plan_save_ensure_user_farm_interactor.rs:82-95` と `plan_save_ensure_user_crops_interactor.rs:122-135` が、上限超過時に `RecordInvalidError::new(Some(<translator.t(key)>), None)` を返す。翻訳器は `PlanSavePassthroughTranslator`（`plan_save_persistence.rs:28`）で、キーを翻訳せずに返す。
2. `RecordInvalidError` の `Display` は `"record invalid{: message}"` 形式（`crates/agrr-domain/src/shared/exceptions/mod.rs:10,34-39`）。既存テストが `"record invalid: name is required"` を固定している（`crates/agrr-adapters-sqlite/src/pest/pest_gateway_test.rs:88`）。
3. `PlanSaveSession::call` は `InvalidTaskScheduleItemError` 以外のエラーを捕捉し、`result.error_message = Some(err.to_string())` にして `Ok(result)` を返す（`plan_save_session.rs:105-112`）。`session_output_from_result` はそれを `failure(message)` に写す（`:326-340`）。
4. `PublicPlanSaveInteractor` は成功でない出力の `error_message` をそのまま `KIND_SAVE_FAILED` の本文にする（`public_plan_save_interactor.rs:100-112`）。`RecordInvalidError` が直接届く経路でも `invalid.to_string()` を使う（`:127-128`）。
5. presenter は 422 + `{"success": false, "error": <本文>}` を返す（`public_plan_save.rs:57-64`）。翻訳器は `PassthroughTranslator`（`:88`）。

したがって、農場上限超過時の応答本文は `"record invalid: activerecord.errors.models.farm.attributes.user.farm_limit_exceeded"` になる（**コード読解による導出。実行検証は未実施。§6 の RED テストで確定する**）。

#### 表示層での結果（導出）

`translateServerToastMessage`（`translate-server-toast-message.ts:54-82`）は、`record invalid: activerecord....` を `:` で分割して前半 `record invalid` をキー候補にするが、空白を含むためキー形式の正規表現（`:2`）に合わず `null` になる。次に `instant(message)` が翻訳できず元の文字列が返る。**結果として、ユーザーには `record invalid: activerecord.errors....farm_limit_exceeded` がそのまま見える**（導出。実行未確認）。

つまり課題 2 は「usecase が translate していない」だけでなく、**サーバー本文に接頭辞が付いており、表示層の暗黙翻訳でも救えない**ことが根本である。

### 2.5 課題 3: Crop 上限（20）と Farm の比較

| 観点 | Farm | Crop | 根拠 |
|------|------|------|------|
| 上限値と判定 | 4 件、`limit_exceeded(count)` | 20 件、`limit_exceeded(count, is_reference)`。**参照作物（`is_reference: true`）は対象外** | `farm/policies/farm_create_limit.rs:5-8`、`crop/policies/crop_create_limit_policy.rs:3-10` |
| サーバーの数え方 | 組織単位・非参照 | 組織単位・非参照 | `agrr-adapters-sqlite/src/farm/farm_gateway.rs:297-309`、`crop/crop_gateway.rs:138-150`（`WHERE organization_id = ?1 AND is_reference = 0`）。ARCHITECTURE の「per user」表記とは異なる（→ 課題 09） |
| 上限エラーのキー | `activerecord.errors.models.farm.attributes.user.farm_limit_exceeded` | `activerecord.errors.models.crop.attributes.user.crop_limit_exceeded` | `farm_create_interactor.rs:126-129`、`crop_create_interactor.rs:143-146` |
| サーバー応答 | 422 `{"errors":[<key>]}`（`PassthroughTranslator`） | 同 | `masters_farms.rs:150,424-430`、`masters_crops.rs:137,283,340` |
| フロント: 事前チェック | あり。`farmGateway.list()` を `ngOnInit` で購読し、`isFarmCreateLimitReached(countUserOwnedFarms(farms))` | **無し** | `components/masters/farms/farm-create.component.ts:196-217`、`domain/farms/farm-create-limit.ts:8-25` |
| フロント: 専用 UI | `limitCheckLoading` 中はローディング、`limitBlocked` で `farms.new.limit_reached` + ヒント + 一覧へのリンク | 無し。`CropCreateViewState` に該当フィールドが無い | `farm-create.component.ts:65-73`、`farm-create.view.ts:9-16`、`components/masters/crops/crop-create.view.ts:13-19` |
| フロント: サーバーエラー時 | `isFarmLimitExceededMessage` で `limitBlocked` を立て、フラッシュを出さない | 汎用フラッシュ（キーは `FlashMessageService` が翻訳） | `adapters/farms/farm-create.presenter.ts:21-31`、`adapters/crops/crop-create.presenter.ts:18-27` |
| i18n | `farms.new.limit_reached` / `limit_reached_hint` が ja / en / in にある | 対応する `crops.new.*` が無い | `ja.json:1062-1063`、`en.json:3448-3449`、`in.json:831-832` |

補足（既存の逸脱・依存方向）:

- Farm の事前チェックは、コンポーネントが gateway トークンを**直接購読**している（`farm-create.component.ts:167,200`）。依存方向（`components → usecase/`のトークン）としては LAYER-RULES の範囲内だが、use case と出力ポートを経由せず、TDD の観測点が component になる。
- `domain/farms/farm-create-limit.ts:1-4` が `core/i18n/...` を import している（domain → core）。`frontend/eslint.config.mjs` に境界ルールは見つからず（`grep` で domain / boundaries の記述なし）、機械的に禁止されているかは**未確認**。
- 一覧のスコープ（`index_list_filter_for_user`）とサーバーの上限計数（組織単位）が一致するかは**未確認**（`crop_list_interactor.rs:44`）。フロントの件数は UX 用のヒントに留め、サーバーを正とする必要がある。

### 2.6 課題 4・5: i18n カタログ

#### 総数

| 言語 | 葉キー数（配列値も 1 件として計上） |
|------|------------------------------------|
| ja | 3,069 |
| en | 3,045 |
| in | 2,838 |

3 言語すべてにあるキーは 2,726 件。JSON 内の重複キー・ドット入りキーは無い。

#### 差分件数

| 比較 | 件数 |
|------|------|
| ja にあり en に無い | 104 |
| en にあり ja に無い | 80 |
| ja にあり in に無い | 343 |
| en にあり in に無い | 246 |
| ja と en の両方にあり in に無い（=「in にだけ無い」） | 239 |
| in にあり ja に無い | 112 |
| in にあり en に無い | 39 |

`ja` / `en` の片側のみのキーの全件は付録 C-1、C-2。`in` に無いキーの接頭辞別件数は付録 C-3。全件の再生成手順は付録 D。

#### コードから参照されているが無いキー

`frontend/src/app` の spec 以外の `.ts` / `.html` から、引用符付きのキー形リテラルを静的に抽出し（1,435 件）、各カタログと突き合わせた。

**全言語で欠落（コードにあるのにカタログに無い）**: 7 件（動的接頭辞と `index.html` の誤検出は除外済み）。

| キー | 参照箇所 | 使われ方 |
|------|----------|----------|
| `crops.setup_proposal_import.apply_failed` | `usecase/plans/apply-bp-amount-proposal-from-learn.usecase.ts:34`、`apply-bp-timing-proposal-from-learn.usecase.ts:32` | エラーメッセージとして生のキーを渡している |
| `farms.errors.invalid_id` | `components/masters/farms/farm-detail.component.ts:302`、`farm-edit.component.ts:169` | `control.error` に生のキー |
| `plans.errors.adjust_failed` | `usecase/plans/apply-weather-reschedule-proposal.usecase.ts:32` | `result.message ?? <key>` |
| `plans.errors.load_failed` | 同 `:40` | 同 |
| `plans.optimizing_live.error.generic` | `components/plans/plan-optimizing.component.ts:145` | `phaseMessage \|\| <key>` |
| `plans.task_schedules.sync.failed` | `components/plans/plan-task-schedule.component.ts:914` | `?? <key>` |
| `plans.work_records.errors.not_found` | `usecase/plans/save-work-record-sheet.usecase.ts:185` | `new Error(<key>)` |

**`in` のみ欠落**: `crops.flash.not_found`（1 件。`usecase/crops/save-crop-stage-panel.usecase.ts:60`、`save-crop-stage-advanced-details.usecase.ts:61`）。ja / en にある。

**動的キー（未確認）**: `<prefix>_` + 値の形で組み立てるキー（`farms.form.region_`、`crops.form.region_` など 10 種）は静的抽出できない。接頭辞に対する `blank/help/in/jp/label/us`（region 系）等のキーは 3 言語すべてに揃っていることを確認したが、実際の値が組み立てられているかは未確認。

**ja / en の片側のみのキー**は、上記の静的参照検索では**すべて参照が見つからなかった**（付録 C-1、C-2）。削除は明示依頼時のみ（[`i18n-completion-orchestrator.mdc`](../../.cursor/rules/i18n-completion-orchestrator.mdc)）であり、本書では削除を提案しない。

既存の機械チェック `frontend/scripts/check-hardcoded-i18n.mjs` は `'key' | translate` と `.instant('key')` のみを検査する（`check-hardcoded-i18n-lib.mjs:29-33`）。本表の 7 件は「メッセージとしてキーを渡す」使い方のため検出されず、`node scripts/check-hardcoded-i18n.mjs` は `OK (1489 static references checked)` で終了する（本調査で実行）。CI にも同ゲートがある（`.github/workflows/frontend-test.yml:76-84`）。

#### サーバーが送出するキーのうち、カタログに無いもの（API 契約上の欠落）

`PassthroughTranslator` はキーをそのまま返すため（`crates/agrr-server/src/adapters.rs:39-44`）、サーバーがキーを送るとフロントのカタログが唯一の翻訳元になる。`masters_*.rs`、`public_plan_save.rs`、`plans.rs`、および crop / farm / field / pest / pesticide / fertilize / agricultural_task / interaction_rule / organization / `plan_save_*` の interactor から、引用符付きのキー形リテラルを抽出して照合した。

| キー | 送出箇所 | 欠落言語 |
|------|----------|----------|
| `activerecord.errors.models.crop.attributes.user.crop_limit_exceeded` | `crop_create_interactor.rs:145`、`plan_save_ensure_user_crops_interactor.rs:128` | **in**（課題 4 本体） |
| `crops.flash.reference_flag_denied` | `masters_crops.rs:306` | ja / en / in |
| `activerecord.errors.models.crop.attributes.updated_at.blank` | `crop_update_interactor.rs:75` | ja / en / in |
| `activerecord.errors.models.crop.attributes.user.blank` | `crop_create_interactor.rs:132`、`crop_update_interactor.rs:111` | ja / en / in |
| `crops.flash.no_permission` | `masters_crops.rs:302,349,366` | in |
| `crops.flash.not_found` | `crop_destroy_interactor.rs:60` | in |
| `crops.flash.reference_flag_admin_only` / `reference_only_admin` | `crop_update_interactor.rs:62`、`crop_create_interactor.rs:71` | in |
| `crops.flash.cannot_delete_in_use.plan` / `.other` | `crop_destroy_interactor.rs:80-82` | en / in（ja にはある） |
| `farms.flash.cannot_delete_in_use`（葉キー） | `farm_destroy_interactor.rs:141` | ja / en / in（カタログには `.plan` / `.field` / `.other` のサブキーのみ） |
| `activerecord.errors.models.{agricultural_task,fertilize,interaction_rule,pest,pesticide}.attributes.user.blank` | 各 `*_create|update_interactor.rs` | ja / en / in |
| `activerecord.errors.models.agricultural_task.attributes.name.taken` | `agricultural_task_create_interactor.rs:136` | ja / en / in |
| `services.plan_save_service.messages.coordinates` | `plan_save_ensure_user_fields_interactor.rs:26` | in |
| AI 系: `api.errors.fertilizes.{fetch_failed,invalid_payload,name_required}`（in）、`api.errors.fertilizes.not_found`（全言語）、`api.errors.pests.name_required`（ja / in）、`api.messages.fertilizes.{created_by_ai,updated_by_ai}`（in / en, in）、`api.messages.pests.{created_by_ai,updated_by_ai}`（全言語）、`api.errors.crops.name_required`（in） | `*_ai_create|update_interactor.rs` | 上記のとおり。AI 生成系は `builtin_generation_deprecation.rs` の対象か**未確認**で、本課題の必須範囲かはユーザー判断（§3.5） |

`in.json` には、他言語に無い**ルート直下の `index` / `new` / `edit` ブロック**と `flash.template_*` 系（`in.json:3183,3589,3607,3619`）があり、ja / en には存在しない。コード参照は静的検索で見つかっていない（削除は本書の範囲外）。また `in` の値のうち日本語文字を含むものが 62 件ある（en は 2 件: `nav.lang_ja`、`public_plans.results.chart.gdd_section`）。「キーはあるが未訳」の別種の欠落であり、本書のキー欠落一覧には含めない。

`ARCHITECTURE.md:83` は i18n カタログを `{ja,en}.json` としているが、実カタログは `{ja,en,in}.json` である（→ 課題 09）。

#### 課題 5: リゾルバ

`core/i18n/resolve-activerecord-api-error-i18n-key.ts:1-15` は Farm の定数（`:1-2`）と、日本語・英語リテラル 2 件の対応表（`:4-7`）のみを持つ。キー文字列が渡された場合は `trim` して**そのまま返す**（`:12-15`）。従って Crop の上限キーは通過するが、Crop 用の定数・判定関数は存在しない。使用箇所は `usecase/farms/create-farm.usecase.ts:32`（変換）と `domain/farms/farm-create-limit.ts:19`（判定）のみ。

`ngx-translate` の欠落キー挙動: `core/i18n/initial-i18n-bootstrap.ts:36` が `setDefaultLang('ja')` を設定しており、`in` で欠落したキーは ja 文言にフォールバックする可能性が高いが、ngx-translate v17 の挙動は `node_modules` が無いため**未確認**。

---

## 3. あるべき契約

### 3.1 現状の暗黙規約

サーバーの実装から読み取れる暗黙の規約は次のとおり。

- 検証失敗（422）は `errors: string[]`
- 認可・存在しない・destroy 失敗・内部エラーは `error: string`

ただし crops / farms / fields の update、fields の create 失敗、destroy 全般がこの規約から外れる、または規約自体が無い（`masters_crops.rs:314` は検証失敗 `UpdateFailure::Error` も `error`）。また 403 の扱いが揃っていない（pests / pesticides / fertilizes の update は 403 + `errors: ["forbidden"]`、agricultural_tasks / interaction_rules の update は 422 + `errors: ["forbidden"]`）。認可の整合そのものは課題 10 の範囲。

Masters API は API キー（`Authorization: Bearer` / クエリ）でも呼ばれる外部向け API でもある（`masters_auth.rs:1`、`crates/agrr-r4-contract/tests/contracts.rs:3034-3062`、`frontend/src/app/services/masters/masters-client.service.ts:21-24`）。**サーバーの形の変更は外部クライアントに対する互換性の問題になる。**

### 3.2 選択肢の比較

| 案 | 内容 | 長所 | 短所 |
|----|------|------|------|
| **A. サーバー統一（置換）** | 例: 422 は常に `errors[]`、それ以外は常に `error`。既存の逸脱（crops/farms/fields の update ほか）を規約に合わせて修正 | 契約が単純。フロントの分岐が減る | 既存の `error` を `errors` に変える箇所は**外部 API キークライアントに対する破壊的変更**。403 と 422 でキーが変わり、フロントは結局両方を読む必要がある。`crates/agrr-server` の Docker 再ビルド・R4 全件・OpenAPI 更新（課題 08）が必要 |
| **B. フロントで両形式を許容** | `core/` に共通ヘルパーを 1 つ置き、`errors[]`（文字列配列）と `error`（文字列）と状態コードを一箇所で解釈。全 Masters usecase から使う | サーバー変更・外部クライアント影響なし。Masters 以外のルートが混在のままでも耐える。段階的に適用できる | サーバー側の契約は曖昧なまま。サーバーが将来別の形（オブジェクト形 `errors` など）を返すとヘルパーの拡張が必要 |
| **C. サーバーは付加的統一（併記）** | 失敗応答に必ず `error`（主メッセージ）を入れ、複数項目がある検証失敗は加えて `errors[]` も入れる | 既存クライアントを壊さない。フロントは `error` だけ読めば足りる。OpenAPI に明記できる | サーバー変更範囲が広い（Masters の presenter 約 30 箇所）。既存の `errors` のみ返す箇所に `error` を足す設計判断が要る |
| D. エラーコード標準化 | `error_code` を全エラーに付け、フロントがコード → i18n キーに写像。文言は返さない | 英語リテラルの露出（§2.3）を根本解消。国際化が明確 | 影響が最大。既に `error_code` を使う箇所（`masters_auth.rs:98`、blueprints）と未使用箇所が混在し、全面移行が必要 |

### 3.3 推奨

1. **B を先行して実施する（必須・独立）。** 理由: サーバー変更を伴わず外部クライアントに影響せず、Masters 以外のルートも `errors` / `error` が混在（§2.1）しているため、フロントの耐性は C を採っても結局必要になる。
2. **C は B の完了後に任意で実施する（要ユーザー確認）。** A は外部クライアントを壊すため**推奨しない**。D は本課題の範囲を超えるため別課題とする。
3. **サーバー側で例外的に直すもの（B と独立、要ユーザー確認）**: `public_plan_save` の `record invalid: ` 接頭辞除去（§5 S1）。フロントで接頭辞を文字列処理して剥がす案は、サーバーの表示用文字列に依存するため採らない。

### 3.4 契約案（B 採用時にフロントが前提とする形）

共通ヘルパー（`core/`）が受理する失敗応答:

| 入力（`HttpErrorResponse.error`） | 出力 |
|-----------------------------------|------|
| `{ errors: string[] }`（trim 後に空でない要素が 1 件以上） | 要素を `', '` で連結した文字列 |
| `{ error: string }`（trim 後に空でない） | その文字列 |
| 上記以外（本文なし、`errors` がオブジェクト / オブジェクト配列、空文字列） | 本文は使わず状態コード → `apiErrorI18nKey`（`core/api-error-i18n-key.ts:29-57`） |
| 状態コード 409 | 本文にかかわらず `common.api_error.conflict`（サーバー本文は機械コード `stale_record`: `masters_crops.rs:310`。キーでも人間向け文言でもない） |
| `HttpErrorResponse` でない `Error` | `err.message`（本文が無ければ `common.api_error.generic`） |

優先順位は `errors` > `error` とする（Masters では同一応答に両方が入らない: §2.1）。ヘルパーは**翻訳しない**（純関数）。翻訳は既存の表示層（`FlashMessageService` → `translateServerToastMessage`）に任せる。usecase が自前で `TranslateService` を使っている `save-public-plan` / `create-private-plan` は、ヘルパー結果を `translateServerToastMessage` に通す（既存の純関数。`core/i18n/translate-server-toast-message.ts:54`）。

契約案 C（サーバーが併記する場合）の形:

```json
{ "error": "<主メッセージ: i18n キー、または人間向け文言>", "errors": ["<検証項目のメッセージ>"], "error_code": "<任意: 機械可読コード>" }
```

- 4xx / 5xx では `error` を必ず含める。
- `errors` は検証失敗（422）で項目メッセージが複数ある場合の付加情報。
- `errors` の要素の型は文字列に限る。項目別に返す場合（work record 等）は別スキーマとして OpenAPI に明記する（課題 08）。

### 3.5 ユーザー確認が必要な点

| # | 確認事項 | 既定（未回答時の進め方） |
|---|----------|--------------------------|
| Q1 | サーバーの契約を変更するか（C の実施可否）。外部 API キークライアントが `error` / `errors` のどちらに依存しているか | 変更しない。B のみ実施 |
| Q2 | `public_plan_save` の `record invalid: ` 接頭辞をサーバーで除去してよいか（`public_plan_save_interactor.rs:127-128`、`plan_save_session.rs:109`）。既存クライアントが接頭辞付き文字列に依存していないか | 除去する（S1）。フロントは接頭辞を扱わない |
| Q3 | edit / detail 系 presenter が検証文言を `common.api_error.generic` に丸める挙動（`error-dto-i18n-key.ts:16-38`）を、キー形式または既知コードに限り表示するよう変えるか | 変えない。usecase のヘルパー適用までを範囲とする |
| Q4 | Crop 上限の事前チェックを管理者に適用するか。管理者は参照作物なら上限対象外（`crop_create_limit_policy.rs:5-10`） | 非管理者のみ事前チェック。管理者はサーバーエラー時のブロック表示のみ |
| Q5 | Crop 上限のコピー文言（`crops.new.limit_reached` ほか）と Hindi 訳の確認者。既存の Farm 文言は `farms.new.limit_reached`（`ja.json:1062`）を踏襲する | Farm と同型の文言を ja / en / in で新規追加 |
| Q6 | 適用範囲: Masters の 24 usecase に加え、crop 下位リソース（`update-crop-stage`、`update-*-requirement`）、`create-private-plan`、`create-public-plan`、`delete-plan` にもヘルパーを適用するか | 24 usecase + `save-public-plan` のみ。他は別途 |
| Q7 | `resolveActiverecordApiErrorI18nKey` の Crop リテラル（`'作成できるCropは20件までです'` 等）を対応表に足すか。現行サーバーはキーを返すため不要の見込み（§2.6） | 足さない。定数と判定関数のみ追加 |
| Q8 | サーバー送出キーのうち、AI 生成系（`api.*by_ai`、`api.errors.pests.*` 等）と `activerecord...user.blank` 系（通常到達しない）まで欠落を埋めるか。`farms.flash.cannot_delete_in_use` は、カタログにサブキーを足す案と、サーバーでサブキーに変更する案のどちらか | 本課題では Crop / Farm / Field の到達する経路と、コードから参照される 7 件に限定 |
| Q9 | Farm の事前チェック（component が gateway を直接購読）を use case 経由に是正するか | 是正しない。Crop のみ use case 経由で新規実装 |
| Q10 | `errors` と `error` の両方が入る場合の優先順位（本書は `errors` 優先） | `errors` 優先 |

---

## 4. 影響範囲

### 4.1 フロントエンド

| 層 | ファイル | 変更内容（概要） |
|----|----------|------------------|
| `core/` | `api-error-message.ts`（新規）、`i18n/resolve-activerecord-api-error-i18n-key.ts` | 共通ヘルパー、Crop 定数の追加 |
| `domain/` | `domain/crops/crop-create-limit.ts`（新規）、`domain/farms/farm-create-limit.ts`（参照のみ） | Crop 上限の定数・件数・判定 |
| `usecase/` | Masters 24 usecase（表 §2.1）、`save-public-plan.usecase.ts`、`crops/load-crop-create-limit.*`（新規: DTO / input port / output port / usecase / providers） | ヘルパー適用、上限チェックの usecase |
| `adapters/` | `adapters/crops/crop-create.presenter.ts` | `limitBlocked` / `limitCheckLoading` の反映 |
| `components/` | `components/masters/crops/crop-create.component.ts`、`crop-create.view.ts` | 事前チェックの呼び出し、ブロック表示 |
| i18n | `assets/i18n/{ja,en,in}.json` | `crop_limit_exceeded`（`in`）、`crops.new.limit_*`（3 言語）、サーバー送出キーの欠落、コード参照の欠落 7 件 |

### 4.2 バックエンド（Q1 / Q2 の回答により実施）

| 層 | ファイル | 変更内容 |
|----|----------|----------|
| domain | `crates/agrr-domain/src/cultivation_plan/interactors/public_plan_save_interactor.rs:127-128` | `invalid.to_string()` ではなく `RecordInvalidError::detail_message()`（`shared/exceptions/mod.rs:21-23`）を使う |
| adapters | `crates/agrr-adapters-sqlite/src/cultivation_plan/plan_save_session.rs:109` | `err.to_string()` の代わりに `RecordInvalidError` を判別して詳細メッセージのみ渡す |
| edge | `crates/agrr-server/src/masters_*.rs` の presenter（C 案のみ） | 失敗応答に `error` を併記 |
| docs | `docs/api/openapi.yaml:453-461` | `errors` の型を文字列配列に修正（課題 08） |

`crates/agrr-server/**`、`crates/agrr-domain/**`、`crates/agrr-adapters-*/**` を変更した場合、Docker 検証前に `.cursor/skills/dev-docker/scripts/rebuild-restart.sh` が必須（`docker-dev-agrr-server-rebuild.mdc`）。

### 4.3 テスト

| 種別 | 既存で影響を受けるもの | 新規 |
|------|------------------------|------|
| フロント usecase spec | `usecase/public-plans/save-public-plan.usecase.spec.ts:115-143`（生文字列の期待を、キー翻訳後の期待へ更新） | §6 の T1-T12 |
| フロント presenter spec | `adapters/farms/farm-create.presenter.spec.ts`（変更なし想定）、`adapters/plans/plan-new.presenter.spec.ts:102`（Farm キー使用。変更なし想定） | `adapters/crops/crop-create.presenter.spec.ts`（現在存在しない） |
| フロント catalog spec | `core/i18n/farms-activerecord-locale.catalog.spec.ts`（参考）、`core/i18n/crops-new-locale.spec.ts`（拡張） | §6 T10-T12 |
| R4 契約 | Masters crops / farms の create/update/destroy の 4xx 本文形を表明するテストは、`contracts.rs` の `error` / `errors` アサーション全件（`:348,411,636,1221,1626,1726,2123,2418,2442,2689,3043,3192,3280,3454,3471,3879,4502,4563,4595`）を見た限り**見つからなかった**（動的パス構築による検索漏れは未確認）。従って C 案を採っても既存 R4 は壊れない見込み | §6 S-T1, S-T2 |
| ドメイン | `agrr-domain/test/cultivation_plan/interactors_public_plan_save_interactor_test.rs`（構造流用） | §6 S-T3 |

### 4.4 i18n 3 言語

`ja` / `en` / `in` の同パスに追加する（[`i18n-completion-workflow`](../../.cursor/skills/i18n-completion-workflow/SKILL.md) の DoD）。`assets/i18n/*.json` は手編集のみ（一括生成スクリプト禁止）。プレースホルダは `{{param}}`。

---

## 5. 対応方針（層ごと）

依存方向は `components → usecase → domain`、`adapters → gateway tokens`（ARCHITECTURE の Frontend 節、LAYER-RULES の Frontend layout）を守る。

### 5.1 `core/`（横断ヘルパー）

- `core/api-error-message.ts` に、§3.4 の表を実装する純関数を追加する（`TranslateService` に依存しない）。既存の `core/api-error-i18n-key.ts` と並置し、`apiErrorI18nKey` を再利用する。
- `errors` が配列でない場合（オブジェクト、オブジェクト配列）は本文を使わず状態コードに退避する（§2.1 の 3 形式の区別）。work record 系のような専用処理（`create-work-record.usecase.ts:30-35`）は変更しない。

### 5.2 `usecase/`（Masters 24 + save-public-plan）

- 各 usecase の `error:` コールバックを、共通ヘルパー呼び出しに置き換える。usecase が `TranslateService` を持たないもの（大半）は翻訳せずキーまたは文言を `onError` に渡す（表示層が翻訳する。§2.3）。
- `create-farm.usecase.ts` は `resolveActiverecordApiErrorI18nKey` を通す既存の流れを維持する。
- `save-public-plan.usecase.ts` は、ヘルパーの結果を `translateServerToastMessage(text, (k) => this.translate.instant(k))` に通して返す。サーバー修正（S1）後は `activerecord....farm_limit_exceeded` が翻訳される。`in` の欠落キーは §5.6 で解消する。
- `create-private-plan.usecase.ts` の整合（同関数への切替）は Q6 の回答による。

### 5.3 Crop 上限（`domain/` → `usecase/` → `adapters/` → `components/`）

1. `domain/crops/crop-create-limit.ts`: `MAX_NON_REFERENCE_CROPS_PER_USER = 20`（サーバー `crop_create_limit_policy.rs:3` と一致）、`countUserOwnedCrops`、`isCropCreateLimitReached`、`isCropLimitExceededMessage`。Farm 側（`farm-create-limit.ts`）と同じ命名・構造に揃える（[`implementation-consistency-with-existing.mdc`](../../.cursor/rules/implementation-consistency-with-existing.mdc)）。domain → core の import は Farm と同じ形になる（§2.5。是非は Q9 の範囲外の既存事項）。
2. `usecase/crops/load-crop-create-limit.*`: `CROP_GATEWAY.list()`（`usecase/crops/crop-gateway.ts:18`）を購読して件数を数え、出力ポートに `{ limitReached }` を渡す。一覧取得の失敗時は `limitReached: false`（サーバーが最終判定するための UX ヒントであり、ドメイン判定のフォールバックではない）。
3. `adapters/crops/crop-create.presenter.ts`: 出力ポートを実装し、`limitCheckLoading` / `limitBlocked` を更新する。`onError` は `isCropLimitExceededMessage(dto.message)` のとき `limitBlocked: true` かつフラッシュ無し（Farm の `farm-create.presenter.ts:21-31` と同型）。
4. `components/masters/crops/crop-create.component.ts`: 非管理者（Q4 既定）のとき `ngOnInit` で usecase を実行し、`limitCheckLoading` / `limitBlocked` で表示を切り替える。ブロック時の表示は Farm と同じ `plan-new-empty` のマークアップを使い、新しいレイアウト CSS を作らない（[`UI-COMPOSITION-RULES.md`](../design/UI-COMPOSITION-RULES.md) の L3 は Shell + Pattern + UseCase の配線のみ）。実装後に `npm run check:ui-composition`（`frontend/package.json:18`）で禁止パターンの有無を確認する。
5. component が gateway を直接購読する形（Farm の `farm-create.component.ts:200`）は踏襲しない（Q9 既定）。

### 5.4 リゾルバ（課題 5）

`core/i18n/resolve-activerecord-api-error-i18n-key.ts` に `ACTIVERECORD_CROP_LIMIT_EXCEEDED_KEY` を追加する。リテラル対応表への追加は Q7 の回答による（既定は追加しない）。

### 5.5 サーバー（Q1 / Q2 の回答により実施）

- **S1（推奨）**: `public_plan_save` の失敗本文から `record invalid: ` を除く。ドメインの `PublicPlanSaveInteractor`（`:127-128`）と、アダプタの `PlanSaveSession::call`（`plan_save_session.rs:105-111`）の 2 箇所で、`RecordInvalidError` の詳細メッセージのみを使う。
- **S2（Q1 で C を選んだ場合）**: `masters_*.rs` の presenter で、`error` のみの応答に `errors` を、`errors` のみの応答に `error` を付加する。対象は §2.1 の表の全行。`error_code` の追加は行わない（別課題）。

### 5.6 i18n カタログ

追加するキー（3 言語同パス。文言は Q5 の確認後）:

| グループ | キー |
|----------|------|
| Crop 上限 UI | `crops.new.limit_reached`、`crops.new.limit_reached_hint`、`crops.new.manage_crops_link`（Farm の `farms.new.limit_reached` / `limit_reached_hint` / `manage_farms_link` と対応） |
| `in` の欠落（課題 4 本体） | `activerecord.errors.models.crop.attributes.user.crop_limit_exceeded` |
| サーバー送出キーの欠落（Q8 既定の範囲） | `crops.flash.reference_flag_denied`（全言語）、`activerecord.errors.models.crop.attributes.updated_at.blank`（全言語）、`crops.flash.no_permission` / `not_found` / `reference_flag_admin_only` / `reference_only_admin`（`in`）、`crops.flash.cannot_delete_in_use.plan` / `.other`（`en`, `in`） |
| コード参照で全言語欠落の 7 件 | §2.6 の表 |
| `in` のみ欠落 | `crops.flash.not_found` |

追加しないもの: `ja` / `en` の片側のみのキー（参照なし。削除も追加も本書の範囲外）、`in` に無い残りの約 200 件（本課題のエラー契約に関係しないもの）。それらの扱いは、ユーザーが「翻訳漏れ洗い出し」を別途依頼したときに [`i18n-completion-workflow`](../../.cursor/skills/i18n-completion-workflow/SKILL.md) に従って実施する。

---

## 6. TDD 計画

実行は [`test-common`](../../.cursor/skills/test-common/SKILL.md) のスクリプトのみ。`npm test` の直接実行は禁止。出力は `./tmp/{UUID}.log` にリダイレクトしてから `rg` で確認する（`AGENTS.md`）。

### 6.1 実行方法

| 対象 | コマンド | 備考 |
|------|----------|------|
| フロント（個別 spec） | `.cursor/skills/test-common/scripts/run-test-frontend.sh --include=src/app/<path>.spec.ts > ./tmp/<UUID>.log 2>&1` | スクリプトは引数を `npm test -- --watch=false <args>` に渡す（`run-test-frontend.sh:3-24`）。テストビルダーは `@angular/build:unit-test`（`frontend/angular.json:104-106`）。`--include` がこのビルダーで有効かは**未確認**（実装着手時に最初に確認する。無効なら引数なし全件で RED 対象を確認） |
| フロント（全件） | `.cursor/skills/test-common/scripts/run-test-frontend.sh > ./tmp/<UUID>.log 2>&1` | 個別 GREEN 後に実行 |
| ドメイン | `.cursor/skills/test-common/scripts/run-test-rust-domain.sh -- <テスト名の一部> > ./tmp/<UUID>.log 2>&1` | スクリプトは `cargo test -p agrr-domain "$@"` を実行（`run-test-rust-domain.sh:23`）。アダプタのテストを個別に走らせる場合の追加引数は**未確認** |
| R4 契約 | `scripts/run-rust-contract-tests.sh > ./tmp/<UUID>.log 2>&1` | 個別テスト名指定は無い。全件を実行し、ログから該当テスト名を `rg` する。サーバーコード変更後は `rebuild-restart.sh` が先 |

長時間コマンドは [`process-monitor`](../../.cursor/skills/process-monitor/SKILL.md) で終了コードを取得してから結果を断定する。完了後は [`test-slow-detection`](../../.cursor/skills/test-slow-detection/SKILL.md) を実施する。

### 6.2 RED テスト（フロントエンド。方針 B）

すべて現状のコードで**意図した理由で失敗する**ことを確認してから実装に進む。

| ID | spec ファイル（案） | Given / When / Then | RED になる理由 |
|----|---------------------|---------------------|----------------|
| T1 | `frontend/src/app/core/api-error-message.spec.ts`（新規） | 下表の 9 ケースを表で検証 | ヘルパーが存在しない |
| T2 | `frontend/src/app/usecase/crops/update-crop.usecase.spec.ts`（新規） | Given `gateway.update` が `HttpErrorResponse` を投げる。When `execute`。Then `onError` の `message` が期待値。ケース: 403 `{error:'crops.flash.no_permission'}` → 同キー、422 `{error:'crops.flash.reference_flag_denied'}` → 同キー、409 `{error:'stale_record'}` → `common.api_error.conflict`、422 `{errors:['a','b']}` → `'a, b'`（GREEN の保護テスト） | 現状は `errors` のみ読むため、`error` 形式は `Http failure response for ...` になる（`update-crop.usecase.ts:34-37`） |
| T3 | `frontend/src/app/usecase/farms/update-farm.usecase.spec.ts`（新規） | T2 と同型。403 `{error:'farms.flash.no_permission'}`、422 `{error:'<msg>'}` | `update-farm.usecase.ts:27-31` が `error` を読まない |
| T4 | `frontend/src/app/usecase/masters-mutation-error-contract.spec.ts`（新規、表駆動） | Given 24 usecase それぞれと、指定メソッドが投げる `HttpErrorResponse(422, {errors:['m']})` と `HttpErrorResponse(422, {error:'m'})`。When `execute`。Then どちらも `onError({ message: 'm' })` | 下記の 20 usecase（RED）。GREEN 保護は 4 件 |
| T5 | `frontend/src/app/core/i18n/resolve-activerecord-api-error-i18n-key.spec.ts`（拡張） | Given `ACTIVERECORD_CROP_LIMIT_EXCEEDED_KEY`。When resolver に渡す。Then 同キーを返す。定数値が `activerecord.errors.models.crop.attributes.user.crop_limit_exceeded` | 定数が存在しない（型エラー = RED） |
| T6 | `frontend/src/app/domain/crops/crop-create-limit.spec.ts`（新規） | `farm-create-limit.spec.ts` と同型。`countUserOwnedCrops` は `is_reference !== true` のみ数える。20 件で `isCropCreateLimitReached` が true、19 件で false。`isCropLimitExceededMessage(key)` が true、他は false | モジュールが存在しない |
| T7 | `frontend/src/app/usecase/crops/load-crop-create-limit.usecase.spec.ts`（新規） | Given `list()` が非参照 20 件 + 参照 5 件。When `execute`。Then `present({ limitReached: true })`。19 件 → `false`。`list()` がエラー → `false` | usecase が存在しない |
| T8 | `frontend/src/app/adapters/crops/crop-create.presenter.spec.ts`（新規。現在存在しない） | Given view を設定。When `onError({message: <crop 上限キー>})`。Then `limitBlocked: true`、`pendingErrorFlash: null`。他のメッセージでは `pendingErrorFlash` が設定される。限度チェック結果の反映で `limitCheckLoading: false`、`limitBlocked` が更新される | `crop-create.presenter.ts:18-27` は常にフラッシュを出す |
| T9 | `frontend/src/app/components/masters/crops/crop-create.component.spec.ts`（拡張） | Given 非管理者で `list()` が 20 件。When 初期化。Then `crops.new.limit_reached` を含むブロック表示があり、`form` が無い。Given 3 件 → `form` がある。Given `list()` エラー → `form` がある。Given 管理者 → `list()` を呼ばず `form` がある（Q4 既定） | `CropCreateViewState` に該当フィールドが無い |
| T10 | `frontend/src/app/core/i18n/crops-activerecord-locale.catalog.spec.ts`（新規） | `farms-activerecord-locale.catalog.spec.ts` と同型。`crop_limit_exceeded` が ja=`作成できるCropは20件までです`、en=`You can create up to 20 Crops`、in=（承認された文言）で存在 | `in` に無い |
| T11 | `frontend/src/app/core/i18n/crops-new-locale.spec.ts`（拡張） | `crops.new.limit_reached` / `limit_reached_hint` / `manage_crops_link` が ja / en / in に存在し、en / in に日本語文字を含まない（既存の `JAPANESE_UI` 検査を流用） | キーが存在しない |
| T12 | `frontend/src/app/core/i18n/api-error-keys-locale.catalog.spec.ts`（新規） | Given 定数配列 `SERVER_EMITTED_ERROR_KEYS`（§2.6 の表のうち Q8 の範囲）と `CODE_MESSAGE_KEYS`（§2.6 の 7 件 + `crops.flash.not_found`）。When 各キーを 3 言語で引く。Then すべて非空文字列 | §2.6 の欠落キー |
| T13 | `frontend/src/app/usecase/public-plans/save-public-plan.usecase.spec.ts`（既存を更新） | Given 422 `{success:false, error:'activerecord.errors.models.farm.attributes.user.farm_limit_exceeded'}` と `translate.instant` のモック。When `execute`。Then `onError` の `message` が翻訳結果。200 + `success:false` の経路（`:37-41`）も同様。既存の `'Crop limit exceeded'` 期待（`:142`）はキーに置換 | 現状は生のまま返す（`:51-56`） |

**T1 のケース**（`core/api-error-message.spec.ts`）:

1. `{errors:['a','b']}` → `'a, b'`
2. `{errors:['  ','x']}` → `'x'`（空要素を除外）
3. `{error:'k'}` → `'k'`
4. `{errors:['a'], error:'b'}` → `'a'`（Q10 既定）
5. 本文なしの `HttpErrorResponse(404)` → `common.api_error.not_found`
6. `{errors:{name:['x']}}`（オブジェクト形）→ 状態コード由来のキー（例外を投げない）
7. `{errors:[{path:'p', message:'m'}]}`（オブジェクト配列）→ 状態コード由来のキー
8. `HttpErrorResponse(409, {error:'stale_record'})` → `common.api_error.conflict`
9. `Error('boom')`（状態コード無し）→ `'boom'`。`Error('')` → `common.api_error.generic`

**T4 の RED / GREEN 内訳**（§2.1 の表から機械的に導出）:

| 区分 | usecase |
|------|---------|
| RED（`{error:'m'}` を読めない） | create: crop, farm, pest, pesticide, fertilize, agricultural-task。update: crop, farm, pest, pesticide, fertilize, agricultural-task |
| RED（`{errors:['m']}` も `{error:'m'}` も読めない） | create-field、update-field、update-interaction-rule、delete: farm, field, fertilize, agricultural-task, interaction-rule |
| GREEN（保護） | create-interaction-rule、delete-crop、delete-pest、delete-pesticide |

RED は合計 20 usecase（create 7、update 8、delete 5）。Q6 の回答により、crop 下位リソース（`update-crop-stage`、`update-*-requirement` の 5 usecase）を表の行として追加する。

### 6.3 RED テスト（サーバー）

Q1 / Q2 の回答後に確定する。以下は S1（既定で実施）と S2（Q1 で C を選んだ場合）。

| ID | 場所 | Given / When / Then | RED になる理由 |
|----|------|---------------------|----------------|
| S-T3 | `crates/agrr-domain/test/cultivation_plan/interactors_public_plan_save_interactor_test.rs`（既存に追加。既存の Stub 群を流用） | Given 永続化ポートが `RecordInvalidError::new(Some("activerecord.errors.models.farm.attributes.user.farm_limit_exceeded"), None)` を返す。When `PublicPlanSaveInteractor::call`。Then 出力ポートの失敗は `KIND_SAVE_FAILED`、`message == Some("activerecord.errors.models.farm.attributes.user.farm_limit_exceeded")` | `public_plan_save_interactor.rs:127-128` は `invalid.to_string()` で `record invalid: ` が付く |
| S-T4 | `crates/agrr-adapters-sqlite/src/cultivation_plan/plan_save_session_integration_test.rs`（既存に追加。`invoke_save` 流用） | Given 非参照農場を 4 件持つユーザーと保存対象の公開プラン。When `invoke_save`。Then 出力が失敗で、`error_message` が上限キーのみ（接頭辞なし） | `plan_save_session.rs:109` が `err.to_string()` |
| S-T1 | `crates/agrr-r4-contract/tests/contracts.rs`（追加。C 案のみ） | Given `developer_session_id` と `seed_masters_crop(user_id)`。When `PATCH /api/v1/masters/crops/{id}` に `{"crop":{"name":"x"}}`（`updated_at` なし）。Then 422、`body["error"] == "activerecord.errors.models.crop.attributes.updated_at.blank"` かつ `body["errors"]` が同じ 1 要素配列 | 現状は `error` のみ（`masters_crops.rs:314`、`crop_update_interactor.rs:68-77`）。`errors` が無い |
| S-T2 | 同（C 案のみ） | Given 上限（20 件）に達した専用ユーザー。When `POST /api/v1/masters/crops`。Then 422、`errors[0]` が `crop_limit_exceeded` キー、C 案では `error` も同値 | C 案では `error` が無い（`masters_crops.rs:283`）。**共有ユーザー（`developer_session_id`）に 20 件を作ると他の R4 テストの上限を壊すため、専用ユーザーが要る**（`support.rs:164` のコメントが同種の問題を示す）。専用ユーザー用ヘルパーの有無は未確認 |

S1 のみ実施する場合、実行するのは S-T3 と S-T4（ドメイン / アダプタ）。R4 契約は `rebuild-restart.sh` 後に全件を実行して回帰を確認する。

---

## 7. 実装ステップ

1 論理変更 = 1 コミット。各ステップは「RED を確認 → 実装 → 個別 GREEN」の順（[`tdd-on-edit`](../../.cursor/skills/tdd-on-edit/SKILL.md)）。Q1〜Q10 の確認が済んでいない間に着手できるのは、既定で進められるステップ 1〜6。

| 順 | コミット | 内容 | RED → GREEN |
|----|----------|------|-------------|
| 1 | `core: add api error message helper` | `core/api-error-message.ts` | T1 |
| 2 | `usecase: read error and errors in masters update usecases` | update-crop、update-farm、update-field、update-interaction-rule ほか update 全般 | T2, T3, T4（update 行） |
| 3 | `usecase: read error and errors in masters create and destroy usecases` | create 7、delete 5 | T4（create / delete 行） |
| 4 | `i18n: add crop limit and server-emitted error keys` | 3 言語のカタログ追加（`crop_limit_exceeded`、`crops.flash.*`、コード参照 7 件ほか） | T10, T12 |
| 5 | `feat(crops): pre-check crop create limit` | domain → usecase → presenter → component → `crops.new.*` の順 | T5, T6, T7, T8, T9, T11 |
| 6 | `usecase(public-plans): translate save error message` | `save-public-plan` に helper + `translateServerToastMessage` | T13 |
| 7 | `fix(public-plan-save): drop "record invalid" prefix from failure message`（Q2 で承認された場合） | domain と adapter の 2 箇所 | S-T3, S-T4 |
| 8 | `feat(server): include error and errors in masters failures`（Q1 で C を選んだ場合） | `masters_*.rs` の presenter | S-T1, S-T2 ほか |
| 9 | `docs: align openapi Error schema`（課題 08 の作業として、または Q1 の回答後） | `docs/api/openapi.yaml` | – |

ステップ 7 は 6 と独立して実施できるが、ユーザーに見える結果が完成するのは両方の完了後。ステップ 5 では、Farm 側の実装（`farm-create.component.ts`、`create-farm.usecase.ts`、`farm-create.presenter.ts`）には触れない。

各ステップの完了時:

1. 個別 spec を `run-test-frontend.sh` で GREEN にする。
2. ステップ 2・3・5 の後にフロント全件を実行する。
3. `test-slow-detection` を実施する。
4. サーバーに触れたステップ（7, 8）は `rebuild-restart.sh` → `run-rust-contract-tests.sh` → `run-test-rust-domain.sh` を実行する。

---

## 8. リスク・未確定事項

| # | リスク / 未確定 | 対応 |
|---|-----------------|------|
| R1 | `ng test --include` の可否が未確認（`node_modules` 未導入）。可否により個別 RED の確認手順が変わる | ステップ 1 の前に確認する。無効なら全件実行で RED を確認し、ログから該当 spec を `rg` する |
| R2 | 課題 2 の `record invalid: <key>` は**コード読解による導出**。実行して本文を観測していない | S-T3 / S-T4 の RED 実行で確定する。観測結果が異なれば §2.4、§3.3 を修正する |
| R3 | edit / detail 系 presenter が検証文言を `common.api_error.generic` に丸める（§2.3）ため、usecase を直しても edit 画面の見た目は変わらない範囲がある | Q3。既定では presenter は変更しないため、受け入れ条件は usecase の出力（`onError.message`）で定義する |
| R4 | 挙動変更: 本文の無い `HttpErrorResponse` で、従来は `err.message`（`Http failure response ...`）を返していたが、ヘルパー適用後は `common.api_error.*` キーを返す。生メッセージを期待するテスト・画面が無いかは未確認 | 各 usecase の既存 spec を GREEN のまま保つ。フロント全件で回帰を確認する |
| R5 | サーバーの上限計数は組織単位、フロントの件数は一覧（`index_list_filter_for_user`）ベースで、両者が一致するかは未確認 | 事前チェックは UX ヒントに限定し、サーバーエラー時のブロック表示（T8）で最終判定を受ける |
| R6 | 管理者の Crop 事前チェック（参照作物は上限対象外）の扱い | Q4。既定は非管理者のみ |
| R7 | Crop 更新は `updated_at` が必須（`crop_update_interactor.rs:68-77`）。フロントの `update-crop.usecase.ts:66` は `updated_at != null` のときだけ送る。未送信だと 422 になるが、フロントが常に送っているかは未確認。本課題の範囲外の隣接事項として記録する | 課題 11（low-priority-misc）または別課題で確認 |
| R8 | Masters 以外のルート（`plan_variance_learning.rs` ほか）の `error` / `errors` 混在は突合していない | 共通ヘルパーを他 usecase に広げる場合（Q6）に別途調査 |
| R9 | 外部 API キークライアントが `error` / `errors` のどちらに依存しているか不明 | Q1。C 案は付加的なので互換だが、A 案は不可 |
| R10 | 既存 CI ゲート `check-hardcoded-i18n` は「メッセージとしてキーを渡す」使い方を検査しない（§2.6）。今回の欠落 7 件が再発し得る | T12 で既知キーを固定する。ゲート拡張は本課題の範囲外（提案のみ。実施は別途ユーザー確認） |
| R11 | `in` の欠落キーが ja にフォールバックするかは未確認（ngx-translate v17 の挙動） | 実行時確認は未実施。キーを追加すれば挙動に依存しない |
| R12 | Hindi 訳の品質確認者が必要 | Q5 |
| R13 | 上限のキー名 / 文言の Farm との対称性が崩れる（`farms.new.*` は `farm_limit_reached` 系が別にもある: `ja.json:2442` など） | 追加前に `crops.*` 側の既存キー（`crops.new.*`）を再確認し、命名を Farm に揃える |

---

## 9. 受け入れ条件

### フロントエンド（B 案）

1. §6.2 の T1〜T13 がすべて GREEN。
2. Masters の 24 usecase が、`{errors:['m']}` と `{error:'m'}` の両方に対して `onError({ message: 'm' })` を返す（T4）。
3. 409 の本文が `stale_record` のとき `common.api_error.conflict` を返す（T2）。
4. `errors` がオブジェクト / オブジェクト配列でも例外を投げず、状態コード由来のキーを返す（T1）。
5. Crop 上限（20 件）に達した非管理者は、フォーム送信前にブロック表示が出る。サーバーが上限エラーを返した場合もブロック表示に切り替わり、フラッシュは出ない（T8, T9）。
6. `save-public-plan` の失敗メッセージが、キーを含む場合は翻訳された文言になる（T13）。
7. `assets/i18n/{ja,en,in}.json`: §5.6 の追加キーが 3 言語の同パスに存在する。`in` の `crop_limit_exceeded` が存在する（T10）。§2.6 のコード参照 7 件とサーバー送出キー（Q8 の範囲）が 3 言語にある（T12）。`i18n` の diff に意図しない大量削除が無く、プレースホルダが `{{...}}` のまま。
8. `run-test-frontend.sh` の全件が GREEN。`test-slow-detection` で閾値超過テストが検出されない。`npm run check:ui-composition` が通る。
9. Farm 側のコードに変更が無い。

### サーバー（Q2 で S1 を承認した場合）

10. S-T3 / S-T4 が GREEN。公開プラン保存の上限超過応答の `error` が `record invalid: ` を含まない。
11. `rebuild-restart.sh` 後に `scripts/run-rust-contract-tests.sh`、`run-test-rust-domain.sh` が GREEN。

### サーバー（Q1 で C を選んだ場合の追加）

12. S-T1 / S-T2 が GREEN。Masters の失敗応答（§2.1 の表の全行）が `error` を必ず含む。
13. `docs/api/openapi.yaml` の `Error` スキーマが実装（`errors` は文字列配列、`error` は文字列）と一致する。

---

## 10. 関連課題との依存

`docs/spec-defects/` には本書作成時点で `03-api-key-scope-docs.md` と `04-api-key-query-auth.md` のみが存在する。他の番号は未作成のため、以下は依頼文で示された番号と本調査で確認した接点に基づく。

| 番号 | 関係 | 内容 |
|------|------|------|
| 01 resource-limit-bypass | **強い関連（先行・同時に確認）** | Farm / Crop の上限の強制方法が変わる場合（バイパス対策など）、本書のエラーキー・状態コード（422 + 上限キー）と `MAX_*` 定数の同期（`farm-create-limit.ts:8`、`crop_create_limit_policy.rs:3`）に影響する。01 が上限をサーバー側で新たに強制する経路を追加する場合、そのエラー形は本書の契約（§3.4）に合わせる |
| 02 contact-recaptcha | 弱い関連 | `contact_messages.rs:75` の `errors`（`full_messages`）と、`error` に reCAPTCHA 文言を返す応答（`contracts.rs:4595`）が混在する。共通ヘルパーの適用範囲（Q6）を広げる場合の対象 |
| 03 api-key-scope-docs | 弱い関連 | 403 の本文 `{"error":"forbidden","error_code":"insufficient_scope"}`（`masters_auth.rs:98`）は `error` + `error_code` の形。共通ヘルパーは `error` を読むため互換 |
| 04 api-key-query-auth | 関連なし（本書の範囲外） | – |
| 05 fail-closed-critical / 06 fail-closed-suspected | 弱い関連 | エラーを握りつぶさず明示する方針（`fallback.mdc`）。本書の一覧取得失敗時 `limitReached: false`（§5.3）は UX ヒントであり、ドメイン判定ではない。05 / 06 が「エラー時の既定値」を規定する場合はそれに従う |
| 08 openapi-gaps | **強い関連（後続）** | `docs/api/openapi.yaml:453-461` の `Error` スキーマ（`errors` の型）と、`error_code`、`errors` の 3 形式（§2.1）の明記。本書の Q1 の結果を反映する |
| 09 stale-design-docs | **強い関連** | `ARCHITECTURE.md:83`（i18n を `{ja,en}.json` とする記述。実際は 3 言語）、`ARCHITECTURE.md` の Resource Limits 節の「per user」（実装は組織単位: §2.5）が実態と異なる |
| 10 authorization-consistency | **強い関連** | update の認可失敗の扱いが揃っていない（pests / pesticides / fertilizes は 403、agricultural_tasks / interaction_rules は 422 + `errors: ["forbidden"]`: §3.1）。本書は「`error` / `errors` を読めるようにする」だけで、状態コードの整合は 10 で扱う |
| 11 low-priority-misc | 関連 | Crop 更新の `updated_at` 必須（R7）、`in.json` のルート直下の孤立ブロックと日本語値（§2.6）、`check-hardcoded-i18n` の検出範囲（R10）を、優先度の低い課題として引き継ぐ候補 |

---

## 付録

### 付録 A: フロントエンド usecase の読み取り位置（`frontend/src/app/usecase/`）

| usecase | 行 | 読む項目 |
|---------|----|----------|
| `crops/create-crop.usecase.ts` | 33-36 | `errors` |
| `crops/update-crop.usecase.ts` | 34-37 | `errors` |
| `crops/delete-crop.usecase.ts` | 27-34 | `error` → `errors` |
| `farms/create-farm.usecase.ts` | 28-34 | `errors`（+ リゾルバ） |
| `farms/update-farm.usecase.ts` | 27-31 | `errors` |
| `farms/delete-farm.usecase.ts` | 25-26 | `message` |
| `farms/create-field.usecase.ts` / `update-field.usecase.ts` / `delete-field.usecase.ts` | 17 | `message` |
| `pests/create-pest.usecase.ts` / `update-pest.usecase.ts` | 33-36 | `errors` |
| `pests/delete-pest.usecase.ts` | 27-34 | `error` → `errors` |
| `pesticides/create-pesticide.usecase.ts` / `update-pesticide.usecase.ts` | 32-35 | `errors` |
| `pesticides/delete-pesticide.usecase.ts` | 27-34 | `error` → `errors` |
| `fertilizes/create-fertilize.usecase.ts` / `update-fertilize.usecase.ts` | 33-36 | `errors` |
| `fertilizes/delete-fertilize.usecase.ts` | 25-26 | `message` |
| `agricultural-tasks/create-agricultural-task.usecase.ts` / `update-agricultural-task.usecase.ts` | 34-37 | `errors` |
| `agricultural-tasks/delete-agricultural-task.usecase.ts` | 27-28 | `message` |
| `interaction-rules/create-interaction-rule.usecase.ts` | 30-33 | `errors` → `error` |
| `interaction-rules/update-interaction-rule.usecase.ts` | 30 | `message` |
| `interaction-rules/delete-interaction-rule.usecase.ts` | 24 | `message` |

### 付録 B: 本調査で実行したコマンド

- `node scripts/check-hardcoded-i18n.mjs`（`frontend/` で実行、読み取りのみ）: `check-hardcoded-i18n: OK (1489 static references checked)`。
- Python による JSON 平坦化とキー集合の差分、コード中の引用符付きキー形リテラルの静的抽出（付録 D）。
- `rg` / `grep` によるコード読解。テストスイート・ビルド・サーバー起動は実行していない。

### 付録 C: i18n 差分の詳細

#### C-1: ja にあり en に無いキー（104 件）

- `activerecord.errors.*` (1): `models.cultivation_plan.attributes.farm_id.taken`
- `api.messages.*` (8): `agrr_command_failed`, `agrr_daemon_not_running`, `agrr_result_parse_failed`, `crop_not_found`, `data_fetch_failed`, `fertilizes.updated_by_ai`, `no_cultivation_period`, `weather_forecast_failed`
- `controllers.plans.*` (4): `task_schedule_items.errors.forbidden`, `task_schedule_items.errors.internal_server_error`, `task_schedule_items.errors.not_found`, `task_schedule_items.errors.parameter_missing`
- `crops.flash.*` (5): `cannot_delete_in_use.field`, `cannot_delete_in_use.other`, `cannot_delete_in_use.plan`, `delete_error`, `task_not_found`
- `crops.show.*` (1): `available_task_count`
- `farms.edit.*` (6): `form.region_blank`, `form.region_help`, `form.region_in`, `form.region_jp`, `form.region_label`, `form.region_us`
- `farms.flash.*` (4): `cannot_delete_in_use.field`, `cannot_delete_in_use.other`, `cannot_delete_in_use.plan`, `delete_error`
- `farms.new.*` (6): `form.region_blank`, `form.region_help`, `form.region_in`, `form.region_jp`, `form.region_label`, `form.region_us`
- `fields.edit.*` (9): `form.area_help`, `form.area_label`, `form.area_placeholder`, `form.daily_cost_help`, `form.daily_cost_label`, `form.daily_cost_placeholder`, `form.name_help`, `form.name_label`, `form.name_placeholder`
- `fields.show.*` (7): `area`, `confirm_delete`, `created_at`, `daily_cost`, `daily_cost_value`, `name`, `updated_at`
- `js.messages.*` (3): `jsGanttNotLoaded`, `jsPlansLoadError`, `jsPlansLoadErrorWithMessage`
- `models.cultivation_plan.*` (1): `phases.weather_data_fetched`
- `models.cultivation_plan_field.*` (1): `default_name`
- `models.farm.*` (1): `default_name`
- `plans.messages.*` (1): `plan_copied_annual`
- `plans.show.*` (9): `display_range.apply`, `display_range.end_date`, `display_range.quick_select.full_range`, `display_range.quick_select.month_back`, `display_range.quick_select.month_forward`, `display_range.quick_select.range_1year`, `display_range.quick_select.range_2year`, `display_range.start_date`, `display_range.title`
- `public_plans.errors.*` (1): `invalid_farm_size`
- `public_plans.results.*` (4): `detail.tabs.info`, `detail.tabs.stages`, `detail.tabs.temperature`, `detail.title`
- `public_plans.show.*` (29): `detail.loading_data`, `detail_temp.*`（17 件）, `info.*`（9 件）, `stages.intro`, `stages.loading`
- `services.errors.*` (3): `messages.record_invalid`, `messages.restrict_dependent_destroy.has_many`, `messages.restrict_dependent_destroy.has_one`

（`public_plans.show.*` の `detail_temp` / `info` の個別キーは付録 D のスクリプトで列挙できる。）

#### C-2: en にあり ja に無いキー（80 件）

- `api.errors.*` (9): `data_fetch_failed`, `no_cultivation_period`, `pests.daemon_not_running`, `pests.fetch_failed`, `pests.fetch_failed_with_reason`, `pests.invalid_affected_crops`, `pests.invalid_payload`, `pests.name_required`, `weather_forecast_failed`
- `api.messages.*` (1): `fertilizes.invalid_payload`
- `fields.show.*` (1): `delete_confirm`
- `plans.optimizing.*` (38): `crop_palette.{hint,in_use,title,toggle}`, `detail.{loading,loading_data}`, `gantt.{month_format,title}`, `header.*`（12 件）, `info.*`（9 件）, `show.*`（7 件）, `stages.{intro,loading}`
- `public_plans.messages.*` (2): `crop_added`, `field_added`
- `public_plans.optimizing.*` (1): `hint`
- `public_plans.results.*` (28): `detail_temp.*`（17 件）, `info.*`（9 件）, `stages.{intro,loading}`

#### C-3: `in` に無いキーの接頭辞別件数（ja かつ en にあり in に無い 239 件）

`crops.show`(56)、`crops.pests`(52)、`crops.stage`(32)、`api.errors`(25)、`errors.messages`(25)、`api.messages`(8)、`pests.form`(9)、`crops.form`(7)、`js.pest_ai`(7)、`crops.flash`(4)、`pests.show`(3)、`models.cultivation_plan`(2)、`public_plans.show`(2)、`activerecord.errors`(1)（= `crop_limit_exceeded`）、`crops.index`(1)、`errors.format`(1)、`errors.template`(1)、`jobs.optimize_cultivation_plan`(1)、`meta.default`(1)、`services.plan_save_service`(1)。

`in` にあり ja に無い 112 件のうち、ルート直下の孤立ブロック（`index.*`、`new.*`、`edit.*`、`flash.template_*`、`flash.no_permission`、`flash.redirect_to_create`）が 39 件（`in` にあり en にも無い 39 件と同一）、`plans.optimizing.*` が 38 件、`public_plans.results.*` が 29 件、その他 6 件。

### 付録 D: 再現手順（読み取り専用）

```bash
cd frontend/src/assets/i18n
python3 - <<'EOF'
import json
def flat(o, p=''):
    r = {}
    for k, v in o.items():
        kk = f'{p}.{k}' if p else k
        if isinstance(v, dict):
            r.update(flat(v, kk))
        else:
            r[kk] = v
    return r
d = {n: flat(json.load(open(f'{n}.json'))) for n in ['ja', 'en', 'in']}
ja, en, inn = set(d['ja']), set(d['en']), set(d['in'])
for name, keys in [
    ('ja_not_en', ja - en), ('en_not_ja', en - ja), ('ja_not_in', ja - inn),
    ('en_not_in', en - inn), ('in_not_ja', inn - ja), ('in_not_en', inn - en),
    ('in_missing_both', (ja & en) - inn),
]:
    print(name, len(keys))
    for k in sorted(keys):
        print('  ', k)
EOF
```

コード中のキー参照は、`frontend/src/app` の spec 以外の `.ts` / `.html` から正規表現 `(['"`])([A-Za-z][A-Za-z0-9_]*(?:\.[A-Za-z0-9_]+)+)\1` で引用符付きリテラルを抽出し、先頭セグメントがカタログのトップレベルキーに含まれるものだけを対象にして、各カタログの葉キーと照合した。`index.html` などの誤検出と、`<prefix>_` で終わる動的接頭辞は手作業で除外した。サーバー送出キーは、`crates/agrr-server/src/masters_*.rs`、`public_plan_save.rs`、`plans.rs` と、対象コンテキストの `crates/agrr-domain/src/<context>/interactors/*.rs` から `"<a.b.c>"` 形のリテラルを同様に照合した。
