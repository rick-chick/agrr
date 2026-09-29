# 02: 問い合わせフォームが reCAPTCHA 未実装のため送信できない

本書は**対応計画のみ**であり、コード・設定・他文書の修正は含まない。記載する事実は 2026-09-29 時点（基準コミット `cdfd21ac6`）のリポジトリを実際に読んで確認したものだけで、`file:line` を付ける。読んでいない・実行していない・外部サービスの状態に依存するものは「未確認」と明記する。

参照した規約: [`ARCHITECTURE.md`](../../ARCHITECTURE.md)、[`docs/architecture/LAYER-RULES.md`](../architecture/LAYER-RULES.md)、[`tdd-on-edit`](../../.cursor/skills/tdd-on-edit/SKILL.md)、[`test-common`](../../.cursor/skills/test-common/SKILL.md)、[`evidence-before-design-and-implementation.mdc`](../../.cursor/rules/evidence-before-design-and-implementation.mdc)、[`docs/design/UI-COMPOSITION-RULES.md`](../design/UI-COMPOSITION-RULES.md)（フロント変更のため）。

---

## 1. 概要と重大度

### 概要

匿名エンドポイント `POST /api/v1/contact_messages` は reCAPTCHA 検証を**必須**にしている（fail-closed）。一方、Angular の問い合わせフォームは reCAPTCHA の取得・送信を一切実装していない。したがって**サーバー側の設定状態にかかわらず、フロントのフォームから送信して成功する経路は現ツリーに存在しない**（コード読みによる。実機での再現は未実施。根拠は §2.1〜§2.3）。

| サーバーの `RECAPTCHA_SECRET_KEY` | フロントの送信結果（コード上） | ユーザーに見えるメッセージ |
|---|---|---|
| 未設定 | 503 `{"error":"reCAPTCHA is not configured"}` | 「送信に失敗しました。」(`contact_form.errors.send_failed`) |
| 設定済み | 422 `{"error":"reCAPTCHA token is required"}` | 「入力内容を確認してください。」(`contact_form.errors.validation_failed`)。入力は正しいのに誤解を招く |

加えて、成功レスポンスの形とフロントの型・テストが乖離している（§2.4）。現状これは実害を出していないが、reCAPTCHA 対応で同じ経路を触るため同時に是正する。

### 重大度

| 項目 | 重大度 | 理由 |
|---|---|---|
| 問い合わせフォームが送信不能 | **高** | 公開ページ `/contact`・`/en/contact` の唯一のフォーム機能が全環境で失敗する。データ破壊・情報漏えいはない |
| 失敗時メッセージの誤誘導（422 を validation_failed と表示） | 中 | 利用者が入力を疑い続ける |
| 成功レスポンス型の乖離 | 低 | 現状は presenter が DTO を使わないため表面化していない（`frontend/src/app/adapters/contact/contact-form.presenter.ts:102-111`） |
| 本番の `RECAPTCHA_SECRET_KEY` 設定有無 | 未確認 | §2.6 参照 |

---

## 2. 現状（確認済み事実）

### 2.1 バックエンド: reCAPTCHA を必須にしている

| 事実 | 根拠 |
|---|---|
| リクエストボディが `recaptcha_token: Option<String>` を受ける | `crates/agrr-server/src/contact_messages.rs:29-37`（token は 36 行目） |
| ハンドラは token・`remote_ip` を入力 DTO に詰め、interactor を 1 回呼ぶ（R7 準拠） | `crates/agrr-server/src/contact_messages.rs:101-133` |
| interactor の順序は「レート制限 → reCAPTCHA → gateway.create」 | `crates/agrr-domain/src/contact_messages/interactors/create_contact_message_interactor.rs:47-51, 53-69, 71-86` |
| `NotConfigured` は `Unavailable` 失敗（メッセージ `"reCAPTCHA is not configured"`） | 同 `:58-63` |
| `Error(msg)` は `Recaptcha` 失敗 | 同 `:64-68` |
| 失敗 → HTTP の写像: RateLimit=429 `{"error":"rate_limit"}`、Recaptcha=422 `{"error": msg}`、Unavailable=503 `{"error": msg}`、Validation=422 `{"errors":[...]}` | `crates/agrr-server/src/contact_messages.rs:58-79` |
| 成功は 201 `{"id","status"}` のみ | `crates/agrr-server/src/contact_messages.rs:86-94`（フィールドは 89-92 行目） |
| secret 未設定なら `NotConfigured`、token が空なら `Error("reCAPTCHA token is required")` | `crates/agrr-server/src/contact_message_recaptcha.rs:124-131` |
| 上記は単体テストで固定済み | 同 `:185-204`（`verify_rejects_when_secret_missing` / `verify_rejects_when_token_missing`） |
| `RECAPTCHA_SECRET_KEY` と `RECAPTCHA_VERIFY_URL`（既定 `https://www.google.com/recaptcha/api/siteverify`）を環境変数から読む | 同 `:7, :15-22` |
| ヘルスに `recaptcha_configured` と警告 `"RECAPTCHA_SECRET_KEY is unset; contact messages are rejected"` を載せる | `crates/agrr-server/src/routes.rs:33-46`（警告は 35-37 行目） |
| 起動時に未設定なら `tracing::warn!` | `crates/agrr-server/src/contact_message_recaptcha.rs:35-41` |
| R4 契約: 未設定→503、正常→201 `queued`、レート超過→429、検証失敗→422 | `crates/agrr-r4-contract/tests/contracts.rs:4476, 4509, 4533, 4567`（token を含むペイロードは 4457-4464） |
| R4 の契約ランタイムは mock 検証サーバーとテスト用 secret を設定する。secret 未設定のシェル契約もある | `scripts/run-rust-contract-tests.sh:260-264, 308-354`、`scripts/recaptcha-contract-mock.py` |

### 2.2 フロントエンド: reCAPTCHA の実装・送信が無い

| 事実 | 根拠 |
|---|---|
| `frontend/src` 配下に `recaptcha` を含むファイルが 0 件（大文字小文字を区別せず再確認済み） | `grep -rIli recaptcha frontend/src` の結果が空 |
| 送信ペイロード型に token フィールドが無い | `frontend/src/app/domain/contact/contact-message.model.ts:1-7` |
| コンポーネントが組み立てるペイロードは name/email/subject/message/source のみ | `frontend/src/app/components/contact-form/contact-form.component.ts:176-184` |
| テンプレートに reCAPTCHA ウィジェットの置き場が無い（フィールド 44-100、送信ボタン 102-110） | 同 `:44-133` |
| ゲートウェイはペイロードをそのまま `POST /api/v1/contact_messages` する | `frontend/src/app/adapters/contact/http-contact-gateway.service.ts:16-18` |
| **422 を一律 `validation_failed` に写像**（reCAPTCHA 失敗もバリデーション失敗も区別しない）。それ以外は `send_failed` | `frontend/src/app/usecase/contact/send-contact-message.usecase.ts:49-58` |
| ユースケースのテストが想定する 422 の本文は `{ field_errors: {...} }` だが、サーバーの実本文は `{ errors: [...] }` または `{ error: "..." }` | テスト側 `frontend/src/app/usecase/contact/send-contact-message.usecase.spec.ts:87-93`、サーバー側 `crates/agrr-server/src/contact_messages.rs:65-76` |
| プライバシーポリシー等に reCAPTCHA / Google の利用表記が無い | 上記 grep が `frontend/src`（i18n JSON を含む）で 0 件 |
| Google スクリプトの動的ロードには既存の前例がある（`document.createElement('script')`、ブラウザ限定） | `frontend/src/app/services/google-analytics.service.ts:191-199` |
| ランタイム設定の前例: `window.*` を優先し `environment` にフォールバック | `frontend/src/app/core/google-ads-runtime-config.ts:12-28`、注入は `.cursor/skills/deploy-frontend/scripts/gcp-frontend-deploy.sh:71, 218-223` |
| `/contact` は事前レンダリング対象 | `frontend/src/app/core/seo/public-prerender-routes.ts:5` |

### 2.3 サーバーが検証している reCAPTCHA の種別

| 事実 | 根拠 |
|---|---|
| 検証先は `siteverify` エンドポイント（`api/siteverify`） | `crates/agrr-server/src/contact_message_recaptcha.rs:7` |
| 送信フォームは `secret` / `response` / `remoteip` の 3 項目 | 同 `:85-91` |
| 判定に使う応答フィールドは `success` と `error-codes` のみ。`score` / `action` / `hostname` は構造体に無く**検証していない** | 同 `:48-62, :117-121` |

読み取れる結論:

- 実装は「`success` が真ならよい」という**v2 相当の検証**である。
- `siteverify` の応答形式は v2 と v3 で共通のため、**トークンが v2 か v3 かはサーバー実装から区別できない**。v3 のトークンを渡した場合も `score` を見ずに通るので、ボット判定としては機能しない。
- Enterprise は別 API（`assessments`）を使うため、この実装では検証できない。ただしこの点は Google の仕様に関する記述であり、本調査では公式ドキュメントを再照会していない（未確認。実装着手前に確認する）。
- リポジトリにはどの種別の site key を発行したかの記録が無い。現ツリーに `RECAPTCHA_SITE_KEY` の語は存在せず、履歴上は削除済みの旧契約文書に「`RECAPTCHA_SITE_KEY / SECRET_KEY (オプション)`」とあるのみ（コミット `feecfbda9`、削除は `a40a3b87c`）。

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
| E2E スモーク `contact form submits successfully` は reCAPTCHA なしで成功を期待する。現行サーバー挙動と矛盾する | `frontend/e2e/smoke/operation-smoke.spec.ts:96-105` |
| ただし CI のスモーク実行スクリプトは `route` / `layout` / `wizard-progress` / `a11y` / `empty-state` しか実行せず、`operation-smoke.spec.ts` は含まれない | `scripts/run-e2e-smoke-ci.sh:118-135`、`frontend/package.json:28-34` |
| そのため、この矛盾は CI では検知されない（検知されなかった理由は推測。原因の断定はしない） | 同上 |
| `cargo test -p agrr-server` を実行する `test-common` のスクリプト・CI ステップは見つからない（`scripts/`、`.github/workflows`、`.cursor/skills/test-common` を grep して `-p agrr-server` のテスト実行は 0 件） | grep 結果（ビルドのみ `scripts/run-rust-contract-tests.sh:93-94`） |

### 2.6 RECAPTCHA_SECRET_KEY / site key の設定状況

| 対象 | 状況 | 根拠 |
|---|---|---|
| ローカル Docker（`agrr-server`） | **未設定**。compose の環境変数に無い → ヘルスは `recaptcha_configured:false`、POST は 503（コード上。コンテナ起動での実測は未実施） | `docker-compose.yml:28-40` |
| `env.example` / `env.gcp.example` / `env.gcp.test.example` | 記載なし | grep 0 件 |
| `docs/` 全体 | 記載なし（履歴上の削除済み文書を除く） | grep 0 件 |
| 本番 Cloud Run デプロイスクリプト | env ファイルに含めていない。`--set-secrets` は `SCHEDULER_AUTH_TOKEN` のみ | `.cursor/skills/deploy-server/scripts/_agrr-server-cloud-run.sh:104-125, 141, 149` |
| 上記の含意 | このスクリプトでデプロイした本番には secret が入らない。なお `gcloud run deploy --env-vars-file` は既存の環境変数を置換する仕様と理解しているが、公式ドキュメントでの再確認は未実施（未確認）。Cloud Run コンソールや別手段で手動設定されている可能性は排除できない | 同上 |
| **本番の実際の設定状態** | **未確認**。本環境に `gcloud` が無く（`command -v gcloud` が空）、`curl https://agrr.net/api/v1/health` は 10 秒でタイムアウトした。確認手順は §6.4 に記載 | 実行結果 |
| フロント側 site key の配布 | 仕組みなし。`gcp-frontend-deploy.sh` は `API_BASE_URL` / `STATIC_PATH_PREFIX` / Ads 2 変数だけを注入 | `.cursor/skills/deploy-frontend/scripts/gcp-frontend-deploy.sh:71, 218-223` |

### 2.7 経緯（git 履歴で確認）

- `feecfbda9`（2026-02-10）: Rails 時代に問い合わせフォームを実装。reCAPTCHA は「オプション」扱いで、Angular 側に実装は入っていない。
- `1e9b5baba`（2026-08-27、#1143）: Rust で reCAPTCHA 検証と IP レート制限を強制化。
- `e5d705383`（2026-08-29、#1205）: secret 未設定を fail-closed（503）に変更。

つまり**サーバー側で検証を強制化した時点でフロントの対応が行われていない**。これが本課題の直接原因である（履歴の読みによる。担当者の意図は未確認）。

### 2.8 関連する周辺事実（本課題の範囲外だが計画に影響する）

- Rust クレートに問い合わせメールの配送処理は見つからない（`smtp` / `mailer` / `lettre` の grep 0 件）。`sent_at` も更新されない。作成された `queued` 行を誰が読むかはリポジトリ上不明（運営側の受信経路は未確認）。
- `ContactMessage::validate()` は本番経路から呼ばれていない（呼び出しはエンティティ内の `valid()` とテストのみ）。gateway は空文字チェックだけを行う（`crates/agrr-adapters-sqlite/src/contact_messages/contact_message_gateway.rs:64-69`）。メール形式・長さのサーバー側検証は効いていない。
- レート制限の IP は `X-Forwarded-For` の**先頭要素**を採用する（`crates/agrr-server/src/contact_messages.rs:39-56`）。LB 配下でクライアントが偽装できるかは未確認。リミッタはプロセス内メモリで、Cloud Run は `--max-instances 1` / `--min-instances 0`（`_agrr-server-cloud-run.sh:140, 146`、`crates/agrr-server/src/contact_message_rate_limit.rs:66-69`）。

---

## 3. 仕様の確定

### 3.1 選択肢比較

| 案 | 内容 | 長所 | 短所 |
|---|---|---|---|
| **A1 v2 チェックボックス（推奨）** | フロントにウィジェットを実装。サーバーは現状の `success` 検証のまま | サーバー実装と意味が一致（`success` のみ判定）。サーバーは原則無変更。スパム対策要件（#1143）を維持 | 外部スクリプトと iframe が増える。CSP（§5.5）、プライバシー表記、a11y スモークへの影響 |
| A2 v2 invisible | 送信時に `execute()` | UI が簡素 | チャレンジが出た場合のフローが複雑。ウィジェット状態管理が増える |
| A3 v3 | スコアで判定 | ユーザー操作が不要 | **サーバーに `score` / `action` / `hostname` 検証と閾値方針の追加が必要**（§2.3）。閾値決定にプロダクト判断が必要。検証を足さないと保護にならない |
| A4 Enterprise | Enterprise API で検証 | 高機能 | サーバーの検証実装を差し替える大改修（アダプタ、認証情報、コスト）。過剰 |
| B サーバー側で要件を外す | reCAPTCHA を廃止しレート制限のみ | フロント無変更 | #1143・#1205 の方針を反転。レート制限はプロセス内メモリで、IP 取得も偽装余地がある（§2.8）。匿名の書き込み口の保護が弱くなる。fail-closed 方針とも逆向き |
| C 機能を無効化 | フォームを隠し `mailto:` 等の案内に置換 | 最小・即時にユーザーの誤誘導を止められる | 問い合わせ機能そのものを失う。恒久策ではない |

### 3.2 推奨

**A1（v2 チェックボックス）を採用する。** サーバーが実際に検証している内容（`success` の真偽）と一対一に対応し、サーバー側の検証ロジックを変えずに済む。C は A1 の実装完了まで**別途必要と判断された場合のみ**の暫定策とする（本書のスコープ外。ユーザー判断）。

サイトキー未設定・スクリプト読み込み失敗時は、**トークンなしで送信せず**、送信を無効化してエラー文言を表示する（フロント側も fail-closed。`ARCHITECTURE.md` の fail-closed 方針に整合）。

### 3.3 ユーザー確認が必要な点

| # | 確認事項 | 理由 |
|---|---|---|
| Q1 | reCAPTCHA の種別（推奨: v2 チェックボックス） | §3.1。v3 を選ぶ場合はサーバー変更が必須になり計画が変わる |
| Q2 | Google reCAPTCHA コンソールでのキー発行（登録ドメイン: `agrr.net` と必要なサブドメイン、開発用 `localhost`）と、本番 secret の Secret Manager 登録 | 人手の作業。secret 名は未確定（案: `recaptcha-secret-key`） |
| Q3 | プライバシーポリシー・Cookie 表記への reCAPTCHA / Google 利用の追記要否と文言 | 現状記載なし（§2.2）。法務・方針判断 |
| Q4 | 問い合わせ受信後の運営側の受信経路（`queued` 行を誰がどう読むか） | §2.8。送信が成功しても運営に届かない状態が残る可能性。本課題の対象に含めるか別課題にするか |
| Q5 | エラー応答に安定した `code` フィールドを**追加**してよいか（後方互換。§5.1） | API 契約の追加。課題 07 と整合が必要 |
| Q6 | 本番 LB へ CSP ヘッダーを適用する作業（`scripts/apply-lb-security-response-headers.sh`）の実施者とタイミング | 本番操作 |
| Q7 | E2E スモーク（`operation-smoke.spec.ts`）を CI スクリプトに含めるか | 現状 CI に含まれない（§2.5）。含める場合は外部通信の扱いが必要 |

---

## 4. 影響範囲

| 領域 | 影響 |
|---|---|
| ユーザー向け画面 | `/contact`、`/en/contact`（`frontend/src/app/routes/pages.routes.ts`、`locale-en.routes.ts`）。About / Terms / Privacy / footer / navbar から同ページへ誘導されている（`grep contact` で確認したファイル群。個別の挙動は未読） |
| 事前レンダリング | `contact` は prerender 対象（`public-prerender-routes.ts:5`）。ウィジェットの初期化は**ブラウザ限定**にする必要がある |
| API 契約 | `POST /api/v1/contact_messages` のリクエスト（`recaptcha_token` は既に受理済み）、エラー応答（`code` 追加案）。`docs/api/openapi.yaml` に `contact` の記載が無い（`grep -c contact` = 0）ので契約文書は存在しない → 課題 08 |
| バックエンド | 原則変更なし。`code` を追加する場合のみ `crates/agrr-server/src/contact_messages.rs` |
| デプロイ | サーバー: `_agrr-server-cloud-run.sh`（secret 注入）。フロント: `gcp-frontend-deploy.sh`（site key 注入）。Docker 開発: `docker-compose.yml`、`env.example` |
| セキュリティヘッダー | CSP Report-Only の更新（§5.5） |
| テスト | フロント unit / i18n カタログ、R4、E2E スモーク、a11y・layout スモーク（`/contact` を含む。`frontend/e2e/smoke/a11y-smoke-lib.ts`、`layout-conformance-bindings.mjs` が contact を参照。詳細な対象条件は未読） |
| 運用 | 本番 secret の登録と、デプロイスクリプトが secret を落とさないことの保証（§2.6） |

---

## 5. 対応方針

前提: 実装は[Q1〜Q3]の回答後に着手する（根拠ゲート）。以下は推奨案 A1 の前提での変更点。

### 5.1 バックエンド（`crates/agrr-server`）

ドメイン（`agrr-domain`）は変更しない。interactor は既に `NotConfigured` / `Error` を出力ポートで区別している（`create_contact_message_interactor.rs:53-69`）。

| ファイル | 変更 | 難易度 |
|---|---|---|
| `crates/agrr-server/src/contact_messages.rs` | `failure_response`（`:58-79`）の Recaptcha 失敗に `"code":"recaptcha_failed"`、Unavailable に `"code":"recaptcha_unavailable"` を**追加**（既存の `error` は維持）。プレゼンタが HTTP 形状のみを決める（R6）ので層違反にならない | 低 |

理由: 現状 422 は reCAPTCHA 失敗とバリデーション失敗の両方で使われ、`error`（英語の可変文字列）と `errors`（配列）で見分けるしかない。503 も Cloud Run 基盤起因と区別できない。文字列一致で判別するのは脆いので、安定した `code` を足す。**Q5・課題 07 の回答次第**で、追加しない場合はフロントを本文の形状（`error` 文字列 vs `errors` 配列）と HTTP ステータスで判別する暫定実装になる（この場合は課題 07 の契約決定後に置換）。

### 5.2 フロントエンド（`frontend/src/app`）

依存方向は `components → usecase → domain`、HTTP と外部スクリプトは `adapters/`（`ARCHITECTURE.md` の Frontend 節）。

| 層 | ファイル | 変更 |
|---|---|---|
| domain | `domain/contact/contact-message.model.ts` | ペイロードに `recaptcha_token` を追加。`validatePayload` が空 token を `contact_form.validation.recaptcha_required` で拒否。`ContactMessageRecord` を**サーバー契約に合わせて** `{ id: number; status }` のみの作成結果型へ縮小（案 a）。`email` / `message` / `created_at` / `sent_at` を除去 |
| usecase | `usecase/contact/contact-gateway.ts`、`send-contact-message.dtos.ts` | 戻り値型と成功 DTO を縮小型へ。`created_at` / `sent_at` を除去 |
| usecase | `usecase/contact/send-contact-message.usecase.ts` | `toErrorDto`（`:49-58`）を、`code` で `recaptcha_failed` → `contact_form.errors.recaptcha_failed`、`recaptcha_unavailable` → `contact_form.errors.recaptcha_unavailable`、`errors` 配列付き 422 → `validation_failed`、それ以外 → `send_failed` に。到達不能な `status === 'failed'` 分岐（`:32-35`）を削除 |
| usecase | `usecase/contact/recaptcha-widget.port.ts`（新規） | ウィジェット描画・リセット・利用可否のポートと `InjectionToken`。コンポーネントがアダプタを直接 import しないための境界（既存の `contact-form.providers.ts:1-12` の束ね方に従う） |
| usecase | `usecase/contact/contact-form.providers.ts` | ポートの実装を提供 |
| adapters | `adapters/contact/http-contact-gateway.service.ts` | 応答マッピング（`:19-31`）を `{ id, status }` のみに。ペイロード（token 含む）をそのまま POST |
| adapters | `adapters/contact/google-recaptcha-widget.adapter.ts`（新規） | `api.js?render=explicit&hl=<言語>` の動的ロード（`google-analytics.service.ts:191-199` の方式を踏襲し、`isPlatformBrowser` でブラウザ限定、多重ロード防止）、`grecaptcha.render` / `reset`、期限切れコールバック、ロード失敗の通知 |
| core | `core/recaptcha-runtime-config.ts`（新規） | `window.RECAPTCHA_SITE_KEY` を優先し `environment.recaptchaSiteKey` にフォールバック（`google-ads-runtime-config.ts:12-28` と同型）。空文字なら「利用不可」 |
| core | `environments/environment*.ts`（`environment.ts`、`environment.prod.ts`、`environment.gcp-test.ts`） | `recaptchaSiteKey` を追加。dev は Google が公開しているテスト用 site key（値は実装時に公式ドキュメントで確認。本書には記載しない）、prod は空（デプロイ注入） |
| components | `components/contact-form/contact-form.component.ts`（＋必要なら同ディレクトリの子コンポーネント） | 本文と送信ボタンの間（現テンプレート `:99-102` の間）にウィジェットのホスト要素を置く。トークン保持、送信時に `recaptcha_token` をペイロードへ、**送信の成否にかかわらず送信後にウィジェットをリセット**（v2 のトークンは 1 回限り。サーバーは検証後に gateway を呼ぶため、失敗しても消費される: `interactor:53-71`）、利用不可なら送信無効化とメッセージ表示 |
| i18n | `assets/i18n/{ja,en,in}.json` | §5.4 |
| e2e | `frontend/e2e/smoke/operation-smoke.spec.ts` | §6.3 |

UI 構成規約（`docs/design/UI-COMPOSITION-RULES.md`）への適合:

- ウィジェットのホストは L3 ページ配下のフォーム内に置く。ページテンプレートにレイアウト CSS を直書きしない。既存の `form-card__field` / `form-card__actions` クラス（`contact-form.component.ts:46, 102`）と `_form-primitives.css` の範囲で構成する。
- L1 Pattern は Gateway / UseCase を呼べない規則があるため、スクリプトロードを伴うウィジェットは `components/shared/patterns/` に置かない。`components/contact-form/` 配下に閉じる。
- `check:ui-composition` の禁止パターン（規約の「Forbidden patterns」節）に触れないこと。実行方法は §6 の前提を参照（実行は未実施）。
- 事前レンダリング時にウィジェットを初期化しない（SSR 安全）。
- `hl`（表示言語）はスクリプト読み込み時に固定される。SPA 内で言語を切り替えたときの再描画は**未確認**（§8）。

### 5.3 site key の配布方法

| 案 | 内容 | 評価 |
|---|---|---|
| **1. デプロイ時 `window.RECAPTCHA_SITE_KEY` 注入（推奨）** | `gcp-frontend-deploy.sh` に `RECAPTCHA_SITE_KEY`（`.env.gcp.frontend`）を追加し、`ADS_ASSIGN` と同じ方式で `INJECT_SNIPPET` に含める（`:71, 218-223`）。フロントは `window` を優先、`environment` にフォールバック | 既存の Ads 用と同型（実装統一）。site key は公開情報なので露出は問題ない。再ビルド不要。サーバー secret との組の不一致は自動検知できない → 運用手順で担保（§6.4） |
| 2. `environment.prod.ts` に固定値 | 値をコミット | 単純だが、キー更新にビルドが要る。環境別（gcp-test）に分けにくい |
| 3. サーバー API で配布 | ヘルスまたは新エンドポイントで site key を返す | secret との一貫性は最良だが、公開 API 面と OpenAPI（課題 08）を増やす。別環境変数 `RECAPTCHA_SITE_KEY` をサーバーにも持たせる必要がある |

推奨は 1。site key が空のときはフロントが「利用不可」として送信を止める。

### 5.4 i18n キー（ja / en / in）

既存の `contact_form` ブロックは `ja.json:1529-1551`、`en.json:219-241`、`in.json:1292-`。`in` は Hindi（`in.json` の内容で確認）。追加するキー案:

| キー | 用途 |
|---|---|
| `contact_form.recaptcha.aria_label` | ウィジェット領域のラベル（a11y） |
| `contact_form.validation.recaptcha_required` | チェック未実施のまま送信 |
| `contact_form.errors.recaptcha_failed` | サーバーが検証失敗（422 + `recaptcha_failed`）。再チェックを促す |
| `contact_form.errors.recaptcha_unavailable` | site key 未設定 / スクリプト読み込み失敗 / サーバー未設定（503 + `recaptcha_unavailable`）。時間をおく旨または別手段の案内 |

429（`rate_limit`）専用文言はエラー契約（課題 07）で扱う。本課題では追加しない。

`frontend/src/app/core/i18n/contact-form-locale.catalog.spec.ts` の `CONTACT_FORM_KEYS`（`:17-33`）へ同キーを追加して 3 ロケールを網羅する。

### 5.5 CSP / `security_headers.rs` への影響

| 事実 | 根拠 |
|---|---|
| CSP は**Report-Only**のみ（enforce ではない）。`report-uri` / `report-to` ディレクティブは無い | `crates/agrr-server/src/security_headers.rs:12-19, 35-39` |
| 現行 `script-src` は `'self' 'unsafe-inline' 'unsafe-eval'` と GTM / GA のみ。`frame-src` の指定は無く `default-src 'self'` にフォールバックする | 同 `:13-19` |
| 同じ値が `scripts/agrr-security-response-headers.yaml` に複製されている。LB 側は `agrr-frontend-backend` 等に適用される | `scripts/agrr-security-response-headers.yaml`、`scripts/agrr-lb-backend-security-headers.yaml` |
| **SPA の HTML に付くのは LB バックエンドバケットのヘッダーで、agrr-server の CSP ミドルウェアは API 応答にのみ付く**（reCAPTCHA を読み込むのは SPA 側） | 上記 2 ファイルの構成から。LB の実設定値そのものは未確認 |
| 整合検証: `scripts/verify-security-response-headers-lib.mjs` はヘッダー名・バックエンド名・Rust の定数名の存在を見る（値は比較しない）。CI で `node --test scripts/verify-security-response-headers.test.mjs` が走る | `scripts/verify-security-response-headers-lib.mjs:4-23`、`.github/workflows/frontend-test.yml:155` |

含意:

- Report-Only のため**現状のままでも送信自体は阻害されない**。ただし enforce へ移行する際に reCAPTCHA が壊れないよう、同時に許可を足しておくのが妥当（推奨）。
- 追加するオリジン（Google の公開ドキュメントに基づく想定。実装時に公式ドキュメントで再確認する）: `script-src` に `https://www.google.com/recaptcha/` と `https://www.gstatic.com/recaptcha/`、`frame-src` に `https://www.google.com/recaptcha/` と `https://recaptcha.google.com/recaptcha/`。
- 変更箇所は**同期して 2 か所**: `security_headers.rs` の `CONTENT_SECURITY_POLICY_REPORT_ONLY` と `scripts/agrr-security-response-headers.yaml`。LB への反映は本番操作（Q6）で、`scripts/apply-lb-security-response-headers.sh` を使う（実行はユーザー判断）。

### 5.6 設定・デプロイ・ドキュメント

| ファイル | 変更 |
|---|---|
| `.cursor/skills/deploy-server/scripts/_agrr-server-cloud-run.sh` | 本番は `--set-secrets` に `RECAPTCHA_SECRET_KEY=<secret名>:latest` を追加（`:149`）。test モードは既存の `SCHEDULER_AUTH_TOKEN` と同様に環境変数から env ファイルへ（`:121-124` の方式）。secret を落とさないことの保証が目的 |
| `.cursor/skills/deploy-frontend/scripts/gcp-frontend-deploy.sh` | `RECAPTCHA_SITE_KEY` を読み、`INJECT_SNIPPET` へ注入（`:71, 218-223`）。冒頭のコメント（`:3-16`）と `.cursor/skills/deploy-frontend/SKILL.md` の `.env.gcp.frontend` 項目を更新 |
| `docker-compose.yml` | `agrr-server` の environment に `RECAPTCHA_SECRET_KEY=${RECAPTCHA_SECRET_KEY:-}`（`:28-40`）。空のままなら意図どおり 503（fail-closed）。ローカルで通すには Google のテスト用 secret を `.env` に置く |
| `env.example` | `RECAPTCHA_SECRET_KEY`（サーバー）と `RECAPTCHA_SITE_KEY`（フロントのデプロイ / 開発）の説明を追加 |
| `env.gcp.example` | 本番は Secret Manager で管理する旨（`SCHEDULER_AUTH_TOKEN` の注記 `:56` と同型） |

`crates/*` を変更した場合、Docker での検証前に `.cursor/skills/dev-docker/scripts/rebuild-restart.sh` が必須（`docker compose restart` は不可。ワークスペースの規約）。

---

## 6. TDD 計画

各項目は **RED（失敗を確認）→ GREEN → REFACTOR**（`tdd-on-edit`）。実行は `test-common` のスクリプトのみ。出力は `./tmp/{UUID}.log` にリダイレクトしてから grep する（`AGENTS.md`）。`npm test` の直接実行・`rails test` は禁止。個別実行の引数の書式（`run-test-frontend.sh` は `npm test -- --watch=false "$@"` に転送: `.cursor/skills/test-common/scripts/run-test-frontend.sh`）は、`ng test` の絞り込みオプションがこのリポジトリで有効かを実装時に確認する（未確認）。

### 6.1 フロントエンド（`.cursor/skills/test-common/scripts/run-test-frontend.sh`）

| ID | ファイル案 | given / when / then | RED になる理由 |
|---|---|---|---|
| F1 | `domain/contact/contact-message.spec.ts` | given 有効な email/message で `recaptcha_token` が空 / when `validatePayload` / then `{ valid:false, message:'contact_form.validation.recaptcha_required' }` | 現行は token を検査しない |
| F2 | `adapters/contact/http-contact-gateway.service.spec.ts` | given サーバー応答 `{id:7,status:'queued'}` / when `postMessage` / then 結果が **`toStrictEqual({id:7,status:'queued'})`**（`email` 等のキーが無い） | 現行は `email:undefined` などのキーを持つオブジェクトを返す（`toEqual` は undefined を無視するため `toStrictEqual` を使う） |
| F3 | 同上 | given ペイロードに `recaptcha_token:'tok'` / when `postMessage` / then `apiClient.post` が `('/api/v1/contact_messages', payload)` で呼ばれ body に token を含む | ペイロード型に無く、型・テストが存在しない（挙動は転送のみなので characterization。F5 と組で意味を持つ） |
| F4 | `usecase/contact/send-contact-message.usecase.spec.ts` | given ゲートウェイが `{id:1,status:'queued'}` / when `execute` / then `onSuccess({id:1,status:'queued'})` のみで呼ばれ、`created_at` / `sent_at` を含まない | 現行は `sent_at:null` を付与する（`:40-47`） |
| F5 | 同上 | given ゲートウェイが `{status:422,error:{error:'reCAPTCHA failure: invalid-input-response',code:'recaptcha_failed'}}` で失敗 / then `onError({message:'contact_form.errors.recaptcha_failed'})` | 現行は 422 を一律 `validation_failed` |
| F6 | 同上 | given `{status:503,error:{error:'reCAPTCHA is not configured',code:'recaptcha_unavailable'}}` / then `onError({message:'contact_form.errors.recaptcha_unavailable'})` | 現行は `send_failed` |
| F7 | 同上 | given `{status:422,error:{errors:["Email is invalid"]}}`（実サーバーの本文形状に修正した fixture）/ then `validation_failed`（回帰防止） | 既存テストの fixture が `field_errors` という実在しない形状（`:87-93`）。fixture 修正と同時に維持を確認 |
| F8 | `components/contact-form/contact-form.component.spec.ts` | given ウィジェットが token `'tok'` を通知し入力が有効 / when `submit()` / then `useCase.execute` が `recaptcha_token:'tok'` 付きペイロードで 1 回呼ばれる | 現行は token を持たない（`:176-184`） |
| F9 | 同上 | given token 未取得 / when `submit()` / then `useCase.execute` が呼ばれず、`control.message` が `contact_form.validation.recaptcha_required` の validation 種別 | 同上 |
| F10 | 同上 | given `execute` の完了（成功・失敗の両方）/ then ウィジェットの `reset` が呼ばれる | 機能なし |
| F11 | 同上 | given site key 未設定（ポートが利用不可）/ when 描画 / then 送信ボタンが無効で `contact_form.errors.recaptcha_unavailable` が表示され、`execute` は呼ばれない | 機能なし |
| F12 | `adapters/contact/google-recaptcha-widget.adapter.spec.ts`（新規） | given ブラウザ環境で `window.grecaptcha` をスタブ / when `render(host, siteKey, callbacks)` / then `render` が `sitekey` とコールバック付きで呼ばれ、`api.js` の `<script>` は 1 回だけ挿入される。given サーバープラットフォーム / then `document` に触れず利用不可を返す。given script の `onerror` / then 利用不可を通知 | 新規 |
| F13 | `core/recaptcha-runtime-config.spec.ts`（新規） | `window.RECAPTCHA_SITE_KEY` が優先、空白はトリム、未設定なら `environment.recaptchaSiteKey`、双方空なら空文字 | 新規 |
| F14 | `core/i18n/contact-form-locale.catalog.spec.ts` | `CONTACT_FORM_KEYS` に §5.4 の 4 キーを追加 → ja / en / in の 3 ロケール分が失敗 | JSON 未追加 |

RED の確認: 上記を追加し、`test-common` で **意図した理由で失敗**すること（F1〜F14 のうち新規実装が必要なもの）を確認してから GREEN に進む。GREEN 後は個別 → 引数なしの全体 → `test-slow-detection`。

### 6.2 バックエンド

`agrr-domain` は変更しないが、回帰確認として `.cursor/skills/test-common/scripts/run-test-rust-domain.sh` を実行する。

| ID | 場所 | given / when / then | 実行 |
|---|---|---|---|
| B1 | `crates/agrr-r4-contract/tests/contracts.rs`（既存 `:4476` を拡張） | given secret 未設定のサーバー / when POST / then 503 かつ `json["code"] == "recaptcha_unavailable"`（`error` に "reCAPTCHA" を含む既存断言は維持） | `scripts/run-rust-contract-tests.sh`。RED: `code` が無い |
| B2 | 同（既存 `:4567` を拡張） | given secret 設定済みで無効 token / when POST / then 422 かつ `code == "recaptcha_failed"` | 同。RED: 同上 |
| B3 | 同（新規 `post_contact_message_returns_422_when_recaptcha_token_missing`） | given secret 設定済み / when `recaptcha_token` を省略して POST / then 422、`error == "reCAPTCHA token is required"`、`code == "recaptcha_failed"` | 同。**現行フロントが実際に踏む経路**の契約化。`code` 以外は既存挙動なので、`code` 追加前は `code` 断言で RED |
| B4 | `crates/agrr-server/src/contact_messages.rs` の `mod tests`（`:135-178`） | `failure_response(recaptcha("bad"))` → 422・`error=="bad"`・`code=="recaptcha_failed"`。`failure_response(unavailable(..))` → 503・`code=="recaptcha_unavailable"`。既存 `failure_response_unavailable_returns_503`（`:141-147`）の維持 | `cargo test -p agrr-server` を実行する `test-common` スクリプトは**見つからない**（§2.5）。`run-test-rust-domain.sh` は引数を `cargo test -p agrr-domain "$@"` に渡すので `-p agrr-server <filter>` を付与すれば実行できる可能性があるが**未確認**。使えなければ B1〜B3 を正とし、B4 の運用はユーザーに確認 |
| B5 | `crates/agrr-server/src/security_headers.rs` の `mod tests`（`:52-`） | given `CONTENT_SECURITY_POLICY_REPORT_ONLY` / then `script-src` に `https://www.google.com/recaptcha/` と `https://www.gstatic.com/recaptcha/`、`frame-src` に `https://www.google.com/recaptcha/` を含む | B4 と同じ実行上の注意 |
| B6 | `scripts/verify-security-response-headers-lib.mjs` ＋ `.test.mjs` | given `agrr-security-response-headers.yaml` / then CSP に同じ reCAPTCHA オリジンを含む（Rust 定数との重複は値ではなく契約として検証） | CI は `node --test`（`.github/workflows/frontend-test.yml:155`）。`test-common` に対応スクリプトが無いため、実行経路はユーザーに確認 |

サーバーのロジック変更は `code` の追加だけなので、reCAPTCHA の検証そのものの RED は無い（`contact_message_recaptcha.rs` の単体テスト 4 件、`:185` 以降の `verify_*` と `parse_verify_response_*` が検証ロジックを固定済み）。

### 6.3 E2E / 手動

| ID | 内容 |
|---|---|
| E1 | `operation-smoke.spec.ts:96-105` を新仕様へ更新。Google 実サービスへの依存を避けるため、Playwright で `api.js` 読み込みをスタブして決定的にする案を推奨。サーバー側検証は `RECAPTCHA_VERIFY_URL` をモックに向けるか、Google の公開テストキーペアを使う（外部通信の可否は CI 環境で未確認。Q7） |
| E2 | `a11y` / `layout` スモーク（`/contact` を含む）が、iframe 追加後も GREEN であること。`npm run check:ui-composition` の結果（実行は未実施） |
| E3 | gcp-test（`gcp-test-local` スキル）で実キーを用いた手動確認（キー発行は Q2） |

### 6.4 本番の事前確認手順（未確認事項の解消）

1. `GET https://agrr.net/api/v1/health` の `recaptcha_configured` と `warnings` を確認する（`routes.rs:33-46`）。`gcloud` が使える環境なら Cloud Run のサービス定義の環境変数・シークレット参照も確認する（本調査では未実施）。
2. `false` の場合は、Secret Manager への登録と Cloud Run への注入が**フロント公開より先**に必要。
3. デプロイ後に `recaptcha_configured:true` と `warnings:[]` を確認。site key と secret が同じキーペアであることは、実キーでの 1 件の送信で確認する（自動検知手段は無い）。

---

## 7. 実装ステップ

1〜2 の前に Q1〜Q3 の回答を得る。各ステップは「RED → GREEN → REFACTOR → 全体実行 → `test-slow-detection`」で完結させ、ステップ単位でコミットする。

| # | 内容 | テスト | コミット |
|---|---|---|---|
| 1 | 成功レスポンス型の是正（`ContactMessageRecord` を縮小、ゲートウェイ / ユースケース / DTO / 既存テスト fixture の修正、到達不能な `failed` 分岐の削除） | F2, F4 | `fix(frontend): align contact gateway types with API contract` |
| 2 | サーバーのエラー応答に `code` を追加 | B1〜B4 | `feat(server): add code to contact reCAPTCHA error responses`。`crates/*` 変更のため `rebuild-restart.sh` 後に R4 |
| 3 | ユースケースのエラー写像（reCAPTCHA / 未設定 / バリデーションを区別） | F5〜F7 | `fix(frontend): map contact reCAPTCHA errors distinctly`（2 に依存） |
| 4 | site key ランタイム設定 + ウィジェットポート / アダプタ + ドメインのトークン検証 | F1, F12, F13 | `feat(frontend): add reCAPTCHA widget port and adapter` |
| 5 | コンポーネント統合（ホスト要素、token 送信、リセット、利用不可時の fail-closed）+ i18n（ja/en/in）+ カタログ spec | F8〜F11, F14 | `feat(frontend): require reCAPTCHA in contact form` |
| 6 | CSP（`security_headers.rs` と `agrr-security-response-headers.yaml` を同期） | B5, B6 | `chore(security): allow reCAPTCHA origins in CSP report-only` |
| 7 | 設定・デプロイ・ドキュメント（compose、env 例、server / frontend デプロイスクリプト、スキル文書） | `DRY_RUN=1` によるデプロイスクリプトの出力確認（`gcp-frontend-deploy.sh` は `DRY_RUN` を持つ。注入部に既存の自動テストは無い: `.cursor/skills/deploy-frontend/scripts/*.test.mjs` は該当なし） | `chore(deploy): wire RECAPTCHA_SECRET_KEY and RECAPTCHA_SITE_KEY` |
| 8 | E2E スモーク更新（と Q7 次第で CI への組み込み） | E1, E2 | `test(e2e): update contact form smoke for reCAPTCHA` |
| 9 | 手動確認（E3）と本番展開（ユーザー作業） | §6.4 | なし |

本番展開の順序: (1) secret 登録 → (2) サーバーをデプロイ（フォームは引き続き失敗するが現状と同じで悪化しない）→ (3) フロントを `RECAPTCHA_SITE_KEY` 付きでデプロイ → (4) LB の CSP 反映（Q6）。

---

## 8. リスク・未確定事項

| # | 内容 | 状態 |
|---|---|---|
| R1 | 本番の `RECAPTCHA_SECRET_KEY` の有無 | 未確認（§2.6）。§6.4 で解消 |
| R2 | デプロイスクリプトが手動設定の secret を消す可能性（`--env-vars-file` の置換仕様） | gcloud の仕様理解に基づく。未確認 |
| R3 | site key と secret のキーペア不一致は自動検知できない | 運用手順で担保 |
| R4 | v2 トークンは 1 回限り・有効期限あり。送信失敗後に再利用できない | 対策: 成否にかかわらずリセット（F10）。トークン期限切れコールバックの扱いは実装時に確認（Google の仕様。未確認） |
| R5 | SPA 内の言語切替（`hl`）に追従した再描画 | 未確認。追従が難しい場合は「ページ読み込み時の言語」で固定する妥協案を Q として再確認 |
| R6 | Google の iframe が a11y / layout スモークに与える影響 | 未確認。E2 で確認 |
| R7 | CI で Google への外部通信が可能か | 未確認（Q7）。不可ならスタブ / モックで統一 |
| R8 | 送信成功後の運営側の受信経路が不明（`queued` 行の消費者が見当たらない） | Q4。本課題で直すと範囲が拡大する |
| R9 | Cookie / プライバシー表記の追記要否 | Q3 |
| R10 | `code` 追加は API 契約の追加。課題 07 の決定と名称・形式が食い違うと二重改修になる | 課題 07 の方針を先に確認 |
| R11 | `test-common` にサーバークレート単体テスト・スクリプトテスト（`node --test`）の入口が無い | B4〜B6 の実行経路をユーザーに確認。使えない場合、サーバー側の RED は R4（B1〜B3）で代替 |
| R12 | 到達不能な `failed` 分岐と関連テストの削除は、将来「作成応答で `failed` を返す」設計を想定していないという判断を含む | R4 契約は `queued` のみ固定（§2.4）。異議があれば分岐を残す |
| R13 | 実機（Docker 起動 / 本番）での再現は未実施 | 本書の失敗経路は、単体テスト・R4 契約・フロントのコード読みの組合せに基づく |

---

## 9. 受け入れ条件

1. 有効な site key・secret（テスト用キーペアで可）を設定した環境で、`/contact` のフォームに入力し reCAPTCHA を完了して送信すると、サーバーが 201 `{id,status:"queued"}` を返し、画面に成功メッセージが表示される。
2. reCAPTCHA 未完了で送信すると、`useCase.execute` を呼ばずに `contact_form.validation.recaptcha_required` が表示される（F9）。
3. サーバーが reCAPTCHA 検証失敗（422）を返したとき、`contact_form.errors.recaptcha_failed` が表示され、入力エラー文言（`validation_failed`）にならない。ウィジェットがリセットされる（F5, F10）。
4. サーバー側 secret 未設定（503）または site key 未設定・スクリプト読み込み失敗のとき、送信は行われず `contact_form.errors.recaptcha_unavailable` が表示される（F6, F11, F12）。
5. `frontend` の `ContactMessageRecord` 相当の型とゲートウェイ / ユースケースのテストが、サーバーの実応答 `{id, status}` と一致する（F2, F4）。
6. i18n の新規キーが ja / en / in の全てに定義されている（F14）。
7. R4 契約（B1〜B3）が GREEN。`agrr-domain` の既存テストが GREEN。フロントの全体テストが GREEN。`test-slow-detection` を実施済み。
8. `docker-compose.yml` / `env.example` / デプロイスクリプトで `RECAPTCHA_SECRET_KEY` と `RECAPTCHA_SITE_KEY` の入力口が定義され、本番デプロイが secret を落とさない。
9. 本番: `GET /api/v1/health` が `recaptcha_configured:true` かつ `warnings:[]`。実キーで 1 件送信できる（ユーザー作業）。
10. CSP（Report-Only）に reCAPTCHA のオリジンが含まれ、Rust 定数と YAML の内容が一致する（B5, B6）。
11. `/contact` の a11y / layout スモークと `check:ui-composition` が GREEN（E2）。
12. E2E スモークの問い合わせテストが新仕様と矛盾しない（E1）。CI に含めるかは Q7 の回答による。

---

## 10. 関連課題との依存

`docs/spec-defects/` には本書作成時点で `03-api-key-scope-docs.md` と `04-api-key-query-auth.md` しか存在しない。**01・05〜11 の内容は未読**であり、以下は課題名と本書の調査結果からの見立てである（未確認）。

| 課題 | 関係 | 内容 |
|---|---|---|
| 01 resource-limit-bypass | 弱い関連 | 本課題は匿名エンドポイントで農場・作物の上限と無関係。ただし §2.8 のレート制限（IP 取得・プロセス内メモリ・単一インスタンス前提）が制限回避の議論と重なる可能性がある。重複の有無は 01 を確認してから判断 |
| 03 api-key-scope-docs | 依存なし | 認証つき API 用。問い合わせは匿名 |
| 04 api-key-query-auth | 依存なし | 同上 |
| 05 fail-closed-critical / 06 fail-closed-suspected | 方針が整合 | secret 未設定→503 は fail-closed の実例（`ARCHITECTURE.md` の fail-closed 節）。案 B（要件を外す）は方針と逆向き。フロントの「site key 未設定なら送信しない」も同方針。両課題の列挙対象に本件が含まれるかは未確認 |
| **07 frontend-error-contract** | **強い依存** | エラー判別（`code`）とユースケースのエラー写像を本課題で導入する。07 が共通エラー契約を定めるなら、名称・形式を先に合わせる（R10、Q5）。429 専用文言も 07 側で扱う |
| 08 openapi-gaps | 依存（入力提供） | `docs/api/openapi.yaml` に `contact_messages` の記載が無い（§4）。本課題の確定契約（`recaptcha_token`、201 / 422 / 429 / 503、`code`）を 08 に渡す。本課題で OpenAPI を追加するか 08 に委ねるかは 08 の範囲次第 |
| 09 stale-design-docs | 関連 | 問い合わせの旧契約文書は履歴上削除済み（`a40a3b87c`）で、現行の契約文書が無い。今回の環境変数追加を反映する docs の所在も含め、09 と重複しないよう調整 |
| 10 authorization-consistency | 依存なし（未確認） | 匿名エンドポイントのため対象外の見立て。`GET /api/v1/contact_messages` は常に空配列を返す実装（`crates/agrr-server/src/contact_messages.rs:24-27`）で、データは出ない |
| 11 low-priority-misc | 移管候補 | §2.8 の「`ContactMessage::validate()` が本番経路で未使用」「X-Forwarded-For 先頭要素の採用」「`GET` ダミー」は本課題の範囲外。11 または新規課題へ |
