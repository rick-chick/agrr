# 07: フロントエンドとバックエンドのエラー契約・i18n のずれ

本書は**対応計画のみ**であり、コード・文書・カタログの修正は含まない。記載する事実は 2026-09-29 時点のリポジトリを実際に読んで確認したものだけで、`file:line` を付ける。読んでいない・実行していないものは「未確認」と明記する。

参照した規約: [`ARCHITECTURE.md`](../../ARCHITECTURE.md)（Frontend 節）、[`docs/architecture/LAYER-RULES.md`](../architecture/LAYER-RULES.md)、[`docs/design/UI-COMPOSITION-RULES.md`](../design/UI-COMPOSITION-RULES.md)、[`tdd-on-edit`](../../.cursor/skills/tdd-on-edit/SKILL.md)、[`test-common`](../../.cursor/skills/test-common/SKILL.md)、[`i18n-completion-workflow`](../../.cursor/skills/i18n-completion-workflow/SKILL.md)、[`i18n-completion-orchestrator.mdc`](../../.cursor/rules/i18n-completion-orchestrator.mdc)、[`evidence-before-design-and-implementation.mdc`](../../.cursor/rules/evidence-before-design-and-implementation.mdc)、[`no-convenience-tech-debt.mdc`](../../.cursor/rules/no-convenience-tech-debt.mdc)、[`fallback.mdc`](../../.cursor/rules/fallback.mdc)。

### 調査の限界（先に明記）

- `frontend/node_modules` が無く、Angular / vitest / ngx-translate は実行していない。フロントの挙動は**コード読解**による。
- `cargo test` / `scripts/run-rust-contract-tests.sh` は実行していない。サーバーの挙動は**コード読解**による。
- i18n カタログの比較と、コード中のキー参照の静的抽出は Python スクリプトで機械的に実施した（付録 D に再現手順）。テンプレートリテラルなどで動的に組み立てるキーは検出できない（未確認）。
- 本書の「サーバー全 handler の返却形」（§2.7）の箇所数は、`crates/agrr-server/src/**/*.rs` の各ファイルを最初の `#[cfg(test)]` の手前で切り、正規表現で `"error"` / `"errors"` / `"success": false` / `"success": false, "message"` を数えた概数である（付録 D-2 に再現手順）。インラインのテストモジュール内の期待値は含まない。`json!` を介さずに組み立てる本文は数え漏れがあり得る（§8 R13）。
- 第 2 回決定（§0.2）で統合先を `errors` にしたため、§2.7 の箇所数を「`error` 単数と `message` 形式の全数」として再集計し直した（§3.2.1）。第 1 回の版が §2.7 に書いた Plans 系の `error` の件数（61）は誤りで、表の値から 71 に訂正した。
- 外部 API キー利用者が実際にどのキー（`error` / `errors`）に依存しているかは、リポジトリ内のコードとドキュメントからしか調べていない。API キー経由のリクエストを利用者別に集計する手段は、`security_audit_log.rs:11-19` のイベント種別（キー生成・再生成など）を見る限り無い。Cloud Logging 側の HTTP ログで数えられるかは**未調査**。

---

## 0. 決定事項

### 0.1 決定（第 1 回: ユーザー指示「統合」の解釈）

| 項目 | 内容 |
|------|------|
| 決定 | フロントエンドとサーバーの**エラー契約を単一形式に統合**する |
| 具体 | (a) 全 Masters / Plans 系 API が、失敗時に同一の形の本文を返す。(b) `error`（単数文字列）と `errors`（配列）の混在を解消する。(c) フロントは共通の純関数 1 系統でエラー本文を読む。旧形式の受信は許容しない方向とする（§3.4） |
| 出典 | 指示語「統合」（[`README.md`](README.md) の「決定事項（ユーザー指示の反映）」表。07 は「フロントとサーバーのエラー契約を単一形式に統合」に対応づけた） |
| 解釈の限界 | 「統合」は、課題 01 の**経路統合**（Farm / Crop の上限判定を作成経路の間で揃えること）も含意し得る。ただしそれは [01](01-resource-limit-bypass.md) で扱う。本書は上限の強制方法には触れず、01 が追加・変更する上限エラーの「形」だけを本書の契約に合わせる |
| 位置づけ | 上記は文脈からの**解釈**であり、誤りがあればこの節を差し替える |

### 0.2 決定（第 2 回: ユーザー指示「errors」の解釈）

| 項目 | 内容 |
|------|------|
| 決定 | エラー契約の統合先を **`errors`（文字列配列）に確定**する |
| 具体 | (a) 4xx / 5xx の失敗本文は、必ず `errors: string[]`（1 件以上、各要素は非空文字列）を含む。単一メッセージも `errors: ["<msg>"]` とする。(b) `error`（単数文字列）と `message` は失敗本文の契約から外す。移行期間だけ旧キーを併記し、ゲートを満たしたら削除する（§3.5）。(c) 任意の付加情報として、機械可読コード `error_code` と項目別メッセージ `field_errors` を許す。(d) フロントは `errors` の 1 系統だけを読む（§3.7） |
| 出典 | ユーザー指示「errors」（[`README.md`](README.md) の「決定事項（第 2 回: 未決事項への回答）」表。07 の統合先選択への回答として対応づけた） |
| 解釈 | 「errors」を「統合先の単一形式は、既に API に存在する `errors` キーである」と解釈した。値を**文字列配列**に限るのは、現行の Masters create / update が返す形（§2.1）と一致し、OpenAPI 課題 08 の D-14 も同じ形を推奨しているため。項目別の map（`{field: [msg]}`）とオブジェクト配列（`{path, message}`）を `errors` に入れる解釈は採らない（→ §3.3 C3） |
| **前回推奨を覆す点** | 第 1 回の版は、`error`（単数）を統合先とする案（旧 U1）を推奨していた。**この推奨は採用しない**。根拠に挙げた事実（`error` が約 313 箇所・`errors` が約 102 箇所、外部契約 `getting-started.md:57` が `error`、公式 MCP クライアント `tools/agrr-mcp` が `error` を読む、フロントが `error` をコードとして比較している）は消えない。これらは「`errors` 統合の追加コスト」として §3.2 で整理し直した |
| 解釈の限界 | 「errors」は、旧キー（`error` / `message`）をいつ削除するかや、外部 API キー利用者への影響の許容までは含意しない。それらは未決（§3.9 Q2）のまま残す。旧版の統合先選択（旧 Q1）は本決定で解消したため削除した |

### 0.3 本書が実コードの調査から導いた設計（ユーザー決定ではない）

移行方式や共通ヘルパーは指示では指定されていないため、実コードの事実から決めた（根拠は §2.7〜§2.9、§3.2〜§3.8）。ユーザーが覆せる点は §3.9 の Q に集約した。

| 論点 | 設計 | 主な根拠 |
|------|------|----------|
| 統合先の形 | 4xx / 5xx は必ず `{"errors": ["<非空文字列>", ...]}`。任意で `error_code` と `field_errors` を付ける。`error` と `message` は失敗本文から廃止する | `errors` 102 箇所のうち 96 箇所は既に文字列配列で、Masters の create / update の検証失敗と Plans 系の大半がこの形（§2.7）。OpenAPI も文字列配列を推奨（課題 08 D-14） |
| 追加コスト（サーバー） | 変更箇所は **349**（`error` 299 + `message` 47 + 項目別 map 3）。前回推奨の `error` 統合で必要だった 146（`errors` 99 + `message` 47）の約 2.4 倍 | §3.2.1 |
| 旧形式の扱い（フロント） | 統合後は**許容しない**。`error` も `message` も読まない | 「統合」の意図。二重の読み取りを残すと、`no-convenience-tech-debt.mdc` の「軽微な技術負債は残置しない」に反する |
| 移行方式 | 併記は**必要**。サーバー S1（`errors` を追加し、旧キー `error` / `message` を併記）→ フロント F1（`errors` 1 系統に切替）→ サーバー S2（旧キー削除）の 3 リリース。併記の要否と期間はデプロイ順序と削除ゲートで定義する。項目別 map の 3 箇所だけは、`errors` の型そのものが変わるため併記できず、S2 で型を変える | 旧フロントは `error` を 15 ファイルで読み、警告分類（`backend-warmup.ts:74-80`）も `error` の有無に依存する（§3.5、§3.7） |
| 共通ヘルパー | `crates/agrr-server/src/api_error.rs`（エッジ層）に薄いヘルパーを導入する。単一メッセージも `errors: [msg]`、任意の `error_code`、項目別は `field_errors` | 現状、共通のエラー応答ヘルパーは無く、`"error": "internal"` だけで 88 箇所・23 ファイルに複製されている（§2.9）。LAYER-RULES の R6 / R7 に適合（§3.6） |
| フロントの共通関数 | `frontend/src/app/core/api-error-message.ts`（純関数）に集約し、24 usecase と、それ以外の本文リーダー、`error` をコードとして比較している箇所を置換する。本文の解釈は下位モジュール `core/api-error-body.ts` に置く（循環参照の回避） | §2.2、§2.8、§3.7 |

---

## 1. 概要と重大度

### 概要

フロントエンド（`frontend/src/app/usecase/**`）とサーバー（`crates/agrr-server/src/`）の間で、エラー本文の形と i18n キーの扱いが揃っていない。課題は次の 5 件である。依頼文の前提のうち、調査で**訂正・補足が必要だった点**を併記する。

| # | 課題 | 調査結果の要点（詳細は §2） | 依頼文の前提との差 |
|---|------|------------------------------|--------------------|
| 1 | Masters のエラー本文が `error` / `errors` で混在し、フロントが片方しか読まない | サーバーは create/update の検証失敗を `errors[]`、認可・destroy・一部 update を `error` で返す。フロントは usecase ごとに読む側がばらばら。**24 個の Masters 変更系 usecase のうち 20 個**が、少なくとも一方の形を読めない | crop / farm の update だけでなく、field の create/update/destroy、farm/field/fertilize/agricultural-task/interaction-rule の destroy、interaction-rule の update も**サーバーの形を読めない**。一方 pests / pesticides / fertilizes / agricultural-tasks の update は、サーバーが `errors[]` を返すため現状は整合している |
| 2 | `save-public-plan` が API のエラー文字列をそのまま返す | サーバーが返す文字列は**純粋な i18n キーではなく `record invalid: <key>` 形式**（コード読解による導出）。表示層の翻訳も、この形式では発火しない | 依頼文は「i18n キー文字列が入る」としているが、実際は `record invalid: ` という接頭辞が付く |
| 3 | Crop 上限（20）に事前チェックと専用 UI が無い | Farm は事前チェック + `limitBlocked` UI + サーバーエラー時のブロック表示がある。Crop は一切無い | 加えて、Crop は**管理者が参照作物を作る場合は上限対象外**（`crop_create_limit_policy.rs:5-10`）で、Farm と同じ実装をそのまま移植できない |
| 4 | `in.json` に `crop_limit_exceeded` が無い | 事実。加えて、サーバーが送出するキーやコードが参照するキーで、カタログに無いものが複数ある（§2.6） | ja/en/in の比較で、ja のみ 343 件・en のみ 246 件が `in` に無い。コードから静的に参照されているのに全言語で欠落しているキーが 7 件ある |
| 5 | `resolveActiverecordApiErrorI18nKey` が Farm のみ対応 | 事実。ただし現行サーバーは翻訳済み文言ではなくキーをそのまま返す（`PassthroughTranslator`）ため、Farm のリテラル対応表も現状では発火しない見込み（未確認: 他に翻訳済み文言を返す経路） | 機能不全ではなく、判定関数（`isCropLimitExceededMessage` 相当）が無いことが実質の欠落 |

課題 1 は §0 の決定により「フロントの読み取りを usecase ごとに直す」課題ではなく、「サーバーとフロントのエラー契約を単一形式に統合する」課題として再定義した（§3）。統合先は第 2 回決定で `errors`（文字列配列）に確定した（§0.2）。以降の課題 2〜5 は統合と独立に対応できる。

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
- 「両方の形（`error` と `errors`）を読める」ものは 4 件のみ（create-interaction-rule、delete-crop、delete-pest、delete-pesticide）。残り 20 件は片方または両方を読めない。統合後の RED / GREEN の対応は §6.2 T4 に示す。

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

フロントの `err.error?.errors?.join(', ')` 系の実装は `errors` がオブジェクトのとき `join` が存在せず例外になり得る。Masters の対象エンドポイントは配列のため現状は問題ないが、統合後の共通関数は `errors` を「非空の文字列配列」のときだけ読み、map やオブジェクト配列は無視するため（§3.7）この例外は起こらない。3 種類の `errors` のうち、文字列配列は統合先としてそのまま残し、項目別 map は `field_errors` に移し（§3.3 C5）、オブジェクト配列は失敗本文ではない結果ペイロードとして対象外にする（§3.3 C3）。

#### Masters 以外の Rust ルート

Masters 以外にも `error` / `errors` / `message` の 3 系統が混在している。全ハンドラの返却形は §2.7 の網羅表、本文を読むフロント・外部クライアント・テストの一覧は §2.8 を参照。フロント側の突合は、Masters の 24 usecase（§2.1）に加えて §2.8 の本文リーダーまで行った。Plans 系の画面（gantt の変更操作など）が本文を読む経路は §2.8 の範囲で確認したもので、それ以外の読み方は**未確認**（§8 R8）。

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

- edit 系 presenter は、usecase が正しく検証メッセージを読めても（例: `update-pest` の `errors`）、キー形式でなければ汎用メッセージに丸める。**usecase だけ直しても、edit 画面ではサーバーの検証文言は見えない**。表示方針（丸めるか、キー / コードを渡すか）は §3.9 の Q7。
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

したがって、農場上限超過時の応答本文は `"record invalid: activerecord.errors.models.farm.attributes.user.farm_limit_exceeded"` になる（**コード読解による導出。実行検証は未実施。§6.3 の S-T3 / S-T4 で確定する**）。

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
| AI 系: `api.errors.fertilizes.{fetch_failed,invalid_payload,name_required}`（in）、`api.errors.fertilizes.not_found`（全言語）、`api.errors.pests.name_required`（ja / in）、`api.messages.fertilizes.{created_by_ai,updated_by_ai}`（in / en, in）、`api.messages.pests.{created_by_ai,updated_by_ai}`（全言語）、`api.errors.crops.name_required`（in） | `*_ai_create|update_interactor.rs` | 上記のとおり。AI 生成系は `builtin_generation_deprecation.rs` の対象か**未確認**で、本課題の必須範囲かはユーザー判断（§3.9 Q14） |

`in.json` には、他言語に無い**ルート直下の `index` / `new` / `edit` ブロック**と `flash.template_*` 系（`in.json:3183,3589,3607,3619`）があり、ja / en には存在しない。コード参照は静的検索で見つかっていない（削除は本書の範囲外）。また `in` の値のうち日本語文字を含むものが 62 件ある（en は 2 件: `nav.lang_ja`、`public_plans.results.chart.gdd_section`）。「キーはあるが未訳」の別種の欠落であり、本書のキー欠落一覧には含めない。

`ARCHITECTURE.md:83` は i18n カタログを `{ja,en}.json` としているが、実カタログは `{ja,en,in}.json` である（→ 課題 09）。

#### 課題 5: リゾルバ

`core/i18n/resolve-activerecord-api-error-i18n-key.ts:1-15` は Farm の定数（`:1-2`）と、日本語・英語リテラル 2 件の対応表（`:4-7`）のみを持つ。キー文字列が渡された場合は `trim` して**そのまま返す**（`:12-15`）。従って Crop の上限キーは通過するが、Crop 用の定数・判定関数は存在しない。使用箇所は `usecase/farms/create-farm.usecase.ts:32`（変換）と `domain/farms/farm-create-limit.ts:19`（判定）のみ。

`ngx-translate` の欠落キー挙動: `core/i18n/initial-i18n-bootstrap.ts:36` が `setDefaultLang('ja')` を設定しており、`in` で欠落したキーは ja 文言にフォールバックする可能性が高いが、ngx-translate v17 の挙動は `node_modules` が無いため**未確認**。

### 2.7 サーバー: 全 handler の返却形（網羅表）

`crates/agrr-server/src/` の全ファイルを対象に、4xx / 5xx（および `success: false`）本文のキーを数えた。箇所数は「そのファイルに `json!` で書かれたキーの数」（インラインテストは除く。付録 D-2）。**同一の `json!` に `error` と `errors` が併記されている箇所は無い**（0 件）。

区分（§3.2.1 で使う）: **A** = `{"error": string}`、**B** = `{"success": false, "message": string}`、**C** = `errors` が文字列配列、**D** = `errors` が項目別 map、**E** = 統合の対象外。

| # | 対象ファイル | 本文の形 | 箇所数 | 根拠（file:line） | `errors` 統合での変更 |
|---|--------------|----------|--------|-------------------|----------------------|
| 1 | `masters_{crops,farms,fields,pests,pesticides,fertilizes,agricultural_tasks,interaction_rules}.rs`（主要 8 リソース） | 認可・存在なし・destroy・list / detail の失敗・内部エラーは `{"error": string}`。create の検証と一部 update は `{"errors": [string]}`（§2.1 の表） | `error` 72 / `errors` 18 | `errors`: crops `:128,283`、farms `:141,429`、fields `:87`、pests `:186,199,255`、pesticides `:210,224,269`、fertilizes `:191,205,247`、agricultural_tasks `:184,236`、interaction_rules `:169,223` | `error` 72 箇所（A）を `errors: [msg]` に変える（S1 は `error` を併記）。`errors` 18 箇所（C）は変更なし |
| 2 | `masters_crop_stages.rs` | 大半は `error`。order 競合などの検証失敗は `{"errors": ["invalid"]}` | `error` 16 / `errors` 3 | `errors`: `:254,304,371` | `error` 16 箇所（A）を変える。`errors` 3 箇所（C）は変更なし |
| 3 | `masters_crop_requirements.rs` | 404 / 409 は `error`、検証失敗は `errors`（要件 4 種 × create / update 相当） | `error` 32 / `errors` 8 | `errors`: `:168,240,340,412,512,584,684,756` | `error` 32 箇所（A）を変える。`errors` 8 箇所（C）は変更なし |
| 4 | `masters_crop_task_schedule_blueprints.rs` | 大半は `error` + `error_code`。検証失敗のみ `{"errors": [string], "error_code": "validation_failed"}` | `error` 13 / `errors` 1 / `error_code` 9 | `errors`: `:424`（型は `Vec<String>`: `crates/agrr-domain/src/crop/dtos/masters_crop_task_schedule_blueprint_create_failure.rs:15`）。`error_code`: `:392-424` | `error` 13 箇所（A）を `errors: [msg]` に変え、`error_code` は維持する。`:424`（C）は変更なし |
| 5 | `masters_crop_pests.rs` / `masters_crop_pesticides.rs` / `masters_crop_agricultural_tasks.rs` / `masters_farm_temperature_chart.rs` / `masters_crop_context.rs` | `error` のみ（`masters_crop_agricultural_tasks.rs:29-30` は廃止 API の `error` + `error_code`） | `error` 18 / `errors` 0 | `masters_crop_pests.rs:134-205`、`masters_crop_pesticides.rs:65`、`masters_farm_temperature_chart.rs:126-159`、`masters_crop_context.rs:41-52` | 18 箇所（A）を変える（`error_code` は維持） |
| 6 | `masters_crop_setup_proposal.rs` | 失敗は `error`（`:52,118`）。**検証結果は HTTP 200 の結果ペイロード** `{"mode","valid": false,"errors": [{path,message}]}` | `error` 2 / `errors` 1（200 本文） | `:84-97`（`:94`）、`errors_to_json` は `:144-154` | `error` 2 箇所（A）を変える。`errors` は「エラー本文」ではなく dry_run / apply の結果（課題 08 D-07）で、**失敗本文の契約の対象外（E）**。オブジェクト配列のまま変更しない |
| 7 | `masters_auth.rs` / `masters_rate_limit.rs` | `error` のみ（401 `unauthorized`、403 `forbidden` + `error_code: insufficient_scope`、429 `rate_limit`） | `error` 3 / `error_code` 1 | `masters_auth.rs:95-107`、`masters_rate_limit.rs:138-150` | 3 箇所（A）を変える。**文書化された外部契約が変わる**（`getting-started.md:57`。§3.8） |
| 8 | `plans.rs` / `public_plans.rs` / `public_plan_save.rs` | `error` のみ。`public_plan_save.rs` は `{"success": false, "error": string}`（`success` は付加情報） | `error` 18 / 9 / 4 | `plans.rs:129-511`、`public_plans.rs:249-546`、`public_plan_save.rs:57-64,78,91,110` | 31 箇所（A）を変える。`public_plans.rs` には #9 の `message` 形式が別に 4 箇所ある |
| 9 | `cultivation_plans_mutations.rs` / `cultivation_plans.rs` / `field_cultivation_climate.rs` / `field_cultivations.rs`（forbidden）/ `public_plans.rs`（`:601-616`） | `{"success": false, "message": string}`（**`message` が本文**。`error` は無い） | 32 / 5 / 5 / 1 / 4（計 47） | `cultivation_plans_mutations.rs:146-785`、`cultivation_plans.rs:62-105`、`field_cultivation_climate.rs:153-242`、`field_cultivations.rs:197`、`public_plans.rs:601-616` | 47 箇所（B）を `errors: [msg]` に変える（S1 は `message` を併記。`success: false` は付加情報として残す）。`cultivation_plans_mutations.rs:157` の 503 は `technical_details` も持つ |
| 10 | `field_cultivations.rs` | 大半は `error`。検証失敗のみ `{"success": false, "errors": [string]}` | `error` 14 / `errors` 1 | `errors`: `:201`（`flatten_error_messages()` の結果: `:179-180`） | `error` 14 箇所（A）を変える。`:201`（C）は変更なし |
| 11 | `task_schedules.rs` | `{"errors": [string]}`（401 / 404 / 500）。検証失敗（422）のみ**項目別 map** `{"errors": {field: [string]}}` | `errors` 21（配列 20 + map 1） | 配列: `:103,117,158,188,193,209,213,295,330,335,352,381,386,394,398,402,415,437,445,449`。map: `:112` | 配列 20 箇所（C）は変更なし。map 1 箇所（D）は `field_errors` を追加し、`errors` は S2 まで map のまま（§3.5） |
| 12 | `work_records.rs` | `{"errors": [string]}`（401 / 404 / 500 / destroy 失敗）、検証失敗は項目別 map、**409 は `{"error": "stale_record"}`** | `errors` 5（配列 4 + map 1）/ `error` 1 | 配列: `:175,182,196,429`。map: `:189`。`error`: `:270`（R4 `contracts.rs:348`） | 配列 4 箇所（C）は変更なし。map 1 箇所（D）は #11 と同じ。`:270`（A）を `errors: ["stale_record"]` に変える。同一ファイルで 2 形式が混在している |
| 13 | `work_record_photos.rs` | `{"errors": [string]}`（401 / 404 / 500）、検証失敗は項目別 map | `errors` 4（配列 3 + map 1） | 配列: `:184,191,209`。map: `:202` | 配列 3 箇所（C）は変更なし。map 1 箇所（D）は #11 と同じ |
| 14 | `plan_variance_learning.rs` / `weather_reschedule_proposals.rs` / `plan_vs_actual.rs` | `{"errors": [string]}` のみ（401 `unauthorized`、404 `not_found`、500 `internal_error`、検証失敗はメッセージ 1 件） | `errors` 24 / 8 / 4 | `plan_variance_learning.rs:165-592`、`weather_reschedule_proposals.rs:81-241`、`plan_vs_actual.rs:65-109` | 計 36 箇所（C）は変更なし。**`errors` 統合ではこの 36 箇所が「既に統合済み」** |
| 15 | `work_hub.rs` / `variance_portfolio.rs` / `entry_schedule.rs` / `deletion_undo.rs` / `internal_farms.rs` | `error` のみ。付加キー: `entry_schedule.rs:402` の `error_key`、`deletion_undo.rs:48,76` の `"status": "error"` | `error` 3 / 3 / 7 / 2 / 10 | `work_hub.rs:67,84,93`、`variance_portfolio.rs:84,124,133`、`entry_schedule.rs:215-518`、`deletion_undo.rs:48,76`、`internal_farms.rs:60-290` | 25 箇所（A）を変える。付加キーは据え置き（§3.9 Q10）。`entry_schedule.rs:215,221` の `weather_location_required` / `prediction_payload_missing` はフロントが `error` の値として比較している（§3.7.1） |
| 16 | `contact_messages.rs` | 429 `{"error":"rate_limit"}`、422（captcha）`{"error": msg}`、503 `{"error": msg}`、**検証 422 のみ** `{"errors": full_messages}` | `error` 3 / `errors` 1 | `:58-79`（検証は `:75`）。`full_messages()` はフィールド名を落として平坦化する: `crates/agrr-domain/src/shared/validation/validation_errors.rs:53-58` | `error` 3 箇所（A）を変える。検証 422（`:75`、C）は `errors` のまま変更なし。`field_errors`（`messages()`: 同 `:45-51`）を追加する |
| 17 | `organizations.rs` | ほぼ `error`。**create の検証失敗のみ** `{"errors": [string]}` | `error` 33 / `errors` 1 | `errors`: `:595`（`create_failure`: `:586-598`） | `error` 33 箇所（A）を変える。`:595`（C）は変更なし |
| 18 | `account.rs` / `api_keys.rs` / `auth_api.rs` / `ai_api.rs` | `error` のみ。`account.rs:64` は `error: "confirmation_required"` に加えて `message` も返す | `error` 9 / 3 / 2 / 16 | `account.rs:46,64,75`、`api_keys.rs:42`、`auth_api.rs:82,89`、`ai_api.rs:135-477` | 30 箇所（A）を変える。`account.rs:64` の `message` は付加情報で、フロントは `body.message \|\| body.error` で読んでいる（`account.component.ts:180-182`。§3.7.1） |
| 19 | `routes.rs`（スケジューラ認証）/ `fallback.rs` / `scheduler_weather_update.rs` | `error` のみ（`fallback.rs:16-18` は `error` + `message` + `path`、`scheduler_weather_update.rs:184` は `success: false` + `error`） | `error` 3 / 1 / 2 | `routes.rs:98,106,114`、`fallback.rs:15-19`、`scheduler_weather_update.rs:184,205` | 6 箇所（A）を変える。旧版が挙げていた `builtin_generation_deprecation.rs:185` は、`#[cfg(test)]`（`:114`）内のテスト期待値で本体の失敗本文ではない |
| 20 | `backdoor/routes.rs` | `error` 14 と `{"success": false, "errors": [...], "timestamp"}` 2 | `error` 14 / `errors` 2 | `:225,289`、パスは `/api/v1/backdoor/*`（`:28-36`） | **対象外（E）**（運用用のエンドポイントで、フロントの usecase は参照しない。統合に含めるかは §3.9 Q5） |

集計（`errors` 統合に必要な作業の量。詳細は §3.2.1）:

- `error` は **313 箇所**（うち #20 の 14 を除く **299 箇所**が変更対象 = 区分 A）。`errors` は 102 箇所（うち文字列配列 96 = 区分 C は変更なし、項目別 map 3 = 区分 D、対象外 3 = #6 の結果ペイロード 1 + #20 の 2）。`{"success": false, "message": ...}` 形式が **47 箇所**（区分 B）。
- Masters（`masters_*.rs` 全体）だけを数えると `error` 156 : `errors` 31、Plans 系（#8〜#15 のファイル）は `error` 71 : `errors` 67 でほぼ拮抗する（旧版は Plans 系の `error` を 61 と書いていたが、上表の #8 の 31 + #10 の 14 + #12 の 1 + #15 の 25 = 71 が正しい）。
- 項目別 map（`errors` が map）の 3 箇所は、フロントが専用に読んでいる（`usecase/plans/create-work-record.usecase.ts:31-33` ほか。§2.8）。

共通の下位パターン（同じ意味の失敗が別の形で書かれている実例。ヘルパー導入でここが 1 か所に集約される）:

| 意味 | 形 | 箇所数 / ファイル数 |
|------|----|--------------------|
| 401 未認証 | `{"error": "unauthorized"}` | 21 箇所 / 11 ファイル |
| 401 未認証 | `{"errors": ["unauthorized"]}` | 13 箇所 / 6 ファイル |
| 401 未認証 | `{"success": false, "message": "unauthorized"}` | 6 箇所 / 3 ファイル |
| 500 内部エラー | `{"error": "internal"}` | 88 箇所 / 23 ファイル |
| 500 内部エラー | `{"errors": ["internal"]}` / `["internal_error"]` / `{"error": "Internal server error"}` | 6 / 15 / 2 箇所 |
| 応答なし | `{"error": "no response"}` / `{"errors": ["no response"]}` / `{"message": "no response"}` | 17 / 4 / 7 箇所 |

### 2.8 エラー本文の読み手（フロント・外部クライアント・ドキュメント・テスト）

#### フロントエンド（`frontend/src/app`、spec 除く）

§2.2 の 24 usecase 以外にも、エラー本文のキーを読む箇所がある（`rg` で `.error` / `.errors` / `error_code` を抽出して確認）。

| 分類 | 読む項目 | 箇所 |
|------|----------|------|
| Masters の 24 usecase | §2.2、付録 A | `usecase/{crops,farms,pests,pesticides,fertilizes,agricultural-tasks,interaction-rules}/*.usecase.ts` |
| その他の `errors` 読み | `errors` のみ | `usecase/pests/load-pest-detail.usecase.ts:22`、`load-pest-for-edit.usecase.ts:22` |
| その他の `error` / `errors` 読み | `errors` → `error` または `error` → `errors` | `usecase/public-plans/create-public-plan.usecase.ts:36-40`、`usecase/plans/delete-plan.usecase.ts:30-31`、`usecase/farms/retry-farm-weather-fetch.usecase.ts:27-28`、`usecase/plans/field-climate/load-field-climate.usecase.ts:89-90`、`usecase/private-plan-create/create-private-plan.usecase.ts:31-45`、`usecase/public-plans/save-public-plan.usecase.ts:50-64` |
| その他の `error` 読み | `error` のみ | `usecase/farms/load-farm-temperature-chart.usecase.ts:29`、`usecase/work-hub/ensure-plan-for-farm.usecase.ts:71-77` |
| `error` を**キー / コード**として比較 | `error === 'plans.errors.plan_already_exists_annual'`、`error === 'weather_location_required'`、警告文言の判定 | `ensure-plan-for-farm.usecase.ts:17,72`、`core/api-error-i18n-key.ts:13-22`、`core/backend-warmup/backend-warmup.ts:74-80` |
| `message` 読み | `error.error.message`（`{success:false,message}` 形式向け） | `adapters/plans/gantt-plan-http.helpers.ts:3-8`（呼び出し: `gantt-plan-api.gateway.ts:105,142,171,204,233,266`） |
| `message` → `error` 読み | `body?.message \|\| body?.error` | `components/settings/account/account.component.ts:180-182` |
| `error_code` 読み | `error_code` | `core/crop-blueprint-regenerate-error-i18n.ts:19-26` |
| 項目別 map 読み | `errors` を `Record<string, string[]>` として読む | `usecase/plans/create-work-record.usecase.ts:31-35`、`update-work-record.usecase.ts:31-35`、`save-work-record-sheet.usecase.ts:54-58` |
| 状態コードのみ | 本文を読まない | contact（`usecase/contact/send-contact-message.usecase.ts:49-58`）、crop stage / blueprint 系（§2.1） |

観察:

- フロントは既に `error` を「i18n キーまたは機械コード」として比較する用途（上表の 3 箇所）に使っている。`errors`（配列）に統合すると、この 3 箇所の比較（と、`error` を翻訳して返す `create-private-plan`、`error` の有無で警告分類を決める `backend-warmup.ts`）は、そのままでは成立しなくなる。`errors` の要素との比較に移行する必要がある（§3.7.1）。
- 逆に `errors` は、Masters の 24 usecase のうち 16 件が既に読んでいる（create-crop、update-crop、create-farm、update-farm、pest / pesticide / fertilize / agricultural-task の create と update、delete-crop / pest / pesticide、create-interaction-rule。§2.1）。読めない 8 件（field の 3 操作、delete-farm / fertilize / agricultural-task / interaction-rule、update-interaction-rule）は、どちらの形でも共通関数への置換が必要で、`errors` 統合による追加コストではない。
- `contact` の spec は 422 の本文を `{ field_errors: {...} }` と想定している（`usecase/contact/send-contact-message.usecase.spec.ts:87-93`）が、サーバーは `field_errors` を返していない（§2.7 #16）。項目別詳細の名前としてフロント側に既に `field_errors` / `fieldErrors` がある（`usecase/plans/create-work-record.dtos.ts:15` ほか）。

#### 外部 API キー利用者に向けた契約

| 対象 | 内容 | 根拠 |
|------|------|------|
| `docs/api/getting-started.md` | 失敗本文として文書化されているのは 429 の `{ "error": "rate_limit" }` のみ。検証失敗の本文の形は書かれていない | `getting-started.md:57` |
| `docs/api/openapi.yaml` | `Error` スキーマは `error: string` と `errors: array<object>`。実装の `errors` は文字列配列なので不一致（課題 08 D-14） | `openapi.yaml:453-461` |
| 公式 MCP サーバー（リポジトリ内） | 失敗時、本文の `error` が非空ならそれを `Error.message` にし、無ければ `AGRR API <status> for <path>` にする。`errors` は読まない（本文全体は `err.body` に載る） | `tools/agrr-mcp/src/agrr-client.mjs:87-95`、テスト `tools/agrr-mcp/test/agrr-client.test.mjs:122-126` は 401 `{error}` のみ |
| スキル（サンプル） | dry_run の検証結果 `errors` を読む指示。これは #6 の結果ペイロードで、失敗本文ではない | `.cursor/skills/agrr-crop-setup/SKILL.md:34` |

含意: 現行の Masters の作成失敗（`errors` のみ）は、公式 MCP では汎用文言に落ちる。`errors` へ統合すると、文書化された 429（`getting-started.md:57`）と 401 / 403、および MCP の読み取り（`agrr-client.mjs:87-95`）が影響を受ける。MCP は `errors` を読む版へ更新すると、作成失敗の具体メッセージも得られる。更新前の MCP は、旧キーの併記が終わった後（S2 以降）に `Error.message` が `AGRR API <status> for <path>` に劣化する（本文は `err.body` に残る）。§3.8。

#### R4 契約テストと単体テストの期待値

`crates/agrr-r4-contract/tests/contracts.rs` の失敗本文の表明は 19 箇所（行: `348,411,636,1221,1626,1726,2123,2418,2442,2689,3043,3192,3280,3454,3471,3879,4502,4563,4595`。§4.3。`3043` は `error_code == "insufficient_scope"`）。`errors` を表明するのは次の箇所。

| 行 | 表明 | 対象 |
|----|------|------|
| `411`, `636` | `json["errors"]["name"]` / `["photos"]`（項目別 map） | work_records の検証、photos の `upload_init` |
| `1221` | `json["errors"][0] == "not_found"` | weather_reschedule_proposals の preview |
| `1626`, `1726` | `json["errors"].as_array()` | variance_learning の更新・reoptimize |
| `2418`, `2442` | `json.get("errors").is_some()` | crop_stages の create / update |
| `2689` | `response_body["errors"]` が空でない | setup_proposal の dry_run 結果（**結果ペイロード。変更なし**） |

それ以外（`348`,`2123`,`3192`,`3280`,`3454`,`3471`,`3879`,`4502`,`4563`,`4595`）は `error` を、`3043` は `error_code` を表明している。`entry_schedule.rs` のインラインテスト（`:818-880`）も `error` を表明する。インラインテスト全体の期待値は**未網羅**。`errors` 統合で S2 に更新が必要なのは、`error` を表明する 10 箇所と項目別 map を表明する 2 箇所の計 12 箇所である（§3.2.1、§4.3）。

### 2.9 共通のエラー型・レスポンスヘルパーの有無

結論: **無い。** 確認した内容:

- `crates/agrr-server/src` を `ApiError` / `fn error_response` / `fn json_error` / `fn unprocessable` / `fn bad_request` / `fn forbidden` で検索して 0 件。
- `internal_error()` が 10 ファイルに**個別に定義**されている: `masters_farm_temperature_chart.rs:156`、`work_hub.rs:90`、`masters_crop_context.rs:48`（`pub(crate)`。`masters_crop_pests.rs:4`、`masters_crop_task_schedule_blueprints.rs:7`、`masters_crop_setup_proposal.rs:4`、`masters_crop_pesticides.rs:4` が import）、`masters_fields.rs:358`、`work_records.rs:193`、`work_record_photos.rs:206`、`masters_farms.rs:394`、`variance_portfolio.rs:130`、`masters_crops.rs:380`、`organizations.rs:550`。ほかに `not_found()` が `work_records.rs:179`、`work_record_photos.rs:188` にある。
- `masters_json.rs` は entity → JSON の整形（`farm_to_json` ほか）で、エラー本文は扱わない（`masters_json.rs:1-25`）。
- 401 は `user_id_from_session` が `Result<i64, StatusCode>`（本文なし）を返し（`session_auth.rs:26`）、各 handler が `map_err(|status| (status, Json(...)))` で本文を組み立てている（例 `plans.rs:129-133`、`work_hub.rs:64-68`、`plan_variance_learning.rs:163-166`）。この 3 行のパターンで `error` / `errors` / `message` の 3 形式に分かれている（§2.7 の下位パターン表）。
- ドメイン側の `RecordInvalidError` などは表示用メッセージを持つが、HTTP の本文の形は知らない（`crates/agrr-domain/src/shared/exceptions/mod.rs:10,34-39`）。これは正しい責務分離で、変更しない。

---

## 3. あるべき契約（`errors` への統合）

### 3.1 現状の暗黙規約と、その限界

サーバーの実装から読み取れる暗黙の規約は次のとおり。

- 検証失敗（422）は `errors: string[]`
- 認可・存在しない・destroy 失敗・内部エラーは `error: string`

この規約に従わない箇所が広く残っている（§2.7）。

- Masters の crops / farms / fields の update、fields の create 失敗、destroy 全般（§2.1）
- 同一ファイルで両形式が混在する箇所: `work_records.rs`（`:270` は `error`、`:175-196` は `errors`）、`organizations.rs`（`:595` のみ `errors`）、`contact_messages.rs`（`:75` のみ `errors`）、`field_cultivations.rs`（`:201` のみ `errors`）
- `errors` が配列ではなく**項目別 map** になる箇所（`task_schedules.rs:112`、`work_records.rs:189`、`work_record_photos.rs:202`）
- 本文が `message` の `{"success": false, "message": ...}` 形式（47 箇所）
- 403 の扱いも揃っていない（pests / pesticides / fertilizes の update は 403 + `errors: ["forbidden"]`、agricultural_tasks / interaction_rules の update は 422 + `errors: ["forbidden"]`）。状態コードの整合は課題 10 の範囲であり、本書は**本文の形**だけを揃える

`errors` を統合先にすると、この「暗黙の規約」のうち検証失敗側を全面に広げ、`error` 側を吸収することになる。

Masters API は API キー（`Authorization: Bearer` / `x-api-key`）でも呼ばれる外部向け API である（`masters_auth.rs:1`、`crates/agrr-r4-contract/tests/contracts.rs:3034-3062`、`frontend/src/app/services/masters/masters-client.service.ts:21-24`）。**本文の形の変更は外部クライアントへの互換性の問題になる**（§2.8、§3.8）。

### 3.2 前回推奨（`error` 統合）の根拠を「`errors` 統合の追加コスト」として再整理

第 1 回の版は、次の事実を根拠に `error`（単数）への統合を推奨していた。第 2 回決定（§0.2）で統合先を `errors` にしたため、同じ事実は「統合先を `errors` にすると余分にかかる作業」を意味する。

| 前回の根拠（事実） | `errors` 統合での意味（追加コスト） | 詳細 |
|--------------------|--------------------------------------|------|
| `error` が約 313 箇所、`errors` が約 102 箇所（§2.7） | (a) サーバーで**変更が必要な箇所は 349**（`error` 299 + `message` 47 + 項目別 map 3）。前回の 146 の約 2.4 倍。`errors` の 96 箇所は変更なし | §3.2.1 |
| 401 / 500 の定型本文が大量に複製されている（§2.9） | (b) 共通ヘルパーを `errors` 前提で設計する。単一メッセージも `errors: [msg]`、任意の `error_code`、項目別は `field_errors` | §3.6 |
| フロントが `error` をコード / i18n キーとして比較している（§2.8） | (c) 共通純関数を `errors` 前提にし、24 usecase の置換に加え、`error` の値を比較している既存箇所（i18n キー解決、警告分類、`resolveActiverecordApiErrorI18nKey` の入力元）を移行する | §3.7、§3.7.1 |
| 外部契約 `getting-started.md:57` が `error`、公式 MCP `tools/agrr-mcp` が `error` を読む | (d) **文書化された外部契約の破壊的変更**。`getting-started.md`、`openapi.yaml` の `Error` スキーマ、MCP クライアントの読み取りを更新する必要がある。旧キーの併記期間とその終了ゲートを定義する | §3.5、§3.8 |

#### 3.2.1 (a) サーバーで変更が必要な箇所の全数

`crates/agrr-server/src/**/*.rs`（インラインテストを除く）を再集計した（付録 D-2）。`error` 単数を返している handler と、`{"success": false, "message"}` 形式を含める。

| 区分 | 現在の形 | 箇所数 | S1 で必要な作業 | 旧キーの併記 |
|------|----------|--------|-----------------|--------------|
| A | `{"error": string}`（`error_code` などの付加キー付きを含む） | **299**（313 のうち #20 backdoor の 14 を除く） | `errors: [msg]` を追加する | `error` を併記 |
| B | `{"success": false, "message": string}` | **47** | `errors: [msg]` を追加する（`success: false` は付加情報として残す） | `message` を併記 |
| C | `{"errors": [string, ...]}` | 96 | 変更なし（空配列にならないことの確認だけ。§8 R24） | 不要 |
| D | `{"errors": {field: [string]}}`（項目別 map） | **3**（`task_schedules.rs:112`、`work_records.rs:189`、`work_record_photos.rs:202`） | `field_errors` を追加する。`errors` は S2 まで map のまま | `errors`（map）自体が旧キー。S2 で文字列配列に変える |
| E | 対象外 | 3 | なし（`masters_crop_setup_proposal.rs:94` の結果ペイロード 1、`backdoor/routes.rs` の `errors` 2） | – |

- 変更対象は A + B + D = **349 箇所**。旧キーの併記が必要なのは A + B = **346 箇所**。
- A の内訳: Masters 系 156、Plans / 公開プラン系 71、その他（contact・organizations・account 系・スケジューラ認証）72（§4.2 の表）。
- A のうち `"error": "internal"` が 84 箇所（22 ファイル。全体の 88 箇所 / 23 ファイルから、対象外の `backdoor/routes.rs` の 4 箇所を除く）、`"error": "unauthorized"` が 21 箇所（11 ファイル）で、ヘルパーに集約すれば個別の書き換えは 105 箇所分減る（§3.6）。
- `error_code` を持つ 11 箇所（blueprint 9、`masters_auth.rs` 1、`masters_crop_agricultural_tasks.rs` 1）は `error_code` を維持し、`error` だけを `errors: [msg]` に置き換える。
- R4 契約テスト（`contracts.rs`）の失敗本文の表明 19 箇所（§2.8）のうち、**S2 で変更が必要なのは 12 箇所**: `error` を表明する 10 箇所（`348,2123,3192,3280,3454,3471,3879,4502,4563,4595`）と、項目別 map を表明する 2 箇所（`411,636`）。`errors` の配列を表明する 5 箇所（`1221,1626,1726,2418,2442`）、`error_code` の 1 箇所（`3043`）、結果ペイロードの 1 箇所（`2689`）は変更不要。S1 の期間は旧キーが併記されるため、既存の 19 箇所はすべて通ったまま。
- 変更しない範囲（#20 の backdoor）を含めるかは §3.9 Q5。

### 3.3 統合契約（`errors`）の仕様

```json
{
  "errors": ["<非空文字列: i18n キー、または人間可読メッセージ>", "..."],
  "error_code": "<任意: 機械可読コード>",
  "field_errors": { "<field>": ["<message>", "..."] }
}
```

| # | 規則 |
|---|------|
| C1 | Masters / Plans 系の 4xx / 5xx の本文は JSON オブジェクトで、`errors`（1 件以上の非空文字列の配列）を必ず含む |
| C2 | 単一メッセージも `errors: ["<msg>"]` とする。複数の検証メッセージは**結合せず**要素を分ける。`ValidationErrors::full_messages()`（`validation_errors.rs:53-58`）の順序をそのまま使う |
| C3 | `errors` に配列以外（項目別 map、オブジェクト配列）を入れない。例外は 2 つ。(i) HTTP 200 / 201 の**結果ペイロード**（`masters_crop_setup_proposal.rs:84-97` の `errors: [{path, message}]`）は失敗本文ではないため対象外。(ii) 移行期間（S1〜S2）に限り、項目別 map の 3 箇所（区分 D）は `errors` が map のまま（§3.5） |
| C4 | `error`（単数）と `message` は失敗の主メッセージにしない。S1 の間だけ旧キーとして併記し（deprecated）、S2 で削除する。`success: false` など他の付加情報は許容する |
| C5 | 項目別の検証メッセージが必要な API（work record、photos、task schedule、contact）は、`field_errors` に `{field: [message]}` を追加する。名前は既存のフロント側の語彙（`field_errors` / `fieldErrors`）に合わせる。同じメッセージを平坦化した文字列配列を `errors` にも入れる（S2 以降。D の 3 箇所は S2 で map から平坦化に変わる） |
| C6 | `error_code` は既存の名称・値を維持する（`insufficient_scope`: `masters_auth.rs:98`、blueprint 系: `masters_crop_task_schedule_blueprints.rs:392-424`、廃止 API: `masters_crop_agricultural_tasks.rs:29-30`）。値は自由文字列（課題 08 D-03 の推奨と一致）。機械判定に使う識別子は、新規のものは `error_code` に置く |
| C7 | 409 の `stale_record` は機械コード（`masters_crops.rs:310`、`work_records.rs:270`）で、`errors: ["stale_record"]` とする。フロントは状態コード 409 で判定する（§3.7） |
| C8 | 付加情報（`success`、`status`、`error_key`、`path`、`timestamp`、`technical_details`）は許容する。共通リーダーは参照しない |
| C9 | HTTP ステータスは本書で変えない（課題 10 の範囲） |

`errors` の要素の中身（i18n キーか、英語リテラルか）は本書で変えない。edit 系 presenter が検証文言を汎用メッセージに丸める挙動（§2.3）は Q7 の範囲。

### 3.4 フロント: 旧形式（`error` / `message`）を許容するか

**推奨: 統合後は許容しない。**

| 選択肢 | 内容 | 評価 |
|--------|------|------|
| **許容しない（推奨）** | 共通関数は `errors` / `error_code` / `field_errors` だけを読む。`error` と `message` は無視して状態コード由来のキーに退避する | 「統合」の意図と一致し、読み取り経路が 1 つになる。旧形式への互換負担は**サーバーの一時併記**（§3.5）に集約される |
| 一定期間許容する | 共通関数が `error` / `message` も読む | フロント先行のデプロイが可能になるが、「許容の終了」を保証する機構が無い。フロントの旧形式利用は計測手段も無く（§8 R14）、削除タスクの残置になる。`no-convenience-tech-debt.mdc` の「技術負債は残置しない」と衝突するため採らない |

許容しないことは、テストで固定する（§6.2 T1: `{error:'a'}` を読まないこと）。

### 3.5 移行方式とデプロイ順序（旧キー併記の再設計）

#### 併記の要否

`errors` 統合でも**旧キーの併記は必要**である。理由は、旧フロント（F0）と外部クライアントが、次の箇所で `error` / `message` を読むためである。

- F0 は `error` の値を 15 ファイルで読む（`ensure-plan-for-farm`、`delete-plan`、`load-field-climate`、`save-public-plan`、`create-public-plan`、`create-private-plan`、`delete-crop`、`delete-pesticide`、`delete-pest`、`create-interaction-rule`、`retry-farm-weather-fetch`、`load-farm-temperature-chart`、`account.component`、`api-error-i18n-key`、`backend-warmup`。`rg` による抽出で、取りこぼしの可能性は §8 R8）。`message` は gantt ヘルパー（`gantt-plan-http.helpers.ts:3-8`）と `account.component`（`:180-182`）が読む。
- 警告分類が `error` の有無に依存する。`backend-warmup.ts:74-80` の `httpErrorBodyCode` が本文の `error` を読み、`isEntryScheduleWeatherHttpError`（`:84-106`）が「`error` があり、かつ 503 で daemon 系の文字列でなければ、警告ではなく明示的な失敗」と分類する。`error` が消えると 503 が警告扱いになり、GET は 2 秒間隔で最大 30 回再試行される（`retry-backend-warmup.ts:5-6`）。
- 外部の API キー利用者と公式 MCP（`agrr-client.mjs:87-95`）は `error` を読む。文書化された 429 の本文も `error` である（`getting-started.md:57`）。

#### 移行方式の比較

| 方式 | 内容 | 判定 |
|------|------|------|
| **M1: サーバーが `errors` を追加し旧キーを一時併記 → フロントを `errors` 1 系統に → 旧キー削除（推奨）** | S1: 全対象箇所に `errors` を追加し、A は `error`、B は `message` を併記する（D は `field_errors` を追加）。F1: フロントを厳格版に切り替える。S2: 旧キーを削除し、D の `errors` を文字列配列にする | 3 回のリリースで、各時点で旧フロント・新フロントの双方が壊れない |
| M2: 併記なしの一斉切替 | S と F を同じ変更で切り替える | サーバー（Cloud Run）とフロント（GCS + CDN）は別デプロイで原子的でなく、中間状態で退行する。外部クライアントも即座に影響する。不採用 |
| M3: フロント先行 | F1 を先に出す | F1 は `errors` しか読まない。A の 299 箇所と B の 47 箇所は `errors` を持たない（S0）ため、destroy 系、認証、Plans 系などが状態コード由来の汎用文言に劣化する。不採用 |
| M4: サーバー先行だが旧キーを併記しない | S1 で `error` / `message` を返さない | F0 が上記の箇所で `error` / `message` を読めず、警告分類が変わる。不採用 |

`deploy-server`（Cloud Run。[`SKILL.md`](../../.cursor/skills/deploy-server/SKILL.md)）と `deploy-frontend`（`.cursor/skills/deploy-frontend/scripts/gcp-frontend-deploy.sh`）は別のスキル・スクリプトである。フロントは `index.html` が `no-cache`（`gcp-frontend-deploy.sh:397,408`）、ハッシュ付きアセットが `immutable`（`:436`）で、CDN 無効化は `URL_MAP_NAME` が設定されている場合のみ実行される（`:470-478`）。開いたままのタブは旧バンドルで動き続け、バージョン確認による強制更新の仕組みは見つからなかった（`frontend/src` で `SwUpdate` / `checkForUpdate` / `version.json` を検索して該当なし）。

#### 項目別 map の 3 箇所（区分 D）だけは併記できない

`errors` は `error` と違い、同じキーの**型**が変わる（map → 文字列配列）。F0 の `create-work-record.usecase.ts:31-35` などは `errors` を `Object.keys(...)` で map として扱うため、文字列配列が来ると `onValidationError({ fieldErrors: <配列> })` が呼ばれ、`work-record-sheet.component.ts:1018` の `this.control.fieldErrors[field]` が `undefined` になって項目別エラーが表示されなくなる（コード読解。実画面は未確認）。したがって次の順序にする。

1. S1: `field_errors` を**追加**し、`errors` は map のまま残す（C3 の例外 ii）。
2. F1: 項目別エラーを `field_errors` から読む。`errors` が map のときは無視する（§3.7 の `errors` は「非空の文字列配列」だけ読む）。
3. S2: `errors` を平坦化した文字列配列にする。

`task_schedules.rs:112` の map をフロントのどの箇所が読んでいるかは特定できていない（§2.8 の項目別 map 読みは work record の 3 usecase のみ）。S2 の前に確定する（§3.5 のゲート 5）。

#### 中間状態ごとの影響

| 中間状態 | 影響 | 判定 |
|----------|------|------|
| S1 × 旧フロント（F0） | F0 が読む `error` / `message` は併記されているため従来どおり。F0 が `errors` のみを読む update 系（crop / farm）は、従来は本文が `error` で読めなかったが、`errors` が加わるため**改善**する。D の map は変わらない | 非退行 |
| S1 × F1 | F1 は `errors` を読む。S1 は全対象箇所（D を除く）で `errors` を返す。D は `field_errors` を返す | 正常 |
| S0（現状）× F1（フロント先行） | A の 299 箇所と B の 47 箇所が `errors` を持たないため、F1 は状態コード由来の汎用文言に劣化する。work record の項目別エラー（`field_errors` が無い）が表示されなくなる | **退行。禁止** |
| S1 → S2 を F1 の反映前に実施 | F0 は `error` / `message` を読めなくなる。警告分類が変わり、D の map が文字列配列になって項目別エラーが消える | **退行。順序ガードが必要** |
| F1 稼働中に S1 を S0 へロールバック | S0 は A / B に `errors` を持たないため F1 が劣化する | S1 のロールバックは F1 のロールバックと同時に行う（§8 R15） |
| F1 稼働中に S2 済み | 正常（F1 は旧キーを読まない） | 正常 |
| 外部クライアント（S2 以降） | `error` / `message` を読んでいた利用者は読めなくなる。公式 MCP は更新版に置換すれば読める（§3.8） | Q2 の承認が前提（§3.9） |

#### 旧キー（`error` / `message`）削除（S2）の実施ゲート（日時ではなく条件で定義する）

1. F1 が本番に反映済みで、CDN 無効化が実行されたことをデプロイのログで確認している。
2. S2 用の R4 テスト（旧キーが**存在しない**こと）が RED であることを確認済み（§6.3 S-T2）。
3. `docs/api/getting-started.md` と `docs/api/openapi.yaml` に、`errors` を主とする失敗本文の形と、`error` / `message` の廃止（S1 の時点で `deprecated`）が反映され、公開済みである（課題 08、03 と同一ファイルを編集するため順序に注意）。
4. 公式 MCP クライアント（`tools/agrr-mcp`）が `errors` を読む版に更新され、テストが GREEN である（§3.8）。
5. リポジトリ内に `error` / `message` を失敗本文から読むフロントのコードが無い（`rg` 条件は §8 R8）。かつ、区分 D の 3 箇所を読むフロントの箇所（work record の 3 usecase と、`task_schedules.rs:112` の読み手）が `field_errors` に移行済みである。
6. 外部利用者の依存について、確認できた、または確認手段が無いことをユーザーが承認した（Q2）。

ゲート 1〜5 は機械的に確認できる。ゲート 6 だけは人の判断であり、未承認の間は S2 を実施せず、S1 の併記を維持する。併記の期間は日時では定めない。

### 3.6 共通エラー型・レスポンスヘルパーの導入（(b)。LAYER-RULES R6 / R7 に照らす）

**推奨: 導入する。** 既存の共通ヘルパーは無く（§2.9）、単一形式は各箇所の規律に依存している。現状の 4 形式・401 の 3 形式・`"internal"` の 88 重複（§2.7）は、規律だけでは維持できなかった実績である。`errors` 統合では変更箇所が 349 になるため、手作業を減らす効果も大きい。

案（`crates/agrr-server/src/api_error.rs`。`lib.rs` に `pub mod api_error;` を追加）:

```rust
pub type ApiError = (StatusCode, Json<Value>);

/// {"errors": [msg]}。単一メッセージ。
pub fn api_error(status: StatusCode, message: impl Into<String>, legacy: Legacy) -> ApiError;
/// {"errors": [msg], "error_code": code}
pub fn api_error_with_code(status: StatusCode, message: impl Into<String>, code: &str, legacy: Legacy) -> ApiError;
/// {"errors": [m1, m2, ...]}。既に errors だった箇所（区分 C）用。空は 500 として扱う。
pub fn api_errors(status: StatusCode, messages: Vec<String>) -> ApiError;
/// {"errors": [平坦化したメッセージ], "field_errors": {...}}。S1 は Legacy::ErrorsMap で errors を map のまま出す。
pub fn api_field_errors(status: StatusCode, fields: &BTreeMap<String, Vec<String>>, legacy: Legacy) -> ApiError;
/// 付加情報（success / technical_details / error_key など）を足す。
pub fn with_extra(err: ApiError, extra: serde_json::Map<String, Value>) -> ApiError;
pub fn unauthorized(legacy: Legacy) -> ApiError;   // 401 {"errors": ["unauthorized"]}
pub fn internal_error() -> ApiError;               // 500 {"errors": ["internal"]}
```

`Legacy` は移行期間（S1）だけの引数で、旧キーの併記を 1 か所（`attach_legacy_keys`）に閉じ込める。

| `Legacy` の値 | 併記するキー | 使う箇所（従来の形） |
|---------------|--------------|----------------------|
| `None` | なし | 従来から `errors` だった箇所（区分 C の 96 箇所）と新規の失敗 |
| `Error` | `error: <errors[0]>` | 従来 `error` だった箇所（区分 A の 299 箇所。うち 105 箇所は `unauthorized` / `internal_error` に集約） |
| `Message` | `message: <errors[0]>` | `{success:false, message}` の 47 箇所（区分 B） |
| `ErrorsMap` | `errors: {field: [..]}`（従来の map と同一） | 項目別 map の 3 箇所（区分 D）。S1 のみ |

`api_error` は単一メッセージ専用で、`Legacy::Error` / `Message` の併記値は `errors[0]` と一致する。複数メッセージを持つ箇所（区分 C）は従来から `errors` なので、`api_errors` は `legacy` 引数を持たない。`api_errors` に空配列が渡された場合は、失敗の理由が無い本文になり C1 に反するため、`tracing::error!` を出して 500 の `errors: ["internal"]` にする（サーバー側の不具合として可視化する。クライアント向けの成功風の応答にしない）。

S2 では `Legacy` 型、`attach_legacy_keys`、`api_error` 系の `legacy` 引数を削除する。呼び出し側は**コンパイルエラーで一覧できる**ため、削除漏れが起きない。

LAYER-RULES との照合:

| 規則 | 適合の根拠 |
|------|-----------|
| R1（ドメインはフレームワーク非依存） | ヘルパーは `agrr-server`（エッジ）に置く。`agrr-domain` は変更しない。ガードが禁止するのはドメインでの `use axum` などである（`scripts/run-architecture-guard-lib.mjs:11-17`）。ドメインの表示用メッセージ（`RecordInvalidError::detail_message`: `shared/exceptions/mod.rs:21-23`）は据え置く |
| R6（Presenter は HTTP の整形のみ。データ取得・副作用なし） | ヘルパーは本文の整形だけで、I/O・取得・翻訳を持たない。出力ポート実装（各 handler ファイル内の `on_failure`。例 `masters_crops.rs:298-315`）から呼ぶ |
| R7（薄い HTTP エッジ） | inline の `json!` を関数呼び出しに置き換えるため、エッジはむしろ薄くなる。ガードの R7 検査は「route handler が interactor に委譲しているか」で（`run-architecture-guard-lib.mjs:180-204`）、ヘルパー追加の影響を受けない |
| R0 / R5 | 認可・判定・rescue による分岐を持たない。どの失敗をどの状態コード・メッセージにするかは、従来どおり presenter / handler が決める |
| R9（契約先行） | 契約は R4 契約テスト（観測可能な本文）で固定する（§6.3）。ヘルパーの単体テストは補助 |
| R8 | 責務の置き場所の移動ではなく、重複の集約である。LAYER-RULES は presenter を `agrr-adapters-*` と書くが、実際の出力ポート実装は handler ファイル内にある（`masters_crops.rs:292`）。この実態の是正は本書の範囲外 |

`masters_json.rs` は entity の JSON 整形専用であるため、エラー本文のヘルパーは混ぜず別モジュールにする。

導入しない場合の代替は、機械ゲートだけで維持する方法である。ただし `"internal"` の 88 重複と 401 の重複は残り、S1 / S2 の変更も 346 + 3 箇所の手作業になる。

**機械ゲート（提案。Q9）**: `scripts/run-architecture-guard-lib.mjs` に、`crates/agrr-server/src` で失敗本文に `"error"` / `"message"` キーを直接書くことを禁止する検査を足す（許可リスト: `api_error.rs`、`backdoor/routes.rs`。結果ペイロード `masters_crop_setup_proposal.rs` の `errors` は `"errors"` のみを対象としないため検査に掛からない）。テストは `scripts/run-architecture-guard-lib.test.mjs` に追加する（CI: `.github/workflows/lint.yml:26,29`）。S2 の前は A / B の併記が `api_error.rs` に閉じるため、この検査は S1 の各コミットで段階的に有効にできる。

### 3.7 フロント: 共通純関数（(c)。`core/api-error-message.ts` 案）の契約

読み取りは次の関数だけを公開する。**翻訳はしない**（純関数）。翻訳は既存の表示層（`FlashMessageService` → `translateServerToastMessage`）に任せる。

本文の解釈は下位モジュール `core/api-error-body.ts`（`HttpErrorResponse` の型以外に依存しない純関数）の 1 か所に置く。`backend-warmup.ts` が本文の `errors` を読む必要があるが、`api-error-message.ts` は `api-error-i18n-key.ts` を経由して `backend-warmup.ts` を import するため、`api-error-message.ts` に解釈を置くと循環参照になる（`api-error-i18n-key.ts:2-6` が `backend-warmup` を import している）。

| 関数 | 入力 → 出力 |
|------|-------------|
| `apiErrorMessages(err: unknown): string[]` | `HttpErrorResponse` の本文が `errors` を**文字列配列**として持つとき、空白のみの要素を除いた配列。それ以外（`errors` が無い、map、オブジェクト配列、非文字列要素だけ）は `[]` |
| `apiErrorMessage(err: unknown): string` | `HttpErrorResponse` で 409 → `common.api_error.conflict`（サーバー本文は機械コード `stale_record`）。`HttpErrorResponse` で `apiErrorMessages(err)` が非空 → `', '` で結合した文字列（現行の表示と同じ）。それ以外の `HttpErrorResponse`（本文なし、旧形式の `error` / `message`、配列以外の `errors`） → `apiErrorI18nKey(err)`（`core/api-error-i18n-key.ts:29-57`）。`HttpErrorResponse` 以外の `Error` → `err.message`（空なら `common.api_error.generic`）。それ以外 → `common.api_error.generic` |
| `apiErrorHasMessage(err: unknown, key: string): boolean` | `apiErrorMessages(err)` が `key` を**要素として**含むか。i18n キーやコードとの比較専用（§3.7.1） |
| `apiErrorCode(err: unknown): string \| null` | 本文の `error_code` が非空文字列ならその値、それ以外は `null` |
| `apiFieldErrors(err: unknown): Record<string, string[]> \| null` | 本文の `field_errors` が「値がすべて文字列配列のオブジェクト」ならその値、それ以外は `null` |

`core/backend-warmup/backend-warmup.ts:16-28` の `errorBodyText`（本文全体の文字列化による GCE ウォームアップ判定）は契約の読み取りではないため対象外。

#### 3.7.1 `error` をコード / i18n キーとして比較している既存箇所の移行

現行では `error` の値そのものを比較・翻訳・分類に使っている箇所がある。`errors` 統合では、比較対象を `errors` の**要素**にする。単一メッセージは `errors: [key]` になるため、比較は `apiErrorHasMessage(err, key)`（または `apiErrorMessages(err)[0]`）に置き換える。

| 箇所 | 現行 | `errors` 前提の移行 |
|------|------|--------------------|
| `usecase/work-hub/ensure-plan-for-farm.usecase.ts:17,71-72` | 422 かつ `body.error === 'plans.errors.plan_already_exists_annual'` | `apiErrorHasMessage(err, PLAN_ALREADY_EXISTS_KEY)` |
| 同 `:75-79`（`resolveErrorMessage`） | `body.error?.trim()` をそのまま返す | `apiErrorMessage(err)` |
| `core/api-error-i18n-key.ts:13-22`（`entryScheduleWeatherApiErrorI18nKey`） | 本文の `error` が `weather_location_required` か | `apiErrorHasMessage(err, 'weather_location_required')` |
| `core/backend-warmup/backend-warmup.ts:74-106`（`httpErrorBodyCode`、`isEntryScheduleWeatherHttpError`） | 本文の `error` が非空文字列なら「明示的な失敗」（503 で daemon 系の文字列でなければ警告ではない）。`prediction_payload_missing` / `weather_location_required` の比較 | `core/api-error-body.ts` の `errors[0]` を使う。判定規則は同じで、`error` の代わりに `errors[0]` を見る。**挙動の差**は §8 R22 |
| `usecase/private-plan-create/create-private-plan.usecase.ts:31-36` | `error` を `translate.instant` に通し、翻訳できればその結果、できなければキー | `apiErrorMessages(err)` の各要素を `translate.instant` に通してから結合する。`errors` の結合後文字列はキーとして翻訳できないため、要素単位で翻訳する |
| `usecase/public-plans/save-public-plan.usecase.ts:50-64` | `error` 優先、次に `errors` の結合 | `apiErrorMessage(err)`（§5.2 で `translateServerToastMessage` に通す） |
| `usecase/farms/create-farm.usecase.ts:28-34`、`domain/farms/farm-create-limit.ts:19`（`resolveActiverecordApiErrorI18nKey`） | `errors` を結合した文字列を、リテラル対応表で `ACTIVERECORD_FARM_LIMIT_EXCEEDED_KEY` に写す | 入力元を `apiErrorMessage(err)` にする。関数の署名と判定（`resolveActiverecordApiErrorI18nKey(message) === KEY`）は変えない。`errors` が複数要素で上限キーが混ざると結合後に一致しない点は現行と同じ（要素単位の判定に変えるかは範囲外） |
| `components/settings/account/account.component.ts:180-182` | `body?.message \|\| body?.error` | `apiErrorMessage(err)`（旧キーを読まない） |
| `adapters/plans/gantt-plan-http.helpers.ts:3-8` | `error.error.message` | `apiErrorMessage(error)` |
| `core/crop-blueprint-regenerate-error-i18n.ts:19-26` | `error_code` | 変更なし（`error_code` は維持。`apiErrorCode` への載せ替えは任意） |
| `retry-farm-weather-fetch`、`delete-plan`、`load-field-climate`、`create-public-plan`、`delete-crop`、`delete-pest`、`delete-pesticide`、`create-interaction-rule`、`load-farm-temperature-chart` | `error` 優先または `errors` 優先の混在 | `apiErrorMessage(err)` に統一 |

既存 spec のうち、本文の fixture を `error` / `message` で書いているものは `errors` に書き換える（`error: { error: ... }` を持つ spec が 14 ファイル、`error: { message: ... }` が 2 ファイル。§4.3）。

### 3.8 外部契約の破壊的変更（(d)）

| 対象 | 現状 | `errors` 統合での更新 |
|------|------|------------------------|
| `docs/api/getting-started.md:57` | 失敗本文として文書化されているのは 429 の `{ "error": "rate_limit" }` のみ | `{ "errors": ["rate_limit"] }` に更新し、失敗本文の形（`errors` 必須、`error_code` / `field_errors` 任意）の節を足す。S1 の期間は `error` も併記される旨を `deprecated` として書く |
| `docs/api/openapi.yaml:453-461`（`Error` スキーマ） | `error: string` と `errors: array<object>` | `errors: array<string>`（必須、1 件以上）、`error_code: string`、`field_errors: map<string, array<string>>`。`error` と `message` は S1 の間 `deprecated: true` で残し、S2 で削除する（課題 08 D-03 / D-14） |
| 公式 MCP クライアント `tools/agrr-mcp/src/agrr-client.mjs:87-95` | 本文の `error` が非空ならそれを `Error.message` にし、無ければ `AGRR API <status> for <path>` にする。`errors` は読まない | `errors` が非空の文字列配列なら `', '` で結合して `Error.message` にする。`error` は読まない。テスト `tools/agrr-mcp/test/agrr-client.test.mjs:122-126` の fixture（401 `{error: 'unauthorized'}`）を `errors` に書き換え、422 の複数メッセージのテストを足す |
| 更新しない MCP の利用者（S2 以降） | – | `Error.message` が `AGRR API <status> for <path>` に**劣化**する（本文は `err.body` に残る）。読み取りが失敗するのではなく具体メッセージが失われる |
| API キー経由のクライアント全般 | `error` を読んでいるかは、リポジトリ内では計測できない（調査の限界） | S1 の間は併記で非破壊。S2 は Q2 の承認が前提 |
| `.cursor/skills/agrr-crop-setup/SKILL.md:34` | dry_run の結果 `errors`（`{path, message}`）を読む | 変更なし（結果ペイロード。C3 の例外 i） |

MCP はこのリポジトリ内のコードであり、`errors` を読む版への更新は S2 の前提（ゲート 4）として本書の範囲に含める。

### 3.9 ユーザー確認が必要な点

旧 Q1（統合先の選択）は、第 2 回決定（§0.2）で確定したため削除した。番号は他の節からの参照を保つため詰めない。

| # | 確認事項 | 既定（未回答時の進め方） |
|---|----------|--------------------------|
| Q2 | **旧キー（`error` / `message`）削除 S2 の実施可否**と、外部 API キー利用者が `error` / `message` に依存していないかの確認（§3.5 のゲート 6） | 依存が確認できない間は S2 を実施しない。S1（併記）は維持する |
| Q3 | 項目別の検証情報の名前 `field_errors` | `field_errors` |
| Q4 | 共通ヘルパー `api_error.rs` の導入（§3.6） | 導入する |
| Q5 | 適用範囲。既定は Masters・Plans 系・公開プラン系・contact・organizations・account 系・スケジューラ認証（§2.7 の #1〜#19 の区分 A / B / D）。運用用の backdoor（#20）は対象外 | 左記 |
| Q6 | `public_plan_save` の `record invalid: ` 接頭辞をサーバーで除去してよいか（`public_plan_save_interactor.rs:127-128`、`plan_save_session.rs:109`）。既存クライアントが接頭辞付き文字列に依存していないか | 除去する（S3）。フロントは接頭辞を扱わない |
| Q7 | edit / detail 系 presenter が検証文言を `common.api_error.generic` に丸める挙動（`error-dto-i18n-key.ts:16-38`）を、キー形式または既知コードに限り表示するよう変えるか | 変えない。usecase の共通関数適用までを範囲とする |
| Q8 | Crop 上限の事前チェックを管理者に適用するか。管理者は参照作物なら上限対象外（`crop_create_limit_policy.rs:5-10`） | 非管理者のみ事前チェック。管理者はサーバーエラー時のブロック表示のみ |
| Q9 | 機械ゲート（失敗本文への `error` / `message` キー直書きの禁止）を `run-architecture-guard-lib.mjs` に足すか | 足す |
| Q10 | 付加情報の `error_key`（`entry_schedule.rs:402`、`backdoor/routes.rs:62`）を `error_code` に統一するか。フロントは `error_key` を参照していない（`frontend/src` で該当なし） | 据え置く（付加情報。C8） |
| Q11 | Crop 上限のコピー文言（`crops.new.limit_reached` ほか）と Hindi 訳の確認者。既存の Farm 文言は `farms.new.limit_reached`（`ja.json:1062`）を踏襲する | Farm と同型の文言を ja / en / in で新規追加 |
| Q12 | フロントの適用範囲。既定は 24 usecase に加えて §2.8 の本文リーダーすべて。本文を読まない usecase（crop stage 更新の `err.message`、blueprint 系の状態コードのみ）は、契約が単一になったため共通関数へ載せ替えることもできるが、既定では範囲外 | 左記 |
| Q13 | `resolveActiverecordApiErrorI18nKey` の Crop リテラル（`'作成できるCropは20件までです'` 等）を対応表に足すか。現行サーバーはキーを返すため不要の見込み（§2.6） | 足さない。定数と判定関数のみ追加 |
| Q14 | サーバー送出キーのうち、AI 生成系（`api.*by_ai`、`api.errors.pests.*` 等）と `activerecord...user.blank` 系（通常到達しない）まで欠落を埋めるか。`farms.flash.cannot_delete_in_use` は、カタログにサブキーを足す案と、サーバーでサブキーに変更する案のどちらか | 本課題では Crop / Farm / Field の到達する経路と、コードから参照される 7 件に限定 |
| Q15 | Farm の事前チェック（component が gateway を直接購読）を use case 経由に是正するか | 是正しない。Crop のみ use case 経由で新規実装 |

---

## 4. 影響範囲

### 4.1 フロントエンド

| 層 | ファイル | 変更内容（概要） |
|----|----------|------------------|
| `core/` | `api-error-body.ts`（新規。本文の解釈）、`api-error-message.ts`（新規。公開関数）、`api-error-i18n-key.ts:13-22`、`crop-blueprint-regenerate-error-i18n.ts:19-26`（任意）、`backend-warmup/backend-warmup.ts:74-106`、`i18n/resolve-activerecord-api-error-i18n-key.ts` | 共通の純関数（§3.7）。`error` を比較している箇所を `errors` の要素比較に移行（§3.7.1）。Crop 定数の追加 |
| `domain/` | `domain/crops/crop-create-limit.ts`（新規）、`domain/farms/farm-create-limit.ts`（参照のみ） | Crop 上限の定数・件数・判定 |
| `usecase/` | Masters 24 usecase（表 §2.1）、その他の本文リーダー（§2.8: `load-pest-detail`、`load-pest-for-edit`、`create-public-plan`、`delete-plan`、`retry-farm-weather-fetch`、`load-field-climate`、`create-private-plan`、`save-public-plan`、`load-farm-temperature-chart`、`ensure-plan-for-farm`）、work record 3 usecase（`errors` の map → `field_errors`）、`crops/load-crop-create-limit.*`（新規: DTO / input port / output port / usecase / providers） | 共通関数の適用、`error` の比較の移行、項目別エラーの読み取り元の変更、上限チェックの usecase |
| `adapters/` | `adapters/plans/gantt-plan-http.helpers.ts`、`adapters/crops/crop-create.presenter.ts` | `message` 読みの廃止、`limitBlocked` / `limitCheckLoading` の反映 |
| `components/` | `components/settings/account/account.component.ts:180-182`、`components/masters/crops/crop-create.component.ts`、`crop-create.view.ts` | 本文読みの共通関数化、事前チェックの呼び出し、ブロック表示 |
| i18n | `assets/i18n/{ja,en,in}.json` | `crop_limit_exceeded`（`in`）、`crops.new.limit_*`（3 言語）、サーバー送出キーの欠落、コード参照の欠落 7 件 |

### 4.2 バックエンド（Q2〜Q5 の回答により実施）

変更対象の箇所数は §2.7 と §3.2.1 の集計に基づく（区分 A = `error` 299、B = `message` 47、D = 項目別 map 3。区分 C の 96 箇所は変更なし）。

| 層 | ファイル | 区分と箇所数 | 変更内容 |
|----|----------|--------------|----------|
| edge（新規） | `crates/agrr-server/src/api_error.rs`、`lib.rs` | – | 共通ヘルパー（§3.6）。既存の `internal_error()` の 10 個の定義を置換 |
| edge（Masters） | `masters_{crops,farms,fields,pests,pesticides,fertilizes,agricultural_tasks,interaction_rules}.rs`、`masters_crop_stages.rs`、`masters_crop_requirements.rs`、`masters_crop_task_schedule_blueprints.rs`、`masters_crop_{pests,pesticides,agricultural_tasks,context,setup_proposal}.rs`、`masters_farm_temperature_chart.rs`、`masters_auth.rs`、`masters_rate_limit.rs` | A 156（72 + 16 + 32 + 13 + 18 + 2 + 3） | `error` を `errors: [msg]` に変更（S1 は `Legacy::Error` で `error` を併記。`error_code` は維持） |
| edge（Plans / 公開プラン系） | `plans.rs`（18）、`public_plans.rs`（9）、`public_plan_save.rs`（4）、`field_cultivations.rs`（14）、`work_records.rs:270`（1）、`work_hub.rs`（3）、`variance_portfolio.rs`（3）、`entry_schedule.rs`（7）、`deletion_undo.rs`（2）、`internal_farms.rs`（10） | A 71 | 同上 |
| edge（Plans 系 `message`） | `cultivation_plans_mutations.rs`（32）、`cultivation_plans.rs`（5）、`field_cultivation_climate.rs`（5）、`field_cultivations.rs:197`（1）、`public_plans.rs:601-616`（4） | B 47 | `message` を `errors: [msg]` に変更（S1 は `Legacy::Message`）。`success: false` は付加情報として維持 |
| edge（項目別 map） | `task_schedules.rs:112`、`work_records.rs:189`、`work_record_photos.rs:202` | D 3 | `field_errors` を追加。`errors` は S1 の間 map のまま（`Legacy::ErrorsMap`）、S2 で平坦化した文字列配列にする |
| edge（その他） | `contact_messages.rs`（3）、`organizations.rs`（33）、`account.rs`（9）、`api_keys.rs`（3）、`auth_api.rs`（2）、`ai_api.rs`（16）、`routes.rs`（3）、`fallback.rs`（1）、`scheduler_weather_update.rs`（2） | A 72 | 同上。contact は `field_errors` を追加（`errors` の検証 422 は変更なし） |
| edge（変更なし） | `plan_variance_learning.rs`、`weather_reschedule_proposals.rs`、`plan_vs_actual.rs`、`task_schedules.rs` / `work_records.rs` / `work_record_photos.rs` の配列側、Masters の `errors` 側、`field_cultivations.rs:201`、`organizations.rs:595`、`masters_crop_task_schedule_blueprints.rs:424` | C 96 | 本文は変更しない。空配列にならないことを確認（§8 R24） |
| domain | `crates/agrr-domain/src/cultivation_plan/interactors/public_plan_save_interactor.rs:127-128` | – | `invalid.to_string()` ではなく `RecordInvalidError::detail_message()`（`shared/exceptions/mod.rs:21-23`）を使う（Q6 / S3） |
| adapters | `crates/agrr-adapters-sqlite/src/cultivation_plan/plan_save_session.rs:109` | – | `err.to_string()` の代わりに `RecordInvalidError` を判別して詳細メッセージのみ渡す（S3） |
| docs | `docs/api/openapi.yaml:453-461`、`docs/api/getting-started.md:57` | – | `Error` スキーマと 429 の例、失敗本文の節の更新（課題 08、03。§3.8、§10） |
| tools | `tools/agrr-mcp/src/agrr-client.mjs:87-95`、`tools/agrr-mcp/test/agrr-client.test.mjs:122-126` | – | `errors` を読む版に更新（S2 のゲート 4。§3.8） |

`crates/agrr-server/**`、`crates/agrr-domain/**`、`crates/agrr-adapters-*/**` を変更した場合、Docker 検証前に `.cursor/skills/dev-docker/scripts/rebuild-restart.sh` が必須（`docker-dev-agrr-server-rebuild.mdc`）。

### 4.3 テスト

| 種別 | 既存で影響を受けるもの | 新規 |
|------|------------------------|------|
| フロント usecase / core spec | 本文の fixture を `error` で書いている spec 14 ファイル（`core/api-error-i18n-key.spec.ts`、`core/backend-warmup/backend-warmup.spec.ts`、`core/crop-blueprint-regenerate-error-i18n.spec.ts`、`usecase/crops/{apply-crop-setup-proposal,create-crop-task-schedule-blueprint,delete-crop,dry-run-crop-setup-proposal,regenerate-crop-task-schedule-blueprints}.usecase.spec.ts`、`usecase/entry-schedule/load-entry-schedule-crops.usecase.spec.ts`、`usecase/farms/{load-farm-temperature-chart,retry-farm-weather-fetch}.usecase.spec.ts`、`usecase/plans/delete-plan.usecase.spec.ts`、`usecase/private-plan-create/create-private-plan.usecase.spec.ts`、`usecase/work-hub/ensure-plan-for-farm.usecase.spec.ts`。`rg "error: \{ ?error:"` による）と、`message` で書いている 2 ファイル（`adapters/plans/gantt-plan-api.gateway.spec.ts`、`usecase/plans/load-gantt-plan-data.usecase.spec.ts`）。`save-public-plan.usecase.spec.ts:91,115-143` は `{ success: false, error: ... }`。`error_code` を持つ fixture は `error_code` を維持し、`error` だけ `errors: [...]` に書き換える。`errors` を既に使う spec 6 ファイル（`core/crop-stage-reorder-error-i18n.spec.ts`、`usecase/farms/{create-farm,retry-farm-weather-fetch}.usecase.spec.ts`、`usecase/plans/{create-work-record,update-work-record,delete-plan}.usecase.spec.ts`）は原則そのまま（work record の 2 つは map なので `field_errors` に変更） | §6.2 の T1〜T17 |
| フロント presenter spec | `adapters/farms/farm-create.presenter.spec.ts`（変更なし想定）、`adapters/plans/plan-new.presenter.spec.ts:102`（Farm キー使用。変更なし想定） | `adapters/crops/crop-create.presenter.spec.ts`（現在存在しない） |
| フロント catalog spec | `core/i18n/farms-activerecord-locale.catalog.spec.ts`（参考）、`core/i18n/crops-new-locale.spec.ts`（拡張） | §6.2 T10〜T12 |
| R4 契約 | 失敗本文の表明は `contracts.rs` に 19 箇所（§2.8）。S1（旧キー併記）では**既存の表明はすべて通ったまま**（旧キー・map が残るため）。S2 で変更が必要なのは 12 箇所: `error` を表明する 10 箇所（`348,2123,3192,3280,3454,3471,3879,4502,4563,4595`）を `errors` の表明に、項目別 map を表明する 2 箇所（`411,636`）を `field_errors` の表明に更新する。`errors` の配列を表明する 5 箇所（`1221,1626,1726,2418,2442`）と `3043`（`error_code`）、`2689`（結果ペイロード）は変更しない | §6.3 S-T0〜S-T2 |
| ドメイン | `agrr-domain/test/cultivation_plan/interactors_public_plan_save_interactor_test.rs`（構造流用） | §6.3 S-T3 |
| 公式 MCP | `tools/agrr-mcp/test/agrr-client.test.mjs:122-126`（401 の `{error}` fixture を `errors` に変更） | 422 の複数メッセージが `Error.message` に出るテスト |

### 4.4 i18n 3 言語

`ja` / `en` / `in` の同パスに追加する（[`i18n-completion-workflow`](../../.cursor/skills/i18n-completion-workflow/SKILL.md) の DoD）。`assets/i18n/*.json` は手編集のみ（一括生成スクリプト禁止）。プレースホルダは `{{param}}`。

---

## 5. 対応方針（層ごと）

依存方向は `components → usecase → domain`、`adapters → gateway tokens`（ARCHITECTURE の Frontend 節、LAYER-RULES の Frontend layout）を守る。

### 5.1 `core/`（横断ヘルパー）

- `core/api-error-body.ts`（新規）に、本文の解釈を 1 か所で持つ純関数を置く。`errors` が「空白のみを除いた非空の文字列配列」か、`error_code` が非空文字列か、`field_errors` が「値がすべて文字列配列のオブジェクト」かを検証する。`error`（旧形式）と `message` は読まない（§3.4）。`errors` が map / オブジェクト配列のときは `[]` を返し、例外を投げない（`errors` が map の間は S1 の区分 D が該当する）。
- `core/api-error-message.ts` に、§3.7 の関数（`apiErrorMessages` / `apiErrorMessage` / `apiErrorHasMessage` / `apiErrorCode` / `apiFieldErrors`）を実装する。`TranslateService` に依存しない。既存の `core/api-error-i18n-key.ts` と並置し、`apiErrorI18nKey` を再利用する。解釈を `api-error-body.ts` に分けるのは、`backend-warmup.ts` が本文の `errors` を読む必要があり、`api-error-message.ts` → `api-error-i18n-key.ts` → `backend-warmup.ts` の import と循環しないようにするため。
- `error` を比較している既存箇所を移行する（§3.7.1）: `core/api-error-i18n-key.ts:13-22`（`weather_location_required`）、`core/backend-warmup/backend-warmup.ts:74-106`（`httpErrorBodyCode` を `errors[0]` に）。`core/crop-blueprint-regenerate-error-i18n.ts:19-26`（`error_code`）は変更しない。`errorBodyText`（`backend-warmup.ts:16-28`）は契約の読み取りではないため対象外。

### 5.2 `usecase/` と本文リーダー

- Masters の 24 usecase の `error:` コールバックを、`apiErrorMessage(err)` の呼び出しに置き換える。usecase が `TranslateService` を持たないもの（大半）は翻訳せず、キーまたは文言を `onError` に渡す（表示層が翻訳する。§2.3）。
- `create-farm.usecase.ts` は `resolveActiverecordApiErrorI18nKey` を通す既存の流れを維持する（`apiErrorMessage` の結果を通す）。
- §2.8 のその他の本文リーダー（`load-pest-detail`、`load-pest-for-edit`、`create-public-plan`、`delete-plan`、`retry-farm-weather-fetch`、`load-field-climate`、`load-farm-temperature-chart`、`account.component.ts:180-182`）も、同じ関数に統一する。`create-private-plan` は `apiErrorMessages(err)` の各要素を `translate.instant` に通してから結合する（§3.7.1）。`ensure-plan-for-farm` の `error === PLAN_ALREADY_EXISTS_KEY` の比較（`:72`）は `apiErrorHasMessage(err, PLAN_ALREADY_EXISTS_KEY)` に、`resolveErrorMessage` は `apiErrorMessage(err)` に置き換える。
- `save-public-plan.usecase.ts` は、`apiErrorMessage(err)` の結果を `translateServerToastMessage(text, (k) => this.translate.instant(k))` に通して返す。サーバー修正（S3）後は `activerecord....farm_limit_exceeded` が翻訳される。`in` の欠落キーは §5.6 で解消する。`SavePublicPlanResponse.error`（`public-plan-gateway.ts:12`）と、HTTP 200 で `success: false` を受ける分岐（`save-public-plan.usecase.ts:37-41`）は、サーバーが失敗をすべて 4xx / 5xx で返す（`public_plan_save.rs:50-115`）ため到達不能に見える。削除するかは実装時に判断する（§8 R21）。
- work record の 3 usecase（`create-work-record`、`update-work-record`、`save-work-record-sheet`）は、項目別エラーを `apiFieldErrors(err)` から読む。`ValidationErrorBody` 型（`errors?: Record<string, string[]>`）は削除する。
- `adapters/plans/gantt-plan-http.helpers.ts` の `error.error.message` 読みを `apiErrorMessage(error)` に置き換える。`gantt-plan-api.gateway.ts:102,139,168` の `response.message`（HTTP 2xx の本文）は失敗本文ではないため変更しない。
- contact（`send-contact-message.usecase.ts:49-58`）は課題 02 が扱う。本書は契約（`errors` / `error_code` / `field_errors`）を提供する（§10）。
- 適用範囲の既定は Q5 / Q12。

### 5.3 Crop 上限（`domain/` → `usecase/` → `adapters/` → `components/`）

1. `domain/crops/crop-create-limit.ts`: `MAX_NON_REFERENCE_CROPS_PER_USER = 20`（サーバー `crop_create_limit_policy.rs:3` と一致）、`countUserOwnedCrops`、`isCropCreateLimitReached`、`isCropLimitExceededMessage`。Farm 側（`farm-create-limit.ts`）と同じ命名・構造に揃える（[`implementation-consistency-with-existing.mdc`](../../.cursor/rules/implementation-consistency-with-existing.mdc)）。domain → core の import は Farm と同じ形になる（§2.5。是非は本書の範囲外の既存事項）。
2. `usecase/crops/load-crop-create-limit.*`: `CROP_GATEWAY.list()`（`usecase/crops/crop-gateway.ts:18`）を購読して件数を数え、出力ポートに `{ limitReached }` を渡す。一覧取得の失敗時は `limitReached: false`（サーバーが最終判定するための UX ヒントであり、ドメイン判定のフォールバックではない）。
3. `adapters/crops/crop-create.presenter.ts`: 出力ポートを実装し、`limitCheckLoading` / `limitBlocked` を更新する。`onError` は `isCropLimitExceededMessage(dto.message)` のとき `limitBlocked: true` かつフラッシュ無し（Farm の `farm-create.presenter.ts:21-31` と同型）。
4. `components/masters/crops/crop-create.component.ts`: 非管理者（Q8 既定）のとき `ngOnInit` で usecase を実行し、`limitCheckLoading` / `limitBlocked` で表示を切り替える。ブロック時の表示は Farm と同じ `plan-new-empty` のマークアップを使い、新しいレイアウト CSS を作らない（[`UI-COMPOSITION-RULES.md`](../design/UI-COMPOSITION-RULES.md) の L3 は Shell + Pattern + UseCase の配線のみ）。実装後に `npm run check:ui-composition`（`frontend/package.json:18`）で禁止パターンの有無を確認する。
5. component が gateway を直接購読する形（Farm の `farm-create.component.ts:200`）は踏襲しない（Q15 既定）。

### 5.4 リゾルバ（課題 5）

`core/i18n/resolve-activerecord-api-error-i18n-key.ts` に `ACTIVERECORD_CROP_LIMIT_EXCEEDED_KEY` を追加する。リテラル対応表への追加は Q13 の回答による（既定は追加しない）。

### 5.5 サーバー

段階は S0〜S3 とし、デプロイは S0・S1 → フロント（F1）→ S2 の順に行う（§3.5）。S3 は独立している。

- **S0（ヘルパー導入）**: `api_error.rs` を追加し、既存の `internal_error()` の 10 個の定義と `unauthorized` の定型本文（`error` 21 箇所 + `errors` 13 箇所 + `message` 6 箇所）をヘルパー呼び出しに置き換える。この時点では本文の形は変えない（`Legacy` は従来の形を再現する）。
- **S1（`errors` の追加。旧キーは併記）**: §3.2.1 の区分 A の 299 箇所と B の 47 箇所を、`api_error.rs` 経由で `errors: [msg]` に変更する。A には `Legacy::Error`、B には `Legacy::Message` で旧キーを併記する。区分 D の 3 箇所は `field_errors` を追加し、`errors` は map のまま（`Legacy::ErrorsMap`）。区分 C の 96 箇所は本文を変えない。ファミリー単位で進める: (1) Masters（`masters_*.rs`）、(2) Plans / 公開プラン系（A、B、D を別コミット）、(3) contact・organizations・account 系・スケジューラ認証。
- **S2（旧キー削除）**: §3.5 のゲートを満たした後に、`Legacy` 型と `attach_legacy_keys` を削除する。コンパイルエラーが指す呼び出し側の引数を削除する。区分 D の 3 箇所は `errors` を平坦化した文字列配列にする。R4 の表明 12 箇所（§4.3）を `errors` / `field_errors` の表明に更新する。OpenAPI と `getting-started.md` から `error` / `message` の deprecated 記述を削除する。
- **S3（Q6 で承認された場合）**: `public_plan_save` の失敗本文から `record invalid: ` を除く。ドメインの `PublicPlanSaveInteractor`（`:127-128`）と、アダプタの `PlanSaveSession::call`（`plan_save_session.rs:105-111`）の 2 箇所で、`RecordInvalidError` の詳細メッセージのみを使う。

### 5.6 i18n カタログ

追加するキー（3 言語同パス。文言は Q11 の確認後）:

| グループ | キー |
|----------|------|
| Crop 上限 UI | `crops.new.limit_reached`、`crops.new.limit_reached_hint`、`crops.new.manage_crops_link`（Farm の `farms.new.limit_reached` / `limit_reached_hint` / `manage_farms_link` と対応） |
| `in` の欠落（課題 4 本体） | `activerecord.errors.models.crop.attributes.user.crop_limit_exceeded` |
| サーバー送出キーの欠落（Q14 既定の範囲） | `crops.flash.reference_flag_denied`（全言語）、`activerecord.errors.models.crop.attributes.updated_at.blank`（全言語）、`crops.flash.no_permission` / `not_found` / `reference_flag_admin_only` / `reference_only_admin`（`in`）、`crops.flash.cannot_delete_in_use.plan` / `.other`（`en`, `in`） |
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

### 6.2 RED テスト（フロントエンド。統合契約 `errors`）

すべて現状のコードで**意図した理由で失敗する**ことを確認してから実装に進む。既存 spec の本文を新形式（`errors`）に更新する変更も、RED（更新した spec が失敗する）から始める。

| ID | spec ファイル（案） | Given / When / Then | RED になる理由 |
|----|---------------------|---------------------|----------------|
| T1 | `frontend/src/app/core/api-error-message.spec.ts`（新規） | 下記 14 ケースを表で検証 | 関数が存在しない |
| T2 | `frontend/src/app/usecase/crops/update-crop.usecase.spec.ts`（新規） | Given `gateway.update` が `HttpErrorResponse` を投げる。When `execute`。Then `onError` の `message` が期待値。ケース: 403 `{errors:['crops.flash.no_permission']}` → 同キー、422 `{errors:['crops.flash.reference_flag_denied']}` → 同キー、409 `{errors:['stale_record']}` → `common.api_error.conflict`、422 `{errors:['a','b']}` → `'a, b'`、旧形式 422 `{error:'a'}` → `common.api_error.generic`（`'a'` にならない） | 旧形式のケース（現状は Angular の `Http failure response ...` を返す）、409 のケース（現状は `stale_record` をそのまま返す）、本文なしのケースが RED。`errors` 形式の 403 / 422 は GREEN の保護（`update-crop.usecase.ts:34-37`） |
| T3 | `frontend/src/app/usecase/farms/update-farm.usecase.spec.ts`（新規） | T2 と同型。403 `{errors:['farms.flash.no_permission']}`、422 `{errors:['<msg>']}`、旧形式 `{error:'a'}` | 旧形式と本文なしのケースが RED。`errors` 形式は GREEN の保護（`update-farm.usecase.ts:27-31`） |
| T4 | `frontend/src/app/usecase/masters-mutation-error-contract.spec.ts`（新規、表駆動） | Given 24 usecase それぞれと、指定メソッドが投げる `HttpErrorResponse(422, {errors:['m']})` と `HttpErrorResponse(422, {error:'m'})`。When `execute`。Then 前者は `onError({ message: 'm' })`、後者は `message` が `'m'` にならず `common.api_error.generic` | 下表の内訳 |
| T5〜T13 | 下記（Crop 上限・i18n・公開プラン保存。T13 の fixture のみ `errors`） | – | – |
| T14 | `frontend/src/app/usecase/masters-other-readers-error-contract.spec.ts`（新規、表駆動） | Given §2.8 の本文リーダー（`load-pest-detail`、`load-pest-for-edit`、`create-public-plan`、`delete-plan`、`retry-farm-weather-fetch`、`load-field-climate`、`create-private-plan`、`load-farm-temperature-chart`）と `gantt-plan-http.helpers` の `extractGanttPlanHttpErrorMessage`、`account.component` の削除失敗。When `HttpErrorResponse(422, {errors:['m']})`。Then `'m'`（`create-private-plan` は `translate.instant` のモックを通した結果）。旧形式 `{error:'m'}` / `{success:false, message:'m'}` では `'m'` にならない | `{errors:['m']}` を読めず RED: `load-farm-temperature-chart`（`error` のみ）、gantt ヘルパー（`message` のみ）、`account.component`（`message \|\| error`）。旧形式を読まないことで RED: `delete-plan`、`retry-farm-weather-fetch`、`load-field-climate`、`create-public-plan`、`create-private-plan`、`load-farm-temperature-chart`、gantt ヘルパー、`account.component`。GREEN の保護: `load-pest-detail`、`load-pest-for-edit`（現状 `errors` を読む） |
| T15 | `frontend/src/app/usecase/plans/work-record-field-errors.spec.ts`（新規）または既存 spec の拡張 | Given `HttpErrorResponse(422, {errors:['validation'], field_errors:{name:['x']}})`。When `create-work-record` / `update-work-record` / `save-work-record-sheet` を実行。Then `onValidationError({ fieldErrors: {name:['x']} })`。S1 の期間の本文 `{errors:{name:['x']}, field_errors:{name:['x']}}` でも `field_errors` から読む。`field_errors` が無く `errors` が map の本文では `onValidationError` を呼ばず `onError`（汎用キー） | 現状は `errors` の map を読む（`create-work-record.usecase.ts:31-33` ほか）。既存 spec（`create-work-record.usecase.spec.ts:73-92` ほか）の fixture は `errors` の map |
| T16 | `frontend/src/app/core/backend-warmup/backend-warmup.spec.ts`、`core/api-error-i18n-key.spec.ts`（既存を更新） | 既存 fixture（`error: { error: 'prediction_payload_missing' }` など: `backend-warmup.spec.ts:46,54,62,71`、`api-error-i18n-key.spec.ts:65,76,87`）を `errors: [...]` に書き換える。加えて次を固定: 503 `{errors:['prediction_payload_missing']}` は警告ではない（`isBackendWarmupHttpError` が false）、503 `{errors:['agrr_daemon_not_running']}` は警告、503 `{error:'x'}`（旧形式のみ）は本文コードなしとして警告扱い、本文なしの 502 / 503 は警告、422 `{errors:['weather_location_required']}` は `api.entry_schedule.errors.weather_location_required` | 現状は `error` を読むため、`errors` fixture の 503 は「コードなし」として警告扱いになり、`isBackendWarmupHttpError` が true を返す（RED） |
| T17 | `frontend/src/app/usecase/work-hub/ensure-plan-for-farm.usecase.spec.ts`（既存を更新） | fixture `:56,85,112` を `errors: [...]` に書き換える。422 `{errors:['plans.errors.plan_already_exists_annual']}` で既存の分岐（`:72`）が動く。422 `{errors:['plans.errors.no_fields_in_farm']}` は `onError({ message: 'plans.errors.no_fields_in_farm' })` | 現状は `body.error` を比較するため、`errors` fixture では既存プラン分岐に入らない（RED） |

**T5〜T13**（Crop 上限・i18n・公開プラン保存。統合契約の変更は T13 の fixture のみ）:

| ID | spec ファイル（案） | Given / When / Then | RED になる理由 |
|----|---------------------|---------------------|----------------|
| T5 | `frontend/src/app/core/i18n/resolve-activerecord-api-error-i18n-key.spec.ts`（拡張） | Given `ACTIVERECORD_CROP_LIMIT_EXCEEDED_KEY`。When resolver に渡す。Then 同キーを返す。定数値が `activerecord.errors.models.crop.attributes.user.crop_limit_exceeded` | 定数が存在しない（型エラー = RED） |
| T6 | `frontend/src/app/domain/crops/crop-create-limit.spec.ts`（新規） | `farm-create-limit.spec.ts` と同型。`countUserOwnedCrops` は `is_reference !== true` のみ数える。20 件で `isCropCreateLimitReached` が true、19 件で false。`isCropLimitExceededMessage(key)` が true、他は false | モジュールが存在しない |
| T7 | `frontend/src/app/usecase/crops/load-crop-create-limit.usecase.spec.ts`（新規） | Given `list()` が非参照 20 件 + 参照 5 件。When `execute`。Then `present({ limitReached: true })`。19 件 → `false`。`list()` がエラー → `false` | usecase が存在しない |
| T8 | `frontend/src/app/adapters/crops/crop-create.presenter.spec.ts`（新規。現在存在しない） | Given view を設定。When `onError({message: <crop 上限キー>})`。Then `limitBlocked: true`、`pendingErrorFlash: null`。他のメッセージでは `pendingErrorFlash` が設定される。限度チェック結果の反映で `limitCheckLoading: false`、`limitBlocked` が更新される | `crop-create.presenter.ts:18-27` は常にフラッシュを出す |
| T9 | `frontend/src/app/components/masters/crops/crop-create.component.spec.ts`（拡張） | Given 非管理者で `list()` が 20 件。When 初期化。Then `crops.new.limit_reached` を含むブロック表示があり、`form` が無い。Given 3 件 → `form` がある。Given `list()` エラー → `form` がある。Given 管理者 → `list()` を呼ばず `form` がある（Q8 既定） | `CropCreateViewState` に該当フィールドが無い |
| T10 | `frontend/src/app/core/i18n/crops-activerecord-locale.catalog.spec.ts`（新規） | `farms-activerecord-locale.catalog.spec.ts` と同型。`crop_limit_exceeded` が ja=`作成できるCropは20件までです`、en=`You can create up to 20 Crops`、in=（承認された文言）で存在 | `in` に無い |
| T11 | `frontend/src/app/core/i18n/crops-new-locale.spec.ts`（拡張） | `crops.new.limit_reached` / `limit_reached_hint` / `manage_crops_link` が ja / en / in に存在し、en / in に日本語文字を含まない（既存の `JAPANESE_UI` 検査を流用） | キーが存在しない |
| T12 | `frontend/src/app/core/i18n/api-error-keys-locale.catalog.spec.ts`（新規） | Given 定数配列 `SERVER_EMITTED_ERROR_KEYS`（§2.6 の表のうち Q14 の範囲）と `CODE_MESSAGE_KEYS`（§2.6 の 7 件 + `crops.flash.not_found`）。When 各キーを 3 言語で引く。Then すべて非空文字列 | §2.6 の欠落キー |
| T13 | `frontend/src/app/usecase/public-plans/save-public-plan.usecase.spec.ts`（既存を更新） | Given 422 `{success:false, errors:['activerecord.errors.models.farm.attributes.user.farm_limit_exceeded']}` と `translate.instant` のモック。When `execute`。Then `onError` の `message` が翻訳結果。既存の `'Crop limit exceeded'` 期待（`:142`）はキーに置換。fixture `:91,125` の `error` は `errors` に置換 | 現状は `error` / `errors` を生のまま返す（`:50-64`） |

**T1 のケース**（`core/api-error-message.spec.ts`）:

1. `HttpErrorResponse(422, {errors:['k']})` → `apiErrorMessage` が `'k'`、`apiErrorMessages` が `['k']`
2. `{errors:['  k  ', ' ']}` → `apiErrorMessages` が `['k']`（trim し、空白のみを除く）
3. `{errors:['a','b']}` → `apiErrorMessage` が `'a, b'`（現行の結合表示と同じ）
4. 404 で `{errors:[]}`（空）→ `common.api_error.not_found`（空の `errors` は使わない）
5. 旧形式 `HttpErrorResponse(422, {error:'a'})` → `common.api_error.generic`（`'a'` を返さない）
6. 旧形式 `HttpErrorResponse(500, {success:false, message:'m'})` → `common.api_error.generic`（`'m'` を返さない）
7. `{errors:['a'], error:'b'}` → `'a'`（S1 の併記本文でも `errors` を読む）
8. `HttpErrorResponse(409, {errors:['stale_record']})` → `common.api_error.conflict`
9. 本文なしの `HttpErrorResponse(404)` → `common.api_error.not_found`
10. `{errors:{name:['x']}}`（map。S1 の区分 D）と `{errors:[{path:'a',message:'b'}]}`（オブジェクト配列）→ 例外を投げず `apiErrorMessages` が `[]`、`apiErrorMessage` が `common.api_error.generic`
11. `Error('boom')` → `'boom'`。`Error('')` と `null` → `common.api_error.generic`
12. `apiErrorHasMessage`: `{errors:['weather_location_required']}` に対し `'weather_location_required'` が true、`'other'` が false。旧形式 `{error:'weather_location_required'}` は false
13. `apiErrorCode`: `{error_code:'insufficient_scope'}` → `'insufficient_scope'`。`{}` と `{error_code:''}` → `null`
14. `apiFieldErrors`: `{field_errors:{name:['x']}}` → `{name:['x']}`。`{field_errors:{name:'x'}}` → `null`。S1 の `{errors:{name:['x']}}`（`field_errors` なし）→ `null`

**T4 の RED / GREEN 内訳**（§2.1 の表から機械的に導出。`errors` を読める usecase は 16、読めない usecase は 8）:

| 検査 | 区分 | usecase |
|------|------|---------|
| `{errors:['m']}` を `'m'` として返す | GREEN（保護。16 件） | create: crop, farm, pest, pesticide, fertilize, agricultural-task, interaction-rule。update: crop, farm, pest, pesticide, fertilize, agricultural-task。delete: crop, pest, pesticide |
| `{errors:['m']}` を `'m'` として返す | RED（8 件） | create-field、update-field、delete: farm, field, fertilize, agricultural-task, interaction-rule、update-interaction-rule |
| 旧形式 `{error:'m'}` を読まない | RED（4 件） | delete-crop、delete-pest、delete-pesticide、create-interaction-rule（現状は `error` を読む） |
| 旧形式 `{error:'m'}` を読まない | GREEN（保護。20 件） | 上記以外（`error` を読まない） |
| 本文なしの `HttpErrorResponse`（および旧形式のみの本文）で `common.api_error.*` を返す | RED（24 件すべて） | 全 usecase が `err?.message ?? 'Unknown error'` にフォールバックする（例 `update-crop.usecase.ts:34-37`、`delete-field.usecase.ts:17`）ため、Angular の標準メッセージが返る（§8 R4） |

Q12 の回答により、crop 下位リソース（`update-crop-stage`、`update-*-requirement` の 5 usecase）を表の行として追加する。

### 6.3 RED テスト（サーバー）

契約は R4 契約テスト（観測可能な本文）に置く。`agrr-server` のインラインテストには `test-common` 上の専用入口が無く、CI も一部を実行していない（[`README.md`](README.md) の「テスト実行に関する共通の制約」）。

| ID | 場所 | Given / When / Then | RED になる理由 |
|----|------|---------------------|----------------|
| S-T0 | `crates/agrr-r4-contract/tests/contracts.rs`（共通アサート `assert_error_envelope` を追加し、既存の失敗系 18 箇所（§2.8。`2689` は結果ペイロードのため除く）に組み込む。R4 に無い経路は新規テスト） | Given 各ファミリーの失敗経路。When リクエスト。Then 本文が JSON オブジェクトで、`errors` が 1 件以上の非空文字列の配列。検証失敗は各メッセージが別要素。項目別検証は `field_errors`。対象の新規経路: Masters の crops update（403、`reference_flag_denied`）・farms update（403）・fields 各操作・各 destroy・crop_stages create（`invalid`。区分 C の保護）・requirements の 404・blueprint の 404 と検証（`error_code` を維持）・`masters_auth` の 401 / 403 / `masters_rate_limit` の 429、Plans 系の plans 404・work_records 409 と 422（`field_errors.name`）・entry_schedule 422 / 503・cultivation_plans_mutations 404（`message` 形式）・field_cultivations 422、contact 429 / 検証 422（`field_errors`）、organizations の 403 | `error` のみ、または `message` のみを返す箇所（区分 A / B）で `errors` が無い。区分 C の箇所は GREEN の保護 |
| S-T1 | 同（S1 の互換テスト） | Given S-T0 と同じ経路のうち、区分 A / B / D の箇所。When リクエスト。Then 旧キーが**併記**されている（A は `error` が `errors[0]` と同一文字列、B は `message` が `errors[0]` と同一文字列、D は `errors` が従来の map と同一で `field_errors` が同じ内容）。区分 C の箇所には旧キーが無い | S1 の実装前は、新形式（`errors`）が無いため S-T0 が RED。S1 の実装後は GREEN。S2 で削除される |
| S-T2 | 同（S2 の削除テスト） | Given S-T0 と同じ経路。Then 失敗本文に `error` と `message` が**存在しない**（`fallback.rs` の `path` などの付加情報は除く）。区分 D の `errors` が文字列配列で、`field_errors` と内容が対応している。setup_proposal の結果ペイロードの `errors`（`contracts.rs:2689`）は対象外 | S1 の状態では旧キーが併記されているため RED。S2 の実装で GREEN |
| S-T3 | `crates/agrr-domain/test/cultivation_plan/interactors_public_plan_save_interactor_test.rs`（既存に追加。既存の Stub 群を流用） | Given 永続化ポートが `RecordInvalidError::new(Some("activerecord.errors.models.farm.attributes.user.farm_limit_exceeded"), None)` を返す。When `PublicPlanSaveInteractor::call`。Then 出力ポートの失敗は `KIND_SAVE_FAILED`、`message == Some("activerecord.errors.models.farm.attributes.user.farm_limit_exceeded")` | `public_plan_save_interactor.rs:127-128` は `invalid.to_string()` で `record invalid: ` が付く |
| S-T4 | `crates/agrr-adapters-sqlite/src/cultivation_plan/plan_save_session_integration_test.rs`（既存に追加。`invoke_save` 流用） | Given 非参照農場を 4 件持つユーザーと保存対象の公開プラン。When `invoke_save`。Then 出力が失敗で、`error_message` が上限キーのみ（接頭辞なし） | `plan_save_session.rs:109` が `err.to_string()` |
| S-T5（任意） | `crates/agrr-server/src/api_error.rs` のインライン `#[cfg(test)]` | `api_error(422, "a", Legacy::Error)` が `errors == ["a"]` かつ `error == "a"`。`Legacy::None` は `error` を持たない。`api_errors(422, ["a","b"])` が `errors == ["a","b"]`。`api_errors(422, [])` が 500 の `errors == ["internal"]`。`api_field_errors(.., Legacy::ErrorsMap)` が `errors` に map、`field_errors` に同内容。`api_error_with_code` が `error_code` を保持 | ヘルパーが存在しない。`test-common` の入口が無いため、契約は S-T0〜S-T2 が担保する |
| S-T6（Q9） | `scripts/run-architecture-guard-lib.test.mjs` | Given `crates/agrr-server/src` に失敗本文の `"error"` / `"message"` キーを直書きしたフィクスチャ。When ガードを実行。Then 違反として検出される。許可リスト（`api_error.rs`、`backdoor/routes.rs`）は検出されない | 検査が存在しない |

S-T0 の経路ごとに必要な seed ヘルパー（`support.rs`）の有無は**未確認**。無い場合は `support.rs` に追加する（例: 上限に達した専用ユーザーは、共有ユーザー `developer_session_id` に 20 件を作ると他の R4 テストの上限を壊すため専用が要る。`support.rs:164` のコメントが同種の問題を示す）。

S1 のみで止める場合に実行するのは S-T0 と S-T1、S3 を含めるなら S-T3 と S-T4。R4 契約は `rebuild-restart.sh` 後に全件を実行して回帰を確認する。

---

## 7. 実装ステップ

1 論理変更 = 1 コミット。各ステップは「RED を確認 → 実装 → 個別 GREEN」の順（[`tdd-on-edit`](../../.cursor/skills/tdd-on-edit/SKILL.md)）。Q2〜Q15 の確認が済んでいない間に着手できるのは、既定で進められるステップ 1〜12。ステップ 13（S3）は Q6 の承認後、ステップ 14（S2）は Q2 と §3.5 のゲート後、ステップ 15（機械ゲート）は Q9 の承認後。

**デプロイ順序は固定**: サーバー S1（手順 1〜6）→ フロント F1（手順 7〜12）→ S2（手順 14）。フロントを先に出さない。S2 を F1 の前に出さない。詳細とゲートは §3.5。

| 順 | コミット | 内容 | RED → GREEN |
|----|----------|------|-------------|
| 1 | `test(r4): assert errors envelope on failure paths` | `assert_error_envelope` と、既存・新規の失敗経路への組み込み（S-T0）、旧キー併記の検査（S-T1） | S-T0 / S-T1 が RED（区分 A / B の箇所に `errors` が無い） |
| 2 | `feat(server): add api_error helper` | `api_error.rs`（S0）。既存の `internal_error()` 10 定義と `unauthorized` の定型本文を置換。`Legacy` は従来の形を再現し、本文の形は変えない | S-T5。S-T0 の既存 `error` 系は GREEN のまま |
| 3 | `feat(server): add errors to masters failure bodies` | Masters の区分 A 156 箇所を `api_error` 経由の `errors: [msg]` に変更し、`error` を併記する（S1-1）。`masters_auth.rs` / `masters_rate_limit.rs` を含む | S-T0 / S-T1 の Masters 行 |
| 4 | `feat(server): add errors to plans failure bodies` | Plans / 公開プラン系の区分 A 71 箇所、区分 B の `message` 47 箇所、区分 D の 3 箇所（`field_errors` を追加）（S1-2）。A / B / D でコミットを分ける | S-T0 / S-T1 の Plans 行 |
| 5 | `feat(server): add errors to remaining failure bodies` | contact・organizations・account 系・スケジューラ認証の区分 A 72 箇所（S1-3）。`contact_messages.rs` は `field_errors` を追加。課題 02 の Turnstile 実装と同じファイルを触るため、順序を調整（§10） | S-T0 / S-T1 の contact / organizations 行 |
| 6 | `docs: declare errors failure contract` と `feat(mcp): read errors from failure body` | `getting-started.md` と `openapi.yaml` の失敗本文を `errors` 主体に更新し、`error` / `message` を `deprecated` で記載（課題 08、03）。`tools/agrr-mcp` を `errors` 読みに更新し、テストを更新。S1 のデプロイと同時に公開する（§3.5 ゲート 3、4） | MCP のテスト（422 の複数メッセージ）が RED → GREEN |
| – | （デプロイ）サーバー S1 | `rebuild-restart.sh` → `run-rust-contract-tests.sh` → `run-test-rust-domain.sh` を GREEN にしてから `deploy-server` | – |
| 7 | `core: add api error body and message helpers` | `core/api-error-body.ts`、`core/api-error-message.ts`、`error` 比較の移行（`api-error-i18n-key.ts`、`backend-warmup.ts`。§3.7.1） | T1, T16 |
| 8 | `usecase: read errors in masters usecases` | Masters 24 usecase を共通関数に置換 | T2, T3, T4 |
| 9 | `usecase: read errors in other readers` | §2.8 の本文リーダー、`ensure-plan-for-farm` の比較、`create-private-plan` の要素単位の翻訳、`account.component`、gantt ヘルパー、work record 3 usecase の `field_errors` 読み | T14, T15, T17 |
| 10 | `i18n: add crop limit and server-emitted error keys` | 3 言語のカタログ追加（`crop_limit_exceeded`、`crops.flash.*`、コード参照 7 件ほか） | T10, T12 |
| 11 | `feat(crops): pre-check crop create limit` | domain → usecase → presenter → component → `crops.new.*` の順 | T5, T6, T7, T8, T9, T11 |
| 12 | `usecase(public-plans): translate save error message` | `save-public-plan` に共通関数 + `translateServerToastMessage` | T13 |
| – | （デプロイ）フロント F1 | 手順 6 までのサーバー（S1）が本番に反映済みであることを確認してから `deploy-frontend`（CDN 無効化のログを確認） | – |
| 13 | `fix(public-plan-save): drop "record invalid" prefix from failure message`（Q6 で承認された場合） | domain と adapter の 2 箇所（S3）。S1 / F1 とは独立して実施できる | S-T3, S-T4 |
| 14 | `refactor(server): remove legacy error keys`（§3.5 のゲートと Q2 を満たした後） | `Legacy` と `attach_legacy_keys` を削除。区分 D の `errors` を平坦化した文字列配列にする。R4 の表明 12 箇所を更新。`openapi.yaml` / `getting-started.md` から `error` / `message` の記述を削除 | S-T2 |
| 15 | `chore(guard): forbid error and message keys in failure bodies`（Q9） | `run-architecture-guard-lib.mjs` に検査と許可リストを追加 | S-T6 |

手順 13（S3）はユーザーに見える結果がフロントの手順 12 と揃って初めて完成する。手順 11 では、Farm 側の実装（`farm-create.component.ts`、`create-farm.usecase.ts`、`farm-create.presenter.ts`）には触れない（`create-farm.usecase.ts` は手順 8 で共通関数化する際に触れるが、`resolveActiverecordApiErrorI18nKey` の流れは維持する）。

各ステップの完了時:

1. 個別 spec を `run-test-frontend.sh` で GREEN にする。
2. フロントは手順 7〜9・11 の後に全件を実行する。
3. `test-slow-detection` を実施する。
4. サーバーに触れたステップ（1〜6, 13, 14）は `rebuild-restart.sh` → `run-rust-contract-tests.sh` → `run-test-rust-domain.sh` を実行する。

---

## 8. リスク・未確定事項

| # | リスク / 未確定 | 対応 |
|---|-----------------|------|
| R1 | `ng test --include` の可否が未確認（`node_modules` 未導入）。可否により個別 RED の確認手順が変わる | 手順 7 の前に確認する。無効なら全件実行で RED を確認し、ログから該当 spec を `rg` する |
| R2 | 課題 2 の `record invalid: <key>` は**コード読解による導出**。実行して本文を観測していない | S-T3 / S-T4 の RED 実行で確定する。観測結果が異なれば §2.4 を修正する |
| R3 | edit / detail 系 presenter が検証文言を `common.api_error.generic` に丸める（§2.3）ため、usecase を直しても edit 画面の見た目は変わらない範囲がある | Q7。既定では presenter は変更しないため、受け入れ条件は usecase の出力（`onError.message`）で定義する |
| R4 | 挙動変更: 本文の無い `HttpErrorResponse` で、従来は `err.message`（`Http failure response ...`）を返していたが、共通関数の適用後は `common.api_error.*` キーを返す。生メッセージを期待するテスト・画面が無いかは未確認 | 各 usecase の既存 spec を GREEN のまま保つ。フロント全件で回帰を確認する |
| R5 | サーバーの上限計数は組織単位、フロントの件数は一覧（`index_list_filter_for_user`）ベースで、両者が一致するかは未確認 | 事前チェックは UX ヒントに限定し、サーバーエラー時のブロック表示（T8）で最終判定を受ける |
| R6 | 管理者の Crop 事前チェック（参照作物は上限対象外）の扱い | Q8。既定は非管理者のみ |
| R7 | Crop 更新は `updated_at` が必須（`crop_update_interactor.rs:68-77`）。フロントの `update-crop.usecase.ts:66` は `updated_at != null` のときだけ送る。未送信だと 422 になるが、フロントが常に送っているかは未確認。本課題の範囲外の隣接事項として記録する | 課題 11（low-priority-misc）または別課題で確認 |
| R8 | 旧キーを読むコードの抽出は `rg` の正規表現による。分割代入や `Object.entries` など、正規表現に掛からない読み方が残っている可能性は**未確認** | 手順 9 の完了時に、`rg -n "\.error\??\.(error\|message)\b\|body\??\.(error\|message)\b\|as \{ error\?: (string\|unknown) \}" frontend/src/app --glob '!*.spec.ts'`（現状 16 ファイル 19 行）が 0 件になることを確認し、残りは目視で確認する。S2 のゲート 5 |
| R9 | 既存 CI ゲート `check-hardcoded-i18n` は「メッセージとしてキーを渡す」使い方を検査しない（§2.6）。今回の欠落 7 件が再発し得る | T12 で既知キーを固定する。ゲート拡張は本課題の範囲外（提案のみ。実施は別途ユーザー確認） |
| R10 | `in` の欠落キーが ja にフォールバックするかは未確認（ngx-translate v17 の挙動） | 実行時確認は未実施。キーを追加すれば挙動に依存しない |
| R11 | Hindi 訳の品質確認者が必要 | Q11 |
| R12 | 上限のキー名 / 文言の Farm との対称性が崩れる（`farms.new.*` は `farm_limit_reached` 系が別にもある: `ja.json:2442` など） | 追加前に `crops.*` 側の既存キー（`crops.new.*`）を再確認し、命名を Farm に揃える |
| R13 | 箇所数（A 299、B 47、D 3、C 96 ほか）は正規表現による概数。`json!` を介さずに組み立てる本文（`serde_json::Map` の手組み、`Value` を返す関数）は数え漏れがあり得る | S1 のコミットごとに、対象ファイルの `rg '"errors?"' -c` を実施前後で比較する。R4 の S-T0 が最終的な検出手段 |
| R14 | 外部 API クライアントと旧フロントのバンドルが `error` / `message` に依存しているかは、リポジトリ内では**計測できない**（API キー利用の利用者別集計がない: 調査の限界）。S2 は破壊的変更になり得る | S1 は旧キーを併記するため非破壊。S2 は Q2 と §3.5 のゲートが前提。OpenAPI に `deprecated` を先に明記する。Cloud Logging の HTTP ログで API キー付きリクエストの失敗応答を数えられるかは**未調査** |
| R15 | F1 稼働中にサーバーだけを S1 → S0 へロールバックすると、F1 が区分 A / B の箇所で劣化する（§3.5） | S1 のロールバックは F1 のロールバックと同時に行う運用とする。`deploy-server` スキルにロールバック手順があるかは**未確認** |
| R16 | S2 後に、旧バンドルを開いたままのタブで destroy・認証・Plans 系の失敗メッセージが汎用文言に劣化し、区分 D では項目別エラーが表示されなくなる。強制更新の仕組みは見つからなかった（§3.5） | 再読み込みで解消する。許容できない場合は、バージョン確認による更新促しを別課題とする |
| R17 | 複数要素の `errors` を `', '` で結合して表示すると、`translateServerToastMessage` が結合後の文字列をキーとして翻訳できない | 現行のフロントも `errors.join(', ')` で結合してから表示しており（例 `create-crop.usecase.ts:35`）、退行ではない。要素単位で翻訳する必要があれば `create-private-plan` と同じ要素単位の翻訳を使う |
| R18 | `Legacy` 引数の付け間違い（従来 `errors` の箇所に旧キーを付ける、従来 `error` の箇所で付け忘れる） | S-T1 が「旧キーが併記されるべき箇所だけに併記されること」を検査する。S2 で `Legacy` を削除するとコンパイルエラーで呼び出しが列挙される |
| R19 | 課題 02（Turnstile）が同じ `contact_messages.rs:58-79` を触る。順序を誤ると二重改修になる | 手順 2（`api_error.rs`）を先に入れ、02 はヘルパー経由で実装する（§10） |
| R20 | S-T0 の新規経路に必要な seed ヘルパーが `support.rs` に無い可能性（§6.3） | 無ければ追加する。追加が大きい経路は、既存の失敗系テストへの `assert_error_envelope` の組み込みのみで代替し、未検証の経路を明記する |
| R21 | `save-public-plan.usecase.ts:37-41`（HTTP 200 で `success: false`）と `SavePublicPlanResponse.error` は、サーバー側では到達しない可能性が高い（`public_plan_save.rs:50-115` は失敗をすべて 4xx / 5xx で返す）が、他のクライアントが 200 の失敗を期待しているかは未確認 | 実装時に削除の可否を判断する（`project-necessary-code-only.mdc`）。削除しない場合、この分岐は失敗本文の契約（C1）の対象外として残る |
| R22 | 警告分類の挙動差: `isEntryScheduleWeatherHttpError` は、503 で本文コードがあり daemon 系の文字列でなければ「明示的な失敗」とする。旧 `error` から `errors[0]` に読み替えると、**従来 `message` 形式（本文コードなし）で 503 を返していた `cultivation_plans_mutations.rs:157` は、警告扱いから明示的な失敗に変わる**。また課題 05 が新設する 503（`ProgressDaemonUnavailable`）は、`errors[0]` が daemon 系の文字列でなければ GET でも再試行されない | 変更は T16 で固定する。`cultivation_plans_mutations.rs:157` は POST 系（`post` は再試行しない: `api.service.ts:62-70`）で、表示が warmup 文言から本文のキーに変わるだけ。05 の写像は §10 |
| R23 | 区分 D の `task_schedules.rs:112` の map を読むフロントの箇所を特定していない（§2.8 の項目別 map 読みは work record の 3 usecase のみ）。S2 で `errors` が文字列配列に変わると、その読み手が壊れる可能性がある | S2 の前に `rg` で `task_schedule` 系の 422 の読み手を確認する（§3.5 ゲート 5）。無ければ D の 2 箇所（work record 系）だけが読み手を持つ |
| R24 | 区分 C の 96 箇所と `api_errors` は、空配列を返し得る箇所があるかを未確認（`field_cultivations.rs:179-180` の `flatten_error_messages()`、`full_messages()`、blueprint の `Vec<String>`）。空だと C1 の「1 件以上」に反する | S-T0 で検証失敗経路の `errors` が非空であることを表明する。`api_errors` は空のとき 500 にする（§3.6） |

---

## 9. 受け入れ条件

### フロントエンド

1. §6.2 の T1〜T17 がすべて GREEN。
2. Masters の 24 usecase が、`{errors:['m']}` に対して `onError({ message: 'm' })` を返し、旧形式 `{error:'m'}` を読まない（T4）。
3. 409 の本文が `errors: ['stale_record']` のとき `common.api_error.conflict` を返す（T2）。
4. `errors` が map / オブジェクト配列でも例外を投げず、状態コード由来のキーを返す（T1）。
5. work record の項目別エラーが `field_errors` から読まれる（T15）。
6. 警告分類（`isBackendWarmupHttpError`）と `weather_location_required` / `plan_already_exists_annual` の比較が `errors` の要素で動き、旧形式の `error` だけの本文では動かない（T16, T17）。
7. Crop 上限（20 件）に達した非管理者は、フォーム送信前にブロック表示が出る。サーバーが上限エラーを返した場合もブロック表示に切り替わり、フラッシュは出ない（T8, T9）。
8. `save-public-plan` の失敗メッセージが、キーを含む場合は翻訳された文言になる（T13）。
9. `assets/i18n/{ja,en,in}.json`: §5.6 の追加キーが 3 言語の同パスに存在する。`in` の `crop_limit_exceeded` が存在する（T10）。§2.6 のコード参照 7 件とサーバー送出キー（Q14 の範囲）が 3 言語にある（T12）。`i18n` の diff に意図しない大量削除が無く、プレースホルダが `{{...}}` のまま。
10. `run-test-frontend.sh` の全件が GREEN。`test-slow-detection` で閾値超過テストが検出されない。`npm run check:ui-composition` が通る。
11. `rg -n "\.error\??\.(error|message)\b|body\??\.(error|message)\b|as \{ error\?: (string|unknown) \}" frontend/src/app --glob '!*.spec.ts'` と `rg -n "ValidationErrorBody" frontend/src/app` が 0 件（旧キーを読む個別の本文リーダーが残っていない。R8）。
12. Farm 側のコードに、共通関数の適用以外の変更が無い。

### サーバー（S0 / S1）

13. S-T0 / S-T1 が GREEN。既存の R4 が GREEN のまま（旧キー・map の併記により、`error` / 項目別 map を表明する 12 箇所も通る）。
14. §2.7 の区分 A / B / D の失敗本文（349 箇所）が、すべて非空の文字列配列の `errors` を持つ（区分 D は `field_errors`）。A の 299 箇所は `Legacy::Error`、B の 47 箇所は `Legacy::Message` で旧キーを併記している。
15. `fn internal_error` の個別定義が `crates/agrr-server/src` から無くなり、`api_error.rs` に 1 つだけ存在する。
16. `rebuild-restart.sh` 後に `scripts/run-rust-contract-tests.sh`、`run-test-rust-domain.sh` が GREEN。

### サーバー（S2。§3.5 のゲートと Q2 を満たした後）

17. S-T2 が GREEN。`Legacy` 型と `attach_legacy_keys` がコードベースに存在しない。区分 D の `errors` が文字列配列で、R4 の表明 12 箇所が `errors` / `field_errors` の表明に更新されている。
18. `docs/api/openapi.yaml` の `Error` スキーマが実装と一致し（`errors` は必須の文字列配列、`error_code` は文字列、`field_errors` は項目名 → 文字列配列の map）、`error` / `message` の `deprecated` 記述が削除されている。`docs/api/getting-started.md` の 429 の例が `errors` で、失敗本文の形式の節がある。
19. `tools/agrr-mcp` が `errors` を読み、テストが GREEN。
20. Q9 を承認した場合、S-T6 が GREEN で、`scripts/run-architecture-guard.sh` が OK。

### サーバー（Q6 で S3 を承認した場合）

21. S-T3 / S-T4 が GREEN。公開プラン保存の上限超過応答の `errors` が `record invalid: ` を含まない。

---

## 10. 関連課題との依存

`docs/spec-defects/` の各文書（01〜11）と [`README.md`](README.md) の決定事項表（第 1 回・第 2 回）を読んだ範囲での接点。他の文書は並行して更新されている可能性があり、下記の参照先（節番号・Q 番号）は本書作成時点のもの。

| 番号 | 関係 | 内容 |
|------|------|------|
| 01 resource-limit-bypass | **強い関連（「統合」の別解釈を担当）** | 「統合」が上限判定の経路統合を含意する場合はそちらで扱う（§0.1）。本書との接点は 2 つ。(a) Farm / Crop の Masters create の上限エラーは既に `errors: [key]`（`masters_farms.rs:429`、`masters_crops.rs:283,340`）で、`errors` 統合では**本文が変わらない**。フロントの `isCropLimitExceededMessage`（T6, T8）と `resolveActiverecordApiErrorI18nKey` は、`apiErrorMessage` の結果を受ける。(b) 01 が上限をサーバー側で新たに強制する経路を追加する場合、そのエラーは `api_error.rs` 経由で `errors: [key]`（422 + 上限キー）の形にし、`MAX_*` 定数の同期（`farm-create-limit.ts:8`、`crop_create_limit_policy.rs:3`）を保つ |
| 02 contact-recaptcha（Turnstile 採用） | **強い関連（契約の形を共有）** | 02 は CAPTCHA 失敗の応答を `contact_messages.rs:58-79` の `failure_response` で組み立て、識別用に新規キー `code`（`captcha_failed` / `captcha_unavailable`）を追加する案（02 の §3.4 Q10、§8 R10、§5.1 の presenter 行、§5.2 の usecase 行）を持つ。**`errors` 前提で本書の契約に合わせる点**: (1) 識別子は新規の `code` ではなく既存の `error_code` を使う（`masters_auth.rs:98`、blueprint 系、フロントの `crop-blueprint-regenerate-error-i18n.ts:19-26` が同名を使用済みで、2 つ目の名前を作らない）。値の名称（`captcha_failed` / `captcha_unavailable`）は 02 で確定する。(2) **CAPTCHA 失敗（422）は `{"errors": ["<文言>"], "error_code": "captcha_failed"}`、secret 未設定などの利用不可（503）は `{"errors": ["<文言>"], "error_code": "captcha_unavailable"}`**。文言は 02 の `"Turnstile failure: <error-codes>"` / `"CAPTCHA is not configured"` をそのまま `errors[0]` に入れる。S1 の間は `Legacy::Error` により `error` も併記される。(3) 入力検証の 422 は従来どおり `errors`（`full_messages`。§2.7 #16）で本文が変わらず、`field_errors`（`validation_errors.rs:45-51`）を加える。CAPTCHA 失敗と入力検証は、同じ 422 でも `error_code` の有無で区別できる（`error` 文字列と `errors` 配列の形状で区別する暫定案は不要）。フロントの spec が既に `field_errors` を想定している（`send-contact-message.usecase.spec.ts:87-93`）。(4) 02 が導入するフロントの `toErrorDto` は、本文の形状判別ではなく `apiErrorCode(err)` / `apiFieldErrors(err)` / `apiErrorMessages(err)` を使う。02 のフロントテスト F5 / F6 の fixture（`{error:'...', code:'...'}`。02 の該当行）は `{errors:['...'], error_code:'...'}` に読み替える。(5) 429 の `rate_limit` は `{"errors": ["rate_limit"]}`。専用文言は本書の契約の上で 02 が扱う。**順序**: 本書の手順 2（`api_error.rs`）を先に入れ、02 はヘルパー経由で実装する。R4 の `contracts.rs:4502-4595`（02 が Turnstile 向けに書き換える。`error` を表明している 3 箇所）は S2 の更新対象 12 箇所に含まれるため、02 のテスト書き換えと同じ PR か連続した PR で調整する |
| 03 api-key-scope-docs | 関連 | 403 の本文 `{"error":"forbidden","error_code":"insufficient_scope"}`（`masters_auth.rs:98`）は、`errors` 統合では `{"errors":["forbidden"],"error_code":"insufficient_scope"}` になる（S1 は `error` を併記）。`docs/api/getting-started.md` を 03 と本書の手順 6 の両方が編集するため、03 を先に入れる（README の着手順どおり）。03 が扱う MCP の `apply_crop_setup` 削除（README 第 2 回決定）と、本書の MCP の `errors` 読みは同じ `tools/agrr-mcp/` を触るため、コンフリクトに注意する |
| 04 api-key-query-auth | 関連なし（本書の範囲外） | – |
| 05 fail-closed-critical / 06 fail-closed-suspected | **関連（typed 失敗 → HTTP の写像で本文の形を共有）** | 05 A-6 は、typed な失敗（`FieldCultivationClimateFailureReason`: `ProgressDaemonUnavailable` 503 / `ProgressExecutionFailed` 500 など）を出力ポートの `on_failure` で受け、server が `reason` の**網羅的な `match`** で状態コードと本文を決める。**本書に合わせる点**: (1) 05 の暫定案 `{"success": false, "error_key": ..., "message": ...}` は、`{"success": false, "errors": ["<reason 由来のキーまたは翻訳済み文言>"], "error_code": "<reason の snake_case>"}` に読み替える（`message` は失敗の主メッセージにしない。C4）。作業記録の新しい outcome（`SnapshotUnavailable`）も `work_records.rs` の既存の `errors` 配列に合わせる（05 の記述と一致）。(2) 05 の失敗種別ごとの `match` は `api_error_with_code` を返すようにし、新しい種別の写像漏れはコンパイルエラーで検出する。(3) `load-field-climate.usecase.ts:86-93` は `errors` を既に読むため、05 の新しい本文はフロントの追加変更なしで `onError.message` に出る（05 は「`message` は読まれない」ことを 07 の領域とした）。(4) **警告分類との相互作用**: 05 の 503（`ProgressDaemonUnavailable`）は、`errors[0]` が daemon 系の文字列（`daemon_unavailable` など: `backend-warmup.ts:31-39`）を含めば警告として GET が再試行され、含まなければ明示的な失敗で再試行されない（§8 R22）。どちらにするかは 05 が決める。06 の 8 項目に失敗応答の追加がある場合も同様に `api_error.rs` 経由の `errors`（+ `error_code`）の形にする |
| 08 openapi-gaps | **強い関連（後続。Error スキーマを `errors[]` 主体に更新）** | 08 の D-03（`Error` に `error_code` を追加）と D-14（`Error.errors` を文字列配列に修正）は、本書の契約で次のように上書きされる。**`Error` = `{ errors: array<string>（必須、1 件以上）, error_code: string, field_errors: map<string, array<string>> }`**。`error` と `message` は S1 の期間中 `deprecated` として記載し、S2 で削除する。08 の §4.2 の After（`error: string` を先頭に置き `errors` を任意とする形）は、`errors` を必須にして `error` を deprecated に直す必要がある。08 が記載する失敗本文の例（D-03 (a) の `403 {"error":"forbidden","error_code":"insufficient_scope"}`、D-07 の `404 {"error":"crop not found"}` と `422 {"error":"mode must be dry_run or apply"}`、D-12 の `422 {"error":"record not found"}`）は `errors: [...]` 形式に書き換える。08 の T13（`error` が `mode must be dry_run or apply`）は `errors[0]` の表明に変わる。setup_proposal の 200 結果 `errors: [{path, message}]`（D-07）は `Error` ではなく専用スキーマで、本書の C3 の例外（i）に当たる。D-03 の `error_code` の型（自由文字列か enum か）は、08 の推奨（自由文字列）に本書も合わせる。08 の 403 / 429 / 400 の追記は、すべて `Error` を参照するため本書の形式に自動的に従う。08 の §5 の「実装との整合を機械検証する」仕組みには、S-T0 の `assert_error_envelope` を取り込む。openapi の更新順序は §3.5 のゲート 3（S2 の前に公開） |
| 09 stale-design-docs | 関連 | `ARCHITECTURE.md:83`（i18n を `{ja,en}.json` とする記述。実際は 3 言語）、`ARCHITECTURE.md` の Resource Limits 節の「per user」（実装は組織単位: §2.5）が実態と異なる。本書の `api_error.rs` 導入後は、`ARCHITECTURE.md` / LAYER-RULES にエラー本文の契約（C1〜C9）への参照を足すかどうかを 09 で判断する |
| 10 authorization-consistency | **強い関連** | update の認可失敗の扱いが揃っていない（pests / pesticides / fertilizes は 403、agricultural_tasks / interaction_rules は 422 + `errors: ["forbidden"]`: §3.1）。本書は本文を `{"errors": ["forbidden"]}` に揃えるだけで、状態コードの整合は 10 で扱う。10 が状態コードを変更する場合は、S-T0 の該当行の期待値を合わせる |
| 11 low-priority-misc | 関連 | Crop 更新の `updated_at` 必須（R7）、`in.json` のルート直下の孤立ブロックと日本語値（§2.6）、`check-hardcoded-i18n` の検出範囲（R9）を、優先度の低い課題として引き継ぐ候補 |

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

24 usecase 以外の本文リーダー（`load-pest-detail`、`create-public-plan`、`delete-plan`、work record 3 usecase、`ensure-plan-for-farm`、gantt ヘルパー、`account.component.ts` ほか）は §2.8 に一覧した。

### 付録 B: 本調査で実行したコマンド

- `node scripts/check-hardcoded-i18n.mjs`（`frontend/` で実行、読み取りのみ）: `check-hardcoded-i18n: OK (1489 static references checked)`。
- Python による JSON 平坦化とキー集合の差分、コード中の引用符付きキー形リテラルの静的抽出（付録 D）。
- `rg` / `grep` によるコード読解。テストスイート・ビルド・サーバー起動は実行していない。
- Python による `crates/agrr-server/src/**/*.rs` の `"error"` / `"errors"` / `"success": false` の箇所数の集計（付録 D-2。第 2 回決定に伴い `"success": false, "message"` の列と合計を追加して再集計）。読み取りのみ。
- `rg` による本文リーダーの抽出（例: `rg -n "\.error\??\.(errors?|message)\b" frontend/src/app --glob '!*.spec.ts'` は 26 ファイル 36 行。旧キー `error` / `message` を読む箇所に絞った `rg -n "\.error\??\.(error|message)\b|body\??\.(error|message)\b|as \{ error\?: (string|unknown) \}" frontend/src/app --glob '!*.spec.ts'` は 16 ファイル 19 行。本文の fixture を持つ spec は `rg -l "error: \{ ?error:" --glob '*.spec.ts' frontend/src/app` などで数えた）、`tools/agrr-mcp/`・`docs/api/` の読解、`.cursor/skills/deploy-frontend/scripts/gcp-frontend-deploy.sh` のキャッシュ設定の読解。

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

#### D-2: サーバーの失敗本文キーの箇所数（§2.7）

```bash
cd crates/agrr-server/src
python3 - <<'PY'
import re, glob
tot = [0, 0, 0, 0]
for f in sorted(glob.glob('**/*.rs', recursive=True)):
    s = open(f).read()
    i = s.find('#[cfg(test)]')
    s = s[:i] if i >= 0 else s
    e = len(re.findall(r'"error"\s*:', s))
    es = len(re.findall(r'"errors"\s*:', s))
    sf = len(re.findall(r'"success"\s*:\s*false', s))
    sm = len(re.findall(r'"success"\s*:\s*false\s*,\s*"message"', s))
    if e or es or sf:
        print(f, 'error=', e, 'errors=', es, 'success:false=', sf, 'success:false+message=', sm)
    for k, v in enumerate((e, es, sf, sm)):
        tot[k] += v
print('TOTAL error, errors, success:false, success:false+message =', tot)
PY
```

実行結果の合計は `error` 313、`errors` 102、`success: false` 67、`success: false` + `message` 47。`error` の 313 から `backdoor/routes.rs` の 14 を除いた 299 が区分 A。`errors` の 102 から、結果ペイロード 1（`masters_crop_setup_proposal.rs`）、`backdoor/routes.rs` の 2、項目別 map 3（`task_schedules.rs:112`、`work_records.rs:189`、`work_record_photos.rs:202`）を除いた 96 が区分 C（§3.2.1）。定型本文の件数（§2.7 の下位パターン表）は、同じ切り出しで `"error"\s*:\s*"unauthorized"`（21 箇所 / 11 ファイル）、`"error"\s*:\s*"internal"`（88 箇所 / 23 ファイル）などの正規表現を数えた。

`{success: false, message}` 形式の 47 箇所は、`cultivation_plans_mutations.rs`（32）・`cultivation_plans.rs`（5）・`field_cultivation_climate.rs`（5）・`field_cultivations.rs:197`（1）・`public_plans.rs:601-616`（4）の `"success": false` のうち `message` を持つものを数えた。正規表現 `"success"\s*:\s*false\s*,\s*"message"` の一致数で確認した（5 ファイル合計 47）。上記スクリプトの `success:false` 列はこのうち `field_cultivations.rs` の `errors` 側 1 箇所を含む。
