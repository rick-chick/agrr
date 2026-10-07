# 02: 問い合わせフォームの CAPTCHA が未実装のため送信できない（方針変更: reCAPTCHA → Cloudflare Turnstile）

> **Turnstile へ方針変更**: 本書は当初「reCAPTCHA v2/v3/Enterprise のどれを実装するか」を比較していた。ユーザー指示により **CAPTCHA は reCAPTCHA ではなく Cloudflare Turnstile を採用する**（§0）。ファイル名 `02-contact-recaptcha.md` は他文書のリンク維持のため変更しない。

- 状態: 対応計画（本書はドキュメントのみ。コード・設定・他文書は未変更）。CAPTCHA の採用サービスは Turnstile で確定（§0）。エラー応答の契約は課題 07 の最新契約（`errors` 配列 + `error_code`）に従う（§0 の D-4〜D-6）。未決は §3.4 の Q1〜Q9 と Q11〜Q17（Q10 は 07 に従う形で解消）。
- 基準コミット: `cdfd21ac6`（2026-09-29 時点のリポジトリを実際に読んだ事実だけを `file:line` 付きで記載）。
- 整合更新（2026-10-07）: README の決定事項（第 1〜3 回）と課題 07 の最新版（§0.2・§0.3・§3.3・§3.6・§3.7・§10）に合わせ、エラー形状・`code` 提案・依存欄（§10）を更新した。本更新で読み直した行（`contact_messages.rs:58-79`、`contact_message_recaptcha.rs:15-22, 124-131`、`create_contact_message_interactor.rs:53-69`、`contracts.rs:4502, 4563, 4595`、`send-contact-message.usecase.ts:49-58`、同 spec `:87-93`）は、更新時点の作業ツリーで内容が本書の記述と一致することを確認した。それ以外の行番号は基準時点のまま（再確認していない）。`crates/agrr-server/src/api_error.rs` と `frontend/src/app/core/api-error-message.ts` は更新時点で**未作成**（`ls` で確認）。
- 記載ルール: 読んでいない・実行していないものは「未確認」と明記する。Cloudflare Turnstile の仕様は、記憶ではなく**この環境から公式ドキュメントを取得して確認した内容**（取得日 2026-09-29、§3.1 に URL と各ページの Last updated）と、ダミーキーでの `siteverify` 実測（§3.1.2）に限って断定する。確認できなかった点は §3.1.3 に列挙し、実装着手前に公式ドキュメントで再確認する。

参照した規約: [`ARCHITECTURE.md`](../../ARCHITECTURE.md)、[`docs/architecture/LAYER-RULES.md`](../architecture/LAYER-RULES.md)、[`tdd-on-edit`](../../.cursor/skills/tdd-on-edit/SKILL.md)、[`test-common`](../../.cursor/skills/test-common/SKILL.md)、[`evidence-before-design-and-implementation.mdc`](../../.cursor/rules/evidence-before-design-and-implementation.mdc)、[`naming-ules.mdc`](../../.cursor/rules/naming-ules.mdc)、[`docs/design/UI-COMPOSITION-RULES.md`](../design/UI-COMPOSITION-RULES.md)（フロント変更のため）。

---

## 0. 決定事項

| # | 決定 | 状態 |
|---|---|---|
| D-1 | 問い合わせフォーム（`POST /api/v1/contact_messages`）の CAPTCHA は **Cloudflare Turnstile を採用**する。reCAPTCHA（v2 / v3 / Enterprise のいずれも）は採用しない | **確定** |
| D-2 | サーバー側の検証は Turnstile の `siteverify`（`https://challenges.cloudflare.com/turnstile/v0/siteverify`）へ**置換**する。reCAPTCHA との併用・切替機構は作らない（旧コードは撤去する） | **確定** |
| D-3 | fail-closed 方針は維持する（secret 未設定→503、フロントの site key 未設定・スクリプト読み込み失敗→送信不可）。CAPTCHA を外す・素通しする経路は作らない | **確定**（現行方針の継続） |
| D-4 | 問い合わせ API のエラー応答は、課題 07 の統合契約に従う。失敗本文は `errors`（非空文字列の配列）を必須とし、単数の `error` 文字列は新規応答に書かない。本書は新規キー `code` を**導入しない** | **確定**（README 第 2 回「errors」・第 3 回「削除」の帰結。07 §0.2・§0.3） |
| D-5 | CAPTCHA 失敗の識別子は、既存の `error_code` に置く。422（拒否・トークン欠落）は `{"errors":["<文言>"],"error_code":"captcha_failed"}`、503（secret 未設定・一時利用不可）は `{"errors":["<文言>"],"error_code":"captcha_unavailable"}`。値の名称は本書で確定する（07 §10 が確定を 02 に委ねている） | **確定**（名称は本書。形は 07） |
| D-6 | 失敗応答はエッジの共通ヘルパー（07 §3.6 の `crates/agrr-server/src/api_error.rs`）経由で組み立てる。入力検証の 422 は従来どおり `errors` で、`error_code` を持たない（CAPTCHA 失敗と `error_code` の有無・値で区別する） | **確定**（形は 07）。ヘルパーは未作成。着手順と旧キー併記の要否は未確定（Q16） |

- 由来: ユーザー指示は「Cloudflare、する」（`docs/spec-defects/README.md` の決定事項表と同一）。指示中の語は「claudflawer」と表記ゆれしており、**「Cloudflare」の意味と解釈**した。さらに、本課題（問い合わせフォームの CAPTCHA）の文脈で Cloudflare の CAPTCHA 製品である **Turnstile を指す**と解釈した。**この2段の解釈は文脈からの推定**であり、誤りがあれば本節を差し替える（Cloudflare の他製品、たとえば WAF / Bot Management、DNS プロキシの採用を意味する場合は方針が変わる。§3.4 Q6）。
- D-4〜D-6 の由来: README の決定事項（第 2 回「errors」: エラー契約の統合先を `errors` 配列に確定、第 3 回「削除」: 旧キー `error` / `message` を削除）と、それを受けた課題 07 の確定（`errors` 必須、任意で `error_code` / `field_errors`。07 §0.2・§0.3・§3.3）。07 §10 は 02 の旧案（`error` を維持して新規 `code` を追加）を「`code` ではなく既存の `error_code` を使う。名称は 02 で確定する」と読み替えており、本書はこれに合わせた。`error_code` は `masters_auth.rs:98` とフロントの `crop-blueprint-regenerate-error-i18n.ts:19-26` が同名で使用済みで、2 つ目の名前を作らない。この対応づけは README の文言と 07 の記述からの**解釈**である。
- Cloudflare / Turnstile は**リポジトリ内で未使用**である（確認済み）:
  - `rg -i 'cloudflare|turnstile' --hidden -g '!node_modules' -g '!target' -g '!.git' .` のヒットは本書更新前の時点で `docs/spec-defects/README.md`（決定事項表の 2 行）のみ。コード・スクリプト・設定・フロント・ドキュメントに 0 件。
  - `rg -il 'cf-connecting|cf-turnstile|challenges\.cloudflare|cf_clearance|cdn-cgi' --hidden -g '!node_modules' -g '!target' -g '!.git' .` は 0 件。
  - したがって「既存の Turnstile 実装を直す」のではなく、**新規導入**である。導入にあたり既存の reCAPTCHA 実装（`crates/` と `scripts/` のみに存在。§5.7）を置換する。
- 本決定で**変わらない**もの: 「フロントが CAPTCHA トークンを一切送らないため、サーバーの設定にかかわらず送信が成功しない」という課題の本体（§1、§2）。Turnstile へ変えても、フロント実装が入るまで送信不能である事実は同じ。
- 本決定の**範囲外**: Cloudflare を DNS / プロキシ / WAF として使うかどうか（現状は GCP LB 経由。§3.4 Q6。Turnstile は公式ドキュメント上、他の Cloudflare サービスなしで単独利用できる: §3.1.1 の 11）。

---

## 1. 概要と重大度

### 概要

匿名エンドポイント `POST /api/v1/contact_messages` は、現状 reCAPTCHA 検証を**必須**にしている（fail-closed）。一方、Angular の問い合わせフォームは CAPTCHA トークンの取得・送信を一切実装していない。したがって**サーバー側の設定状態にかかわらず、フロントのフォームから送信して成功する経路は現ツリーに存在しない**（コード読みによる。実機での再現は未実施。根拠は §2.1〜§2.3）。この構造は CAPTCHA を Turnstile に変えても変わらない（フロントに Turnstile ウィジェットが入り、サーバーが Turnstile を検証して初めて解消する）。

以下の表は**現行の（reCAPTCHA 前提の）挙動**である。Turnstile 移行後は `RECAPTCHA_SECRET_KEY` を `TURNSTILE_SECRET_KEY` に読み替える（§5）。

| サーバーの `RECAPTCHA_SECRET_KEY`（現行） | フロントの送信結果（コード上） | ユーザーに見えるメッセージ |
|---|---|---|
| 未設定 | 503 `{"error":"reCAPTCHA is not configured"}` | 「送信に失敗しました。」(`contact_form.errors.send_failed`) |
| 設定済み | 422 `{"error":"reCAPTCHA token is required"}` | 「入力内容を確認してください。」(`contact_form.errors.validation_failed`)。入力は正しいのに誤解を招く |

加えて、成功レスポンスの形とフロントの型・テストが乖離している（§2.4）。現状これは実害を出していないが、CAPTCHA 対応で同じ経路を触るため同時に是正する。

### 重大度

| 項目 | 重大度 | 理由 |
|---|---|---|
| 問い合わせフォームが送信不能 | **高** | 公開ページ `/contact`・`/en/contact` の唯一のフォーム機能が全環境で失敗する。データ破壊・情報漏えいはない |
| 失敗時メッセージの誤誘導（422 を validation_failed と表示） | 中 | 利用者が入力を疑い続ける |
| 成功レスポンス型の乖離 | 低 | 現状は presenter が DTO を使わないため表面化していない（`frontend/src/app/adapters/contact/contact-form.presenter.ts:102-111`） |
| 本番の CAPTCHA secret の設定有無 | 未確認 | 現行の `RECAPTCHA_SECRET_KEY` も、移行後の `TURNSTILE_SECRET_KEY` も本番の状態は未確認（§2.6、§6.6） |
| テスト用 secret が本番に混入した場合に検証が素通しになる | 中（発生条件は設定ミス） | Turnstile 公式のテスト用 secret は、実測で任意のトークンを成功にした（§3.1.2）。fail-closed に反する経路のため §3.2 T7 でガードを提案 |

---

## 2. 現状（確認済み事実）

本章はコードの**現状**であり、reCAPTCHA の名称はここでは現行実装のものを指す。

### 2.1 バックエンド: reCAPTCHA を必須にしている

| 事実 | 根拠 |
|---|---|
| リクエストボディが `recaptcha_token: Option<String>` を受ける | `crates/agrr-server/src/contact_messages.rs:29-37`（token は 36 行目） |
| ハンドラは token・`remote_ip` を入力 DTO に詰め、interactor を 1 回呼ぶ（R7 準拠） | `crates/agrr-server/src/contact_messages.rs:101-133` |
| interactor の順序は「レート制限 → reCAPTCHA → gateway.create」 | `crates/agrr-domain/src/contact_messages/interactors/create_contact_message_interactor.rs:47-51, 53-69, 71-86` |
| `NotConfigured` は `Unavailable` 失敗（メッセージ `"reCAPTCHA is not configured"`。文言は**ドメイン側**に書かれている） | 同 `:58-63` |
| `Error(msg)` は `Recaptcha` 失敗 | 同 `:64-68` |
| 失敗 → HTTP の写像: RateLimit=429 `{"error":"rate_limit"}`、Recaptcha=422 `{"error": msg}`、Unavailable=503 `{"error": msg}`、Validation=422 `{"errors":[...]}` | `crates/agrr-server/src/contact_messages.rs:58-79` |
| 成功は 201 `{"id","status"}` のみ | `crates/agrr-server/src/contact_messages.rs:86-94`（フィールドは 89-92 行目） |
| secret 未設定なら `NotConfigured`、token が空なら `Error("reCAPTCHA token is required")` | `crates/agrr-server/src/contact_message_recaptcha.rs:124-131` |
| 上記は単体テストで固定済み | 同 `:185-204`（`verify_rejects_when_secret_missing` / `verify_rejects_when_token_missing`） |
| `RECAPTCHA_SECRET_KEY` と `RECAPTCHA_VERIFY_URL`（既定 `https://www.google.com/recaptcha/api/siteverify`）を環境変数から読む | 同 `:7, :15-22` |
| ヘルスに `recaptcha_configured` と警告 `"RECAPTCHA_SECRET_KEY is unset; contact messages are rejected"` を載せる | `crates/agrr-server/src/routes.rs:33-46`（警告は 35-37 行目、キーは 45 行目） |
| 起動時に未設定なら `tracing::warn!` | `crates/agrr-server/src/contact_message_recaptcha.rs:35-41` |
| R4 契約: 未設定→503、正常→201 `queued`、レート超過→429、検証失敗→422、ヘルスの `recaptcha_configured` | `crates/agrr-r4-contract/tests/contracts.rs:4466, 4476, 4509, 4533, 4567`（token を含むペイロードは 4457-4464） |
| R4 の契約ランタイムは mock 検証サーバーとテスト用 secret を設定する。secret 未設定のシェル契約もある | `scripts/run-rust-contract-tests.sh:260-264, 308-354`、`scripts/recaptcha-contract-mock.py` |
| R4 の「未設定→503」テスト（`:4476`）は、契約ランタイムで secret が設定済みのため**スキップされる**（`RECAPTCHA_SECRET_KEY` が空でなければ `return`）。未設定→503 はシェル契約（`run-rust-contract-tests.sh:308-354`）が担う | `contracts.rs:4477-4483`、`run-rust-contract-tests.sh:262, 308-354` |

### 2.2 フロントエンド: CAPTCHA の実装・送信が無い

| 事実 | 根拠 |
|---|---|
| `frontend/src` 配下に `recaptcha` を含むファイルが 0 件（大文字小文字を区別せず再確認済み） | `grep -rIli recaptcha frontend/src` の結果が空 |
| 送信ペイロード型に token フィールドが無い | `frontend/src/app/domain/contact/contact-message.model.ts:1-7` |
| コンポーネントが組み立てるペイロードは name/email/subject/message/source のみ | `frontend/src/app/components/contact-form/contact-form.component.ts:176-184` |
| テンプレートに CAPTCHA ウィジェットの置き場が無い（フィールド 44-100、送信ボタン 102-110） | 同 `:44-133` |
| ゲートウェイはペイロードをそのまま `POST /api/v1/contact_messages` する | `frontend/src/app/adapters/contact/http-contact-gateway.service.ts:16-18` |
| **422 を一律 `validation_failed` に写像**（CAPTCHA 失敗もバリデーション失敗も区別しない）。それ以外は `send_failed` | `frontend/src/app/usecase/contact/send-contact-message.usecase.ts:49-58` |
| ユースケースのテストが想定する 422 の本文は `{ field_errors: {...} }` だが、サーバーの実本文は `{ errors: [...] }` または `{ error: "..." }` | テスト側 `frontend/src/app/usecase/contact/send-contact-message.usecase.spec.ts:87-93`、サーバー側 `crates/agrr-server/src/contact_messages.rs:65-76` |
| プライバシーポリシーは Google Analytics（節 4）と Google AdSense（節 5）の利用を記載しているが、CAPTCHA サービス（Turnstile / Cloudflare）の記載は無い（`cloudflare` / `turnstile` は 0 件） | `frontend/src/assets/i18n/ja.json:4048-4106`（`privacy` ブロック。`en.json:4012`、`in.json:3761` に同構造） |
| 外部スクリプトの動的ロードには既存の前例がある（`document.createElement('script')`、ブラウザ限定） | `frontend/src/app/services/google-analytics.service.ts:191-199` |
| ランタイム設定の前例: `window.*` を優先し `environment` にフォールバック | `frontend/src/app/core/google-ads-runtime-config.ts:12-28`、注入は `.cursor/skills/deploy-frontend/scripts/gcp-frontend-deploy.sh:69-71, 213-223` |
| `/contact` は事前レンダリング対象 | `frontend/src/app/core/seo/public-prerender-routes.ts:5` |
| アプリのロケールは `ja` / `en` / `in`。`in` は UI 文言が Hindi のため、HTML `lang` は `hi` に写像する既存関数がある | `frontend/src/app/core/app-locale.ts:10-20`（`documentHtmlLang`） |

### 2.3 サーバーが現在検証している内容（Turnstile への置換に関係する点）

| 事実 | 根拠 |
|---|---|
| 検証先は `siteverify` エンドポイント | `crates/agrr-server/src/contact_message_recaptcha.rs:7` |
| 送信は `application/x-www-form-urlencoded`（`.form(&form)`）で `secret` / `response` / `remoteip` の 3 項目。`remoteip` は空でなければ付与 | 同 `:85-94` |
| 判定に使う応答フィールドは `success` と `error-codes`（欠落時は空配列）のみ。`score` / `action` / `hostname` / `challenge_ts` は構造体に無く**検証していない** | 同 `:48-62, :115-121` |

読み取れる結論:

- 現行の検証は「`success` が真ならよい」という単純な形で、Turnstile の `siteverify`（form 形式の `secret` / `response` / `remoteip` を受け、`success` / `error-codes` を返す。§3.1.1 の 1・2）と**形が同じ**である。置換の中心は URL・環境変数名・エラー文言・エラーコードの分類であり、HTTP 呼び出しの骨格は流用できる。
- リポジトリにはどの CAPTCHA のキーを発行したかの記録が無い（履歴上の旧契約文書に `RECAPTCHA_SITE_KEY / SECRET_KEY (オプション)` とあるのみ。コミット `feecfbda9`、削除は `a40a3b87c`）。Turnstile のキーは新規に発行する（§3.4 Q1）。

### 2.4 成功レスポンスの型・テストの乖離

| 事実 | 根拠 |
|---|---|
| サーバーは作成時に status を常に `queued` で INSERT し、`id`・`status` のみ返す | `crates/agrr-adapters-sqlite/src/contact_messages/contact_message_gateway.rs:72-73`、`crates/agrr-server/src/contact_messages.rs:89-92` |
| R4 契約も `status == "queued"` と `id` しか固定していない | `crates/agrr-r4-contract/tests/contracts.rs:4509-4527` |
| フロントのゲートウェイは `res.email` / `res.message` / `res.created_at` / `res.sent_at` などを読み `ContactMessageRecord` を組み立てる（実際は `undefined` になるが型は `string`） | `frontend/src/app/adapters/contact/http-contact-gateway.service.ts:19-31`、型は `contact-message.model.ts:11-21` |
| ゲートウェイのテストは `email`/`message`/`created_at`/`sent_at` 入りの**架空のサーバー応答**を返して `toEqual` で照合している | `frontend/src/app/adapters/contact/http-contact-gateway.service.spec.ts:28-45, 50-64` |
| ユースケースは `status === 'failed'` を失敗扱いにするが、サーバーの作成応答が `failed` を返す経路はコード上存在しない | `frontend/src/app/usecase/contact/send-contact-message.usecase.ts:32-35` |
| 成功 DTO に `created_at` / `sent_at` を含めるが presenter は DTO を使わない | `frontend/src/app/usecase/contact/send-contact-message.dtos.ts:5-10`、`contact-form.presenter.ts:102-111` |

### 2.5 テスト・CI の穴

| 事実 | 根拠 |
|---|---|
| E2E スモーク `contact form submits successfully` は CAPTCHA なしで成功を期待する。現行サーバー挙動と矛盾する | `frontend/e2e/smoke/operation-smoke.spec.ts:96-105` |
| ただし CI のスモーク実行スクリプトは `route` / `layout` / `wizard-progress` / `a11y` / `empty-state` しか実行せず、`operation-smoke.spec.ts` は含まれない | `scripts/run-e2e-smoke-ci.sh:118-135`、`frontend/package.json:28-34` |
| そのため、この矛盾は CI では検知されない（検知されなかった理由は推測。原因の断定はしない） | 同上 |
| `cargo test -p agrr-server` を実行する `test-common` のスクリプト・CI ステップは見つからない（`scripts/`、`.github/workflows`、`.cursor/skills/test-common` を grep して `-p agrr-server` のテスト実行は 0 件） | grep 結果（ビルドのみ `scripts/run-rust-contract-tests.sh:93-94`） |
| `scripts/run-rust-contract-contact-shell-lib.test.mjs`（契約モックの配線検査）を実行する CI ステップ・`test-common` スクリプトは見つからない | `rg 'contact-shell-lib' .github scripts .cursor` が本体・テスト自身以外で 0 件 |

### 2.6 現行 RECAPTCHA_SECRET_KEY / 各環境の設定状況

| 対象 | 状況 | 根拠 |
|---|---|---|
| ローカル Docker（`agrr-server`） | **未設定**。compose の環境変数に無い → ヘルスは `recaptcha_configured:false`、POST は 503（コード上。コンテナ起動での実測は未実施） | `docker-compose.yml:28-41` |
| `env.example` / `env.gcp.example` / `env.gcp.test.example` | CAPTCHA 関連の記載なし | grep 0 件 |
| `docs/` 全体（`docs/spec-defects/` を除く） | 記載なし（履歴上の削除済み文書を除く） | grep 0 件 |
| 本番 Cloud Run デプロイスクリプト | env ファイルに含めていない。`--set-secrets` は `SCHEDULER_AUTH_TOKEN` のみ | `.cursor/skills/deploy-server/scripts/_agrr-server-cloud-run.sh:104-125, 141, 149` |
| 上記の含意 | このスクリプトでデプロイした本番には secret が入らない。なお `gcloud run deploy --env-vars-file` は既存の環境変数を置換する仕様と理解しているが、公式ドキュメントでの再確認は未実施（未確認）。Cloud Run コンソールや別手段で手動設定されている可能性は排除できない | 同上 |
| **本番の実際の設定状態** | **未確認**。本環境に `gcloud` が無く（`command -v gcloud` が空）、`curl https://agrr.net/api/v1/health` は 10 秒でタイムアウトした。確認手順は §6.6 に記載 | 実行結果 |
| フロント側 site key の配布 | 仕組みなし。`gcp-frontend-deploy.sh` は `API_BASE_URL` / `STATIC_PATH_PREFIX` / Ads 2 変数だけを注入 | `.cursor/skills/deploy-frontend/scripts/gcp-frontend-deploy.sh:69-71, 213-223` |

### 2.7 経緯（git 履歴で確認）

- `feecfbda9`（2026-02-10）: Rails 時代に問い合わせフォームを実装。reCAPTCHA は「オプション」扱いで、Angular 側に実装は入っていない。
- `1e9b5baba`（2026-08-27、#1143）: Rust で reCAPTCHA 検証と IP レート制限を強制化。
- `e5d705383`（2026-08-29、#1205）: secret 未設定を fail-closed（503）に変更。

つまり**サーバー側で検証を強制化した時点でフロントの対応が行われていない**。これが本課題の直接原因である（履歴の読みによる。担当者の意図は未確認）。

### 2.8 関連する周辺事実（本課題の範囲外だが計画に影響する）

- Rust クレートに問い合わせメールの配送処理は見つからない（`smtp` / `mailer` / `lettre` の grep 0 件）。`sent_at` も更新されない。作成された `queued` 行を誰が読むかはリポジトリ上不明（運営側の受信経路は未確認）。
- `ContactMessage::validate()` は本番経路から呼ばれていない（呼び出しはエンティティ内の `valid()` とテストのみ）。gateway は空文字チェックだけを行う（`crates/agrr-adapters-sqlite/src/contact_messages/contact_message_gateway.rs:64-69`）。メール形式・長さのサーバー側検証は効いていない。
- レート制限の IP は `X-Forwarded-For` の**先頭要素**を採用する（`crates/agrr-server/src/contact_messages.rs:39-56`）。LB 配下でクライアントが偽装できるかは未確認。リミッタはプロセス内メモリで、Cloud Run は `--max-instances 1` / `--min-instances 0`（`_agrr-server-cloud-run.sh:140, 146`、`crates/agrr-server/src/contact_message_rate_limit.rs:66-69`）。

### 2.9 Turnstile への置換に関わる現行実装の追加事実

| 事実 | 根拠 | 置換時の含意 |
|---|---|---|
| ヘッダーから IP が取れない場合、ハンドラは文字列 `"unknown"` を `remote_ip` として入力 DTO に入れる。検証器は空でなければそのまま `remoteip` として送る | `contact_messages.rs:107, 112-121`、`contact_message_recaptcha.rs:88-91` | Turnstile の `remoteip` は任意項目（§3.1.1 の 1）。IP として解釈できない値は送らない設計にする（§3.2 T4） |
| 検証器は HTTP ステータスを見ず、本文を JSON として解釈する。JSON でなければ `Error("...verification failed: ...")` | `contact_message_recaptcha.rs:93-111`（`status` の参照が無い）、`:50-56` | Turnstile は secret 不正で 400、GET で 405 を返す（§3.1.2）。400 は JSON 本文が付くので解釈可能だが、**運用側の設定不備がユーザー起因の 422 に写る**（次行） |
| 通信失敗・本文読み取り失敗・JSON 解釈失敗・`success:false` はすべて同じ `Error(msg)` → `Recaptcha` 失敗 → **422** になる | 同 `:50-56, 93-109`、`create_contact_message_interactor.rs:64-68`、`contact_messages.rs:62-65` | Cloudflare 側の障害や secret 誤設定でも利用者に「CAPTCHA をやり直して」に近い 422 が出る。§3.2 T3 で三分類（拒否 / 一時利用不可 / 未設定）にする案 |
| HTTP クライアントは `Client::new()` で、コード上に明示的なタイムアウト指定は無い | `contact_message_recaptcha.rs:93` | 公式は「Siteverify の応答に妥当なタイムアウトを設定する」を推奨（§3.1.1 の 12）。明示タイムアウトの追加を推奨（値は実装時に決定） |
| 検証はブロッキング HTTP をスレッドで実行して join する | 同 `:132-146` | 骨格は流用する（変更不要） |

---

## 3. 仕様の確定（Turnstile 採用を前提にした設計）

### 3.1 Turnstile 公式仕様の一次確認

#### 3.1.1 確認した公式ドキュメントの内容

取得方法: 2026-09-29、この環境から `curl https://developers.cloudflare.com/turnstile/<path>/index.md` で各ページの Markdown 版を取得して読んだ（HTTP 200）。ページ右上の Last updated を併記する。**公式ドキュメントは更新されうるため、実装着手前に再確認する**（特に 1・4・9・10）。

| # | 確認した内容 | 出典（`https://developers.cloudflare.com/turnstile/` 配下）・Last updated |
|---|---|---|
| 1 | 検証: `POST https://challenges.cloudflare.com/turnstile/v0/siteverify`。`application/x-www-form-urlencoded` と `application/json` の両方を受け、応答は常に JSON。パラメータは `secret`（必須）、`response`（必須）、`remoteip`（任意）、`idempotency_key`（任意。再試行用 UUID） | `get-started/server-side-validation/`（Sep 16, 2026） |
| 2 | 応答フィールド: `success`、`challenge_ts`、`hostname`、`error-codes`、`action`、`cdata`、`metadata.ephemeral_id`（Enterprise のみ） | 同上 |
| 3 | エラーコード: `missing-input-secret`、`invalid-input-secret`、`missing-input-response`、`invalid-input-response`（トークンが不正・不正形式・期限切れ）、`bad-request`、`timeout-or-duplicate`（検証済みトークンの再使用）、`internal-error`（再試行） | 同上 |
| 4 | トークン: 最大 2048 文字、**有効期間 300 秒**、**1 回限り**。期限切れ・再使用は `timeout-or-duplicate`。期限切れ時はウィジェットを `turnstile.reset` でリフレッシュ | 同上 |
| 5 | Siteverify は **POST のみ**（reCAPTCHA の GET クエリ形式は不可） | `migration/recaptcha/`（May 5, 2026） |
| 6 | ウィジェット: `api.js` は**指定 URL から取得する必要があり、プロキシ・キャッシュすると将来の更新で壊れる**（Caution）。SPA・動的コンテンツには明示レンダリング（`api.js?render=explicit` + `turnstile.render()`）を推奨。操作 API は `turnstile.reset(widgetId)` / `getResponse` / `remove` / `isExpired` / `execute` | `get-started/client-side-rendering/`（Jun 17, 2026） |
| 7 | レンダーパラメータ: `sitekey`、`action`（32 文字以内、英数字・`_`・`-`）、`callback` / `error-callback` / `expired-callback` / `timeout-callback`、`theme`（`auto`/`light`/`dark`）、`size`（`normal`/`flexible`/`compact`）、`language`（`auto` または ISO 639-1 / 言語+国コード）、`response-field`（既定 `true`。隠し入力の作成有無）、`response-field-name`（既定 `cf-turnstile-response`）、`refresh-expired`（`auto` 既定 / `manual` / `never`）、`retry`、`appearance` | `get-started/client-side-rendering/widget-configurations/`（Jun 28, 2026） |
| 8 | 対応言語に `ja`（日本語）と `hi`（ヒンディー語）と `en` が含まれる | `reference/supported-languages/`（May 5, 2026） |
| 9 | ウィジェットモード: **Managed（推奨）**、Non-Interactive、Invisible。**Invisible にする条件として、自サイトのプライバシーポリシーで Cloudflare の Turnstile Privacy Addendum（`https://www.cloudflare.com/turnstile-privacy-policy/`）を参照すること**と明記されている。Managed / Non-Interactive の表記義務の有無は、読んだページには記載が無かった（未確認） | `concepts/widget/`（Apr 16, 2026） |
| 10 | CSP: `script-src` と `frame-src` に `https://challenges.cloudflare.com` を許可する（または nonce 方式。Cloudflare は nonce を推奨し `strict-dynamic` とも動作すると記載）。`connect-src` は**プリクリアランスモード使用時のみ `'self'` が必要**と記載され、それ以外の `connect-src` 要件の記載は無い | `reference/content-security-policy/`（May 5, 2026） |
| 11 | プラン: Free は「20 ウィジェットまで」「1 ウィジェットあたり 10 ホスト名まで」「チャレンジ数無制限」。**「Turnstile は他の Cloudflare サービスを必要とせず単独で利用できる」**。ホスト名は FQDN で、スキーム・ポート・パス・ワイルドカードは不可。ルートドメインを登録するとそのサブドメインも許可される。ウィジェットの作成にはホスト名が最低 1 つ必要 | `plans/`（Aug 14, 2026）、`additional-configuration/hostname-management/`（Apr 27, 2026）、`get-started/widget-management/dashboard/`（Apr 16, 2026） |
| 12 | 公式のベストプラクティス: secret は環境変数等で安全に保管し、**Siteverify はバックエンドからのみ呼ぶ**、トークンは毎リクエストで検証、`action` / `hostname` が指定されていれば確認する、Siteverify に妥当なタイムアウトを設定する、ユーザーに内部エラー詳細を出さない | `get-started/server-side-validation/`（Sep 16, 2026） |
| 13 | テスト用キー（公式のダミー）: サイトキー `1x00000000000000000000AA`（常に通過・可視）、`2x00000000000000000000AB`（常に失敗・可視）、`1x00000000000000000000BB`（常に通過・非可視）、`2x00000000000000000000BB`（常に失敗・非可視）、`3x00000000000000000000FF`（インタラクティブを強制）。secret `1x0000000000000000000000000000000AA`（常に通過）、`2x0000000000000000000000000000000AA`（常に失敗）、`3x0000000000000000000000000000000AA`（`timeout-or-duplicate`）。ダミーサイトキーは `localhost` を含む任意のドメインで動作。ダミーサイトキーが出すトークンは `XXXX.DUMMY.TOKEN.XXXX`。「テスト用 secret はダミートークンのみ受理し実トークンを拒否、本番 secret はダミートークンを拒否する」と記載。自動テストツール（Selenium / Cypress / Playwright）は Turnstile にボットと判定されうるため、ダミーキーを使うよう案内 | `troubleshooting/testing/`（May 5, 2026）、`tutorials/excluding-turnstile-from-e2e-tests/`（Apr 16, 2026） |
| 14 | 移行ガイドに、reCAPTCHA v2 相当の互換モード（`api.js?compat=recaptcha`。`grecaptcha` として登録、`g-recaptcha-response` を使う）がある。reCAPTCHA v3 は対象外 | `migration/recaptcha/`（May 5, 2026） |

#### 3.1.2 ダミーキーでの `siteverify` 実測（2026-09-29、この環境から）

公式のダミー secret（3.1.1 の 13 の値）を使い、実サーバーへ POST した結果（本番キーは使っていない）。

| # | リクエスト（form） | HTTP | 応答（抜粋） |
|---|---|---|---|
| 1 | secret=`1x…AA`、response=`XXXX.DUMMY.TOKEN.XXXX`、remoteip=`203.0.113.1` | 200 | `success:true`、`hostname:"example.com"`、`error-codes:[]`、`metadata.result_with_testing_key:true` |
| 2 | secret=`2x…AA`、response=ダミートークン | 200 | `success:false`、`error-codes:["invalid-input-response"]` |
| 3 | secret=`3x…AA`、response=ダミートークン | 200 | `success:false`、`error-codes:["timeout-or-duplicate"]` |
| 4 | secret=`1x…AA`、response=`bad-token`（ダミートークンではない） | 200 | **`success:true`**（公式の「ダミートークンのみ受理」の記載と**食い違う**） |
| 5 | secret=`1x…AA`、response=空 | 200 | `success:false`、`error-codes:["missing-input-response"]` |
| 6 | secret=`invalid`、response=ダミートークン | **400** | `success:false`、`error-codes:["invalid-input-secret"]` |
| 7 | secret=空、response=ダミートークン | **400** | `success:false`、`error-codes:["missing-input-secret"]` |
| 8 | `GET ?secret=...&response=...` | **405** | `error-codes:["bad-request"]`、`messages:["This API expects POST requests."]` |
| 9 | secret=`1x…AA`、response=ダミートークン、remoteip=`unknown` | 200 | `success:true`（テスト用 secret では不正な `remoteip` でも成功。本番 secret での挙動は未確認） |
| 10 | `Content-Type: application/json` で secret=`2x…AA` | 200 | `success:false`、`invalid-input-response`（JSON 形式も受理） |

実測から言えること（この 1 回の観測の範囲）:

- 検証器が `success` と `error-codes` だけ見れば、テスト用 secret では公式の 3 パターン（通過 / 失敗 / 重複）を再現できる。
- **テスト用 secret `1x…AA` は任意の空でないトークンを通した**（#4）。ダミー secret を本番に設定すると検証が実質無効になる（§1、§3.2 T7、§8 R14）。無効トークンの異常系テストには `2x…AA` を使うか、ローカルのモックを使う（§5.8）。
- secret の不備（不正・未指定）は **HTTP 400 + JSON 本文**で返り、現行検証器はステータスを見ずに本文を解釈するため、JSON は読める（§2.9）。

#### 3.1.3 この環境で確認できなかった点（実装着手前に公式ドキュメント・実環境で再確認する）

- 本番キー（実 secret）での `siteverify` の応答・レート制限・可用性の保証（SLA）。
- Cloud Run（本番サーバー）から `challenges.cloudflare.com` への到達性（送信 egress の制限有無を含む）。
- 実ブラウザ（Chromium / Playwright）での `api.js` のロード、Managed モードの挙動、`refresh-expired: auto` でトークンが自動更新されたときに `callback` が再度呼ばれるか（公式ページは「自動更新する」とだけ記載し、コールバックの再発火は明記していない）。
- ウィジェットを `remove()` して別の `language` で再 `render()` した際の実挙動（API は 3.1.1 の 6・7 に記載あり。SPA での言語切替の実機確認は未実施）。
- Cloudflare へ送られる情報の範囲と、日本・インド向けサービスでの法的な表記要件（プライバシーポリシー文言。法務判断）。Managed モードで Privacy Addendum の参照が必要か（3.1.1 の 9）。
- CSP の `connect-src` に `https://challenges.cloudflare.com` が実際に必要か（公式ページは要求していない。3.1.1 の 10）。Report-Only の違反をブラウザで確認して判断する（現行 CSP に `report-uri` は無い: §5.5）。
- 検証時に `hostname` / `action` を照合する場合の、テスト用キーでの `hostname`（実測は `example.com`。§3.1.2）と本番ホスト名の差の扱い。
- Turnstile のトークンが「発行元ウィジェットの secret でのみ検証成功する」ことの公式な明示記述（読んだページには見当たらない。設計上は前提にしていない）。

### 3.2 採用構成と設計判断

| # | 判断 | 内容・理由 | 状態 |
|---|---|---|---|
| T1 | 描画方式 | **明示レンダリング**（`api.js?render=explicit`）を採用。Angular は SPA で、公式も SPA・動的コンテンツには明示を推奨（3.1.1 の 6）。フォームはテンプレート駆動で JSON を送るため、隠し入力（`cf-turnstile-response`）には頼らず `callback` で受け取ったトークンをペイロードに載せる。`response-field: false` を指定して隠し入力の生成を止める | 推奨 |
| T2 | ウィジェットモード | **Managed（推奨）**。公式が推奨し、必要時のみチェックボックスが出る。Invisible はプライバシーポリシーへの Privacy Addendum 参照が条件（3.1.1 の 9）で、UI が出ない分、失敗時の説明が難しい | 推奨（Q3） |
| T3 | 検証結果の分類 | 現行は「拒否」「通信失敗・不正応答」「`success:false`」がすべて 422 になる（§2.9）。Turnstile では次の**三分類**に改める案: ① **拒否（422）** = `missing-input-response` / `invalid-input-response` / `timeout-or-duplicate`（利用者が再チェックすれば直る）、② **一時利用不可（503）** = `missing-input-secret` / `invalid-input-secret` / `bad-request` / `internal-error`、通信失敗、タイムアウト、JSON 以外の応答、HTTP 5xx（運用側の問題。利用者に CAPTCHA をやり直させても直らない）、③ **未設定（503）** = secret 空。いずれも fail-closed（通さない）。②③は利用者向けには同じ「利用不可」文言でよい。エラーコードの意味は 3.1.1 の 3 に従う | 推奨（Q9） |
| T4 | `remoteip` | 任意項目（3.1.1 の 1）。**IP アドレスとして解釈できる場合のみ送る**（`std::net::IpAddr` でパース）。`"unknown"` は送らない（§2.9）。レート制限側の `"unknown"` の扱いは変えない。LB 配下の `X-Forwarded-For` の信頼性は未確認（§2.8）のため、`remoteip` は補助情報であり判定の根拠にしない | 推奨 |
| T5 | `hostname` / `action` の検証 | 公式は「指定があれば確認」を推奨（3.1.1 の 12）。ただしテスト用キーは `hostname:"example.com"` を返す（§3.1.2）ため、固定ホスト名の照合を入れると開発・CI が壊れる。**本課題では実装しない**（現行の `success` のみ判定と同じ水準）。ウィジェット側で `action: 'contact'` を付けておけば、将来の検証追加で追加のフロント改修が要らない | 本課題では見送り（追加する場合は別課題 / Q として再確認） |
| T6 | クライアント側 fail-closed | site key 未設定・`api.js` のロード失敗・`error-callback` 発火時は、**トークンなしで送信させず**、送信ボタンを無効化して利用不可のメッセージを出す。`expired-callback` でトークンを破棄し、再取得まで送信不可にする | 推奨 |
| T7 | テスト用 secret の本番混入ガード | 公式のダミー secret は実測で任意トークンを通した（§3.1.2 #4）。本番で誤設定すると CAPTCHA が無効化される。**`AGRR_ENV` が本番のとき、既知のダミー secret（3.1.1 の 13 の 3 値）を「未設定」として扱う**案（`NotConfigured` → 503）。`routes.rs:30-33` は `RAILS_ENV` / `AGRR_ENV` が無いと `"production"` を返す（環境判定の既定が本番）点に注意。ローカル compose（`AGRR_ENV=development`）では許可する | 提案（Q11） |
| T8 | 旧 reCAPTCHA との併用 | しない（D-2）。互換モード `?compat=recaptcha`（3.1.1 の 14）は使わない。理由: 新規実装で互換の必要が無く、`grecaptcha` グローバルを再定義する副作用を避けるため | 確定 |
| T9 | CAPTCHA 失敗 → フロントの区別 | 新規キー `code` は**追加しない**（D-4〜D-6）。課題 07 の契約に従い、CAPTCHA 拒否（422。トークン欠落を含む）は `{"errors":["Turnstile failure: <error-codes>"],"error_code":"captcha_failed"}`、利用不可（503。secret 未設定・一時利用不可）は `{"errors":["CAPTCHA is not configured"],"error_code":"captcha_unavailable"}`（文言は §3.3.1 の中立化後。`errors[0]` はフロントでは表示せず、`error_code` で文言キーを決める）とする。入力検証の 422 は従来どおり `errors` のみ（`error_code` なし）で、同じ 422 でも `error_code` の有無・値で区別できる。フロントは 07 §3.7 の `apiErrorCode(err)` で判別し、本文の形状（`error` 文字列 vs `errors` 配列）には依存しない。応答の組み立ては 07 §3.6 の `api_error.rs` のヘルパー（`api_error_with_code`）経由 | 確定（Q10 解消。旧キー併記の要否と着手順は Q16） |

### 3.3 名称の決定

#### 3.3.1 ドメインの port 名を reCAPTCHA 固有から中立にする是非

現行のドメインは reCAPTCHA の名前を持つ: `RecaptchaVerifierPort` / `RecaptchaVerifyResult`（`crates/agrr-domain/src/contact_messages/ports/recaptcha_verifier_port.rs:1-15`）、`CreateContactMessageFailureKind::Recaptcha` / `recaptcha()` / `recaptcha_kind()`（`dtos/create_contact_message_failure.rs:9, 31, 59`）、`CreateContactMessageInput.recaptcha_token`（`dtos/create_contact_message_input.rs:11`）、interactor のフィールド `recaptcha_verifier`（`create_contact_message_interactor.rs:17`）と文言 `"reCAPTCHA is not configured"`（`:60`）。

| 観点 | 中立名（例 `CaptchaVerifierPort`）にする | 名前は据え置き（中身だけ Turnstile） | `TurnstileVerifierPort` にする |
|---|---|---|---|
| 名前と実装の一致 | 一致する | **食い違う**（reCAPTCHA と書いて Turnstile を検証。読み手を誤解させる） | 一致するが、ドメインにベンダー名が入る |
| 既存規約との整合 | 既存の ports は**役割名**（`ClockPort` / `LoggerPort` / `TranslatorPort` / `FarmRefreshBroadcastPort` など。`crates/agrr-domain/src/shared/ports/`）で、ベンダー名を持たない。`naming-ules.mdc` は「既存の命名を尊重し、名前を発散させない」 | 現行名を尊重するが、上記の食い違いを生む | 役割名の慣行から外れる |
| 将来のサービス変更 | ドメインを触らずにエッジの具象だけ差し替えられる（ポートの目的そのもの） | 同左だが名前が嘘になる | ドメインの改名が再発 |
| 変更コスト | 参照は 13 ファイル（domain 6・server 6・R4 契約 1。加えてスクリプト 4。§5.7）。ただし**クレート内部の名前**であり、公開 API（HTTP）の形を変えない（ただしヘルスキー・エラー文言は別。下記） | なし | 中立名と同じ |

**推奨: 中立名にする**（Q7）。名称案: `CaptchaVerifierPort` / `CaptchaVerifyResult` / `CreateContactMessageFailureKind::Captcha`（`captcha()` / `captcha_kind()`）/ `CreateContactMessageInput.captcha_token` / interactor の `captcha_verifier` / 文言 `"CAPTCHA is not configured"`。ファイル名は `ports/captcha_verifier_port.rs`。ベンダー固有の名前が許されるのは**エッジの具象**（`crates/agrr-server/src/contact_message_turnstile.rs` の `TurnstileVerifier`、環境変数 `TURNSTILE_*`、リクエストのワイヤ名）に限る。リネームは**振る舞い不変のリファクタ**（既存テストの名前だけを変える）として、Turnstile 実装より先に別コミットで行う（§7）。

同時に決める公開面の名前（同じ Q7 の対象。API を消費する既存クライアントはリポジトリ内に見当たらないが、外部の監視等は未確認）:

- ヘルスの JSON キー `recaptcha_configured`（`routes.rs:45`）→ `captcha_configured`。R4 `contracts.rs:4466-4473` を追随。リポジトリ内の他の消費者は `docs/spec-defects/09` の記述のみ（フロントに 0 件）。外部監視が旧キーを参照していないかは**未確認**。旧キーを併記する互換は作らない（`no-convenience-tech-debt.mdc`）。
- ヘルスの警告文 `"RECAPTCHA_SECRET_KEY is unset; contact messages are rejected"`（`routes.rs:36`）→ `"TURNSTILE_SECRET_KEY is unset; contact messages are rejected"`（環境変数名は具象なので Turnstile 固有でよい）。
- エラー本文の文言 `"reCAPTCHA ..."`: ドメイン由来（`"reCAPTCHA is not configured"`）は `"CAPTCHA is not configured"`、エッジ由来（`"reCAPTCHA failure: ..."`）は `"Turnstile failure: <error-codes>"` とする。R4 が `json["error"]` の `contains("reCAPTCHA")` で断言している（`contracts.rs:4502-4506, 4595`）ため、断言は `error_code`（T9）と `errors[0]` へ移す（`error` は 07 の S2 で撤去されるため、新規・改修する断言は `error` を読まない）。

#### 3.3.2 リクエストフィールド名とサーバー側 DTO 名

Turnstile の隠し入力の既定名は `cf-turnstile-response`（3.1.1 の 7）。ただし本フォームはネイティブの form 送信ではなく JSON の `POST` であり、この名前に**従う技術的な必要は無い**。

| 案 | ワイヤ（JSON キー） | エッジ DTO（`ContactMessageBody`） | ドメイン入力 | 長所 | 短所 |
|---|---|---|---|---|---|
| **A（推奨）** | `cf-turnstile-response` | `#[serde(rename = "cf-turnstile-response")] cf_turnstile_response: Option<String>` | `captcha_token` | Cloudflare の標準名（公式の例と同じ）。ベンダー固有名はエッジに閉じ、ドメインは中立 | 既存の JSON キーは snake_case（`name` / `email` / `subject` / `message` / `source` / `recaptcha_token`: `contact_messages.rs:31-36`）で、ハイフン付きキーは異質。OpenAPI（課題 08）ではクォートして記述 |
| B | `captcha_token` | `captcha_token: Option<String>` | `captcha_token` | 既存の snake_case と統一。**API 契約がベンダー中立**（将来サービスを変えても契約が変わらない）。`recaptcha_token` からの機械的置換 | Cloudflare 公式の名前とは異なる（マッピング不要のため実害は小さい） |

推奨は A（ユーザーが挙げた名前で、Cloudflare の標準名に一致）。B も同等に実現可能で、契約の中立性では B が優れる。決定は Q8。

- どちらの案でも、**旧 `recaptcha_token` は受け付けない**（フロントは元々送っていないため後方互換の必要が無い。`serde` は未知フィールドを無視するので、旧キーを送られても Turnstile のトークン欠落として 422 になる）。
- フロントのドメインペイロードは、案によらず**中立名 `captcha_token`** を持たせ、ゲートウェイ（`http-contact-gateway.service.ts:16-18`）でワイヤ名へ写像する（案 A の場合のみ写像が要る。F3 で固定）。ペイロード型にベンダー固有のキー名（ハイフン付き）を持ち込まないため。

#### 3.3.3 環境変数・キーの配布

| 名前 | 置き場所 | 用途 | 備考 |
|---|---|---|---|
| `TURNSTILE_SECRET_KEY` | サーバー（`agrr-server`）の環境変数。本番は Secret Manager 経由（`--set-secrets`）、ローカル compose は `.env` | `siteverify` の `secret` | 公式の例も `TURNSTILE_SECRET_KEY`（3.1.1 の 13 の環境設定例）。未設定→503（fail-closed） |
| `TURNSTILE_VERIFY_URL` | サーバーの環境変数（任意） | `siteverify` の URL を上書き（R4 のモック用） | 既定 `https://challenges.cloudflare.com/turnstile/v0/siteverify`。現行 `RECAPTCHA_VERIFY_URL` と同じ役割（`contact_message_recaptcha.rs:18-19`） |
| `TURNSTILE_SITE_KEY` | フロントのデプロイ時注入（`.env.gcp.frontend` → `window.TURNSTILE_SITE_KEY`）と `environment.turnstileSiteKey` のフォールバック | ウィジェットの `sitekey` | site key は公開情報。既存の Ads 設定方式を踏襲（§5.3） |

### 3.4 ユーザー確認事項（Turnstile 前提）

| # | 確認事項 | 理由・現状 |
|---|---|---|
| Q1 | **Cloudflare アカウントとウィジェットの登録・キー発行**（人手の作業）。ホスト名（本番 `agrr.net`。サブドメインは自動的に許可される: 3.1.1 の 11）、テスト環境（`agrr-test.net` 等。実際のホスト名は未確認）を含めるか。本番とテストでウィジェットを分けるか。Free プランは「20 ウィジェット・1 ウィジェット 10 ホスト名」まで | リポジトリに Cloudflare の設定は無い（§0）。開発（`localhost`）はダミーキーで足りる（3.1.1 の 13） |
| Q2 | **本番 secret の Secret Manager 登録**と、Cloud Run の実行サービスアカウントへの参照権限（`secretAccessor`）の付与。secret 名は未確定（案: `turnstile-secret-key`） | 人手の作業。既存の `scheduler-auth-token` の付与状況は本調査では未確認（`gcloud` が無い） |
| Q3 | **ウィジェットモード**: Managed（推奨）/ Non-Interactive / Invisible。Invisible を選ぶ場合はプライバシーポリシーで Turnstile Privacy Addendum を参照する必要がある（3.1.1 の 9） | UX と説明責任の判断 |
| Q4 | **プライバシー表記**: プライバシーポリシー（`privacy` ブロック、`ja.json:4048-4106` ほか 3 ロケール）に Turnstile / Cloudflare の利用を追記するか、文言、Privacy Addendum へのリンク、`last_updated` の更新 | 現状は記載なし（§2.2）。Managed での表記義務は未確認（3.1.3）。法務・方針判断 |
| Q5 | **旧 `RECAPTCHA_SECRET_KEY` の撤去タイミング** | 提案: コード上の参照（`crates/`・`scripts/`）は**実装 PR で同時に全撤去**（併用しない: D-2）。本番の Cloud Run や Secret Manager に旧 secret / 環境変数が**もし存在すれば**、Turnstile の本番動作確認（§6.6）が済んだ後に運用作業として削除する（存在の有無は未確認: §2.6）。Google 側の reCAPTCHA キーの削除は不要なら放置で害は無いが、発行済みなら整理を判断 |
| Q6 | **Cloudflare を DNS / プロキシに使う予定があるか**。**本件とは独立**: Turnstile はドキュメント上、他の Cloudflare サービス不要で単独利用できる（3.1.1 の 11）。現状の経路は GCP LB（`scripts/agrr-lb-backend-security-headers.yaml` と `scripts/apply-lb-security-response-headers.sh` が LB のバックエンドを対象にする）。将来 Cloudflare をプロキシにする場合は、クライアント IP の取得（`X-Forwarded-For` 先頭要素の採用: §2.8、`CF-Connecting-IP` の扱い）と CSP の再検討が別途必要になる。予定が無ければ本件は影響を受けない | 独立事項の確認 |
| Q7 | ドメインの port・失敗種別・入力フィールド・ヘルスキー・文言を**中立名へ改める**か（推奨: する。§3.3.1） | 公開面（ヘルスの `captcha_configured`、エラー文言）が変わる。外部監視の参照は未確認 |
| Q8 | リクエストのワイヤ名: A `cf-turnstile-response`（推奨・ユーザー指定の名前）か B `captcha_token`（§3.3.2） | API 契約の追加。課題 08 の OpenAPI に反映 |
| Q9 | 検証結果を**三分類**（拒否 422 / 一時利用不可 503 / 未設定 503）に改めてよいか（§3.2 T3）。現行は障害も 422 | ドメインの結果型に 1 種類増える。fail-closed は変わらない |
| Q10 | **解消（07 に従う）**: 新規 `code` は追加せず、07 の契約（`errors` 配列 + 既存の `error_code`）に合わせる。値は `captcha_failed` / `captcha_unavailable`（§3.2 T9、D-4〜D-6、§5.1） | README 第 2 回「errors」・第 3 回「削除」、07 §0.2・§0.3・§10。旧キー併記の要否と着手順は Q16 に分離 |
| Q11 | テスト用 secret の本番混入ガード（§3.2 T7）を入れるか | 実測で任意トークンが通った（§3.1.2）。入れない場合は運用手順（§6.6）のみで担保 |
| Q12 | 本番 LB へ CSP ヘッダーを適用する作業（`scripts/apply-lb-security-response-headers.sh`）の実施者とタイミング | 本番操作。CSP は Report-Only のため適用が遅れても送信は阻害されない（§5.5） |
| Q13 | E2E スモーク（`operation-smoke.spec.ts`）を CI スクリプトに含めるか。含める場合の Turnstile との接続方針（スタブか公式ダミーキーの実通信か） | 現状 CI に含まれない（§2.5）。CI からの外部通信の可否は未確認 |
| Q14 | 問い合わせ受信後の運営側の受信経路（`queued` 行を誰がどう読むか） | §2.8。送信が成功しても運営に届かない状態が残る可能性。本課題に含めるか別課題にするか |
| Q15 | **429 `rate_limit` の専用文言をどちらの課題で扱うか**。07 §10 は「専用文言は本書の契約の上で 02 が扱う」とし、本書 §5.4 は「07 で扱う」としており、**相互に委譲して担当が決まっていない**。現状、フロントは 429 を `send_failed`（「送信に失敗しました。」）に丸める（`send-contact-message.usecase.ts:49-58` は 422 以外を区別しない）。07 の適用後、429 の本文は `{"errors":["rate_limit"]}`（`error_code` なし。07 §10 (5)、A5） | 既定: 本課題では追加しない（現行の `send_failed` を維持。§5.4 のとおり）。追加する場合の案: 状態コード 429 を判別して `contact_form.errors.rate_limited` を ja / en / in に追加（i18n の範囲が広がる） |
| Q16 | **着手順と旧キー併記（`Legacy`）**。07 §10 (6) は「02 を 07 の手順 2（`api_error.rs`）の後に実装し、初めから `errors` + `error_code` で書く」ことを推奨する。一方 07 §10 (2) は「S1 の間は `Legacy::Error` により `error` も併記される」としており、02 が書き換える CAPTCHA 失敗・503 は現行も `error` を返す既存の応答（`contact_messages.rs:65-72`）なので、併記対象になるか 02 が最終形で上書きするかが**未確定**。外部の非ブラウザクライアントが問い合わせ API の `error` を読んでいるかは未確認（07 §3.5.2 の外部依存確認は Masters を対象とし、認証不要の `contact_messages` はログでしか確認できないと 07 が述べている） | 既定: 07 §10 (6) の推奨に従い、`api_error.rs` の後に最終形（旧キー併記なし）で実装する。これにより 02 の新規応答は S2 の撤去対象に加わらない。07 側が contact を P6（外部依存確認）の対象に含めるかは 07 の判断。02 のフロント変更（手順 5）は 07 の手順 7（`core/api-error-message.ts`）の後 |
| Q17 | **`contact_messages` の契約（OpenAPI）と成功応答型の是正の担当**。(a) `docs/api/openapi.yaml` に `contact` の記載が無い（§4）。08 は 02 を「Masters API と無関係・依存なし」と記載し（`08-openapi-gaps.md:1047`）、08 に contact の記述は見当たらない一方、07 の `Error` スキーマ更新は 08 側で行う前提（07 §10）で、11 は 08 が契約として記載する前提（`11-low-priority-misc.md:385`）。誰が `contact_messages` を OpenAPI に載せるかが決まっていない。(b) 成功応答型の是正（本書 §7 手順 1）は、11 の項目 3 案 A と同一の変更（`ContactMessageRecord` の縮小）で、11 側は案 A の採否が確認事項のまま（`11-low-priority-misc.md:181, 184`）。どちらで実施するか決まっていない | 既定: (a) 本課題では OpenAPI を追加せず、確定契約を 08 に渡すのみ（§10）。(b) 本書の手順 1 で実施し、11 の項目 3 は 02 の完了後に不要化する（先にマージされた側にもう一方が追従する） |

---

## 4. 影響範囲

| 領域 | 影響 |
|---|---|
| ユーザー向け画面 | `/contact`、`/en/contact`（`frontend/src/app/routes/pages.routes.ts`、`locale-en.routes.ts`）。About / Terms / Privacy / footer / navbar から同ページへ誘導されている（`grep contact` で確認したファイル群。個別の挙動は未読） |
| 事前レンダリング | `contact` は prerender 対象（`public-prerender-routes.ts:5`）。ウィジェットの初期化は**ブラウザ限定**にする必要がある |
| API 契約 | `POST /api/v1/contact_messages` のリクエスト（旧 `recaptcha_token` → Turnstile トークン。名前は Q8）、エラー応答（`errors` + `error_code`。07 の契約。D-4〜D-6）、`GET /api/v1/health` のキー（`recaptcha_configured` → 中立名。Q7）。`docs/api/openapi.yaml` に `contact` の記載が無い（`grep -c contact` = 0）ので契約文書は存在しない → 課題 08 |
| バックエンド | ドメイン（port・失敗種別・入力・interactor の名前変更と結果分類）、エッジ（検証器の置換・DTO・ヘルス・状態）。詳細は §5.1 |
| デプロイ | サーバー: `_agrr-server-cloud-run.sh`（`TURNSTILE_SECRET_KEY` の secret 注入）。フロント: `gcp-frontend-deploy.sh`（site key 注入）。Docker 開発: `docker-compose.yml`、`env.example` |
| セキュリティヘッダー | CSP Report-Only の更新（§5.5） |
| テスト | ドメイン、エッジ単体、R4 契約（モックとシェル契約）、フロント unit / i18n カタログ、E2E スモーク、a11y・layout スモーク（`/contact` を含む。`frontend/e2e/smoke/a11y-smoke-lib.ts`、`layout-conformance-bindings.mjs` が contact を参照。詳細な対象条件は未読） |
| ドキュメント | プライバシーポリシー文言（Q4）、`.cursor/skills/deploy-frontend/SKILL.md` の `.env.gcp.frontend` 項目、`env*.example`。他課題文書の reCAPTCHA 言及（`docs/spec-defects/{01,03,04,05,06,07,08,09,10,11}` と `README.md` の 02 行の説明）は本書の編集範囲外で、追随が必要 |
| 運用 | Cloudflare のウィジェット・キー管理、本番 secret の登録、デプロイスクリプトが secret を落とさないことの保証（§2.6）、旧 secret の撤去（Q5） |

---

## 5. 対応方針

前提: 実装は Q1〜Q4（キー発行・Secret Manager・モード・プライバシー）の回答後に着手する（根拠ゲート）。以下は §3.2 の推奨案（T1〜T9、Q7=中立化、Q8=案 A、Q9=三分類）と、07 の契約（D-4〜D-6。`errors` + `error_code`）を前提とした変更点である。回答が異なる場合は該当行を読み替える。

### 5.1 バックエンド（層ごとの変更）

`ARCHITECTURE.md` / LAYER-RULES の流れ（Axum ハンドラ → 入力 DTO → ドメインの interactor → gateway / port → presenter）に従う。ベンダー固有の名前は**エッジの具象**に限る（§3.3.1）。

| 層 | ファイル | 変更 |
|---|---|---|
| domain: port | `crates/agrr-domain/src/contact_messages/ports/recaptcha_verifier_port.rs` → `captcha_verifier_port.rs`、`ports/mod.rs:3, 9` | `RecaptchaVerifierPort` → `CaptchaVerifierPort`。結果型 `RecaptchaVerifyResult { Ok, Error(String), NotConfigured }` → `CaptchaVerifyResult { Ok, Rejected(String), Unavailable(String), NotConfigured }`（Q9 を採用する場合。不採用なら `Error(String)` を維持）。ファイル冒頭の Ruby 由来コメント（`RecaptchaVerifier`）は実態に合わせて更新 |
| domain: DTO | `dtos/create_contact_message_failure.rs:9, 31, 59`、`dtos/create_contact_message_input.rs:11, 22, 31` | `Recaptcha` → `Captcha`、`recaptcha()` → `captcha()`、`recaptcha_kind()` → `captcha_kind()`、`recaptcha_token` → `captcha_token` |
| domain: interactor | `interactors/create_contact_message_interactor.rs:8, 17, 22, 32, 36, 53-69` | フィールド `recaptcha_verifier` → `captcha_verifier`、順序（レート制限 → CAPTCHA → gateway.create）は変えない。`NotConfigured` と `Unavailable(msg)` は `Unavailable` 失敗（文言 `"CAPTCHA is not configured"` / 受け取った文言）、`Rejected(msg)` は `Captcha` 失敗 |
| edge: 検証器 | `crates/agrr-server/src/contact_message_recaptcha.rs` → `contact_message_turnstile.rs`、`lib.rs:26` | `TurnstileVerifier`。`TURNSTILE_SECRET_KEY` / `TURNSTILE_VERIFY_URL`（既定は Turnstile の `siteverify`）を読む。`secret` / `response` / `remoteip`（IP として解釈できるときのみ）を form 送信（骨格は現行 `:85-94` を流用）。応答は `success` と `error-codes` のみ解釈（§3.2 T5）。**エラーコードを三分類**（§3.2 T3）。HTTP 非 2xx でも JSON 本文があれば解釈する（400 の `invalid-input-secret` 等）。JSON でない応答・通信失敗・タイムアウトは `Unavailable`。明示タイムアウトを設定（値は実装時決定）。token 空は `Rejected("Turnstile token is required")`。エラー文言の `"reCAPTCHA ..."` は `"Turnstile ..."` へ。起動時 `tracing::warn!` は `TURNSTILE_SECRET_KEY is unset; ...` |
| edge: 状態・合成 | `state.rs:3, 54, 119`、`test_support.rs:11, 293` | フィールド `recaptcha_verifier: Arc<RecaptchaVerifier>` → `captcha_verifier: Arc<TurnstileVerifier>`（`from_env()` は維持） |
| edge: ヘルス | `routes.rs:33-46` | `recaptcha_configured` → `captcha_configured`（Q7）、警告文 `"TURNSTILE_SECRET_KEY is unset; contact messages are rejected"` |
| edge: ハンドラ・DTO | `contact_messages.rs:29-37, 101-133` | `ContactMessageBody` に Turnstile トークンのフィールド（Q8: 案 A なら `#[serde(rename = "cf-turnstile-response")] cf_turnstile_response`）。入力 DTO の `captcha_token` へ詰め替え。`remote_ip` の詰め方（`:107`）は維持し、検証器側で IP として解釈できない値を送らない |
| edge: presenter（HTTP 形状） | `contact_messages.rs:58-79`（`failure_response`） | `Captcha` 失敗 → 422 `{"errors":[msg],"error_code":"captcha_failed"}`、`Unavailable` → 503 `{"errors":[msg],"error_code":"captcha_unavailable"}`。07 §3.6 の `api_error_with_code`（`crates/agrr-server/src/api_error.rs`）経由で組み立て、単数の `error` と新規 `code` は書かない（D-4〜D-6。旧キー併記の要否は Q16）。`RateLimit`（現行 `{"error":"rate_limit"}`）と `Validation`（`errors` のまま）は 07 の変更範囲で、本書は変更しない。プレゼンタは HTTP 形状のみを決める（R6）ので層違反にならない |
| edge: 本番混入ガード | `contact_message_turnstile.rs` | 既知のダミー secret を本番で `NotConfigured` とする（Q11 を採用する場合。T7） |
| 契約・スクリプト | `scripts/recaptcha-contract-mock.py` → `captcha-contract-mock.py`、`run-rust-contract-tests.sh:260-274, 294, 308-354`、`run-rust-contract-contact-shell-lib.mjs`（+ `.test.mjs`）、`crates/agrr-r4-contract/tests/contracts.rs` | §5.7 の一覧と §6 の RED |

理由（識別子に `error_code` を使う）: 現状 422 は CAPTCHA 失敗とバリデーション失敗の両方で使われ、`error`（英語の可変文字列）と `errors`（配列）の形状で見分けるしかない（`contact_messages.rs:65-76`）。503 も Cloud Run 基盤起因と区別できない。文字列一致や本文の形状で判別するのは脆い。07 の契約では失敗本文が常に `errors` 配列になり、形状では区別できなくなるため、機械可読な識別子を `error_code` に置く。識別子の名前を新規の `code` にすると、既存の `error_code`（`masters_auth.rs:98`、blueprint 系）との 2 系統になるため、既存名に統一する（D-4〜D-6。Q10 は解消）。

### 5.2 フロントエンド（`frontend/src/app`）

依存方向は `components → usecase → domain`、HTTP と外部スクリプトは `adapters/`（`ARCHITECTURE.md` の Frontend 節）。外部の npm パッケージは追加しない（`api.js` は公式 URL から動的ロードする。3.1.1 の 6 のとおり、バンドルやプロキシはしない）。`turnstile` グローバルの型はアダプタ内に最小限を宣言する。

| 層 | ファイル | 変更 |
|---|---|---|
| domain | `domain/contact/contact-message.model.ts` | ペイロードに `captcha_token` を追加。`validatePayload` が空 token を `contact_form.validation.captcha_required` で拒否。`ContactMessageRecord` を**サーバー契約に合わせて** `{ id: number; status }` のみの作成結果型へ縮小（案 a）。`email` / `message` / `created_at` / `sent_at` を除去 |
| usecase | `usecase/contact/contact-gateway.ts`、`send-contact-message.dtos.ts` | 戻り値型と成功 DTO を縮小型へ。`created_at` / `sent_at` を除去 |
| usecase | `usecase/contact/send-contact-message.usecase.ts` | `toErrorDto`（`:49-58`）を、07 §3.7 の `apiErrorCode(err)`（`core/api-error-message.ts`。未作成）で判別する形に: `error_code` が `captcha_failed` → `contact_form.errors.captcha_failed`、`captcha_unavailable` → `contact_form.errors.captcha_unavailable`、`error_code` なしの 422 → `validation_failed`、それ以外 → `send_failed`。本文の形状（`error` / `errors`）や旧キーは読まない。到達不能な `status === 'failed'` 分岐（`:32-35`）を削除。着手は 07 の手順 7（共通関数の導入）の後（Q16） |
| usecase | `usecase/contact/captcha-widget.port.ts`（新規） | ウィジェットの描画・リセット・破棄・利用可否のポートと `InjectionToken`。コンポーネントがアダプタを直接 import しないための境界（既存の `contact-form.providers.ts:1-12` の束ね方に従う） |
| usecase | `usecase/contact/contact-form.providers.ts` | ポートの実装を提供 |
| adapters | `adapters/contact/http-contact-gateway.service.ts` | 応答マッピング（`:19-31`）を `{ id, status }` のみに。ペイロードの `captcha_token` をワイヤ名（Q8。案 A は `cf-turnstile-response`）へ写像して POST |
| adapters | `adapters/contact/turnstile-widget.adapter.ts`（新規） | `https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit` の動的ロード（`google-analytics.service.ts:191-199` の方式を踏襲し、`isPlatformBrowser` でブラウザ限定、多重ロード防止。URL は公式のまま固定）。`turnstile.render(host, { sitekey, action: 'contact', language, theme: 'auto', size, 'response-field': false, callback, 'error-callback', 'expired-callback', 'timeout-callback' })`、`reset` / `remove`。`language` は `documentHtmlLang`（`app-locale.ts:18-20`。`ja` / `en` / `hi`。3 つとも対応言語: 3.1.1 の 8）。ロード失敗・`error-callback`・`unsupported-callback` を「利用不可」として通知 |
| core | `core/turnstile-runtime-config.ts`（新規） | `window.TURNSTILE_SITE_KEY` を優先し `environment.turnstileSiteKey` にフォールバック（`google-ads-runtime-config.ts:12-28` と同型）。空文字なら「利用不可」 |
| core | `environments/environment*.ts`（`environment.ts`、`environment.prod.ts`、`environment.gcp-test.ts`） | `turnstileSiteKey` を追加。`environment.ts`（`ng serve`）は公式ダミー `1x00000000000000000000AA`、`environment.prod.ts` は空またはデプロイ注入（§5.3）、`environment.gcp-test.ts` は Q1 の回答による |
| components | `components/contact-form/contact-form.component.ts`（＋必要なら同ディレクトリの子コンポーネント） | 本文と送信ボタンの間（現テンプレート `:99-102` の間）にウィジェットのホスト要素を置く。トークン保持、送信時に `captcha_token` をペイロードへ、**送信の成否にかかわらず送信後にウィジェットをリセット**（トークンは 1 回限りで、サーバーは CAPTCHA 検証後に gateway を呼ぶため、gateway が失敗してもトークンは消費される: `interactor:53-71`、3.1.1 の 4）、`expired-callback` でトークン破棄、利用不可なら送信無効化とメッセージ表示。言語切替時は `remove` → `render`（実挙動は未確認: 3.1.3） |
| i18n | `assets/i18n/{ja,en,in}.json` | §5.4 |
| e2e | `frontend/e2e/smoke/operation-smoke.spec.ts` | §6.5 |

UI 構成規約（`docs/design/UI-COMPOSITION-RULES.md`）への適合:

- ウィジェットのホストは L3 ページ配下のフォーム内に置く。ページテンプレートにレイアウト CSS を直書きしない。既存の `form-card__field` / `form-card__actions` クラス（`contact-form.component.ts:46, 102`）と `_form-primitives.css` の範囲で構成する。
- L1 Pattern は Gateway / UseCase を呼べない規則があるため、スクリプトロードを伴うウィジェットは `components/shared/patterns/` に置かない。`components/contact-form/` 配下に閉じる。
- `check:ui-composition` の禁止パターン（規約の「Forbidden patterns」節）に触れないこと（実行は未実施）。
- 事前レンダリング時にウィジェットを初期化しない（SSR 安全）。
- ウィジェットのサイズは `size`（`normal` 300px / `flexible` 幅 100%（最小 300px）/ `compact` 150px: 3.1.1 の 7 の出典ページ）。フォーム幅とモバイルの見え方は実装時に決める（未確認）。

### 5.3 site key の配布方法（既存 Ads 設定方式を踏襲）

| 案 | 内容 | 評価 |
|---|---|---|
| **1. デプロイ時 `window.TURNSTILE_SITE_KEY` 注入 + `environment` フォールバック（推奨）** | `gcp-frontend-deploy.sh` に `TURNSTILE_SITE_KEY`（`.env.gcp.frontend`）を追加し、`ADS_ASSIGN` と同じ方式で `INJECT_SNIPPET` に含める（`:69-71, 213-223`）。フロントは `window` を優先、`environment` にフォールバック（Ads と同型: `google-ads-runtime-config.ts:12-28`） | 既存の Ads 用と同型（実装統一）。site key は公開情報なので露出は問題ない。再ビルド不要。サーバー secret との組の不一致は自動検知できない → 運用手順で担保（§6.6） |
| 2. `environment.prod.ts` に固定値 | 値をコミット | 前例あり（本番の Ads ID が `environment.prod.ts:7` にコミット済み）。単純だが、キー更新にビルドが要る。環境別（gcp-test）に分けにくい |
| 3. サーバー API で配布 | ヘルスまたは新エンドポイントで site key を返す | secret との一貫性は最良だが、公開 API 面と OpenAPI（課題 08）を増やす。サーバーにも `TURNSTILE_SITE_KEY` を持たせる必要がある |

推奨は 1（2 の併用可）。site key が空のときはフロントが「利用不可」として送信を止める。

注意（デプロイ経路）: `frontend-deploy.yml` の `Run deploy script` は `API_BASE_URL` 等の環境変数だけを渡し（`.github/workflows/frontend-deploy.yml:69-77`）、`.env.gcp.frontend` を作成するステップは無い。一方 `gcp-frontend-deploy.sh` は env ファイルが無いと停止する（`:49-56`。`.env.*` は `.gitignore:15`）。したがって**この CI 経路で `deploy` が成功するかは未確認**であり、site key の注入は手動デプロイ（`.env.gcp.frontend`）が主経路と想定される。CI 経路を使う場合は workflow への `TURNSTILE_SITE_KEY` の追加も要る（本課題の範囲で扱うか要確認）。

### 5.4 i18n キー（ja / en / in）

既存の `contact_form` ブロックは `ja.json:1529-1551`、`en.json:219-241`、`in.json:1292-`。`in` は Hindi。追加するキー案:

| キー | 用途 |
|---|---|
| `contact_form.captcha.aria_label` | ウィジェット領域のラベル（a11y） |
| `contact_form.validation.captcha_required` | 検証未完了のまま送信 |
| `contact_form.errors.captcha_failed` | サーバーが検証失敗（422 + `error_code: "captcha_failed"`）。再確認を促す |
| `contact_form.errors.captcha_unavailable` | site key 未設定 / スクリプト読み込み失敗 / サーバー未設定・一時利用不可（503 + `error_code: "captcha_unavailable"`）。時間をおく旨または別手段の案内 |

429（`rate_limit`）専用文言は、本書の既定では追加しない（担当が 07 と相互委譲になっているため未確定: Q15）。

`frontend/src/app/core/i18n/contact-form-locale.catalog.spec.ts` の `CONTACT_FORM_KEYS`（`:17-33`）へ同キーを追加して 3 ロケールを網羅する。プライバシーポリシーへの追記（Q4 が「追記する」の場合）は `privacy` ブロック（`ja.json:4048-4106`、`en.json:4012`、`in.json:3761`）に節を追加し、`last_updated` を更新する（節番号の振り直しが要る。`section9` が「お問い合わせ」）。

### 5.5 CSP / `security_headers.rs` への影響

| 事実 | 根拠 |
|---|---|
| CSP は**Report-Only**のみ（enforce ではない）。`report-uri` / `report-to` ディレクティブは無い | `crates/agrr-server/src/security_headers.rs:12-19, 35-39` |
| 現行 `script-src` は `'self' 'unsafe-inline' 'unsafe-eval'` と GTM / GA のみ。`connect-src` は `'self'` と GA / GTM。`frame-src` の指定は無く `default-src 'self'` にフォールバックする | 同 `:13-19` |
| 同じ値が `scripts/agrr-security-response-headers.yaml` に複製されている（`:8`）。LB 側は `agrr-frontend-backend` 等に適用される | `scripts/agrr-security-response-headers.yaml`、`scripts/agrr-lb-backend-security-headers.yaml` |
| **SPA の HTML に付くのは LB バックエンドバケットのヘッダーで、agrr-server の CSP ミドルウェアは API 応答にのみ付く**（Turnstile を読み込むのは SPA 側） | 上記 2 ファイルの構成から。LB の実設定値そのものは未確認 |
| 整合検証: `scripts/verify-security-response-headers-lib.mjs` はヘッダー名・バックエンド名・Rust の定数名の存在を見る（値は比較しない）。CI で `node --test scripts/verify-security-response-headers.test.mjs` が走る | `scripts/verify-security-response-headers-lib.mjs:4-23`、`.github/workflows/frontend-test.yml:155` |

Turnstile 向けの変更（公式の要件: 3.1.1 の 10。公式ドキュメントでの再確認は実装時に行う）:

- `script-src` に `https://challenges.cloudflare.com` を追加する。
- `frame-src https://challenges.cloudflare.com` を**新設**する（現状 `frame-src` が無く `default-src 'self'` にフォールバックするため、ウィジェットの iframe は明示許可が要る）。
- `connect-src`: 公式は通常モードでは要求していない（プリクリアランス使用時のみ `'self'`）。ユーザーの指示にあった `connect-src` への追加は、**公式要件としては確認できなかった**ため、既定では追加しない。Report-Only の違反をブラウザで確認して、必要と分かった場合のみ追加する（3.1.3）。
- nonce 方式は採用しない。現行 `script-src` は `'unsafe-inline'` を含み、nonce を導入すると CSP3 対応ブラウザで `'unsafe-inline'` が無効になり既存のインラインスクリプトに影響する（CSP 仕様の理解に基づく。本調査では実機確認していない）ため、オリジン許可方式とする。
- 変更箇所は**同期して 2 か所**: `security_headers.rs` の `CONTENT_SECURITY_POLICY_REPORT_ONLY` と `scripts/agrr-security-response-headers.yaml`。LB への反映は本番操作（Q12）で、`scripts/apply-lb-security-response-headers.sh` を使う（実行はユーザー判断）。
- Report-Only のため**現状のままでも送信自体は阻害されない**。ただし enforce へ移行する際に Turnstile が壊れないよう、同時に許可を足しておく。

### 5.6 設定・デプロイ・ドキュメント

| ファイル | 変更 |
|---|---|
| `.cursor/skills/deploy-server/scripts/_agrr-server-cloud-run.sh` | 本番は `--set-secrets` に `TURNSTILE_SECRET_KEY=<secret名>:latest` を追加（`:149`）。現行は `--set-secrets "SCHEDULER_AUTH_TOKEN=scheduler-auth-token:latest"` の 1 指定なので、同一フラグ内でカンマ区切りにする（`gcloud` の `--set-secrets` の複数指定の書式は仕様の理解に基づく。本環境に `gcloud` が無く未確認）。test モードは既存の `SCHEDULER_AUTH_TOKEN` と同様に環境変数から env ファイルへ（`:121-124` の方式）。secret を落とさないことの保証が目的 |
| `.cursor/skills/deploy-frontend/scripts/gcp-frontend-deploy.sh` | `TURNSTILE_SITE_KEY` を読み、`INJECT_SNIPPET` へ注入（`:69-71, 213-223`）。冒頭のコメント（`:3-16`）と `.cursor/skills/deploy-frontend/SKILL.md` の `.env.gcp.frontend` 項目を更新 |
| `docker-compose.yml` | `agrr-server` の environment に `TURNSTILE_SECRET_KEY=${TURNSTILE_SECRET_KEY:-...}`（`:28-41`）。既定値を公式ダミー secret `1x0000000000000000000000000000000AA` にするか空にするかは要判断（ダミーは開発では便利だが、実測で任意トークンを通す: §3.1.2。`AGRR_BACKDOOR_TOKEN` は既に compose に既定値がある前例: `:40`）。フロント `ng serve` の site key はダミー（`environment.ts`）で、両者が揃って初めて開発環境で送信できる |
| `env.example` | `TURNSTILE_SECRET_KEY`（サーバー）と `TURNSTILE_SITE_KEY`（フロントのデプロイ / 開発）の説明を追加（公式ダミーキーの値と「本番に使わない」注意を併記） |
| `env.gcp.example` | 本番は Secret Manager で管理する旨（`SCHEDULER_AUTH_TOKEN` の注記 `:56-57` と同型） |

`crates/*` を変更した場合、Docker での検証前に `.cursor/skills/dev-docker/scripts/rebuild-restart.sh` が必須（`docker compose restart` は不可。ワークスペースの規約）。

### 5.7 既存 reCAPTCHA 関連の名称・テスト・設定の置換一覧

`rg -il recaptcha`（`docs/spec-defects/` を除く）でヒットするのは `crates/` と `scripts/` の **17 ファイル**のみ。**フロント、`docker-compose.yml`、`env*.example`、デプロイスクリプト、`docs/`（`spec-defects` 以外）には 0 件**であり、それらは「置換」ではなく「Turnstile 用の新規追加」になる（§5.6）。件数は `rg -ci recaptcha`（大文字小文字を区別しない一致行数）。

| 現行 | 置換後（推奨） | 場所（行数） |
|---|---|---|
| `RecaptchaVerifierPort` / `RecaptchaVerifyResult`（`Error` → `Rejected` / `Unavailable`） | `CaptchaVerifierPort` / `CaptchaVerifyResult` | `crates/agrr-domain/src/contact_messages/ports/recaptcha_verifier_port.rs`（6）→ `captcha_verifier_port.rs`、`ports/mod.rs`（2） |
| `CreateContactMessageFailureKind::Recaptcha` / `recaptcha()` / `recaptcha_kind()` | `Captcha` / `captcha()` / `captcha_kind()` | `dtos/create_contact_message_failure.rs`（5） |
| `CreateContactMessageInput.recaptcha_token` | `captcha_token` | `dtos/create_contact_message_input.rs`（3） |
| interactor の `recaptcha_verifier` と `"reCAPTCHA is not configured"` | `captcha_verifier` と `"CAPTCHA is not configured"` | `interactors/create_contact_message_interactor.rs`（12） |
| ドメインテスト（`NoopRecaptcha` / `BadRecaptcha` / `UnconfiguredRecaptcha`、`calls_on_failure_when_recaptcha_*`、`Some("reCAPTCHA is not configured")`） | `Captcha` 系へ改名、文言更新、`Unavailable` / `Rejected` の新ケース | `crates/agrr-domain/test/contact_messages/interactors_create_contact_message_interactor_test.rs`（29。`:6-10, :245-316`） |
| `RecaptchaVerifier`、`RECAPTCHA_SECRET_KEY`、`RECAPTCHA_VERIFY_URL`、既定 URL、`"reCAPTCHA ..."` 文言、スレッド名 `recaptcha-verify`、単体テスト | `TurnstileVerifier`、`TURNSTILE_SECRET_KEY`、`TURNSTILE_VERIFY_URL`、Turnstile の `siteverify` URL、`"Turnstile ..."` 文言、`turnstile-verify`、テストを Turnstile 応答（`error-codes` の分類）へ | `crates/agrr-server/src/contact_message_recaptcha.rs`（37）→ `contact_message_turnstile.rs`、`lib.rs:26`（1） |
| `state.recaptcha_verifier` | `state.captcha_verifier` | `state.rs`（3）、`test_support.rs`（2） |
| ヘルス `recaptcha_configured` と警告文 | `captcha_configured` と `TURNSTILE_SECRET_KEY is unset; ...` | `routes.rs:33-46`（4） |
| リクエスト DTO の `recaptcha_token`、`failure_response` の `Recaptcha` 分岐、単体テスト内の `"reCAPTCHA is not configured"` | Turnstile トークンのフィールド（Q8）、`Captcha` 分岐と `errors` + `error_code`（D-4〜D-6）、文言更新 | `crates/agrr-server/src/contact_messages.rs`（7。`:36, :62, :117, :143-146`） |
| R4 契約: `contact_message_payload` の `recaptcha_token`、`get_health_reports_recaptcha_configuration_status`、`post_contact_message_returns_503_when_recaptcha_not_configured`、`..._422_when_recaptcha_fails`、`RECAPTCHA_SECRET_KEY` 参照、`contains("reCAPTCHA")` 断言 | Turnstile / captcha 名へ改名、`captcha_configured`、`errors[0]` / `error_code` 断言（旧 `json["error"]` は読まない）、`TURNSTILE_SECRET_KEY` | `crates/agrr-r4-contract/tests/contracts.rs`（16。`:4457-4473, :4476-4506, :4567-4596`） |
| 契約用モック | `captcha-contract-mock.py`（Turnstile 応答形式。トークンで分岐） | `scripts/recaptcha-contract-mock.py`（1） |
| 契約ランタイム: モック起動、`RECAPTCHA_SECRET_KEY` / `RECAPTCHA_VERIFY_URL` / `RECAPTCHA_MOCK_*`、ログ名、未設定シェル契約 | `TURNSTILE_*`、モック名、ログ名 | `scripts/run-rust-contract-tests.sh`（21。`:260-274, :294, :308-354`） |
| モック配線検査（`verifyRecaptchaContractMockSetup`、`RECAPTCHA_CONTRACT_MOCK_SCRIPT`、`unconfigured-recaptcha@example.com`、`recaptcha_token` の検査） | 名称とペイロード検査を Turnstile 版へ | `scripts/run-rust-contract-contact-shell-lib.mjs`（12）、`.test.mjs`（3） |
| `docker-compose.yml`、`env.example`、`env.gcp*.example`、`_agrr-server-cloud-run.sh`、`gcp-frontend-deploy.sh`、`deploy-frontend/SKILL.md`、フロント一式 | **新規追加**（現行 0 件） | §5.2、§5.6 |
| ヘルス警告文言（`routes.rs:36`） | 上記のとおり置換 | — |

### 5.8 CI テスト方針（Turnstile 公式ダミーキーの利用）

原則: **CI の必須テストは外部ネットワークに依存させない**（CI から `challenges.cloudflare.com` に到達できるかは未確認: 3.1.3、Q13）。公式ダミーキー（3.1.1 の 13）は、外部通信ができる場合の補助検証に位置づける。

| 層 | 方針 | 使うキー・データ |
|---|---|---|
| ドメイン（`run-test-rust-domain.sh`） | フェイクの `CaptchaVerifierPort` で全分岐（`Ok` / `Rejected` / `Unavailable` / `NotConfigured`）を検証。ネットワークなし | なし |
| エッジ単体（`agrr-server` のインラインテスト） | 手書きのローカル TCP モックで `TurnstileVerifier` を検証。**リクエスト本文（`secret` / `response` / `remoteip`）とメソッドをモック側で捕捉して断言**（現行のモックは本文を読むだけで断言していない: `contact_message_recaptcha.rs:160-183`）。`error-codes` の分類は §3.1.1 の 3 の各コードで検証 | ダミー値の文字列（実 secret は不要） |
| R4 契約（`run-rust-contract-tests.sh`） | ローカルのモック（`captcha-contract-mock.py`）で `siteverify` 相当を再現し、`TURNSTILE_VERIFY_URL` で向ける。トークン値で応答を分岐（通過 / `invalid-input-response` / 一時利用不可）。**契約用 secret は明らかな偽値（例 `contract-test-turnstile-secret`）にする**: 公式ダミー secret を使うと、`TURNSTILE_VERIFY_URL` の設定漏れで実サーバーに到達したとき任意トークンが成功し、偽の GREEN になりうる（§3.1.2 #4） | 偽 secret + モック |
| フロント unit | `window.turnstile` をスタブして、アダプタ（`render` / `reset` / `remove` の呼び出し、ロード失敗）とコンポーネントを検証 | サイトキーは任意の文字列 |
| E2E スモーク（`operation-smoke.spec.ts`。現状 CI 外: §2.5） | 決定的にするため Playwright で `**/turnstile/v0/api.js` を**スタブ**する案を推奨（テスト専用。本番の `api.js` をプロキシ・キャッシュしないという公式の注意は本番配信に関するもの: 3.1.1 の 6）。サーバー側は `TURNSTILE_VERIFY_URL` をモックへ向ける | ダミーサイトキー `1x00000000000000000000AA` |
| 補助（外部通信可能な環境のみ・任意） | 実 `api.js` + 実 `siteverify` を公式ダミーペアで通す: 通過 `1x…AA` / `1x…AA`、常に失敗 `2x…AB` / `2x…AA`、重複 `1x…AA` / `3x…AA`。手動確認（E3）にも使える。ダミートークンは `XXXX.DUMMY.TOKEN.XXXX` | 3.1.1 の 13 の組 |
| 本番 | 公式ダミーキーを使わない。テスト用 secret の混入を防ぐ（T7、§6.6） | 実キー |

---

## 6. TDD 計画

各項目は **RED（失敗を確認）→ GREEN → REFACTOR**（`tdd-on-edit`）。実行は `test-common` のスクリプトのみ。出力は `./tmp/{UUID}.log` にリダイレクトしてから grep する（`AGENTS.md`）。`npm test` の直接実行・`rails test` は禁止。個別実行の引数の書式（`run-test-frontend.sh` は `npm test -- --watch=false "$@"` に転送: `.cursor/skills/test-common/scripts/run-test-frontend.sh`）は、`ng test` の絞り込みオプションがこのリポジトリで有効かを実装時に確認する（未確認）。

### 6.1 ドメイン（`.cursor/skills/test-common/scripts/run-test-rust-domain.sh`）

名称の中立化（§3.3.1、Q7）は**振る舞い不変のリファクタ**。既存テストの名前を先に新名へ変えて RED（コンパイル失敗）を確認し、実装を改名して GREEN にする。新しい分岐（三分類。Q9）だけが実質的な RED になる。

| ID | ファイル | given / when / then | RED になる理由 |
|---|---|---|---|
| D1 | `interactors_create_contact_message_interactor_test.rs`（既存の 3 ケースを改名） | 既存の 3 シナリオ（`Ok` / 失敗 / 未設定）を `CaptchaVerifierPort` / `CaptchaVerifyResult` / `captcha_kind()` で書き直す | 新名が未定義（コンパイル失敗） |
| D2 | 同 | given `verify` が `NotConfigured` / then `on_failure` が `unavailable_kind()`、`message == "CAPTCHA is not configured"` | 現行文言は `"reCAPTCHA is not configured"`（`:315`） |
| D3 | 同（新規） | given `verify` が `Rejected("x")` / then `captcha_kind()`、`message == "x"`、gateway が呼ばれない | 新分岐 |
| D4 | 同（新規） | given `verify` が `Unavailable("y")` / then `unavailable_kind()`、`message == "y"`、gateway が呼ばれない | 新分岐（Q9 採用時） |
| D5 | 同 | given レート超過 / then CAPTCHA 検証器が呼ばれない（順序の回帰防止。現行の順序: `interactor:47-51`） | 既存挙動の固定（characterization） |

### 6.2 エッジ単体（`agrr-server` のインラインテスト）

`test-common` に `cargo test -p agrr-server` の入口が見つからない（§2.5）。`run-test-rust-domain.sh` は引数を `cargo test -p agrr-domain "$@"` に渡すと理解しており、`-p agrr-server` を付けて実行できるかは**未確認**。使えなければ §6.3 の R4 契約を正とし、実行経路をユーザーに確認する（§8 R11）。

| ID | 場所 | given / when / then | RED になる理由 |
|---|---|---|---|
| V1 | `contact_message_turnstile.rs` の `mod tests` | given secret 空 / then `NotConfigured` | 新モジュール |
| V2 | 同 | given token が `None` / 空 / 空白 / then `Rejected("Turnstile token is required")`、外部呼び出しなし | 同 |
| V3 | 同 | given モックが `{"success":true,"error-codes":[]}` / when `verify(Some("t"), Some("203.0.113.1"))` / then `Ok`。モックが **POST**、本文に `secret=` / `response=t` / `remoteip=203.0.113.1` を含むことを断言 | 同（現行は本文を断言していない） |
| V4 | 同 | given `remote_ip` が `"unknown"` / `None` / then 本文に `remoteip` を含まない | T4 |
| V5 | 同 | given `success:false` かつ `["invalid-input-response"]` / `["missing-input-response"]` / `["timeout-or-duplicate"]` / then `Rejected`（文言に `error-codes` を含む） | T3 |
| V6 | 同 | given `["invalid-input-secret"]` / `["missing-input-secret"]` / `["bad-request"]` / `["internal-error"]`（HTTP 400 で JSON 本文つきを含む） / then `Unavailable` | T3。現行は 422 相当（§2.9） |
| V7 | 同 | given JSON でない本文（HTTP 405 相当）/ 接続失敗 / then `Unavailable` | 同 |
| V8 | 同 | given 既定の検証 URL / then `https://challenges.cloudflare.com/turnstile/v0/siteverify` と一致（`TURNSTILE_VERIFY_URL` の上書きも検証） | 新規 |
| V9 | 同 | given `AGRR_ENV` が本番かつ secret が既知のダミー値（`1x…AA` 等 3 値）/ then `NotConfigured`。非本番では許可 | T7（Q11 採用時） |
| B4 | `contact_messages.rs` の `mod tests`（`:135-178`） | `failure_response(captcha("bad"))` → 422・`errors==["bad"]`・`error_code=="captcha_failed"`。`failure_response(unavailable(..))` → 503・`errors[0]` が文言・`error_code=="captcha_unavailable"`。いずれも単数 `error` キーと `code` キーを持たない（Q16 の既定）。既存 `failure_response_unavailable_returns_503`（`:141-147`）は `json["error"]` を読むため、`errors[0]` と `error_code` の断言へ書き換える。`failure_response_rate_limit_includes_json_body`（`:150-154`）は 07 の変更範囲で、本書は変更しない | D-4〜D-6 |
| B5 | `security_headers.rs` の `mod tests`（`:52-`） | given `CONTENT_SECURITY_POLICY_REPORT_ONLY` / then `script-src` と `frame-src` の双方に `https://challenges.cloudflare.com` を含む | §5.5 |
| B6 | `scripts/verify-security-response-headers-lib.mjs` ＋ `.test.mjs` | given `agrr-security-response-headers.yaml` / then CSP に同じ `https://challenges.cloudflare.com` を含む（Rust 定数との重複は値ではなく契約として検証） | CI は `node --test`（`.github/workflows/frontend-test.yml:155`）。`test-common` に対応スクリプトが無く、実行経路はユーザーに確認 |

### 6.3 R4 契約（`scripts/run-rust-contract-tests.sh`）

| ID | 場所 | given / when / then | 備考 |
|---|---|---|---|
| C1 | `crates/agrr-r4-contract/tests/contracts.rs`（既存 `:4466` を改名） | given secret 設定済み / when `GET /api/v1/health` / then `captcha_configured == true`、`warnings` が空 | RED: 旧キー名 |
| C2 | 同（既存 `:4476` を改名。シェル契約 `run-rust-contract-tests.sh:308-354` も追随） | given secret 未設定 / when POST / then 503、`error_code == "captcha_unavailable"`、`errors[0]` に `CAPTCHA` を含む | RED: `error_code` が無く、`errors` が無い（現行は `error` のみ）。契約ランタイムでは secret 設定済みのためテスト本体はスキップされ、シェル契約が担う（§2.1） |
| C3 | 同（既存 `:4567` を拡張） | given 設定済みで無効トークン（モックが `invalid-input-response`）/ when POST / then 422、`error_code == "captcha_failed"`、`errors[0]` に `Turnstile` を含む | RED: `error_code` が無い。`errors` が無い（現行は `error` のみ） |
| C4 | 同（新規 `post_contact_message_returns_422_when_captcha_token_missing`） | given 設定済み / when トークンのフィールドを省略して POST / then 422、`error_code == "captcha_failed"`、`errors` が非空の文字列配列 | **現行フロントが実際に踏む経路**の契約化 |
| C5 | 同（既存 `:4509` の入力を Turnstile のワイヤ名へ） | given 有効トークン / when POST / then 201、`{id, status:"queued"}` | RED: 新ワイヤ名（Q8） |
| C6 | 同（新規） | given モックが一時利用不可（`internal-error`）を返すトークン / when POST / then 503、`error_code == "captcha_unavailable"`、`errors` が非空の文字列配列 | Q9 採用時。モックに分岐を追加 |
| C7 | `run-rust-contract-contact-shell-lib.test.mjs`（既存を改名） | given 改名後のモック / then 配線検査（Dockerfile.test の python3、起動、readiness、ペイロードのフィールド名）が通る | RED: 旧名を見て失敗 |

R4 の失敗本文の断言のうち、本書が書き換えるのは CAPTCHA 系の 2 箇所（`contracts.rs:4502-4506` の 503、`:4595` の 422。C2・C3）だけである。429 の断言（`:4563` の `json["error"] == "rate_limit"`）は 07 の S2 更新対象（07 の「S2 で変更が必要な 12 箇所」に含まれる）で、本書は変更しない。本書が 07 の S1・S2 より先に入る場合は現行のまま、後に入る場合は 07 の更新後の断言に従う（Q16）。

### 6.4 フロントエンド（`.cursor/skills/test-common/scripts/run-test-frontend.sh`）

| ID | ファイル案 | given / when / then | RED になる理由 |
|---|---|---|---|
| F1 | `domain/contact/contact-message.spec.ts` | given 有効な email/message で `captcha_token` が空 / when `validatePayload` / then `{ valid:false, message:'contact_form.validation.captcha_required' }` | 現行は token を検査しない |
| F2 | `adapters/contact/http-contact-gateway.service.spec.ts` | given サーバー応答 `{id:7,status:'queued'}` / when `postMessage` / then 結果が **`toStrictEqual({id:7,status:'queued'})`**（`email` 等のキーが無い） | 現行は `email:undefined` などのキーを持つオブジェクトを返す（`toEqual` は undefined を無視するため `toStrictEqual` を使う） |
| F3 | 同上 | given ペイロードに `captcha_token:'tok'` / when `postMessage` / then `apiClient.post` が `('/api/v1/contact_messages', body)` で呼ばれ、body にワイヤ名（Q8: 案 A は `'cf-turnstile-response': 'tok'`）を含み、ペイロードの中立名 `captcha_token` は含まない | ペイロード型に無く、写像も無い |
| F4 | `usecase/contact/send-contact-message.usecase.spec.ts` | given ゲートウェイが `{id:1,status:'queued'}` / when `execute` / then `onSuccess({id:1,status:'queued'})` のみで呼ばれ、`created_at` / `sent_at` を含まない | 現行は `sent_at:null` を付与する（`:40-47`） |
| F5 | 同上 | given ゲートウェイが `{status:422,error:{errors:['Turnstile failure: invalid-input-response'],error_code:'captcha_failed'}}` で失敗 / then `onError({message:'contact_form.errors.captcha_failed'})` | 現行は 422 を一律 `validation_failed` |
| F6 | 同上 | given `{status:503,error:{errors:['CAPTCHA is not configured'],error_code:'captcha_unavailable'}}` / then `onError({message:'contact_form.errors.captcha_unavailable'})` | 現行は `send_failed` |
| F7 | 同上 | given `{status:422,error:{errors:["Email is invalid"],field_errors:{email:["is invalid"]}}}`（07 適用後の入力検証 422 の本文形状に修正した fixture。`error_code` なし）/ then `validation_failed`（回帰防止。CAPTCHA 失敗と `error_code` の有無で区別される） | 既存テストの fixture は `{ field_errors: {...} }` のみで `errors` を持たない（`:87-93`）。07 §2.7 #16 は入力検証 422 に `errors`（現行どおり）と `field_errors` の両方を載せるとしているため、fixture を合わせて維持を確認 |
| F7b | 同上 | given `{status:429,error:{errors:["rate_limit"]}}` / then `send_failed`（本課題の既定。Q15 で専用文言を追加する場合は RED の対象に変わる） | 現行の挙動の固定（characterization） |
| F8 | `components/contact-form/contact-form.component.spec.ts` | given ウィジェットが token `'tok'` を通知し入力が有効 / when `submit()` / then `useCase.execute` が `captcha_token:'tok'` 付きペイロードで 1 回呼ばれる | 現行は token を持たない（`:176-184`） |
| F9 | 同上 | given token 未取得 / when `submit()` / then `useCase.execute` が呼ばれず、`control.message` が `contact_form.validation.captcha_required` の validation 種別 | 同上 |
| F10 | 同上 | given `execute` の完了（成功・失敗の両方）/ then ウィジェットの `reset` が呼ばれる | 機能なし |
| F11 | 同上 | given site key 未設定（ポートが利用不可）/ when 描画 / then 送信ボタンが無効で `contact_form.errors.captcha_unavailable` が表示され、`execute` は呼ばれない | 機能なし |
| F12 | `adapters/contact/turnstile-widget.adapter.spec.ts`（新規） | given ブラウザ環境で `window.turnstile` をスタブ / when `render(host, siteKey, callbacks)` / then `render` が `sitekey`・`language`（`in` ロケールは `hi`）・`'response-field': false`・コールバック付きで呼ばれ、`api.js`（`https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit`）の `<script>` は 1 回だけ挿入される。given `expired-callback` / then トークンが破棄される。given サーバープラットフォーム / then `document` に触れず利用不可を返す。given script の `onerror` / `error-callback` / then 利用不可を通知。`remove` が呼べる | 新規 |
| F13 | `core/turnstile-runtime-config.spec.ts`（新規） | `window.TURNSTILE_SITE_KEY` が優先、空白はトリム、未設定なら `environment.turnstileSiteKey`、双方空なら空文字 | 新規 |
| F14 | `core/i18n/contact-form-locale.catalog.spec.ts` | `CONTACT_FORM_KEYS` に §5.4 の 4 キーを追加 → ja / en / in の 3 ロケール分が失敗 | JSON 未追加 |

RED の確認: 上記を追加し、`test-common` で **意図した理由で失敗**すること（新規実装が必要なもの）を確認してから GREEN に進む。GREEN 後は個別 → 引数なしの全体 → `test-slow-detection`。

### 6.5 E2E / 手動

| ID | 内容 |
|---|---|
| E1 | `operation-smoke.spec.ts:96-105` を新仕様へ更新。CI の決定性のため `api.js` をスタブ（§5.8）。サーバー側検証は `TURNSTILE_VERIFY_URL` をモックに向ける。実通信のダミーキー検証は外部通信が可能な環境のみ（Q13） |
| E2 | `a11y` / `layout` スモーク（`/contact` を含む）が、iframe 追加後も GREEN であること。`npm run check:ui-composition` の結果（実行は未実施） |
| E3 | gcp-test（`gcp-test-local` スキル）で実キーを用いた手動確認（キー発行は Q1）。公式ダミーペア（`1x…AA` / `2x…AB`）での通過・失敗の両ケースも確認（外部通信が可能な環境） |

### 6.6 本番の事前確認手順（未確認事項の解消）

1. `GET https://agrr.net/api/v1/health` の `captcha_configured`（移行前は `recaptcha_configured`）と `warnings` を確認する（`routes.rs:33-46`）。`gcloud` が使える環境なら Cloud Run のサービス定義の環境変数・シークレット参照も確認する（本調査では未実施）。
2. `false` の場合は、Secret Manager への登録と Cloud Run への注入が**フロント公開より先**に必要（実キーの `TURNSTILE_SECRET_KEY`。**公式のテスト用 secret は設定しない**: §3.1.2 #4、T7）。
3. デプロイ後に `captcha_configured:true` と `warnings:[]` を確認。site key と secret が同じウィジェットのキーペアであることは、実キーでの 1 件の送信で確認する（自動検知手段は無い）。
4. 本番の Cloud Run から `challenges.cloudflare.com` へ到達できることは、実キーでの 1 件の送信（201）で確認する（到達不能ならヘルスは `true` でも 503 になる。§8 R16）。
5. 旧 `RECAPTCHA_SECRET_KEY` が本番に存在する場合は、上記が済んだ後に撤去する（Q5）。

---

## 7. 実装ステップ

1〜2 の前に Q1〜Q4 の回答を得る。各ステップは「RED → GREEN → REFACTOR → 全体実行 → `test-slow-detection`」で完結させ、ステップ単位でコミットする。

| # | 内容 | テスト | コミット |
|---|---|---|---|
| 1 | 成功レスポンス型の是正（`ContactMessageRecord` を縮小、ゲートウェイ / ユースケース / DTO / 既存テスト fixture の修正、到達不能な `failed` 分岐の削除） | F2, F4 | `fix(frontend): align contact gateway types with API contract` |
| 2 | ドメインの名称中立化（振る舞い不変。Q7）と三分類の追加（Q9） | D1〜D5 | `refactor(domain): neutralize contact captcha port naming` |
| 3 | エッジの検証器を Turnstile へ置換（`contact_message_turnstile.rs`、状態・ヘルス・ハンドラ DTO、R4 モックと契約ランタイム、旧 reCAPTCHA 名称の撤去） | V1〜V9, C1〜C7 | `feat(server): verify contact messages with Cloudflare Turnstile`。`crates/*` 変更のため `rebuild-restart.sh` 後に R4 |
| 4 | CAPTCHA 失敗・利用不可の応答を `errors` + `error_code` にする（`api_error.rs` のヘルパー経由。D-4〜D-6。着手は 07 の手順 2 の後: Q16） | B4, C2, C3, C4, C6 | `feat(server): return errors and error_code for contact captcha failures` |
| 5 | ユースケースのエラー写像（`error_code` で CAPTCHA 失敗 / 利用不可 / 入力検証を区別）。着手は 07 の手順 7（`core/api-error-message.ts`）の後 | F5〜F7, F7b | `fix(frontend): map contact captcha errors by error_code`（4 に依存） |
| 6 | site key ランタイム設定 + ウィジェットポート / アダプタ + ドメインのトークン検証 + ゲートウェイのワイヤ名写像 | F1, F3, F12, F13 | `feat(frontend): add Turnstile widget port and adapter` |
| 7 | コンポーネント統合（ホスト要素、token 送信、リセット、利用不可時の fail-closed）+ i18n（ja/en/in）+ カタログ spec（+ Q4 の回答次第でプライバシー文言） | F8〜F11, F14 | `feat(frontend): require Turnstile in contact form` |
| 8 | CSP（`security_headers.rs` と `agrr-security-response-headers.yaml` を同期。`script-src` と `frame-src`） | B5, B6 | `chore(security): allow Turnstile origin in CSP report-only` |
| 9 | 設定・デプロイ・ドキュメント（compose、env 例、server / frontend デプロイスクリプト、スキル文書） | `DRY_RUN=1` によるデプロイスクリプトの出力確認（`gcp-frontend-deploy.sh` は `DRY_RUN` を持つ。注入部に既存の自動テストは無い: `.cursor/skills/deploy-frontend/scripts/*.test.mjs` は該当なし） | `chore(deploy): wire TURNSTILE_SECRET_KEY and TURNSTILE_SITE_KEY` |
| 10 | E2E スモーク更新（と Q13 次第で CI への組み込み） | E1, E2 | `test(e2e): update contact form smoke for Turnstile` |
| 11 | 手動確認（E3）と本番展開（ユーザー作業） | §6.6 | なし |

本番展開の順序: (1) Cloudflare でウィジェット作成・キー発行（Q1）→ (2) secret 登録（Q2）→ (3) サーバーをデプロイ（フォームは引き続き失敗するが現状と同じで悪化しない）→ (4) フロントを `TURNSTILE_SITE_KEY` 付きでデプロイ → (5) LB の CSP 反映（Q12）→ (6) 動作確認（§6.6）後に旧 `RECAPTCHA_*` を撤去（Q5）。

07 との順序（07 §3.5.1・§7・§10 に基づく。07 のコミット番号は 07 の「実装ステップ」表の順）: (a) 07 の手順 2（`api_error.rs` の導入。S0）→ 本書の手順 3〜4。`api_error.rs` が無い状態で先に実装すると、`json!` で `error` / `code` を直書きすることになり、07 の S2・機械ゲート（S-T6）の撤去対象を増やす。(b) 本書の手順 5 は 07 の手順 7（`core/api-error-message.ts`）の後。(c) 現行フロントは 422 の本文を読まず状態コードだけで判定する（`send-contact-message.usecase.ts:49-58`）ため、サーバーの本文形状を先に変えても現行フロントは退行しない。本番展開の (3)（サーバー）を (4)（フロント）より先にする順序と整合する。(d) 07 の手順 5（contact の区分 A の変換と `field_errors` 追加）と本書の手順 3〜4 は同じ `contact_messages.rs` を触るため、同一 PR か連続した PR で調整する。順序が逆転した場合の旧キー併記の扱いは Q16。

---

## 8. リスク・未確定事項

| # | 内容 | 状態 |
|---|---|---|
| R1 | 本番の `TURNSTILE_SECRET_KEY`（移行前は `RECAPTCHA_SECRET_KEY`）の有無 | 未確認（§2.6）。§6.6 で解消 |
| R2 | デプロイスクリプトが手動設定の secret を消す可能性（`--env-vars-file` の置換仕様） | gcloud の仕様理解に基づく。未確認 |
| R3 | site key と secret のキーペア不一致は自動検知できない | 運用手順で担保 |
| R4 | トークンは 300 秒有効・1 回限り（3.1.1 の 4）。長文入力でウィジェット表示から 5 分を超える、または送信失敗後の再送でトークンが失効・消費済みになる | 対策: 成否にかかわらずリセット（F10）、`expired-callback` で破棄（F12）。`refresh-expired: auto` の自動更新でコールバックが再発火するかは未確認（3.1.3） |
| R5 | SPA 内の言語切替に追従した再描画（`remove` → `render`） | API は公式に記載（3.1.1 の 6）。実挙動は未確認。追従が難しい場合は「ページ読み込み時の言語」で固定する妥協案を Q として再確認 |
| R6 | Turnstile の iframe が a11y / layout スモークに与える影響 | 未確認。E2 で確認 |
| R7 | CI で `challenges.cloudflare.com` への外部通信が可能か | 未確認（Q13）。不可ならスタブ / モックで統一（§5.8） |
| R8 | 送信成功後の運営側の受信経路が不明（`queued` 行の消費者が見当たらない） | Q14。本課題で直すと範囲が拡大する |
| R9 | Cookie / プライバシー表記の追記要否（Managed での表記義務は未確認） | Q4 |
| R10 | 識別子の名称・形式が課題 07 とずれると二重改修になる | **解消方針**: 新規 `code` をやめ、07 の契約（`errors` + `error_code`）に合わせた（D-4〜D-6）。残る調整は着手順と旧キー併記（Q16、R21） |
| R11 | `test-common` にサーバークレート単体テスト・スクリプトテスト（`node --test`）の入口が無い | V1〜V9、B4〜B6 の実行経路をユーザーに確認。使えない場合、サーバー側の RED は R4（C1〜C7）で代替 |
| R12 | 到達不能な `failed` 分岐と関連テストの削除は、将来「作成応答で `failed` を返す」設計を想定していないという判断を含む | R4 契約は `queued` のみ固定（§2.4）。異議があれば分岐を残す |
| R13 | 実機（Docker 起動 / 本番 / 実ブラウザ）での再現は未実施 | 本書の失敗経路は、単体テスト・R4 契約・フロントのコード読みの組合せに基づく |
| R14 | **テスト用 secret が本番に設定されると検証が素通しになる**（実測で `1x…AA` が任意トークンを成功にした: §3.1.2 #4）。公式ドキュメントの「ダミートークンのみ受理」の記載と食い違う | Q11（T7 のガード）。少なくとも §6.6 の手順で「本番に公式ダミー secret を設定しない」を明記 |
| R15 | 公式ドキュメントは更新されうる（本書は 2026-09-29 取得）。特にエラーコード、CSP、ダミーキー | 実装着手前に §3.1.1 の 1・3・4・9・10・13 を再確認 |
| R16 | サーバーが `challenges.cloudflare.com` に依存する（障害・到達不能時は fail-closed で 503）。可用性の依存先が Google から Cloudflare に変わる（reCAPTCHA でも同型） | 三分類（T3）で利用者に「時間をおいて再試行」を案内。明示タイムアウトを設定。Cloud Run からの到達性は §6.6 で確認 |
| R17 | CSP `connect-src` の要否は公式要件として確認できていない | Report-Only の違反を実ブラウザで確認して判断（3.1.3） |
| R18 | `remoteip` の元である `X-Forwarded-For` 先頭要素は偽装の余地がある（§2.8） | `remoteip` は任意・補助情報として扱い、判定根拠にしない（T4） |
| R19 | `frontend-deploy.yml` の CI 経路は env ファイルを用意せず、スクリプトが停止する可能性（§5.3） | この経路が実際に使われているかは未確認。使う場合は workflow への `TURNSTILE_SITE_KEY` 追加を別途判断 |
| R20 | 他課題文書・README に、現状と食い違う記述が残る（2026-10-07 時点。§10 に一覧） | 本書の編集範囲外。追随が必要（§4、§10） |
| R21 | 07 の `api_error.rs`（S0）とフロントの `core/api-error-message.ts` は未作成（`ls` で確認）。本書の手順 4・5 は 07 の手順 2・7 に依存する。07 が先に進まない場合、本書の失敗応答は `json!` の直書き（`error` / `code` 系の新規実装）になり、07 の撤去対象を増やす | 着手順を 07 の手順に合わせる（§7）。やむを得ず先行する場合の扱いは Q16 |
| R22 | 07 §10 は 02 の旧案（`error` + 新規 `code`）を前提にした読み替えを書いており、本書の更新後は「読み替えが済んだ」状態になる。07 側の記述（「02 の現状は `error` と `code` の案のまま」）は本書の範囲外で、07 が読み直すまで食い違って見える | 07 側の更新を待つ。本書は 07 の読み替え（§10 (1)〜(5)）と一致させてある |

---

## 9. 受け入れ条件

1. 有効な Turnstile の site key・secret（公式ダミーペアで可）を設定した環境で、`/contact` のフォームに入力しウィジェットを完了して送信すると、サーバーが 201 `{id,status:"queued"}` を返し、画面に成功メッセージが表示される。
2. ウィジェット未完了（トークン未取得）で送信すると、`useCase.execute` を呼ばずに `contact_form.validation.captcha_required` が表示される（F9）。
3. サーバーが Turnstile 検証失敗（422。本文は `{"errors":[..],"error_code":"captcha_failed"}`）を返したとき、`contact_form.errors.captcha_failed` が表示され、入力エラー文言（`validation_failed`）にならない。ウィジェットがリセットされる（F5, F10）。
4. サーバー側 secret 未設定または Turnstile 側の一時利用不可（503）、あるいは site key 未設定・`api.js` 読み込み失敗のとき、送信は行われず（フロント起因の場合）または送信が拒否され、`contact_form.errors.captcha_unavailable` が表示される（F6, F11, F12, C2, C6）。
5. サーバーは、`missing-input-response` / `invalid-input-response` / `timeout-or-duplicate` を 422、`missing-input-secret` / `invalid-input-secret` / `bad-request` / `internal-error` と通信失敗・不正応答を 503 に分類する（V5〜V7。Q9 を不採用にした場合は本項を、全失敗が 422 であることに読み替える）。
6. `frontend` の `ContactMessageRecord` 相当の型とゲートウェイ / ユースケースのテストが、サーバーの実応答 `{id, status}` と一致する（F2, F4）。
7. i18n の新規キーが ja / en / in の全てに定義されている（F14）。
8. R4 契約（C1〜C7）が GREEN。`agrr-domain` のテスト（D1〜D5）が GREEN。フロントの全体テストが GREEN。`test-slow-detection` を実施済み。R4 契約の必須テストは外部ネットワークを使わない（§5.8）。
9. `docker-compose.yml` / `env.example` / デプロイスクリプトで `TURNSTILE_SECRET_KEY` と `TURNSTILE_SITE_KEY` の入力口が定義され、本番デプロイが secret を落とさない。`crates/` と `scripts/` に `recaptcha` / `RECAPTCHA` が残らない（`rg -i recaptcha crates scripts` が 0 件。他課題文書の言及を除く）。
10. 本番: `GET /api/v1/health` が `captcha_configured:true` かつ `warnings:[]`。実キーで 1 件送信できる。本番に公式ダミー secret が設定されていない（ユーザー作業）。
11. CSP（Report-Only）の `script-src` と `frame-src` に `https://challenges.cloudflare.com` が含まれ、Rust 定数と YAML の内容が一致する（B5, B6）。
12. `/contact` の a11y / layout スモークと `check:ui-composition` が GREEN（E2）。
13. E2E スモークの問い合わせテストが新仕様と矛盾しない（E1）。CI に含めるかは Q13 の回答による。
14. CAPTCHA 失敗・利用不可の応答本文は、07 の契約に合わせて `errors`（非空の文字列配列）と `error_code`（`captcha_failed` / `captcha_unavailable`）を持ち、新規キー `code` と、本書が新規に書く単数 `error` を持たない（B4, C2〜C4, C6。旧キー併記の扱いは Q16）。入力検証の 422 は `error_code` を持たず、フロントは `validation_failed` を表示する（F7）。

---

## 10. 関連課題との依存

2026-10-07 の整合更新で読んだもの: `README.md` 全文（決定事項の第 1〜3 回を含む）、課題 07 の §0・§3.3・§3.5.1・§3.6〜§3.8・§7・§10 と、07 内の contact・captcha・`error_code` の該当箇所、03 §10 の 02 行、05 §0 と §10 の 02 行、および 01 / 04 / 05 / 06 / 08 / 09 / 10 / 11 の「02」「contact」「captcha」「recaptcha」に関する記述（検索で抽出した行）。01・04〜06・08〜11 は**全文を精読していない**。他文書は並行して更新されうるため、下の行番号・節番号は更新時点（作業ツリー）のもの。

| 課題 | 関係 | 内容 |
|---|---|---|
| 01 resource-limit-bypass | 依存なし（01 側も同じ判断） | 01 は 02 を「依存なし（未作成・未確認）」としている（`01-resource-limit-bypass.md:671`）。01 に問い合わせのレート制限・匿名エンドポイントの記述は無い（`レート制限` `rate_limit` `匿名` の検索で 0 件）。本書 §2.8 のレート制限（IP 取得・プロセス内メモリ・単一インスタンス前提）と 01 の上限判定は別の仕組みで、現時点で重なる議論は見当たらない |
| 03 api-key-scope-docs | 機能の依存なし。**デプロイの同乗のみ** | 03 は認証つき API 用で、問い合わせは匿名。03 §10 は 02 を「機能の依存なし。デプロイの同乗のみ関係する」とし（`03-api-key-scope-docs.md:1175`）、V27 と Turnstile の導入を**別リリースにできるなら別にする**、分けられない場合は V27 の適用確認（DB）と Turnstile の確認（実送信）を独立に行うとしている。03 は本書の §6.6 の手順 2〜4 と §8 R16 を参照しているため、**これらの節・項番号は変更しない**。03 の V27 移行後の 403 の本文形式は 07 が扱い、本書の対象外 |
| 04 api-key-query-auth | 依存なし | 同上。04 側も 02 を「依存なし」としている（`04-api-key-query-auth.md:289`） |
| 05 fail-closed-critical | 依存なし。方針は整合 | 05 側は 02 を「依存なし（対象コードが重ならない）」とする（`05-fail-closed-critical.md:450`）。本書の secret 未設定→503（D-3）は fail-closed の実例で、README 第 1 回「厳格」（05 / 06 に反映）と矛盾しない。05 の失敗本文（`error_key` と `message` を含む暫定案）の `errors` への読み替えは 07 の領域で、本書は関与しない |
| 06 fail-closed-suspected | **突合の依頼あり（本書側の確認結果）** | 06 は、秘密値の `unwrap_or_default()`（`state.rs:97-104`、`contact_message_recaptcha.rs:17`）を「02・04 と突合してから扱う」としている（`06-fail-closed-suspected.md:560, 619`）。本書側のコード確認: `contact_message_recaptcha.rs:17` は `RECAPTCHA_SECRET_KEY` 未設定を空文字にするが、空（空白のみを含む）は `is_configured()` が偽（`:31-33`）となり `NotConfigured`（`:124-126`）を返し、interactor が `unavailable`（503）にする（`create_contact_message_interactor.rs:58-63`）。空の secret が検証を**素通しにする経路は無く**、明示的な失敗になる。なお `state.rs:97-104` の `unwrap_or_default()` は Google OAuth・スケジューラ・backdoor の値で、CAPTCHA の secret ではない（CAPTCHA の検証器は `state.rs:54, 119` で別に生成される）。06 の分類は 06 側の判断。06 が列挙する 8 項目と追加対象に問い合わせの CAPTCHA は含まれていない（読んだ範囲）。§3.2 T7（ダミー secret の本番混入ガード。Q11）は、06 の列挙対象に加える候補になりうる（未確認） |
| **07 frontend-error-contract** | **強い依存（形は 07 に従属。本書は名称を確定）** | 本書は 07 の最新契約（README 第 2 回「errors」・第 3 回「削除」。07 §0.2・§0.3）に合わせた（D-4〜D-6、§3.2 T9、§5.1・§5.2、Q10 解消）。対応づけ（07 §10 の (1)〜(5) と一致させた）: (1) 識別子は新規 `code` ではなく既存 `error_code`。値 `captcha_failed` / `captcha_unavailable` は本書で確定。(2) CAPTCHA 拒否 422 は `{"errors":["<文言>"],"error_code":"captcha_failed"}`、利用不可 503 は `{"errors":["<文言>"],"error_code":"captcha_unavailable"}`。(3) 入力検証 422 は `errors`（`full_messages`）のままで、`field_errors`（`validation_errors.rs:45-51`）を 07 が追加する。CAPTCHA 失敗とは `error_code` の有無で区別する（本文の形状では区別しない）。(4) フロントの `toErrorDto` は `apiErrorCode(err)` を使う（07 §3.7。本書のテスト F5〜F7 の fixture は `{errors:[..],error_code:..}` に更新済み）。(5) 429 `rate_limit` は 07 により `{"errors":["rate_limit"]}`（`error_code` なし）。専用文言の担当は 07 と本書で相互委譲になっており**未確定**（Q15）。**着手順**（07 §10 (6)・§7 に基づく）: 07 の手順 2（`api_error.rs`）→ 本書の手順 3〜4、07 の手順 7（`core/api-error-message.ts`）→ 本書の手順 5（§7）。いずれも未作成（R21）。**旧キー併記の要否と 07 の S1 / S2・P6 との関係は未確定**（Q16）。R4 の `contracts.rs:4502-4506, 4595` は本書が書き換え、`:4563`（429）は 07 の S2 に委ねる（§6.3）。07 側の §10 は 02 を「`error` + 新規 `code` の案のまま」と記述しており、本書の更新で読み替え済みになる（R22） |
| 08 openapi-gaps | 依存（入力提供）。**担当は未確定** | `docs/api/openapi.yaml` に `contact_messages` の記載が無い（§4）。08 は 02 を「Masters API と無関係・依存なし」とし（`08-openapi-gaps.md:1047`）、08 に contact の記述は見当たらない。07 は 08 の `Error` スキーマを `errors` 必須・`error_code`・`field_errors` に更新する前提（07 §10）。本書の確定契約（Turnstile トークンのワイヤ名（Q8。案 A ではハイフン付きキーのクォート記述）、201 / 422 / 429 / 503、`errors` + `error_code`）と、ヘルスの `captcha_configured`（Q7）を 08 に渡す。誰が `contact_messages` を OpenAPI に載せるかは決まっていない（Q17 (a)） |
| 09 stale-design-docs | 関連 | 問い合わせの旧契約文書は履歴上削除済み（`a40a3b87c`）で、現行の契約文書が無い。今回の環境変数追加（`TURNSTILE_*`）とヘルスキー変更を反映する docs の所在も含め、09 と重複しないよう調整。09 はヘルスの `recaptcha_configured` を現行の事実として記述している（`09-stale-design-docs.md:92`）。現行コードの記述としては正しく、Q7 の名称変更を実施する際に追随が必要。09 側は 02 を「依存なし」としている（同 `:397`） |
| 10 authorization-consistency | 依存なし | 10 側も 02 を「依存なし」としている（`10-authorization-consistency.md:1258`）。匿名エンドポイントのため認可の対象外。`GET /api/v1/contact_messages` は常に空配列を返す実装（`crates/agrr-server/src/contact_messages.rs:24-27`）で、データは出ない |
| 11 low-priority-misc | 移管候補 + **同一変更の重複** | §2.8 の「`ContactMessage::validate()` が本番経路で未使用」「X-Forwarded-For 先頭要素の採用」「`GET` ダミー」は本課題の範囲外。11 または新規課題へ。11 の項目 3（案 A: `ContactMessageRecord` を `{id, status}` に縮小）は本書の手順 1 と**同一の変更**で、11 側は案 A の採否が確認事項のまま（`11-low-priority-misc.md:181, 184`）。どちらで実施するかは未確定（Q17 (b)）。11 は `contact-message.model.ts` を扱い、本書のペイロード変更（`captcha_token` 追加）と同一ファイルで競合しうる（同 `:98, :379`）。11 の「サーバーのエラー形状（`error` / `errors`）は 02 が決める」（同 `:379`）は、07 が決める形（`errors` + `error_code`）に更新が必要（11 側の記述。本書の範囲外） |
| README | 一部追随済み・一部が古い | `docs/spec-defects/README.md` の 02 行と「ユーザー判断が必要な主な事項」の 02 は Turnstile に更新済み。一方、(a) 着手順 4 は「02（reCAPTCHA の種別・キー発行はユーザー判断が先）」のまま、(b) 更新履歴の「02 の `code` 提案（07 では `error_code` に読み替え）…追随が未実施」は、本書の更新で 02 側が追随済みになる。README は本書の編集範囲外 |

### 10.1 本更新で未確定のまま残る事項

§3.4 の Q15〜Q17 に集約している。Q1〜Q9・Q11〜Q14 は本更新の対象外で、状態は変わっていない（Q10 のみ解消）。

| # | 内容 | 担当・次の一手 |
|---|---|---|
| Q15 | 429 `rate_limit` の専用文言を 02 と 07 のどちらで扱うか（相互に委譲） | ユーザー判断。既定は「追加しない」 |
| Q16 | 着手順（07 の手順 2・7 が先か）と、CAPTCHA 失敗・503 の旧キー（`error`）併記の要否。外部の非ブラウザクライアントの有無は未確認 | 07 側の S1 / S2・P6 の運用方針に依存。既定は 07 §10 (6) の推奨（`api_error.rs` の後に最終形で実装） |
| Q17 | (a) `contact_messages` を OpenAPI に載せる担当（08 は範囲外と読める）、(b) 成功応答型の是正を 02 と 11 のどちらで実施するか | 08 / 11 の範囲確認。既定は (a) 本課題では追加せず 08 に契約を渡す、(b) 本書の手順 1 |
