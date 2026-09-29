# 04. API キーのクエリ認証（`?api_key=`）: 文書と実装の不一致

**種別:** 仕様不具合の対応計画（ドキュメント）。本書はコードを変更しない。
**対象:** `docs/api/getting-started.md`（Masters API 認証の説明）と `crates/agrr-server/src/masters_auth.rs`（実装）。

根拠は 2026-09-29 時点で実際に読んだファイル・実行した `git log` のみ。読んでいないものは「未確認」と明記する。

---

## 1. 概要と重大度

| 項目 | 内容 |
| ---- | ---- |
| 事象 | 公開文書は `?api_key=<key>` を「クエリ（非推奨）」の認証方式として載せているが、サーバーはクエリのキーを読まず、その要求を 401 にする。 |
| 種別 | 文書の誤り（実装は意図的に変更済み）。実装の欠陥ではない。 |
| 重大度 | **中（文書起因の利用者影響）**。この方式の利用者は 401 になる。認証が意図せず通るという安全側の不具合ではない。セキュリティ上は現状の実装（クエリを受けない）が望ましい。 |
| 緊急度 | 文書を実装に合わせる小さな修正で解消できる。 |
| 推奨 | 選択肢 A（文書からクエリ認証を削除し、実装は現状維持）。§3 参照。 |

---

## 2. 現状（確認済み事実）

### 2.1 文書

- `docs/api/getting-started.md:24-30` の認証表に 3 行ある: Bearer（`:28`）、ヘッダー `x-api-key`（`:29`）、`クエリ（非推奨） | ?api_key=<api_key>`（`:30`）。
- `docs/api/openapi.yaml:386-399` の `securitySchemes` は `bearerApiKey`（http bearer）、`headerApiKey`（`x-api-key`）、`sessionCookie` のみ。トップレベル `security`（`:23-25`）も Bearer とヘッダーの 2 つだけ。`in: query` の API キー方式は無い。
- `tools/agrr-mcp/src/agrr-client.mjs:68` は `Authorization: Bearer` のみ使用。`tools/agrr-mcp/README.md:15` も Bearer と記載。クエリの記載は無い。
- `frontend/src/app/components/settings/api-keys/api-keys.component.ts:79-81` の使い方表示は `X-API-Key` と `Authorization: Bearer` のみ。`frontend/src` で i18n キー `api_keys.usage.query` を検索したが該当は無かった。
- `?api_key=` の記載が残るのは、`docs/`・`frontend/src`・`tools`・`crates`・`README.md` を検索した範囲では `docs/api/getting-started.md:30` のみ（`docs/migration/archive/**` は除外）。テストの検証用 URL（`crates/agrr-r4-contract/tests/contracts.rs:3147`）は別。
- `docs/api/getting-started.md` の最終変更コミットは `4d0760283`（API キー UI・レート制限・API 文書追加, #320）。下記の削除コミットより前で、その後この文書は更新されていない（`git log --oneline -3 -- docs/api/getting-started.md`）。

### 2.2 実装

- `crates/agrr-server/src/masters_auth.rs:44` `pub fn extract_api_key(headers: &HeaderMap, _query: Option<&str>) -> Option<String>`。`_query` は参照されない。読むのは次の 2 つだけ。
  - `Authorization: Bearer <key>`（`:45-53`）
  - `x-api-key`（`:54-59`）
  - どちらも無ければ `None`（`:60`）。
- 単体テスト `masters_auth.rs:177-181` `extract_api_key_ignores_query_parameter`: 空ヘッダーに `Some("secret-key")` を渡すと `None` になることを表明。
- R4 契約テスト `crates/agrr-r4-contract/tests/contracts.rs:3140-3150` `get_masters_with_query_api_key_is_rejected`: `regenerate_api_key` で得たキーを `GET /api/v1/masters/crops?api_key={key}`（Cookie・ヘッダーなし）に付けると **401** を表明。**クエリ拒否の回帰テストは既にある。**
- 同ファイル `:2758-2782` `post_masters_crop_setup_proposal_with_api_key_authenticates`: `Authorization: Bearer` で dry_run が 200。Bearer の正常系が既にある。
- 401 の本文は `{"error":"unauthorized"}`（`masters_auth.rs:102-107` の `unauthorized()`）。ヒント文言は無い。

### 2.3 `extract_api_key` と `resolve_masters_*` の呼び出し元（全数）

`rg` で `crates/` 全体を検索した結果。

| 呼び出し元 | file:line | クエリ引数 | 意味 |
| ---------- | --------- | ---------- | ---- |
| `resolve_masters_principal` | `masters_auth.rs:70` | `query_api_key`（引数をそのまま渡す） | `extract_api_key` の唯一の呼び出し元。渡しても無視される。 |
| `resolve_masters_user_id` | `masters_auth.rs:92` | `query_api_key` を素通し | `resolve_masters_principal` の薄いラッパー。 |
| `MastersUserId::from_request_parts` | `masters_auth.rs:142` | **`None`** | Masters の全ハンドラが使う抽出子（`masters_*.rs` 16 ファイルが `use crate::masters_auth::MastersUserId`）。 |
| `masters_rate_limit::middleware` | `masters_rate_limit.rs:163` | **`None`** | レート制限。認証失敗は制限せず素通し（`:164-171`）。 |

- 呼び出し元は Masters のみ。`api_keys.rs`（`session_id` Cookie の `CookieJar`, `:4,15,48-62`）、`ai_api.rs`（`user_id_from_session`, `:8,152` ほか）、`cable.rs`（`resolve_cable_session` が `user_id_from_session`, `:398-399`）は API キーを扱わない。
- `crates/` 全体で `x-api-key` を扱うのは `masters_auth.rs:54` のみ。`routes.rs:76-88` の `extract_scheduler_token` は `X-Scheduler-Token` / `Authorization: Bearer`（スケジューラ用トークン）で、API キーとは別物。
- 結論: **クエリ引数が実際に値を持って渡される箇所は 0 件。** 2 つの関数（`resolve_masters_principal` / `resolve_masters_user_id`）のシグネチャに未使用のクエリ引数 `query_api_key` が残っているだけで、コード上の死んだ引数になっている（§5 の任意整理を参照）。

### 2.4 履歴（`git log`、閲覧のみ）

**クエリ認証は意図的に削除された。**

- コミット `e8331a2df` "fix(security): mask /me api_key and stop localStorage auto-save (#1165) (#1176)"（`git log -S"_query" -- crates/agrr-server/src/masters_auth.rs` で特定）。
- コミットメッセージに "Reject query-string api_key for Masters API auth" と明記。同時に次を実施。
  - `masters_auth.rs`: `extract_api_key` からクエリ分岐と `query_api_key_param` を削除、抽出子は `None` を渡す。
  - `masters_rate_limit.rs`: `query_api_key` 関数を削除し `None` を渡す。
  - R4 契約テスト（クエリ拒否・`/me` のマスク）と単体テスト（`extract_api_key_ignores_query_parameter`）を追加。
  - フロントの設定画面からクエリ例を削除（`api-keys.component.ts`）。
- 削除前の実装は `git show e8331a2df -- crates/agrr-server/src/masters_auth.rs` で確認済み。以前は `?api_key=` の値を読んで認証に使っていた。
- 当時 `docs/api/getting-started.md` は更新されておらず、これが本件の原因（文書の取り残し）。
- 未確認: #1165 の Issue 本文（GitHub 上）。コミットメッセージ以外の議論や、クエリ認証を使っていた既知の利用者の有無は読んでいない。

### 2.5 URL 内キーの漏えい面（現状のログ出力）

現状はクエリのキーを認証に使わないが、クライアントが `?api_key=` を付けた場合、その URL 自体がサーバー・経路のログに残り得るかを確認した。

- `crates/agrr-server/src/security_audit_log.rs:10-18,26-38`: 監査ログのイベント型とレコード項目は `event_type` / `user_id` / `timestamp` / `resource_*` / `action` のみ。URL・クエリ文字列・ヘッダーの項目は無い。`log_api_key_generate` / `log_api_key_regenerate`（`:94-105`）も `user_id` のみ。**クエリ文字列は記録されない（確認済み）。**
- `crates/agrr-server/src/telemetry.rs`: 全体（`:1-162`）を読み、`init`（`:48-69`）は `tracing_subscriber::fmt` と任意の OTLP 出力の設定、他は trace id 取得と最適化チェーンの span（`plan_id` / `channel` / `step`）。リクエスト URL は扱っていない（確認済み）。
- **`crates/agrr-server/src/lib.rs:185-188` の `TraceLayer::new_for_http().make_span_with(DefaultMakeSpan::new().level(Level::INFO))` と `DefaultOnResponse`:** このリクエスト span が URI（クエリ含む）を出力するかは、`tower-http` 0.6.11（`Cargo.lock:2942-2943`）のソースがローカルに無く読めなかったため **未確認**。確認手順は §6.3 に置く。
- `masters_rate_limit.rs:155` は `request.uri().query()` を読むが、`classify_masters_request`（`:157`）に渡すだけでログには出さない。`masters_auth.rs:148` の `parts.uri.query()` もスコープ判定用（`enforce_api_key_scopes`）で、出力しない。
- `security_headers.rs:10,33` は `Referrer-Policy: strict-origin-when-cross-origin` をレスポンスに付与する。これは JSON レスポンスに対する設定で、キーを URL に載せたクライアント側ページの Referer 送出を制御するものではない。
- 未確認: Cloud Run / ロードバランサーのリクエストログ（`requestUrl`）に URL のクエリが含まれるか、本番のログ保持と閲覧権限。リポジトリ内のコードでは確定できない。
- 未確認: `gcloud logging read` などによる本番ログの実測（本書作成時は未実行）。

---

## 3. 仕様の確定

### 3.1 選択肢

| 観点 | A. 文書からクエリ認証を削除（実装は現状維持）【推奨候補】 | B. 実装を復活（クエリ認証を再び受ける） |
| ---- | ---- | ---- |
| 変更内容 | `getting-started.md:30` を削除し、非対応の注記を追加。 | `extract_api_key` の `_query` を復活、`from_request_parts` / レート制限に `?api_key` の値を渡す。 |
| 変更規模 | 文書 1 ファイル。 | `masters_auth.rs` / `masters_rate_limit.rs` / テスト反転 / 文書 / OpenAPI。 |
| 実装との整合 | 現行の実装・契約テスト・OpenAPI・MCP・SPA と一致する。 | #1165 の意図的な削除を覆す。契約テスト `contracts.rs:3141` と単体テスト `masters_auth.rs:178` を反転する必要がある。 |
| セキュリティ | URL にキーを載せる経路を作らない。 | キーがアクセスログ・プロキシ/CDN ログ・ブラウザ履歴・Referer・共有 URL に残り得る。キー再発行以外に回収手段が無い。 |
| 利用者影響 | `?api_key=` 利用者は現状すでに 401（実装は変更済み）。文書が実態に追いつくだけ。 | 既存の利用者は復旧するが、漏えい面が再び開く。 |
| 一貫性 | `openapi.yaml` は Bearer/ヘッダーのみで元から一致。 | `openapi.yaml` にも `in: query` を追加する必要があり、`08 openapi-gaps` に波及。 |

### 3.2 セキュリティ評価

- クエリにキーを載せると、URL が保存される場所すべてにキーが残る: サーバー/LB/CDN のアクセスログ、`tower-http` の span 出力（§2.5 で未確認）、ブラウザ履歴、Referer、ブックマーク、共有リンク、エラー報告ツール。ヘッダー（Bearer / `x-api-key`）はこれらに通常残らない。
- キーは Masters API の読み書き（スコープ導入後は既定 `masters:read`、`contracts.rs:3094-3120`）を許す長期資格情報で、再生成でしか無効化できない。漏えい時の影響が大きい。
- 現状の実装は「クエリのキーを黙って無視 → 401」で fail-closed（`ARCHITECTURE.md` の fail-closed 方針と整合）。B は明確な利益（ヘッダーを設定できない環境の救済）が無ければ採らない。
- **A を推奨する。** 理由: 実装・契約テスト・OpenAPI・MCP・SPA の全てがヘッダー方式で一致しており、文書 1 行だけが取り残されている。

### 3.3 ユーザー確認が必要な点

1. A（文書削除）で確定してよいか。B を採る要望（ヘッダーを付けられない外部クライアントなど）が実在するか。要望が無ければ A で進める。
2. `?api_key=` を付けたときの 401 に**ヒント**（`error_code` など）を返すか（§5.3）。導入する場合、`docs/api/openapi.yaml` の 401 定義（`Unauthorized`）との整合が必要。
3. 本番ログ（Cloud Run/LB）に過去 `?api_key=` 付きの URL が残っていないかの調査と、残っていた場合のキー再発行の案内の要否。調査権限は本書からは確認できない。

---

## 4. 影響範囲

- **既存利用者:** `?api_key=` を使っていた外部クライアントは、#1165 以降すでに 401。文書を直しても挙動は変わらない。利用者数・期間は**未確認**（本番ログ未調査）。
- **後方互換:** A は挙動を変えないため互換性影響は無い。B は挙動を再変更する（#1165 で拒否となった要求が再び通る）。
- **クエリ付きのキーが過去にログへ残った可能性:** 削除前（#1165 以前）の期間に URL に載ったキーは、ログ保持期間内なら残り得る。§3.3 の 3 で扱う。
- **影響するドキュメント:** `docs/api/getting-started.md` のみ（§2.1）。`openapi.yaml`・MCP README・SPA 画面は既に一致。
- **影響しない面:** セッション Cookie 認証、Cable、AI API、`api_keys.rs` の発行系（§2.3）。
- **注意（現状の挙動）:** セッション Cookie を持つブラウザから `?api_key=<何か>` を付けても、クエリは無視されて Cookie で認証される。クエリのキーが原因で 401 になるのは Cookie も無い場合のみ。文書では「クエリは認証に使われない」と書く（「必ず 401」とは書かない）。

---

## 5. 対応方針

### 5.1 文書の Before / After（`docs/api/getting-started.md`）

Before（`:24-30`）:

```markdown
すべての Masters エンドポイントは **API キー** または **ログインセッション Cookie** が必要です。サーバー間連携では API キーを使います。

| 方式 | 例 |
|------|-----|
| Bearer | `Authorization: Bearer <api_key>` |
| ヘッダー | `x-api-key: <api_key>` |
| クエリ（非推奨） | `?api_key=<api_key>` |
```

After:

```markdown
すべての Masters エンドポイントは **API キー** または **ログインセッション Cookie** が必要です。サーバー間連携では API キーを使います。

| 方式 | 例 |
|------|-----|
| Bearer | `Authorization: Bearer <api_key>` |
| ヘッダー | `x-api-key: <api_key>` |

API キーはヘッダーでのみ受け付けます。クエリパラメータ（`?api_key=<api_key>`）は認証に使われません。URL にキーを載せると、アクセスログやブラウザ履歴、Referer に残るためです。以前クエリでキーを渡していた場合は、上記のヘッダー方式に置き換えてください。クエリのキーだけで認証しようとした要求は **HTTP 401** になります。
```

- 「クエリで 401」の記述は、Cookie なしで `?api_key=` のみを付けた場合を指す（§4 の注意）。
- `getting-started.md:32-41` のスコープ説明（「スコープ列は DB に保存していません」）は実装（`masters_auth.rs:109-127`、`contracts.rs:3094-3120`）と食い違うが、別課題 **03 api-key-scope-docs** の範囲。本課題では触れない。

### 5.2 実装（A の場合）

- 変更なし。振る舞いは既に目的の状態。
- 任意の整理（別途、TDD で扱う）: `resolve_masters_principal` / `resolve_masters_user_id` / `extract_api_key` の未使用クエリ引数（`masters_auth.rs:44,67,90`）と、呼び出し側の `None`（`masters_auth.rs:142`、`masters_rate_limit.rs:163`）の削除。挙動は変えず、「クエリは受けない」ことをシグネチャで表す。`project-necessary-code-only` と `no-convenience-tech-debt` の観点で残置しないなら本件で実施する。判断は §8 に置く。
  - 削除する場合は既存テスト `masters_auth.rs:178-181` が `extract_api_key(&headers, Some(...))` を呼んでいるため、シグネチャ変更に合わせて更新する（RED は「コンパイルが通らない」ではなく、契約テストによる 401 維持で担保する）。

### 5.3 401 のヒント（任意・要ユーザー確認）

- 現状 `masters_auth.rs:102-107` の 401 本文は `{"error":"unauthorized"}` のみ。`?api_key=` が付いていたのに 401 になった利用者は原因に気づきにくい。
- 案: クエリに `api_key` が含まれ、かつ認証が失敗した場合に限り、本文へ `"error_code": "api_key_query_not_supported"` と `"hint"`（例: 「API キーは Authorization: Bearer または x-api-key ヘッダーで渡してください」）を追加する。
- 制約:
  - キーの値を本文・ログに出さない（`api_key` の有無だけを見る）。
  - 層はエッジ（`crates/agrr-server/src/masters_auth.rs`）のみ。R7（薄い HTTP エッジ）に沿い、ドメイン（`agrr-domain`）へ HTTP 概念（クエリ文字列）を持ち込まない。
  - 正常系の 401（クエリなし）の本文は変えない。
  - OpenAPI の `Unauthorized` 応答（`openapi.yaml:43,62,81` が参照）へ追加項目を反映する場合は **08 openapi-gaps** と調整する。
- 採否は §3.3 の 2。A の最小対応では**実装しない**（文書のみ）。

### 5.4 B を採る場合の層ごとの変更（参考・非推奨）

| 層 | 変更 |
| -- | ---- |
| ドメイン（`crates/agrr-domain/src/shared`） | 変更なし（`MastersApiCredentialsResolveInput` は抽出済みキーを受けるだけ）。 |
| エッジ（`masters_auth.rs`） | `extract_api_key` で `api_key` パラメータを読む（パーセントデコード含む）、`from_request_parts` で `parts.uri.query()` を渡す。 |
| エッジ（`masters_rate_limit.rs`） | `resolve_masters_user_id` に同じクエリ値を渡す（渡さないと API キーのレート制限が session/anonymous と食い違う）。 |
| ログ | span/アクセスログからクエリをマスクする仕組みを追加（§2.5 の未確認事項の解消が前提）。 |
| テスト | `contracts.rs:3141` と `masters_auth.rs:178` を反転し、レート制限・マスクの新規テストを追加。 |
| 文書 | `openapi.yaml` に `in: query` の securityScheme、getting-started の維持。 |

---

## 6. TDD / 検証計画

`tdd-on-edit` の規約は「ソース・テストの追加・変更」に適用される。A の最小対応は**文書のみ**（例外: ドキュメントのみ）なので RED は不要。ただし、文書と実装の一致を回帰テストで固定するため、下記を確認・追加する。

### 6.1 既存テストの確認（確認済み・実行は未実施）

| テスト | パス | 表明 |
| ------ | ---- | ---- |
| `extract_api_key_ignores_query_parameter` | `crates/agrr-server/src/masters_auth.rs:178-181` | クエリだけでは `None`。 |
| `get_masters_with_query_api_key_is_rejected` | `crates/agrr-r4-contract/tests/contracts.rs:3141-3150` | `GET /api/v1/masters/crops?api_key=<有効キー>` が 401。 |
| `post_masters_crop_setup_proposal_with_api_key_authenticates` | 同 `:2758-2782` | Bearer で dry_run が 200。 |

- 実行経路: R4 契約は `scripts/run-rust-contract-tests.sh`（`test-common` 記載のスクリプト）。テスト名フィルタ引数は受けない構成（Docker 内で `agrr-r4-contract-tests` を一括実行, `run-rust-contract-tests.sh:359`）。一括実行後は遅延検知（`node scripts/check-slow-libtest-output-cli.mjs`, 同 `:369`）が走る。
- **注意（確認済み）:** `masters_auth.rs` の単体テストは `cargo test -p agrr-server` で走るが、`test-common` のスクリプト（`run-test-rust-domain.sh:21-25` は `-p agrr-domain` と `-p agrr-migrate`）にも、`.github/workflows/rails-test.yml:57-58` / `rust-domain-test.yml:51-58`（`agrr-domain` / `agrr-migrate` / `agrr-adapters-sqlite _gateway_test`）にも `agrr-server` の単体テストは含まれない（`rg "cargo test"` の結果の範囲）。他のワークフローで実行されているかは**未確認**。よってゲートとして頼れる回帰テストは R4 契約テスト。
- 実行結果（GREEN/RED）は本書作成時点では**未取得**。実装ステップ開始時に `run-rust-contract-tests.sh` を全体実行して現状 GREEN を確認する（プロセス完了と終了コードを見てから断定。`process-monitor`）。

### 6.2 追加する回帰テスト案（A のとき任意・§5.3 を採るときは必須）

配置: `crates/agrr-r4-contract/tests/contracts.rs`（`get_masters_with_query_api_key_is_rejected` の近傍、既存の命名 `get_/post_masters_*` に揃える）。ヘルパーは `support.rs` の `contract_api_session_id`（`:109`）、`regenerate_api_key`（`:152`）、`empty_headers` を再利用する。

**案 1: `post_masters_setup_proposal_with_query_api_key_is_rejected`（書き込み系でも拒否）**

- given: `contract_api_session_id` でセッションを得て `regenerate_api_key` で有効キーを発行。`seed_masters_crop(user_id)` で作物を用意（既存の `post_masters_crop_setup_proposal_with_api_key_authenticates` と同じ準備）。
- when: Cookie・ヘッダーなしで `POST /api/v1/masters/crops/{id}/setup_proposal?mode=dry_run&api_key={key}` を送る。
- then: 401。`crop_stages` などの状態が変化していない（dry_run なので副作用は元々無いが、認証が通っていないことを 401 で表明）。

**案 2: `get_masters_with_query_api_key_is_ignored_when_header_key_is_valid`（ヘッダー優先/クエリ非影響）**

- given: 有効キーを発行。
- when: `Authorization: Bearer {有効キー}` と `?api_key=invalid-key` の両方を付けて `GET /api/v1/masters/crops`。
- then: 200（クエリの値が認証に影響しない）。

**案 3: `get_masters_with_query_api_key_returns_hint_body`（§5.3 採用時のみ）**

- given: 有効キー。
- when: `GET /api/v1/masters/crops?api_key={key}`（Cookie・ヘッダーなし）。
- then: 401、かつ本文 JSON の `error_code == "api_key_query_not_supported"`、`hint` が存在し、**本文にキー文字列が含まれない**（`assert!(!body.contains(&key))`）。クエリなし 401 の本文は `{"error":"unauthorized"}` のまま（既存契約の維持）。

**案 4（任意）: 単体テスト** `masters_auth.rs` の `tests` モジュールに、`extract_api_key` が Bearer とクエリの両方で Bearer 側を返すことを追加。ただし §6.1 の注意どおり通常経路で実行されないため、追加するなら実行経路（`cargo test -p agrr-server` を `test-common` に載せるか）を先に決める。

RED の確認: 案 1・2 は現状の実装で GREEN になる（挙動固定のテスト）。案 3 は §5.3 実装前は RED（本文に `error_code` が無い）。RED/GREEN は `scripts/run-rust-contract-tests.sh` で確認する。エッジ（`agrr-server`）を変更する場合は、Docker 検証前に `.cursor/skills/dev-docker/scripts/rebuild-restart.sh` を実行する（`docker-dev-agrr-server-rebuild` ルール）。

### 6.3 ログ漏えいの検証（§2.5 の未確認の解消）

- 手順: `agrr-server` をローカル起動し、`curl -i "http://127.0.0.1:8080/api/v1/masters/crops?api_key=DUMMY-SECRET-123"` を送る。起動ログ（stdout/stderr）に `DUMMY-SECRET-123` が出るかを検索する。出力は `./tmp/{UUID}.log` へ保存してから検索する（`AGENTS.md` の方針）。
- 判定: 出る場合は `TraceLayer` の `make_span_with` をクエリを含まない span（メソッドとパスのみ）に置き換える別課題を起票し、**10 authorization-consistency / 11 low-priority-misc のどちらに置くかを決める**。出ない場合は §2.5 を「確認済み・出力されない」に更新する。
- 本番（Cloud Run/LB）ログは `gcp-available` ルールに従い `gcloud logging read` でクエリ付き URL の有無を調べる。実施するかは §3.3 の 3。

---

## 7. 実装ステップ

前提: §3.3 の 1 で A が確定していること。

1. **現状確認:** `scripts/run-rust-contract-tests.sh` を実行し、`get_masters_with_query_api_key_is_rejected` を含めて GREEN であることを終了コードまで確認する（未実施）。
2. **文書修正:** `docs/api/getting-started.md:24-30` を §5.1 の After に置換する（この段階では文書のみ）。
3. **§6.3 のログ確認**（ローカル）を実施し、結果で §2.5 を更新する（この課題の文書か別課題）。
4. **（任意）回帰テスト追加:** §6.2 の案 1・2 を追加し、GREEN を確認する。
5. **（採用時のみ）401 ヒント:** 案 3 を先に書き RED を確認 → `masters_auth.rs` の `unauthorized()` を拡張して GREEN → `rebuild-restart.sh` → 契約テスト全体 → 遅延検知（`test-slow-detection`）。
6. **（任意）未使用引数の削除:** §5.2。テストが GREEN のまま挙動が変わらないことを確認する。
7. **クローズ確認:** §9 の受け入れ条件を満たすことを確認する。

---

## 8. リスク・未確定事項

| 項目 | 内容 | 扱い |
| ---- | ---- | ---- |
| 既存利用者 | `?api_key=` を使う外部クライアントが存在するか、いつから 401 か。 | 未確認。本番ログ調査（§3.3 の 3）。文書修正の可否は左右しない。 |
| 過去ログ内のキー | #1165 以前にクエリで渡されたキーがログに残っている可能性。 | 未確認。残存が判明した場合はキー再生成の案内を検討（ユーザー判断）。 |
| `TraceLayer` の URI 出力 | `lib.rs:185-188` の span が URL（クエリ含む）を出すか。 | 未確認。§6.3 で確認。 |
| Cloud Run/LB ログ | リクエストログにクエリが残るか。 | 未確認。リポジトリ内では確定不可。 |
| 単体テストの実行経路 | `agrr-server` の単体テストを走らせる標準スクリプト・CI が見当たらない。 | 未確認（他ワークフロー未読）。契約テストで担保する。 |
| 401 ヒントの採否 | 追加項目が OpenAPI 定義・フロント・MCP の 401 処理に影響しないか。 | 未確認。採用時に `08 openapi-gaps` と `07 frontend-error-contract` を確認。 |
| 未使用クエリ引数の削除 | 挙動不変のリファクタだが、テスト（`masters_auth.rs:180`）と 2 関数のシグネチャを変える。 | 実施可否を実装時に決定。放置は「便宜による技術負債」に当たり得るため、原則は本件内で削除する。 |
| #1165 の議論 | 削除の判断根拠がコミットメッセージ以外にあるか。 | 未確認（GitHub 上の Issue 未読）。 |

---

## 9. 受け入れ条件

- `docs/api/getting-started.md` の認証表に `?api_key=` が無く、クエリで API キーを渡せない旨と代替（Bearer / `x-api-key`）が明記されている。
- リポジトリ内（`docs/migration/archive/**` を除く）に `?api_key=` を認証手段として案内する記述が残っていない（`rg -n "\?api_key"` で 0 件。テストコードの検証用 URL を除く）。
- `scripts/run-rust-contract-tests.sh` が GREEN（終了コード 0）で、`get_masters_with_query_api_key_is_rejected` が含まれて通り、遅延検知に指摘が無い。
- （回帰テストを追加した場合）§6.2 の案 1・2 が GREEN。
- §6.3 のローカルログ確認が実施され、結果（クエリが出力される/されない）が記録されている。出力される場合は別課題として起票済み。
- §3.3 の 1〜3 についてユーザーの判断が記録されている。
- 採用時のみ: 401 ヒントが契約テスト（案 3）で表明され、キー値が本文・ログに出ない。

---

## 10. 関連課題との依存

| 番号 | 課題 | 関係 |
| ---- | ---- | ---- |
| 03 | api-key-scope-docs | **同一文書 `getting-started.md` の別箇所**（`:32-41` のスコープ説明が実装と不一致）。同じファイルを編集するため、変更の衝突を避けて順序を調整する。相互に必須ではない。 |
| 08 | openapi-gaps | 401 ヒントを採用する場合、`openapi.yaml` の `Unauthorized` 応答の追記が必要。B を採る場合は `securitySchemes` に `in: query` が必要。A の最小対応では変更なし（OpenAPI は既に Bearer/ヘッダーのみ）。 |
| 07 | frontend-error-contract | 401 本文に項目を追加する場合、フロントのエラー契約への影響を確認。A の最小対応では無関係（SPA は Cookie 認証のみ）。 |
| 09 | stale-design-docs | 「文書の取り残し」という同じ性質の課題。本件の是正内容（削除コミット後の文書未更新）は同課題の再発防止の材料になる。 |
| 10 | authorization-consistency | §6.3 で `TraceLayer` がクエリを出力すると判明した場合の置き場の候補。他の認証経路（Cable の Cookie、AI API のセッション）とは独立（§2.3）。 |
| 11 | low-priority-misc | §5.2 の未使用引数削除を独立して扱う場合の置き場の候補。 |
| 01 / 02 / 05 / 06 | resource-limit-bypass / contact-recaptcha / fail-closed-critical / fail-closed-suspected | 依存なし。クエリを無視して 401 とする現状は fail-closed の方針と整合（`ARCHITECTURE.md` の Fail-closed 節）。 |
