# 08 — `docs/api/openapi.yaml` と実装の乖離（対応計画）

**種別:** 対応計画（本書はドキュメントのみ。コード・`openapi.yaml` は本書では変更しない）
**対象:** [`docs/api/openapi.yaml`](../api/openapi.yaml)（AGRR Masters API）と `crates/agrr-server/src/masters_*.rs` の実装
**パス表記:** `crop_*_interactor.rs` は `crates/agrr-domain/src/crop/interactors/`、`shared/exceptions/mod.rs` は `crates/agrr-domain/src/`、`pool/mod.rs`・`soft_delete.rs`・`crop/crop_gateway.rs` は `crates/agrr-adapters-sqlite/src/`、`masters_*.rs` は `crates/agrr-server/src/`、`contracts.rs`・`support.rs` は `crates/agrr-r4-contract/tests/`、`masters_api_scope.rs` は `crates/agrr-domain/src/shared/dtos/`、`crop-*-api.gateway.ts` は `frontend/src/app/adapters/crops/` を指す（特記なきものは同ディレクトリ規則）。`crop_masters_task_schedule_blueprint_*_interactor.rs`・`crop_setup_proposal_interactor.rs` は `crop_*_interactor.rs` と同じ `crates/agrr-domain/src/crop/interactors/` にある。
**根拠の扱い:** 本書の事実は 2026-09-29 時点のリポジトリ（`master`）を読んで確認したものだけを `file:line` 付きで記す。2026-10-07 の改訂（第 3 回決定の反映）で追加した主張も、その時点のワーキングツリーのコードを読んで確認したものだけを記す。コードを読んだだけで実行していないものは「未実測」、読めていないものは「未確認」と明記する。本書作成時にテストは実行していない。他番号の文書（01〜11）は現在すべて存在し、第 10 章の依存関係は 02・03・07・10 の最新版（2026-10-07 時点のワーキングツリー）の該当節を読んで整合させた（読んだ範囲は第 10 章に明記する。全文の精読ではない）。

**改訂（第 2 回・第 3 回決定の反映）:** README の決定事項により、`Error` スキーマの確定先が `errors`（文字列配列）になった（第 2 回「errors」）。旧キー `error` は削除が確定した（第 3 回「削除」。実施条件は 07 §3.5.3 の P1〜P6）。API キーは read のみで write はセッションのみ（03 の第 1 回「与えない」と第 3 回「移行する」）、Farm / Crop の編集は所有者のみへ縮小（10 の第 3 回「縮小」）。これらに合わせ、(1) `Error` の差分案を 07 の契約に揃え、旧キーを「deprecated → 削除」の 2 段階で扱う（4.2、4.14）、(2) 03・07・10 との責務境界と `openapi.yaml` の編集フェーズを第 0 章に追加した、(3) 旧キー削除後の最終状態を 4.16 に追加した、(4) 第 10 章の依存欄を更新した。**実装・`openapi.yaml` の変更は本書では行わない。**

---

## 0. 決定事項の反映と責務境界

### 0.1 本書に影響する決定

| 決定（README） | 出典 | 08 への影響 |
| -------------- | ---- | ----------- |
| 第 2 回「errors」: 失敗本文は `errors: string[]`（1 件以上）が必須。任意で `error_code` と `field_errors` | 07 §0.2、§3.3（C1〜C6） | D-03・D-14 の `Error` を `errors` 必須・`error_code`（自由文字列）・`field_errors` に改める。旧版の After（`error` 先頭、`errors` 任意）は採らない（4.2、4.14） |
| 第 3 回「削除」: 旧キー `error` / `message` を削除する。S1 で併記（deprecated）、S2 で撤去 | 07 §0.3、§3.5.1、§3.5.3、§3.5.4（O1） | `openapi.yaml` の旧キーは「S1 で `deprecated: true` → S2 で記載削除」の 2 段階。最終形は 4.16 |
| 第 1 回「与えない」(a)・第 3 回「移行する」: API キーは `masters:read` のみ。write はセッションのみ | 03 §0、§5.2 | write operation の `security` 上書きは 03 の領分（4.15）。V27 を本番に適用して DB で確認した後に公開する |
| 第 3 回「縮小」: Farm / Crop の編集は所有者（と admin）のみ。閲覧の範囲は P14 で未確定（推奨は組織単位のまま） | 10 §0、§2.10、§3.1（P14） | `openapi.yaml` に organization・owner・admin の語は無い（`rg -n -i "organi\|admin\|owner" docs/api/openapi.yaml` が 0 件）。縮小で変わる応答は、非所有の組織メンバーによる crop の更新・削除（現状は成功 → 403）と、stage・blueprint・setup_proposal の書き込み（現状は成功 → 404）で、いずれも既存の `403` / `404` の枠内に収まる（根拠は 2.1 の D-03 の (b) 行と 4.11）。記載は変えず、description に「所有者」「組織」を書かない |
| 第 3 回「共有」: Farm / Crop の枠は組織で共有 | 01 §0 | `createCrop` の 422（上限超過を含む。`masters_crops.rs:338-343`）は不変 |

### 0.2 責務境界（二重定義の禁止）

原則: `openapi.yaml` の同じ箇所を、2 つの文書が書き換え案として持たない。各箇所は下表の「正」の文書だけが内容を決め、他方は参照にとどめる。

| 論点 | 正（内容を決める文書） | 08 の扱い |
| ---- | ---------------------- | --------- |
| 失敗本文の契約（`errors` 必須、`error_code`、`field_errors`、旧キーの併記と撤去の実施条件・順序） | **07** §3.3・§3.5 | `Error` スキーマと description への転記だけを行い、契約を変える提案はしない。段階ごとの形は 4.14 |
| 失敗本文の例・description に書くメッセージ文字列 | 実装（本書の `file:line`）。キー名（`error` / `errors`）の扱いは 07 | 「message `…`」の形で書き、キー名を直書きしない（4.5〜4.12） |
| API キーは read のみという方針、冒頭 description の「API keys are read-only」の文言、`securitySchemes` の description | **03** §5.2.1・§5.2.2 | 変更案を持たない。08 が持つのは D-09（グローバル `security` への `sessionCookie` 追加）だけ |
| write operation への `security: [{sessionCookie: []}]` の上書き（03 の Q7）。対象 operation、setup_proposal の例外、公開時期 | **03** §5.2.3（案 B が推奨。Q7 の回答が正） | 4.15 に適用後の形を再掲するが、対象と文言は 03 から変えない。Q7 が案 A（注記のみ）なら 4.15 を適用しない。他の差分案は Q7 に影響されない |
| 全 operation への `403` / `429` の付与、`Forbidden` / `BadRequest` / `RateLimited` の応答定義 | **08**（D-03・D-04・D-06） | 03 は「08 を先に入れる」としている（03 §5.2.3、§10）。03 の `insufficient_scope` の説明は `Forbidden` を参照する |
| 403 / 404 / 422 の状態コード統一（D-12 の案 B）、誰が編集できるかの認可判定 | **10**（U16 は未対応。P3 の admin の扱いは未決） | 現状の実挙動だけを記載する（案 A）。10 が状態コードを変えたら同じ変更で更新する（4.11） |
| `info.description` | 03（スコープと read のみの段落）と 08（範囲基準 4.10、429 の補足 4.3）。**段落単位で分ける** | 08 は「Scope of this document」と 429 の補足の段落だけを書く。冒頭のスコープ箇条書きは 03 が書く |
| `openapi.yaml` 未掲載のエンドポイント（contact、climate_data、entry_schedule、public_plans ほか） | D-10 の決定（3.3 の確認事項 3）。subset 維持（推奨 (a)）なら追加しない | 02・05・06・11 が 08 へ渡すとした契約は、(a) では本ファイルに載せない（第 10 章） |

### 0.3 `openapi.yaml` の編集フェーズ

`openapi.yaml` の公開面は GitHub の master で、サーバーのデプロイとは独立に公開される（03 §5.4.1.9。`llms.txt:10` が GitHub の blob を指す）。失敗本文の形や API キーの書き込み可否は実装の状態に依存するため、実装より先に断定的に書くと不正確になる。差分案（第 4 章）を次のフェーズに分け、適用の順序と公開の条件を固定する。日時ではなく条件で定義する。

| フェーズ | 内容 | 公開の条件 | 依存する実装の状態 |
| -------- | ---- | ---------- | ------------------ |
| A | 失敗本文の形に依存しない修正。D-01・D-02（204）、D-03 の `403` 応答、D-04 の `429`、D-05、D-06、D-07、D-08、D-09、D-10、D-11、D-12、D-13、D-15。`Error` は暫定形 E1（4.14）にする | 他フェーズを待たずに公開できる | 現状の実装と一致する |
| C | write operation の `security` 上書き。03 の description・`securitySchemes` の文言（03 §5.2） | 03 の V27 を本番に適用し、DB で適用を確認した後（03 §5.4.1.9） | 03 の V27 |
| B | `Error` を E2 形（`errors` 必須、`error` は `deprecated: true`）にする（4.14） | 07 の S1 が本番に反映済みで、`errors` を読む MCP 更新版の公開と同時（07 §3.5.1 の S1 の行） | 07 の S1 |
| D | `Error` から `error` を削除して E3（最終形）にし、deprecated の記述を消す（4.14、4.16） | 07 の P1〜P6 がすべて満たされ記録された後。S2 と同時（07 §3.5.3、§3.5.4 の O1・O2） | 07 の S2 |

順序は A → C → B → D。A を C より先にする理由は 03 §5.2.3・§10（08 が先）。C を B より先にする理由は 07 §10（`getting-started.md` を 03 の公開が先、07 の S1 の文書更新はその後）。適用時点で S1 がすでに本番にあるなら A と B を一度に、S2 が済んでいるなら A と D を一度に適用し、E1・E2 を経由しない。E1 は S1 より前の実装を表す暫定形で、S1 の本番反映後に E1 のまま残さない（B へ進む）。E2 も S2 の反映後に残さない（D へ進む）。

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
| D-03 | 403 が全く記載されていない・`Error` に `error_code` が無い（`error_code` は自由文字列で 07 の C6 と一致。write operation の `security` 上書きは 03 が正: 0.2） | Medium |
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
| D-14 | `Error.errors` の要素型が `object` だが実際は文字列配列（07 の契約で `errors` は必須の文字列配列に確定。旧キー `error` は deprecated を経て削除） | Medium |
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
| D-03 | 403 | 全 operation に無い。`Error` は `error` / `errors` のみ（`openapi.yaml:453-461`） | (a) API キーのスコープ不足: `403 {"error":"forbidden","error_code":"insufficient_scope"}`。(b) ポリシー拒否: crop show/update/destroy は `403 {"error":"crops.flash.no_permission"}`、agricultural_task の list/show/destroy は `403`。stage・blueprint・setup_proposal は 403 にならない（404） | (a) `masters_auth.rs:95-100`、判定 `masters_auth.rs:109-128`、要求スコープ分類 `masters_api_scope.rs:16-34`、R4 `contracts.rs:3014`（403 と `error_code` を表明）・`3070`（apply も 403）。(b) `masters_crops.rs:300-303, 347-350, 364-367`、`masters_agricultural_tasks.rs:94-97, 134, 289`、`masters_crop_stages.rs:75, 122`（404）、`masters_crop_setup_proposal.rs:115-120`（404）、`crop_setup_proposal_interactor.rs:68-71`（編集不可は not found 扱い）。blueprint も編集不可は `CropNotFound`（404 `Crop not found`）: 一覧 `crop_masters_task_schedule_blueprint_index_interactor.rs:62`、作成 `..._create_interactor.rs:102`、更新 `..._update_interactor.rs:63`、削除 `..._destroy_interactor.rs:59`、写像 `masters_crop_task_schedule_blueprints.rs:387-427, 452-473`。stage の編集不可も 404（`masters_crop_stages.rs:75, 122`）。**10 の縮小（Farm / Crop の編集は所有者のみ）後も、この写像は変わらない**（10 §2.10.3 の Edge 行、§5.9）。変わるのは、これまで成功していた非所有の組織メンバーの操作が、上記の 403 / 404 になる点である | Medium |
| D-04 | 429 | setup_proposal のみ（`openapi.yaml:382-383`）。`RateLimited` は `openapi.yaml:440-450` | 全 Masters ルートに適用。`429 {"error":"rate_limit"}` + `Retry-After`（秒）。認証に失敗した匿名リクエストは対象外 | `masters_routes.rs:7-29`（`route_layer`）、`masters_rate_limit.rs:109-136`（tier 分類）、`138-150`（応答）、`152-176`（middleware、匿名除外は 169-171）、R4 `contracts.rs:3153` | Medium |
| D-05 | `PUT` | Crop / CropStage / AgriculturalTask の update は `patch` のみ（`openapi.yaml:84, 168, 248`） | `PUT` と `PATCH` が同一ハンドラ。blueprint は `PATCH` のみ | `masters_crops.rs:37-43`、`masters_crop_stages.rs:48-51`、`masters_agricultural_tasks.rs:40-43`、`masters_crop_task_schedule_blueprints.rs:57-60`。Angular は `PATCH` を使用（`crop-api.gateway.ts:25`、`crop-stage-api.gateway.ts:24`） | Low |
| D-06 | crop_stage の 400 | create: 404/422 のみ、update: 404 のみ（`openapi.yaml:144-151, 179-185`） | create は `name` 空 / `order` 欠落で `400 {"error":"Invalid parameters"}`。update は `name`・`order` 双方欠落または `name` 空白で同 400。reorder は `crop_stages` 空で同 400 | `masters_crop_stages.rs:179-197, 199-228, 320-328`。R4 に 400 を表明するマスタ系テストは無い（`contracts.rs` の 400 表明は 4669 の backdoor 系 1 件のみ） | Medium |
| D-07 | setup_proposal のレスポンス | `200` は `CropSetupProposalDryRunResponse`（`mode` は `enum [dry_run]`、`errors` の items は `object`）、`201` は説明のみ（`openapi.yaml:368-375, 624-635`） | 200: `{"mode":"dry_run","valid":true,"normalized":…}`。200: 検証失敗は `{"mode":"dry_run\|apply","valid":false,"errors":[{"path","message"}]}`（**apply でも 200**）。201: `{"mode":"apply","valid":true,"normalized":…,"result":{"stage_ids","agricultural_task_ids","blueprint_ids"}}`。404: `{"error":"crop not found"}`。422: `{"error":"mode must be dry_run or apply"}` | `masters_crop_setup_proposal.rs:45-56, 73-82, 84-97, 99-113, 115-120, 144-154`、R4 `contracts.rs:2669`（検証失敗 200）・`2693`・`2715`（201 と `result` の一部）。apply 時の検証失敗 200 と invalid mode 422 を表明するテストは無い | High |
| D-08 | スキーマ部分集合 | `Crop` は `id/name/variety/region/is_reference` のみ（`openapi.yaml:463-475`）。`CropStage` は `id/name/order`（`504-511`）。agricultural_task・blueprint の 200 は説明のみ | `Crop` は 12 キー（`id,name,variety,area_per_unit,revenue_per_area,region,groups,user_id,created_at,updated_at,is_reference,crop_stages`）。`crop_stages` は show のみ実データ、list/create/update は `[]`。stage は `crop_id` と要件オブジェクト 4 種を含み得る。task は 13 キー、blueprint は 19 キー | `masters_json.rs:97-112, 114-168`、`masters_crops.rs:84, 114, 158, 197`、`masters_agricultural_tasks.rs:52-68`、`masters_crop_task_schedule_blueprints.rs:63-85` | Low |
| D-09 | セッション認証 | グローバル `security` は `bearerApiKey` と `headerApiKey` のみ（`openapi.yaml:23-25`）。`sessionCookie` は定義済み（`399-403`）、description 冒頭では「Session cookie authentication has full Masters access」（`13`） | Cookie `session_id` を Bearer / `x-api-key` と並べて解決。セッション主体はスコープ検査なし | `masters_auth.rs:44-61, 63-84, 115-118`。`getting-started.md:24` も「API キー または ログインセッション Cookie」。スコープ検査の対象は API キー主体だけで、`principal.api_key_scopes` が無い（セッション）なら素通りする（`masters_auth.rs:115-117`。単体テスト `masters_auth.rs:159`）。write の分類は `masters_api_scope.rs:16-34`。write operation の `security` 上書きは 03 の領分（0.2、4.15） | Low |
| D-10 | subset の範囲基準 | 「Public subset … crop master data, agricultural tasks, task schedule blueprints, and external skill `setup_proposal`」（`openapi.yaml:5-7`）。含める/除く基準の記述なし | 同じ認証・スコープ・レート制限が下記の記載外エンドポイントにも及ぶ（2.3 参照） | `masters_routes.rs:7-29`、`masters_api_scope.rs:17`（`/api/v1/masters/` 配下はすべて分類）、`llms.txt:10`（「OpenAPI contract for agrr-server HTTP APIs」と全体契約のように記載） | Low |
| D-11 | blueprint 作成のリクエスト形 | `TaskScheduleBlueprintCreateRequest` は `task_schedule_blueprint` ラッパー（`openapi.yaml:542-546`）。フィールド定義なし | フラット body（`agricultural_task_id`, `stage_order`, `stage_name`, `gdd_trigger`, `task_type`, `description`, `priority`）。ラッパーは未知キーとして無視され、必須項目欠落で `422 missing_agricultural_task_id` になる（serde の既定動作に基づく導出・未実測） | `masters_crop_task_schedule_blueprints.rs:135-150, 392-395`、Angular `crop-task-schedule-blueprint-api.gateway.ts:20-26`（フラット送信）、R4 `contracts.rs:2127, 2158`（フラット送信で 201/422） | High |
| D-12 | 記載 404 が実際は 422 | crop show/update/destroy、agricultural_task update/destroy に `404`（`openapi.yaml:82, 99, 110, 263, 274`） | crop update: not found は `UpdateFailure::Error` → `422 {"error":"record not found"}`。crop destroy: not found は `422 {"error":"<crops.flash.not_found の訳>"}`。agricultural_task update は全失敗が `422 {"errors":[msg]}`（ポリシー拒否も 422）。agricultural_task destroy の失敗は `422`。crop show は `e.message == "Crop not found"` の一致でのみ 404 だが、`RecordNotFoundError` の表示文字列は `record not found` のため 422 になると読める（未実測） | `crop_update_interactor.rs:44-50`、`masters_crops.rs:297-315, 345-360, 362-370`、`crop_destroy_interactor.rs:56-67`、`crop_detail_interactor.rs:50-62`、`shared/exceptions/mod.rs:6-7`、`agrr-adapters-sqlite/src/pool/mod.rs:149-162`、`crop/crop_gateway.rs:102-107`、`masters_agricultural_tasks.rs:228-238, 286-292` | Medium |
| D-13 | crop update の必須項目・409 | `CropUpdateRequest` は `name` / `variety` のみ、レスポンスは 200/401/404（`openapi.yaml:492-502, 85-100`） | body の `crop.updated_at` が必須（空なら `422`）。古い値は `409 {"error":"stale_record"}`。`area_per_unit`, `revenue_per_area`, `region`, `groups`, `is_reference` も受理。非 admin が `is_reference` を変えると `422` | `masters_crops.rs:51-61, 164-201, 304-311`、`crop_update_interactor.rs:55-80, 137-140`。R4 に masters crop の update テストは無い（`contracts.rs:345` の 409 は work_records 用） | High |
| D-14 | `Error.errors` の型 | `errors: array of object`（`openapi.yaml:458-461`） | `errors` は文字列配列（crop 作成 `["name is required"]`、stage `["invalid"]`、task `[msg]`、blueprint の検証失敗）。オブジェクト配列なのは setup_proposal の `errors` のみ（`{path,message}`） | `masters_crops.rs:125-129, 281-284`、`masters_crop_stages.rs:253-255`、`masters_agricultural_tasks.rs:181-185`、`masters_crop_task_schedule_blueprints.rs:422-425`（`errors` の型は `Vec<String>`: `crates/agrr-domain/src/crop/dtos/masters_crop_task_schedule_blueprint_create_failure.rs:15`）、`masters_crop_setup_proposal.rs:144-154`。**07 の契約で上書き**: 失敗本文の `errors` は 1 件以上の非空文字列の配列で必須（07 §3.3 の C1）。setup_proposal の 200 の `errors: [{path, message}]` は失敗本文ではなく結果ペイロードで、07 の C3 の例外 (i) として対象外（4.6 の専用スキーマ） | Medium |
| D-15 | 削除の undo 応答 | crop: 「Deleted (undo token may be returned)」、task: 「Deleted」（`openapi.yaml:106-107, 270-271`） | crop は常に `200 {"undo":{"undo_token","undo_path","toast_message","undo_deadline","auto_hide_after"}}`。agricultural_task は `200` でフラット（`undo_token, undo_deadline, toast_message, undo_path, auto_hide_after, resource, redirect_path, resource_dom_id, metadata`） | `masters_json.rs:170-186`、`masters_crops.rs:230-234`、`masters_agricultural_tasks.rs:283-285`、`agrr-adapters-sqlite/src/soft_delete.rs:44-56` | Low |
| D-16 | 構文不正・欠落パラメータ | 記載なし | `Json<…>` / `Query<…>` extractor（`mode` は `SetupProposalQuery` の必須文字列）。axum 0.8 の標準拒否（400/415/422 とテキスト body）になると考えられるが、ステータスと body は実測していない | `masters_crop_setup_proposal.rs:33-36, 43`、`crates/agrr-server/Cargo.toml:29`（axum 0.8）。**未確認** | 未確認 |

### 2.2 実 API の確定表（openapi 記載 operation）

以下は上記の実装読解から確定した「実際のステータスとボディ」。`401` は全 operation 共通で `{"error":"unauthorized"}`（`masters_auth.rs:102-107`）。`403 scope`・`429` も全 operation 共通（D-03、D-04）。「未実測」は実行して確認していない導出。

**本表の失敗本文の読み方（07 との対応）:** 本表の `{"error": X}` は、07 の S0（現状）の実測である。07 の S1 以降は同じ失敗が `{"errors": [X], "error": X}`（`error` は deprecated の併記）、S2 以降は `{"errors": [X]}` になる（07 §3.3 の C1・C4、§3.5.4 の A2）。ステータスと `error_code` は変わらない。`{"errors": [...]}` の行は 07 の区分 C（変更なし）。本書の差分案（第 4 章）は、メッセージ文字列を「message `X`」と書いて、この差を吸収する。

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

**subset 基準の文書化状況（確認結果）:** `openapi.yaml:5-7` は含める領域を列挙するだけで、除外基準・除外一覧はどこにも無い。`getting-started.md:1` は「スキル作者向け」とするのみ。公式 MCP サーバーが呼ぶのは 4 本（作物一覧・作物詳細・dry_run・apply）に限られる（`tools/agrr-mcp/README.md:51-54`、`tools/agrr-mcp/src/agrr-client.mjs:23, 41, 48, 57`。03 の `apply_crop_setup` 削除（M-A）が実施されると apply が消えて 3 本になり、`:57` は削除され、以降の行番号がずれる: 03 §5.3、§5.3.6）。`openapi.yaml` の operation 20 本はこの 4 本（削除後は 3 本）を超える（stage・task・blueprint の CRUD）ため、「MCP が使うものだけ」という基準でもない。つまり**基準は文書化されておらず、現状の範囲は経緯によるものと読める（経緯は未確認）**。`llms.txt:10` は同ファイルを「agrr-server HTTP APIs の OpenAPI 契約」と説明しており、subset という自己申告と食い違う。

### 2.4 関連文書との不整合（他課題へ委譲）

| 箇所 | 内容 | 委譲先 |
| ---- | ---- | ------ |
| `getting-started.md:32-41` | 「現時点ではキーごとのスコープ列は DB に保存していません」「発行されたキーは現状読み取りと書き込みの両方が可能」。実装はスコープを強制し、既定は `["masters:read"]`（`masters_api_scope.rs:47-50`、R4 `contracts.rs:3014, 3049, 3070`、`3095` の `post_api_keys_generate_defaults_to_read_only_scopes`）。`openapi.yaml:10-13` は新規・再発行キーについて実装どおり（V15 以前の既存キーは read+write のまま残る。03 の V27 が read のみへ移行する）。03 の文書公開は V27 の DB 適用確認後（0.3 のフェーズ C） | 03 |
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
| D-03 | `Forbidden` レスポンスを追加し、全 operation に付与。`Error` に `error_code`（string）を追加 | 実装が返している。公開 operation が返す `error_code` は `insufficient_scope` と blueprint 作成の 7 値（`crop_not_found`、`missing_agricultural_task_id`、`missing_gdd_trigger`、`invalid_stage_order`、`agricultural_task_not_found`、`duplicate_blueprint`、`validation_failed`: `masters_crop_task_schedule_blueprints.rs:392-424`。`duplicate_blueprint` は更新も返す: `:452-473`）。廃止 API の `crop_task_template_api_removed` と regenerate の値は D-10 の除外対象の operation のため、列挙に含めない | **07 の C6 は自由文字列で確定済み**（既存の値を維持し、新規の識別子は `error_code` に置く）。08 もこれに合わせる。残る確認は、`enum` で固定するかどうかだけ（既定: 自由文字列。値の追加で契約が壊れず、後から `enum` に絞るより安全）。**API キーの read のみ方針に基づく 403 の説明と write operation の `security` 上書きは 03 が正**（0.2） |
| D-04 | 全 operation に `429`（既存 `RateLimited`）を付与 | 全 Masters ルートに適用（`masters_routes.rs:25-28`） | 不要 |
| D-05 | 実装は変更せず、`patch` の description に「`PUT` は同義のエイリアス」と書く。**`security` も `PATCH` と同じ**（03 の案 B では session のみ。`PUT` も write の分類に入る: `masters_api_scope.rs:31`）ことを同じ description に書く | フロントは `PATCH` のみ使用。`PUT` を残した経緯は未確認（`masters_auth.rs:1` に「Rails `BaseController` parity」とあるが、`PUT` との関係は未確認）。削除は外部利用者の有無が未確認のため破壊的になり得る。OpenAPI 3.0.3 には「別メソッドの別名」を表す構文が無く、`put` を別 operation として足すと operation が増える（03 の write 12 件の数え方も変わる） | **要**: `PUT` を公式サポートとして記載するか、非推奨として将来削除するか。推奨は「エイリアスとして記載のみ」（`put` の operation は足さない） |
| D-06 | openapi に `400`（`Invalid parameters`）を create / update に追加 | 実装が返している。`CropStageCreateRequest` に `name`・`order` を必須で記載 | 不要 |
| D-07 | `CropSetupProposalResponse`（200）と `CropSetupProposalApplyResponse`（201）を定義し、`422`（mode 不正）を記載。apply の検証失敗は 200 と明記 | 実装どおり。R4 が 200/201 の一部を固定済み。apply の 200 検証失敗・422 は 6.3 で固定する | 不要（ただし apply の検証失敗を 200 のままにするか 4xx にするかは別課題。本課題では現状を記載） |
| D-08 | `Crop`（12 キー）・`CropStage`・`AgriculturalTask`・`TaskScheduleBlueprint` のレスポンススキーマを実 JSON に合わせて記載。リクエスト body に実際に受理するプロパティを追加 | 実装の JSON 生成箇所が単一（`masters_json.rs`、`task_json`、`blueprint_json`） | 不要 |
| D-09 | グローバル `security` に `sessionCookie` を追加（OR） | `getting-started.md:24` と実装が両方式を許容。`sessionCookie` の description（`openapi.yaml:403`）にある「UI only」は残す（03 の §5.2.2 も同じ文を維持し「Required for all write operations.」を追記する）。**03 の案 B（write operation を session のみに上書き）とは矛盾しない**: グローバルは read の既定（3 方式の OR）、write の 12 operation だけが 03 の上書きで session のみになる（4.15） | 不要 |
| D-10 | subset のまま、`info.description` に範囲基準と除外一覧、「除外エンドポイントにも同じ認証・スコープ・レート制限が及ぶ」を明記 | 全 Masters を網羅すると operation が大幅に増え（2.3 の系統すべて）、ルートの追加のたびに追随が必要になる。基準を先に決めれば範囲外の追加で乖離が生じない | **要**: (a) subset 維持 + 基準明記（推奨）、(b) 全 Masters を網羅。基準の案は 4.10 |
| D-11 | openapi をフラット body に直す | Angular・R4・実装が一致してフラット | 不要 |
| D-12 | 本課題では実挙動（422）を openapi に記載。挙動変更は 10 と合わせて判断 | 404 に揃える実装変更は crop の 3 操作と task の 2 操作に及び、認可の返し方（403/404/422）の統一方針が前提になる。crop show の 422 は未実測のため、実測後に確定。**10 の最新版は状態コード統一（U16）に未対応**で、縮小（D8）も「新しい状態コードを作らず現行の写像を維持する」（10 §2.10.3、§5.9）ため、10 に統一方針ができるまで (b) は選べない | **要**: (a) 実挙動を記載して当面維持（推奨）、(b) 実装を 404 に修正（10 の U16 と同一の変更として実施） |
| D-13 | `updated_at` を必須にし、`409`・`422`・`403` を記載 | 実装どおり。楽観ロックの契約であり、記載しないと更新が必ず 422 になる | 不要 |
| D-14 | `Error.errors` を文字列配列に直し、07 の契約に合わせて**必須**（1 件以上、各要素は非空）にする（フェーズ B 以降。フェーズ A の暫定形は 4.14）。旧キー `error` は B で `deprecated: true`、D で削除。setup_proposal の `errors`（`{path,message}`）は専用スキーマにする | 実装どおり（A）、07 の契約（B・D）。`error` を恒久のプロパティとして書かない（07 §10 の 08 の行） | 不要 |
| D-15 | 削除応答の 2 形状を別スキーマで記載 | 形状の統一は実装変更（フロントの `deleteWithUndo` が両形状を扱う: `frontend/src/app/services/masters/masters-client.service.ts:60-63`）。本課題では現状を記載 | 不要 |
| D-16 | 今回は記載しない。実測後に判断 | 未確認の挙動を契約に書かない（根拠ゲート） | 不要 |

### 3.3 ユーザー確認が必要な点（まとめ）

1. D-03: `error_code` を自由文字列にするか `enum` にするか。07 の C6 は自由文字列で確定済みのため、既定は自由文字列。`enum` に絞る場合は 07 の C6 の改訂が先に要る（`error_code` の値が増えるたびに契約が変わるため）。
2. D-05: `PUT` をエイリアスとして記載するのみでよいか、廃止方針を持つか。
3. D-10: subset を維持して基準を明記するか、全 Masters を網羅するか。基準の文言案（4.10）でよいか。02・05・06・11 が 08 へ渡した未掲載エンドポイントの契約の扱いもこの回答で決まる（第 10 章）。
4. D-12: not found / ポリシー拒否のステータスを、本課題では現状（422）記載にとどめ、変更は 10 の U16 と一体で行うか。

本書の確認事項に含めないもの（別文書が回答の窓口）: 03 の Q7（write operation の `security` 上書き。既定は案 B）、03 の Q9（MCP のバージョン）、07 の Q2（旧キー撤去の猶予延長）、10 の U16（認可失敗の状態コード統一）・P3（admin）・P14（Farm / Crop の閲覧）。これらの回答によって差分案が変わる箇所は、各所に参照を付けた（0.2、4.11、4.15、4.16）。

上の 4 点は、確認が取れるまでは推奨案で進めてよい（いずれも `openapi.yaml` の記述を後から差し替えるだけで済み、実装には影響しない）。

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

`204` の operation には `content` を付けない。`401` / `403` / `404` / `429` は 4.2・4.3 の適用ルールで追加する。適用後の operation ごとの最終形は 4.16。crop と agricultural_task の削除は `200`（undo 応答）のままで、204 にしない（D-15、4.13）。

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

After（フェーズ A。`Error` は現状の実装に一致する暫定形 E1。D-14 と同時に適用する。フェーズ B 以降の形は 4.14）

```yaml
  responses:
    Forbidden:
      description: |
        Forbidden. Either the API key lacks the scope required for the operation
        (`error_code: insufficient_scope`) or the resource policy denies the operation
        (message `crops.flash.no_permission`).
      content:
        application/json:
          schema:
            $ref: '#/components/schemas/Error'
  schemas:
    Error:
      type: object
      description: |
        Failure body. Until the server returns `errors` on every failure, the message is in
        `errors` on some failures and in `error` on others.
      properties:
        error:
          type: string
        error_code:
          type: string
          description: |
            Machine-readable code when present. A free-form string; new values may be added.
            Known values: `insufficient_scope`, `crop_not_found`,
            `missing_agricultural_task_id`, `missing_gdd_trigger`, `invalid_stage_order`,
            `agricultural_task_not_found`, `duplicate_blueprint`, `validation_failed`.
        errors:
          type: array
          items:
            type: string
            minLength: 1
```

差分案のうち 07 に依存する点: (1) `error_code` は自由文字列で、既存の値を維持する（07 の C6）。値の列挙は「known values」の例示で、`enum` にしない。(2) 旧版にあった `crop_task_template_api_removed` は、410 を返す `crops/{crop_id}/agricultural_tasks` 系（`masters_crop_agricultural_tasks.rs:13-33`）が D-10 の除外対象で `openapi.yaml` に operation が無いため、列挙から外した。(3) `Forbidden` の description は、判定の主体（所有者・admin・組織メンバー）を書かない（10 の縮小で変わる箇所を 08 が二重に持たないため。0.1）。(4) メッセージ文字列は「message `…`」と書き、`error:` のキー名を直書きしない（07 の S1・S2 でキーが変わるため）。

適用ルール: 20 operation すべての `responses` に次を追加する（スコープ 403 は全 operation に起こり得るため）。

```yaml
        '403':
          $ref: '#/components/responses/Forbidden'
```

ポリシー拒否の 403 が起き得る operation（crop show/update/destroy、agricultural_task list/show/destroy）には、`Forbidden` の description に依存せず operation 側の description に「ポリシー拒否時も 403」と補足する。stage・blueprint・setup_proposal はポリシー拒否が 404 になるため補足しない（10 の縮小後も同じ。2.1 の D-03 の行）。

スコープ起因の 403 が各 operation で起きる条件は次のとおり（実装は `masters_api_scope.rs:16-34`、`masters_auth.rs:109-128`）。`Forbidden` の description には条件を書かず、「API キーが操作に必要なスコープを持たない」とだけ書く。条件の詳しい説明と「API キーは read のみ」の方針は 03 が書く（0.2）。

| operation の種類 | 403（`insufficient_scope`）が起きる API キー | 備考 |
| ---------------- | ------------------------------------------- | ---- |
| write（`POST` / `PUT` / `PATCH` / `DELETE`、`setup_proposal?mode=apply`） | `masters:write` を持たないキー。03 の V27 適用後は全キー | セッションは対象外（`masters_auth.rs:115-117`） |
| read（`GET`、`setup_proposal?mode=dry_run`） | `masters:read` も `masters:write` も持たないキー（スコープが NULL・空・不正 JSON のキー）。API キー主体は `Some(parse_api_key_scopes_json(..))` で作られ（`crates/agrr-adapters-sqlite/src/shared/api_key_principal_gateway.rs:28`）、空配列は read も拒否される（`masters_api_scope.rs:39-42`）。03 §2.4 も同じ導出で、**未実測**（03 の T-7 で固定する予定） | 通常のキーでは起きないが、`Forbidden` を全 operation に付けるのはこのため |

### 4.3 D-04: 429 を全 operation に

Before（`openapi.yaml:382-383` のみ）

```yaml
        '429':
          $ref: '#/components/responses/RateLimited'
```

After: 20 operation すべての `responses` に同じ参照を追加する。`RateLimited`（`openapi.yaml:440-450`）は変更しない。`info.description` の「See getting-started.md」の近くに「429 は認証済みリクエストのみ対象」と補足する（匿名は対象外: `masters_rate_limit.rs:169-171`）。この補足は 08 が書く段落で、冒頭のスコープ箇条書き（03 が書き換える）とは別の段落にする（0.2）。`RateLimited` の本文は `Error` を参照するため、`rate_limit` のメッセージは 07 の段階（E1 → E2 → E3）に自動で従う。`getting-started.md:57` の例は 03 と 07 が編集する（08 は編集しない）。

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
        `PUT` is accepted on this path as an alias of `PATCH` with the same body, responses
        and authentication requirements.
      operationId: updateCrop
```

`put` を別 operation として足さない（3.2 の D-05）。03 の案 B で `patch` に付く `security`（セッションのみ）は、`PUT` にも及ぶことを上の 1 文で表す（0.2、4.15）。`updateCrop` の `patch` の `security` 行は 03 が書き、08 は書かない。

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
      description: 'Missing or blank required parameters (message `Invalid parameters`)'
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
          description: 'Crop not found or not editable by the caller (message `crop not found`)'
          content:
            application/json:
              schema:
                $ref: '#/components/schemas/Error'
        '422':
          description: '`mode` is neither `dry_run` nor `apply` (message `mode must be dry_run or apply`)'
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

`CropSetupProposalDryRunResponse` は `CropSetupProposalResponse` に置き換えて削除する。`CropSetupProposalResponse.errors`（`{path, message}` の配列）は、`Error` の `errors`（文字列配列）とは別物である。前者は HTTP 200 の検証結果ペイロードで、07 は失敗本文の契約の対象外（C3 の例外 (i)、§2.7 の #6）とし、型を変えないと決めている。このため `Error` の `$ref` を使い回さず、専用スキーマ（上の `CropSetupProposalValidationError`）のまま維持する。旧キー撤去（フェーズ D）後も変更しない。404・422 は `Error` を参照するため、07 の段階（E1 → E2 → E3）に従う。`normalized` が `CropSetupProposal` と一致するかは未確認（`normalize` 出力はポリシー実装 `crop_setup_proposal_policy` の戻り値で、本書では読んでいない）。実装時に `crop_setup_proposal_policy::validate_and_normalize` の出力形を確認し、違えば専用スキーマにする。

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

グローバルの意味は「read operation の既定（3 方式の OR）」になる。write operation を session のみにする上書きは 03 が書く（4.15）。`sessionCookie` の description と `bearerApiKey` / `headerApiKey` の description の書き換えも 03（0.2）。この変更（フェーズ A）は 03 の公開（フェーズ C）より先に出してよい。グローバルに session を足す事実（`getting-started.md:24`、`masters_auth.rs:63-84`）は、V27 の適用に依存しない。

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
            The message is a translated string.
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

**10 の最新版との整合（2026-10-07 時点の 10 を読んだ範囲）:**

- 10 は認可失敗の状態コード統一（403 / 404 / 422）を U16 として**未対応**のままにしている（§8.2）。縮小（D8）は「新しい状態コードを作らず、現行の写像を維持する」（§2.10.3 の Edge 行、§5.9）。したがって案 A（実挙動の記載）を維持できる。案 B を選ぶのは、10 が U16 の統一方針を決めた後で、その変更と同じ PR で `openapi.yaml` を更新する。
- 縮小で、非所有の組織メンバーの `updateCrop` / `destroyCrop` は成功から 403 `crops.flash.no_permission` になる（`masters_crops.rs:297-303, 362-367`）。`updateCrop` に追加する `'403'` で足りるため、追加の記載は要らない。stage・blueprint・setup_proposal の書き込みは 404 になり（`masters_crop_stages.rs:75, 122`、`crop_masters_task_schedule_blueprint_*_interactor.rs` の `assert_edit` 失敗、`crop_setup_proposal_interactor.rs:68-71`）、既存の `'404'` で足りる。**description に「所有者」「組織」「admin」を書かない**（10 の P3・P14 が未決で、記載が先に古くなるため）。
- blueprint 一覧（`listTaskScheduleBlueprints`）は現状、閲覧なのに編集判定（`assert_edit`）で通している（`crop_masters_task_schedule_blueprint_index_interactor.rs:62`。10 の E9）。10 の P14 が (a)（閲覧は組織単位のまま）なら、10 が一覧を閲覧判定へ切り替える。非所有の組織メンバーは現状も縮小後も一覧を取得でき、非メンバーは 404 のままなので、`openapi.yaml` の記載は変わらない。P14 が (b)（閲覧も所有者のみ）に決まった場合は、非所有の組織メンバーの `showCrop` が 403 `crops.flash.no_permission`（`masters_crops.rs:347-350`）になり、一覧から他メンバーの行が消える。既存の `'403'` の枠内だが、D-12 の確定表（2.2）と T6・T7 の given を 10 の決定に合わせて見直す。
- 10 の §4（ドキュメント行）は「`openapi.yaml` に `organization` の記述が無く、更新は不要の見込み」とし、U10 を未確認にしている。本書で `rg -n -i "organi|admin|owner" docs/api/openapi.yaml` を実行し、0 件であることを確認した（認可の主体に関する記述は `openapi.yaml` に無い）。U10 のうち「`openapi.yaml` に組織・所有者の記述があるか」は解消できる。ステータスの写像が変わらないことは上記のコード読解（未実測）による。

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
                a stale value yields 409 (message `stale_record`).
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
          description: 'Stale update (message `stale_record`)'
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

### 4.14 `Error` スキーマの段階別の形（D-03・D-14。07 の契約への追随）

`Error` は 07 の段階（S0 → S1 → S2）と 0.3 のフェーズに合わせて 4 つの形を取る。内容を決めるのは 07（0.2）で、本節は転記の形を固定するだけである。E1 は 4.2 に示した。

| 形 | 使うフェーズ | `errors` | `error` | `error_code` | `field_errors` |
| -- | ------------ | -------- | ------- | ------------ | -------------- |
| E0（現行。`openapi.yaml:453-461`） | – | 任意。要素型は `object`（実装は文字列。誤り） | 任意の文字列 | 無い | 無い |
| E1 | A | 任意。文字列配列（要素は非空） | 任意の文字列（deprecated にしない） | 任意の文字列 | 書かない |
| E2 | B（07 の S1 以降） | **必須**。1 件以上の非空文字列の配列 | 任意。`deprecated: true` | 任意の文字列 | 任意 |
| E3 | D（07 の S2 以降。最終形） | **必須**。同上 | **プロパティごと削除** | 任意の文字列 | 任意 |

E2（07 の S1 の公開版。07 §3.8、§3.5.1 の S1 の行）

```yaml
    Error:
      type: object
      required: [errors]
      properties:
        errors:
          type: array
          minItems: 1
          items:
            type: string
            minLength: 1
          description: |
            Failure messages. Always present on a 4xx or 5xx response. Each item is an i18n key
            or a readable message.
        error_code:
          type: string
          description: |
            Machine-readable code when present. A free-form string; new values may be added.
            Known values: `insufficient_scope`, `crop_not_found`,
            `missing_agricultural_task_id`, `missing_gdd_trigger`, `invalid_stage_order`,
            `agricultural_task_not_found`, `duplicate_blueprint`, `validation_failed`.
        field_errors:
          type: object
          additionalProperties:
            type: array
            items:
              type: string
          description: |
            Optional per-field messages. No operation in this document returns it at present.
        error:
          type: string
          deprecated: true
          description: |
            Same string as `errors[0]`. Present only on responses that returned `error` before
            `errors` was added. Do not read it; it will be removed.
```

E3（最終形）は E2 から `error` のプロパティ（`deprecated` と description を含む）を削除したもので、他は同一である。

- **`message` は載せない。** 07 の §3.8 と §3.5.4 の O1 は旧キーとして `error` と `message` を挙げるが、`openapi.yaml` の operation の失敗本文に最上位の `message` は無い。Masters の `"message"` は、成功本文（`masters_crop_pests.rs:125`）と setup_proposal の結果ペイロード内の要素（`masters_crop_setup_proposal.rs:150`）だけで、失敗本文には現れない（`rg -n '"message"' crates/agrr-server/src/masters_*.rs` の 2 件）。`message` を最上位に持つ失敗は 07 の区分 B（Plans 系の `{success: false, message}`）で、`openapi.yaml` に operation が無い。載せると存在しない旧キーを契約に書くことになるため、`Error` には `error` だけを deprecated として載せる。07 側の §3.8・§3.5.4 O1 の `message` の扱い（Masters の公開 operation には不要）は、07 の改訂時に確認を依頼する（第 10 章）。
- **`error` の併記の範囲。** 07 の S1 は、区分 A（従来 `error` を返した箇所）にだけ `error` を併記する。区分 C（従来 `errors` を返した箇所。blueprint の `validation_failed` を含む）は `error` を持たない（07 §3.2.1）。E2 の `error` が「任意」なのはこのため。
- **5xx。** 07 の契約は 5xx も対象だが、`openapi.yaml` の operation に 5xx の記載は無い。本書は 5xx を追加しない（D-16 と同じく、未確認の挙動を契約に書かない根拠ゲート）。
- **`field_errors`。** 07 の最終形（O1）に含まれるため `Error` に載せる。Masters の公開 operation が `field_errors` を返す実装は、現状も 07 の S1 の計画にも無い（`rg -n "field_errors" crates --glob '*.rs'` が 0 件。07 の対象は contact・work record・task schedule・photo）。使われないプロパティを載せることになるが、`Error` は 07 の契約と同一の形にそろえるため残す。載せない判断をするなら 07 の O1 の改訂が先に要る。
- **例と description の書き方。** 本書の差分案は、メッセージ文字列を「message `…`」と書き、`error:` / `errors:` のキー名を直書きしない（4.5〜4.12）。キー名は `Error` スキーマだけが持つ。フェーズ D の受け入れ検査（4.16）が、旧キーの直書きの残存を検出できる。

### 4.15 write operation の `security` 上書き（**正は 03 §5.2.3。本節は再掲**）

**責務:** 内容（対象 operation、setup_proposal の例外、文言、公開時期）は 03 が決める（0.2）。03 の Q7 の回答が案 A（注記のみ）の場合は、本節を適用しない。本節は 08 の他の差分案との**重なり**（グローバル `security` の D-09、`responses` の 403 の D-03、`PUT` の D-05）を解消するために、適用後の形を 1 か所に書く。03 の推奨は案 B で、Q7 の既定でもある。

公開の条件は、03 の V27 を本番に適用して DB で確認した後（フェーズ C）。V27 の前は、V15 以前の既存キーが書き込めるため、「write は session のみ」は不正確になる（03 §5.4.1.9）。

対象は write の 12 operation（`createCrop`、`updateCrop`、`destroyCrop`、`createCropStage`、`updateCropStage`、`destroyCropStage`、`createAgriculturalTask`、`updateAgriculturalTask`、`destroyAgriculturalTask`、`createTaskScheduleBlueprint`、`updateTaskScheduleBlueprint`、`destroyTaskScheduleBlueprint`）。`setup_proposal` は対象外（`mode` の値で `security` を分けられないため。03 §5.2.3）。

適用後の形（`createCrop` の例）

```yaml
    post:
      operationId: createCrop
      security:
        - sessionCookie: []
      responses:
        '201': ...
        '401':
          $ref: '#/components/responses/Unauthorized'
        '403':
          $ref: '#/components/responses/Forbidden'
```

重なりの解消

| 重なる箇所 | 08 の担当 | 03 の担当 |
| ---------- | --------- | --------- |
| グローバル `security`（D-09） | `sessionCookie` を足す（4.8。フェーズ A） | 触れない |
| write operation の `security` | 書かない | 12 件に `security: [{sessionCookie: []}]`（フェーズ C） |
| `setup_proposal` の `security` | グローバルのまま | グローバルのまま。description と `403` で「`mode=apply` は API キーでは 403」と明記 |
| 12 件の `responses` の `403` | `Forbidden` を参照して追加（4.2。フェーズ A） | 追加しない（08 に従う。03 §5.2.4） |
| `PUT` | `patch` の description に「同じ authentication requirements」（4.4） | `patch` に `security` を付ければ `PUT` にも及ぶ。`put` を別 operation にしない |
| 実装の挙動 | API キーで write を呼ぶと 401 ではなく 403 `insufficient_scope`（`masters_api_scope.rs:16-34`、`masters_auth.rs:109-128`） | `securitySchemes` の description と冒頭 description で説明 |

`security` から外れた方式（write に API キー）が実際には 401 ではなく 403 を返す点は、`Forbidden` の description（4.2）が担う。operation の `security` が session のみでも、`'403'` を write の 12 件に載せる理由はこれである。

### 4.16 旧キー削除後の最終 OpenAPI 状態（フェーズ A〜D をすべて適用した後）

07 の S2 が完了し、03 の V27 と文書公開が済み、本書の差分案がすべて適用された後の `openapi.yaml` の状態を、確認できる形で固定する。**この状態は実装・他文書の決定に依存する**ため、各行に出典を付けた。D-12 の案 B・03 の Q7 の案 A・10 の U16 の決定で変わる行は注記した。

**(1) `Error`（E3）と共通応答**

| 項目 | 最終の状態 | 出典 |
| ---- | ---------- | ---- |
| `Error` | `required: [errors]`。`errors`（`minItems: 1`、非空文字列）、`error_code`（自由文字列）、`field_errors`。`error` のプロパティと `deprecated` の記述が無い | 07 §3.3（C1・C4・C6）、§3.5.4（O1）、4.14 |
| `Unauthorized` / `NotFound` / `Unprocessable` / `RateLimited` / `Forbidden` / `BadRequest` | すべて `Error` を参照する。`RateLimited` は `Retry-After` ヘッダーを維持。description と例にキー名（`error`）を書かない | 4.2〜4.5、07 §3.5.4 の A5 |
| setup_proposal の 200 の `errors` | `CropSetupProposalResponse.errors`（`{path, message}` の配列）のまま。`Error` と共有しない | 07 §3.3（C3 の例外 (i)）、4.6 |
| `error_code` の列挙 | `enum` にしない（自由文字列 + known values の例示）。ユーザーが `enum` を選ぶ場合は 07 の C6 の改訂が先 | 07 §3.3（C6）、3.3 の確認事項 1 |
| グローバル `security` | `bearerApiKey`・`headerApiKey`・`sessionCookie`（OR） | 4.8 |
| 12 の write operation | `security: [{sessionCookie: []}]`（03 の Q7 が案 B の場合） | 4.15、03 §5.2.3 |
| 削除の 2 operation | `destroyCropStage` と `destroyTaskScheduleBlueprint` は `204`（`content` 無し） | 4.1 |

**(2) operation ごとの `responses`（20 本）**

`401` / `403` / `429` は全 operation に付く（`Unauthorized` / `Forbidden` / `RateLimited`）。表は成功応答と、それ以外の応答（`401` / `403` / `429` を除く）を示す。`security` の列の「session」は 03 の案 B の場合。

| operationId | 成功 | その他の応答 | `security` |
| ----------- | ---- | ------------ | ---------- |
| `listCrops` | 200 `[Crop]` | 422 | グローバル |
| `createCrop` | 201 `Crop` | 422（上限超過を含む） | session |
| `showCrop` | 200 `Crop` | 実測（6.3 の T7）で確定した 404 または 422。確定までは現行の 404 を維持 | グローバル |
| `updateCrop` | 200 `Crop` | 409、422（`PUT` は同じ） | session |
| `destroyCrop` | 200 `CropDestroyResponse` | 422 | session |
| `listCropStages` | 200 `[CropStage]` | 404 | グローバル |
| `createCropStage` | 201 `CropStage` | 400、404、422 | session |
| `showCropStage` | 200 `CropStage` | 404 | グローバル |
| `updateCropStage` | 200 `CropStage` | 400、404、422（`PUT` は同じ） | session |
| `destroyCropStage` | 204 | 404 | session |
| `listAgriculturalTasks` | 200 `[AgriculturalTask]` | – | グローバル |
| `createAgriculturalTask` | 201 `AgriculturalTask` | 422 | session |
| `showAgriculturalTask` | 200 `AgriculturalTask` | 404 | グローバル |
| `updateAgriculturalTask` | 200 `AgriculturalTask` | 422（ポリシー拒否・not found を含む。`PUT` は同じ） | session |
| `destroyAgriculturalTask` | 200 `AgriculturalTaskDestroyResponse` | 422 | session |
| `listTaskScheduleBlueprints` | 200 `[TaskScheduleBlueprint]` | 404 | グローバル |
| `createTaskScheduleBlueprint` | 201 `TaskScheduleBlueprint` | 404、422 | session |
| `updateTaskScheduleBlueprint` | 200 `TaskScheduleBlueprint` | 404、422 | session |
| `destroyTaskScheduleBlueprint` | 204 | 404 | session |
| `cropSetupProposal` | 200 `CropSetupProposalResponse`、201 `CropSetupProposalApplyResponse` | 404、422（`mode` 不正） | グローバル（`mode=apply` の API キーは 403） |

表の根拠は 2.2 の確定表である。差分案で触れていなかった追記が 1 点ある: **`updateCropStage` の `422`**（order 競合など。`masters_crop_stages.rs:199-228`、R4 `contracts.rs:2422`）は、2.1 の D-06 が「update は 404 のみ」と書いた現状に対して、最終形では記載する。`listAgriculturalTasks` の失敗は全件 403（2.2）のため、`403` 以外の行は無い。`403` の意味は、ポリシー拒否（crop show/update/destroy、agricultural_task list/show/destroy）とスコープ不足（全 operation。read は NULL・空スコープのキーのみ: 4.2 の表）の 2 種類である。

**(3) 旧キー削除の受け入れ検査（フェーズ D）**

| # | 検査 | 期待 |
| - | ---- | ---- |
| 1 | `rg -n "deprecated" docs/api/openapi.yaml` | 0 件（現行も 0 件。07 の O1 と同じ検査） |
| 2 | `rg -n '"error"\|\berror:' docs/api/openapi.yaml` | 0 件。`error_code:` は一致しない。例・description にも旧キー名が無い |
| 3 | `rg -n '"error"' docs/api` | 0 件（`getting-started.md` を含む。07 の O2 と同じ。`getting-started.md` の編集は 03・07） |
| 4 | `Error` の `required` | `[errors]` |
| 5 | 全 20 operation の `responses` に `Unauthorized` / `Forbidden` / `RateLimited` | 4.16 (2) と一致 |
| 6 | `python3` などで YAML を読み、`$ref` がすべて解決できる（使い捨て。リポジトリに追加しない: 5.2） | エラー無し |

検査 1〜3 は 07 の S2 の受け入れ条件（07 §9 の 20）と同じ内容で、08 が `Error` と応答の記載を担う部分の確認である。**機械検証の限界:** 08 の再発防止の P3 / P6 は `Error` の中身を検証しない。旧キーの再混入は 07 の S-T0 / S-T2 / S-T6 と上の検査 2・3 で防ぐ（07 §3.5.5）。

**(4) 最終形に至るまでの差分の要約**

| 遷移 | 変わるもの |
| ---- | ---------- |
| E0 → E1（フェーズ A） | `errors` の要素型を文字列にし、`error_code` を足す。`403` / `429` / `400` / 204 / `PUT` / スキーマ / `sessionCookie`（グローバル） |
| E1 → フェーズ C | 12 の write operation に `security` の上書き。冒頭 description と `securitySchemes` の文言（03） |
| E1 → E2（フェーズ B） | `errors` を必須（`minItems: 1`）にし、`field_errors` を足し、`error` を `deprecated: true` で足す |
| E2 → E3（フェーズ D） | `error` を削除する。deprecated の記述を無くす |

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
4. **07 の S-T0 / S-T2 との分担**: P3 / P6 は失敗本文のキー（`errors` / `error`）を検証しない。`Error` の形の機械的な担保は 07 が持つ（S-T0 の `assert_error_envelope`、旧キー不在の S-T2、直書き禁止の S-T6。07 §3.5.5、§10）。本書の R4 テストは、失敗本文の形を自前で表明せず、07 が Masters の経路に組み込む `assert_error_envelope` を使う（6.1）。`openapi.yaml` の `Error` の内容を機械検証する仕組みは追加しない。

追加の運用規約が必要な場合は、`docs/api/openapi.yaml` 冒頭ではなく既存の場所（PR の観点）に留める。新規ドキュメントは作らない。

---

## 6. TDD / 検証計画

### 6.1 位置付け

`openapi.yaml` の修正はドキュメントのみの変更で、`.cursor/rules/tdd-on-edit.mdc` の例外（ドキュメント/設定のみ）に当たる。ただし本計画は、記載する内容が事実であることを**テストで固定してから**文書へ反映する（`evidence-before-design-and-implementation.mdc` の根拠ゲート）。

- 追加する R4 テストの多くは、**既存実装の挙動を固定する特性化テスト**であり、追加時点で GREEN になる（RED は無い）。これは意図どおりで、RED を作るために実装を壊すことはしない。
- 実装の挙動を変える判断（D-12 で案 B を選ぶ場合）だけは通常の RED → GREEN とする。RED は「期待するステータスを表明して失敗する」ことで確認する。
- **失敗本文のキー（07 との境界）。** 現状（07 の S0）の Masters の失敗本文は `error` が多く、`errors` は一部だけである（2.2）。本書のテストの「`error` が `X`」という旧版の表明は、07 の S2 で更新対象が増える（07 §3.2.1 の「12 箇所」に加わる）。これを避けるため、失敗本文を表明するテストは次の 2 つに分けて書く。(1) **状態コードと `error_code`**: 現状で GREEN になる特性化テスト。S1・S2 に影響されない。(2) **メッセージ値**: `errors[0]` の表明（07 の S-T0 の `assert_error_envelope` を使う）。07 の S1 の前に追加すると `errors` が無い経路は RED になる。この RED は 07 の S-T0 の RED と同じ原因なので、**07 の手順 3（Masters の S1）と同じ PR 列に置くか、その後に追加する**。旧キー `error` を表明するテストは作らない（07 §10 の 08 の行の選択肢「初めから `errors[0]` で書く」を採る）。T4・T6・T9・T10・T13 が該当する（6.3）。
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
| T4 | D-13 | `patch_masters_crop_with_stale_updated_at_returns_409` | 同上。`GET` で取得した `updated_at` を使って 1 回更新済み | 古い `updated_at` で再度 `PATCH` | 409。メッセージ値は `errors[0]` が `stale_record`（07 の C7。6.1 の (2)） |
| T5 | D-13 / D-05 | `put_masters_crop_is_alias_of_patch` | 同上 | 最新の `updated_at` で `PUT /crops/{id}` | 200 と更新後の name |
| T6 | D-03 / D-12 | `patch_masters_reference_crop_by_non_admin_returns_403` | 参照 crop（`seed_reference_crop_with_stage`）、非 admin セッション（`farmer_session_id`） | `PATCH /crops/{id}` | 403。メッセージ値は `errors[0]` が `crops.flash.no_permission`（6.1 の (2)）。ポリシー判定は `updated_at` の検査より先（`crop_update_interactor.rs:55-80`）のため `updated_at` は不要 |
| T7 | D-12 | `get_masters_crop_unknown_id_returns_expected_status` | ログイン済みユーザー | 存在しない id で `GET /crops/{id}` | **導出では 422**（`masters_crops.rs:352` と `shared/exceptions/mod.rs:6-7`）。実測して確定し、その値を表明する。D-12 で案 B（404 に修正）を選ぶ場合は 404 を表明して RED にする |
| T8 | D-12 | `delete_masters_crop_unknown_id_returns_422` | 同上 | 存在しない id で `DELETE /crops/{id}` | 422（`crop_destroy_interactor.rs:56-67`）。案 B を選ぶ場合は 404 で RED |
| T9 | D-06 | `post_masters_crop_stage_without_name_returns_400_invalid_parameters` | ユーザーの crop | `POST .../crop_stages` に `{"crop_stage":{"order":1}}` | 400。メッセージ値は `errors[0]` が `Invalid parameters`（6.1 の (2)） |
| T10 | D-06 | `patch_masters_crop_stage_with_empty_payload_returns_400` | 1 stage を持つ crop | `PATCH .../crop_stages/{id}` に `{"crop_stage":{}}` | 400。メッセージ値は `errors[0]` が `Invalid parameters`（6.1 の (2)） |
| T11 | D-07 | `post_masters_crop_setup_proposal_apply_invalid_returns_200_with_apply_mode` | ユーザーの crop、`thermal_requirement` を空にした提案 | `POST ...setup_proposal?mode=apply` | 200、`mode` が `apply`、`valid` が `false`、`errors[0]` に `path` と `message`。永続化されない（stage 一覧が空のまま） |
| T12 | D-07 | 既存 `post_masters_crop_setup_proposal_apply_persists_stages_and_blueprints`（2715）に追記 | 同上 | 有効な提案で `mode=apply` | 201 に加えて `mode` が `apply`、`normalized` が存在、`result.agricultural_task_ids` が長さ 1 の配列 |
| T13 | D-07 | `post_masters_crop_setup_proposal_invalid_mode_returns_422` | ユーザーの crop | `?mode=bogus` | 422。メッセージ値は `errors[0]` が `mode must be dry_run or apply`（6.1 の (2)）。セッションで呼ぶこと（API キーが read のみだと、`mode` が `apply` でも `dry_run` でもない POST は write 扱いで 403 になり得る: `masters_api_scope.rs:18-31` の読解。未実測） |
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

1. **確認事項の回収**（3.3）。回答が無い場合は推奨案で進める。D-12 が案 B になった場合は本課題から切り離して 10 に渡す。他文書が窓口の確認（03 の Q7、07 の Q2、10 の U16・P3・P14）は、各文書の回答を待って 0.3 のフェーズを進める。
2. **根拠の実測**: 6.3 の T7・T14 の導出値（crop show の 422、ラッパー body が 422）を、R4 で実測して確定する。未確定の値は `openapi.yaml` に書かない。
3. **契約テスト追加**（6.3）。個別 → 全体 → 遅延検知（6.4）。メッセージ値の表明（T4・T6・T9・T10・T13）は 07 の手順 3（Masters の S1）と同じ PR 列かその後（6.1）。
4. **`openapi.yaml` の修正**（4 章の順。フェーズ A: 0.3）。適用時点で 07 の S1 または S2 が本番にあれば、フェーズ B・D の形を同時に適用する（0.3）。
   1. `components`: `Error`（D-03・D-14。E1。4.14）、`responses`（`Forbidden`、`BadRequest`）、スキーマ（D-07・D-08・D-11・D-15）
   2. 全 operation の `responses`: `403`・`429`（D-03・D-04）
   3. D-01・D-02: 削除 204
   4. D-06: stage の 400 とリクエストスキーマ
   5. D-13・D-12: crop update の body と各 operation の 403/409/422/404
   6. D-07: setup_proposal のレスポンス
   7. D-05: `PUT` エイリアスの description
   8. D-09: グローバル `security`
   9. D-10: `info.description`（「Scope of this document」の段落のみ。冒頭のスコープ箇条書きは 03）
5. **後続フェーズ**（0.3）。**C**: 03 の V27 の DB 適用確認後に、03 が write operation の `security` と description を公開する（4.15。08 は適用しない）。**B**: 07 の S1 の本番反映と同時に `Error` を E2 にする（4.14）。**D**: 07 の P1〜P6 を満たし S2 と同時に `Error` を E3 にし、4.16 (3) の検査を実行する。B・D の PR は、07 の該当 PR（07 §7 の手順 6、14c）と同じ列に置く。
6. **検証**: YAML として構文が正しいこと、`$ref` がすべて解決できることを、ローカルで 1 回確認する。使い捨ての確認に留め、リポジトリにツールや設定は追加しない（5.2）。`docs/api/openapi.yaml` の記載を、2.2 の確定表と 1 行ずつ突き合わせる。
7. **参照元の同期は 03・04・07・09 に委譲**（2.4）。本課題では `getting-started.md`・snippet は変更しない（07 の O2 の `getting-started.md` の失敗本文の節と 429 の例は 03・07 が編集する）。ただし、`openapi.yaml` の変更と矛盾する記述が残るため、その事実を 03・04・07・09 の担当に引き継ぐ。
8. **PR 記載**: 各記載がどの R4 テストに支えられているかを対応表で示す。導出だけで実測していない項目があれば、その旨を明記する。

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
| R10 | 本書の表は 2026-09-29 時点の `master` に対するもの（0.1 以降の追記は 2026-10-07 のワーキングツリー）。実装が変わると乖離が再発する | 表の陳腐化 | 5 章の P6 で固定したテストが落ちれば気付ける。表そのものは PR 時点の再確認を要する |
| R11 | `openapi.yaml` は GitHub の master が公開面で、サーバーのデプロイと独立に公開される（03 §5.4.1.9）。`Error` を E2 / E3 にするフェーズ B・D を、07 の S1 / S2 より先に公開すると、契約が実装より先行して不正確になる | 外部スキルが `errors` だけを読み、`error` のみを返す失敗で本文を読み損ねる（B が S1 より先）。`error` を読む利用者が、D の公開後に実装が `error` を返している間は案内に従えない（D が S2 より先） | 0.3 のフェーズと条件を固定した。B・D は 07 の該当 PR と同じ列に置く |
| R12 | write operation の `security`（4.15）を 03 の V27 の DB 適用確認より先に公開すると、V15 以前のキーが書き込める状態で「write は session のみ」と書くことになる | 契約の不正確（03 §5.4.1.9 と同じ理由） | フェーズ C は 03 の公開と同時にする。08 は 4.15 を単独で適用しない（0.2） |
| R13 | 07 の §3.8・§3.5.4 O1 は旧キーとして `error` と `message` を挙げるが、本書は `Error` に `message` を載せない（4.14。Masters の公開 operation の失敗本文に最上位の `message` が無いことをコードで確認した） | 07 の最終状態の検査と 08 の `Error` に差が出る | 07 の改訂時に、`message` の扱いを Masters の公開 operation では不要とすることを確認する（第 10 章）。08 は 07 に合わせて `message` を載せる側には変えない（存在しないキーを契約に書かない） |
| R14 | 10 の U16（認可失敗の状態コード統一）と P14（閲覧範囲）、P3（admin）は未決。決まると 2.2 の確定表と 4.11・4.16 の一部が変わり得る | D-12 の案 B への切り替え、`showCrop` の 403 の範囲 | 0.1・4.11 に、変わる行を明記した。10 の決定後に同じ変更で更新する。それまでは description に主体（所有者・組織・admin）を書かない |
| R15 | 4.16 の最終状態の表は、3 文書（03 の Q7、07 の S2、10 の U16）の決定が前提で、一部は未回答。表は決定が確定するまで「現時点の推奨での最終形」にすぎない | 表の陳腐化 | 各行に出典と、変わる条件を付けた。フェーズ D の PR で再確認する |
| R16 | 03 の `apply_crop_setup` 削除（M-A）で `tools/agrr-mcp` の行番号がずれ、本書 2.3 が引く `file:line`（`agrr-client.mjs:23, 41, 48, 57`）が変わる | 根拠の `file:line` が古くなる | 2.3 に注記した。03 の実装後に更新する（03 §5.3.6 が同じ依頼を 07・08 に出している） |

---

## 9. 受け入れ条件

1. 4 章の変更が `docs/api/openapi.yaml` に適用され、YAML と `$ref` が有効である。
2. `openapi.yaml` の全 operation（20 本）に `401` / `403` / `429` が記載され、`Error` に `error_code`（自由文字列）があり、`errors` が文字列配列になっている（フェーズ A の E1）。フェーズ B 以降は、`errors` が必須（`minItems: 1`）で、`error` が `deprecated: true`（B）、削除済み（D）になっている（4.14、4.16）。
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
13. 03・04・07・09 に対して、`getting-started.md`・snippet との不整合（2.4）が引き継がれている。
14. 0.2 の責務境界のとおり、`openapi.yaml` の同じ箇所を 08 と他文書が二重に変更していない。write operation の `security` は 03 だけが書き（フェーズ C）、`info.description` は段落単位で分担している。
15. フェーズ B・D の `Error` の公開が、07 の S1・S2 の本番反映（と P1〜P6 の記録）と同時かそれより後である。フェーズ C が 03 の V27 の DB 適用確認より後である。
16. 説明文・例に「message `…`」の形で書かれ、`error:` のキー名が直書きされていない（4.14、4.16 (3) の検査 2）。
17. フェーズ D の後、4.16 (3) の検査 1〜6 を実施した記録がある。旧キー削除後の operation ごとの応答が 4.16 (2) と一致している。
18. 10 の縮小（D8）の前後で、`openapi.yaml` の operation の応答（ステータス）に変更が無い。description に所有者・組織・admin の語が無い（4.11）。

---

## 10. 関連課題との依存

`docs/spec-defects/` の 01〜11 と README の決定事項（第 1〜3 回）を読んだ範囲での接点である（改訂日: 2026-10-07）。**読んだ範囲:** 02・03・07・10 は、`openapi.yaml`・エラー契約・認可・`security` に触れる節（03 §0・§5.2・§10、07 §0・§2.7〜§2.8・§3・§4.2・§10、10 §0・§2.10・§3.1・§4・§5.9・§8.2・§9・§10、02 の OpenAPI への言及行）を読んだ。全文の精読ではない。01・04・05・06・09・11 は、08 または `openapi.yaml` に言及する行を検索して読んだだけである。他の文書は並行して更新されている可能性があり、下記の節番号・Q 番号は改訂時点のもの。

**依存の向きの要約:** 08 は、07 の契約（`Error` と旧キーの段階）と 03 の方針（`security`・read のみ）を `openapi.yaml` へ転記する後続側である。10 の認可の決定は、08 の記載（ステータスの意味）の前提になるが、現時点では 08 の記載を変えない。順序は A → C → B → D（0.3）。

| 番号 | 課題 | 本書との関係 | 順序・調整 |
| ---- | ---- | ------------ | ---------- |
| 01 | resource-limit-bypass | `POST /crops` の 422（作成上限超過を含む: `masters_crops.rs:338-343`）は本書の `createCrop` の 422 に含まれる。第 3 回決定「共有」（組織で枠を共有。01 の D-5）と案 A で、Masters の挙動は不変（01 §11 の 08 の行が同じ見立て）。01 の B1（件数 API）は、10 の P14 が (b)（閲覧も所有者のみ）になった場合だけ必要で、その場合は `openapi.yaml` に追加が要る（01 §3.6、10 §2.10.5）。plan-save 側の上限超過応答は `openapi.yaml` の対象外（plans 系は未掲載: D-10 (a)） | 01 の挙動が変わる場合のみ `createCrop` の 422 の説明を追随。P14 が (b) なら、B1 の API を D-10 の範囲に含めるかを 3.3 の確認事項 3 で判断 |
| 02 | contact-recaptcha（Turnstile 採用） | `contact_messages` は `openapi.yaml` に無く（`grep -c contact` が 0 件。02 §4 の API 契約の行）、Masters API でもない。02 は Turnstile トークンのワイヤ名（`cf-turnstile-response`、Q8）、201 / 422 / 429 / 503、`captcha_configured` を 08 へ渡すとし、「誰が載せるかは未確定」としている（02 §10 の 08 の行、Q17 (a)。02 の既定は「本課題では OpenAPI を追加しない」）。02 が引く旧版 08 の第 10 章の行（Masters と無関係・依存なし）は本改訂で書き換えた。**本書の回答:** D-10 (a)（subset 維持、推奨）なら **08 は contact を `openapi.yaml` に載せない**（Q17 (a) の 02 の既定と一致）。02 の契約は 02 と R4 が担い、公開文書が必要なら別の判断になる。07 の契約への読み替え: CAPTCHA 失敗は `{"errors": [...], "error_code": "captcha_failed"}`（422）、利用不可は `"captcha_unavailable"`（503）、429 は `errors: ["rate_limit"]`（07 §10 の 02 の行）。`Error` は `error_code` を自由文字列とするため、これらの値が増えても `Error` の変更は不要。D-10 (b) を選び contact を載せる場合は、`Error` を共用し、`error_code` の known values に 2 値を足す | 依存は 3.3 の確認事項 3 の回答次第。(a) なら 08 に作業なし。02 を先に実装する場合も 08 に影響しない |
| 03 | api-key-scope-docs | **`security` 上書き（Q7）、「API キーは read のみ」の方針と冒頭 description・`securitySchemes` の文言は 03 が正**（0.2）。08 は `Forbidden` と全 operation への `403`、D-09 のグローバル `security` への `sessionCookie` 追加を担当する。03 は「08 を先に入れてから `security` を適用」（03 §10）、公開は V27 の DB 適用確認後（03 §5.4.1.9）。V27 後の 403 の本文は 07 の段階に従う（`errors: ["forbidden"]` + `error_code: insufficient_scope`。S1 は `error` 併記、S2 で削除。07 §10 の 03 の行）。03 の `apply_crop_setup` 削除（M-A）で、本書 2.3 の「MCP が呼ぶのは 4 本」は 3 本になり、`agrr-client.mjs` の行番号がずれる（03 §5.3.6 の依頼。R16）。`getting-started.md` は 03・04・07 が編集し、08 は編集しない | 順序: 08 のフェーズ A → 03 の V27 → 03 の文書公開（フェーズ C）→ 07 の S1 の文書公開（フェーズ B）。03 の Q7 の回答（既定は案 B）を待つ。403 とスコープの説明文言は 03 と同じ表現（「API キーが操作に必要なスコープを持たない」）にそろえる |
| 04 | api-key-query-auth | クエリ認証は実装が無視して 401（`masters_auth.rs:44`、R4 3141）。`openapi.yaml` の `securitySchemes` にクエリ方式は無く本書は影響を受けない。`getting-started.md:30` の修正は 04。04 が `?api_key=` の 401 にヒント（`error_code` など）を足す場合は、`Unauthorized`（`openapi.yaml:422`）が `Error` を参照するため、`error_code` は自由文字列でスキーマ変更は不要で、known values への追記だけで足りる（04 §5.3） | 04 がクエリ認証を復活させる場合のみ `securitySchemes` を追加。ヒントを足す場合は 08 の known values を追随 |
| 05 | fail-closed-critical | `climate_data` と `entry_schedule/crops` は `openapi.yaml` に無い（05 §10）。05 は 503 / 422 / `error_key` の応答を 08 で記載するとしているが、D-10 (a) なら載せない。05 の失敗本文は 07 の契約（`errors` + `error_code`）に合わせる側で、08 に影響しない（07 §10 の 05 の行） | 依存は 3.3 の確認事項 3 の回答次第。(a) なら作業なし |
| 06 | fail-closed-suspected | `climate_data`・`entry_schedule`・`weather_reschedule` は `openapi.yaml` に無い（06 §9）。D の `masters_crops.rs:111`（`list_by_crop_id(id).unwrap_or_default()`）は、06 が「`internal_error()` に流す」と決めた（06 §3 の D）ため、本書の R8 の引き継ぎ先は 06 で確定。修正後、`showCrop` は stage 取得失敗時に 500 を返し得る。本書は 5xx を記載しない方針（4.14）で、500 を `showCrop` に足すかは、5xx の記載方針と一緒に決める（D-16 と同じく、今回は足さない） | 06 の実装後、`showCrop` の応答に 5xx を記載するかを 07 の 5xx の扱いと合わせて判断 |
| 07 | frontend-error-contract | **`Error` の契約と旧キーの段階は 07 が正**（0.2）。08 の D-03・D-14 は 07 §3.3 の契約で上書きされ、`Error` = `{errors（必須・文字列配列・1 件以上）, error_code（自由文字列）, field_errors}`、旧キー `error` は S1 で `deprecated`、S2 で削除（4.14、4.16）。08 の失敗本文の例は「message `…`」の形に直し、キー名を直書きしない（07 §10 の 08 の行 (3)）。メッセージ値の R4 表明は `errors[0]`（07 の S-T0 を使う。6.1）。setup_proposal の 200 の `errors: [{path, message}]` は結果ペイロードで 07 の C3 の例外 (i)。**確認依頼（07 の改訂時）:** 07 §3.8・§3.5.4 O1 が旧キーに挙げる `message` は、Masters の公開 operation の失敗本文に無い（4.14、R13）。07 §10 の 08 の行が前提としていた「08 は `error` 先頭の形で書かれている」状態は、本改訂（4.2、4.14）で解消した。2.2 に読み替えの注記を加え、T4・T6・T9・T10・T13 のメッセージ値の表明を `errors[0]` にした | フェーズ B は 07 の S1 と同時、D は S2 と同時（0.3）。07 §3.5.3 の P3 は 08 と 03 の文書公開を要求し、順序は 03 → 08（B）→ 07 の S1（07 §10 の 03 の行 (3)）。07 の S-T0 は 08 の機械検証（5.2 の 4）を担う |
| 09 | stale-design-docs | `setup_proposal-openapi-snippet.yaml` のレガシー扱いと、参照元（`tools/agrr-mcp/README.md:56`、`.cursor/skills/agrr-crop-setup/SKILL.md:33`）の付け替え、`llms.txt:10` の説明。snippet は旧 `Error` 形（401/404 のみ）のまま残ると、08 の最終形（4.16）と食い違う。`organizations` の定義が `openapi.yaml` に無い点（09 §9）は D-10 (a) の除外一覧に含まれる | 本書の `openapi.yaml` 修正後に、snippet を廃止または `openapi.yaml` への参照に置き換える。順序は本書 → 09 |
| 10 | authorization-consistency | **認可の可否（誰が編集・閲覧できるか）と、状態コード統一（U16）は 10 が正**（0.2）。第 3 回「縮小」は Farm / Crop の編集を所有者（と admin）のみにし、閲覧は P14（推奨 (a): 組織単位のまま）、Plan の admin は P3 が未決。縮小後も応答の写像は現行のまま（Farm / Crop は 403、stage・blueprint・setup_proposal は 404。10 §2.10.3、§5.9）なので、`openapi.yaml` の `403` / `404` の記載は変わらない（4.11、0.1）。D-12 の案 B（統一）は U16 が決まるまで選べず、案 A（現状記載）を維持。10 の U10（`openapi.yaml` の認可記述）は、組織・owner・admin の語が無いことを `rg` で確認して解消できる（本書 4.11）。10 §4 のドキュメント行が「更新不要の見込み」とする見立てと一致 | 10 が U16 を決めたら、同じ変更で `openapi.yaml`（D-12 の 4 行と 2.2・4.16 の表）を更新。P14 が (b) なら T6・T7 の given と `showCrop` の `403` の範囲を見直す（4.11）。description に主体（所有者・組織・admin）を書かない |
| 11 | low-priority-misc | D-05・D-09・D-10 のような重大度 Low の項目は、11 と分担せず本書で完結させる。11 は `public_plans` / `contact_messages` の `openapi.yaml` 記載が無いことを 08 の領域としている（11 §9）。11 の項目 3（問い合わせ成功応答の型の最終形 `id` / `status`）は、08 が contact を載せる場合の正とされる。D-10 (a) なら載せないため、08 に作業なし | 依存なし（D-10 (b) の場合のみ 11 の最終形を採る） |
