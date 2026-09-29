# 08 — `docs/api/openapi.yaml` と実装の乖離（対応計画）

**種別:** 対応計画（本書はドキュメントのみ。コード・`openapi.yaml` は本書では変更しない）
**対象:** [`docs/api/openapi.yaml`](../api/openapi.yaml)（AGRR Masters API）と `crates/agrr-server/src/masters_*.rs` の実装
**パス表記:** `crop_*_interactor.rs` は `crates/agrr-domain/src/crop/interactors/`、`shared/exceptions/mod.rs` は `crates/agrr-domain/src/`、`pool/mod.rs`・`soft_delete.rs`・`crop/crop_gateway.rs` は `crates/agrr-adapters-sqlite/src/`、`masters_*.rs` は `crates/agrr-server/src/`、`contracts.rs`・`support.rs` は `crates/agrr-r4-contract/tests/`、`crop-*-api.gateway.ts` は `frontend/src/app/adapters/crops/` を指す（特記なきものは同ディレクトリ規則）。
**根拠の扱い:** 本書の事実は 2026-09-29 時点のリポジトリ（`master`）を読んで確認したものだけを `file:line` 付きで記す。コードを読んだだけで実行していないものは「未実測」、読めていないものは「未確認」と明記する。本書作成時にテストは実行していない（`docs/spec-defects/` は本書作成時点で本書のみ。他番号の文書は未作成のため、第 10 章の依存関係は本書側の想定である）。

---

## 1. 概要と重大度

### 1.1 概要

`openapi.yaml` は外部スキル向けの Masters API 契約として公開されている（`docs/api/openapi.yaml:5-7`、`llms.txt:10`）。実装（`crates/agrr-server/src/masters_*.rs`）と突き合わせると、次の 3 種類の乖離がある。

1. **成功レスポンスの食い違い** — 削除の 200/204、setup_proposal の apply 応答、blueprint 作成のリクエスト形。準拠クライアントが誤動作する。
2. **エラー契約の欠落・誤り** — 403 / 409 / 429 / 400 の未記載、`Error.errors` の型、`error_code`、記載された 404 が実際は 422 になる操作。
3. **スキーマ・範囲の不足** — `Crop` 等のレスポンススキーマが部分集合、`PUT` エイリアス、セッション認証、記載外エンドポイントの範囲基準。

契約の正の優先順位は `CLAUDE.md`（Norm priority）で「1. 観測可能なテスト → 2. LAYER-RULES → 3. rules」であり、`ARCHITECTURE.md` の R9 も contract-first を「ports/DTOs + observable tests」と定めている。したがって既定の方針は **契約テスト（R4）で固定された実装の挙動を正とし、`openapi.yaml` を実装に合わせる**である（第 3 章）。

### 1.2 重大度の基準

| 重大度 | 基準 |
| ------ | ---- |
| High | `openapi.yaml` のとおりに実装したクライアントが、成功系でも失敗する・誤って解釈する（ステータス、必須パラメータ、リクエスト形の不一致） |
| Medium | 失敗系の分岐が漏れる、または記載が実際と矛盾して誤ったエラー処理になり得る（403/409/429/400 未記載、記載 404 が実際は 422） |
| Low | 記述不足で実害は限定的（部分集合スキーマ、`PUT` エイリアス、security 表記、範囲基準） |

### 1.3 サマリ

| ID | 項目 | 重大度 |
| -- | ---- | ------ |
| D-01 | stage 削除: 200 記載 / 実装 204 | High |
| D-02 | blueprint 削除: 200 記載 / 実装 204 | High |
| D-03 | 403 が全く記載されていない・`Error` に `error_code` が無い | Medium |
| D-04 | 429 が setup_proposal にしか記載されていない | Medium |
| D-05 | Crop / CropStage / AgriculturalTask の `PUT` が未記載（PATCH のみ） | Low |
| D-06 | crop_stage の 400 `Invalid parameters` が未記載 | Medium |
| D-07 | setup_proposal の apply 201 body、apply 時の 200 検証失敗、422 が未記載・誤記 | High |
| D-08 | `Crop` 等のスキーマが実 JSON の部分集合、リクエスト body のプロパティ不足 | Low |
| D-09 | セッション Cookie 認証がグローバル `security` に無い | Low |
| D-10 | openapi 記載外の Masters エンドポイントが多数あり、subset の範囲基準が文書化されていない | Low |
| D-11 | blueprint 作成: openapi は `task_schedule_blueprint` ラッパー / 実装はフラット body | High |
| D-12 | 記載 404 が実際は 422（crop update/destroy、crop show（コード読みによる導出）、agricultural_task update/destroy） | Medium |
| D-13 | crop update: `updated_at` 必須・409 `stale_record` が未記載 | High |
| D-14 | `Error.errors` の要素型が `object` だが実際は文字列配列 | Medium |
| D-15 | 削除時の undo 応答形状（crop はネスト、agricultural_task はフラット）が未記載 | Low |
| D-16 | JSON 構文不正・型不一致・`mode` 欠落時のエラー body（axum 標準拒否） | 未確認 |

D-01〜D-10 は依頼で指定された課題。D-11〜D-16 は再確認の過程で新たに確認した乖離である。

---

## 2. 現状

### 2.1 乖離一覧表

「openapi 記載」は `docs/api/openapi.yaml`、「実装」は `crates/agrr-server/src/`（特記なければ）の行番号。

| ID | 項目 | openapi 記載 | 実装 | 根拠 file:line | 重大度 |
| -- | ---- | ------------ | ---- | -------------- | ------ |
| D-01 | `DELETE .../crop_stages/{id}` | `200 Deleted`（`openapi.yaml:189-191`） | `204`、body なし。対象なしは `404 {"error":"not found"}` | `masters_crop_stages.rs:376-403`（204 は 400）、R4 `contracts.rs:2494`（204 表明は 2514）、Angular `crop-stage-api.gateway.ts:34`（`delete<void>`） | High |
| D-02 | `DELETE .../task_schedule_blueprints/{id}` | `200 Deleted`（`openapi.yaml:337-338`） | `204`、body なし | `masters_crop_task_schedule_blueprints.rs:343-385`（204 は 359）、Angular `crop-task-schedule-blueprint-api.gateway.ts:48`（`delete<void>`）。R4 に blueprint 削除のテストは無い（`contracts.rs` の blueprint 系は 2067〜2195 の作成・一覧・regenerate のみ） | High |
| D-03 | 403 | 全 operation に無い。`Error` は `error` / `errors` のみ（`openapi.yaml:453-461`） | (a) API キーのスコープ不足: `403 {"error":"forbidden","error_code":"insufficient_scope"}`。(b) ポリシー拒否: crop show/update/destroy は `403 {"error":"crops.flash.no_permission"}`、agricultural_task の list/show/destroy は `403`。stage・blueprint・setup_proposal は 403 にならない（404） | (a) `masters_auth.rs:95-100`、判定 `masters_auth.rs:109-128`、要求スコープ分類 `masters_api_scope.rs:16-34`、R4 `contracts.rs:3014`（403 と `error_code` を表明）・`3070`（apply も 403）。(b) `masters_crops.rs:300-303, 347-350, 364-367`、`masters_agricultural_tasks.rs:94-97, 134, 289`、`masters_crop_stages.rs:75, 122`（404）、`masters_crop_setup_proposal.rs:115-120`（404）、`crop_setup_proposal_interactor.rs:68-71`（編集不可は not found 扱い） | Medium |
| D-04 | 429 | setup_proposal のみ（`openapi.yaml:382-383`）。`RateLimited` は `openapi.yaml:440-450` | 全 Masters ルートに適用。`429 {"error":"rate_limit"}` + `Retry-After`（秒）。認証に失敗した匿名リクエストは対象外 | `masters_routes.rs:7-29`（`route_layer`）、`masters_rate_limit.rs:109-136`（tier 分類）、`138-150`（応答）、`152-176`（middleware、匿名除外は 169-171）、R4 `contracts.rs:3153` | Medium |
| D-05 | `PUT` | Crop / CropStage / AgriculturalTask の update は `patch` のみ（`openapi.yaml:84, 168, 248`） | `PUT` と `PATCH` が同一ハンドラ。blueprint は `PATCH` のみ | `masters_crops.rs:37-43`、`masters_crop_stages.rs:48-51`、`masters_agricultural_tasks.rs:40-43`、`masters_crop_task_schedule_blueprints.rs:57-60`。Angular は `PATCH` を使用（`crop-api.gateway.ts:25`、`crop-stage-api.gateway.ts:24`） | Low |
| D-06 | crop_stage の 400 | create: 404/422 のみ、update: 404 のみ（`openapi.yaml:144-151, 179-185`） | create は `name` 空 / `order` 欠落で `400 {"error":"Invalid parameters"}`。update は `name`・`order` 双方欠落または `name` 空白で同 400。reorder は `crop_stages` 空で同 400 | `masters_crop_stages.rs:179-197, 199-228, 320-328`。R4 に 400 を表明するマスタ系テストは無い（`contracts.rs` の 400 表明は 4669 の backdoor 系 1 件のみ） | Medium |
| D-07 | setup_proposal のレスポンス | `200` は `CropSetupProposalDryRunResponse`（`mode` は `enum [dry_run]`、`errors` の items は `object`）、`201` は説明のみ（`openapi.yaml:368-375, 624-635`） | 200: `{"mode":"dry_run","valid":true,"normalized":…}`。200: 検証失敗は `{"mode":"dry_run\|apply","valid":false,"errors":[{"path","message"}]}`（**apply でも 200**）。201: `{"mode":"apply","valid":true,"normalized":…,"result":{"stage_ids","agricultural_task_ids","blueprint_ids"}}`。404: `{"error":"crop not found"}`。422: `{"error":"mode must be dry_run or apply"}` | `masters_crop_setup_proposal.rs:45-56, 73-82, 84-97, 99-113, 115-120, 144-154`、R4 `contracts.rs:2669`（検証失敗 200）・`2693`・`2715`（201 と `result` の一部）。apply 時の検証失敗 200 と invalid mode 422 を表明するテストは無い | High |
| D-08 | スキーマ部分集合 | `Crop` は `id/name/variety/region/is_reference` のみ（`openapi.yaml:463-475`）。`CropStage` は `id/name/order`（`504-511`）。agricultural_task・blueprint の 200 は説明のみ | `Crop` は 12 キー（`id,name,variety,area_per_unit,revenue_per_area,region,groups,user_id,created_at,updated_at,is_reference,crop_stages`）。`crop_stages` は show のみ実データ、list/create/update は `[]`。stage は `crop_id` と要件オブジェクト 4 種を含み得る。task は 13 キー、blueprint は 19 キー | `masters_json.rs:97-112, 114-168`、`masters_crops.rs:84, 114, 158, 197`、`masters_agricultural_tasks.rs:52-68`、`masters_crop_task_schedule_blueprints.rs:63-85` | Low |
| D-09 | セッション認証 | グローバル `security` は `bearerApiKey` と `headerApiKey` のみ（`openapi.yaml:23-25`）。`sessionCookie` は定義済み（`399-403`）、description 冒頭では「Session cookie authentication has full Masters access」（`13`） | Cookie `session_id` を Bearer / `x-api-key` と並べて解決。セッション主体はスコープ検査なし | `masters_auth.rs:44-61, 63-84, 115-118`。`getting-started.md:24` も「API キー または ログインセッション Cookie」 | Low |
| D-10 | subset の範囲基準 | 「Public subset … crop master data, agricultural tasks, task schedule blueprints, and external skill `setup_proposal`」（`openapi.yaml:5-7`）。含める/除く基準の記述なし | 同じ認証・スコープ・レート制限が下記の記載外エンドポイントにも及ぶ（2.3 参照） | `masters_routes.rs:7-29`、`masters_api_scope.rs:17`（`/api/v1/masters/` 配下はすべて分類）、`llms.txt:10`（「OpenAPI contract for agrr-server HTTP APIs」と全体契約のように記載） | Low |
| D-11 | blueprint 作成のリクエスト形 | `TaskScheduleBlueprintCreateRequest` は `task_schedule_blueprint` ラッパー（`openapi.yaml:542-546`）。フィールド定義なし | フラット body（`agricultural_task_id`, `stage_order`, `stage_name`, `gdd_trigger`, `task_type`, `description`, `priority`）。ラッパーは未知キーとして無視され、必須項目欠落で `422 missing_agricultural_task_id` になる（serde の既定動作に基づく導出・未実測） | `masters_crop_task_schedule_blueprints.rs:135-150, 392-395`、Angular `crop-task-schedule-blueprint-api.gateway.ts:20-26`（フラット送信）、R4 `contracts.rs:2127, 2158`（フラット送信で 201/422） | High |
| D-12 | 記載 404 が実際は 422 | crop show/update/destroy、agricultural_task update/destroy に `404`（`openapi.yaml:82, 99, 110, 263, 274`） | crop update: not found は `UpdateFailure::Error` → `422 {"error":"record not found"}`。crop destroy: not found は `422 {"error":"<crops.flash.not_found の訳>"}`。agricultural_task update は全失敗が `422 {"errors":[msg]}`（ポリシー拒否も 422）。agricultural_task destroy の失敗は `422`。crop show は `e.message == "Crop not found"` の一致でのみ 404 だが、`RecordNotFoundError` の表示文字列は `record not found` のため 422 になると読める（未実測） | `crop_update_interactor.rs:44-50`、`masters_crops.rs:297-315, 345-360, 362-370`、`crop_destroy_interactor.rs:56-67`、`crop_detail_interactor.rs:50-62`、`shared/exceptions/mod.rs:6-7`、`agrr-adapters-sqlite/src/pool/mod.rs:149-162`、`crop/crop_gateway.rs:102-107`、`masters_agricultural_tasks.rs:228-238, 286-292` | Medium |
| D-13 | crop update の必須項目・409 | `CropUpdateRequest` は `name` / `variety` のみ、レスポンスは 200/401/404（`openapi.yaml:492-502, 85-100`） | body の `crop.updated_at` が必須（空なら `422`）。古い値は `409 {"error":"stale_record"}`。`area_per_unit`, `revenue_per_area`, `region`, `groups`, `is_reference` も受理。非 admin が `is_reference` を変えると `422` | `masters_crops.rs:51-61, 164-201, 304-311`、`crop_update_interactor.rs:55-80, 137-140`。R4 に masters crop の update テストは無い（`contracts.rs:345` の 409 は work_records 用） | High |
| D-14 | `Error.errors` の型 | `errors: array of object`（`openapi.yaml:458-461`） | `errors` は文字列配列（crop 作成 `["name is required"]`、stage `["invalid"]`、task `[msg]`、blueprint の検証失敗）。オブジェクト配列なのは setup_proposal の `errors` のみ（`{path,message}`） | `masters_crops.rs:125-129, 281-284`、`masters_crop_stages.rs:253-255`、`masters_agricultural_tasks.rs:181-185`、`masters_crop_task_schedule_blueprints.rs:422-425`（`errors` の型は `Vec<String>`: `crates/agrr-domain/src/crop/dtos/masters_crop_task_schedule_blueprint_create_failure.rs:15`）、`masters_crop_setup_proposal.rs:144-154` | Medium |
| D-15 | 削除の undo 応答 | crop: 「Deleted (undo token may be returned)」、task: 「Deleted」（`openapi.yaml:106-107, 270-271`） | crop は常に `200 {"undo":{"undo_token","undo_path","toast_message","undo_deadline","auto_hide_after"}}`。agricultural_task は `200` でフラット（`undo_token, undo_deadline, toast_message, undo_path, auto_hide_after, resource, redirect_path, resource_dom_id, metadata`） | `masters_json.rs:170-186`、`masters_crops.rs:230-234`、`masters_agricultural_tasks.rs:283-285`、`agrr-adapters-sqlite/src/soft_delete.rs:44-56` | Low |
| D-16 | 構文不正・欠落パラメータ | 記載なし | `Json<…>` / `Query<…>` extractor（`mode` は `SetupProposalQuery` の必須文字列）。axum 0.8 の標準拒否（400/415/422 とテキスト body）になると考えられるが、ステータスと body は実測していない | `masters_crop_setup_proposal.rs:33-36, 43`、`crates/agrr-server/Cargo.toml:29`（axum 0.8）。**未確認** | 未確認 |

### 2.2 実 API の確定表（openapi 記載 operation）

以下は上記の実装読解から確定した「実際のステータスとボディ」。`401` は全 operation 共通で `{"error":"unauthorized"}`（`masters_auth.rs:102-107`）。`403 scope`・`429` も全 operation 共通（D-03、D-04）。「未実測」は実行して確認していない導出。

**共通**

| 状況 | ステータス | body | 根拠 |
| ---- | ---------- | ---- | ---- |
| 資格情報なし・不正（Bearer / `x-api-key` / Cookie `session_id`。クエリ `api_key` は無視） | 401 | `{"error":"unauthorized"}` | `masters_auth.rs:44-61, 102-107`、R4 `contracts.rs:3141` |
| API キーにスコープ不足（read のみで write、または setup_proposal apply） | 403 | `{"error":"forbidden","error_code":"insufficient_scope"}` | `masters_auth.rs:95-100`、`masters_api_scope.rs:16-34` |
| レート制限超過（認証済みのみ） | 429 | `{"error":"rate_limit"}` + `Retry-After` | `masters_rate_limit.rs:138-150` |

**crops**

| operation | 成功 | 失敗 | 根拠 |
| --------- | ---- | ---- | ---- |
| `GET /crops` | 200 `[Crop]`（`crop_stages` は `[]`） | 422 `{"error":msg}` | `masters_crops.rs:63-89, 249-254` |
| `POST /crops` | 201 `Crop` | 422 `{"errors":["name is required"]}`（名前なし）、422 `{"errors":[msg]}`（ドメイン失敗。作成上限超過を含む） | `masters_crops.rs:120-162, 280-285, 338-343` |
| `GET /crops/{id}` | 200 `Crop`（`crop_stages` に実データ） | 403 `{"error":"crops.flash.no_permission"}`、存在しない場合は 422 `{"error":"record not found"}`（未実測。D-12） | `masters_crops.rs:91-118, 345-360` |
| `PATCH\|PUT /crops/{id}` | 200 `Crop`（`crop_stages` は `[]`） | 403 `crops.flash.no_permission`、409 `stale_record`、422（参照フラグ変更不可 / `updated_at` 欠落 / not found / 検証） | `masters_crops.rs:164-201, 297-315`、`crop_update_interactor.rs:44-80` |
| `DELETE /crops/{id}` | 200 `{"undo":{…}}` | 403 `crops.flash.no_permission`、422（使用中 / not found） | `masters_crops.rs:203-238, 362-370`、`crop_destroy_interactor.rs:56-88` |

**crop_stages**（stage 系の 404 は、存在しない・閲覧不可・編集不可の理由を区別せず `{"error":"not found"}`。create / reorder は自分の非参照 crop のみ対象: `masters_crop_context.rs:18-46`）

| operation | 成功 | 失敗 | 根拠 |
| --------- | ---- | ---- | ---- |
| `GET .../crop_stages` | 200 `[CropStage]` | 404 | `masters_crop_stages.rs:54-78, 126-156` |
| `POST .../crop_stages` | 201 `CropStage` | 404、400 `Invalid parameters`、422 `{"errors":["invalid"]}`（order 競合など。R4 `contracts.rs:2402`） | `masters_crop_stages.rs:179-197, 230-267`、`masters_crop_context.rs:18-46` |
| `GET .../crop_stages/{id}` | 200 `CropStage` | 404 | `masters_crop_stages.rs:80-124, 158-166`、R4 `contracts.rs:2535` |
| `PATCH\|PUT .../crop_stages/{id}` | 200 `CropStage` | 404、400 `Invalid parameters`、422 `{"errors":["invalid"]}` | `masters_crop_stages.rs:199-228, 339-374`、R4 `contracts.rs:2422, 2557` |
| `DELETE .../crop_stages/{id}` | **204（body なし）** | 404 `{"error":"not found"}` | `masters_crop_stages.rs:376-403`、R4 `contracts.rs:2494, 2592` |

**agricultural_tasks**

| operation | 成功 | 失敗 | 根拠 |
| --------- | ---- | ---- | ---- |
| `GET /agricultural_tasks`（`filter`, `q`） | 200 `[Task]` | 403 `{"error":msg}`（失敗はすべて 403） | `masters_agricultural_tasks.rs:46-50, 83-120` |
| `POST /agricultural_tasks` | 201 `Task` | 422 `{"errors":[msg]}` | `masters_agricultural_tasks.rs:176-221` |
| `GET /agricultural_tasks/{id}` | 200 `Task` | 404 `{"error":msg}`（Error）、403 `forbidden`（ポリシー） | `masters_agricultural_tasks.rs:122-157` |
| `PATCH\|PUT /agricultural_tasks/{id}` | 200 `Task` | 422 `{"errors":[msg]}`（not found・ポリシー拒否・参照フラグを含む全失敗） | `masters_agricultural_tasks.rs:223-279` |
| `DELETE /agricultural_tasks/{id}` | 200（フラット undo） | 422 `{"error":msg}`、403 `forbidden` | `masters_agricultural_tasks.rs:281-319` |

**task_schedule_blueprints**（`PUT` は無い）

| operation | 成功 | 失敗 | 根拠 |
| --------- | ---- | ---- | ---- |
| `GET .../task_schedule_blueprints` | 200 `[Blueprint]` | 404 `{"error":"Crop not found"}` | `masters_crop_task_schedule_blueprints.rs:91-133`、R4 `contracts.rs:2067, 2078` |
| `POST .../task_schedule_blueprints`（フラット body） | 201 `Blueprint` | 404 `crop_not_found`、422（`missing_agricultural_task_id` / `missing_gdd_trigger` / `invalid_stage_order` / `agricultural_task_not_found` / `duplicate_blueprint` / `validation_failed`。`error_code` 付き） | `masters_crop_task_schedule_blueprints.rs:146-193, 387-427`、R4 `contracts.rs:2127, 2158` |
| `PATCH .../task_schedule_blueprints/{id}`（フラット body） | 200 `Blueprint` | 404 `Crop not found` / `Blueprint not found`、422 `duplicate_blueprint` | `masters_crop_task_schedule_blueprints.rs:269-341, 452-473` |
| `DELETE .../task_schedule_blueprints/{id}` | **204（body なし）** | 404（同上） | `masters_crop_task_schedule_blueprints.rs:343-385` |

**setup_proposal**（`POST /crops/{crop_id}/setup_proposal?mode=…`）

| 状況 | ステータス | body | 根拠 |
| ---- | ---------- | ---- | ---- |
| `mode=dry_run` で検証成功 | 200 | `{"mode":"dry_run","valid":true,"normalized":{…}}` | `masters_crop_setup_proposal.rs:73-82`、R4 `contracts.rs:2693` |
| 検証失敗（`dry_run` / `apply` 共通） | 200 | `{"mode":"dry_run\|apply","valid":false,"errors":[{"path","message"}]}` | `masters_crop_setup_proposal.rs:84-97, 144-154`、R4 `contracts.rs:2669`（dry_run のみ） |
| `mode=apply` で成功 | 201 | `{"mode":"apply","valid":true,"normalized":{…},"result":{"stage_ids":[…],"agricultural_task_ids":[…],"blueprint_ids":[…]}}` | `masters_crop_setup_proposal.rs:99-113`、R4 `contracts.rs:2715` |
| crop が存在しない・自分の編集対象でない | 404 | `{"error":"crop not found"}` | `masters_crop_setup_proposal.rs:115-120`、`crop_setup_proposal_interactor.rs:59-71` |
| `mode` が `dry_run` / `apply` 以外 | 422 | `{"error":"mode must be dry_run or apply"}` | `masters_crop_setup_proposal.rs:45-56` |
| スコープ | dry_run は read、apply は write | | `masters_api_scope.rs:20-28` |

### 2.3 openapi 記載外の Masters エンドポイント（D-10）

`masters_routes.rs:7-29` に束ねられ、同じ認証・スコープ・レート制限を受ける。`openapi.yaml` に載っていない主なもの。

| 系統 | ルート | 根拠 |
| ---- | ------ | ---- |
| farms | `/api/v1/masters/farms`、`/farms/{id}`（`PATCH`/`PUT`/`DELETE`）、`/farms/{id}/fetch_weather_data`、`/farms/{id}/temperature_chart` | `masters_farms.rs:39-53`、`masters_farm_temperature_chart.rs:27-32` |
| fields | `/farms/{farm_id}/fields`、`/fields/{id}` | `masters_fields.rs:27-40` |
| pests / fertilizes / pesticides / interaction_rules | 一覧・作成・詳細・更新（`PUT`/`PATCH`）・削除 | `masters_pests.rs:29-36`、`masters_fertilizes.rs:31-38`、`masters_pesticides.rs:31-38`、`masters_interaction_rules.rs:32-39` |
| crop 配下 | `crops/{crop_id}/pests`（一覧・作成・削除）、`crops/{crop_id}/pesticides`（一覧）、`crops/{crop_id}/crop_stages/{stage_id}/{temperature,thermal,sunshine,nutrient}_requirement`（show/create/update/delete） | `masters_crop_pests.rs:29-39`、`masters_crop_pesticides.rs:20-25`、`masters_crop_requirements.rs:46-84` |
| crop_stages 並べ替え | `PUT crops/{crop_id}/crop_stages/reorder` | `masters_crop_stages.rs:38-43, 269-307`、Angular `crop-stage-api.gateway.ts:28` |
| 廃止・非推奨 | `crops/{crop_id}/agricultural_tasks` 系は全メソッド `410 crop_task_template_api_removed`。`task_schedule_blueprints/regenerate` は `Deprecation` / `Sunset` ヘッダー付き | `masters_crop_agricultural_tasks.rs:13-33`、R4 `contracts.rs:2197〜2290`、`builtin_generation_deprecation.rs:26-46`、`masters_crop_task_schedule_blueprints.rs:53-56, 195-267` |

**subset 基準の文書化状況（確認結果）:** `openapi.yaml:5-7` は含める領域を列挙するだけで、除外基準・除外一覧はどこにも無い。`getting-started.md:1` は「スキル作者向け」とするのみ。公式 MCP サーバーが呼ぶのは 4 本（作物一覧・作物詳細・dry_run・apply）に限られる（`tools/agrr-mcp/README.md:51-54`、`tools/agrr-mcp/src/agrr-client.mjs:23, 41, 48, 57`）。`openapi.yaml` の operation 20 本はこの 4 本を超える（stage・task・blueprint の CRUD）ため、「MCP が使うものだけ」という基準でもない。つまり**基準は文書化されておらず、現状の範囲は経緯によるものと読める（経緯は未確認）**。`llms.txt:10` は同ファイルを「agrr-server HTTP APIs の OpenAPI 契約」と説明しており、subset という自己申告と食い違う。

### 2.4 関連文書との不整合（他課題へ委譲）

| 箇所 | 内容 | 委譲先 |
| ---- | ---- | ------ |
| `getting-started.md:32-41` | 「現時点ではキーごとのスコープ列は DB に保存していません」「発行されたキーは現状読み取りと書き込みの両方が可能」。実装はスコープを強制し、既定は `["masters:read"]`（`masters_api_scope.rs:47-50`、R4 `contracts.rs:3014, 3049, 3070`、`3095` の `post_api_keys_generate_defaults_to_read_only_scopes`）。`openapi.yaml:10-13` は実装どおり | 03 |
| `getting-started.md:30` | クエリ `?api_key=` を「非推奨」の認証方式として掲載。実装は無視して 401（`masters_auth.rs:44`、R4 `contracts.rs:3141`） | 04 |
| `setup_proposal-openapi-snippet.yaml` | 「レガシー snippet・本体は openapi.yaml に統合」（`getting-started.md:92`）だが、`tools/agrr-mcp/README.md:56` と `.cursor/skills/agrr-crop-setup/SKILL.md:33` は今もスキーマの参照元にしている。snippet の responses は 200/201/401/404 のみ（`snippet:131-139`）で 403/422/429 と apply body が無い。security は `bearerApiKey` + `sessionCookie`（`snippet:109-111`）で `headerApiKey` が無い | 09 |

---

## 3. 方針

### 3.1 判断基準

「実装を正として openapi を直す」か「実装を openapi に合わせる」かは、次の順で判断する。

| 順 | 基準 | 実装を正とする条件 | openapi を正とする条件 |
| -- | ---- | ------------------ | ---------------------- |
| 1 | 観測可能な契約で固定済みか（`CLAUDE.md` Norm priority 1） | R4 契約テストや既存クライアント（Angular、MCP）が現挙動に依存している | 現挙動を固定するテスト・クライアントが無く、かつ 2 で欠陥と判定できる |
| 2 | HTTP 意味論・他操作との一貫性 | 現挙動が一般的な REST 意味論に沿う（削除 204、競合 409） | 現挙動が明らかに不整合（not found が 422、ポリシー拒否が 422 など） |
| 3 | 変更の影響範囲 | 文書修正のみで済む | 実装変更は `crates/*` 変更となり、`rebuild-restart.sh` と R4 更新が必要（`.cursor/rules/docker-dev-agrr-server-rebuild.mdc`）。既存の外部利用者が壊れる可能性は未確認 |
| 4 | 他課題との重複 | 単独で完結する | 認可の一貫性など他課題（10）の設計判断を先取りしてしまう場合は、そちらに委ねる |

**本課題の既定:** 挙動変更を伴わずに乖離を解消できる項目は、すべて `openapi.yaml` を実装に合わせる。挙動を変えるべきか判断が要る項目（D-12）は、本課題では**実挙動を openapi に正確に書く**ことに留め、挙動変更は 10（authorization-consistency）などで別途決める。

### 3.2 項目別の推奨

| ID | 推奨 | 理由 | ユーザー確認 |
| -- | ---- | ---- | ------------ |
| D-01 | openapi を `204`（body なし）に直す | R4 が 204 を表明（`contracts.rs:2514`）、Angular が `delete<void>`（`crop-stage-api.gateway.ts:34`）。実装変更は利益がなく既存利用者を壊し得る | 不要 |
| D-02 | 同上（`204`） | Angular が `delete<void>`（`crop-task-schedule-blueprint-api.gateway.ts:48`）。R4 に無いため 6.3 の T1 で固定する | 不要 |
| D-03 | `Forbidden` レスポンスを追加し、全 operation に付与。`Error` に `error_code`（string）を追加 | 実装が返している。既知の `error_code` は `insufficient_scope` のほか blueprint 系が複数（`masters_crop_task_schedule_blueprints.rs:392-425`）、廃止 API の `crop_task_template_api_removed` がある | **要**: `error_code` を自由文字列 + description で既知値を列挙するか、`enum` で固定するか。推奨は自由文字列（値の追加で契約が壊れないため） |
| D-04 | 全 operation に `429`（既存 `RateLimited`）を付与 | 全 Masters ルートに適用（`masters_routes.rs:25-28`） | 不要 |
| D-05 | 実装は変更せず、`patch` の description に「`PUT` は同義のエイリアス」と書く | フロントは `PATCH` のみ使用。`PUT` を残した経緯は未確認（`masters_auth.rs:1` に「Rails `BaseController` parity」とあるが、`PUT` との関係は未確認）。削除は外部利用者の有無が未確認のため破壊的になり得る | **要**: `PUT` を公式サポートとして記載するか、非推奨として将来削除するか。推奨は「エイリアスとして記載のみ」 |
| D-06 | openapi に `400`（`Invalid parameters`）を create / update に追加 | 実装が返している。`CropStageCreateRequest` に `name`・`order` を必須で記載 | 不要 |
| D-07 | `CropSetupProposalResponse`（200）と `CropSetupProposalApplyResponse`（201）を定義し、`422`（mode 不正）を記載。apply の検証失敗は 200 と明記 | 実装どおり。R4 が 200/201 の一部を固定済み。apply の 200 検証失敗・422 は 6.3 で固定する | 不要（ただし apply の検証失敗を 200 のままにするか 4xx にするかは別課題。本課題では現状を記載） |
| D-08 | `Crop`（12 キー）・`CropStage`・`AgriculturalTask`・`TaskScheduleBlueprint` のレスポンススキーマを実 JSON に合わせて記載。リクエスト body に実際に受理するプロパティを追加 | 実装の JSON 生成箇所が単一（`masters_json.rs`、`task_json`、`blueprint_json`） | 不要 |
| D-09 | グローバル `security` に `sessionCookie` を追加（OR） | `getting-started.md:24` と実装が両方式を許容。`sessionCookie` の description（`openapi.yaml:403`）にある「UI only」は残す | 不要 |
| D-10 | subset のまま、`info.description` に範囲基準と除外一覧、「除外エンドポイントにも同じ認証・スコープ・レート制限が及ぶ」を明記 | 全 Masters を網羅すると operation が大幅に増え（2.3 の系統すべて）、ルートの追加のたびに追随が必要になる。基準を先に決めれば範囲外の追加で乖離が生じない | **要**: (a) subset 維持 + 基準明記（推奨）、(b) 全 Masters を網羅。基準の案は 4.10 |
| D-11 | openapi をフラット body に直す | Angular・R4・実装が一致してフラット | 不要 |
| D-12 | 本課題では実挙動（422）を openapi に記載。挙動変更は 10 と合わせて判断 | 404 に揃える実装変更は crop の 3 操作と task の 2 操作に及び、認可の返し方（403/404/422）の統一方針が前提になる。crop show の 422 は未実測のため、実測後に確定 | **要**: (a) 実挙動を記載して当面維持（推奨）、(b) 実装を 404 に修正（10 と同一の変更として実施） |
| D-13 | `updated_at` を必須にし、`409`・`422`・`403` を記載 | 実装どおり。楽観ロックの契約であり、記載しないと更新が必ず 422 になる | 不要 |
| D-14 | `Error.errors` を文字列配列に直す。setup_proposal の `errors`（`{path,message}`）は専用スキーマにする | 実装どおり | 不要 |
| D-15 | 削除応答の 2 形状を別スキーマで記載 | 形状の統一は実装変更（フロントの `deleteWithUndo` が両形状を扱う: `frontend/src/app/services/masters/masters-client.service.ts:60-63`）。本課題では現状を記載 | 不要 |
| D-16 | 今回は記載しない。実測後に判断 | 未確認の挙動を契約に書かない（根拠ゲート） | 不要 |

### 3.3 ユーザー確認が必要な点（まとめ）

1. D-03: `error_code` を自由文字列にするか `enum` にするか。
2. D-05: `PUT` をエイリアスとして記載するのみでよいか、廃止方針を持つか。
3. D-10: subset を維持して基準を明記するか、全 Masters を網羅するか。基準の文言案（4.10）でよいか。
4. D-12: not found / ポリシー拒否のステータスを、本課題では現状（422）記載にとどめ、変更は 10 と一体で行うか。

これら 4 点は、確認が取れるまでは推奨案で進めてよい（いずれも `openapi.yaml` の記述を後から差し替えるだけで済み、実装には影響しない）。

---

## 4. `openapi.yaml` の具体的な差分案

以下は差分案であり、本書では適用しない。行番号は現行 `docs/api/openapi.yaml`。型が実装の JSON から一意に読めないものには「型は実装時に確定」と注記する。

### 4.1 D-01 / D-02: 削除は 204

Before（`openapi.yaml:189-191`、`337-338`）

```yaml
    delete:
      operationId: destroyCropStage
      responses:
        '200':
          description: Deleted
```

```yaml
    delete:
      operationId: destroyTaskScheduleBlueprint
      responses:
        '200':
          description: Deleted
```

After

```yaml
    delete:
      operationId: destroyCropStage
      responses:
        '204':
          description: Deleted (no response body)
```

```yaml
    delete:
      operationId: destroyTaskScheduleBlueprint
      responses:
        '204':
          description: Deleted (no response body)
```

### 4.2 D-03: 403 と `error_code`

Before（`openapi.yaml:453-461`。`components.responses` に 403 なし）

```yaml
    Error:
      type: object
      properties:
        error:
          type: string
        errors:
          type: array
          items:
            type: object
```

After（D-14 と同時に適用）

```yaml
  responses:
    Forbidden:
      description: |
        Forbidden. Either the API key lacks the required scope
        (`error_code: insufficient_scope`) or the resource policy denies the operation
        (e.g. `error: crops.flash.no_permission`).
      content:
        application/json:
          schema:
            $ref: '#/components/schemas/Error'
  schemas:
    Error:
      type: object
      properties:
        error:
          type: string
        error_code:
          type: string
          description: |
            Machine-readable code when present. Known values include `insufficient_scope`,
            `crop_not_found`, `missing_agricultural_task_id`, `missing_gdd_trigger`,
            `invalid_stage_order`, `agricultural_task_not_found`, `duplicate_blueprint`,
            `validation_failed`, `crop_task_template_api_removed`.
        errors:
          type: array
          items:
            type: string
```

適用ルール: 20 operation すべての `responses` に次を追加する（スコープ 403 は全 operation に起こり得るため）。

```yaml
        '403':
          $ref: '#/components/responses/Forbidden'
```

ポリシー拒否の 403 が起き得る operation（crop show/update/destroy、agricultural_task list/show/destroy）には、`Forbidden` の description に依存せず operation 側の description に「ポリシー拒否時も 403」と補足する。stage・blueprint・setup_proposal はポリシー拒否が 404 になるため補足しない。

### 4.3 D-04: 429 を全 operation に

Before（`openapi.yaml:382-383` のみ）

```yaml
        '429':
          $ref: '#/components/responses/RateLimited'
```

After: 20 operation すべての `responses` に同じ参照を追加する。`RateLimited`（`openapi.yaml:440-450`）は変更しない。`info.description` の「See getting-started.md」の近くに「429 は認証済みリクエストのみ対象」と補足する（匿名は対象外: `masters_rate_limit.rs:169-171`）。

### 4.4 D-05: `PUT` エイリアス

Before（`openapi.yaml:84-87` ほか 3 箇所）

```yaml
    patch:
      tags: [crops]
      summary: Update crop
      operationId: updateCrop
```

After（`updateCrop`、`updateCropStage`、`updateAgriculturalTask` の 3 箇所）

```yaml
    patch:
      tags: [crops]
      summary: Update crop
      description: |
        `PUT` is accepted on this path as an alias of `PATCH` with the same body and responses.
      operationId: updateCrop
```

### 4.5 D-06: crop_stage の 400

Before（`openapi.yaml:144-151`、`179-184`）

```yaml
      responses:
        '201':
          description: Created stage
        '401':
          $ref: '#/components/responses/Unauthorized'
        '404':
          $ref: '#/components/responses/NotFound'
        '422':
          $ref: '#/components/responses/Unprocessable'
```

After（`createCropStage`。`updateCropStage` は `'200'` の前後に同じ `'400'` を追加）

```yaml
      responses:
        '201':
          description: Created stage
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/CropStage'
        '400':
          $ref: '#/components/responses/BadRequest'
        '401':
          $ref: '#/components/responses/Unauthorized'
        '403':
          $ref: '#/components/responses/Forbidden'
        '404':
          $ref: '#/components/responses/NotFound'
        '422':
          $ref: '#/components/responses/Unprocessable'
        '429':
          $ref: '#/components/responses/RateLimited'
```

```yaml
  responses:
    BadRequest:
      description: 'Missing or blank required parameters (`error: Invalid parameters`)'
      content:
        application/json:
          schema:
            $ref: '#/components/schemas/Error'
```

リクエストスキーマ（Before: `openapi.yaml:514-526` は `crop_stage: type: object` のみ）

```yaml
    CropStageCreateRequest:
      type: object
      required: [crop_stage]
      properties:
        crop_stage:
          type: object
          required: [name, order]
          properties:
            name:
              type: string
              minLength: 1
            order:
              type: integer
    CropStageUpdateRequest:
      type: object
      required: [crop_stage]
      properties:
        crop_stage:
          type: object
          minProperties: 1
          properties:
            name:
              type: string
              minLength: 1
            order:
              type: integer
```

### 4.6 D-07: setup_proposal のレスポンス

Before（`openapi.yaml:367-383`、`624-635`）

```yaml
      responses:
        '200':
          description: dry_run result (valid or validation errors)
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/CropSetupProposalDryRunResponse'
        '201':
          description: apply succeeded
```

```yaml
    CropSetupProposalDryRunResponse:
      type: object
      properties:
        mode:
          type: string
          enum: [dry_run]
        valid:
          type: boolean
        normalized:
          $ref: '#/components/schemas/CropSetupProposal'
        errors:
          type: array
          items:
            type: object
```

After

```yaml
      responses:
        '200':
          description: |
            dry_run success (`valid: true`), or a validation failure in either mode
            (`valid: false`, `errors` populated). A failed `apply` validation is still HTTP 200.
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/CropSetupProposalResponse'
        '201':
          description: apply succeeded
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/CropSetupProposalApplyResponse'
        '401':
          $ref: '#/components/responses/Unauthorized'
        '403':
          $ref: '#/components/responses/Forbidden'
        '404':
          description: 'Crop not found or not editable by the caller (`error: crop not found`)'
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Error'
        '422':
          description: '`mode` is neither `dry_run` nor `apply` (`error: mode must be dry_run or apply`)'
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Error'
        '429':
          $ref: '#/components/responses/RateLimited'
```

```yaml
    CropSetupProposalValidationError:
      type: object
      properties:
        path:
          type: string
        message:
          type: string
    CropSetupProposalResponse:
      type: object
      required: [mode, valid]
      properties:
        mode:
          type: string
          enum: [dry_run, apply]
        valid:
          type: boolean
        normalized:
          $ref: '#/components/schemas/CropSetupProposal'
        errors:
          type: array
          items:
            $ref: '#/components/schemas/CropSetupProposalValidationError'
    CropSetupProposalApplyResponse:
      type: object
      required: [mode, valid, normalized, result]
      properties:
        mode:
          type: string
          enum: [apply]
        valid:
          type: boolean
          enum: [true]
        normalized:
          $ref: '#/components/schemas/CropSetupProposal'
        result:
          type: object
          properties:
            stage_ids:
              type: array
              items:
                type: integer
            agricultural_task_ids:
              type: array
              items:
                type: integer
            blueprint_ids:
              type: array
              items:
                type: integer
```

`CropSetupProposalDryRunResponse` は `CropSetupProposalResponse` に置き換えて削除する。`normalized` が `CropSetupProposal` と一致するかは未確認（`normalize` 出力はポリシー実装 `crop_setup_proposal_policy` の戻り値で、本書では読んでいない）。実装時に `crop_setup_proposal_policy::validate_and_normalize` の出力形を確認し、違えば専用スキーマにする。

### 4.7 D-08: レスポンス・リクエストスキーマ

Before（`openapi.yaml:463-475`、`504-511`）

```yaml
    Crop:
      type: object
      properties:
        id:
          type: integer
        name:
          type: string
        variety:
          type: string
        region:
          type: string
        is_reference:
          type: boolean
```

After（型は `CropEntity`（`agrr-domain/src/crop/entities/crop_entity.rs:6-20`）に基づく）

```yaml
    Crop:
      type: object
      properties:
        id:
          type: integer
        name:
          type: string
        variety:
          type: string
          nullable: true
        area_per_unit:
          type: number
          nullable: true
        revenue_per_area:
          type: number
          nullable: true
        region:
          type: string
          nullable: true
        groups:
          type: array
          items:
            type: string
        user_id:
          type: integer
          nullable: true
        created_at:
          type: string
          nullable: true
        updated_at:
          type: string
          nullable: true
          description: Send this value back as `crop.updated_at` when updating (optimistic lock).
        is_reference:
          type: boolean
        crop_stages:
          type: array
          description: Populated on `GET /crops/{id}` only; `[]` on list, create, and update.
          items:
            $ref: '#/components/schemas/CropStage'
    CropStage:
      type: object
      properties:
        id:
          type: integer
        crop_id:
          type: integer
        name:
          type: string
        order:
          type: integer
        temperature_requirement:
          type: object
          description: Present only when set. Fields per `masters_json.rs:122-136`; numeric types to be confirmed.
        thermal_requirement:
          type: object
          description: Present only when set. `id`, `required_gdd`.
        sunshine_requirement:
          type: object
          description: Present only when set. `id`, `minimum_sunshine_hours`, `target_sunshine_hours`.
        nutrient_requirement:
          type: object
          description: Present only when set. `id`, `daily_uptake_n`, `daily_uptake_p`, `daily_uptake_k`, `region`.
```

追加するスキーマ: `AgriculturalTask`（`masters_agricultural_tasks.rs:52-68` の 13 キー）、`TaskScheduleBlueprint`（`masters_crop_task_schedule_blueprints.rs:63-85` の 19 キー）。各 operation の `200` / `201` に `content` を付ける。フィールドの型は `AgriculturalTaskEntity`（`agrr-domain/src/agricultural_task/entities/agricultural_task_entity.rs:8-22`）と `MastersCropTaskScheduleBlueprint`（`agrr-domain/src/crop/dtos/`）から確定する（後者の型定義は本書では未読）。

`CropCreateRequest`（`openapi.yaml:477-490`）には `area_per_unit`（number）、`revenue_per_area`（number）、`groups`（string 配列）、`is_reference`（boolean。非 admin は設定不可: `crop_update_interactor.rs:60-68` は update の場合。create の制約は未確認）を追加する（`masters_crops.rs:51-61`）。`AgriculturalTaskCreateRequest` / `UpdateRequest`（`openapi.yaml:528-540`）には `TaskAttrs`（`masters_agricultural_tasks.rs:164-174`）の `name, description, time_per_sqm, weather_dependency, skill_level, region, task_type, is_reference` を追加する。

### 4.8 D-09: セッション認証

Before（`openapi.yaml:23-25`）

```yaml
security:
  - bearerApiKey: []
  - headerApiKey: []
```

After

```yaml
security:
  - bearerApiKey: []
  - headerApiKey: []
  - sessionCookie: []
```

### 4.9 D-11: blueprint 作成はフラット body

Before（`openapi.yaml:542-546`）

```yaml
    TaskScheduleBlueprintCreateRequest:
      type: object
      properties:
        task_schedule_blueprint:
          type: object
```

After（`masters_crop_task_schedule_blueprints.rs:135-144` に対応）

```yaml
    TaskScheduleBlueprintCreateRequest:
      type: object
      required: [agricultural_task_id, stage_order, gdd_trigger]
      properties:
        agricultural_task_id:
          type: integer
        stage_order:
          type: integer
        stage_name:
          type: string
        gdd_trigger:
          type: number
        task_type:
          type: string
        description:
          type: string
        priority:
          type: integer
```

`required` は、欠落時に 422（`missing_agricultural_task_id` / `missing_gdd_trigger` / `invalid_stage_order`）となる項目（`masters_crop_task_schedule_blueprints.rs:392-403`）に合わせた。`stage_order` が「省略可でデフォルトあり」かはドメインの create interactor を読んでいないため未確認。実装時に `crop_masters_task_schedule_blueprint_create_interactor.rs` で確認して `required` を確定する。PATCH の body（`openapi.yaml:316-324` は `type: object`）は `BlueprintBody`（`masters_crop_task_schedule_blueprints.rs:269-282`）の 11 キーを持つ `TaskScheduleBlueprintUpdateRequest` に置き換える。

### 4.10 D-10: subset の範囲基準

Before（`openapi.yaml:5-7`）

```yaml
  description: |
    Public subset of the AGRR Masters JSON API for crop master data, agricultural tasks,
    task schedule blueprints, and external skill `setup_proposal` workflows.
```

After（案。確認事項 3 の回答で文言を確定）

```yaml
  description: |
    Public subset of the AGRR Masters JSON API for crop master data, agricultural tasks,
    task schedule blueprints, and external skill `setup_proposal` workflows.

    **Scope of this document.** Included: operations that an external (server-to-server)
    skill needs to read and maintain a crop's stages, its agricultural tasks and its task
    schedule blueprints, plus `setup_proposal`. Not included (still served under
    `/api/v1/masters/`): farms, fields, pests, fertilizes, pesticides, interaction rules,
    crop pests / pesticides, crop stage requirement sub-resources, `crop_stages/reorder`,
    and deprecated endpoints (`task_schedule_blueprints/regenerate`,
    `crops/{crop_id}/agricultural_tasks` which returns 410). These are used by the web UI and
    are not a stable external contract. Authentication, scopes and rate limits apply to
    every `/api/v1/masters/` route, documented here or not.
```

「web UI 用で安定した外部契約ではない」という位置付けは、現状のコードだけからは決められない方針判断（確認事項 3）。基準を (b)（全 Masters を網羅）にする場合は、上記の除外一覧を operation として追加することになる。

### 4.11 D-12: 404 と 422

案 A（本課題の推奨。実挙動を記載）。Before（`openapi.yaml:99-110`、`263`、`274`）の `'404'` を、実際に返す応答に差し替える。

```yaml
    delete:
      operationId: destroyCrop
      responses:
        '200':
          description: Deleted. Always returns the undo payload.
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/CropDestroyResponse'
        '401':
          $ref: '#/components/responses/Unauthorized'
        '403':
          $ref: '#/components/responses/Forbidden'
        '422':
          description: |
            Not found, or in use by a cultivation plan or other resources.
            The `error` message is a translated string.
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Error'
        '429':
          $ref: '#/components/responses/RateLimited'
```

- `updateCrop`: `'404'` を削除し、`'403'` / `'409'` / `'422'` を追加する。
- `showCrop`: `'404'` は未実測のため、実測（6.3 の T7）が終わるまで記載を変えない。実測で 422 であれば `'422'` に差し替える。
- `updateAgriculturalTask`: `'404'` を削除し、`'422'`（ポリシー拒否・not found・検証を含む）を記載する。
- `destroyAgriculturalTask`: `'404'` を削除し、`'403'` と `'422'` を記載する。

案 B（実装を 404 / 403 に修正する場合）: `openapi.yaml` の 404 は維持し、`403` のみ追加する。実装変更は本課題の対象外（10 と一体）。

### 4.12 D-13: crop update

Before（`openapi.yaml:492-502`）

```yaml
    CropUpdateRequest:
      type: object
      required: [crop]
      properties:
        crop:
          type: object
          properties:
            name:
              type: string
            variety:
              type: string
```

After

```yaml
    CropUpdateRequest:
      type: object
      required: [crop]
      properties:
        crop:
          type: object
          required: [updated_at]
          properties:
            updated_at:
              type: string
              description: |
                `updated_at` of the crop as last read. Missing or blank yields 422;
                a stale value yields 409 (`error: stale_record`).
            name:
              type: string
            variety:
              type: string
            area_per_unit:
              type: number
            revenue_per_area:
              type: number
            region:
              type: string
            groups:
              type: array
              items:
                type: string
            is_reference:
              type: boolean
              description: Only an admin may change it; otherwise 422.
```

`updateCrop` の `responses` に次を追加する。

```yaml
        '200':
          description: Updated crop
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Crop'
        '403':
          $ref: '#/components/responses/Forbidden'
        '409':
          description: 'Stale update (`error: stale_record`)'
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Error'
        '422':
          $ref: '#/components/responses/Unprocessable'
```

### 4.13 D-15: 削除の undo 応答

After（追加スキーマ。`CropDestroyResponse` は 4.11 で参照）

```yaml
    UndoPayload:
      type: object
      properties:
        undo_token:
          type: string
        undo_path:
          type: string
        toast_message:
          type: string
        undo_deadline:
          type: string
        auto_hide_after:
          type: integer
    CropDestroyResponse:
      type: object
      properties:
        undo:
          $ref: '#/components/schemas/UndoPayload'
    AgriculturalTaskDestroyResponse:
      allOf:
        - $ref: '#/components/schemas/UndoPayload'
        - type: object
          properties:
            resource:
              nullable: true
            redirect_path:
              type: string
            resource_dom_id:
              nullable: true
            metadata:
              type: object
```

`metadata` などの厳密な型は `soft_delete.rs:44-56` の JSON 出力から読めないため、実装時に確認する。`undo_token` などのキー名は `masters_json.rs:177-185` と `soft_delete.rs:44-56` で確認済み。

---

## 5. 再発防止（openapi と実装の整合を機械検証する方法）

今回の乖離は、`openapi.yaml` と実装を結ぶ機械的な検証が無いことが原因である。`docs/api/` を対象にするチェックは、リポジトリ内に存在しない（`openapi` を含むファイルは `docs/api/*`、`llms.txt`、`tools/agrr-mcp/README.md` 等で、CI 設定・`scripts/` には無い。`.github/workflows/doc-freshness.yml` は `docs/`・`.cursor/rules` の内部リンクと陳腐化パターンのみを検査し、`docs/api/openapi.yaml` の内容は検査しない）。

### 5.1 選択肢の比較

| 案 | 内容 | 検出できる乖離 | 追加物 | 費用・リスク |
| -- | ---- | -------------- | ------ | ------------ |
| P1 | 現状維持（手動レビュー） | なし | なし | 今回の乖離が実証済み |
| P2 | OpenAPI lint（Spectral / Redocly 等）を CI に追加 | 文書の構文・`$ref` 破損・スタイル。実装との乖離は検出しない（204 と 200 の食い違いは通る） | Node 依存と CI ジョブ | 費用に対して今回の課題を防げない |
| P3 | R4 契約テストが `openapi.yaml` を読み、記載した path × method が実在することを検証（未認証で叩き 401 を期待し、404/405 なら失敗） | 記載 operation の削除・改名・メソッド差異 | `agrr-r4-contract` の dev-dependency に YAML パーサ（`agrr-migrate` が `serde_yaml` 0.9 を使用: `crates/agrr-migrate/Cargo.toml:23`。`0.9.34+deprecated`: `Cargo.lock`）、テスト 1 本（数十行） | ステータス・body は検出しない。ハンドラは認証 extractor が先に走るため未認証で 401 になるはずだが未実測 |
| P4 | R4 契約テストが `openapi.yaml` の全 response を実観測と突合（operation ごとにシードとリクエストを用意） | ステータス・スキーマの乖離まで | 大量の operation 別フィクスチャ | 既存の R4 テストと重複し、保守費が大きい |
| P5 | 実装から OpenAPI を生成（`utoipa` 等） | 乖離そのものが起きにくい | 全ハンドラへのマクロ付与、依存追加 | 薄いエッジ（R7）にスキーマ宣言が入り、全 Masters ルートに影響。`agrr-server` の大規模変更 |
| P6 | 記載したステータス・ボディを、既存の R4 契約テストで 1 つずつ固定する。`openapi.yaml` を変更するときは対応するテストを同じ変更で更新する（運用規約） | 固定されたものについての実装側の変更（テストが落ちる） | `contracts.rs` へのテスト追加のみ | 文書側の変更は検出しない（テストが正で、文書はそれに従うという一方向） |

### 5.2 推奨

`.cursor/rules/project-necessary-code-only.mdc` は「依頼・再現済みの不具合・既存契約・テストで求められる振る舞いに直結する差分」に限定している。これに照らし、次の順で推奨する。

1. **P6（必須・本課題の一部）**: 4 章の各記載について、根拠となる R4 テストが無いものだけを 6 章で追加する。追加物は `crates/agrr-r4-contract/tests/contracts.rs` へのテストのみで、新規ツール・依存を持たない。`CLAUDE.md` の Norm priority（観測可能なテストが最上位）とも一致する。
2. **P3（任意・ユーザー確認後）**: 「記載した operation が消える」型の乖離を機械的に防ぎたい場合のみ。dev-dependency を 1 つ足す必要があり、今回の乖離（ステータス・body・スキーマ）は防げない。今回の課題の再発防止としては優先度が低く、必要性を示す再現済みの事象（記載 operation が実装から消えた事例）を確認した範囲では見つかっていないため、要望があるまで追加しない。
3. **P2 / P4 / P5 は推奨しない**（P2: 今回の乖離を防げない。P4: 保守費が過大。P5: 影響範囲が過大で、R7 の薄いエッジにも反する）。

追加の運用規約が必要な場合は、`docs/api/openapi.yaml` 冒頭ではなく既存の場所（PR の観点）に留める。新規ドキュメントは作らない。

---

## 6. TDD / 検証計画

### 6.1 位置付け

`openapi.yaml` の修正はドキュメントのみの変更で、`.cursor/rules/tdd-on-edit.mdc` の例外（ドキュメント/設定のみ）に当たる。ただし本計画は、記載する内容が事実であることを**テストで固定してから**文書へ反映する（`evidence-before-design-and-implementation.mdc` の根拠ゲート）。

- 追加する R4 テストの多くは、**既存実装の挙動を固定する特性化テスト**であり、追加時点で GREEN になる（RED は無い）。これは意図どおりで、RED を作るために実装を壊すことはしない。
- 実装の挙動を変える判断（D-12 で案 B を選ぶ場合）だけは通常の RED → GREEN とする。RED は「期待するステータスを表明して失敗する」ことで確認する。
- テストの実行は `test-common` のみ。`scripts/run-rust-contract-tests.sh`（`docker compose --profile test run` を使う。Docker が必要）。出力は `./tmp/{UUID}.log` に保存してから grep する（`AGENTS.md`）。個別確認後に全体を実行し、最後に `.cursor/skills/test-slow-detection/SKILL.md` に従う。

### 6.2 既存の R4 契約テストの確認結果

`crates/agrr-r4-contract/tests/contracts.rs`（関数の開始行）。

| 固定済みの内容 | テスト（行） |
| -------------- | ------------ |
| stage 削除 204 と blueprint の紐付け解除 | `delete_masters_crop_stage_unassigns_linked_blueprints`（2494。204 の表明は 2514） |
| stage の他 crop 指定 404（GET / PATCH / DELETE / requirement） | `get_masters_crop_stage_wrong_crop_returns_404`（2535）、`patch_masters_crop_stage_wrong_crop_returns_404_and_does_not_mutate_stage`（2557）、`delete_masters_crop_stage_wrong_crop_returns_404`（2592）、`get_masters_crop_stage_temperature_requirement_wrong_crop_returns_404`（2614） |
| stage の order 競合 422 | `post_masters_crop_stage_conflicting_order_returns_422`（2402）、`patch_masters_crop_stage_conflicting_order_returns_422`（2422） |
| 参照 crop への stage 操作（非 admin は 404、admin は成功） | `post_reference_crop_stage_by_non_admin_returns_404`（2290）、`patch_reference_crop_stage_by_non_admin_returns_404`（2307）、`post_reference_crop_stage_by_admin_succeeds`（2345） |
| stage 並べ替え | `put_masters_crop_stages_reorder_swaps_stage_orders`（2364）、`put_masters_crop_stages_reorder_remaps_blueprint_stage_orders`（2446） |
| blueprint 一覧・作成（フラット body、422 と `error_code`、201 と `source: manual`）・regenerate 422 | 2067、2078、2098、2127、2158 |
| 廃止 API の 410 | 2197、2215、2234、2253、2272 |
| setup_proposal（dry_run 検証失敗 200、dry_run 成功 200、apply 201 と結果の永続化、API キー認証） | 2669、2693、2715、2759 |
| API キースコープ（read で GET 可・POST 403 と `error_code`、write で POST 201、read で apply 403、生成キーの既定スコープ） | 3014、3049、3070、`post_api_keys_generate_defaults_to_read_only_scopes` |
| クエリ `api_key` は 401 | 3141 |
| apply の 429 と `Retry-After`、body `rate_limit` | 3153 |
| 他ユーザーの farm / crop の show は 403 または 404 | 3514、3531（`assert_cross_user_access_denied` は 403/404 のどちらでも通る: `support.rs:20-25`） |

**未固定（今回の記載に対して根拠となるテストが無いもの）:** blueprint の PATCH・DELETE 204、masters crop の PATCH/PUT/DELETE（成功・403・409・422）、stage の 400、agricultural_task の CRUD 全般、setup_proposal の apply 時検証失敗 200・apply 201 の `mode`/`normalized`/`agricultural_task_ids`・invalid mode 422、crop 存在しない場合の show のステータス。

### 6.3 追加する契約テスト

追加先はすべて `crates/agrr-r4-contract/tests/contracts.rs`（既存の命名 `verb_masters_<resource>_<condition>_returns_<status>` に合わせる）。シード関数は `crates/agrr-r4-contract/tests/support.rs` の既存のもの（`seed_masters_crop` 250、`seed_masters_crop_with_stages` 268、`seed_masters_crop_with_stages_and_blueprints` 295、`seed_masters_crop_with_manual_blueprint` 338、`seed_reference_crop_with_stage` 212-）を再利用し、新規ヘルパは原則作らない。非 admin セッションは `farmer_session_id` / `researcher_session_id`（`support.rs:96-106`）。

| ID | 対応 | テスト名（案） | given | when | then |
| -- | ---- | -------------- | ----- | ---- | ---- |
| T1 | D-02 | `delete_masters_crop_task_schedule_blueprint_returns_204_and_removes_it` | ログイン済みユーザーの crop と 2 件の blueprint（`seed_masters_crop_with_stages_and_blueprints`） | `DELETE .../task_schedule_blueprints/{id}` | 204、body が空。続く一覧に当該 id が無い |
| T2 | D-01 | 既存 `delete_masters_crop_stage_unassigns_linked_blueprints`（2494）に追記 | 同上 | `DELETE .../crop_stages/{id}` | 204 に加えて body が空であること（`assert!(body.is_empty())`） |
| T3 | D-13 | `patch_masters_crop_without_updated_at_returns_422` | ユーザーの crop（`seed_masters_crop`） | `PATCH /crops/{id}` に `{"crop":{"name":"x"}}` | 422 |
| T4 | D-13 | `patch_masters_crop_with_stale_updated_at_returns_409` | 同上。`GET` で取得した `updated_at` を使って 1 回更新済み | 古い `updated_at` で再度 `PATCH` | 409、`error` が `stale_record` |
| T5 | D-13 / D-05 | `put_masters_crop_is_alias_of_patch` | 同上 | 最新の `updated_at` で `PUT /crops/{id}` | 200 と更新後の name |
| T6 | D-03 / D-12 | `patch_masters_reference_crop_by_non_admin_returns_403` | 参照 crop（`seed_reference_crop_with_stage`）、非 admin セッション（`farmer_session_id`） | `PATCH /crops/{id}` | 403、`error` が `crops.flash.no_permission`。ポリシー判定は `updated_at` の検査より先（`crop_update_interactor.rs:55-80`）のため `updated_at` は不要 |
| T7 | D-12 | `get_masters_crop_unknown_id_returns_expected_status` | ログイン済みユーザー | 存在しない id で `GET /crops/{id}` | **導出では 422**（`masters_crops.rs:352` と `shared/exceptions/mod.rs:6-7`）。実測して確定し、その値を表明する。D-12 で案 B（404 に修正）を選ぶ場合は 404 を表明して RED にする |
| T8 | D-12 | `delete_masters_crop_unknown_id_returns_422` | 同上 | 存在しない id で `DELETE /crops/{id}` | 422（`crop_destroy_interactor.rs:56-67`）。案 B を選ぶ場合は 404 で RED |
| T9 | D-06 | `post_masters_crop_stage_without_name_returns_400_invalid_parameters` | ユーザーの crop | `POST .../crop_stages` に `{"crop_stage":{"order":1}}` | 400、`error` が `Invalid parameters` |
| T10 | D-06 | `patch_masters_crop_stage_with_empty_payload_returns_400` | 1 stage を持つ crop | `PATCH .../crop_stages/{id}` に `{"crop_stage":{}}` | 400、`error` が `Invalid parameters` |
| T11 | D-07 | `post_masters_crop_setup_proposal_apply_invalid_returns_200_with_apply_mode` | ユーザーの crop、`thermal_requirement` を空にした提案 | `POST ...setup_proposal?mode=apply` | 200、`mode` が `apply`、`valid` が `false`、`errors[0]` に `path` と `message`。永続化されない（stage 一覧が空のまま） |
| T12 | D-07 | 既存 `post_masters_crop_setup_proposal_apply_persists_stages_and_blueprints`（2715）に追記 | 同上 | 有効な提案で `mode=apply` | 201 に加えて `mode` が `apply`、`normalized` が存在、`result.agricultural_task_ids` が長さ 1 の配列 |
| T13 | D-07 | `post_masters_crop_setup_proposal_invalid_mode_returns_422` | ユーザーの crop | `?mode=bogus` | 422、`error` が `mode must be dry_run or apply` |
| T14 | D-11 | `post_masters_crop_task_schedule_blueprints_wrapped_body_returns_422` | ユーザーの crop と task | `{"task_schedule_blueprint":{…}}` のラッパー body で `POST` | 422、`error_code` が `missing_agricultural_task_id`（openapi をフラットに直す根拠。ラッパーが無視されることの導出を実測で確定する） |
| T15 | D-15 | `delete_masters_crop_returns_nested_undo_payload` | ユーザーの crop（使用中でない） | `DELETE /crops/{id}` | 200、`undo.undo_token` が空でない。`undo.undo_path` が `/undo_deletion` |

agricultural_task の CRUD は R4 の固定が全く無い。D-12・D-15 で記載を変える 2 点だけを次のテストで固定する（その他のプロパティは `task_json`（`masters_agricultural_tasks.rs:52-68`）の読解のみを根拠とし、PR に明記する）。

| ID | 対応 | テスト名（案） | given | when | then |
| -- | ---- | -------------- | ----- | ---- | ---- |
| T16 | D-12 | `patch_masters_agricultural_task_unknown_id_returns_422` | ログイン済みユーザー | 存在しない id で `PATCH /agricultural_tasks/{id}` に `{"agricultural_task":{"name":"x"}}` | 422、`errors` が配列。案 B を選ぶ場合は 404 で RED |
| T17 | D-15 | `delete_masters_agricultural_task_returns_flat_undo_payload` | `POST /agricultural_tasks` で作成した自分の task | `DELETE /agricultural_tasks/{id}` | 200、`undo_token` が最上位にあり `undo` キーは無い |

スコープ 403・429 は既存テスト（3014、3070、3153）で足りるため追加しない（`project-necessary-code-only.mdc`）。

### 6.4 実行手順

1. `crates/agrr-r4-contract/tests/contracts.rs` にテストを追加する。**この時点で `crates/agrr-server` は変更しない**ため、`rebuild-restart.sh` は不要（R4 のテストバイナリは `run-rust-contract-tests.sh` が再ビルドする: `scripts/run-rust-contract-tests.sh` の `ensure_agrr_r4_contract_tests_binary`）。
2. `scripts/run-rust-contract-tests.sh > ./tmp/<UUID>.log 2>&1` を実行し、終了コードを待ってから結果を grep する（`process-monitor`、`dont-finish-task-while-process-is-running.mdc`）。
3. 特性化テストはすべて GREEN であること、T7・T14 は実測値が導出と一致することを確認する。導出と異なった場合は、`openapi.yaml` の After と本書の 2 章の該当行を実測に合わせて直す。
4. 全体（ファイル指定なし）を実行し、`test-slow-detection` で 0.5 秒超のテストを確認する（R4 は `scripts/check-slow-libtest-output-cli.mjs` が自動で検査する）。
5. D-12 で案 B を選んだ場合のみ: RED（T7・T8 が 404 を期待して失敗）を確認してから `crates/agrr-server/src/masters_crops.rs` などを修正し、`.cursor/skills/dev-docker/scripts/rebuild-restart.sh` で API を再ビルドしてから Docker で検証し、GREEN を確認する。

---

## 7. 実装ステップ

1. **確認事項の回収**（3.3）。回答が無い場合は推奨案で進める。D-12 が案 B になった場合は本課題から切り離して 10 に渡す。
2. **根拠の実測**: 6.3 の T7・T14 の導出値（crop show の 422、ラッパー body が 422）を、R4 で実測して確定する。未確定の値は `openapi.yaml` に書かない。
3. **契約テスト追加**（6.3）。個別 → 全体 → 遅延検知（6.4）。
4. **`openapi.yaml` の修正**（4 章の順）。
   1. `components`: `Error`（D-03・D-14）、`responses`（`Forbidden`、`BadRequest`）、スキーマ（D-07・D-08・D-11・D-15）
   2. 全 operation の `responses`: `403`・`429`（D-03・D-04）
   3. D-01・D-02: 削除 204
   4. D-06: stage の 400 とリクエストスキーマ
   5. D-13・D-12: crop update の body と各 operation の 403/409/422/404
   6. D-07: setup_proposal のレスポンス
   7. D-05: `PUT` エイリアスの description
   8. D-09: グローバル `security`
   9. D-10: `info.description`
5. **検証**: YAML として構文が正しいこと、`$ref` がすべて解決できることを、ローカルで 1 回確認する。使い捨ての確認に留め、リポジトリにツールや設定は追加しない（5.2）。`docs/api/openapi.yaml` の記載を、2.2 の確定表と 1 行ずつ突き合わせる。
6. **参照元の同期は 03・04・09 に委譲**（2.4）。本課題では `getting-started.md`・snippet は変更しない。ただし、`openapi.yaml` の変更と矛盾する記述が残るため、その事実を 03・04・09 の担当に引き継ぐ。
7. **PR 記載**: 各記載がどの R4 テストに支えられているかを対応表で示す。導出だけで実測していない項目があれば、その旨を明記する。

`crates/*`（実装）を変更するのは D-12 で案 B を選んだ場合に限られる。その場合は `.cursor/rules/docker-dev-agrr-server-rebuild.mdc` に従う。

---

## 8. リスク・未確定事項

| # | 内容 | 影響 | 対処 |
| - | ---- | ---- | ---- |
| R1 | crop show の存在しない id が 422 になるのは、コード読みからの導出で未実測（`masters_crops.rs:352`、`shared/exceptions/mod.rs:6-7`、`crop_detail_interactor.rs:53-58`） | D-12 の crop show 行と 2.2 の確定表が誤りの可能性 | T7 で実測して確定（6.3） |
| R2 | blueprint 作成でラッパー body が 422 になるのは serde の既定動作に基づく導出で未実測 | D-11 の説明 | T14 で実測 |
| R3 | axum の `Json` / `Query` 拒否時のステータスと body（D-16）は未確認 | 400/415/422 の記載が漏れる | 実測後に別途判断。今回は記載しない |
| R4 | `openapi.yaml` を実装に合わせても、実装側の不整合（not found が 422、agricultural_task update のポリシー拒否が 422、crop は 403 で stage は 404）は残る。文書が「現状の不整合」を正式契約として固定するリスクがある | 後で挙動を直すと契約変更になり、外部利用者に影響する可能性（利用者の有無は未確認） | D-12 の方針（3.2）。10 と調整し、変更する場合は `openapi.yaml` を同じ変更で更新する。当面は description に「現状」と分かる書き方は避け、実挙動をそのまま書く |
| R5 | `PUT` エイリアスの外部利用者の有無が未確認 | 将来削除する場合の影響が読めない | エイリアスとして記載するのみで挙動は変えない |
| R6 | `normalized` の形が `CropSetupProposal` と一致するか未確認（4.6） | `CropSetupProposalResponse` の `normalized` の型 | 実装時に `crop_setup_proposal_policy` の出力を確認 |
| R7 | blueprint DTO・stage 要件の数値型など、スキーマの細部は未読（4.7・4.9） | 型の誤記 | 実装時に該当エンティティ・DTO の定義を読んで確定 |
| R8 | `crops/{id}` の show は `gateway.list_by_crop_id(id).unwrap_or_default()`（`masters_crops.rs:111`）で stage 取得失敗を握りつぶして空配列で 200 を返す | fail-closed 方針（`ARCHITECTURE.md`）との関係。本課題の対象外 | 05 / 06 のどちらに該当するかは各文書で判断（本書では未判定） |
| R9 | 記載外エンドポイントも同じスコープ・レート制限を受ける（2.3）が、利用者は `openapi.yaml` からそれを知れない | 文書化の不足 | 4.10 の基準文言で補う |
| R10 | 本書の表は 2026-09-29 時点の `master` に対するもの。実装が変わると乖離が再発する | 表の陳腐化 | 5 章の P6 で固定したテストが落ちれば気付ける。表そのものは PR 時点の再確認を要する |

---

## 9. 受け入れ条件

1. 4 章の変更が `docs/api/openapi.yaml` に適用され、YAML と `$ref` が有効である。
2. `openapi.yaml` の全 operation（20 本）に `401` / `403` / `429` が記載され、`Error` に `error_code` があり、`errors` が文字列配列になっている。
3. stage 削除・blueprint 削除が `204` になっている。
4. crop update に `updated_at`（必須）・`409`・`422`・`403` が記載され、`PUT` エイリアスが 3 箇所で明記されている。
5. crop_stage の create / update に `400` と `name`・`order` を含むリクエストスキーマがある。
6. setup_proposal の `200` / `201` が `mode` / `valid` / `normalized` / `errors` / `result` を持つスキーマで記載され、apply の検証失敗が 200 であることと mode 不正の 422 が明記されている。
7. blueprint 作成のリクエストがフラット body になっている。
8. `Crop` が実 JSON の 12 キーを持ち、`CropStage`・`AgriculturalTask`・`TaskScheduleBlueprint` のレスポンススキーマが定義され、各 operation から参照されている。
9. グローバル `security` に `sessionCookie` があり、`info.description` に subset の範囲基準と除外一覧が記載されている。
10. 2.2 の確定表の各行が、R4 契約テストで固定されているか、導出のみである場合はその旨が PR に明記されている（未実測の記載が `openapi.yaml` に残っていない）。
11. `scripts/run-rust-contract-tests.sh` が成功し、全体実行と遅延検知（0.5 秒超）を通過している。
12. D-12 で案 B が選ばれた場合のみ、`crates/*` の変更に対する `rebuild-restart.sh` と R4 の GREEN が確認されている。
13. 03・04・09 に対して、`getting-started.md`・snippet との不整合（2.4）が引き継がれている。

---

## 10. 関連課題との依存

`docs/spec-defects/` の他番号文書は本書作成時点で存在しない。以下は本書が読んだ事実に基づく想定の依存関係で、各文書が作成された時点で見直す。

| 番号 | 課題 | 本書との関係 | 順序・調整 |
| ---- | ---- | ------------ | ---------- |
| 01 | resource-limit-bypass | `POST /crops` の 422（作成上限超過を含む: `masters_crops.rs:338-343`）は本書の `createCrop` の 422 に含まれる。上限の実装・挙動変更は 01 が決める | 01 で挙動が変わる場合は `createCrop` の 422 の説明を追随 |
| 02 | contact-recaptcha | Masters API と無関係 | 依存なし |
| 03 | api-key-scope-docs | `getting-started.md:32-41` の誤記（スコープ未保存）を直す。`openapi.yaml:10-13` は実装どおり。403 の `error_code`（`insufficient_scope`）の記載は本書 D-03 が担当 | 403 とスコープの説明文言は 03 と本書で同じ表現にそろえる。03 が先でも後でもよい |
| 04 | api-key-query-auth | クエリ認証は実装が無視して 401（`masters_auth.rs:44`、R4 3141）。`openapi.yaml` の `securitySchemes` にクエリ方式は無く本書は影響を受けない。`getting-started.md:30` の修正は 04 | 04 がクエリ認証を復活させる場合は `securitySchemes` を追加 |
| 05 | fail-closed-critical | 本書は挙動を変えない。R8 の `unwrap_or_default` の該当有無は 05/06 が判断 | 依存なし（R8 の引き継ぎのみ） |
| 06 | fail-closed-suspected | 同上 | 同上 |
| 07 | frontend-error-contract | エラー body の形（`error` / `errors` / `error_code`）の確定表（2.2）と `Error` スキーマ（4.2）は、フロントのエラー契約の元情報になる | 07 は本書の確定表を参照する。本書が先に確定する方が手戻りが少ない |
| 09 | stale-design-docs | `setup_proposal-openapi-snippet.yaml` のレガシー扱いと、参照元（`tools/agrr-mcp/README.md:56`、`.cursor/skills/agrr-crop-setup/SKILL.md:33`）の付け替え、`llms.txt:10` の説明 | 本書の `openapi.yaml` 修正後に、snippet を廃止または `openapi.yaml` への参照に置き換える。順序は本書 → 09 |
| 10 | authorization-consistency | D-12・D-03 の 403 / 404 / 422（crop は 403、stage・blueprint・setup_proposal は 404、agricultural_task update は 422）の統一方針を決める | 挙動の変更は 10 が主導し、本書は現状を記載する。10 で変更したら `openapi.yaml` を同じ変更で更新 |
| 11 | low-priority-misc | D-05・D-09・D-10 のような重大度 Low の項目を、11 と分担せず本書で完結させる | 依存なし。11 に同種の項目があれば重複を避ける |
