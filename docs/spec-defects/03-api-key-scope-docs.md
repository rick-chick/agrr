# 03: API キースコープ仕様と `getting-started.md` §3 の不一致

本書は**対応計画のみ**であり、コード・文書の修正は含まない。記載する事実は 2026-09-29 時点のリポジトリを実際に読んで確認したものだけで、`file:line` を付ける。読んでいない・実行していないものは「未確認」と明記する。

参照した規約: [`ARCHITECTURE.md`](../../ARCHITECTURE.md)、[`docs/architecture/LAYER-RULES.md`](../architecture/LAYER-RULES.md)、[`tdd-on-edit`](../../.cursor/skills/tdd-on-edit/SKILL.md)、[`test-common`](../../.cursor/skills/test-common/SKILL.md)、[`evidence-before-design-and-implementation.mdc`](../../.cursor/rules/evidence-before-design-and-implementation.mdc)。

---

## 1. 概要と重大度

### 概要

[`docs/api/getting-started.md`](../api/getting-started.md) §3 は次のように記載している。

- 「現時点ではキーごとのスコープ列は DB に保存していません」(`getting-started.md:34`)
- 「発行されたキーは現状 **読み取りと書き込みの両方** が可能です」(`getting-started.md:41`)
- 見出しも「スコープ（将来の tier 用）」(`getting-started.md:32`)

実装は逆である。スコープは DB に保存され、Masters API で強制されている。新規発行・再発行のキーは**読み取り専用**で、書き込みは 403 になる。この文書だけが古い。`docs/api/openapi.yaml` は実装と一致している。

加えて、調査で次の**機能上の欠落**を確認した。文書修正だけでは解消しない。

- API キーに `masters:write` を付与する手段が、コード上どこにも存在しない(§2.6)。
- そのため、`setup_proposal?mode=apply` を使う公式 MCP フローとスキル `agrr-crop-setup` は、新規発行キーでは apply の段階で必ず 403 になる(§4)。
- 再生成は書き込み可能な既存キーを読み取り専用へ降格させるが、UI はそれを警告しない(§2.3、§2.6)。

### 重大度

| 項目 | 重大度 | 理由 |
|------|--------|------|
| 文書の誤り(§3 の記述) | 中 | 誤りの向きは実装が厳しい側なので、権限が過剰になる問題ではない。ただしスキル作者・MCP 利用者が「書き込める」と信じて実装し、実行時に 403 で失敗する。 |
| 書き込みスコープの付与手段がない | 高 | 公式に案内している外部スキル/MCP の apply フローが、新規キーでは成立しない(§4)。 |
| 再生成による暗黙の降格 | 中 | V15 で read+write を維持した既存キーが、再生成すると read のみになる。UI の確認ダイアログは「現在のキーが無効になる」ことしか伝えない(`frontend/src/assets/i18n/ja.json:3822` の `regenerate_confirm`)。 |

セキュリティ上の露出(過剰権限)はない。実装は最小権限側に倒れている(`crates/agrr-domain/src/shared/dtos/masters_api_scope.rs:47`「Default scopes for newly generated API keys (least privilege)」)。

---

## 2. 現状(確認済み事実)

### 2.1 スコープの保存(DB)

- `users.api_key_scopes` は `text` 列で、`crates/agrr-migrate/migrations/schema/V15__api_key_scopes.sql:1` で追加される。
- V15 のコメントは「Preserve existing integrations: keys created before scope enforcement get read+write」(`V15__api_key_scopes.sql:3`)。`api_key` が NULL でも空でもなく、スコープが NULL/空の行に `["masters:read","masters:write"]` を設定する(`V15__api_key_scopes.sql:4-8`)。
- V15 導入コミット `44459031c`(#619)はスコープ列・強制・新規キーの既定値を**同一コミット**で導入した。`git show --stat 44459031c` で確認済み。

### 2.2 スコープの解釈(ドメイン)

- スコープ文字列は `masters:read` と `masters:write` の 2 つ(`masters_api_scope.rs:4-5`)。
- 要求スコープの判定(`masters_api_scope.rs:16-34`)は次のとおり。
  - `/api/v1/masters/` 配下のみが対象。
  - `path` に `/setup_proposal` を含み `mode=apply` なら Write、`mode=dry_run` なら Read。
  - それ以外は `GET` / `HEAD` が Read、`POST` / `PUT` / `PATCH` / `DELETE` が Write。
- 許可判定(`masters_api_scope.rs:38-45`)では、Write を持つキーは Read も満たす(`has_read || has_write`)。Write 要求は `masters:write` のみで満たす。
- 新規キーの既定値は `default_api_key_scopes_json()` = `["masters:read"]`(`masters_api_scope.rs:48-50`)。
- `parse_api_key_scopes_json`(`masters_api_scope.rs:53-66`)は、NULL・空・JSON 不正・非配列のとき**空配列**を返す。

### 2.3 スコープの書き込み(発行・再発行)

- `UserApiKeyRotationSqliteGateway::rotate`(`crates/agrr-adapters-sqlite/src/api_keys/user_api_key_rotation_gateway.rs:28-67`)が、生成と再生成の両方で `api_key_scopes = default_api_key_scopes_json()` を書き込む(`:43`、`:52-54`)。
- `regenerate == false` で既にキーがある場合は何も更新せず `success` を返し、キーは返さない(`:40-42`)。
- したがって再生成すると、以前 read+write だったキーも `["masters:read"]` になる。
- コード中に `api_key_scopes` を書き込む本番経路は、上記ゲートウェイ以外にない。`grep -rn "api_key_scopes" crates` の結果は、テスト用ヘルパ `crates/agrr-r4-contract/tests/support.rs:123-131` (`set_user_api_key_scopes`)、V15、および読み取り側のみだった。
- 平文キーからハッシュへの移行(`crates/agrr-adapters-sqlite/src/shared/api_key_principal_gateway.rs:32-42`、`crates/agrr-adapters-sqlite/src/api_keys/api_key_backfill.rs:27`)の `UPDATE` は `api_key_scopes` に触れない。V25(ハッシュ化)後もスコープは保持される。

### 2.4 スコープの読み取りと強制(HTTP 境界)

- API キー認証では `SessionPrincipal.api_key_scopes = Some(parse_api_key_scopes_json(...))` になる(`api_key_principal_gateway.rs:21-29`)。
- セッション Cookie 認証では `api_key_scopes: None` になる(`crates/agrr-adapters-sqlite/src/shared/session_cookie_principal_gateway.rs:33,56,67,79`)。
- `enforce_api_key_scopes`(`crates/agrr-server/src/masters_auth.rs:109-128`)の挙動は次のとおり。
  - `None`(セッション)なら常に許可する(`:115-117`)。
  - `Some(scopes)` で要求を満たさなければ、403 と `{"error":"forbidden","error_code":"insufficient_scope"}` を返す(`:95-100`、`:123-127`)。
- `MastersUserId` extractor(`masters_auth.rs:130-152`)が認証後にこれを呼ぶ。`setup_proposal` ハンドラも `MastersUserId` を使う(`crates/agrr-server/src/masters_crop_setup_proposal.rs:3,40`)。
- NULL スコープのキーは `Some([])` になり、`GET` を含むすべてが 403 になる。コードから導いたもので、実行では未確認。
- API キーの取り出しはヘッダー(`Authorization: Bearer` と `x-api-key`)のみで、クエリの `api_key` は無視される(`masters_auth.rs:44-61`、テスト `masters_auth.rs:177-181`)。getting-started §2 の「クエリ（非推奨）」(`getting-started.md:30`)は課題 04 の領分(§10)。
- レート制限ミドルウェアは `resolve_masters_user_id` で認証だけを行い、スコープは見ない(`crates/agrr-server/src/masters_rate_limit.rs:17,163`)。403 になる書き込みでも分単位カウントには入る可能性がある。この点は**未確認**(挙動未読)。

### 2.5 OpenAPI と文書の現状

- `docs/api/openapi.yaml:9-13` は「Scopes (enforced per API key)」として `masters:read` と `masters:write` を定義する。「Session cookie authentication has full Masters access. API keys default to `masters:read` only on generate/regenerate.」とも書いている。
- `openapi.yaml:358` は apply を `masters:write` としている。`openapi.yaml:391-392,398` は securitySchemes の説明でスコープを記述している。
- `openapi.yaml` には `403` / `insufficient_scope` の記述が**ない**(`grep -n "403\|insufficient" docs/api/openapi.yaml` が 0 件)。課題 08 の領分。
- `docs/api/setup_proposal-openapi-snippet.yaml` はスコープに言及せず、responses は 200/201/401/404 のみ。403 もない。security は `bearerApiKey` と `sessionCookie`。`getting-started.md:92` は同 snippet を「レガシー snippet・本体は openapi.yaml に統合」と位置づけている。
- `getting-started.md` の他の箇所の状況は次のとおり。
  - §5 の典型フロー(`:60-67`)は dry_run の後に apply を案内し、apply の curl 例が `Authorization: Bearer $AGRR_API_KEY` を使う(`:79-87`)。スコープの前提がなく、新規キーでは 403 になる。
  - §4 のレート制限表(`:47-52`)は書き込み(60/分)と apply(5/分)を区別している。これは実装の分類 `Read`/`DryRun`/`Write`/`Apply` と整合する(`masters_rate_limit.rs:20-52`)。
  - `docs/api/builtin-generation-sunset.md:29-49` の「推奨経路」は Bearer で dry_run/apply を呼ぶ例を示し、スコープに触れない。同 `:51-53`(「### 3. UI からインポート」)は UI のインポート(セッション経由)を代替として案内する。

### 2.6 API キー発行 UI(書き込みスコープの付与手段)

- 画面は `frontend/src/app/components/settings/api-keys/api-keys.component.ts`。生成(`:56-64`)と再生成(`:41-50`、確認ダイアログ `:106-128`)のボタンだけで、スコープの表示・選択 UI は**ない**。
- 生成・再生成の HTTP 呼び出しは本文 `{}` で `POST /api/v1/api_keys/generate|regenerate` を叩く(`frontend/src/app/services/api-key-management.service.ts:29-42`、特に `:38`)。
- サーバー側ハンドラ(`crates/agrr-server/src/api_keys.rs:20-21,60-91`)は `CookieJar` のみを受け取り、リクエスト本文もスコープ引数も持たない。
- `GET /auth/me` のレスポンスはマスク済みキーを返す(`crates/agrr-server/src/auth_api.rs:45-99`)。`api_key_scopes` は返さない。`auth_api.rs` にスコープの記述はない。
- 画面の説明文は「マスタ管理用のCRUD APIにアクセスできます」(`frontend/src/assets/i18n/ja.json:3810`)。英語は「Use your API key to access CRUD APIs for master data.」(`en.json:3774`)。エンドポイント一覧(`ja.json:3839`)は `POST`/`PATCH`/`DELETE` を含み、書き込みにスコープが必要な旨は書かれていない。
- **結論**: 書き込みスコープを付与する手段は、サーバー API にも UI にもない。DB を直接更新する以外に手段はない(テストは `support.rs:123-131` で直接 UPDATE している)。ユーザー向けの手順としては存在しない。

### 2.7 既存の契約テスト(R4)

`crates/agrr-r4-contract/tests/contracts.rs` に、次のテストが**既に存在する**(読了済み。この計画の作業では実行していない)。

| テスト | 行 | 表明内容 |
|--------|----|----------|
| `masters_api_key_read_scope_allows_get_and_denies_post` | `:3013-3046` | read キーで `GET` 200、`POST /api/v1/masters/crops` が 403 かつ `error_code == "insufficient_scope"` |
| `masters_api_key_write_scope_allows_post` | `:3048-3067` | read+write キーで `POST` 201 |
| `masters_api_key_read_scope_denies_setup_proposal_apply` | `:3069-3092` | read キーで `mode=apply` が 403 |
| `post_api_keys_generate_defaults_to_read_only_scopes` | `:3094-3120` | `POST /api/v1/api_keys/regenerate` 後の DB の `api_key_scopes` が `["masters:read"]` |

ユニット/ドメインのテストは次のとおり。

- `masters_api_scope.rs:68-128` に、リクエストの分類・許可判定・JSON パースのテストがある。
- `masters_auth.rs:154-208` に、セッション許可と read キーの POST 拒否のテストがある。
- `crates/agrr-domain/test/shared/interactors_masters_api_credentials_resolve_interactor_test.rs:42` は、スコープ付き principal のテストデータを含む。

**不足していること**(存在する範囲で検索した結果)は次のとおり。

- `POST /api/v1/api_keys/generate`(テスト名に反して `regenerate` を叩いている)の既定スコープ。
- read キーで `mode=dry_run` が拒否されないこと(§7 の計画)。
- read キーで `PUT` / `PATCH` / `DELETE` が 403 になること。
- write キーで `mode=apply` が 403 にならないこと。
- 再生成で read+write が `["masters:read"]` に降格すること。
- スコープ NULL/空のキーが fail-closed(403)になること。
- V15 の `UPDATE` 自体のテスト。`crates/agrr-migrate/tests/` と `crates/agrr-migrate/src` に `api_key_scopes` / `V15` の言及はなかった。`schema_smoke.rs` が全スキーマを適用するかは**未確認**。
- 文書(getting-started/openapi)と実装のスコープ定義の機械的な整合検査。`scripts/` の doc 系チェック(`check-doc-freshness-lib.mjs`、`check-doc-stale-paths.sh`、`check-doc-internal-links.sh`)は API スコープを見ない。CI は `.github/workflows/doc-freshness.yml:25-34` で実行する。

### 2.8 外部スキル/MCP の前提

- 公式 MCP: `tools/agrr-mcp/README.md:8` は「AGRR API key with Masters access」とだけ書く。README `:18` は UI か `POST /api/v1/api_keys/generate` での発行を案内する。README `:54` の `apply_crop_setup` は `mode=apply` を呼ぶ。スコープの記述はない。
- `.cursor/skills/agrr-crop-setup/SKILL.md:17-18` の前提は「MCP 接続済み・`AGRR_API_KEY` を渡している」まで。`:36` の手順 5 が `apply_crop_setup` を呼ぶ。書き込みスコープが必要である旨は書かれていない。
- MCP クライアントのエラー処理(`tools/agrr-mcp/src/agrr-client.mjs:88-93`)は `payload.error` の文字列だけを例外メッセージにする。403 の場合は `"forbidden"` になり、`error_code: insufficient_scope` は利用者に届かない。
- 外部スキルが読む `docs/api/setup_proposal-openapi-snippet.yaml` は、403 とスコープの記述を持たない(§2.5)。

---

## 3. 正の確定

### 3.1 実装/OpenAPI を正とする根拠

「文書ではなく実装を正とする」のは、次の理由で確実に説明できる。

1. 実装がスコープを保存・強制している(§2.1〜§2.4)。契約テストがその挙動を固定している(§2.7)。
2. 強制は最小権限という意図的な設計で、コード上に理由が明記されている(`masters_api_scope.rs:47`、V15 コメント `:3`)。
3. OpenAPI が実装と一致している(§2.5)。誤りは `getting-started.md` §3 だけである。
4. `ARCHITECTURE.md` の契約優先(R9)と観測可能なテストの優先順位に沿う。`CLAUDE.md` の規範優先順位は「1. 観測可能なテスト → 2. LAYER-RULES → …」で、文書はテストより下位である。
5. 実装を文書に合わせて「全キー read+write」に戻すと、最小権限を意図した #619 の変更を取り消すことになる。セキュリティ上の後退であり、選ばない。

したがって、文書側を実装に合わせて修正する。実装の変更は本課題の範囲に含めない。

### 3.2 ユーザーへ確認が必要な点

根拠ゲートで確定できるのは「文書を実装に合わせる」ことまでである。以下は調査では確定できないプロダクト判断であり、文書修正の着手条件にはしない。

| # | 確認事項 | 現時点の事実 | 判断が影響する箇所 |
|---|----------|--------------|--------------------|
| Q1 | 書き込みスコープの付与手段を提供するか。提供する場合の形(発行時に UI で選択/課金 tier/管理者付与)は何か | 手段は存在しない(§2.6)。旧 §3 見出しは「将来の tier 用」と書いていた(`getting-started.md:32`)。tier 計画の実在は**未確認** | §5.2 の別課題の要否と形 |
| Q2 | 既存キー(V15 で read+write を維持したもの)を再生成すると read のみになる挙動は、意図した仕様か | コード上はそうなる(§2.3)。仕様として意図されたかは PR/ADR から**未確認**(#619 の説明は「Default new/regenerated keys to masters:read only」と書く) | 確認ダイアログ文言、移行方針 |
| Q3 | 既存キーの現況(本番でスコープが NULL のキーがあるか) | 本番 DB は**未確認**(本計画では問い合わせていない)。`production-primary-sqlite-query` スキルで読み取り確認できるが、本計画のスコープ外 | 「既存キーは read+write」と文書に明記できるかの裏取り |
| Q4 | 書き込みスコープが付与できるまでの間、MCP/スキルの apply 経路の案内をどうするか(UI インポート経由に誘導するか) | `builtin-generation-sunset.md:51-53` は UI インポート(セッション)を案内している | §5.1 の文言 |

Q1〜Q4 の回答を待たずに進められる作業は、§5.1 の文書修正だけである。付与手段を前提にする文言は、回答が出るまで書かない。

---

## 4. 影響範囲

### 4.1 利用者の外部スキル・MCP

- **MCP `apply_crop_setup`** と **スキル `agrr-crop-setup` の手順 5** は書き込み(apply)を前提にする(§2.8)。V15 より後に発行・再発行したキーでは、apply が 403 になる。dry_run と参照(`GET`)は動く。
- **`docs/api/getting-started.md` §5** と **`docs/api/builtin-generation-sunset.md`** の apply 例も、新規キーでは失敗する。
- MCP クライアントは 403 の `error_code` を握りつぶす(`agrr-client.mjs:88-93`)ため、利用者は原因が分かりにくい。
- 外部スキルがどれだけ実在し、どのキー世代を使っているかは**未確認**。リポジトリ内に把握できる情報はない。

### 4.2 既存キー

- V15 以前に発行された平文キー: read+write(§2.1)。ハッシュ移行後も維持(§2.3)。
- V15 以降に発行・再発行されたキー: read のみ(§2.3)。
- 再生成すると、以前 read+write だったキーは read のみに降格する(§2.3)。UI は警告しない(§2.6)。
- スコープが NULL のキー: 実装上は全 403(§2.4)。存在の有無は**未確認**(Q3)。V15 の `UPDATE` は「API キーがあり、スコープが NULL/空」の行を対象にするので、V15 適用済みかつ V15 以降に `api_key` が NULL のまま作られた行だけがこの状態になり得るが、現行の書き込み経路(§2.3)は必ずスコープを設定するため、通常は発生しない。

### 4.3 社内(リポジトリ)への影響

- `frontend` の API キー画面の文言(`ja.json:3810,3839`、`en.json:3774`、`in.json:3480` ほか)は、書き込みが常に可能であるかのような表現になっている。
- 課題 04(クエリ認証)・07(フロントエンドのエラー契約)・08(OpenAPI の不足)・09(古い設計文書)と対象ファイルが重なる(§10)。

---

## 5. 対応方針

原則: **文書修正(§5.1)を先に単独で完了**させる。付与手段の欠落(§5.2)は別課題として切り出し、Q1 の回答を得てから設計する(根拠ゲートを満たすまで設計しない)。

### 5.1 文書修正の具体差分案(実装は変更しない)

#### 5.1.1 `docs/api/getting-started.md` §3(`:32-41`)

Before:

```markdown
## 3. スコープ（将来の tier 用）

現時点ではキーごとのスコープ列は DB に保存していません。ドキュメント上の概念として次を使います。

| スコープ | 操作 |
|----------|------|
| `masters:read` | `GET` / `HEAD`（一覧・詳細・`setup_proposal?mode=dry_run` を含む読み取り相当） |
| `masters:write` | 作成・更新・削除・`setup_proposal?mode=apply` |

発行されたキーは現状 **読み取りと書き込みの両方** が可能です。将来の課金 tier でスコープを分離する予定です。
```

After:

```markdown
## 3. スコープ

API キーごとにスコープを保存し、Masters API（`/api/v1/masters/*`）で強制します。

| スコープ | 操作 |
|----------|------|
| `masters:read` | `GET` / `HEAD`（一覧・詳細）と `setup_proposal?mode=dry_run` |
| `masters:write` | `POST` / `PUT` / `PATCH` / `DELETE`（作成・更新・削除）と `setup_proposal?mode=apply`。読み取りも可能 |

- **新規発行・再発行したキーは `masters:read` のみ**です。書き込み系のリクエストは **HTTP 403** になります。
- ログインセッション Cookie は、スコープに関係なく Masters API のすべての操作が可能です。
- 再発行（**APIキーを再生成**）すると、スコープは `masters:read` に戻ります。
- スコープ導入前に発行された既存キーは、導入時に `masters:read` と `masters:write` の両方に設定されました。ただし再発行すると上記のとおり `masters:read` のみになります。
- 現在、API キーに `masters:write` を付与するための画面・API は提供していません。書き込み系の操作（`setup_proposal?mode=apply` を含む）はログインセッション（画面の **提案 JSON をインポート** など）で行ってください。

スコープが不足しているときのレスポンス:

```json
{ "error": "forbidden", "error_code": "insufficient_scope" }
```
```

注: 「導入時に既存キーは read+write」の 1 文は Q3(本番確認)が取れるまで、V15 コメント(`V15__api_key_scopes.sql:3`)に基づく記述として残す。Q3 で NULL のキーが見つかった場合は文言を見直す。

Q1 の回答で付与手段を提供すると決まった場合のみ、最後の箇条書きを更新する。決まるまでは事実(現状は付与手段なし)を書く。

#### 5.1.2 `docs/api/getting-started.md` §5(`:60-67`、`:79-87`)

apply の直前に注意書きを追加する。

Before(`:66`):

```markdown
3. `valid: true` なら `mode=apply` で永続化
```

After:

```markdown
3. `valid: true` なら `mode=apply` で永続化（**`masters:write` が必要**。読み取り専用キーでは 403 `insufficient_scope`。§3 参照）
```

`### apply 例`(`:79`)の直後に次を追加する。

```markdown
> このリクエストには `masters:write` スコープが必要です。新規発行・再発行の API キーは `masters:read` のみのため、403 になります（§3）。
```

#### 5.1.3 `docs/api/builtin-generation-sunset.md`(`:36-49`)

`apply` の説明行に「`masters:write` が必要」と §3 への参照を 1 行追加する。UI インポート(`:51-53`)は「セッションでは書き込みが可能」であることを示す代替経路として維持する。

#### 5.1.4 `docs/api/setup_proposal-openapi-snippet.yaml`

この snippet はレガシーで本体は `openapi.yaml`(`getting-started.md:92`)。ここには `403` (`insufficient_scope`)の応答と、apply が `masters:write` を要する旨を 1 行ずつ追加する。ただし snippet を残すか廃止するかは課題 08 と重なるため、08 の方針が決まっていればそれに従う。

#### 5.1.5 `tools/agrr-mcp/README.md` と `.cursor/skills/agrr-crop-setup/SKILL.md`

- README の Prerequisites(`README.md:8`)を、次の趣旨に修正する: 「API キーで `apply_crop_setup` を使うには `masters:write` が必要。新規発行キーは `masters:read` のみのため、dry_run までは動作するが apply は 403 になる」。
- SKILL.md の前提(`:17-18`)と手順 5(`:36`)に、同じ注意を追記する。付与手段が Q1 で決まるまでは「apply が 403 の場合は UI インポートで適用する」と案内する。
- 可能なら `agrr-client.mjs:88-93` で `error_code` を例外に含める。これは文書ではなくコード変更なので、TDD 対象の別課題として扱う(課題 07 と近い)。

#### 5.1.6 フロントエンドの文言(コード変更、別扱い)

`ja.json:3810`/`en.json:3774`/`in.json:3480` の説明文と `list_html`(`ja.json:3839`)に「書き込みには `masters:write` が必要で、現在は付与できない」旨を追加する。ロケール JSON の変更でもフロントエンドのテスト(`api-keys.component.spec.ts` ほか)に影響し得るので、TDD の対象とし、文書修正の PR には含めない。

### 5.2 別課題として切り出して提案する機能: API キーのスコープ付与手段

書き込みスコープを付与する手段は存在しない(§2.6)ため、文書だけを直しても apply フローは復旧しない。次を**別課題**として提案する。設計は Q1 の回答後に行う(根拠ゲート: 現時点は方針が未確定で、設計・実装に入らない)。

提案する範囲(案。確定ではない):

1. **発行時のスコープ選択**: `POST /api/v1/api_keys/generate|regenerate` に任意のリクエスト本文 `{ "scopes": ["masters:read", "masters:write"] }` を許可する。省略時は現行どおり `["masters:read"]`(後方互換)。セッション認証のみ。許可するスコープ値はドメインの定数(`masters_api_scope.rs:4-5`)に限定し、未知の値は 422 とする。
2. **表示**: `GET /auth/me` にスコープ(マスクされたキーと並べて)を追加し、画面に「読み取り専用/読み取り+書き込み」を表示する。
3. **UI**: 生成/再生成ダイアログにスコープ選択を追加し、再生成前に「現在のスコープは維持されない/どのスコープで再発行するか」を明示する。既定は read のみ。
4. **レイヤー**: R0/R7 に従い、スコープの妥当性検証は `agrr-domain` の api_keys コンテキストの Policy または Interactor が担う。ハンドラ(`api_keys.rs`)は本文を入力 DTO に写すだけにする。`UserApiKeyRotationGateway` の入力にスコープを追加し、ゲートウェイは受け取った値を保存するだけで判断しない(R0/R3)。実装順は LAYER-RULES R10(ポート契約 → Interactor → Gateway → Presenter → Handler)。
5. **課金 tier**を選ぶ場合は別途プロダクト設計が必要(Q1)。

実装時は本書とは別に `docs/spec-defects/` か issue で計画化し、`tdd-on-edit` に従い RED から始める。

---

## 6. TDD/検証計画

### 6.1 文書のみの変更(§5.1.1〜§5.1.3)

`tdd-on-edit` の例外(ドキュメント/設定のみ)に該当し、RED テストは必須ではない。ただし「文書と実装の整合」を機械的に保つため、次の**契約テストの追加を提案**する。文書の修正前に追加すれば、既存の誤りに対して RED になる。

#### 6.1.1 既存の R4 契約で担保済みの部分(§2.7)

- read キーの `POST` が 403 かつ `error_code == "insufficient_scope"`(`contracts.rs:3013-3046`)
- write キーの `POST` が 201(`:3048-3067`)
- read キーの apply が 403(`:3069-3092`)
- 再生成後の既定スコープが read のみ(`:3094-3120`)

#### 6.1.2 追加案(R4 契約、`crates/agrr-r4-contract/tests/contracts.rs`)

テスト名は既存の命名(`masters_api_key_...`)に揃える。準備は既存の `regenerate_api_key`・`set_user_api_key_scopes`(`support.rs:123-131`)を使う。

| # | テスト案 | 表明 | 目的 |
|---|----------|------|------|
| T1 | `masters_api_key_read_scope_allows_setup_proposal_dry_run` | read キーで `POST .../setup_proposal?mode=dry_run` が 403 ではない(200) | 文書の「read = dry_run 可」を固定 |
| T2 | `masters_api_key_write_scope_allows_setup_proposal_apply` | read+write キーで `mode=apply` が 403 ではない(201) | 文書の「write = apply 可」を固定 |
| T3 | `masters_api_key_read_scope_denies_put_patch_delete` | read キーで `PUT`/`PATCH`/`DELETE` が 403 `insufficient_scope` | 文書の「書き込み系はすべて 403」を固定 |
| T4 | `masters_api_key_regenerate_resets_scopes_to_read_only` | `set_user_api_key_scopes` で read+write にした後 `regenerate` すると DB が `["masters:read"]` | 文書の「再発行で read に戻る」を固定 |
| T5 | `post_api_keys_generate_defaults_to_read_only_scopes_for_new_key` | キー未保有ユーザーが `POST /api/v1/api_keys/generate` して DB が `["masters:read"]` | 既存テストは `regenerate` を叩いており、`generate` の経路が未検証 |
| T6 | `masters_api_key_null_scopes_denies_all_masters_requests` | `api_key_scopes = NULL` のキーで `GET` も 403 | §2.4 の fail-closed を確認(未実行の推論を実測に変える) |
| T7 | `masters_session_cookie_ignores_scopes` | セッション Cookie の `POST` が 403 にならない | 文書の「セッションは全権」を固定(既存テストの重複を先に確認する) |

T1・T2・T3・T4・T5・T7 は、実装が現状でもそのとおり動くと**コードから読み取っている**が、実行では未確認。追加した時点で GREEN のはずで、RED にならない場合は実装が想定と違う(=文書に書けない)ことを示す。T6 は、想定と異なる挙動が出たら Q3 と併せて課題化する。

#### 6.1.3 文書と実装のスコープ定義の整合を機械検証する案(任意、軽量)

`scripts/check-doc-freshness-lib.mjs` に検査関数を 1 つ追加する案(`scripts/check-doc-freshness-lib.test.mjs` にテストを付ける。CI は `doc-freshness.yml:34` で実行される)。

- `masters_api_scope.rs` の `MASTERS_READ` / `MASTERS_WRITE` の値が `getting-started.md` §3 の表と `openapi.yaml` の冒頭 description の両方に現れる。
- `getting-started.md` に「`insufficient_scope`」が含まれる。
- `getting-started.md` に、旧記述「スコープ列は DB に保存していません」が含まれない。

過剰な検査は保守負担になる(`project-necessary-code-only.mdc`)。上記 3 点のみに絞り、採用するかは Q に含めず実装者が判断する。採用しない場合は §6.1.2 の R4 契約だけで十分と判断する。

### 6.2 実行方法(`test-common` のみ)

- R4 契約: `scripts/run-rust-contract-tests.sh`。出力は `./tmp/{UUID}.log` にリダイレクトしてから grep する(`AGENTS.md`)。実行後は `process-monitor` に従い、終了コードを確認するまで結果を断定しない。
- ドメイン: `.cursor/skills/test-common/scripts/run-test-rust-domain.sh`(本課題ではドメイン変更なし。§5.2 の実装時に使う)。
- doc-freshness の検査を追加する場合は `node --test scripts/check-doc-freshness-lib.test.mjs`。`test-common` は Node のスクリプトテストを対象外としているため、CI の `doc-freshness.yml` と同じ経路で実行する。
- 個別テスト GREEN → 全体 → 遅延検知(`test-slow-detection`)の順は、`rails-testing-workflow.mdc` に従う。
- `crates/agrr-server/**` は変更しないため、`rebuild-restart.sh` は不要(`docker-dev-agrr-server-rebuild.mdc`)。テストの追加だけでも R4 は `scripts/run-rust-contract-tests.sh` が必要に応じてバイナリを再ビルドする(`run-rust-contract-tests.sh:20-34`)。

### 6.3 §5.2(付与手段)の検証

別課題で `tdd-on-edit` に従う。RED は、たとえば「`{"scopes":["masters:read","masters:write"]}` で再生成すると DB が両スコープになる」「許可外のスコープ値は 422」「本文なしは従来どおり read のみ」から書く。バグではなく機能追加なので `error-investigation` は使わない。

---

## 7. 実装ステップ

文書修正(本課題の範囲):

1. **前提確認**: §3.2 の Q3(本番のスコープ NULL の有無)を、必要なら `production-primary-sqlite-query` で読み取り確認する。取れない場合は、該当文を V15 コメントに基づく記述として残す。
2. **契約テストの追加(任意、推奨)**: §6.1.2 の T1〜T7 を追加し、`scripts/run-rust-contract-tests.sh` で実行する。GREEN を確認する。想定と異なる結果が出たら、文書を書く前に §8 のリスクとして記録する。
3. **`getting-started.md` §3 の修正**: §5.1.1 の差分を適用する。
4. **`getting-started.md` §5 の修正**: §5.1.2 を適用する。
5. **`builtin-generation-sunset.md` の修正**: §5.1.3 を適用する。
6. **`setup_proposal-openapi-snippet.yaml` の修正**: 課題 08 の方針と衝突しない範囲で §5.1.4 を適用する。
7. **`tools/agrr-mcp/README.md` と `agrr-crop-setup/SKILL.md` の修正**: §5.1.5 の文書部分を適用する。
8. **リンク・鮮度検査**: `./scripts/check-doc-internal-links.sh` と `./scripts/check-doc-stale-paths.sh` を実行する(`doc-freshness.yml:25,28`)。
9. **(任意)機械検証の追加**: §6.1.3 を採用する場合のみ。

別課題(本書の範囲外、要 Q1):

10. §5.2 の付与手段を、issue または新規の `docs/spec-defects/` 計画として起票する。
11. §5.1.5 の MCP クライアントの `error_code` 伝播、§5.1.6 のフロントエンド文言を、課題 07 の作業と調整して TDD で実施する。

---

## 8. リスク・未確定事項

| # | 項目 | 状況 |
|---|------|------|
| R-1 | 本番の既存キーのスコープ分布(NULL がないか) | 未確認。Q3。 |
| R-2 | 付与手段が提供されるまで、MCP の apply が新規キーで動かない | 確認済み(コードから)。文書で明示し、別課題(§5.2)で解消する。実行では未確認。 |
| R-3 | 再生成による降格が、既存の外部統合を壊す | コード上そうなる(§2.3)。実際に再生成して被害を受けた利用者がいるかは未確認。文書で明示する(§5.1.1)。UI の警告は §5.1.6/§5.2 の課題。 |
| R-4 | 403 の書き込みがレート制限のカウントに入るか | 未確認(`masters_rate_limit.rs` の分類とカウント順序を未読)。課題 10 に引き継ぐ。 |
| R-5 | 契約テスト T1〜T7 が想定どおり GREEN になるか | 未実行。RED/GREEN の結果で文書の記述を最終確定する。 |
| R-6 | `schema_smoke.rs` が V15 の `UPDATE` を検証しているか | 未確認。V15 自体のテストは見つからなかった(§2.7)。 |
| R-7 | `en.json:3774` と `in.json:3480` の API キー画面の説明文は「CRUD API にアクセスできる」旨で、書き込みスコープへの言及がない(確認済み)。`in.json` のエンドポイント一覧とロケール全体の他箇所は未読 | §5.1.6 の作業時に確認する。 |
| R-8 | 文書修正の PR が課題 04・08・09 と同じファイルを編集し、競合する | §10 の順序で回避する。 |
| R-9 | ドキュメントが「付与手段なし」と書く状態は、プロダクトとして望ましくない可能性がある | Q1。文書はあくまで現状の事実を書き、望ましい状態への変更は §5.2 で扱う。 |

---

## 9. 受け入れ条件

文書修正(本課題):

1. `docs/api/getting-started.md` §3 に、次の記述が**ない**こと: 「スコープ列は DB に保存していません」「将来の tier 用」「読み取りと書き込みの両方が可能」。
2. §3 に次が**ある**こと: 新規/再発行キーは `masters:read` のみ、書き込みは 403 `insufficient_scope`、セッションは全権、再発行でスコープが戻ること、現状は書き込みスコープの付与手段がないこと。
3. §5 と `builtin-generation-sunset.md` の apply の説明が、`masters:write` を要すると明記していること。
4. `docs/api/openapi.yaml` の冒頭 description(`:9-13`)と `getting-started.md` §3 で、スコープ名・操作分類・既定値が矛盾しないこと。
5. `tools/agrr-mcp/README.md` と `agrr-crop-setup/SKILL.md` に、apply には `masters:write` が必要で、新規キーでは 403 になり得ることが書かれていること。
6. `./scripts/check-doc-internal-links.sh` と `./scripts/check-doc-stale-paths.sh` が成功すること。
7. (契約テストを追加した場合)`scripts/run-rust-contract-tests.sh` が成功し、T1〜T7 が GREEN であること。RED の場合は、その事実に合わせて文書の記述を修正していること。
8. 実装コード(`crates/**`、`frontend/**` の本体)を変更していないこと(テスト追加を除く)。

別課題の起票(受け入れの一部):

9. §5.2 の付与手段が、Q1 の回答とともに issue または計画文書として起票されていること。

---

## 10. 関連課題との依存

| 番号 | 課題 | 関係 |
|------|------|------|
| 01 | resource-limit-bypass | 依存なし。 |
| 02 | contact-recaptcha | 依存なし。 |
| 04 | api-key-query-auth | **同一ファイルの競合**。`getting-started.md` §2 (`:30`) の「クエリ（非推奨）」は実装で無視される(`masters_auth.rs:44-61`)。04 が §2 を、本課題が §3・§5 を編集する。別の PR にするか、先に 04 を入れて本課題を rebase する。 |
| 05 | fail-closed-critical | NULL スコープが全拒否になる挙動(§2.4)は fail-closed 側。T6 の結果によっては 05/06 の観点で再評価する。 |
| 06 | fail-closed-suspected | 同上。`parse_api_key_scopes_json` が不正 JSON を空配列にする(`masters_api_scope.rs:53-66`)ことが安全側かを 06 で見る余地がある。 |
| 07 | frontend-error-contract | MCP クライアントが 403 の `error_code` を捨てる(`agrr-client.mjs:88-93`)点、UI が `insufficient_scope` を表示できない点。§5.1.5/§5.1.6 の後続作業と調整する。 |
| 08 | openapi-gaps | `openapi.yaml` に 403/`insufficient_scope` の応答がない(§2.5)。`setup_proposal-openapi-snippet.yaml` の廃止・統合の判断も 08 に属する。本課題で snippet を編集する前に 08 の方針を確認する。 |
| 09 | stale-design-docs | 古い文書の一群。本課題の `getting-started.md` §3 はその一例。近傍に `docs/adr/ADR-002-organization-multi-tenancy.md:102` が `V15__organizations.sql` と書くが、実際の V15 は `api_key_scopes`、`organizations` は V16(`ls crates/agrr-migrate/migrations/schema`)という不一致があり、09 で扱う。 |
| 10 | authorization-consistency | スコープの強制が extractor(`MastersUserId`)に集中し、レート制限は認証のみ(`masters_rate_limit.rs:163`)であること、`/api/v1/masters/` 以外で API キーが使われるか(未確認)を、認可の一貫性の観点で見る。R-4 を引き継ぐ。 |
| 11 | low-priority-misc | 依存なし。 |

推奨順序: 08(OpenAPI 方針)と 04(getting-started §2)の方針を先に確認 → 本課題の文書修正(§5.1)→ 別課題(§5.2、Q1 回答後)。
