# 11. 低優先度の雑多な仕様不整合 — 対応計画

**種別:** 対応計画（本書はコードを変更しない。実装は別タスク）
**対象:** route-manifest のリダイレクト行 / 未使用の公開プラン農場サイズ API / 問い合わせ POST のレスポンス型 / i18n キー偏りの判断基準
**参照規約:** [`ARCHITECTURE.md`](../../ARCHITECTURE.md)、[`docs/architecture/LAYER-RULES.md`](../architecture/LAYER-RULES.md)、[`docs/design/UI-COMPOSITION-RULES.md`](../design/UI-COMPOSITION-RULES.md)、[`.cursor/skills/tdd-on-edit/SKILL.md`](../../.cursor/skills/tdd-on-edit/SKILL.md)、[`.cursor/skills/test-common/SKILL.md`](../../.cursor/skills/test-common/SKILL.md)、[`.cursor/rules/evidence-before-design-and-implementation.mdc`](../../.cursor/rules/evidence-before-design-and-implementation.mdc)、[`.cursor/rules/project-necessary-code-only.mdc`](../../.cursor/rules/project-necessary-code-only.mdc)、[`.cursor/skills/frontend-css-route-audit/SKILL.md`](../../.cursor/skills/frontend-css-route-audit/SKILL.md)

表記: 「確認済み」はコードを実際に読んだ事実（`file:line`）。「未確認」は読解のみ・未実行・入手不能な事実で、設計・実装の前提にしない。

---

## 1. 概要と重大度

| # | 項目 | 重大度 | 利用者影響 | 要旨 |
|---|------|--------|-----------|------|
| 1 | route-manifest に載るリダイレクト専用ルート `public-plans/select-farm-size` | 低（開発・CI 品質） | なし（E2E / capture のみ） | リダイレクト先 `/public-plans/new` に到達するため、URL 一致を要求する E2E 検証と噛み合わない（静的読解。実行は未確認） |
| 2 | フロント未使用の `GET /api/v1/public_plans/farm_sizes` と関連 i18n | 低（デッドコード） | なし | サイズ選択ステップは意図的に廃止済み。API・i18n・E2E 設定に残骸がある |
| 3 | 問い合わせ POST 成功レスポンスの型不整合 | 低（型の嘘） | 現状なし | サーバーは `id` / `status` のみ返すが、フロントは `email` / `message` / `created_at` / `sent_at` を読む型で受ける |
| 4 | 公開プラン API が認証なしでデータを返す点 | 本書の対象外 | — | [課題 10](10-authorization-consistency.md) 項目 4 で扱う。本書は参照のみ |
| 5 | i18n キー偏り（ja のみ 104 / en のみ 80）の実態と判断基準 | 低（衛生） | 現状なし | 偏りキーはすべてフロントから未参照。削除・保持の基準と代表例のみ提示。全件削除は範囲外 |

全項目が低優先度で、項目 1・2 は同じ「サイズ選択ステップ廃止の後始末」であり、同一変更単位で扱うのが自然。項目 3 は独立。項目 5 は判断基準の文書化のみ。

---

## 2. 項目別の現状（確認済み事実）

### 2.1 項目 1: route-manifest とリダイレクト専用ルート

- ルート定義は `path: 'public-plans/select-farm-size'` が `redirectTo: '/public-plans/new'` + `pathMatch: 'full'`（`frontend/src/app/routes/public-plans.routes.ts:13-17`）。コンポーネントは持たない。
- manifest の該当行は `frontend/e2e/route-manifest.json:119-124`（`pattern` / `url: "/public-plans/select-farm-size"` / `requiresAuth: false` / `source: "public-plans.routes.ts"`）。
- **manifest は手書きではなく生成物。** `npm run e2e:manifest` → `frontend/scripts/generate-e2e-route-manifest.mjs` が `src/app/routes/*.routes.ts` を解析して 3 ファイルを同時に書く（`route-manifest.json`、`e2e/agent-review/route-to-png.md`、`e2e/host-selector-by-pattern.generated.ts`。`generate-e2e-route-manifest.mjs:22-31`）。`frontend/package.json:40-41` に `e2e:manifest` / `e2e:manifest:check`。CI は `npm run e2e:manifest:check` を実行（`.github/workflows/frontend-test.yml:36-37`）、生成器の単体テストは `node --test scripts/generate-e2e-route-manifest.test.mjs`（同 `:90`）。
- 生成器はリダイレクトを意図的に拾う。`parseRouteBlock` は `redirectTo` を含むブロックも 1 行として返す（`generate-e2e-route-manifest-lib.mjs:92-102`）。除外は `E2E_EXCLUDE_MANIFEST_PATTERNS = new Set(['auth/login', 'dashboard'])` の固定リストのみ（`:7`、適用は `:180` と `:253`）。この 2 件は `core.routes.ts:11-12` のリダイレクト専用ルートで、コメントは「SPA 内リダイレクトのみ」（`:6`）。**リダイレクト専用ルートを manifest から除外する先例が既にある。** `select-farm-size` だけがリストに無い。
- 代わりに `HOST_SELECTOR_OVERRIDES` に `'public-plans/select-farm-size': 'app-public-plan-create'` を置いて manifest に残している（`:13-18`、特に `:15`。コメントは「コンポーネントを持たないリダイレクト専用 pattern のホストセレクタ上書き」）。この上書きを固定するテストがある（`generate-e2e-route-manifest.test.mjs:82-85`）。
- `select-farm-size` を名指しする他の箇所（すべて確認済み）:
  - `frontend/e2e/host-selector-by-pattern.generated.ts:65`（生成物）
  - `frontend/e2e/agent-review/route-to-png.md:33`（生成物。PNG 3 言語分の対応行）
  - `frontend/e2e/smoke/layout-contract-bindings.mjs:29`（`'wizard-step'`）
  - `frontend/e2e/smoke/layout-conformance-bindings.mjs:74`（`'L0'`）
  - `frontend/e2e/smoke/a11y-allowlist.json:58` 以降（`landmark-unique` / `aria-allowed-attr` / `aria-required-children` の 3 件）
- 歴史: リダイレクト化はコミット `5f97b1c11`（"Simplify public plan flow (default 300㎡ farm size)"）。同コミットで `route-validity.ts` の `PUBLIC_PLAN_REDIRECT_TO_NEW` から `select-farm-size` を外し、ホストセレクタを `app-public-plan-select-farm-size` から `app-public-plan-create` に置換した。`PUBLIC_PLAN_REDIRECT_TO_NEW` 自体は現在どこにも存在しない（`grep -rn` 0 件）。
- E2E / capture への影響（**静的読解による推論。実行は未確認**）:
  - 共通の妥当性検証は「現在の pathname が `expectedPathname` と一致するまでポーリング」する（`frontend/e2e/route-validity.ts` の `assertPageValidity` 末尾の `.poll(...).toBe(want)`、`:95-98`）。`want` は manifest の `url` から得る（`route-validity-lib.mjs:2-6, 13-17`）。`select-farm-size` は `/public-plans/select-farm-size` を期待するが、ルーターは `/public-plans/new` へ遷移するため一致しないはず。
  - 同じ検証が `e2e/smoke/route-smoke.spec.ts:77-79`、`layout-smoke.spec.ts:99-100`、`locale-i18n-smoke.spec.ts:90-92`、`e2e/visual/route-manifest-visual.spec.ts:84-93`（`assertCapturePageValidity` 経由）で使われる。`a11y-smoke.spec.ts:88-91` は `waitForURL(pathname === expect || startsWith(expect))` で同様に不一致。
  - `select-farm-size` 専用のスキップ・許容分岐は見当たらない（`route-validity.ts` に `work` / `onboarding` / `entry-schedule` のみ特別扱い）。
  - 上記 smoke / capture は `E2E_CAPTURE_DEV_SESSION=1` と Rails development を要する（`frontend/package.json:28-37`、`.cursor/skills/frontend-css-route-audit/SKILL.md`）。CI の `frontend-test.yml` が実行するのは manifest 系の静的検査（`test:route-manifest-coverage`、`e2e:manifest:check`、`e2e:layout-contract:check:enforce`）で、実ブラウザの smoke ではないと読める。**そのため現状 CI が緑でも上記の不一致は検出されていない可能性がある（未確認）。**
  - manifest 静的検査への影響: 行を除去すると `verify-layout-contract-coverage-lib.mjs` の `extraBindings`（manifest に無い binding）が非空になり `ok: false`（`checkLayoutContractCoverage`、`e2e:layout-contract:check:enforce` が RED）。`layout-conformance-bindings.test.mjs:19-25` も `extraConformance` を検出する。つまり除去時は binding 2 箇所の同時削除が必須。
  - `a11y-allowlist.json` の孤立キーを検出するコードは見当たらない（`a11y-smoke-helpers.ts:17` は読み込みのみ）。孤立しても静的検査は落ちないが、残骸になる。
  - `verify-capture-complete.mjs` は manifest の全 pattern × 3 言語の PNG 存在を検証する（`:24-36`）ため、manifest から外せば PNG 期待数は 66 パターン中 1 つ減る（現在 66 行: `python3` で `routes` を数えた結果）。
- リダイレクト先の到達性: `/public-plans/new` は独立に manifest に載っている（同 manifest の `public-plans/new`）。よって `select-farm-size` の PNG は `public-plans/new` の重複になる見込み（PNG 内容は未確認）。
- リダイレクト自体を固定する Angular spec は無い（`select-farm-size` を含む `src/` の参照は `public-plans.routes.ts:14` のみ）。対照的に `/dashboard` は `core.routes.spec.ts:5-13` で固定されている。
- リポジトリ内に `/public-plans/select-farm-size` へのリンク・prerender 登録は無い（`git grep`。`public/` はビルド成果物の追跡ファイルで対象外）。外部ブックマーク・検索インデックスの有無は未確認。

### 2.2 項目 2: `GET /api/v1/public_plans/farm_sizes` の未使用と農場サイズ固定

サーバー側（確認済み）:

- ルート登録: `crates/agrr-server/src/public_plans.rs:59`（`.route("/api/v1/public_plans/farm_sizes", get(wizard_farm_sizes))`）。ハンドラ `wizard_farm_sizes`（`:271-273`）は interactor を経由せず `farm_size_catalog_json()`（`:196-208`）を返す。応答の `name` / `description` は翻訳キー文字列（`public_plans.farm_sizes.{id}.name` 等、`:203-204`）。
- 元データは `FarmSizeCatalog`（`crates/agrr-domain/src/public_plan/catalog/farm_size_catalog.rs:13-26`）: `home_garden`=30㎡、`community_garden`=50㎡、`rental_farm`=300㎡。`all()`（`:32-34`）を使うのは `farm_size_catalog_json`（`public_plans.rs:197`）とドメインテスト `all_returns_three_farm_sizes`（`crates/agrr-domain/test/public_plan/catalog_farm_size_catalog_test.rs:6-11`）のみ（`git grep "FarmSizeCatalog::all"`）。
- アーキテクチャガードで R7 の例外扱い: `scripts/run-architecture-guard-lib.mjs:34-41` の `R7_EXEMPT_HANDLERS` に `'wizard_farm_sizes'`（`:40`）。interactor を持たないハンドラ例外はこの API の存在に依存している。
- **サーバーの `POST /api/v1/public_plans/plans` は `farm_size_id` を必須とし、同じカタログを使う。** `CreatePlanBody.farm_size_id: String`（`public_plans.rs:153`）→ `PublicPlanCreateInput::new(body.farm_id, body.farm_size_id, ...)`（`:527-532` 付近）→ interactor が `gateway.find_by_farm_size_id` → `FarmSizeCatalog::find_by_id`（`crates/agrr-domain/src/public_plan/interactors/public_plan_create_interactor.rs:71-82`、`crates/agrr-adapters-sqlite/src/public_plan/public_plan_gateway.rs:45-47`）。`find_by_id` は「数値文字列なら `area_sqm` 一致、なければ id 文字列一致」（`farm_size_catalog.rs:37-50`）。
- R4 契約テストに `farm_sizes` を扱うものは無い（`crates/agrr-r4-contract` を `git grep` 0 件）。`docs/api/openapi.yaml` に `public_plans` の記載も無い（`grep` 0 件。課題 08 の領域）。

フロント側（確認済み）:

- API 呼び出しは削除済み。`getFarmSizes` はリポジトリ内に存在しない（`grep` 0 件）。コミット `c767ce966` が `public-plan-api.gateway.ts` から `getFarmSizes()` と対応 spec を削除（コミットメッセージ: "default public-plan farm size in the store after removing the size step"）。ステップ削除自体は `5f97b1c11`（"Simplify public plan flow (default 300㎡ farm size)"）。**両コミットのメッセージから、ウィザードのサイズ選択ステップ廃止は意図的な簡素化である。**
- 固定値: `DEFAULT_PUBLIC_PLAN_FARM_SIZE = { id: '300', area_sqm: 300, name: '300㎡', description: '' }`（`frontend/src/app/domain/public-plans/default-public-plan-farm-size.ts:4-9`。コメントに「API の farm_size_id として "300" を送る」）。
- 使用箇所: `PublicPlanStore.setFarm` が農場選択時に `farmSize: DEFAULT_PUBLIC_PLAN_FARM_SIZE` を設定（`frontend/src/app/services/public-plans/public-plan-store.service.ts:54-59`）、`PublicPlanSelectCropComponent.createPlan` が `state.farmSize?.id ?? DEFAULT_PUBLIC_PLAN_FARM_SIZE.id` を送信（`public-plan-select-crop.component.ts:262-263`）→ `PublicPlanApiGateway.createPlan` が `farm_size_id` を POST（`public-plan-api.gateway.ts:37`）。
- **結合点:** フロントの `"300"` はサーバーカタログの `area_sqm == 300`（= `rental_farm`）に暗黙依存する。カタログの 300 を変更・削除するとプラン作成が `Invalid farm size`（`public_plan_create_interactor.rs:79`）で失敗するが、この依存を固定するテストはフロント・サーバーいずれにも見当たらない（未確認: 全テストの網羅は未実施）。
- `FarmSizeOption` 型（`domain/public-plans/farm-size-option.ts`）は `PublicPlanState.farmSize` の型として残っており、削除対象ではない。
- 農場サイズ選択コンポーネントのファイルは存在しない（`git ls-files | grep farm-size` はドメインの 2 ファイルのみ）。

i18n（確認済み）:

| キー | ja.json | en.json | in.json | 参照 |
|------|---------|---------|---------|------|
| `public_plans.errors.select_farm_size` | `:1879` | `:992` | `:1413` | フロント `src` 参照なし |
| `public_plans.errors.invalid_farm_size` | `:1880` | なし | なし | 参照なし（サーバーは英語固定文字列 `"Invalid farm size"` を返す: `public_plan_create_interactor.rs:79`） |
| `public_plans.farm_sizes.*`（3 サイズ × name/description） | `:1901` | `:1015` | `:1436` | フロントからは参照なし。サーバーが `farm_size_catalog_json` で**キー文字列として**返すのみ（`public_plans.rs:203-204`） |

- Rails 側 YAML にも `farm_sizes` がある（`config/locales/views/public_plans.{ja,us,in}.yml:15`）。参照元の Rails ビューは `git grep` で見つからない。サーバーは `config/locales/**/*.yml` を `LocaleCatalog` として読み込む（`crates/agrr-server/src/locale_catalog.rs:1`）が、`farm_sizes` を引く呼び出しは確認できていない（未確認）。
- 外部利用者の有無: リポジトリ内の利用者は無いが、公開・認証なしのエンドポイントであり、本番アクセスログは未確認（`gcloud` で確認可能だが本書作成時は未実施）。

### 2.3 項目 3: 問い合わせ POST のレスポンス型不整合

サーバー（確認済み）:

- 成功レスポンスは 201 で `{ "id": ..., "status": ... }` のみ（`crates/agrr-server/src/contact_messages.rs:85-94`）。
- R4 契約もこれを固定: `post_contact_message_creates_queued_record` は `status == "queued"` と `id` の存在だけを検証（`crates/agrr-r4-contract/tests/contracts.rs:4509-4530`）。他フィールドは契約外。
- 失敗系は別形状: 429 `{"error":"rate_limit"}`、422 `{"error": ...}` / `{"errors": [...]}`、503 `{"error": ...}`（`contact_messages.rs:58-79`）。

フロント（確認済み）:

- `HttpContactGateway.postMessage` は `post<any>` で受け、`email` / `message` / `created_at` を必須として読み、`name` / `subject` / `source` / `sent_at` は `?? null` で補完して `ContactMessageRecord` を組み立てる（`frontend/src/app/adapters/contact/http-contact-gateway.service.ts:16-33`、特に `:19-29`）。
- `ContactMessageRecord`（`frontend/src/app/domain/contact/contact-message.model.ts:11-21`）は `email: string` / `message: string` / `created_at: string` を必須と宣言。実レスポンスでは `undefined`（型の嘘）。`name` / `subject` / `source` / `sent_at` は `null` になる。
- spec は実サーバーに存在しないフィールドを持つモックを使う（`http-contact-gateway.service.spec.ts:28-38, 50-57`）ため、不整合を検出できない。
- 利用側: `SendContactMessageUseCase` が使うのは `record.status`（`'failed'` 分岐と DTO 変換）と `record.id`（`send-contact-message.usecase.ts:32, 40-46`）。`toSuccessDto` は `created_at` / `sent_at` を DTO に詰める（`:40-46`、`SendContactMessageSuccessDto` は `send-contact-message.dtos.ts:5-10`）が、`ContactFormPresenter.onSuccess` は DTO を使わない（引数名 `_dto`、`contact-form.presenter.ts:28-37`）。したがって現状は実害なし（`created_at` は実行時 `undefined`）。
- `status === 'failed'` 分岐（`send-contact-message.usecase.ts:32`）は、サーバーが失敗を 4xx/5xx で返す設計（`failure_response`）なので 201 応答では通常到達しないはず。ただしドメイン側に 201 で `failed` を返す経路が無いことの網羅確認は未実施（未確認）。
- 参考（課題 02 の領域）: フロントの問い合わせ関連ファイルに `recaptcha` は現れない（`frontend/src/app/{domain,usecase}/contact`、`components/contact-form` を `grep`、0 件）。ペイロード型 `ContactMessagePayload`（`contact-message.model.ts:1-7`）は課題 02 側で変更される可能性が高く、同ファイルの編集競合に注意（§9）。

### 2.4 項目 4: 公開プラン API の無認証応答

本書では扱わない。[課題 10](10-authorization-consistency.md) 項目 4 を参照。`GET /api/v1/public_plans/farm_sizes` のハンドラは認証情報を引数に取らない（`public_plans.rs:271`）が、他の公開プラン API の認証要否は本書では未確認。課題 10 の結論が出るまで、本書の項目 2 で認証方針を変更しない。

### 2.5 項目 5: i18n キー偏りの実態（軽い集計）

集計方法: `frontend/src/assets/i18n/{ja,en,in}.json` をリーフキーに平坦化して差集合を取り、`frontend/src`（`*.spec.ts` を除く `.ts` / `.html` / `.mjs`）の文字列リテラルとの完全一致、および `'prefix.' + x` / `` `prefix.${x}` `` 形式の動的キー接頭辞との前方一致で参照を判定。`spec` / `e2e` / `scripts` と `crates`（`git ls-files crates` の全文）も別途照合。**静的な文字列一致のみで、他の方式で組み立てるキーやサーバー応答由来のキーは取りこぼしうる（未確認）。**

キー数（リーフ）:

| ロケール | キー数 |
|---------|--------|
| ja | 3069 |
| en | 3045 |
| in | 2838 |

差集合: ja のみ（en に無い）104、en のみ（ja に無い）80（依頼文の「104 / 80 程度」と一致）。`in` との差は ja−in 343、in−ja 112、en−in 246、in−en 39。**依頼は ja/en の偏りだが、`in`（ヒンディー語・インド向け）も第 3 ロケールとして存在する**（`initial-i18n-bootstrap.ts:35` の `addLangs(['ja','en','in'])`）。

判定結果:

- ja のみ 104 件・en のみ 80 件は、**フロント `src`（spec 除く）・spec・e2e・scripts のいずれからも参照されていない**（動的接頭辞一致も 0 件）。
- ただし `crates` に同名キー文字列が現れるものが 9 件ある（ja のみ 4、en のみ 5）:
  - ja のみ: `api.messages.fertilizes.updated_by_ai`（`fertilize_ai_update_interactor.rs`）、`crops.flash.cannot_delete_in_use.other` / `.plan`（`crop_destroy_interactor.rs`）、`models.cultivation_plan.phases.weather_data_fetched`（`cultivation_plan_phase_policy.rs`）
  - en のみ: `api.errors.no_cultivation_period`（`field_cultivation_climate_data_interactor.rs:232`）、`api.errors.pests.fetch_failed` / `.invalid_affected_crops` / `.invalid_payload` / `.name_required`（`pest_ai_*` 系）
  - サーバーには `PassthroughTranslator`（例: `masters_pests.rs:3, 140`）を注入する経路と、`config/locales/**/*.yml` を読む `LocaleCatalog`（`locale_catalog.rs:24-35`）で解決する経路がある。キーがクライアントに届くかは経路ごとに異なり、**この 9 件がフロントで翻訳されうるかは未確認**。
- 残り（ja のみ 100 / en のみ 75）は参照ゼロ。内訳の上位グループ:
  - ja のみ 100: `public_plans.show.*` 29、`fields.edit.*` 9、`plans.show.*` 9、`api.messages.*` 7、`fields.show.*` 7、`farms.edit.*` 6、`farms.new.*` 6、`controllers.plans.*` 4、`farms.flash.*` 4、`public_plans.results.*` 4 ほか
  - en のみ 75: `plans.optimizing.*` 38、`public_plans.results.*`（`detail_temp` / `info` / `stages`）28、`api.errors.*` 4 ほか（サーバー参照の 5 件を除く）
- 実害: 参照ゼロなので画面への影響は現状なし。仮に参照されると、既定言語は `ja`（`initial-i18n-bootstrap.ts:36` の `setDefaultLang('ja')`）のため、en / in で欠けるキーは ja 文言に落ち、ja で欠けるキー（en のみ）は生キー表示になる（ngx-translate の標準挙動としての理解。`MissingTranslationHandler` のカスタム実装は見当たらない。実機確認は未実施）。
- 参考（誤検知を含む粗い数値）: ja の全 3069 キーのうち、フロント本体（spec 除く）で同じ静的判定により参照ゼロのものは約 1450 件（うち spec / e2e のみが参照するもの 157 件を含む）、そのうち `crates` にも現れないものは約 1295 件。動的組み立て・サーバー由来・Rails YAML 由来の取りこぼしが大きく、**この数値は削除根拠に使えない**。
- 補足: `public-plans-select-farm-locale.spec.ts` のようにキー存在をテストで固定しているカタログがある（`frontend/src/app/core/i18n/*.catalog.spec.ts` など多数）。キー削除時はこれらの spec を先に確認する。

### 2.6 未使用 API の扱い（項目 5 の補足）

サーバールート（`crates/agrr-server/src` の `.route(` 119 件）のうち、フロントの `/api/v1/...` リテラルに現れないものを粗く洗った結果、大半は次の系統でフロント未使用が正常:

- `/api/v1/masters/*` — API キー利用の外部 API（`docs/api/getting-started.md:38-45` にスコープ `masters:read` / `masters:write` とレート制限の記載）
- `/api/v1/backdoor/*`、`/api/v1/internal/*`、`/health`、`/up`、`/api/v1/ready` — 運用系
- `/auth/*`、`/cable` — ブラウザ遷移・WebSocket で、`/api/v1` リテラルとして現れない
- `/api/v1/{crops,fertilizes,pests}/ai_*` — 内蔵 AI 廃止方針（`docs/api/builtin-generation-sunset.md`）下で `builtin_generation_deprecated_*` を返す（`ai_api.rs:4-6`）

この粗い洗い出しは相対パスの組み立て（`ApiService` のベース URL + 相対パス）を辿れていないため、「フロント未使用」の断定には不十分（未確認）。`public_plans/farm_sizes` は個別に確認して未使用と断定できた唯一の公開ウィザード API。

---

## 3. 項目別の選択肢と推奨（ユーザー確認が必要な点）

### 3.1 項目 1: manifest のリダイレクト行

| 案 | 内容 | 評価 |
|----|------|------|
| **A（推奨）** | `E2E_EXCLUDE_MANIFEST_PATTERNS` に `public-plans/select-farm-size` を追加（`auth/login`・`dashboard` と同じ先例）。`HOST_SELECTOR_OVERRIDES` の該当上書きを削除。`layout-contract-bindings.mjs` / `layout-conformance-bindings.mjs` / `a11y-allowlist.json` の該当エントリを削除。`npm run e2e:manifest` で 3 生成物を再生成。再発防止として「コンポーネントを持たない（リダイレクト専用）ルートは manifest に載らない」を検査する単体テストを追加 | 最小差分。先例に整合。E2E の URL 一致検証との不整合が解消 |
| B | 生成器を一般化し `redirectTo` 行を一律スキップ（`parseRouteBlock` `:92-102` を変更し、`E2E_EXCLUDE` 固定リストと `HOST_SELECTOR_OVERRIDES` のリダイレクト用途を廃止） | 再発防止は構造的だが、生成器の設計変更で差分が大きい。現時点のリダイレクト専用ルートは 3 件のみで、A + ガードテストでも同じ再発防止が得られる |
| C | manifest に残し、検証側で「リダイレクト先 pathname を期待」する分岐を追加（`route-validity.ts` 等に例外） | `public-plans/new` と重複する PNG を 3 言語分維持し続ける。検証コードの特殊分岐が増える。非推奨 |

リダイレクト自体（`public-plans.routes.ts:13-17`）の扱い:

| 案 | 評価 |
|----|------|
| **保持（推奨）** | 旧 URL のブックマーク・外部リンクを `/public-plans/new` に救う。`core.routes.spec.ts` と同様の spec でリダイレクトを固定する（現在は固定テストなし） |
| 削除 | `project-necessary-code-only` に最も忠実だが、旧 URL が `**` の 404 になる。外部リンクの有無は未確認 |

**ユーザー確認事項:** (a) 案 A と B のどちらか（推奨 A）。(b) リダイレクトを保持するか（推奨 保持）。

### 3.2 項目 2: farm_sizes API と i18n

前提（確認済み）: サイズ選択ステップの廃止は意図的（`5f97b1c11` / `c767ce966`）。`POST /public_plans/plans` の `farm_size_id` とカタログは現役で保持が必要。

| 案 | 内容 | 評価 |
|----|------|------|
| A | 現状維持（API・i18n を残す） | 未使用コードが残る。契約テストも無く（`crates/agrr-r4-contract` に 0 件）、仕様として保証されていない状態が続く。`project-necessary-code-only` に反する |
| **B（推奨）** | `GET /api/v1/public_plans/farm_sizes` を削除。`farm_size_catalog_json` / `wizard_farm_sizes` / `FarmSizeCatalog::all()` とそのテスト、`R7_EXEMPT_HANDLERS` の `wizard_farm_sizes`、i18n `public_plans.farm_sizes.*` / `public_plans.errors.select_farm_size` / `public_plans.errors.invalid_farm_size`（ja/en/in と Rails YAML `farm_sizes`）を削除。`FarmSizeCatalog::find_by_id`、`POST` の `farm_size_id`、フロントの `DEFAULT_PUBLIC_PLAN_FARM_SIZE` は保持 | 廃止の後始末として完結。R7 例外が 1 件減る。削除後の当該パスは `fallback::api_not_migrated`（501）になる（`fallback.rs:11-18`、`lib.rs:183`） |
| B' | B と同じだが、削除ではなく 410 Gone で返す（先例: `masters_crop_agricultural_tasks.rs:25-33` の `gone`） | 外部利用者が確認された場合のみ。501 `api_not_migrated`（「未実装」の意味）より廃止の意図が明確。ただしコードが残る |
| C | サイズ選択 UI を復活 | 製品判断。UI 復活には `UI-COMPOSITION-RULES`（ウィザード: Funnel Shell + wizard progress、`check:ui-composition` の禁止パターン 3・4）に沿った再実装が必要で、廃止コミットの意図に反する。本書の範囲外 |

**ユーザー確認事項:** (a) B（削除）か B'（410 Gone）か。判断材料は本番アクセスログでの外部利用有無（未確認。`gcloud` で確認可）。(b) `DEFAULT_PUBLIC_PLAN_FARM_SIZE`（`"300"`）とサーバーカタログの暗黙結合を、今回は保持のまま許容するか。将来の解消案として `farm_size_id` 自体を API から外してサーバー既定にする選択肢があるが、API 契約変更を伴うため本書では扱わない。

### 3.3 項目 3: 問い合わせレスポンス型

| 案 | 内容 | 評価 |
|----|------|------|
| **A（推奨）** | フロントの型をサーバー契約（`id` / `status`）に合わせる。ゲートウェイの戻り型を `{ id: number; status: ContactMessageStatus }` 相当に狭め、`SendContactMessageSuccessDto` から `created_at` / `sent_at` を除く。spec のモックを実レスポンス形状に直す | サーバー契約は R4 で既に固定済み（`contracts.rs:4509-4530`）で、フロントが未使用のフィールドを捏造する必要がない。個人情報（`email` / `message`）をレスポンスに載せ直さずに済む |
| B | サーバーが `email` / `message` / `created_at` / `sent_at` も返す | R4 契約と OpenAPI（課題 08）の拡張が必要。フロントは使っていないので不要な契約追加。入力内容のエコーバックも増える。非推奨 |

命名の確認事項: 型 `ContactMessageRecord` は「完全なレコード」を示唆する。狭めた後の名前を `ContactMessageRecord` のまま残すか、別名（例: 受付結果を表す名前）にするかは `implementation-consistency-with-existing` に従い既存の命名を確認して決める。**ユーザー確認事項:** 案 A の採用可否と型名。

### 3.4 項目 5: 判断基準（削除 / 保持）

提案する基準（キー単位）:

1. **削除候補:** 全ロケール横断で、フロント `src`（spec 除く）・`crates`・`config/locales` から参照が無く、動的キー接頭辞にも該当しない。かつ用途となる機能が廃止済みと確認できる（コミット履歴や §2.2 のような根拠がある）。
2. **保持（補完対象）:** `crates` にキー文字列が現れる（サーバーが返すキー）。この場合は削除ではなく、欠落ロケールへの補完（ja / en / in を揃える）を検討する。
3. **保持（動的）:** `plans.learn.*`、`work.variance.status.*` 等、動的接頭辞で組み立てられるグループ（§2.5 の集計では 30 個の接頭辞）。個別キーの参照ゼロ判定は使えない。
4. **保持（外部由来）:** Rails YAML / API エラー翻訳（`activerecord.errors.*` など）は `resolve-activerecord-api-error-i18n-key` など別経路で解決されうる（未確認）。経路を特定するまで削除しない。
5. **削除の実施単位:** 機能単位（例: `public_plans.show.*` 29 件のように接頭辞ごと）。ロケール間の偏りだけを理由に 1 キーずつ削らない。削除前に対応する `*.catalog.spec.ts` を確認する。

代表例:

| 区分 | 例 | 判断 |
|------|----|------|
| 削除候補（機能廃止済み、参照ゼロ） | `public_plans.farm_sizes.*`、`public_plans.errors.select_farm_size`、`public_plans.errors.invalid_farm_size`（項目 2 と同一変更で） | 項目 2 案 B に含める |
| 削除候補（参照ゼロ、機能単位） | ja のみ `public_plans.show.*`（29 件）、`fields.edit.form.*` / `fields.show.*` | 廃止画面の確認後に機能単位で別タスク |
| 削除候補（参照ゼロ、en のみ） | `plans.optimizing.*`（38 件）、`public_plans.results.detail_temp.*` | 同上 |
| 保持・補完 | `api.errors.no_cultivation_period`（en のみ、サーバー参照あり） | ja / in への補完を検討 |
| 保持・補完 | `crops.flash.cannot_delete_in_use.plan`（ja のみ、`crop_destroy_interactor.rs` 参照） | en / in への補完を検討 |

---

## 4. 対応方針（層ごと）

`LAYER-RULES` の依存方向（`components → usecase → domain`、HTTP は adapters）と R7・R9・R10 を前提にする。本計画は新しい振る舞いを追加せず、既存契約の整理と削除が中心。

### 4.1 フロントエンド（`frontend/`）

- **domain** (`src/app/domain/contact/contact-message.model.ts`): 項目 3 案 A で `ContactMessageRecord` を契約形状に合わせる（`id` / `status`）。`ContactMessageStatus`・`validatePayload` 等は変更しない。
- **usecase** (`src/app/usecase/contact/`): `contact-gateway.ts` の戻り型、`send-contact-message.dtos.ts` の `SendContactMessageSuccessDto`（`created_at` / `sent_at` 削除）、`send-contact-message.usecase.ts` の `toSuccessDto` を同期。`'failed'` 分岐の要否は §7 未確定事項。
- **adapters** (`src/app/adapters/contact/http-contact-gateway.service.ts`): `post<any>` をやめ、実レスポンス型で受ける。捏造していたフィールドの補完（`?? null`）を削除。
- **components:** 変更なし（`ContactFormPresenter.onSuccess` は DTO のフィールドを使わない: `contact-form.presenter.ts:28`）。ただし presenter の spec の DTO 生成（`contact-form.presenter.spec.ts:49-54`）は新形状に合わせる。
- **routes** (`src/app/routes/public-plans.routes.ts`): 変更なし（リダイレクト保持の場合）。固定用の spec を追加。
- **i18n** (`src/assets/i18n/{ja,en,in}.json`): 項目 2 案 B に含まれるキーのみ削除。それ以外の偏りキーは本計画で削除しない。
- **e2e / scripts:** 項目 1 案 A の変更を集約（§6）。

### 4.2 バックエンド（`crates/`）

- **agrr-server (edge):** `public_plans.rs` から `wizard_farm_sizes` とルート登録（`:59`）、`farm_size_catalog_json`（`:196-208`）、不要になる `FarmSizeCatalog` import（`:31`）を削除（項目 2 案 B）。`POST` ハンドラ・`CreatePlanBody` は変更しない。
- **agrr-domain:** `FarmSizeCatalog::all()` と `all_returns_three_farm_sizes` を削除（利用者が無くなるため）。`find_by_id` / `FarmSizeRecord` / interactor は変更しない。
- **agrr-adapters-\*:** 変更なし。
- **contract:** 項目 2 の削除を R4 契約で固定（RED → GREEN、§5.2）。項目 3 の R4 契約は既存のまま（案 A ではサーバー変更なし）。
- **R10（実装順）:** 今回は新ポートの追加が無いため対象外。削除は handler → domain の順（利用者側から先に消し、コンパイラで未使用を検出）。

### 4.3 ドキュメント・設定・ガード

- `scripts/run-architecture-guard-lib.mjs:40` の `'wizard_farm_sizes'` を削除（項目 2 案 B と同一変更）。
- `docs/api/openapi.yaml` は本計画で変更しない（`public_plans` は現状未記載。課題 08 で扱う）。
- `docs/README.md` への索引追記は本書の依頼範囲外（`docs/spec-defects/` の索引は取りまとめ側で判断）。

---

## 5. TDD / 検証計画

`tdd-on-edit` に従い、実装前に失敗テスト（RED）を書き、`test-common` の経路で RED を確認する。**テストは `test-common` のスクリプトのみ**（`rails-testing-workflow.mdc`）。テスト出力は `./tmp/{UUID}.log` にリダイレクトして grep する（`AGENTS.md`）。

### 5.1 項目 1（manifest）

**RED の前に一度、現状の不整合を実行して確認する**（根拠ゲート: §2.1 は静的読解のため）。`E2E_CAPTURE_DEV_SESSION=1` の Rails development 環境で `route-smoke.spec.ts` を `select-farm-size` に絞って実行し、pathname 不一致で失敗することを記録する。環境が用意できない場合、E2E 実行は未確認のまま、以下の静的検査系の RED を根拠にする。

| 種別 | パス | Given / When / Then | 現状 |
|------|------|--------------------|------|
| node:test | `frontend/scripts/generate-e2e-route-manifest.test.mjs`（既存ファイルに追加） | Given `src/app/routes` の全ルート定義 / When `buildManifestData` と `parseRoutesFile` を呼ぶ / Then `componentImportPath` が無い（リダイレクト専用）ルートの pattern は `payload.routes` に含まれない | RED（`select-farm-size` が含まれる） |
| node:test | 同上 | Given `buildHostSelectorData` / When map を取得 / Then `map['public-plans/select-farm-size']` は `undefined`（既存テスト `:82-85` の期待を反転） | RED |
| Angular spec | `frontend/src/app/routes/public-plans.routes.spec.ts`（新規、`core.routes.spec.ts` と同形式） | Given `publicPlansRoutes` / When `path === 'public-plans/select-farm-size'` を探す / Then `{ path, redirectTo: '/public-plans/new', pathMatch: 'full' }` | リダイレクトを保持する場合のみ。現状でも通る（固定目的のため RED にならない。特性化テスト） |
| 静的検査 | `npm run e2e:layout-contract:check:enforce` | Given manifest から行を除去 / When 実行 / Then `extraBindings` / `extraConformance` が空で `ok` | 実装途中で RED になる（binding 削除漏れ検出）→ GREEN |

実行経路の注意（要確認）: `run-test-frontend.sh` は `npm test -- --watch=false` = `ng test`（`@angular/build:unit-test`）のみを実行し、`node --test` の `.mjs` テストは含まない（`frontend/package.json:11`、`run-test-frontend.sh` 全体）。`generate-e2e-route-manifest.test.mjs` は CI が直接 `node --test` で実行している（`frontend-test.yml:90`）が、`test-common` の経路には無い。**この RED を `test-common` 経由で実行する手段がない点をユーザーに確認する**（§7）。Angular spec の実行例: `.cursor/skills/test-common/scripts/run-test-frontend.sh --include=src/app/routes/public-plans.routes.spec.ts`（`--include` はビルダー標準オプションだが、本リポジトリでの実行は未確認）。

### 5.2 項目 2（farm_sizes 削除）

| 種別 | パス | Given / When / Then | 現状 |
|------|------|--------------------|------|
| R4 契約 | `crates/agrr-r4-contract/tests/contracts.rs`（`get_entry_schedule_farms_returns_reference_farms_for_region` 付近に追加） | Given 起動済み agrr-server / When `GET /api/v1/public_plans/farm_sizes`（認証なし） / Then 501 かつ `error == "api_not_migrated"`（B' を選ぶなら 410 と `error_code` を先例 `assert_crop_task_template_api_removed` に倣って検証） | RED（現在は 200 でカタログ配列を返す） |
| R4 契約 | 同上（既存の POST 契約が無い場合の特性化） | Given 参照農場と作物 / When `POST /api/v1/public_plans/plans` に `farm_size_id: "300"` / Then 200 で `plan_id` が返る | GREEN のまま維持すべき回帰確認。R4 に該当テストは無い（確認済み: `contracts.rs` に `public_plans/plans` / `farm_size_id` の出現 0 件。`public_plans` は entry_schedule / add_field のみ）。追加し、「削除で POST が壊れない」ことを固定する（暗黙結合 §2.2 の保護にもなる） |
| Domain | `crates/agrr-domain/test/public_plan/catalog_farm_size_catalog_test.rs` | `all_returns_three_farm_sizes` を削除。`find_by_id_*` は維持 | 削除は GREEN の一部 |
| Angular spec | `frontend/src/app/services/public-plans/public-plan-store.service` の既存 spec（有無は未確認） | Given `setFarm(farm)` / When 呼ぶ / Then `state.farmSize?.id === '300'` | 特性化。フロント固定値が消えないことの保護 |
| 静的検査 | `scripts/run-architecture-guard.sh` | Given `wizard_farm_sizes` を `R7_EXEMPT_HANDLERS` から除去し、ハンドラも削除 / When 実行 / Then 違反なし | ハンドラだけ削除して例外リストを残しても通る可能性がある（未確認）。リストの掃除は目視確認 |

実行:

- R4: `scripts/run-rust-contract-tests.sh`
- ドメイン: `.cursor/skills/test-common/scripts/run-test-rust-domain.sh`
- フロント: `.cursor/skills/test-common/scripts/run-test-frontend.sh`

i18n キー削除は、キーの有無を固定する既存 `*.catalog.spec.ts`（`public-plans-select-farm-locale.spec.ts` など）を実行して回帰を確認する。**i18n JSON のみの変更は振る舞い不変のため RED は不要**だが、キー削除で落ちる既存 spec が無いことの GREEN 確認は必須。

`crates/agrr-server/**` を変更したら、Docker 検証前に `.cursor/skills/dev-docker/scripts/rebuild-restart.sh` を実行する（`docker-dev-agrr-server-rebuild.mdc`）。

### 5.3 項目 3（問い合わせレスポンス型）

| 種別 | パス | Given / When / Then | 現状 |
|------|------|--------------------|------|
| Angular spec | `frontend/src/app/adapters/contact/http-contact-gateway.service.spec.ts` | Given `apiClient.post` が実サーバー形状 `{ id: 1, status: 'queued' }` を返す / When `postMessage` / Then 結果は `{ id: 1, status: 'queued' }` と等しく、`email` / `message` / `created_at` などサーバーが返さないキーを持たない | RED（現状は `name: null` 等を補完して返す） |
| Angular spec | `frontend/src/app/usecase/contact/send-contact-message.usecase.spec.ts` | Given ゲートウェイが `{ id: 1, status: 'queued' }` を返す / When `execute` / Then `onSuccess` が `{ id: 1, status: 'queued' }` で呼ばれる | RED（現状は `created_at` / `sent_at` キーを付けて呼ぶ。`toHaveBeenCalledWith` は `undefined` 値を厳密扱いしない場合があるため、`toStrictEqual` 相当の厳密比較で書く） |
| Angular spec | `frontend/src/app/adapters/contact/contact-form.presenter.spec.ts` | DTO を `{ id: 42, status: 'queued' }` に更新し、既存の成功メッセージ表示の断言が通る | 型変更後のコンパイル追従（振る舞い不変） |
| R4 契約 | 既存 `post_contact_message_creates_queued_record`（`contracts.rs:4509-4530`） | サーバー契約の維持を確認 | GREEN のまま（案 A ではサーバー変更なし） |

実行: `.cursor/skills/test-common/scripts/run-test-frontend.sh`（全体）および対象 spec の絞り込み。R4 は `scripts/run-rust-contract-tests.sh`。

### 5.4 項目 5（基準の文書化）

本書 §3.4 の文書化のみ。ドキュメントのみの変更は `tdd-on-edit` の例外（ドキュメント/設定のみ）に該当し、RED テストは書かない。実際の一括削除を別タスクにする場合は、その時点で機能単位に §5.2 の i18n 手順を適用する。

### 5.5 共通の完了手順

個別 GREEN → 全体スイート（`run-test-frontend.sh` / `run-test-rust-domain.sh` / `run-rust-contract-tests.sh`）→ `test-slow-detection`（`rails-testing-workflow.mdc`）。長時間コマンドは `process-monitor` で完了と終了コードを確認してから結果を断定する。

---

## 6. 実装ステップ

依存順。各ステップは RED → GREEN → 必要ならリファクタ。

**変更単位 X（項目 1 + 項目 2 のフロント/E2E側）**

1. （任意・推奨）現状確認: Rails development + Playwright で `select-farm-size` の smoke を実行し、不整合の再現ログを保存。
2. RED: `generate-e2e-route-manifest.test.mjs` に §5.1 の 2 テストを追加（またはテスト更新）。`node --test` で RED を確認（実行経路は §7 の確認事項）。
3. GREEN: `E2E_EXCLUDE_MANIFEST_PATTERNS` に追加、`HOST_SELECTOR_OVERRIDES` の該当行を削除（`generate-e2e-route-manifest-lib.mjs:7, 15`）。
4. `npm run e2e:manifest` で `route-manifest.json`・`route-to-png.md`・`host-selector-by-pattern.generated.ts` を再生成（`generatedAt` の差分を除き、`select-farm-size` 行が消えることを確認）。
5. `layout-contract-bindings.mjs:29`、`layout-conformance-bindings.mjs:74`、`a11y-allowlist.json` の `public-plans/select-farm-size` ブロックを削除。
6. `npm run e2e:manifest:check`・`npm run e2e:layout-contract:check:enforce`・`npm run test:route-manifest-coverage` を実行して GREEN を確認（CI と同じ 3 ステップ）。
7. （リダイレクト保持の場合）`public-plans.routes.spec.ts` を追加してリダイレクトを固定。

**変更単位 Y（項目 2 のバックエンド + i18n）**

8. RED: R4 契約に `GET /api/v1/public_plans/farm_sizes` の削除後期待を追加。POST 回帰テストの有無を確認し、無ければ追加。
9. GREEN: `public_plans.rs` のルート・ハンドラ・JSON 生成・不要 import を削除。`FarmSizeCatalog::all()` とドメインテストの該当ケースを削除。`run-architecture-guard-lib.mjs` の例外を削除。
10. `rebuild-restart.sh` で API を再ビルドしてから Docker 上で確認。
11. i18n: `public_plans.farm_sizes.*`、`public_plans.errors.select_farm_size`、`public_plans.errors.invalid_farm_size` を ja/en/in と `config/locales/views/public_plans.{ja,us,in}.yml` から削除。既存の catalog spec を実行して GREEN を確認。
12. 全体スイート（cargo domain → R4 → frontend）と遅延検知。

**変更単位 Z（項目 3）**

13. RED: §5.3 の gateway / usecase spec を更新。
14. GREEN: `ContactMessageRecord` → gateway → DTO → usecase → presenter spec の順に型を絞る。
15. フロント全体スイート。

**項目 5:** 追加の実装ステップなし（本書が成果物）。

X・Y・Z は互いに独立してマージ可能。X と Y を分けると、Y の前に X だけで CI の E2E 整合が取れる。

---

## 7. リスク・未確定事項

- **E2E の不整合は静的読解のみ（未確認）。** 実際に `select-farm-size` の smoke / capture が失敗しているか、CI で実行されているかは未確認。
- **`test-common` に `node --test`（`.mjs`）の経路が無い。** 項目 1 の RED は `frontend-test.yml:90` と同じ `node --test scripts/generate-e2e-route-manifest.test.mjs` で実行するのが実質唯一。`npm test` 直接実行は禁止（`test-common-entry.mdc`）だが、`node --test` の扱いは規約に明記がない。例外として認めるか、ラッパースクリプトを別途追加するか（スクリプト追加は `project-necessary-code-only` の確認対象）、ユーザー判断が必要。
- **外部利用者の有無が未確認**（`farm_sizes` API、`/public-plans/select-farm-size` の URL）。本番アクセスログ確認が必要（`gcp-available.mdc`）。削除後は 501 `api_not_migrated`（`fallback.rs`）になり、廃止の意図が伝わりにくい。B'（410 Gone）が代替。
- **暗黙結合:** フロントの `"300"` とサーバーカタログの `rental_farm`（300㎡）（§2.2）。今回は温存するが、R4 の POST 回帰テストで保護する。
- **i18n の 9 件（サーバー参照あり）** がクライアントに届くかは未確認。削除候補から外し、別途補完可否を検討する。
- **i18n 集計の精度:** 静的一致のみ。動的キー・サーバー由来キー・Rails YAML 由来は取りこぼしうる。全体の約 1450 件（ja）という参照ゼロ数は削除根拠にしない。
- **`in` ロケール:** 依頼は ja/en の偏りだが、`in` にも偏りがある（§2.5）。判断基準は 3 ロケールを対象にする前提とした。
- **生成物の差分:** `npm run e2e:manifest` は `generatedAt` を更新する。`e2e:manifest:check` は `generatedAt` を無視して比較する（`normalizeManifestJson`）ので CI は通るが、レビュー時のノイズになる。
- **`public/` の追跡ビルド成果物**に `farm_sizes` 文字列が残る（旧バンドル）。ソースではないため対象外とするが、削除の網羅確認では除外条件を明記する。
- **`FarmSizeOption` 型の名前**（`name` が固定日本語 `'300㎡'`）。表示に使われていないため放置するが、将来表示するなら i18n 化が必要（今回は範囲外）。
- 項目 3 の `'failed'` 分岐削除可否（§2.3）は、ドメインが 201 で `failed` を返す経路が無いことを確認するまで分岐を残す（本計画は型の整合のみで分岐は変更しない）。

---

## 8. 受け入れ条件

項目 1:
- `npm run e2e:manifest:check`、`npm run e2e:layout-contract:check:enforce`、`npm run test:route-manifest-coverage` がすべて GREEN。
- `frontend/e2e/route-manifest.json`・`route-to-png.md`・`host-selector-by-pattern.generated.ts` に `public-plans/select-farm-size` が含まれない。
- `layout-contract-bindings.mjs`・`layout-conformance-bindings.mjs`・`a11y-allowlist.json` に該当エントリが無い。
- リダイレクト専用ルートが manifest に載らないことを検査するテストが存在し、`generate-e2e-route-manifest.test.mjs` が GREEN。
- （保持の場合）`/public-plans/select-farm-size` → `/public-plans/new` のリダイレクトが spec で固定されている。

項目 2:
- `GET /api/v1/public_plans/farm_sizes` の期待（501 または 410）が R4 契約で固定され、`scripts/run-rust-contract-tests.sh` が GREEN。
- `POST /api/v1/public_plans/plans`（`farm_size_id: "300"`）が引き続き成功する回帰テストが存在し GREEN。
- `wizard_farm_sizes`・`farm_size_catalog_json`・`FarmSizeCatalog::all()` と `R7_EXEMPT_HANDLERS` の該当エントリが存在しない。
- `public_plans.farm_sizes.*`・`public_plans.errors.select_farm_size`・`public_plans.errors.invalid_farm_size` が 3 ロケールと Rails YAML から削除され、既存の i18n catalog spec が GREEN。
- ウィザード（農場選択 → 作物選択 → 作成）が動作する（Docker 上で `rebuild-restart.sh` 後に確認）。

項目 3:
- ゲートウェイ / ユースケース / DTO の型に `email` / `message` / `created_at` / `sent_at` 等サーバーが返さないフィールドが無い。
- 更新した spec が GREEN。既存の R4 契約（`post_contact_message_creates_queued_record`）が GREEN のまま。
- 問い合わせフォームの成功メッセージ表示（presenter spec）が従来どおり。

項目 5:
- 本書 §3.4 の判断基準が承認されている。実際の一括削除は別タスクとして、機能単位の計画を伴って起票される。

共通: 全体スイートと遅延検知が完了し、`test-common` 以外の経路でテストを実行していない（`node --test` の扱いはユーザー判断に従う）。

---

## 9. 関連課題との依存

| 課題 | 関係 | 調整点 |
|------|------|--------|
| [01 resource-limit-bypass](01-resource-limit-bypass.md) | 依存なし | — |
| [02 contact-recaptcha](02-contact-recaptcha.md) | 項目 3 と同一ファイル・同一エンドポイント | `contact-message.model.ts` / `http-contact-gateway.service.ts` / 契約 `contracts.rs` の問い合わせテストが両方の変更対象。02 が `recaptcha_token` をペイロードに追加する変更と、本書の受信側型の絞り込みは論理的に独立だが、先にマージされた側にもう一方が追従する。サーバーのエラー形状（`error` / `errors`）は 02 が決める |
| [03 api-key-scope-docs](03-api-key-scope-docs.md) | 弱い関連 | §2.6 で `/api/v1/masters/*` を外部 API と分類した根拠（`getting-started.md`）が 03 の文書と一致すること |
| [04 api-key-query-auth](04-api-key-query-auth.md) | 依存なし | — |
| [05 fail-closed-critical](05-fail-closed-critical.md) | 弱い関連 | 項目 2 の削除後 501 `api_not_migrated` は既存の fail-closed 規約（`fallback.rs`）に沿う動作 |
| [06 fail-closed-suspected](06-fail-closed-suspected.md) | 依存なし | — |
| [07 frontend-error-contract](07-frontend-error-contract.md) | 項目 3 と近接 | 問い合わせのエラー処理（`isValidationError` が 422 のみ、`send-contact-message.usecase.ts:56-58`）は 07 の範囲。本書は成功レスポンス型のみ。`send-contact-message.usecase.ts` を両方が編集する可能性があるため順序調整 |
| [08 openapi-gaps](08-openapi-gaps.md) | 項目 2・3 と関連 | `docs/api/openapi.yaml` に `public_plans` / `contact_messages` の記載が無い（`grep` 0 件）。項目 2 の削除後は farm_sizes を 08 に記載しない。項目 3 の最終形（`id` / `status`）は 08 が契約として記載するときの正 |
| [09 stale-design-docs](09-stale-design-docs.md) | 弱い関連 | `docs/design/organization-data-model.md:80` に `farm_sizes` テーブルの記載がある（テナント非スコープ）。テーブル自体（`V1__baseline.sql:15`）は本計画で削除しない。09 が設計文書の陳腐化を扱う際に参照 |
| [10 authorization-consistency](10-authorization-consistency.md) | 項目 4 は 10 の項目 4 | 公開プラン API（`public_plan_data` / 公開 field cultivation）の無認証応答は 10 で扱う。本書は認証方針を変更しない |
