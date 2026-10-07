# 03: API キースコープ仕様と `getting-started.md` §3 の不一致

本書は**対応計画のみ**であり、コード・文書の修正は含まない。記載する事実は 2026-09-29 時点のリポジトリを実際に読んで確認したものだけで、`file:line` を付ける。読んでいない・実行していないものは「未確認」と明記する。日数・週数の見積りは記載しない。

参照した規約: [`ARCHITECTURE.md`](../../ARCHITECTURE.md)、[`docs/architecture/LAYER-RULES.md`](../architecture/LAYER-RULES.md)、[`tdd-on-edit`](../../.cursor/skills/tdd-on-edit/SKILL.md)、[`test-common`](../../.cursor/skills/test-common/SKILL.md)、[`evidence-before-design-and-implementation.mdc`](../../.cursor/rules/evidence-before-design-and-implementation.mdc)、[`project-necessary-code-only.mdc`](../../.cursor/rules/project-necessary-code-only.mdc)。

---

## 0. 決定事項

ユーザー指示のうち「与えない」を次のとおり解釈して確定した(索引: [`README.md`](README.md) の「決定事項」表)。

- **決定**: API キーに**書き込みスコープ(`masters:write`)を付与しない**。付与手段(UI / API / 管理者付与 / 課金 tier)は作らない。API キーは**読み取り専用(`masters:read`)**とする。
- **書き込みの経路**: 書き込み(`POST` / `PUT` / `PATCH` / `DELETE` と `setup_proposal?mode=apply`)は、ログインセッション(ブラウザ/UI)経由のみとする。
- **解釈であること**: この決定は、ユーザー語「与えない」の**解釈 (a)** である。もう一方の解釈 (b)「組織メンバーに Plan の編集権限を与えない(閲覧のみ)」は本書の対象外で、[課題 10](10-authorization-consistency.md) で扱う。ユーザーの意図が (b) だけであった場合は、本節と §5 の方針を差し替える。
- **本書への影響**: 旧版にあった「書き込みスコープの付与手段を別課題として切り出す」提案は**削除**した。代わりに §5 で次の 4 点を計画に落とし込んだ。
  - (i) `getting-started.md` §3 を「キーは読み取り専用。書き込みはセッション経由のみ」に直す Before/After(§5.1)。
  - (ii) `openapi.yaml` の `masters:write` 記述・セキュリティスキーム・各 write operation の扱い(§5.2)。
  - (iii) 公式 MCP `apply_crop_setup` とスキル `agrr-crop-setup` の apply 手順が API キーでは常に 403 になる問題への対処(§5.3)。
  - (iv) 実装が既に「新規・再発行キーは read のみ」であることを踏まえ、コード変更が必要かどうかの判断材料(§5.4)。

### 第2回決定(「移行する」「削除」)

ユーザー指示「複数所属はスコープアウト、移行する、削除、errors、閲覧も許さない」のうち、本課題に関わる 2 語を次のとおり確定した(索引: [`README.md`](README.md) の「決定事項(第 2 回)」表)。指示は短い語で対象を明記していないため、**文脈からの解釈**である。誤りがあれば本節と §5.3、§5.4 を差し替える。

- **決定 (1) 移行する = 選択肢 X2 を採用確定**: V15 以前に発行され、`["masters:read","masters:write"]` のまま残る既存 API キーを、**データ移行で `["masters:read"]` のみに揃える**。実施方法は新しい schema migration(§5.4.1)。旧選択肢 X1(移行しない)と X3(コードで Write を拒否)は**採らない**。
- **決定 (2) 削除 = 選択肢 M-A を採用確定**: 公式 MCP(`tools/agrr-mcp/`)の `apply_crop_setup` ツールを**削除する**。スキル `agrr-crop-setup` の手順 5 は「UI で適用」に書き換える(§5.3)。旧選択肢 M-B(ツールを残して文書化)は**採らない**。
- **解釈であること**:
  - 「移行する」は、複数の未決事項のうち、本課題の Q5(既存キーの read+write を read のみへ移行するか)への回答と解釈した。他課題に「移行」を含む未決事項がある(課題 07 の旧キー併記の移行方式など)が、対象は本課題の V15 以前の既存 API キーである。
  - 「削除」は、他の候補ではなく、**本課題の MCP ツール `apply_crop_setup` の削除**と解釈した。他の候補は、課題 07 の旧キー(`errors` / `message` 併記)の削除(S2)と、課題 10 の削除 undo の扱い(`DeletionUndoScheduleInteractor` が本番未配線)である。この 2 つは本書の対象外で、「削除」の回答としては扱っていない。
  - 解釈が異なる場合の影響: (1) が誤りなら、§5.4.1 の V27 を作らず X1(移行しない)に戻す。その場合は §5.1.1 の After の最後の箇条書きに「過去に発行された一部のキーは書き込み可能な状態が残っている場合がありますが、サポート対象外です。再発行すると読み取り専用になります」を追加する。(2) が誤りなら、M-B に戻す(§5.3.1 の表を参照)。どちらも、他の決定(§0 の第1回決定)には影響しない。
- **確定に伴って残る未決**: 移行そのものの実施承認(本番データ変更)、対象キー所有者への通知の要否、事前確認の結果による中止条件、MCP のバージョン番号の扱い、OpenAPI の `security` 上書き(Q7)。§3.2 の表に残した。

---

## 1. 概要と重大度

### 概要

[`docs/api/getting-started.md`](../api/getting-started.md) §3 は次のように記載している。

- 「現時点ではキーごとのスコープ列は DB に保存していません」(`getting-started.md:34`)
- 「発行されたキーは現状 **読み取りと書き込みの両方** が可能です」(`getting-started.md:41`)
- 見出しも「スコープ（将来の tier 用）」(`getting-started.md:32`)

実装は逆である。スコープは DB に保存され、Masters API で強制されている。新規発行・再発行のキーは**読み取り専用**で、書き込みは 403 になる。この文書だけが古い。`docs/api/openapi.yaml` の冒頭 description は実装と一致している。

§0 の決定により、実装の「API キーは read のみ」は**仕様として確定**した。したがって、次の 2 種類の問題が残る。

- **文書の誤り**: `getting-started.md` §3 が実装と逆。加えて、API キーで書き込めることを前提にした記述が複数の文書に残る(§2.5、§2.8、§2.9)。
- **API キー前提の apply / 書き込み案内が成立しない**: 公式 MCP `apply_crop_setup`、スキル `agrr-crop-setup` の手順 5、`getting-started.md` §5 の apply 例、`builtin-generation-sunset.md` の代替経路は、API キーでは常に 403 になる(§4)。これは新規発行キーの問題ではなく、決定後の**恒久的な状態**である。

### 重大度

| 項目 | 重大度 | 理由 |
|------|--------|------|
| 文書の誤り(§3 の記述) | 中 | 誤りの向きは実装が厳しい側なので、権限が過剰になる問題ではない。ただしスキル作者・MCP 利用者が「書き込める」と信じて実装し、実行時に 403 で失敗する。 |
| API キー前提の書き込み/apply 案内(MCP・スキル・getting-started §5・sunset ガイド) | 高 | 決定後は構造的に常に失敗する。文書だけでなく、MCP ツール `apply_crop_setup` 自体が常に失敗するツールになる(§5.3)。 |
| 再生成による暗黙の降格 | 低 | 決定により意図した仕様に寄せる(Q2)。V15 で read+write を維持した既存キーが、再生成すると read のみになる。UI の確認ダイアログは「現在のキーが無効になる」ことしか伝えない(`frontend/src/assets/i18n/ja.json:3822` の `regenerate_confirm`)。 |
| 既存キーに残る書き込み権限(V15 以前) | 中(要確認) | 決定(書き込みを与えない)と、実装の現況(旧キーは write を保持)が食い違う。第2回決定で X2(データ移行)を採用確定。本番の分布は未確認(Q3)で、移行前の件数確認(§5.4.1.5)が前提。 |

セキュリティ上の露出(過剰権限)は、新規・再発行キーには無い。実装は最小権限側に倒れている(`crates/agrr-domain/src/shared/dtos/masters_api_scope.rs:47`「Default scopes for newly generated API keys (least privilege)」)。

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
- コード中に `api_key_scopes` を書き込む本番経路は、上記ゲートウェイ以外にない。`crates/` 全体の検索(`api_key_scopes` / `masters_api_scope` / `MASTERS_WRITE`)の結果は、上記ゲートウェイ、テスト用ヘルパ `crates/agrr-r4-contract/tests/support.rs:123-131` (`set_user_api_key_scopes`)、V15、および読み取り側のみだった。
- 平文キーからハッシュへの移行(`crates/agrr-adapters-sqlite/src/shared/api_key_principal_gateway.rs:32-42`、`crates/agrr-adapters-sqlite/src/api_keys/api_key_backfill.rs:27`)の `UPDATE` は `api_key_scopes` に触れない。V25(ハッシュ化)後もスコープは保持される。

### 2.4 スコープの読み取りと強制(HTTP 境界)

- API キー認証では `SessionPrincipal.api_key_scopes = Some(parse_api_key_scopes_json(...))` になる(`api_key_principal_gateway.rs:21-29`)。
- セッション Cookie 認証では `api_key_scopes: None` になる(`crates/agrr-adapters-sqlite/src/shared/session_cookie_principal_gateway.rs:33,56,67,79`)。`SessionPrincipal.api_key_scopes` の型は `Option<Vec<String>>` で、doc コメントは「`Some` when resolved via API key; `None` for session cookie (unrestricted Masters access)」(`crates/agrr-domain/src/shared/dtos/session_principal.rs:9-10`)。つまりこのフィールドは**「API キー経由か、セッション経由か」の判別子を兼ねている**。
- `enforce_api_key_scopes`(`crates/agrr-server/src/masters_auth.rs:109-128`)の挙動は次のとおり。
  - `None`(セッション)なら常に許可する(`:115-117`)。
  - `Some(scopes)` で要求を満たさなければ、403 と `{"error":"forbidden","error_code":"insufficient_scope"}` を返す(`:95-100`、`:123-127`)。
- `MastersUserId` extractor(`masters_auth.rs:130-152`)が認証後にこれを呼ぶ。`setup_proposal` ハンドラも `MastersUserId` を使い、引数の先頭側(`State` の次)に置く(`crates/agrr-server/src/masters_crop_setup_proposal.rs:3,40`)。そのため apply の 403 は本文の検証より先に返る。コードから導いたもので、実行では未確認。
- NULL スコープのキーは `Some([])` になり、`GET` を含むすべてが 403 になる。コードから導いたもので、実行では未確認。
- API キーの取り出しはヘッダー(`Authorization: Bearer` と `x-api-key`)のみで、クエリの `api_key` は無視される(`masters_auth.rs:44-61`、テスト `masters_auth.rs:177-181`)。getting-started §2 の「クエリ（非推奨）」(`getting-started.md:30`)は課題 04 の領分(§10)。
- API キーの主体解決(`ApiKeyPrincipalSqliteGateway`)を使う本番コードは `masters_auth.rs:4,71` のみ(`crates/` を `ApiKeyPrincipalSqliteGateway` で検索。他はテストと `lib.rs` の再エクスポート)。したがって API キーが有効なのは `/api/v1/masters/*` に限られる。これは課題 10 が「未確認」としていた点の一部を埋める。

### 2.5 OpenAPI と文書の現状

- `docs/api/openapi.yaml:9-13` は「Scopes (enforced per API key)」として `masters:read` と `masters:write` を定義する。「Session cookie authentication has full Masters access. API keys default to `masters:read` only on generate/regenerate.」とも書いている。
- グローバル `security` は `bearerApiKey` と `headerApiKey` のみ(`openapi.yaml:23-25`)。個別 operation の `security` 上書きは無い(`grep -n "security" docs/api/openapi.yaml` は `:23` のみ。他は `securitySchemes`)。
- `openapi.yaml:358` は apply を `masters:write` としている。`openapi.yaml:386-399` の `securitySchemes` は、`bearerApiKey`(`:391-392`「Scopes are stored on the key (`masters:read`, `masters:write`). New keys default to `masters:read` only.」)、`headerApiKey`(`:398`「Same scope rules as bearerApiKey」)、`sessionCookie`(`:399-403`「Browser session (UI only; not for server-to-server skills)」)。
- `openapi.yaml` の write operation は 20 operation 中、`post` / `patch` / `delete` が計 12(`:44`、`:84`、`:101`、`:133`、`:168`、`:185`、`:216`、`:248`、`:265`、`:291`、`:315`、`:332`)と、`setup_proposal` の `post`(`:353`)。`PUT` の記載は無い(課題 08 D-05)。
- `openapi.yaml` には `403` / `insufficient_scope` の記述が**ない**(`grep -n "403\|insufficient" docs/api/openapi.yaml` が 0 件)。課題 08 D-03 の領分。
- `docs/api/setup_proposal-openapi-snippet.yaml` はスコープに言及せず、responses は 200/201/401/404 のみ。403 もない。security は `bearerApiKey` と `sessionCookie`。`getting-started.md:92` は同 snippet を「レガシー snippet・本体は openapi.yaml に統合」と位置づけている。
- `getting-started.md` の他の箇所の状況は次のとおり。
  - §2 の冒頭(`:24`)は「サーバー間連携では API キーを使います」。読み取り専用である旨がない。
  - §5 の典型フロー(`:60-67`)は dry_run の後に apply を案内し、apply の curl 例が `Authorization: Bearer $AGRR_API_KEY` を使う(`:79-87`)。API キーでは 403 になる。
  - §4 のレート制限表(`:47-52`)は書き込み(60/分)と apply(5/分)を区別している。これは実装の分類 `Read`/`DryRun`/`Write`/`Apply` と整合する(`masters_rate_limit.rs:20-52`)。
- `docs/api/builtin-generation-sunset.md` の API キー前提の記述は次のとおり。
  - 代替表(`:9-14`)は、作物作成に `POST /api/v1/masters/crops`、肥料・害虫に `POST` / `PATCH /api/v1/masters/...` を挙げる(`:9-13`)。API キーでは 403。
  - 「推奨経路」(`:29-49`)は Bearer で `dry_run` の例を示し(`:39-40`)、`apply` を箇条書きで説明する(`:47`)。API キーでは apply が 403。
  - 「肥料・害虫マスタ」(`:61`)は「外部スクリプトで `POST` / `PATCH` を呼び出してください」と案内する。API キーでは 403。
  - 「### 3. UI からインポート」(`:51-53`)は、作物詳細・編集画面の **提案 JSON をインポート**(セッション経由)から同じ `setup_proposal` API を呼べると案内する。決定後は、こちらが**唯一の apply 経路**になる。

### 2.6 API キー発行 UI(スコープの表示・選択)

- 画面は `frontend/src/app/components/settings/api-keys/api-keys.component.ts`。生成(`:56-64`)と再生成(`:41-50`、確認ダイアログ `:106-128`)のボタンだけで、スコープの表示・選択 UI は**ない**。
- 生成・再生成の HTTP 呼び出しは本文 `{}` で `POST /api/v1/api_keys/generate|regenerate` を叩く(`frontend/src/app/services/api-key-management.service.ts:29-42`、特に `:38`)。
- サーバー側ハンドラ(`crates/agrr-server/src/api_keys.rs:20-21,60-91`)は `CookieJar` のみを受け取り、リクエスト本文もスコープ引数も持たない。
- `GET /auth/me` のレスポンスはマスク済みキーを返す(`crates/agrr-server/src/auth_api.rs:45-99`)。`api_key_scopes` は返さない。`auth_api.rs` にスコープの記述はない。
- 画面の説明文は「マスタ管理用のCRUD APIにアクセスできます」(`frontend/src/assets/i18n/ja.json:3810`)。英語は「Use your API key to access CRUD APIs for master data.」(`en.json:3774`)。`in.json:3480` も CRUD API を指す。エンドポイント一覧(`ja.json:3839`)は `POST`/`PATCH`/`DELETE` を含み、書き込みに使えない旨は書かれていない。
- **結論**: 書き込みスコープを付与する手段は、サーバー API にも UI にもない。DB を直接更新する以外に手段はない(テストは `support.rs:123-131` で直接 UPDATE している)。これは§0の決定と**一致している**。決定後は「欠落」ではなく「仕様」であり、UI 文言(CRUD API にアクセスできる、書き込みエンドポイントの一覧)が仕様と食い違う点だけが残る。

### 2.7 既存の契約テスト(R4)

`crates/agrr-r4-contract/tests/contracts.rs` に、次のテストが**既に存在する**(読了済み。この計画の作業では実行していない)。

| テスト | 行 | 表明内容 |
|--------|----|----------|
| `masters_api_key_read_scope_allows_get_and_denies_post` | `:3013-3046` | read キーで `GET` 200、`POST /api/v1/masters/crops` が 403 かつ `error_code == "insufficient_scope"` |
| `masters_api_key_write_scope_allows_post` | `:3048-3067` | read+write キーで `POST` 201 |
| `masters_api_key_read_scope_denies_setup_proposal_apply` | `:3069-3092` | read キーで `mode=apply` が 403 |
| `post_api_keys_generate_defaults_to_read_only_scopes` | `:3094-3120` | `POST /api/v1/api_keys/regenerate` 後の DB の `api_key_scopes` が `["masters:read"]` |
| `post_masters_crop_setup_proposal_apply_persists_stages_and_blueprints` | `:2715-2740` 付近 | **セッション**(developer)の `mode=apply` が 201。stage を作る |
| `post_masters_crop_setup_proposal_apply_rate_limited_returns_429_with_retry_after` | `:3153-3190` | セッション(farmer)の apply を 2 回 201、3 回目が 429 と `Retry-After` |

ユニット/ドメインのテストは次のとおり。

- `masters_api_scope.rs:68-128` に、リクエストの分類・許可判定・JSON パースのテストがある。
- `masters_auth.rs:154-208` に、セッション許可と read キーの POST 拒否のテストがある。
- `crates/agrr-domain/test/shared/interactors_masters_api_credentials_resolve_interactor_test.rs:42` は、スコープ付き principal のテストデータを含む。

**既存テストの弱点**(コードを読んで確認)は次のとおり。

- 403 を表明する 2 つのテスト(`:3021`、`:3077`)は、`regenerate` の直後に `set_user_api_key_scopes(user_id, r#"["masters:read"]"#)` を呼んでスコープを**明示的に上書き**している。「生成したままのキーが書き込めない」ことは、これらのテストでは実キーで確かめられていない(既定値は `:3094-3120` が DB の値だけで確認する)。
- 403 を表明する書き込みは `POST /api/v1/masters/crops` の 1 経路だけ。`PUT` / `PATCH` / `DELETE` と、crops 以外の write ルートは検証していない。
- read キーの apply が 403 でも、**副作用が無いこと**(stage が作られない)は検証していない。

**不足していること**(存在する範囲で検索した結果)は次のとおり。

- `POST /api/v1/api_keys/generate` の既定スコープ(テスト名に反して `regenerate` を叩いている)。
- read キーで `mode=dry_run` が拒否されないこと。
- write キーで `mode=apply` が 403 にならないこと(決定後は不要になる可能性が高い。§6.5)。
- 再生成で read+write が `["masters:read"]` に降格すること。
- スコープ NULL/空のキーが fail-closed(403)になること。
- V15 の `UPDATE` 自体のテスト。`crates/agrr-migrate/tests/` と `crates/agrr-migrate/src` に `api_key_scopes` / `V15` の言及はなかった。`schema_smoke.rs` が全スキーマを適用するかは**未確認**。
- 文書(getting-started/openapi)と実装のスコープ定義の機械的な整合検査。`scripts/` の doc 系チェック(`check-doc-freshness-lib.mjs`、`check-doc-stale-paths.sh`、`check-doc-internal-links.sh`)は API スコープを見ない。CI は `.github/workflows/doc-freshness.yml:25-34` で実行する。

### 2.8 外部スキル/MCP の前提

- 公式 MCP(実体は `tools/agrr-mcp/`)。`tools/agrr-mcp/README.md:8` は「AGRR API key with Masters access」とだけ書く。README `:18` は UI か `POST /api/v1/api_keys/generate` での発行を案内する。README `:54` の `apply_crop_setup` は `mode=apply` を呼ぶ。README `:82-84` の「Apply idempotency」は「dry_run → user confirmation → single `apply_crop_setup`」を推奨フローとする。スコープの記述はない。
- MCP のツールは 4 つで、`list_reference_crops`、`get_crop_detail`、`propose_crop_setup`、`apply_crop_setup`(`tools/agrr-mcp/src/tools.mjs:77-82`)。`apply_crop_setup` の定義は `:58-71`、クライアント側のメソッドは `tools/agrr-mcp/src/agrr-client.mjs:54`。
- MCP クライアントが送る認証は `Authorization: Bearer <api key>` のみで、Cookie を送る手段はない(`agrr-client.mjs:66-71`。`AGRR_API_KEY` が必須で、空だと構築時に例外: `:8-11`)。したがって MCP 経由のリクエストは常に API キー主体になり、`apply_crop_setup` は決定後**常に 403** になる。コードから導いたもので、実行では未確認。
- MCP クライアントのエラー処理(`agrr-client.mjs:87-96`)は、`payload.error` の文字列だけを例外メッセージにし(`:88-92`)、`err.status` と `err.body`(パース済み本文)は保持する(`:93-94`)。403 の場合は `"forbidden"` になり、`error_code: insufficient_scope` はメッセージに現れない。ツールのハンドラ(`tools.mjs`)は `try/catch` を持たず、例外を MCP SDK に伝える。SDK が例外をどう利用者へ返すかは**未確認**。
- `.cursor/skills/agrr-crop-setup/SKILL.md:17-18` の前提は「MCP 接続済み・`AGRR_API_KEY` を渡している」まで。`:36` の手順 5 が `apply_crop_setup` を呼ぶ。手順 4(`:35`)は「適用の明示的な承認を得る」。書き込みスコープが必要である旨は書かれていない。
- 外部スキルが読む `docs/api/setup_proposal-openapi-snippet.yaml` は、403 とスコープの記述を持たない(§2.5)。
- MCP の単体テストは CI で実行される(`.github/workflows/frontend-test.yml:131-133` の「agrr-mcp unit tests」)。`apply` に関するテストは `tools/agrr-mcp/test/agrr-client.test.mjs:95` 以降と `tools/agrr-mcp/test/server-tools.test.mjs:23,34,63-68`。特に `server-tools.test.mjs:34` は「four crop setup tools」を表明する。
- ADR-001 は、外部スキルが AGRR に投入する正規 API を `setup_proposal?mode=dry_run|apply` とし(`docs/adr/ADR-001-external-skill-generation-agrr-daemon-calculation.md:37-46`)、「API 商品化」(#320)を「OpenAPI・API キー導線・レート制限」としている(`:103`)。外部スキルが API キーで apply まで行う前提と読める。§0 の決定はこれと食い違う(§5.5、§10 の課題 09)。

### 2.9 レート制限との順序(課題 10 の R-4 の一部)

- レート制限は `masters_routes.rs:25-28` の `route_layer` として、Masters の全ルートを包む。ミドルウェア(`masters_rate_limit.rs:152-176`)は認証だけを行い(`resolve_masters_user_id`: `:163`)、成功すればスコープを見ずに `check(user_id, tier)` で分単位カウントに入れる。スコープ判定は、その後のハンドラで `MastersUserId` が走る時点(`masters_auth.rs:130-152`)。
- したがって、read キーの `POST` / `apply` が 403 になる場合も、`Write` / `Apply` の分単位カウントを消費する。コードから導いたもので、実行では未確認。
- 実務上の影響: R4 は `AGRR_TEST_SCRIPT=1` で apply の上限が **2 回/分**(`masters_rate_limit.rs:43`)になる。新規テストが同じユーザーで apply を 403 にするだけでも、そのユーザーの apply 枠を消費し、同じユーザーの他の apply テスト(`developer`: `contracts.rs:2715`、`:3069`、`farmer`: `:3153`)が 429 になる恐れがある(§6.3、§8)。R4 は `--test-threads=1` で実行される(`scripts/run-rust-contract-tests.sh:359`)。
- 実際に 403 がカウントされることの是非は、認可の一貫性の観点で課題 10 が扱う。本書では変更しない。

### 2.10 既存キー移行(X2)の設計に使う事実(第2回決定で追加)

すべてリポジトリのコードを読んで確認した。本番 DB は読んでいない。

**`users` テーブルの列と、キーの発行日時を持つ列の有無**

- `users` の列は、V1 の 10 列(`id`、`email`、`name`、`google_id`、`avatar_url`、`created_at`、`updated_at`、`admin`、`is_anonymous`、`api_key`: `V1__baseline.sql:27`)に、V15 の `api_key_scopes`(`V15__api_key_scopes.sql:1`)、V25 の `api_key_hash` と `api_key_prefix`(`V25__api_key_hash.sql:1-2`)を足した 13 列である。`ALTER TABLE users` を含む migration は V15 と V25 だけ(`grep -il "alter table.*users" migrations/schema/*.sql`)。V1 + V15 + V25 を `sqlite3` の作業用 DB に適用して `PRAGMA table_info(users)` でも 13 列を確認した(リポジトリ外の一時ファイル。確認後に削除)。
- **キーの発行日時を持つ列は無い**。`users.created_at` はユーザー作成日時で、キー発行日時ではない。`users.updated_at` は、キーの生成・再生成(`user_api_key_rotation_gateway.rs:52-53`)と、平文からハッシュへの移行(`api_key_backfill.rs:27-28`、`api_key_principal_gateway.rs:37-38`)の `UPDATE` が `datetime('now')` に更新する。したがって**日時による判定はできない**。

**移行対象を特定できる条件**

- V15 が付与する値は、文字列 `["masters:read","masters:write"]` の 1 通りだけ(`V15__api_key_scopes.sql:5`)。対象は「`api_key` が非 NULL かつ空でなく、`api_key_scopes` が NULL または空」の行(`:6-8`)。
- `api_key_scopes` を書く本番コードは、生成・再生成のゲートウェイ(`user_api_key_rotation_gateway.rs:43,52-54`)だけで、値は常に `["masters:read"]`(`masters_api_scope.rs:48-50`)。§2.3 の検索のとおり、これ以外の本番経路は無い(テストの `support.rs:123-131` を除く)。
- したがって、本番 DB で `masters:write` を含むスコープを持つ行は、**V15 が付与した旧キーであるか、DB を直接更新した行**のどちらかである。新規・再発行の read のみキー(`["masters:read"]`)と**取り違えることはない**。区別が付かない場合の扱いを決める必要は生じない。
- V15 の条件は平文の `api_key` 列を見る。V25 以降のハッシュ移行は `api_key` を NULL に更新するが、`api_key_scopes` は変更しない(§2.3)。よって、移行対象の判定には**スコープ列の内容だけ**を使い、`api_key` 列・`api_key_hash` 列の有無は条件に入れない。平文の `api_key` が残る未移行の行(`api_key_backfill.rs:8-14` の対象)も、スコープ列が write を含めば対象になる。
- 主体解決は、ハッシュの照合に失敗したとき平文列での照合に進む(`api_key_principal_gateway.rs:67-80`)。どちらの経路でも `api_key_scopes` 列を読む(`:52`、`:72`)ため、列を更新すれば両方に効く。
- スコープ文字列は JSON 配列だが、書式は固定ではない(V15 は空白なしの 1 通り。`parse_api_key_scopes_json` は空白を含む配列も解釈する: `masters_api_scope.rs:53-66`)。実装は空白なしのみを書くので、判定は `LIKE '%"masters:write"%'` で足りる。`sqlite3` 3.45.1 の作業用 DB で、空白ありの配列(`[ "masters:read" , "masters:write" ]`)と `["masters:write"]` 単独も一致すること、二重引用符の無い `x masters:write` は一致しないこと(`parse_api_key_scopes_json` はこれを空配列にするので、元々すべて 403)を確認した。JSON 関数(`json_each`)は、不正な JSON の行で migration 全体を失敗させ得るので使わない(不正 JSON の行を `json_valid` で除く書き方もできるが、条件が複雑になる)。

**migration の置き場と形式(慣例の確認)**

| 候補 | 内容 | 判断 |
|------|------|------|
| `crates/agrr-migrate/migrations/schema/`(refinery、`V<n>__<name>.sql`) | `embed_migrations!("migrations/schema")`(`schema.rs:6-9`)で埋め込み。適用履歴は `refinery_schema_history`。起動時に `schema run` で**自動適用**される(`schema_up_to_date` が偽なら `migrate_all`: `db_bootstrap_common.sh:136-139`、実体は `:192-207`、呼び出し元は `start_agrr_server.sh:62-64`)。データを更新する SQL の前例がある: V6(`UPDATE task_schedule_items ...`: `V6__drop_task_schedule_item_actuals.sql:2`)、V5・V10 の `INSERT ... SELECT`、V15 自身の `UPDATE` | **採用** |
| `crates/agrr-migrate/data/`(`agrr-migrate data apply --region --kind`) | 参照データ用。バージョンは `manifest/legacy_versions.yaml`(Rails 由来。`scripts/generate_legacy_versions_manifest.rb` で生成)から読み(`manifest.rs:31-38`)、種別は固定の `DATA_KINDS`(`manifest.rs:56-64`: base / nutrients / pests / tasks / templates / dev_fixtures / repair)、履歴は `data_migration_history`(`apply.rs:108-129`)。**デプロイでは走らず、手動実行**(`P7-MIGRATION-RUNBOOK.md` の表) | 不採用。地域・種別に属さないユーザー行の更新には合わない。手動実行なので、実施漏れで旧キーが残るリスクがある |

- 冪等性の慣例: refinery が各バージョンを `refinery_schema_history` に記録し、一度だけ適用する。加えて、`data` 側は `is_applied` で skip し(`apply.rs:65-67`)、履歴の記録は `INSERT OR IGNORE`(`apply.rs:125`)。本件の `UPDATE ... WHERE` は、対象が無くなれば 0 行更新になり、再実行しても結果が変わらない(冪等)。
- 既存の migration ファイルは**編集しない**。V15 を書き換えると、適用済み環境と checksum が食い違う(refinery は既定でこれを拒否する。refinery のソースは手元に無く、この点は既存の運用慣例からの推測で、**未確認**)。新しい V27 を追加する。
- バージョン番号は V26 が最大(`ls migrations/schema`)。V12 は欠番(履歴上も存在しない: `git log --all -- 'crates/agrr-migrate/migrations/schema/V12*'` が空)。次は **V27**。
- 本番の適用経路と制約:
  - Cloud Run は `--max-instances 1`(`.cursor/skills/deploy-server/scripts/_agrr-server-cloud-run.sh:140`)で、同時に複数インスタンスが migration を走らせることはない。
  - 起動時、HTTP の bind(`exec agrr-server`)は復元の後で、migration は**バックグラウンドの post-restore bootstrap**で走る(`start_agrr_server.sh:61-71`)。失敗しても `migrate_all || return 1`(`db_bootstrap_common.sh:139`)はバックグラウンドの関数内の `return` で、サーバーは起動し続ける。すなわち、V27 の適用完了までの間と、V27 が失敗した場合、旧キーは write のまま残る。適用の確認は起動ログではなく DB で行う(§5.4.1.6)。
  - Litestream の保持期間は `retention: 24h`(`config/litestream.yml`)。Litestream 復元による巻き戻しが可能なのは直近 24 時間に限られ、巻き戻すとその時点以降の**すべての書き込み**が失われる。スキーマのロールバックは forward-only とされている(`P7-MIGRATION-RUNBOOK.md` の「Schema rollback」)。
- 本番への 1 回限りの書き込みの前例: `scripts/production-data-migrate-inner.sh`(Cloud Run 上で復元 → `schema run` → `sqlite3` で `DELETE` → `data apply` → Litestream 複製。`:14-34`)を、`.cursor/skills/deploy-server/scripts/run-production-data-migrate.sh` が起動する。ロールバック用の逆 `UPDATE` を本番へ流す場合の既存の経路はこれ(§5.4.1.7)。

**利用実態の把握手段**

- キーの最終使用日時を持つ列・テーブルは見つからなかった。セキュリティ監査ログの関数は、ログイン・ログアウト・キーの生成/再生成・参照マスタ変更・バックドア操作だけ(`crates/agrr-server/src/security_audit_log.rs:80-133`)で、Masters API の認証成功は記録しない。`masters_auth.rs` と `masters_rate_limit.rs` に `tracing::info` / `warn` も無い(`rg "tracing::(info|warn)"` が 0 件)。よって、「旧キーが実際に書き込みに使われているか」は**アプリの DB・ログからは判別できない**。Cloud Run のリクエストログに残る範囲は未確認。
- 通知手段: メール送信ライブラリ名(`smtp`、`mailer`、`sendgrid`、`send_email`、`lettre`)での `crates/` 検索は 0 件。ユーザー全員への一括通知の仕組みはリポジトリ内で確認できなかった。`users.email` は NULL 可(`V1__baseline.sql:27`)。

---

## 3. 正の確定

### 3.1 実装を正とする根拠

「文書ではなく実装を正とする」のは、次の理由で確実に説明できる。

1. 実装がスコープを保存・強制している(§2.1〜§2.4)。契約テストがその挙動を固定している(§2.7)。
2. 強制は最小権限という意図的な設計で、コード上に理由が明記されている(`masters_api_scope.rs:47`、V15 コメント `:3`)。
3. OpenAPI の冒頭 description が実装と一致している(§2.5)。誤りは `getting-started.md` §3 とその周辺である。
4. `ARCHITECTURE.md` の契約優先(R9)と観測可能なテストの優先順位に沿う。`CLAUDE.md` の規範優先順位は「1. 観測可能なテスト → 2. LAYER-RULES → …」で、文書はテストより下位である。
5. §0 の決定(API キーに書き込みスコープを与えない)は、実装の既定値(新規・再発行は read のみ)と一致する。実装を文書に合わせて「全キー read+write」に戻すのは、決定に反し、最小権限を意図した #619 の変更を取り消すことになる。選ばない。

したがって、文書側を実装に合わせて修正する。実装の変更が必要かは §5.4 で判断材料を示す。

### 3.2 ユーザーへ確認が必要な点

§0 の決定(第1回・第2回)で解消した項目と、残る項目を分ける。

解消した項目:

- 旧 Q1「書き込みスコープの付与手段を提供するか」: **提供しない**(§0 第1回)。
- 旧 Q4「付与できるまでの間、MCP/スキルの apply 経路をどう案内するか」: 付与は行わないため、**UI(セッション)経由のみ**と案内する(§5.1、§5.3)。
- 旧 Q5 のうち「移行するか」: **移行する**(X2 採用確定。§0 第2回、§5.4.1)。実施の承認は下の Q5 に残る。
- 旧 Q6「`apply_crop_setup` を削除するか」: **削除する**(M-A 採用確定。§0 第2回、§5.3)。
- 旧 §5.4.2 の K1/K2: X2 の採用と整合するのは **K1(列も定数も残す)**。K2 は本課題で行わない(§5.4.2)。

残る確認事項:

| # | 確認事項 | 現時点の事実 | 推奨 | 判断が影響する箇所 |
|---|----------|--------------|------|--------------------|
| Q2 | 既存キー(V15 で read+write を維持したもの)を再生成すると read のみになる挙動は、意図した仕様として確定してよいか | コード上そうなる(§2.3)。PR/ADR で意図が明記されたかは**未確認**(#619 の説明は「Default new/regenerated keys to masters:read only」と書く) | **意図とみなして確定**する。§0 の決定と整合する。UI の警告は不要。文書化のみ行う(§5.1.1)。X2 で旧キーが移行済みになれば、降格の意味は「再発行しても権限は変わらない」に単純化される | 確認ダイアログ文言(変更しない場合はコード変更なし)、getting-started §3 の文言 |
| Q3 | 本番の既存キーの現況。件数確認(§5.4.1.5)の実行可否と、結果に応じた中止条件 | 本番 DB は**未確認**(本計画では問い合わせていない)。`production-primary-sqlite-query` スキルが使えるかは GCP の認証情報に依存し、未確認(§5.4.1.4) | 実行前にユーザーの承認を得て、読み取り専用の件数確認を行う。**対象 0 件でも V27 は追加する**(環境差を吸収し、決定「移行する」を全環境で満たすため。SQL は 1 文)。異常値(§5.4.1.5 の確認 3)が 1 件でもあれば、V27 の条件を見直してから進める | §5.4.1、§7 の手順 1 |
| Q5 | 本番データ変更(V27 のデプロイ)の**実施承認とタイミング** | 移行は本番データの変更を伴う(§5.4.1)。外部連携が書き込みに使っている可能性は**未確認**(§2.10) | 件数確認(Q3)の結果を提示したうえで、ユーザーが V27 を含むリリースのデプロイを承認する。**承認が取れるまで、V27 を含むコミットを本番へデプロイしない**(migration は起動時に自動適用されるため、マージ後のデプロイが実施点になる: §2.10) | §5.4.1、§7 |
| Q7 | `openapi.yaml` の write operation を、`security` の上書き(セッションのみ)で表すか、注記に留めるか(§5.2) | 現状の OpenAPI は API キー向けの公開仕様(`sessionCookie` は「UI only」) | §5.2 の推奨案(operation ごとに `security` をセッションのみへ上書き) | §5.2、課題 08 との調整 |
| Q8 | 移行対象キーの所有者に**事前通知**するか | 対象件数は未確認(Q3)。通知の仕組み(一括メール等)はリポジトリ内に確認できない(§2.10)。利用実態も DB・ログから判別できない(§2.10) | 件数が 0 なら不要。1 件以上なら、ユーザーが手段(個別連絡、文書のみ)を決める。**文書での告知**は必ず行う(getting-started §3 と、リリース時の変更点。§5.4.1.8) | §5.4.1.8、§7 の手順 |
| Q9 | MCP パッケージのバージョン(`0.1.0`)を、ツール削除に合わせて上げるか | `package.json:3`、`package-lock.json:3,9`、`server.mjs:11` が `0.1.0`。`private: true`(npm 公開なし)。CHANGELOG・タグは無い(§5.3.7) | 0.x の破壊的変更として **`0.2.0` に上げる**。4 箇所の書き換えのみ | §5.3.7 |
| Q10 | 廃止予定エンドポイントの応答 `deprecation.alternative` の文言(`builtin_generation_deprecation.rs:33`)に含まれる `apply` 案内と `tools/agrr-mcp/` の記述を直すか | Sunset 日(2026-10-18)以降に該当ルート自体が削除される(#323)。文言はセッションからは正しい。API キーからは apply が 403 | **直さない**(短期間で消えるコードの文言。テストは `setup_proposal` を含むことだけを表明: `:151-169`)。直す場合は `crates/agrr-server/**` の変更になり、Docker 検証前に `rebuild-restart.sh` が要る | §5.3.6 |

Q2〜Q10 の回答を待たずに進められる作業は次のとおり。

- §5.1 の文書修正のうち、「API キーは読み取り専用・書き込みはセッション経由」を述べる部分。ただし**公開(マージ)は V27 のデプロイ完了後**にする(V27 の適用前は旧キーが書き込めるため、断定が一時的に不正確になる。§5.4.1.9)。
- R4 契約テストの追加(§6.3 の T-1〜T-8)。V27 の有無に依存しない。
- MCP の `apply_crop_setup` 削除(§5.3)とスキルの書き換え。V27 の前後どちらでもよいが、**V27 が先にデプロイされる前に MCP を削除しても、旧キーが HTTP で直接 apply できる状態は残る**点に注意(§5.3.7)。

---

## 4. 影響範囲

### 4.1 利用者の外部スキル・MCP

- **MCP `apply_crop_setup`** と **スキル `agrr-crop-setup` の手順 5** は書き込み(apply)を前提にする(§2.8)。決定後は、API キー(新規・再発行)では常に 403 になる。dry_run と参照(`GET`)は動く。
- **`docs/api/getting-started.md` §5** と **`docs/api/builtin-generation-sunset.md`** の apply・書き込み例も API キーでは失敗する(§2.5)。sunset ガイドの代替表(`:9-13`)・肥料/害虫の案内(`:61`)も同様。
- MCP クライアントは 403 の `error_code` をメッセージに含めない(`agrr-client.mjs:88-92`)ため、利用者は原因が分かりにくい。ただし §5.3 の M-A(ツール削除)を採用すれば、この経路自体が無くなる。
- 外部スキルがどれだけ実在し、どのキー世代を使っているかは**未確認**。リポジトリ内に把握できる情報はない。

### 4.2 既存キー

- V15 以前に発行された平文キー: read+write(§2.1)。ハッシュ移行後も維持(§2.3)。決定(書き込みを与えない)とは食い違う。第2回決定で、V27 により `["masters:read"]` へ移行する(§5.4.1)。移行後、これらのキーで書き込み・apply をしていた外部連携は 403 になる(§5.4.1.8)。
- V15 以降に発行・再発行されたキー: read のみ(§2.3)。
- 再生成すると、以前 read+write だったキーは read のみに降格する(§2.3)。UI は警告しない(§2.6)。決定により、これは意図した仕様とみなす(Q2)。
- スコープが NULL のキー: 実装上は全 403(§2.4)。存在の有無は**未確認**(Q3)。V15 の `UPDATE` は「API キーがあり、スコープが NULL/空」の行を対象にするので、V15 適用済みかつ V15 以降に `api_key` が NULL のまま作られた行だけがこの状態になり得るが、現行の書き込み経路(§2.3)は必ずスコープを設定するため、通常は発生しない。

### 4.3 社内(リポジトリ)への影響

- `frontend` の API キー画面の文言(`ja.json:3810,3839`、`en.json:3774`、`in.json:3480` ほか)は、書き込みが可能であるかのような表現になっている(§2.6)。
- 課題 04(クエリ認証)・07(フロントエンドのエラー契約)・08(OpenAPI の不足)・09(古い設計文書)と対象ファイルが重なる(§10)。

---

## 5. 対応方針

原則: 文書修正(§5.1、§5.2)は単独の PR にする。コード変更(§5.3 の MCP、§5.4 の V27、§5.6 のフロント文言)は、文書修正の PR には含めず、TDD で別に行う。付与手段の設計は**行わない**(§0)。ただし、「API キーは読み取り専用」と断定する文書は、V27 のデプロイ完了後に公開する(V27 の適用前は旧キーが書き込めるため。§5.4.1.9)。

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

**API キーは読み取り専用です。書き込みはログインセッション（ブラウザ／画面）経由のみ可能です。**

API キーごとにスコープを保存し、Masters API（`/api/v1/masters/*`）で強制します。API キーが持つスコープは `masters:read` だけです。

| 操作 | API キー（`masters:read`） | ログインセッション |
|------|---------------------------|--------------------|
| `GET` / `HEAD`（一覧・詳細） | 可 | 可 |
| `setup_proposal?mode=dry_run`（検証のみ） | 可 | 可 |
| `POST` / `PUT` / `PATCH` / `DELETE`（作成・更新・削除） | 不可（HTTP 403） | 可 |
| `setup_proposal?mode=apply`（永続化） | 不可（HTTP 403） | 可 |

- 生成・再生成したキーは **常に `masters:read` のみ**です。
- API キーに書き込みスコープ（`masters:write`）を付与することはできません。付与する画面・API・申請手続きも提供しません。
- 書き込み（`setup_proposal?mode=apply` を含む）は、ログイン後の画面で行ってください。作物の提案 JSON は、作物の詳細・編集画面の **提案 JSON をインポート** から適用できます。
- 再発行（**APIキーを再生成**）すると、スコープは `masters:read` になります。

書き込み系のリクエストを API キーで送ったときのレスポンス:

```json
{ "error": "forbidden", "error_code": "insufficient_scope" }
```
```

注(既存キーの 1 文):

- 第2回決定で移行を**する**(X2)ため、After に「過去に発行されたキーには書き込み権限が残る場合がある」旨の 1 文は**書かない**。
- 代わりに、V27 で移行した事実を利用者に伝える場合は、After の最後の箇条書きの次に「スコープ導入前(V15 以前)に発行されたキーも、`masters:read` のみに揃えました。書き込みはログインセッション経由で行ってください」を追加する(告知の要否は Q8)。
- この文書修正は、V27 のデプロイ完了後に公開する(§5.4.1.9)。

他の変更(同じファイル):

- §2 の冒頭(`:24`)に「API キーは読み取り専用です(§3)」を追記する。
- 課題 04 が §2 の「クエリ（非推奨）」行(`:30`)を消す。§2 は 04、§3・§5 は本課題が編集する(§10)。

#### 5.1.2 `docs/api/getting-started.md` §5(`:60-67`、`:79-87`)

API キーで apply はできないため、apply を API キーの手順から外す。

Before(`:60-67`):

```markdown
## 5. 典型的なフロー（setup_proposal）

外部スキルが作物マスタを提案するときの推奨手順:

1. `GET /api/v1/masters/crops` で対象作物 ID を確認
2. `POST /api/v1/masters/crops/{crop_id}/setup_proposal?mode=dry_run` で提案 JSON を検証
3. `valid: true` なら `mode=apply` で永続化
4. 必要に応じて `GET .../crop_stages` や `.../task_schedule_blueprints` で結果を確認
```

After:

```markdown
## 5. 典型的なフロー（setup_proposal）

外部スキルが作物マスタを提案するときの推奨手順（API キーは読み取り専用のため、適用はログイン後の画面で行います）:

1. `GET /api/v1/masters/crops` で対象作物 ID を確認（API キー）
2. `POST /api/v1/masters/crops/{crop_id}/setup_proposal?mode=dry_run` で提案 JSON を検証（API キー）
3. `valid: true` なら、`normalized` の JSON を利用者に渡し、画面の **提案 JSON をインポート**（`/crops/{crop_id}/setup_proposal`）で適用（ログインセッション）
4. 適用後、必要に応じて `GET .../crop_stages` や `.../task_schedule_blueprints` で結果を確認（API キー）
```

`### apply 例`(`:79-87`)は**削除**する。API キーで 403 になる例を残すと誤用を誘う。セッション Cookie を使うサーバー間の apply は、OpenAPI が「UI only; not for server-to-server skills」としている(`openapi.yaml:403`)ので、代替例も載せない。

§4 のレート制限表の apply 行(`:52`)は、セッションでの apply に対する制限として残す。説明に「(セッションのみ)」を追記する。

#### 5.1.3 `docs/api/builtin-generation-sunset.md`

- 代替表(`:9-13`)の `POST` / `PATCH /api/v1/masters/...` は、API キーでは使えない旨を表の直後に 1 行追記する(「Masters の書き込みはログインセッション(画面)経由。API キーは読み取り専用: [getting-started.md §3](../api/getting-started.md)」)。
- 「### 2. `setup_proposal` で検証・投入」(`:36-49`)は、見出しを「検証(API キー)」と「投入(画面)」に分けるか、`apply` の箇条書き(`:47`)に「API キーでは実行できない。画面から」と追記する。
- 「### 3. UI からインポート」(`:51-53`)を、**apply の唯一の経路**として位置づける文に直す。
- 「肥料・害虫マスタ」(`:61`)の「外部スクリプトで `POST` / `PATCH` を呼び出してください」を、「画面(Masters CRUD)で登録してください。API キーは読み取り専用のため、外部スクリプトから書き込むことはできません」に直す。

#### 5.1.4 `docs/api/setup_proposal-openapi-snippet.yaml`

この snippet はレガシーで本体は `openapi.yaml`(`getting-started.md:92`)。ここには `403`(`insufficient_scope`)の応答と、apply は API キーでは 403 になる旨を 1 行ずつ追加する。ただし snippet を残すか廃止するかは課題 08 と重なるため、08 の方針が決まっていればそれに従う。

#### 5.1.5 `tools/agrr-mcp/README.md` と `.cursor/skills/agrr-crop-setup/SKILL.md`

MCP のコード削除(M-A 確定)と一体で行う。Before/After と行番号つきの一覧は §5.3.2、§5.3.5、§5.3.6 にある。趣旨は次のとおり。

- README の Prerequisites(`README.md:8`): 「AGRR API key with Masters access」を「AGRR API key(read-only)」に直し、「API キーは読み取り専用。書き込み(apply)は UI で行う」を追記する。
- README の Tools 表(`README.md:54`)の `apply_crop_setup` 行と、Apply idempotency 節(`README.md:82-84`)は削除する。
- SKILL.md の前提(`:17-18`)に「API キーは読み取り専用。apply は UI で行う」を追記する。手順 5(`:36`)は §5.3.2 のとおり書き換える。

### 5.2 `openapi.yaml` の扱い(推奨案)

前提: `masters:write` は API キーに付与されない(§0)。ただし実装は、スコープ判定で `masters:write` を今も解釈する(§2.2)ため、OpenAPI の説明から `masters:write` を消すのではなく、「予約・付与しない」と明記する。

#### 5.2.1 冒頭 description(`openapi.yaml:9-13`)

Before:

```yaml
    **Scopes (enforced per API key):**
    - `masters:read` — `GET` / `HEAD` on Masters endpoints, and `setup_proposal?mode=dry_run`
    - `masters:write` — create, update, delete, `setup_proposal?mode=apply`

    Session cookie authentication has full Masters access. API keys default to `masters:read` only on generate/regenerate.
```

After(案):

```yaml
    **API keys are read-only.** Every generated or regenerated key has the `masters:read` scope only.
    `masters:write` is never granted to API keys.

    - `masters:read` — `GET` / `HEAD` on Masters endpoints, and `setup_proposal?mode=dry_run`
    - Writes (`POST` / `PUT` / `PATCH` / `DELETE`, and `setup_proposal?mode=apply`) are available only with a
      logged-in browser session. An API key used for a write returns `403` with `error_code: insufficient_scope`.
```

#### 5.2.2 `securitySchemes`(`openapi.yaml:386-403`)

- `bearerApiKey` の description(`:391-392`)を「User API key as Bearer token. Read-only (`masters:read`).」に直す。
- `headerApiKey`(`:398`)は「Same as bearerApiKey (read-only).」に直す。
- `sessionCookie` の description(`:403`)は「Browser session (UI only; not for server-to-server skills)」のままとし、「Required for all write operations.」を追記する。

#### 5.2.3 各 write operation(推奨: `security` の上書き + 403 の明記)

選択肢は次の 3 つ。

| 案 | 内容 | 長所 | 短所 |
|----|------|------|------|
| **A(注記のみ)** | `security` はグローバルのまま(`bearerApiKey` / `headerApiKey`)。write operation の description に「API キーでは 403」と注記し、`responses` に `403` を追加する | 変更が最小。課題 08 D-03(全 operation に 403)と自然に合う | OpenAPI 上は API キーで write が呼べるように見える。仕様から生成したクライアント/LLM が誤用しやすい |
| **B(`security` の上書き)** | write operation(`post` / `patch` / `delete` の 12 件)に `security: [{ sessionCookie: [] }]` を付ける。read operation はグローバルのまま。`setup_proposal` は A(下記) | 仕様が実装と機械的に一致する。「API キーで書き込めない」が構造で読める | `sessionCookie` は「UI only」の説明と、公開 OpenAPI の読者(外部スキル作者)の関心とのずれが出る。グローバル `security` に `sessionCookie` が無い点(課題 08 D-09)も同時に整理する必要がある |
| **C(write operation を公開 OpenAPI から外す)** | 公開仕様を「API キーで使える範囲」(read と dry_run)だけにする | 公開仕様が API キーの実態と一致する。外部スキルの誤用を防げる | 課題 08 の subset 基準(D-10)と衝突する。UI が使う API の契約文書が消える。`llms.txt:10` が OpenAPI を全体契約のように記載している |

**推奨: B**。理由は次のとおり。

- 仕様と実装が機械的に一致する(Q7)。
- `setup_proposal` は 1 つの operation で `dry_run` と `apply` を `mode` クエリで切り替える(`openapi.yaml:344-353`)。OpenAPI 3.0.3 は `mode` の値ごとに `security` を変えられない。このため `setup_proposal` だけは `security` をグローバル(API キー可)のままにし、description と `responses` の `403` で「`mode=apply` は API キーでは 403」と明記する(案 A と同じ扱い)。
- 12 件の write operation に `403` を追加する作業は、課題 08 D-03 の適用ルール(20 operation すべてに `403`)と同じ箇所に手が入る。08 が先に入るならその後で `security` を追加する。順序は §10。

#### 5.2.4 `403` の応答定義

課題 08 D-03 が定義する `Forbidden` 応答(`insufficient_scope`)を使う。読み取り operation で API キーが 403 になるのは、スコープが NULL/空のキーだけ(§2.4)なので、read operation への `403` の追加は 08 の判断に従う(本書では要求しない)。

#### 5.2.5 `masters:write` の定数と説明の扱い

`openapi.yaml` に `masters:write` を残す場合は「予約。API キーには付与されない」と書く。`x-` 拡張などでスコープ一覧を機械可読にする必要は無い(OpenAPI の `securitySchemes` に `oauth2` 型を使っていないため)。

### 5.3 公式 MCP `apply_crop_setup` の削除(M-A 確定)とスキル `agrr-crop-setup` の書き換え

問題: MCP は Bearer のみを送る(§2.8)。決定後、`apply_crop_setup` は API キー主体で `mode=apply` を呼ぶので**常に 403** になる。スキルの手順 5 も同様。dry_run と参照系は動く。

#### 5.3.1 採用した案と不採用の案

| 案 | 内容 | 判断 |
|----|------|------|
| **M-A: ツールを削除し、apply を UI に誘導する** | MCP から `apply_crop_setup` を削除する。README・テスト・スキルを合わせる(§5.3.5〜§5.3.6) | **採用(第2回決定)**。常に失敗するツールを LLM に公開しない。`project-necessary-code-only.mdc` に沿う |
| M-B: ツールを残し、文書と 403 のメッセージで対処する | ツールは残し、`description` に「API キーでは常に 403」と書く。`agrr-client.mjs:88-92` で `error_code` を例外メッセージに含める | 不採用。常に失敗するツールが残り、LLM が呼ぶたびに 403 の往復が発生する |

M-B を採らないため、403 の `error_code` を MCP の例外メッセージに含める改善(旧 §5.3.3)は**不要**である。参照系ツール(`list_reference_crops`、`get_crop_detail`、`propose_crop_setup`)が 403 になるのは、スコープが NULL/空のキーだけ(§2.4)で、通常は発生しない。汎用のエラー契約は課題 07 の領分とする。

#### 5.3.2 スキルの手順 5 の書き換え(Before / After)

対象: `.cursor/skills/agrr-crop-setup/SKILL.md`(全 48 行を読んで確認した行番号)。

Before(`SKILL.md:3-5`、フロントマターの description):

```yaml
description: >-
  External skill sample for crop master setup via official AGRR MCP tools.
  Reference crop lookup → LLM proposal → dry_run validation → user confirm → apply.
```

After(案):

```yaml
description: >-
  External skill sample for crop master setup via official AGRR MCP tools.
  Reference crop lookup → LLM proposal → dry_run validation → user confirm → hand-off JSON
  (apply is done in the AGRR UI; API keys are read-only).
```

Before(`SKILL.md:13`):

```markdown
作物マスタ（生育ステージ・作業・作業スケジュール青写真）を **公式 MCP** 経由で `setup_proposal` に投入する手順。
```

After(案):

```markdown
作物マスタ（生育ステージ・作業・作業スケジュール青写真）の提案 JSON を **公式 MCP** 経由で組み立て・検証（dry_run）し、**適用は AGRR の画面で行う**手順。
```

前提(`SKILL.md:17-18`)の直後に 1 行追加(案):

```markdown
- API キーは**読み取り専用**。MCP から作物マスタへ書き込む（apply）ことはできない。適用はログイン後の画面で行う
```

Before(`SKILL.md:35-36`):

```markdown
4. **ユーザー確認** — `normalized` の内容を提示し、適用の明示的な承認を得る
5. **apply** — MCP `apply_crop_setup`（同一 `proposal`）。成功後 `result.stage_ids` / `blueprint_ids` を報告
```

After(案):

```markdown
4. **ユーザー確認** — `normalized` の内容を提示し、画面で適用してよいか確認を得る
5. **画面で適用** — MCP では適用できない（API キーは読み取り専用）。検証済みの `proposal` の JSON をユーザーに渡し、AGRR にログインして作物の詳細・編集画面の **提案 JSON をインポート**（`/crops/{crop_id}/setup_proposal`）から適用してもらう
```

UI 側の根拠: ルート `crops/:id/setup_proposal` は `frontend/src/app/routes/masters.routes.ts:49`。インポート画面が JSON の貼り付けから `dry_run` → `apply` を呼ぶ(`crop-setup-proposal-import.component.ts` の `jsonInput` と `applyProposal()`(`:439`)、`crop-setup-proposal-api.gateway.ts:12-25`)ことは読んで確認した。画面操作での適用は**実行していない**。API 側は、セッションの apply が 201 になる R4 の既存テスト(`contracts.rs:2715` 付近)で確認できる。

#### 5.3.3 スキルの「参照」と「禁止」

- `SKILL.md:38-43` の「禁止」は変更しない(`ai_create`、`regenerate` などの禁止は apply の有無に関係しない)。
- `SKILL.md:47` の ADR-001 参照は残す。ADR-001 が外部スキルによる apply を前提にしている点の追記は課題 09(§5.3.4)。

#### 5.3.4 ADR-001

ADR-001 は外部スキルによる apply を含む前提で書かれている(§2.8)。§0 の決定と食い違うため、ADR-001 への追記(または新 ADR)が要る。これは課題 09(古い設計文書)の領分とし、本書では差分案を示さない(§10)。

#### 5.3.5 削除対象の一覧(`tools/agrr-mcp/`、現行の行番号)

`rg -n --hidden -g '!.git' -g '!**/node_modules/**' "apply_crop_setup|applyCropSetup"` を、`docs/spec-defects/` を除くリポジトリ全体に対して実行した結果は、下表の `tools/agrr-mcp/` 配下の行と、スキル `.cursor/skills/agrr-crop-setup/SKILL.md:36`(§5.3.2)だけである(14 行)。

| 区分 | ファイル:行 | 内容 | 操作 |
|------|-------------|------|------|
| ツール定義 | `tools/agrr-mcp/src/tools.mjs:58-73` | `apply_crop_setup` の `description` / `inputSchema` / `handler` | 削除 |
| 登録箇所(ツール名の配列) | `tools/agrr-mcp/src/tools.mjs:81` | `AGRR_MCP_TOOL_NAMES`(`:77-82`)内の `'apply_crop_setup'` | 削除 |
| 登録箇所(サーバー側) | `tools/agrr-mcp/src/server.mjs:15-20` | `createAgrrMcpToolHandlers` の戻り値を列挙して `registerTool` する | **変更なし**(ツール名の直書きが無い)。ただしバージョン `:11` は Q9 |
| 共有スキーマ | `tools/agrr-mcp/src/tools.mjs:3-7` | `cropSetupProposalSchema` | **残す**(`propose_crop_setup` が使う: `:47`) |
| クライアント | `tools/agrr-mcp/src/agrr-client.mjs:53-60` | `applyCropSetup`(JSDoc `:53`、本体 `:54-60`)。直後の空行 `:61` も削除 | 削除 |
| テスト(クライアント) | `tools/agrr-mcp/test/agrr-client.test.mjs:95-120` | `applyCropSetup posts apply mode` | 削除(直後の空行 `:121` も) |
| テスト(モック) | `tools/agrr-mcp/test/server-tools.test.mjs:23-30` | モッククライアントの `applyCropSetup` | 削除 |
| テスト(ツール数) | `tools/agrr-mcp/test/server-tools.test.mjs:34` | テスト名「expose four crop setup tools」 | 「three」に変更し、期待値をリテラルにする(§6.6) |
| テスト(委譲) | `tools/agrr-mcp/test/server-tools.test.mjs:63-69` | `apply_crop_setup delegates apply to client` | 削除(直前の空行 `:62` も) |
| README(前提) | `tools/agrr-mcp/README.md:8` | 「AGRR API key with Masters access」 | 「AGRR API key (read-only)」に変更(§5.1.5) |
| README(ツール表) | `tools/agrr-mcp/README.md:54` | `apply_crop_setup` の行 | 削除 |
| README(節) | `tools/agrr-mcp/README.md:82-84` | 「Apply idempotency」の節(見出し `:82`、本文 `:84`) | 削除。代わりに「Apply is not available via MCP: API keys are read-only. Apply in the AGRR UI (Import proposal JSON on the crop page).」を 1 段落で残す(旧 `:56` の Request/response schema の直前に置くか、Tools 表の直後) |
| README(冒頭) | `tools/agrr-mcp/README.md:3` | 「Official thin MCP wrapper for AGRR Masters crop `setup_proposal` API」 | 変更なし(dry_run は残る) |
| ドキュメント上のツール一覧 | 上記 README の表(`:49-54`)のみ | 他のドキュメントに 4 ツールの一覧は無い(`rg "list_reference_crops|propose_crop_setup|get_crop_detail" -g '*.md'` の該当は README と `docs/spec-defects/` のみ。隠しディレクトリの `.cursor/skills/agrr-crop-setup/SKILL.md:32-34` は手順の中で個別のツールに言及するが、一覧ではなく、`apply_crop_setup` を含むのは `:36` だけ) | — |
| CI | `.github/workflows/frontend-test.yml:131-133` | `npm test` の実行のみ | 変更なし |
| バージョン | `tools/agrr-mcp/package.json:3`、`package-lock.json:3,9`、`src/server.mjs:11` | `0.1.0` | Q9(推奨は `0.2.0`) |

リポジトリ内に MCP 設定ファイル(`.cursor/mcp.json`)は無い(`ls .cursor/mcp.json` がエラー)。README `:30-45` が設定例を示すだけ。

#### 5.3.6 docs 内の言及の修正一覧

`rg -n "tools/agrr-mcp|agrr-mcp|agrr-crop-setup"` の結果(`docs/spec-defects/` と `tools/agrr-mcp/` を除く)を読んで分類した。

| ファイル:行 | 現状 | 修正 |
|-------------|------|------|
| `docs/api/getting-started.md:3` | 「MCP サーバー実装例は README を参照」 | 変更なし(MCP は参照・dry_run に使える)。任意で「(参照と dry_run のみ。適用は画面)」を追記 |
| `docs/api/getting-started.md:66` | 「`valid: true` なら `mode=apply` で永続化」 | §5.1.2 の After(画面で適用) |
| `docs/api/getting-started.md:79-87` | 「apply 例」の curl(API キー) | 削除(§5.1.2) |
| `docs/api/getting-started.md:93` | agrr-mcp へのリンク | 変更なし |
| `docs/api/builtin-generation-sunset.md:9`, `:14` | 代替表(作物作成の `POST`、blueprints regenerate の代替が `setup_proposal`) | §5.1.3(API キーでは使えない旨を 1 行) |
| `docs/api/builtin-generation-sunset.md:31-34` | 「外部スキル / MCP で提案 JSON を生成」(公式 MCP とスキル例へのリンク) | 「提案 JSON の生成と dry_run による検証まで。適用は画面(下の 3)」と 1 文追記 |
| `docs/api/builtin-generation-sunset.md:36-49` | 「`setup_proposal` で検証・投入」。`apply` の箇条書き(`:47`)は API キーの例の直後 | §5.1.3(見出しを分けるか、`apply` に「API キーでは実行できない。画面から」を追記) |
| `docs/api/builtin-generation-sunset.md:51-53` | 「UI からインポート」 | apply の**唯一の経路**として位置づける文に直す(§5.1.3) |
| `docs/api/builtin-generation-sunset.md:57` | 「既存の青写真は `apply` 時に置き換えられます」 | 「画面から適用するときに置き換えられます」に直す |
| `docs/api/builtin-generation-sunset.md:61` | 「外部スクリプトで `POST` / `PATCH` を呼び出してください」 | §5.1.3 のとおり |
| `crates/agrr-server/src/builtin_generation_deprecation.rs:33` | 廃止予定エンドポイントの応答に含める `alternative` に `setup_proposal?mode=dry_run\|apply` と `tools/agrr-mcp/` | Q10(推奨: 直さない) |
| `tools/agrr-repo-mcp/README.md:61` | 「`tools/agrr-mcp/` — crop setup API MCP (HTTP wrapper)」 | 変更なし |
| `docs/adr/ADR-001-...md:35-46,103` | 外部スキルが apply まで行う前提 | 課題 09(§5.3.4) |
| `docs/spec-defects/07`、`08` | `agrr-client.mjs:23, 41, 48, 57`、`agrr-client.mjs:87-95`、`README.md:51-54`、`README.md:56`、`agrr-client.test.mjs:122-126` などの参照 | 削除後に行がずれる(`agrr-client.mjs` の `#request` 以降は約 9 行、`agrr-client.test.mjs:122` は約 27 行上へ)。**実装時に**07・08(と本書 §2.8)の `file:line` を更新する。08 の「MCP が呼ぶのは 4 本」(`08-openapi-gaps.md:155`)は 3 本に、`agrr-client.mjs:57`(apply の URL)は削除される |

`llms.txt` に MCP の言及は無い(`grep -n "mcp" llms.txt` が 0 件)。`docs/api/openapi.yaml` と `setup_proposal-openapi-snippet.yaml` に MCP の言及は無い(§5.1.4 のスコープの修正のみ)。

#### 5.3.7 MCP のバージョンと互換性(削除は破壊的変更か)

- **破壊的変更である**。MCP のツール一覧が公開インターフェースで、`apply_crop_setup` を呼ぶクライアントは、削除後にツールが存在しない旨のエラーを受ける(MCP SDK が返す具体的なエラー形式は**未確認**。`@modelcontextprotocol/sdk` 1.26.0 のソースは手元に無い)。
- ただし、影響を受ける利用者は限られる。新規・再発行のキーは read のみで、`apply_crop_setup` は**書き込み権限が残る V15 以前のキーでしか成功しない**(§2.3、§2.8)。この集合は X2 の移行対象(§5.4.1)と同じで、移行後は全員が 403 になる。削除は、その「常に失敗するツール」を消す。
- 配布形態: `package.json` は `private: true`、`bin` は `./src/index.mjs`(`package.json:4,7-9`)、README の設定例はリポジトリ内のパスを指す(`README.md:37`)。npm には公開されない。バージョンを固定する仕組みはなく、リポジトリを更新した利用者に変更が届く。CHANGELOG はなく、タグも無い(`git tag` が空)。したがって周知の手段は README と PR の説明になる。
- バージョン: 現行は `0.1.0`(`package.json:3`)。0.x の破壊的変更なので、マイナーを上げて **`0.2.0`** にする案(Q9)。書き換え箇所は `package.json:3`、`package-lock.json:3,9`、`src/server.mjs:11`(MCP のハンドシェイクでクライアントに伝わる値)の 4 か所。
- **順序の注意**: MCP のツールを削除しても、旧キー(read+write)を持つ利用者は HTTP で直接 `mode=apply` を呼べる。これを閉じるのは V27(§5.4.1)であり、MCP の削除ではない。両方を同じリリースの窓で行い、文書・周知を揃える。
- 残るツールは 3 つ(`list_reference_crops`、`get_crop_detail`、`propose_crop_setup`)。いずれも `masters:read` で動く(`GET` と `mode=dry_run`: §2.2)。

### 5.4 実装コード変更の要否と、既存キーの移行(X2 確定)

結論: **新規・再発行キーは既に read のみなので、決定を満たすための必須のコード変更は無い**(§2.3、§2.7)。ただし第2回決定により、V15 以前の既存キーの read+write は**データ移行(V27)で read のみへ揃える**(§5.4.1)。DB のスコープ列と定数は残す(§5.4.2)。

#### 5.4.1 V15 以前の既存キーの移行(X2 採用確定)

対象: V15 適用時に平文 `api_key` を持っていたユーザー(§2.1)のうち、その後に再生成していないキー。本番の件数は未確認(Q3)。

**採用しなかった案(第2回決定)**

| 案 | 内容 | 不採用の理由 |
|----|------|--------------|
| X1: 移行しない | 何もしない。再生成で read のみになる(§2.3) | 決定「移行する」に反する。旧キーは書き込み可能なまま無期限に残る |
| X3: コードで API キーの Write を常に拒否する | `masters_api_scope_allows`(`masters_api_scope.rs:38-45`)を変える。DB は触らない | 決定「移行する」はデータ移行を指す。X3 は保存されたスコープ列の意味を無効にし、既存テスト `masters_api_key_write_scope_allows_post`(`contracts.rs:3048-3067`)と `masters_api_scope.rs:110-115` を反転する必要がある |

##### 5.4.1.1 移行対象の判定

- 条件: **`users.api_key_scopes` が二重引用符付きの `"masters:write"` を含む行**(`LIKE '%"masters:write"%'`)。根拠は §2.10。
  - 書き込みスコープを持つ行を作る本番経路は V15 だけで、値は `["masters:read","masters:write"]` の 1 通り(`V15__api_key_scopes.sql:5`)。新規・再発行キーの値は `["masters:read"]` で、この条件に**一致しない**(§2.10)。
  - キーの発行日時を持つ列は無く(§2.10)、`updated_at` は再生成・ハッシュ移行で更新されるため、日時による判定は使えない。
  - 「新規発行の read のみキーと区別が付かない場合」は生じない。付かない場合の扱い(どちらを対象にするか)を決める必要は無い。
- キーの有無(`api_key` / `api_key_hash`)は条件に入れない。キーが無い行にスコープだけが残っていても、更新して害は無く、条件が単純になる。
- 更新後の値: `["masters:read"]`(`default_api_key_scopes_json()` と同一: `masters_api_scope.rs:48-50`)。`["masters:write"]` 単独の行(read が無い)も `["masters:read"]` に揃える。
- 対象外: NULL・空・不正 JSON のスコープ(元々 fail-closed で全 403: §2.4)、`["masters:read"]` の行。`updated_at` は更新しない(スコープ変更はキーの再発行ではなく、V15 の `UPDATE` も更新していない)。

##### 5.4.1.2 migration の置き場と形式

- 置き場: `crates/agrr-migrate/migrations/schema/` の **V27**(`data/` ではない。理由は §2.10 の表)。ファイル名は既存の慣例(`V<n>__<snake_case>.sql`)に沿って `V27__revoke_api_key_write_scope.sql`(名前は案)。
- 形式: SQL 1 文(案)。コメントは V15 と同様に意図だけを書く。

```sql
-- API keys are read-only: align keys issued before scope enforcement (V15 granted read+write).
UPDATE "users"
SET "api_key_scopes" = '["masters:read"]'
WHERE "api_key_scopes" LIKE '%"masters:write"%';
```

- 冪等性: refinery が V27 を 1 回だけ適用する。SQL も、対象が無くなれば 0 行更新になり、再実行しても結果は変わらない(§2.10)。`sqlite3` 3.45.1 の作業用 DB(`users` の簡易テーブルにダミー行を入れたもの)で、同じ `UPDATE` を 2 回流して、1 回目の `changes()` が対象行数、2 回目が 0 になることを確認した(リポジトリ外の一時ファイル。確認後に削除)。
- V15 は**書き換えない**(§2.10)。
- 影響が及ぶ別経路: `run-rust-contract-tests.sh` は、埋め込み SQL が新しいとき `agrr-migrate` を再ビルドし(`:128-133`)、`schema run` を実行する(`:252-253`)。R4 のテストは `set_user_api_key_scopes` でスコープを設定してから使うので(`support.rs:123-131`)、V27 で結果が変わる既存テストは、コードを読んだ範囲では無い(R4 全体の実行は未実施)。E2E・Lighthouse のワークフローは migration の SQL のハッシュをキャッシュキーにしている(`frontend-e2e-smoke.yml:55` ほか)ため、キャッシュが更新されるだけである。
- `crates/agrr-migrate/**` の変更なので、Docker 検証の前に `.cursor/skills/dev-docker/scripts/rebuild-restart.sh` が要る(migration の結果が API の挙動を変えるため。`docker-dev-agrr-server-rebuild.mdc` は `crates/agrr-server/**` などを列挙し、「API 形に影響する migration」も対象としている)。

##### 5.4.1.3 ロールバック方針

- スキーマは forward-only(`P7-MIGRATION-RUNBOOK.md` の「Schema rollback」)。コードの差し戻し(V27 ファイルの revert)では、**適用済みのデータは元に戻らない**。
- Litestream の復元による巻き戻しは採らない。保持期間は 24 時間(`config/litestream.yml`)で、巻き戻すとその時点以降の**すべての書き込み**が失われる(§2.10)。スコープ 1 列の修正に対して釣り合わない。
- 採る方針: **適用前に、対象行の `id` と `api_key_scopes` だけを退避**する(§5.4.1.5 の確認 5)。メール・キーのハッシュ・プレフィックスは退避しない。退避先はリポジトリ外(本番のユーザー ID の一覧をコミットしない)。
- 戻す条件: V27 が**意図しない行を更新した**場合だけ。利用者から「書き込みを戻してほしい」と要望されても、決定(書き込みを与えない)に反するため、戻すかはユーザー判断とし、既定では戻さない。
- 戻す手順は §5.4.1.7。V27 は `refinery_schema_history` に適用済みとして残るため、逆 `UPDATE` の後に再起動しても**再適用されない**。

##### 5.4.1.4 実施前の確認手順と `production-primary-sqlite-query` スキルの利用可否

- スキル: `.cursor/skills/production-primary-sqlite-query/SKILL.md`。GCS の Litestream レプリカを一時ディレクトリへ復元し(`scripts/query_production_primary_sqlite.sh:54-80`)、`sqlite3` で SQL を実行する(`:88-92`)。実行対象は**復元したコピー**で、本番の稼働中の DB ではない。スキルの規約は読み取り専用(「書き込み・本番データの変更は行わない」)。
- 前提: ADC(`gcloud auth application-default login`)、`gsutil ls gs://agrr-production-db/...` が通ること、`curl`・`sqlite3`・`dpkg-deb`。**この計画の作業では実行していない**。GCP の認証情報がこの環境にあるかは**未確認**。
- 制約: レプリカは本番より遅れる可能性がある(`config/litestream.yml` の `sync-interval: 10s`)。件数確認の直後に別のキーが再生成される可能性は残るが、V27 の条件は適用時点のデータに対して評価されるため、確認は目安である。
- 手順:
  1. ユーザーが件数確認の実行を承認する(Q3)。本番の GCS を読むため、承認なしに実行しない。
  2. §5.4.1.5 の確認 1〜4(件数と分布のみ。個人情報を出力しない)を、スキルのスクリプトに SQL を渡して実行する。
  3. 結果をユーザーに提示する。確認 3(異常値)が 1 件でもあれば、V27 の条件を見直してから進める。
  4. Q5 でユーザーが V27 を含むリリースのデプロイを承認する。承認後に、確認 5(退避)を実行する。
- スキルが使えない場合(認証情報が無い等): 件数が分からないまま実施するか、ユーザーが認証情報を用意するまで保留するかを、Q5 の承認時にユーザーが明示的に決める。

##### 5.4.1.5 本番適用前の件数確認 SQL(読み取り専用)

以下は、V1 + V15 + V25 を適用した `sqlite3` の作業用 DB(ダミー行入り)で実行して、構文と出力を確認した。本番では未実行。すべて `SELECT` のみで、メール・キーのハッシュ・プレフィックスを出力しない。

確認 1: スコープの値とキーの状態の分布

```sql
SELECT
  COALESCE(api_key_scopes, '(NULL)') AS scopes,
  CASE
    WHEN api_key_hash IS NOT NULL AND TRIM(api_key_hash) != '' THEN 'hash'
    WHEN api_key IS NOT NULL AND TRIM(api_key) != '' THEN 'plaintext'
    ELSE 'no_key'
  END AS key_state,
  COUNT(*) AS n
FROM users
GROUP BY 1, 2
ORDER BY n DESC;
```

確認 2: V27 の更新対象の件数(V27 の `WHERE` と同一の条件)

```sql
SELECT COUNT(*) AS migration_targets
FROM users
WHERE api_key_scopes LIKE '%"masters:write"%';
```

確認 3: 想定外のスコープ値(V15 の値・既定値以外)。0 行が期待値

```sql
SELECT api_key_scopes, COUNT(*) AS n
FROM users
WHERE api_key_scopes IS NOT NULL
  AND TRIM(api_key_scopes) != ''
  AND api_key_scopes NOT IN ('["masters:read"]', '["masters:read","masters:write"]')
GROUP BY 1;
```

確認 4: 対象のうち、現に有効なキー(ハッシュまたは平文)を持つ行の件数

```sql
SELECT COUNT(*) AS targets_with_key
FROM users
WHERE api_key_scopes LIKE '%"masters:write"%'
  AND ((api_key_hash IS NOT NULL AND TRIM(api_key_hash) != '')
    OR (api_key IS NOT NULL AND TRIM(api_key) != ''));
```

確認 5: 退避用(承認後のみ。`id` とスコープ文字列だけ)

```sql
SELECT id, api_key_scopes
FROM users
WHERE api_key_scopes LIKE '%"masters:write"%'
ORDER BY id;
```

実行例(リポジトリのルートから): `./.cursor/skills/production-primary-sqlite-query/scripts/query_production_primary_sqlite.sh "<SQL>"`

中止・見直しの条件(案): 確認 3 が 1 行以上、または確認 2 と確認 4 の差が想定外に大きい(スコープだけ残ってキーが無い行が多い)場合は、原因を調べてから進める。対象 0 件でも V27 は追加する(Q3)。

##### 5.4.1.6 適用後の確認

- V27 のデプロイ後、レプリカの同期を待って(`sync-interval: 10s`)、確認 2 が 0、`SELECT COUNT(*) FROM refinery_schema_history WHERE version = 27;` が 1 になることを確認する(いずれも同スキル)。
- 起動ログの「Schema migrated successfully」(`db_bootstrap_common.sh:200-202`)だけを根拠にしない。migration はバックグラウンドで走り、失敗してもサーバーは起動し続けるため(§2.10)。

##### 5.4.1.7 ロールバックの実行(意図しない更新があった場合のみ)

- 退避した `id` と元のスコープ文字列から、`UPDATE "users" SET "api_key_scopes" = '<元の値>' WHERE "id" = <id>;` を生成する。
- 本番への書き込みは、既存の前例(`scripts/production-data-migrate-inner.sh:14-34` を `.cursor/skills/deploy-server/scripts/run-production-data-migrate.sh` が起動する Cloud Run 上の 1 回限りの実行)を流用する形になる。これらのスクリプトは今回の用途に合わせた変更が要る。**別途、ユーザーの承認を得てから**実施する(本計画では設計しない)。

##### 5.4.1.8 ユーザー影響と通知

- 影響を受けるのは、V15 以前に発行され、再生成していないキーの所有者。件数は未確認(Q3)。利用実態(書き込みに使っているか)はアプリの DB・ログから判別できない(§2.10)。
- V27 適用後、そのキーでの `POST` / `PUT` / `PATCH` / `DELETE`(`/api/v1/masters/*`)と `setup_proposal?mode=apply` は **HTTP 403** `{"error":"forbidden","error_code":"insufficient_scope"}` になる(`masters_auth.rs:95-100,123-127`)。`GET` / `HEAD` と `mode=dry_run` は変わらない。ログインセッションによる操作(画面)は影響を受けない(`masters_auth.rs:115-117`)。
- 権限を戻す手段は無い(決定)。書き込みが必要な利用者は、画面で行う。
- 403 は人間向けの説明文を含まず、OpenAPI にも 403 の記述が無い(§2.5)。§5.1.1 と §5.2 の文書修正で告知する。403 は分単位の書き込み枠を消費する(§2.9)。
- 通知の要否と手段は **Q8**。リポジトリ内に一括通知の仕組みは確認できない(§2.10)。件数が 0 なら通知は不要。1 件以上なら、ユーザーが手段を決める。

##### 5.4.1.9 デプロイと文書公開の順序

1. Q3: 件数確認(承認後)。
2. TDD: V27 の migration テスト(§6.3 の T-9)を RED → V27 を追加して GREEN → 全体 → 遅延検知。R4 の T-1〜T-8 は V27 に依存せず、並行して追加できる。
3. マージ後、Q5 の承認を得て V27 を含むリリースをデプロイする。MCP の削除(§5.3)も同じ窓で行う。
4. 適用後の確認(§5.4.1.6)。
5. 「API キーは読み取り専用」と断定する文書(`getting-started.md` §3・§5、`builtin-generation-sunset.md`、`openapi.yaml`、MCP README、スキル)を公開する。V27 の適用前に公開すると、旧キーが書き込めるため一時的に不正確になる。

#### 5.4.2 DB のスコープ列と `masters:write` 定数

`masters:write` を API キーに付与しない前提での扱い。第2回決定(X2)と整合するのは K1。

| 案 | 内容 | 判断材料 |
|----|------|----------|
| **K1(確定): 列も定数も残す** | `users.api_key_scopes`、`MASTERS_WRITE`、`MastersApiAccessRequirement::Write` は変更しない | (1) `MastersApiAccessRequirement::Write` は、read キーの書き込みを**拒否するために必要**(§2.2)。(2) `SessionPrincipal.api_key_scopes: Option<...>` は API キー/セッションの判別子を兼ねる(§2.4)。Option を外すには判別子の代替が要る。(3) 列を消す migration は本番データの変更を伴い、得られる利益が小さい(V27 に加えてもう 1 つの本番データ変更を増やすことになる)。`MASTERS_WRITE` は許可判定と既存テストで使われている。 |
| **K2: 列と `masters:write` を撤去する** | API キー主体は「常に read のみ」という固定のポリシーにし、`api_key_scopes` 列(と `parse_api_key_scopes_json`、`default_api_key_scopes_json`)を撤去する | 変更箇所が多い(`masters_api_scope.rs`、`session_principal.rs:10`、`api_key_principal_gateway.rs`、`user_api_key_rotation_gateway.rs:43,52-54`、`session_cookie_principal_gateway.rs`、`support.rs:123-131`、契約テスト)。判別子の再設計も要る。`DROP COLUMN` は SQLite の既存 migration に前例がある(`V4__predicted_weather_metadata.sql:12-14`)が、`api_key_scopes` の削除は未検討。 |

**K1 で確定する**(X2 は列を更新するだけで、列の削除ではない。V27 の後も列は「API キーの権限を保存する」役割を持ち続ける)。将来スコープの種類を増やす予定は本決定に無いので、K2 が YAGNI 側という主張も成り立つが、K2 は判別子の再設計を含み、書き込みを与えない決定の達成に対して費用が釣り合わない。**K2 は本課題では行わない**(要望があれば別課題)。

#### 5.4.3 再生成で降格する挙動(Q2)

コード変更は不要。推奨は「意図とみなして確定し、文書化(§5.1.1)する。UI の警告は不要」。

- 決定により、再生成後に read のみになるのは「与えない」の帰結として整合する。
- UI の確認ダイアログ(`ja.json:3822`)を変えるかはユーザー判断(Q2)。変える場合はフロントエンドの文言変更で、TDD の対象になる(§5.6)。

### 5.5 文書側の他の修正

- ADR-001(§5.3.4)と ADR-002 の `V15__organizations.sql` の誤記(課題 09)は本書の対象外。

### 5.6 フロントエンドの文言(コード変更、別扱い)

決定後、次の文言は仕様と食い違う(§2.6)。文書修正の PR には含めず、TDD で別に行う。

- `ja.json:3810` / `en.json:3774` / `in.json:3480` の説明文(「CRUD API にアクセスできる」)を「読み取り専用」に直す。
- `ja.json:3839` の `list_html` は `POST` / `PATCH` / `DELETE` を列挙している。API キーで使えるのは `GET` だけなので、書き込みの行を削除するか、「書き込みは画面から」と注記する。`en` / `in` の同等箇所は**未読**。
- ロケール JSON の変更は `api-keys.component.spec.ts` ほかのフロントエンドテストに影響し得る。

---

## 6. TDD/検証計画

中心は、**R4 契約で「read キー(API キー)の `POST` / `PUT` / `PATCH` / `DELETE` と apply が 403」を固定する**ことである。決定(書き込みを与えない)を、観測可能なテストで守る。

### 6.1 方針

- 文書のみの修正(§5.1、§5.2)は `tdd-on-edit` の例外(ドキュメント/設定のみ)に該当し、RED は必須ではない。ただし「文書と実装の整合」を保つため、R4 の追加テスト(§6.3)を先に入れる。実装が既に決定を満たしているため、追加テストは**追加した時点で GREEN のはず**である。RED になる場合は、実装が想定と異なる(=文書に書けない)ことを示す。
- **既存テストを弱いまま使い回さない**(§2.7)。既存の 403 テストは `set_user_api_key_scopes` でスコープを上書きしている。新テストは、`regenerate_api_key` で得た**生成直後のキー**を、そのまま使う(`set_user_api_key_scopes` を呼ばない)。これで「生成したままのキーが書き込めない」ことを実キーで固定する。
- 403 の表明は `status == 403` と `error_code == "insufficient_scope"` の両方を検証する(`contracts.rs:3040-3045` と同形)。

### 6.2 既存の R4 契約で担保済みの部分(§2.7)

- read キーの `POST` が 403 かつ `error_code == "insufficient_scope"`(`contracts.rs:3013-3046`)。ただしスコープを明示上書きしている。
- read キーの apply が 403(`:3069-3092`)。同上。
- 再生成後の既定スコープが read のみ(`:3094-3120`)。DB の値のみ。
- セッションの apply が 201(`:2715` 付近)。UI 経路が API 側で成立することの根拠。

### 6.3 追加案(R4 契約、`crates/agrr-r4-contract/tests/contracts.rs`)

テスト名は既存の命名(`masters_api_key_...`)に揃える。準備は既存の `regenerate_api_key`(`support.rs:152-161`)、`seed_masters_crop`(`support.rs:250-`)、`valid_setup_proposal_body`(`contracts.rs:2644`)を使う。

**中心のテスト(read キーの書き込み拒否)**

| # | テスト案 | 表明 | 目的 |
|---|----------|------|------|
| T-1 | `masters_api_key_default_scope_denies_post_put_patch_delete` | `regenerate_api_key` で得たキー(スコープ上書きなし)で、`POST /api/v1/masters/crops`、`PUT` / `PATCH` / `DELETE /api/v1/masters/crops/{id}`(`masters_crops.rs:37-45` に 4 メソッドあり)がそれぞれ 403 かつ `insufficient_scope`。本文は妥当な値にする(検証エラーで 403 が隠れないようにする)。その後、作物が変更・削除されていないこと(セッションで `GET` して名前が同じ、DELETE 後も 200)を確認する | 決定の中心。メソッド 4 種と副作用なしを固定する |
| T-2 | `masters_api_key_default_scope_denies_setup_proposal_apply_without_side_effects` | 生成直後のキーで `mode=apply` が 403 かつ `insufficient_scope`。その後、同じ作物の `GET .../crop_stages` が空配列(何も永続化されていない)。本文が不正でも 403 になること(認可が検証より先: `masters_crop_setup_proposal.rs:40`)は、apply の呼び出し回数を増やすため任意(下記のレート制限に注意) | apply が API キーで使えず、副作用も無いことを固定する |
| T-3 | `masters_api_key_default_scope_denies_all_masters_write_routes` | 表駆動。`masters_*.rs::routes()` にある write ルート(`POST` / `PUT` / `PATCH` / `DELETE`)を一覧化し、生成直後のキーで全件 403 かつ `insufficient_scope`。パスの ID は存在しない値でよい(`MastersUserId` が `Path` より先に走るため 403 が先に返る想定。コードから導いたもの、実行では未確認) | 新規ハンドラーが `MastersUserId` を持たない、または `Json` より後ろに置いた場合の取りこぼしを検知する |
| T-4 | `masters_api_key_default_scope_allows_get_and_setup_proposal_dry_run` | 生成直後のキーで `GET /api/v1/masters/crops` が 200、`mode=dry_run` が 200 で `valid: true` | 読み取り専用キーで参照と検証はできること(文書の「read = GET + dry_run 可」)を固定する |

T-3 の補足:

- 一覧の作成元は、`masters_*.rs` の `routes()` と `.route(` 呼び出し(`grep -n '\.route(' crates/agrr-server/src/masters_*.rs` で 34 行、GET のみのルートを含む)。
- 除外するルートがある。`masters_crop_agricultural_tasks.rs:21` の `put` / `patch` / `delete` は `gone`(410)を返し、`MastersUserId` を持たない(同ファイルの `MastersUserId` 出現数 0)。read キーでは 403 でなく 410 になる。書き込みは起きないので、除外して理由をテストのコメントに残す。410 自体は既存(`contracts.rs:2234-2272`)。
- 「他の write ルートも 403」を確認するのが目的で、全ルートの網羅ではなく、リソース系統ごと(farms、fields、crops、crop_stages、task_schedule_blueprints、pests、pesticides、fertilizes、agricultural_tasks、interaction_rules、crop_requirements)に最低 1 件を含める。

**降格・既定値・fail-closed・セッション**

| # | テスト案 | 表明 | 目的 |
|---|----------|------|------|
| T-5 | `masters_api_key_regenerate_demotes_write_scope_to_read_only` | `set_user_api_key_scopes` で `["masters:read","masters:write"]` にした後、再生成した新キーで `POST /api/v1/masters/crops` が 403。DB の `api_key_scopes` が `["masters:read"]` | Q2(再生成で降格)を仕様として固定する。旧 write キーを再現する準備だけ `set_user_api_key_scopes` を使う |
| T-6 | `post_api_keys_generate_for_new_key_defaults_to_read_only` | `clear_user_api_key_credentials`(`support.rs:142-150`)でキーを消した後、`POST /api/v1/api_keys/generate` で新規発行したキーの DB スコープが `["masters:read"]`。そのキーで `POST` が 403 | 既存テストは `regenerate` を叩くため、`generate` の経路が未検証 |
| T-7 | `masters_api_key_null_scopes_denies_all_masters_requests` | `api_key_scopes = NULL` のキーで `GET` も 403 | §2.4 の fail-closed(コードから導いたもの)を実測に変える。想定と異なる場合は課題 05/06 と併せて再評価する |
| T-8 | `masters_session_cookie_ignores_api_key_scopes` | `set_user_api_key_scopes` で `["masters:read"]` にしたユーザーの**セッション**の `POST /api/v1/masters/crops` が 201 | 書き込みの唯一の経路がセッションであるため、API キーのスコープの影響を受けないことを固定する(既存に同等のテストがあるかは先に確認する) |

**既存キーの移行(V27、X2 確定)**

`agrr-migrate` の既存テスト慣例に沿う。`crates/agrr-migrate/tests/schema_smoke.rs` の既存テスト(`schema_run_includes_v25_api_key_hash_columns`: `:264` など)は、`tempdir` + `DbPaths` + `schema::run` で全 migration を適用した DB を検査する形で、テスト名は `schema_run_includes_vNN_...` または `schema_run_...`。データ更新を検査する migration テスト(V6 の `UPDATE`、V15 の `UPDATE`)は、`crates/agrr-migrate/tests/` に**見つからなかった**(§2.7、`rg "V15|api_key_scopes" crates/agrr-migrate/tests` が 0 件)。V27 が最初の例になる。行を挿入してから検査する形は、`data_repair_*_test.rs` が `support::TestDb::new()`(全 migration を適用した一時 DB: `support.rs`)の接続へ SQL で行を挿入して適用する慣例(例: `data_repair_india_farms_test.rs:7-10`)に揃え、T-9 も `TestDb` を使う(`schema_smoke.rs` は `mod support` を使わず tempdir を直接使うが、行の挿入を伴う検査は `TestDb` の側の慣例)。

| # | テスト案 | 表明 | 目的 |
|---|----------|------|------|
| T-9 | `schema_run_v27_revokes_masters_write_scope_from_legacy_api_keys`(`schema_smoke.rs`) | 準備: `schema::run` で全 migration を適用 → `DELETE FROM refinery_schema_history WHERE version = 27` で V27 を未適用の状態に戻す → 次の行を `users` に挿入(`created_at`・`updated_at` は NOT NULL): (a) `["masters:read","masters:write"]` + `api_key_hash`、(b) `["masters:read"]` + `api_key_hash`、(c) スコープ NULL、(d) スコープ `''`、(e) `["masters:write"]` 単独、(f) 空白入りの `[ "masters:read" , "masters:write" ]`、(g) 平文 `api_key` のみ(ハッシュなし)+ 旧スコープ → `schema::run_primary` で V27 を適用。表明: (a)(e)(f)(g) は `["masters:read"]`。(b) は不変。(c) は NULL のまま、(d) は `''` のまま。全行の `updated_at` が不変 | V27 の条件(§5.4.1.1)を固定する。新規・再発行キーの値を巻き込まないこと、fail-closed の行を変えないこと |
| T-9b | `schema_run_v27_is_idempotent`(同) | T-9 の状態から、`refinery_schema_history` の V27 を再度消して `schema::run_primary` を実行しても、全行の値が変わらない | 冪等性(§5.4.1.2) |

- RED: V27 が無い状態で T-9 を実行すると、(a) の表明で失敗する(履歴の `DELETE` は 0 行で何も起きず、スコープは旧値のまま)。RED の失敗理由は「スコープが移行されない」であり、コンパイルエラーではない。
- 前提の**未検証**: 「`refinery_schema_history` から V27 の行を消して再実行すると、refinery が V27 を未適用として適用する」は、refinery 0.8 のソースが手元に無く、**未確認**(V27 が最大バージョンなので、履歴の最大が 26 になり、通常は保留中の migration として扱われるはず)。RED を確認するときに検証する。動かない場合の代替は、`include_str!("../migrations/schema/V27__revoke_api_key_write_scope.sql")` を `Connection::execute_batch` で流す形(RED はファイルが無いことによるコンパイルエラーになる)。
- 既存の R4(`masters_api_key_write_scope_allows_post`: `contracts.rs:3048-3067`)と `masters_api_scope.rs:110-115` は、K1(§5.4.2)により**そのまま残す**。DB を直接更新した行が write を持ち得ること(サーバーは `masters:write` を解釈し続けること)の記録になる。

**レート制限に関する注意(§2.9)**

- read キーの apply / write の 403 は、`Apply` / `Write` 枠を消費する。R4 の apply 上限は 2 回/分(`AGRR_TEST_SCRIPT=1`、`masters_rate_limit.rs:43`)。
- 既存テストは `developer` で 2 回(`:2715`、`:3069`)、`farmer` で 3 回(`:3153`)apply を呼ぶ。T-2 は、apply の呼び出しが 1 回以下で、`developer` / `farmer` とは別のユーザー(`researcher` など、apply を呼んでいないユーザー)を使う。
- モックログインで使えるユーザーは固定の 5 名(`developer`、`farmer`、`researcher`、`contract_api`、`e2e_empty`: `crates/agrr-server/src/auth_test.rs:59-73`)。T-3 は write を 60 件/分(`Write` 枠の既定)以内に収める。収まらない場合はユーザーを分けるか、一覧を絞る。
- 同じユーザーで `regenerate` すると、そのユーザーの前のキーが無効になる。並列実行では衝突するが、R4 は `--test-threads=1`(`scripts/run-rust-contract-tests.sh:359`)。

### 6.4 文書と実装のスコープ定義の整合を機械検証する案(任意、軽量)

`scripts/check-doc-freshness-lib.mjs` に検査関数を 1 つ追加する案(`scripts/check-doc-freshness-lib.test.mjs` にテストを付ける。CI は `doc-freshness.yml:34` で実行される)。

- `getting-started.md` §3 に「読み取り専用」と「`insufficient_scope`」が含まれる。
- `getting-started.md` に、旧記述「スコープ列は DB に保存していません」が含まれない。
- `openapi.yaml` の冒頭 description に「read-only」が含まれる。

過剰な検査は保守負担になる(`project-necessary-code-only.mdc`)。上記に絞り、採用するかは実装者が判断する。採用しない場合は §6.3 の R4 契約だけで十分と判断する。

### 6.5 決定により不要になる、または位置づけが変わるテスト

- 「write キーで `mode=apply` が 403 にならない」(旧案)は追加しない。write は付与しないため(既存の `masters_api_key_write_scope_allows_post` は、K1 によりそのまま残す: サーバーが `masters:write` を解釈し続けることの記録)。
- 付与手段(スコープ付き生成)のテストは、すべて不要。

### 6.6 MCP(§5.3 の M-A、確定)

`tools/agrr-mcp/` の変更は TDD の対象。削除対象の一覧は §5.3.5。

- **RED の注意**: 現行の `server-tools.test.mjs:34-37` は、`Object.keys(tools)` を `AGRR_MCP_TOOL_NAMES`(`tools.mjs:77-82`)と比べる。両方から `apply_crop_setup` を消しても、この比較は常に一致するため、**このままでは RED にならない**(実装側の配列と同じ実体を期待値にしているため)。期待値を**リテラル**にする。
- RED(1): `server-tools.test.mjs:34-37` のテスト名を「expose three crop setup tools」にし、期待値を `['get_crop_detail', 'list_reference_crops', 'propose_crop_setup']` のリテラルにする。現行のツールは 4 つなので、失敗する。
- RED(2): `assert.equal(tools.apply_crop_setup, undefined)` を追加する(同じテスト内、または別テスト)。
- あわせて削除するテスト: `server-tools.test.mjs:63-69`、`agrr-client.test.mjs:95-120`。モックの `applyCropSetup`(`server-tools.test.mjs:23-30`)も削除する。
- GREEN: `tools.mjs:58-73,81` と `agrr-client.mjs:53-61` を削除する。
- 実行: `tools/agrr-mcp` の `npm test`(`node --test test/*.test.mjs`: `package.json:12`)。CI は `.github/workflows/frontend-test.yml:131-133`。`test-common` は Node のスクリプトテストを対象外としているため、CI の経路(`working-directory: tools/agrr-mcp`)と同じ方法で実行する。
- 文書・スキルの変更(README、SKILL.md)は、文書のみの変更として `tdd-on-edit` の例外に当たる。

### 6.7 実行方法(`test-common` のみ)

- R4 契約: `scripts/run-rust-contract-tests.sh`。出力は `./tmp/{UUID}.log` にリダイレクトしてから grep する(`AGENTS.md`)。実行後は `process-monitor` に従い、終了コードを確認するまで結果を断定しない。
- ドメイン + `agrr-migrate`: `.cursor/skills/test-common/scripts/run-test-rust-domain.sh`。このスクリプトは `cargo test -p agrr-domain "$@"` の後に `cargo test -p agrr-migrate --quiet` を実行する(`:21-25`)。T-9 と T-9b はここで実行される(引数はドメインのテストにだけ渡るため、`agrr-migrate` のテストは絞り込めず全件実行される)。
- フロントエンド: `.cursor/skills/test-common/scripts/run-test-frontend.sh`(§5.6 の実施時)。
- doc-freshness の検査を追加する場合は `node --test scripts/check-doc-freshness-lib.test.mjs`。CI の `doc-freshness.yml` と同じ経路で実行する。
- 個別テスト GREEN → 全体 → 遅延検知(`test-slow-detection`)の順は、`rails-testing-workflow.mdc` に従う。
- 文書修正と R4 のテスト追加だけなら `crates/agrr-server/**` は変更しないため、`rebuild-restart.sh` は不要(`docker-dev-agrr-server-rebuild.mdc`)。V27(`crates/agrr-migrate/migrations/`)を追加した場合は、Docker 検証の前に `.cursor/skills/dev-docker/scripts/rebuild-restart.sh` が要る。R4 は `scripts/run-rust-contract-tests.sh` が必要に応じてバイナリを再ビルドする(`run-rust-contract-tests.sh:20-34`)。

---

## 7. 実装ステップ

TDD(`tdd-on-edit`)に従い、コード変更は RED → GREEN の順に進める。テストは `test-common` のスクリプトだけで実行する。日時の見積りは書かない。

**A. 事前確認(ユーザー承認が先)**

1. **件数確認(Q3)**: 承認を得て、`production-primary-sqlite-query` のスクリプトで §5.4.1.5 の確認 1〜4 を実行し、結果を提示する。使えない場合は、Q5 の承認時に「未確認のまま実施するか」をユーザーが決める(§5.4.1.4)。

**B. テストの追加(V27 に依存しない)**

2. **契約テストの追加(推奨)**: §6.3 の T-1〜T-8 を追加し、`scripts/run-rust-contract-tests.sh` で実行する。GREEN を確認する。想定と異なる結果が出たら、文書を書く前に §8 のリスクとして記録する。

**C. 既存キーの移行(V27、別 PR)**

3. **RED**: `schema_smoke.rs` に T-9・T-9b を追加し、`.cursor/skills/test-common/scripts/run-test-rust-domain.sh` で失敗(スコープが移行されない)を確認する。「履歴の V27 を消して再実行」が refinery で動くことも、ここで確認する(§6.3)。
4. **GREEN**: `crates/agrr-migrate/migrations/schema/V27__revoke_api_key_write_scope.sql` を追加する(§5.4.1.2)。同じスクリプトで GREEN を確認し、全体 → 遅延検知(`test-slow-detection`)を行う。
5. **R4**: `scripts/run-rust-contract-tests.sh` を全件実行し、既存の R4 が V27 で変化しないことを確認する(§5.4.1.2)。
6. **Docker 検証**: `.cursor/skills/dev-docker/scripts/rebuild-restart.sh` の後に確認する。

**D. MCP とスキル(別 PR、V27 と同じリリースの窓)**

7. **RED**: `server-tools.test.mjs` の期待値をリテラルの 3 ツールにし、`apply_crop_setup` が無いことの表明を加える(§6.6)。`tools/agrr-mcp` の `npm test` で失敗を確認する。
8. **GREEN**: §5.3.5 の削除を行い、`npm test` で GREEN を確認する。Q9 の回答に従い、バージョンを上げる。
9. **README とスキル**: §5.3.2、§5.3.5 の書き換えを行う。
10. **参照の更新**: 課題 07・08 と本書 §2.8 の `file:line`(MCP のクライアントとテスト、README)を更新する(§5.3.6)。

**E. デプロイ(ユーザー承認後)**

11. **Q5 の承認を得て**、V27 と MCP の削除を含むリリースをデプロイする(`deploy-server` スキル)。migration は起動時に自動適用される(§2.10)。
12. **適用後の確認**: §5.4.1.6 に従う。

**F. 文書の公開(V27 の適用確認後)**

13. **`getting-started.md` §3 の修正**: §5.1.1 の差分を適用する。
14. **`getting-started.md` §5 の修正**: §5.1.2 を適用する。
15. **`builtin-generation-sunset.md` の修正**: §5.1.3 と §5.3.6 を適用する。
16. **`openapi.yaml` の修正**: §5.2 を適用する。課題 08 と同じ箇所に手が入るため、順序は §10 に従う。
17. **`setup_proposal-openapi-snippet.yaml` の修正**: 課題 08 の方針と衝突しない範囲で §5.1.4 を適用する。
18. **リンク・鮮度検査**: `./scripts/check-doc-internal-links.sh` と `./scripts/check-doc-stale-paths.sh` を実行する(`doc-freshness.yml:25,28`)。
19. **(任意)機械検証の追加**: §6.4 を採用する場合のみ。

**G. その他(別扱い)**

20. **フロントエンド文言**: §5.6。課題 07 の作業と調整する。
21. **Q10**(`builtin_generation_deprecation.rs:33` の文言)は、推奨どおり直さない場合は作業なし。

---

## 8. リスク・未確定事項

| # | 項目 | 状況 |
|---|------|------|
| R-1 | 本番の既存キーのスコープ分布(read+write のまま残るキー、NULL のキー) | 未確認。Q3。Q5 の判断の前提。 |
| R-2 | MCP の `apply_crop_setup` とスキルの apply が、決定後は API キーで恒久的に動かない | コードから確認済み(§2.8)。実行では未確認。§5.3 で対処する。 |
| R-3 | 再生成による降格が、既存の外部統合を壊す | コード上そうなる(§2.3)。実際に再生成して被害を受けた利用者がいるかは未確認。Q2 で意図とみなして確定し、文書で明示する(§5.1.1)。 |
| R-4 | 403 になる書き込みがレート制限のカウントに入る | コードを読んで確認した(§2.9)。実行では未確認。認可の一貫性として課題 10 に引き継ぐ。R4 の新テストは、この挙動と apply 枠(2 回/分)を前提に設計する(§6.3)。 |
| R-5 | 契約テスト T-1〜T-8 が想定どおり GREEN になるか | 未実行。RED/GREEN の結果で文書の記述を最終確定する。 |
| R-6 | V15 の `UPDATE` を検証するテストが無い | `crates/agrr-migrate/tests` と `src` に `V15` / `api_key_scopes` の言及は 0 件(§2.7)。V27 の T-9・T-9b が、データ更新を検査する最初の migration テストになる。「履歴の V27 を消して再実行」が refinery で動くかは未確認(§6.3)。 |
| R-7 | `en.json` と `in.json` の API キー画面のエンドポイント一覧、およびロケール全体の他箇所 | 説明文(`en.json:3774`、`in.json:3480`)は確認済み(CRUD API)。`list_html` の `en` / `in` は未読。§5.6 の作業時に確認する。 |
| R-8 | 文書修正の PR が課題 04・08・09 と同じファイルを編集し、競合する | §10 の順序で回避する。 |
| R-9 | 旧キー(read+write)の外部連携が、V27 で突然 403 になる | 影響の有無は未確認(Q3)。利用実態は DB・ログから判別できず、一括通知の仕組みもリポジトリ内で確認できなかった(§2.10)。ユーザー確認事項(Q5、Q8)。 |
| R-10 | MCP のツール `apply_crop_setup` を削除すると、削除を前提にしていない利用者がいる | 決定済み(M-A)。`apply_crop_setup` が成功するのは V15 以前のキーだけで、V27 の対象と同じ集合(§5.3.7)。MCP SDK がツール不在をどう返すかは未確認。 |
| R-11 | ユーザーの意図が解釈 (b) のみだった場合、本書の方針(API キー読み取り専用)は不要な制約になる | §0 で解釈であることを明記した。第1回決定だけなら実装の変更は生じない(文書のみ差し戻す)。第2回決定(V27 と MCP 削除)を実施した後は、データと MCP の変更が残る。実施前に §0 の解釈をユーザーが確認する。 |
| R-12 | T-3 の表駆動テストが、`Write` 枠(60 件/分)や apply 枠(2 回/分)を超えて 429 になる | §6.3 の注意のとおり、ユーザーを分けるか一覧を絞る。 |
| R-13 | V27 の適用がバックグラウンドで走り、失敗してもサーバーが起動し続ける。適用前・失敗時は旧キーが write のまま | コードから確認(§2.10)。適用後の確認を DB で行う(§5.4.1.6)。 |
| R-14 | V27 が意図しない行を更新した場合の巻き戻し | Litestream の保持は 24 時間で、復元は全書き込みを失う。適用前に対象行の `id` とスコープを退避し、逆 `UPDATE` で戻す(§5.4.1.3、§5.4.1.7)。本番へ流す経路は既存スクリプトの流用で、別途承認が要る。 |
| R-15 | 事前確認スキルの実行可否 | GCP 認証情報の有無が未確認。この計画では本番に接続していない(§5.4.1.4)。 |
| R-16 | 移行対象の判定が `LIKE` の文字列一致で、書式の異なる JSON を取りこぼす可能性 | 実装が書く書式は 2 通りのみ(§2.10)。確認 3(§5.4.1.5)で想定外の値が 0 行であることを見てから進める。空白入りの配列は一致することを確認済み。 |

---

## 9. 受け入れ条件

文書修正(本課題):

1. `docs/api/getting-started.md` §3 に、次の記述が**ない**こと: 「スコープ列は DB に保存していません」「将来の tier 用」「読み取りと書き込みの両方が可能」。
2. §3 に次が**ある**こと: API キーは読み取り専用(`masters:read` のみ)、書き込みはログインセッション経由のみ、書き込み系の API キー利用は 403 `insufficient_scope`、`masters:write` は API キーに付与しないこと、再発行でスコープが `masters:read` になること。
3. §5 の apply の手順が、API キーではなく画面(提案 JSON をインポート)経由になっていること。`### apply 例`(API キーの curl)が無いこと。
4. `builtin-generation-sunset.md` の代替表・肥料/害虫の案内・`apply` の説明が、書き込みは API キーでは 403 でセッション(画面)経由と明記していること。
5. `docs/api/openapi.yaml` の冒頭 description と `securitySchemes` が「API キーは読み取り専用」と明記していること。write operation の扱い(§5.2.3 の推奨 B、または Q7 の回答)が、`setup_proposal` の `mode=apply` の注記を含めて反映されていること。
6. `tools/agrr-mcp/README.md` と `agrr-crop-setup/SKILL.md` が、API キーは読み取り専用で apply は UI で行うことを明記し、`apply_crop_setup` が README(表と Apply idempotency 節)とスキル(手順 5)から消えていること(§5.3.2、§5.3.5)。
7. `./scripts/check-doc-internal-links.sh` と `./scripts/check-doc-stale-paths.sh` が成功すること。
8. (契約テストを追加した場合)`scripts/run-rust-contract-tests.sh` が成功し、T-1〜T-8 が GREEN であること。RED の場合は、その事実に合わせて文書の記述を修正していること。
9. 文書修正の PR が、実装コード(`crates/**`、`frontend/**`、`tools/agrr-mcp/**` の本体)を変更していないこと(テスト追加を除く)。
10. 「API キーは読み取り専用」と断定する文書の公開が、V27 の適用確認(条件 13)より後であること(§5.4.1.9)。

コード変更(別 PR、ユーザー確認後):

11. **MCP(M-A)**: `tools/agrr-mcp/src/tools.mjs`、`agrr-client.mjs`、テストから `apply_crop_setup` / `applyCropSetup` が消え(§5.3.5 の一覧)、`server-tools.test.mjs` の期待値がリテラルの 3 ツールで、`tools/agrr-mcp` の `npm test` が成功すること。`rg -n --hidden -g '!.git' -g '!**/node_modules/**' "apply_crop_setup|applyCropSetup"` の該当が `docs/spec-defects/` 以外に無いこと。
12. **V27(X2)**: `crates/agrr-migrate/migrations/schema/V27__*.sql` が追加され、V15 のファイルが変更されていないこと。T-9・T-9b が GREEN で、`run-test-rust-domain.sh`(`agrr-migrate` のテストを含む)が成功すること。`scripts/run-rust-contract-tests.sh` が成功し、既存の R4 が変化していないこと。
13. **本番適用**: 事前の件数確認(§5.4.1.5)の結果をユーザーが確認し、Q5 で V27 のデプロイを承認していること。適用後、確認 2 が 0 件、`refinery_schema_history` に version 27 があること(§5.4.1.6)。対象キーの所有者への通知は Q8 の回答に従うこと。
14. **バージョン**: Q9 の回答に従い、MCP のバージョンが更新されていること(推奨は `0.2.0`)。
15. **参照の更新**: 課題 07・08 と本書 §2.8 の `tools/agrr-mcp` への `file:line` が、削除後の行番号に更新されていること(§5.3.6)。

---

## 10. 関連課題との依存

| 番号 | 課題 | 関係 |
|------|------|------|
| 01 | resource-limit-bypass | 依存なし。 |
| 02 | contact-recaptcha | 依存なし。 |
| 04 | api-key-query-auth | **同一ファイルの競合**。`getting-started.md` §2 (`:30`) の「クエリ（非推奨）」は実装で無視される(`masters_auth.rs:44-61`)。04 が §2 を、本課題が §3・§5(と §2 の冒頭 1 文)を編集する。README の推奨順どおり 03 を先に入れ、04 を rebase する。または別の PR にする。 |
| 05 | fail-closed-critical | NULL スコープが全拒否になる挙動(§2.4)は fail-closed 側。T-7 の結果によっては 05/06 の観点で再評価する。 |
| 06 | fail-closed-suspected | 同上。`parse_api_key_scopes_json` が不正 JSON を空配列にする(`masters_api_scope.rs:53-66`)ことが安全側かを 06 で見る余地がある。 |
| 07 | frontend-error-contract | MCP クライアントが 403 の `error_code` を捨てる(`agrr-client.mjs:88-92`)点、UI が `insufficient_scope` を表示できない点。M-A(ツール削除、確定)により MCP 側の対応は不要(§5.3.1)。§5.6 の後続作業と調整する。**「削除」の回答は 07 の旧キー削除(S2)ではない**(§0)。07 が参照する `agrr-client.mjs:87-95` と `agrr-client.test.mjs:122-126` は、`apply_crop_setup` の削除で行がずれる(§5.3.6)。 |
| 08 | openapi-gaps | `openapi.yaml` に 403/`insufficient_scope` の応答がない(§2.5)。08 が「公式 MCP が呼ぶのは 4 本」(`08-openapi-gaps.md:155`)と記す点は、`apply_crop_setup` の削除(§5.3)で 3 本になる。`setup_proposal-openapi-snippet.yaml` の廃止・統合の判断も 08 に属する。`securitySchemes` と冒頭 description、D-09(`sessionCookie` がグローバル `security` にない)は 08 と本書の両方が触れる。§5.2.3 の推奨 B(`security` の上書き)は、08 の 403 追加(D-03)と同じ operation を編集するので、08 を先に入れてから本書の `security` 上書きを適用するのが安全。403 とスコープの説明文言は 08 と同じ表現にそろえる。 |
| 09 | stale-design-docs | 古い文書の一群。本課題の `getting-started.md` §3 はその一例。ADR-001 が外部スキルによる apply を前提にしている点(§5.3.4)は 09 で扱う。近傍に `docs/adr/ADR-002-organization-multi-tenancy.md:102` が `V15__organizations.sql` と書くが、実際の V15 は `api_key_scopes`、`organizations` は V16(`ls crates/agrr-migrate/migrations/schema`)という不一致があり、09 で扱う。 |
| 10 | authorization-consistency | 第2回決定の「削除」は、10 の削除 undo(`DeletionUndoScheduleInteractor` が本番未配線)の扱いではない(§0)。ユーザー語「与えない」の**もう一方の解釈 (b)**「組織メンバーに Plan の編集権限を与えない(閲覧のみ)」を扱う(§0、[README](README.md) の決定事項表)。また、スコープの強制が extractor(`MastersUserId`)に集中し、レート制限は認証のみ(`masters_rate_limit.rs:163`)であること(§2.9、R-4)を、認可の一貫性の観点で見る。API キーが有効なのは `/api/v1/masters/*` に限られる(§2.4)ことを、10 の「API キーが `/api/v1/masters/` 以外で使われるか(未確認)」の回答として引き継ぐ。 |
| 11 | low-priority-misc | 依存なし。 |

推奨順序: 08(OpenAPI 方針)と 04(getting-started §2)の方針を先に確認 → R4 テスト追加(§6.3)→ 件数確認(Q3)→ V27 と MCP 削除のコード変更(§5.3、§5.4.1。TDD)→ ユーザー承認(Q5、Q8、Q9)後にデプロイ → V27 の適用確認 → 文書の公開(§5.1、§5.2。Q7 を含む)→ フロント文言(§5.6)。文書の公開を V27 の適用確認より後にする理由は §5.4.1.9。
