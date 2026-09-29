# 09: 設計文書が実装と乖離・リンク切れ（ADR-002 / organization-data-model / SLI-SLO ほか）

本書は**対応計画のみ**であり、コード・文書の修正は含まない。記載する事実は 2026-09-29 時点のリポジトリ（`master`）を実際に読んで確認したものだけで、`file:line` を付ける。読んでいない・実行していないものは「未確認」と明記する。

参照した規約: [`ARCHITECTURE.md`](../../ARCHITECTURE.md)、[`docs/architecture/LAYER-RULES.md`](../architecture/LAYER-RULES.md)、[`tdd-on-edit`](../../.cursor/skills/tdd-on-edit/SKILL.md)、[`evidence-before-design-and-implementation.mdc`](../../.cursor/rules/evidence-before-design-and-implementation.mdc)、[`project-necessary-code-only.mdc`](../../.cursor/rules/project-necessary-code-only.mdc)。

---

## 1. 概要と重大度

### 概要

設計文書（ADR・設計メモ・運用文書）が実装・ファイル配置と乖離している。5 系統ある。

| # | 系統 | 要旨 |
|---|------|------|
| A | ADR-002 の記述ずれ | Context の「現状」表、参照ファイル名、フェーズ進捗表が実装（2026-08-06 に epic #604 の子 issue がすべて close 済み）に追随していない |
| B | クォータの記述 | `ARCHITECTURE.md` / `organization-data-model.md` / ADR-002 が「ユーザー単位」。実装は経路により「組織単位」と「ユーザー単位」が混在しており、**正しい記述は課題 01 の決定待ち** |
| C | SLI/SLO 文書 | 相対リンク 6 箇所（5, 54, 135, 141 行の 4 行に 6 リンク）が `docs/.cursor/...` を指して切れている。ヘルスエンドポイントの出典が 1 ファイルのみ |
| D | 全 Markdown のリンク切れ | 対象 39 ファイル・ローカルリンク 374 件のうち **20 件が切れ**。既存 CI（`doc-freshness.yml`）は検査対象が 6 ファイル固定のため検知していない |
| E | 存在しないパス参照 | `LAYER-RULES.md:27` と `CLAUDE.md:51` の `composition.rs`、ADR-002 の `V15__organizations.sql` など。追加で `ARCHITECTURE.md` の「Rails shell が残る」記述も実態と乖離（§2.7、スコープ判断が必要） |

### 重大度

| 項目 | 重大度 | 理由 |
|------|--------|------|
| A ADR-002 の記述ずれ | 中 | ADR は設計判断の正本。「現状は `user_id` のみ」を信じると、実装済みの org スコープ認可を見落として重複実装・誤修正を招く。実行時の不具合はない |
| B クォータ記述 | 中（01 に従属） | `ARCHITECTURE.md` は L1 の規範文書。実装と食い違うまま放置すると、01 の修正後も文書が誤る。今は正解が確定しないため**書き換えない** |
| C SLI/SLO のリンク切れ | 低〜中 | 障害時ランブックの参照先（deploy-server / production-admin スキル）に辿り着けない。運用手順書であるため中に近い |
| D リンク切れ全般 | 低 | 20 件中 11 件が `docs/migration/archive/` 内（履歴文書）。ただし機械検査の網が狭い点は再発要因 |
| E 存在しないパス参照 | 低〜中 | `LAYER-RULES.md` は L2 規範。エージェントが存在しない `composition.rs` を探す |

いずれも本番挙動には影響しない（文書のみ）。

---

## 2. 現状（確認済み事実）

### 2.1 ADR-002 の記述と実装の照合

ADR-002（`docs/adr/ADR-002-organization-multi-tenancy.md`、Status: Accepted 2026-08-06、`:5`）を全文読み、実装と照合した。

| # | ADR の記述 | 実装（確認した根拠） | 判定 |
|---|-----------|---------------------|------|
| A1 | `:11` 「現状は **ユーザー単位のテナント分離** のみ」 | org 単位の認可・一覧が実装済み（A2〜A3） | 乖離 |
| A2 | `:24` `farm_policy.rs` — `user_id == Some(user.id)` | `farm_policy.rs:30-41` の `view_allowed` / `edit_allowed` 自体は `user_id` 判定のまま。ただし `farm_policy.rs:22-27` の `record_access_filter` が `ReferenceRecordAccessFilter` を返し、`crates/agrr-domain/src/shared/reference_record_access_filter.rs:37-51`（`view_allows`）と `:53-67`（`edit_allows`）が「policy が許可、または `organization_member_access`（`crates/agrr-domain/src/shared/org_scope.rs:14-23`）が許可」で判定する | 乖離（判定が 2 段構えに変わった） |
| A3 | `:25` `reference_index.rs` — `user_id = ?` | `crates/agrr-adapters-sqlite/src/shared/reference_index.rs:13-24` の `org_in_clause`（`organization_id IN (...)`）と、`:29-45`（`ReferenceOrOwned`）・`:47-64`（`OwnedNonReference`）の WHERE。org 所属がない場合のみ `user_id` 単独（`:30-34`, `:48-52`）。org 所属ありでも `organization_id IS NULL AND user_id = ?` を許す（`:41`, `:59`）＝未バックフィル行の救済 | 乖離 |
| A4 | `:17` 「Farm / Crop 作成上限は `user_id` 単位」 | 経路により異なる（§2.2） | 乖離（起票時点の記述としては正しい） |
| A5 | `:55` クォータ「フェーズ 2」「personal org は現行と同等」 | masters 経由の作成は既に org 単位で数えている（§2.2）。「契約プランに応じた org 単位上限」（`organization-data-model.md:104`）の実装は未確認（`farm_create_limit.rs:5` は定数 4 のみで、プラン別の分岐は読んだ範囲に無い） | 進捗ずれ（フェーズ 1 の中で先行実装） |
| A6 | `:66` `OrganizationAccessPolicy`（仮称） | 実在: `crates/agrr-domain/src/organization/policies/organization_access_policy.rs`（`member_access_allowed` `:15-26`、`manage_members_allowed` `:38-40` ほか） | 仮称が確定名に。乖離は軽微 |
| A7 | `:67` `FarmPolicy` 等に `organization_id` チェックを追加 | 追加先は `FarmPolicy` 関数本体ではなく `ReferenceRecordAccessFilter`（A2）。`crop_policy.rs` / `pest_policy.rs` 等 6 ポリシーも `organization` に言及（`rg` で確認、個別の中身は未確認） | 機構が記述と異なる |
| A8 | `:102` `V15__organizations.sql`（新規） | 実在するのは `crates/agrr-migrate/migrations/schema/V16__organizations.sql`。`V15__api_key_scopes.sql` は別物 | 誤記 |
| A9 | `:73-78` API 形状（`/api/v1/organizations` ほか 4 ルート） | `crates/agrr-server/src/organizations.rs:44-60` に同一の 4 ルートが実在。`lib.rs:177` で `merge` 済み | 一致 |
| A10 | `:80` 認可「owner または admin（メンバー管理）」 | `organization_access_policy.rs:38-40` と一致 | 一致 |
| A11 | `:42-47` personal org バックフィル（1:1・冪等・Tier 1 に `organization_id` 設定） | 起動時に非同期実行（`crates/agrr-server/src/lib.rs:124-127`、`personal_organization.rs:9`）。未所属ユーザーのみ対象（`personal_organization_sqlite_gateway.rs:93-98` の `NOT EXISTS`）、slug は `user-{id}`（`personal_organization_policy.rs:4-6`）、Tier 1 更新は `personal_organization_sqlite_gateway.rs:29-30,81,114-129` | 一致（実行形態は「マイグレーション」ではなく起動時処理。`V16__organizations.sql:2` の「Backfill is a separate migration」とも表現が異なる） |
| A12 | `:106` フロント「org 切替 UI・コンテキスト」 | `frontend/src` に `v1/organizations` の参照が無い（`rg` 0 件）。未実装 | 一致（未実装のまま） |
| A13 | `:119-127` フェーズ進捗表 | `#604` と `#606`〜`#612` は `gh issue view` ですべて CLOSED（2026-08-06）。表に状態列がない。`:117` の「起票後に issue 番号を本表へ追記する」は追記済みで陳腐化。表の「フェーズ 1〜6」は実装順であり、`:49-58` の製品フェーズ（1 / 2 / 3+）と語が衝突している（#607〜#612 の GitHub タイトルはすべて「Phase 1」） | 乖離 |
| A14 | `:46` 移行期間中は `user_id` を残し `organization_id` 優先へ段階的切替 | 一致。`farm_policy.rs:48-49` は作成時に `user_id`（作成者）と `organization_id` の両方を設定 | 一致 |
| A15 | 複数 org 所属ユーザーが新規作成するときの所属先 | ADR に規則の記載なし（`:80` は「`organization_id` コンテキストを注入」のみ）。実装は `member_organization_ids` の先頭（`farm_create_interactor.rs:71-72`、`crop_create_interactor.rs:60-61`）で、先頭は `ORDER BY id`（`organization_membership_sqlite_gateway.rs:92`）＝最古の所属 | ADR に未記載の決定事項（§2.2 と同根、01/10 に関連） |

### 2.2 クォータの実装状況（課題 01 の決定に必要な事実。本書では方針を決めない）

| 経路 | 数え方 | 根拠 |
|------|--------|------|
| Farm 作成（masters） | **組織単位** | `crates/agrr-domain/src/farm/interactors/farm_create_interactor.rs:122-125`、SQL は `crates/agrr-adapters-sqlite/src/farm/farm_gateway.rs:303`（`WHERE organization_id = ?1 AND is_reference = 0`） |
| Crop 作成（masters） | **組織単位** | `crop_create_interactor.rs:140-143`、`crop_gateway.rs:144` |
| Crop 作成（AI upsert） | **組織単位** | `crates/agrr-adapters-sqlite/src/crop/crop_ai_upsert_sqlite_persistence.rs:175-177` |
| 公開計画の保存に伴う Farm 作成 | **ユーザー単位** | `crates/agrr-domain/src/cultivation_plan/interactors/plan_save_ensure_user_farm_interactor.rs:82-83`、SQL は `crates/agrr-adapters-sqlite/src/cultivation_plan/plan_save_gateways.rs:105`（`WHERE user_id = ?1`） |
| 公開計画の保存に伴う Crop 作成 | **ユーザー単位** | `plan_save_ensure_user_crops_interactor.rs:122-123`、`plan_save_gateways.rs:283` |

- 上限値の定数名は `MAX_NON_REFERENCE_FARMS_PER_USER = 4`（`farm_create_limit.rs:5`）、`MAX_NON_REFERENCE_CROPS_PER_USER = 20`（`crop_create_limit_policy.rs:3`）のまま。
- エラーメッセージは「作成できるFarmは4件までです」等（`config/locales/ja.yml:358,362`、`en.yml:226,230`）。
- 文書側の記述は次の 4 箇所すべてが「ユーザー単位」または「現行と同等」:`ARCHITECTURE.md:90-91`、`organization-data-model.md:96-104`、ADR-002 `:17,55`。
- 上表の「組織単位／ユーザー単位」の混在をどちらに寄せるかは課題 01 の決定事項。本書は決定に**依存する文書修正箇所の一覧**（§3.2）だけを用意する。

### 2.3 SLI/SLO 文書（`docs/ops/core-api-optimization-sli-slo.md`）

リンク切れ（`docs/ops/` から見て `../.cursor/` は `docs/.cursor/` を指す。正しくは `../../.cursor/`）:

| 行 | リンク先 |
|----|----------|
| 5 | `deploy-server` / `production-admin` / `production-primary-sqlite-query` の各 SKILL.md（3 リンク） |
| 54 | `production-primary-sqlite-query` |
| 135 | `deploy-server`（§緊急復旧。`.cursor/skills/deploy-server/SKILL.md:76` に該当見出しが実在） |
| 141 | `production-primary-sqlite-query` |

同じ文書の 140 行・150 行は既に `../../.cursor/...` で正しく、内部で書式が不統一。

ヘルスエンドポイント（`:6`）: 出典が `crates/agrr-server/src/lib.rs` のみ。実装は次のとおり分かれる。

- `/health` と `/up`: `lib.rs:149-150`（固定文字列 `"ok"` を返す）
- `/api/v1/health`: `crates/agrr-server/src/routes.rs:18`（ルート定義）、ハンドラ `routes.rs:26` の `api_v1_health`（JSON。`status` / `database` / `recaptcha_configured` 等を返す）。`lib.rs:179` の `merge(routes::api_routes())` で組み込まれる
- 同ファイルに `/api/v1/ready`（`routes.rs:19`）があるが、本文書は未記載

この文書には内容検査テストがある。`scripts/verify-core-api-optimization-sli-slo-doc-lib.mjs:6-84` が必須見出し・キーワード・`### Runbook:` 2 件以上を要求し、`frontend-test.yml:191` で実行される。リンク修正だけならこの検査に影響しない（§5 で実測）。

### 2.4 全 Markdown の相対リンク検査（機械実行）

**方法**: 一時 Python スクリプト（`/tmp/lc/check.py`、リポジトリ外・コミットしない）で、`docs/**/*.md`・`ARCHITECTURE.md`・`README.md`・`CLAUDE.md`・`AGENTS.md`（`docs/README.md` は `docs/**` に含まれる）を走査した。インラインリンク、画像、参照定義、`CLAUDE.md` の `@path` を対象とし、フェンスコード内・外部 URL・`mailto:` は除外。相対リンクは記載ファイルのディレクトリ基準で解決し、存在を確認した。`#anchor` は対象が `.md` の場合に見出し slug との一致も確認した。

**結果**: 39 ファイル（`docs/spec-defects/` 作成前の測定。03・04 追加後は 41 ファイル・380 件で、追加分に切れなし）、ローカルリンク 374 件、**切れ 20 件**、anchor 不一致 0 件。

| # | 記載ファイル:行 | 記載リンク | 解決先（存在しない） | 正しい参照（実在を確認） |
|---|-----------------|-----------|----------------------|--------------------------|
| 1 | `docs/design/layout-contracts.md:4` | `../frontend/e2e/smoke/layout-archetype-design-contracts.mjs` | `docs/frontend/e2e/...` | `../../frontend/e2e/smoke/layout-archetype-design-contracts.mjs` |
| 2 | `docs/migration/app-rust-stack/PROVISIONAL-STACK.md:73` | `../../../lib/composition_root.rb` | `lib/composition_root.rb` | 参照先は削除済み（コミット `d3c583d9b`、2026-06-01）。リンクを外す |
| 3 | `docs/migration/app-rust-stack/README.md:27` | `../../test/README.md` | `docs/test/README.md` | `../../../test/README.md` |
| 4-5 | `docs/migration/archive/README.md:12`（2 リンク） | `../../.cursor/skills/test-common/SKILL.md` / `../../test/README.md` | `docs/.cursor/...` / `docs/test/...` | `../../../.cursor/skills/test-common/SKILL.md` / `../../../test/README.md` |
| 6-8 | `docs/migration/archive/P6-COMPLETION-CRITERIA.md:19,103,172` | `./ADR-strangler-lb-url-map.md` | `docs/migration/archive/ADR-...` | `../app-rust-stack/ADR-strangler-lb-url-map.md` |
| 9-13 | 同 `:31,97,118,171,173` | `./PRODUCTION-CUTOVER-STATUS.md` | `docs/migration/archive/PRODUCTION-...` | `../app-rust-stack/PRODUCTION-CUTOVER-STATUS.md` |
| 14 | 同 `:55` | `./PROVISIONAL-STACK.md` | `docs/migration/archive/PROVISIONAL-...` | `../app-rust-stack/PROVISIONAL-STACK.md` |
| 15-17 | `docs/ops/core-api-optimization-sli-slo.md:5`（3 リンク） | `../.cursor/skills/{deploy-server,production-admin,production-primary-sqlite-query}/SKILL.md` | `docs/.cursor/...` | `../../.cursor/skills/.../SKILL.md` |
| 18 | 同 `:54` | `../.cursor/skills/production-primary-sqlite-query/SKILL.md` | 同上 | `../../.cursor/...` |
| 19 | 同 `:135` | `../.cursor/skills/deploy-server/SKILL.md` | 同上 | `../../.cursor/...` |
| 20 | 同 `:141` | `../.cursor/skills/production-primary-sqlite-query/SKILL.md` | 同上 | `../../.cursor/...` |

- `docs/migration/archive/` 内が 11 件（#4-14）。移行時に `docs/migration/` 直下から `archive/` へ移動した際に相対パスが更新されなかった形跡（`./` で兄弟を指している）。
- `ARCHITECTURE.md` / `README.md` / `docs/README.md` / `CLAUDE.md` / `AGENTS.md` / `LAYER-RULES.md` に切れは無い。

**既存 CI の検査範囲との突き合わせ**:

- `scripts/check-doc-internal-links.sh` → `checkDocInternalLinks`（`scripts/check-doc-freshness-lib.mjs:202-221`）。対象は `LINK_SCAN_FILES` の **6 ファイル固定**（`:44-51`）で、`docs/ops`・`docs/design`・`docs/migration` は対象外。
- CI: `.github/workflows/doc-freshness.yml:24-25`。現在 `./scripts/check-doc-internal-links.sh` は OK で終わる（実行確認済み）。上記 20 件を検知できない理由はこれ。
- 切れ 20 件がすべて既存の検査範囲外にあることは、`checkDocInternalLinks` の対象を `docs/**/*.md` に広げた一時コピー（`/tmp` 上）で実行し、独立実装の上記スクリプトと**同じ 20 件**が出ることで確認した。フェンスコード内の偽陽性は出なかった。

### 2.5 パス参照（バッククォート内）の陳腐化

**方法**: 一時 Python スクリプト（`/tmp/lc/paths.py`）で `docs/**/*.md` のバッククォート内トークンのうち `crates/` `docs/` `scripts/` `frontend/` `lib/` `app/` `test/` `.cursor/` `tools/` `config/` `db/` `bin/` `Dockerfile` 等で始まるものを抽出し、リポジトリ直下または記載ファイル基準で存在確認した。178 件を検査し、**46 件が存在しない**。手作業で文脈を読んで分類した。

| 分類 | 件数の目安 | 対象 | 措置 |
|------|-----------|------|------|
| **要修正（現行の規範・仕様文書）** | 2 件 | `docs/adr/ADR-002-...md:102`（`V15__organizations.sql` → 実在は `V16`）、`docs/architecture/LAYER-RULES.md:27`（`composition.rs`） | §3 で修正。`CLAUDE.md:51` も同じ誤り（検査対象ファイルだが上記 46 件の外） |
| **要判断（運用手順）** | 1 件 | `docs/migration/app-rust-stack/P7-MIGRATION-RUNBOOK.md:175` `db/fixtures/india_reference_weather.json`。`db/fixtures/` には `*_reference_crops.json` の 3 ファイルしかなく該当ファイルは無い。「image に含まれる」という記述の真偽は**未確認**（`Dockerfile.agrr-server` は未読） | 本課題では修正しない。§7 に未確定として記載 |
| **履歴記録（削除済みを削除済みと明記）→ 変更不要** | 25 件 | 削除された旧 Ruby / Rails 時代のパス（旧ドメイン用ディレクトリ、旧 API コントローラ、`Dockerfile.production`、`config/routes`、`test/domain` 等）。文脈を読んで削除済み・旧世代と明記されていると確認した行: `PRODUCTION-CUTOVER-STATUS.md:25,36`、`P7-REFINERY-ADR.md:4,9,25`、`ADR-strangler-lb-url-map.md:31`、`P7-MIGRATION-RUNBOOK.md:91`、`PROVISIONAL-STACK.md:120`、`P8-RAILS-SHELL-REMOVAL.md:31,33,37`、`lib-domain-rust/ARCHITECTURE.md:3`（文書冒頭で旧世代の記述と明示）、`lib-domain-rust/TEST-STRATEGY.md:3`、`archive/README.md:18,20`、`P6-COMPLETION-CRITERIA.md:79,174` | 変更しない。`scripts/check-doc-freshness-lib.mjs:39-42` が `docs/migration/` を stale 検査の allowlist に入れているのと整合 |
| 履歴記録（残りの行） | 15 件 | `PROVISIONAL-STACK.md:130,140,169,170,274`、`P7-REFINERY-ADR.md:8`、`lib-domain-rust/ARCHITECTURE.md:10,40,44,98`、`archive/lib-domain-rust-TEST-STRATEGY-pre-p8.md:16,35`（`archive/` は `README.md` で履歴文書と明記）。`PROVISIONAL-STACK.md` は冒頭で「仮決定（2026-05-29）」と自己申告、`lib-domain-rust/ARCHITECTURE.md` は `:3` で era 明記。各行の文脈の個別読了は未実施 | 変更しない（履歴文書として扱う。個別確認は未実施のため断定しない） |
| **偽陽性** | 3 件 | `lib/core/agrr`（`PROVISIONAL-STACK.md:190,293`）は `.gitignore:178` で除外されたバイナリ（`lib/core/` には `.gitkeep` のみ）。`docs/ops/backdoor-threat-model.md:30` の `db/clear` はファイルではなく API 操作名 | 措置不要 |

**「Ruby:」コメント**:

- `docs/` 内の「Ruby:」は 2 件のみ。`docs/migration/archive/lib-domain-rust-TEST-STRATEGY-pre-p8.md:42`（当時のテストコード例）と `docs/migration/app-rust-stack/PROVISIONAL-STACK.md:144`（移行当時の Ruby アダプタ名との対応メモ。Rust 側の対応ポートは `crates/agrr-domain/src/shared/ports/cultivation_plan_phase_broadcast_port.rs` に実在）。どちらも履歴文書内で、修正不要。
- 参考（`docs/` の外、本課題の範囲外）: `crates/` 配下の Rust ソースには `Ruby:` コメントが `rg -c` で 901 ファイル・合計 1483 件ある（例 `farm_policy.rs:29`、`reference_record_access_filter.rs:6,12`）。文書ではなくコード内コメントなので本課題では扱わず、課題 11 の候補として §9 に記載する。

### 2.6 「Ruby」「Rails」を含む現行文書の記述（`docs/migration/` 以外）

- `docs/testing/angular_frontend_mechanical_checks.md:5`: 「**Rails**: 開発環境では `enable_reloading = true` のため…再起動不要」。次項のとおり Rails 設定ファイルは既に削除されており、この記述は実態に合わない。
- 同 `:20`、`docs/README.md:12,23`: 「Ruby 契約は P8.6 で削除済み」等、削除済みと明記しており問題なし。

### 2.7 追加で確認した乖離: 「Rails shell が残る」記述（スコープ判断が必要）

依頼の 4 課題の外だが、「設計文書が実装と乖離」に該当し、`ARCHITECTURE.md` を編集する課題 2 と同じファイルに関わるため記録する。

| 文書 | 記述 |
|------|------|
| `ARCHITECTURE.md:9` | 「A **Rails shell** remains for local SPA fallback, static pages, and dev/test helpers only」 |
| `ARCHITECTURE.md:16` | 「Rails shell (dev) \| SPA fallback, `auth_test`, static pages only」 |
| `README.md:90` | 「開発シェル（縮小中） \| Rails 8 — SPA フォールバック・契約テスト用 AR・`auth_test` のみ」 |
| `CLAUDE.md:7` | 「Rails shell is **dev/local only**」 |

実態:

- リポジトリ直下に `app/`・`Gemfile` は無く、`config/` は `litestream*.yml`・`locales/`・`reference-fixtures.lock.json` のみ（`ls` で確認）。`.rb` は `db/*_archive/`（129 件）、`bin/`（1 件）、`scripts/`（3 件）、`.cursor/skills/research-tools/scripts/`（1 件）に残るが、Rails アプリ本体（`app/`・`Gemfile`・`config/application.rb`）は無い。
- `docs/migration/app-rust-stack/P8-RAILS-SHELL-REMOVAL.md:33` が `config/application.rb`・`bin/rails` 等の削除済みを列挙し、フェーズ表で P8.7 は「完了」（2026-06-02）。
- `docker-compose.yml` の profile は `test` のみ（`:85-86`）。`.cursor/skills/dev-docker/SKILL.md:80` の `rails-up.sh` は `.cursor/skills/dev-docker/scripts/` に存在しない（`ls` で確認）。
- `auth_test` は Rust 側に実在（`crates/agrr-server/src/auth_test.rs`、`lib.rs:178`）。

`ARCHITECTURE.md` は L1 の規範文書、`CLAUDE.md` はエージェント入口であり、本節の記述をどう改めるかは規範文書の変更にあたる。**本課題に含めるかは判断が必要**（§7）。含めない場合も、事実として本節に残す。

---

## 3. 修正方針

### 3.1 文書ごとの Before / After

原則: **事実の更新だけ**を行い、設計判断（Decision）は書き換えない。日付・issue 番号は実装時に確認して記入する（本書では推測しない）。

#### (a) `docs/ops/core-api-optimization-sli-slo.md`（01 に依存しない・確定）

| 箇所 | Before | After |
|------|--------|-------|
| `:5` | `(../.cursor/skills/deploy-server/SKILL.md)` ほか 3 リンク | `(../../.cursor/skills/.../SKILL.md)` |
| `:54` `:135` `:141` | `(../.cursor/skills/...)` | `(../../.cursor/skills/...)` |
| `:6` | `**ヘルスエンドポイント**: /health, /up, /api/v1/health（crates/agrr-server/src/lib.rs）` | `**ヘルスエンドポイント**: /health, /up（crates/agrr-server/src/lib.rs）、/api/v1/health（crates/agrr-server/src/routes.rs）` |

`/api/v1/ready` を併記するかは任意（§7）。併記しない場合、文書の意図（SLI 測定用）に変更はない。

#### (b) その他のリンク切れ（確定）

§2.4 の表の「正しい参照」列のとおり。#2（`PROVISIONAL-STACK.md:73`）だけはリンク先が存在しないため、リンクを外して「`lib/composition_root.rb`（P8 で削除済み）」とテキスト化する。一時コピー（`/tmp` 上）で全 20 件を修正すると切れ 0 件になることを確認済み。

#### (c) `docs/architecture/LAYER-RULES.md:27` と `CLAUDE.md:51`（確定）

| ファイル | Before | After（案） |
|----------|--------|-------------|
| `LAYER-RULES.md:27` | `injected at the edge in \`crates/agrr-server/src/composition.rs\`` | `injected at the edge in the handler modules under \`crates/agrr-server/src/\`` |
| `CLAUDE.md:51` | `Edge: \`crates/agrr-server/src/\` (routes, \`composition.rs\`, presenter wiring)` | `Edge: \`crates/agrr-server/src/\` (routes, handler-side interactor wiring, presenter wiring)` |

根拠: `composition.rs` はどのコミットでも現行ツリーに存在せず（`find crates -name 'composition*'` が 0 件）、interactor の組み立ては各ハンドラで行われる（例: `crates/agrr-server/src/masters_farms.rs:148-160`）。`LAYER-RULES.md` には内容検査 `scripts/check-layer-rules-md-lib.mjs`（禁止語・許可パス接頭辞・100 行上限）があるが、After 案は `crates/agrr-server` 接頭辞で許可され、禁止語も含まない。修正後の文書は 71 行のまま。

なお `docs/` 外に同じ誤りがある（`.cursor/skills/clean-architecture-violation-fix-workflow/SKILL.md:25,58,82`、`.cursor/rules/rails-clean-architecture.mdc:22`）。本課題は `docs/` と依頼が列挙したルート文書が対象のため範囲外とし、§7 に記載する。

#### (d) `docs/adr/ADR-002-organization-multi-tenancy.md`

**ADR を更新するか、新 ADR を追加するかの判断基準**（本リポジトリに ADR 改訂規約は見当たらない。`ADR-001` も同じ構成で、`.cursor/rules` に ADR 更新義務の記載は読んだ範囲に無い。以下は本書の提案）:

| 変更の性質 | 例 | 措置 |
|-----------|----|------|
| 実装が Decision に追いついた（事実の更新） | Context の参照実装表、`V15`→`V16`、進捗表 | ADR-002 を**その場で更新**。Status は Accepted のまま |
| 仮称の確定・機構の言い換え（Decision の意図は不変） | `OrganizationAccessPolicy`（仮称）、`FarmPolicy` に追加 → `ReferenceRecordAccessFilter` 経由 | ADR-002 を**その場で更新**（実装名を明記） |
| Decision 自体の変更・追加 | クォータの集計単位の確定（テナント単位かユーザー単位か）、複数所属時の org 選択規則の新設（A15）、role 別権限の変更 | **新 ADR（ADR-003 以降）** を追加し、ADR-002 の該当節に「Amended by ADR-00x」を 1 行追記 |

**現時点の判定**: A1〜A3・A6〜A8・A13 は事実の更新なので**その場更新**。A4・A5（クォータ）と A15（所属先の選択規則）は Decision の中身に触れるため、**課題 01 の決定内容を見て**「その場更新で足りるか / 新 ADR が要るか」を再判定する。文書側で仕様を先取りして書かない。

**その場更新の差分案**（A4・A5・A15 以外）:

| 箇所 | Before | After（案） |
|------|--------|-------------|
| `:11` | `AGRR は現状 **ユーザー単位のテナント分離** のみを持つ。…` | `AGRR は起票時点（2026-08-06）で **ユーザー単位のテナント分離** のみを持っていた。現在は organization 単位のアクセス制御が併存する（下記「実装状況」）。…`（以降の `user_id` スコープの説明は起票時点として保持） |
| `:19-26` 見出しと表 | `現状の参照実装:`（`farm_policy.rs — user_id == Some(user.id)`、`reference_index.rs — user_id = ?`） | 見出しを `起票時点の参照実装:` に改め、表はそのまま保持。直後に `実装状況（YYYY-MM-DD 時点）` 表を追加し、`farm_policy.rs:22-27` と `reference_record_access_filter.rs:37-67`（policy または org メンバーシップで許可）、`reference_index.rs:13-64`（`organization_id IN` を org 所属時に使用）を記載 |
| `:66` | `OrganizationAccessPolicy`（仮称） | `OrganizationAccessPolicy`（`crates/agrr-domain/src/organization/policies/organization_access_policy.rs`） |
| `:67` | `FarmPolicy 等は organization_id チェックを追加し…` | `既存ポリシーの org 対応は ReferenceRecordAccessFilter（crates/agrr-domain/src/shared/reference_record_access_filter.rs）を介して行う。user_id 単独判定は policy 側に残る` |
| `:102` | `V15__organizations.sql（新規）` | `V16__organizations.sql` |
| `:106` | `org 切替 UI・コンテキスト（フェーズ 1 以降の子 issue）` | 変更しない（未実装のまま。任意で「未着手」と明記） |
| `:117` | `…起票後に issue 番号を本表へ追記する。` | 該当文を削除（追記済み） |
| `:119-127` 表 | 列: フェーズ / Issue / 内容 | 列名を `ステップ` に改め（`:49-58` の製品フェーズとの衝突回避）、`状態` 列を追加。#606〜#612 を `完了（2026-08-06）`。日付は各 issue の `closedAt` を実装時に再取得して記入 |

**`:55`（クォータ行）と `:17` は 01 の決定待ち**（§3.2）。

#### (e) `docs/design/organization-data-model.md`

| 箇所 | Before | After（案） | 依存 |
|------|--------|-------------|------|
| `:1`, `docs/README.md:8` | `Organization データモデル案` | 任意: 実装済みの旨を 1 行追記（見出し改名は index 文言との同期が要るため §7 の判断事項） | なし |
| `:62` | `新規作成時は organization_id を必須とし` | `新規作成時は domain 層で organization_id を必須とし（DB 列は nullable: V16__organizations.sql:1）` 。根拠 `farm_policy.rs:43-50`（`organization_id: i64` を必須引数） | なし |
| `:92` | `バックフィルスクリプトは is_personal = 1 の org が既に存在するユーザーはスキップ。` | `バックフィルは起動時に実行され（crates/agrr-server/src/lib.rs:124-127）、personal org を持たないユーザーのみ対象（personal_organization_sqlite_gateway.rs:93-98）。` | なし |
| `:94-104` クォータ移行 | 「現行: ユーザーあたり…」「personal org: 現行と同等」 | §3.2 | **01** |
| `:119-126` 関連ファイル | パス | 変更不要（実在確認済み） | なし |

`:83-90` の移行手順（slug `user-{id}`、name は email か `Personal`）は `personal_organization_policy.rs:4-16` と一致しており、修正不要。

### 3.2 課題 01 の決定後に反映する文書修正箇所の一覧

01（resource-limit-bypass: クォータのスコープ確定）が決まるまで、次の箇所は**書き換えない**。決定後は下表を機械的に処理する。

| # | 箇所 | 現行の記述 | 01 の決定ごとの反映内容 |
|---|------|-----------|-------------------------|
| Q1 | `ARCHITECTURE.md:90` | `Farm: max 4 non-reference farms per user` | 集計単位（user / organization）に合わせ `per user` を書き換え。単位が organization の場合は「メンバーが複数 org に所属する場合の所属先規則」も 1 行明記（A15 参照） |
| Q2 | `ARCHITECTURE.md:91` | `Crop: max 20 non-reference crops per user` | 同上 |
| Q3 | `organization-data-model.md:96-99` | `現行: Farm: ユーザーあたり…` / `Crop: ユーザーあたり…` | 決定後の実装に合わせて更新（識別子 `FarmCreateLimitPolicy` / `CropCreateLimitPolicy` は実在: `farm_create_limit.rs:2`、`crop_create_limit_policy.rs` はモジュール名） |
| Q4 | `organization-data-model.md:101-104` | 移行後: personal org は現行と同等、法人 org は契約プラン別（フェーズ 2） | 「masters 経路は既に org 単位」（§2.2）を反映するか、01 で経路を統一した結果に合わせる。契約プラン別上限の有無は未確認のため、01 の決定に無ければ「未定義」と明記 |
| Q5 | ADR-002 `:17` | `Farm / Crop 作成上限は user_id 単位` | `起票時点` として保持（Context）。Decision に触れる場合は新 ADR（§3.1(d)） |
| Q6 | ADR-002 `:55` | クォータ行: フェーズ 2 / personal org は現行と同等 | 01 の決定に応じて「実装済み」「フェーズ 2 未実装」を書き分け |
| Q7 | 用語 | 定数名 `..._PER_USER`（コード側） | コード側の改名は 01 の作業。文書は識別子を引用していないため（`ARCHITECTURE.md:90-91` は定数名を引用しない）追随不要 |

Q1〜Q7 は 01 のマージ**後**に実施する（先行すると 01 の結論とずれた記述が再び残る）。

### 3.3 実施しないこと

- `docs/migration/` 配下の履歴記録の書き換え（リンク切れ 13 件の修正を除く。うち `PROVISIONAL-STACK.md:73` は削除済みファイルのためリンクを外す）。
- `crates/` 配下の `Ruby:` コメントの一括除去（範囲外。課題 11 候補）。
- アンカー検査・バッククォート内パス検査の CI 追加（§4 で理由を述べる）。

---

## 4. 再発防止

### 現状の仕組み

既存の `scripts/check-doc-internal-links.sh`（`check-doc-freshness-lib.mjs:202-221`）が CI（`doc-freshness.yml:24-25`）で走っている。仕組み自体は機能しているが、対象が固定 6 ファイル（`:44-51`）であることが、20 件のリンク切れを見逃した直接原因（§2.4）。

### 案の比較

| 案 | 内容 | 評価（`project-necessary-code-only` に照らして） |
|----|------|------------------------------------------------|
| **A. 文書修正のみ** | 20 件を直して終える | 最小。ただし同じ原因で再発する。依頼の「再発防止」を満たさない |
| **B. 既存チェッカの対象拡張（推奨）** | `listLinkCheckFiles`（`:53-55`）を、既存の `LINK_SCAN_FILES` に加えて `docs/**/*.md` も走査するよう変更。`walkMarkdown`（`:27-37`）は既に同ファイルにあり再利用できる。新規スクリプトは追加しない | 既存の仕組みの穴を塞ぐだけ。`docs/**/*.md` に広げても、修正後のツリーでは切れ 0 件・偽陽性 0 件だと一時コピーで実測済み |
| C. アンカー検査・バッククォート内パス検査を追加 | 見出し slug の一致、`` `crates/...` `` の存在確認 | **不要**。アンカー不一致は今回 0 件。バッククォート内パスは偽陽性が多い（§2.5: gitignore 済みバイナリ、API 操作名、履歴文書内の削除済みパス 40 件）。追加する根拠が無い |
| D. 新規スクリプト・新規ワークフロー | 別スクリプトでリンク検査 | 既存と重複するため**追加しない** |

### 推奨と条件

- **B を採用する場合の条件**: 先に §3.1(a)(b) のリンク修正を反映してからチェッカを拡張する。逆順だと CI が 20 件で失敗する。
- B はコード変更（`.mjs` とそのテスト）を含むため、**別コミット・別ステップ**に分け、`tdd-on-edit` に従って RED から始める（§5）。文書修正（例外扱い）と混ぜない。
- B の採否自体は本課題の依頼範囲（「要否を整理する」）のため、採用可否の最終判断は実装着手前に確認する（§7）。

---

## 5. 検証計画

### 5.1 文書のみの変更は TDD の例外

`tdd-on-edit` の例外（ドキュメント/設定のみ）に該当するため、§3.1 の文書修正（ADR・data-model・SLI/SLO・リンク修正・`LAYER-RULES.md` / `CLAUDE.md`）には RED テストを書かない。代わりに次の**機械検証**をすべて通す。

### 5.2 リンクチェックの実行手順

1. 既存 CI と同じ検査（リポジトリ直下で）:

   ```bash
   ./scripts/check-doc-internal-links.sh
   ./scripts/check-doc-stale-paths.sh
   node --test scripts/check-doc-freshness-lib.test.mjs
   node --test scripts/verify-core-api-optimization-sli-slo-doc-lib.test.mjs
   node --test scripts/check-layer-rules-md-lib.test.mjs
   ```

   期待: いずれも成功。現在の master で `check-doc-internal-links: OK`・`check-doc-stale-paths: OK` を確認済み。SLI/SLO と LAYER-RULES の 2 テストは、修正を当てた一時コピー（`/tmp` 上）で pass 4 / fail 0 を確認済み。

2. `docs/` 全体の網羅検査（一時実行。リポジトリに追加しない）。§2.4 の Python スクリプトと同じ方針で、`docs/**/*.md` + ルート 4 ファイルの相対リンクを解決し、切れ 0 件・anchor 不一致 0 件を確認する。スクリプトは `/tmp` 上に置き、実行後に削除してよい。

3. 追加の目視:

   - `git diff --stat` が編集対象の文書だけであること。
   - `docs/ops/core-api-optimization-sli-slo.md` の `### Runbook:` 見出し・必須節が残っていること（手順 1 のテストが担保）。
   - `docs/architecture/LAYER-RULES.md` が 100 行以下・禁止語なし（手順 1 のテストが担保）。

### 5.3 チェッカ拡張（案 B）を採用する場合のみ: TDD

`tdd-on-edit` と `test-common` の運用に従う（`node --test` は `doc-freshness.yml:34` が実行する既存経路。Rust/Frontend のテストランナーの対象外）。

1. **RED**: `scripts/check-doc-freshness-lib.test.mjs` に「`docs/` 配下の切れリンクを検出する」テストを追加する。既存の `checkDocInternalLinks fails on broken relative link`（`:25`）の形式に合わせ、一時ディレクトリに `docs/ops/x.md` と切れリンクを作って `ok === false` を期待する。本番ツリーに対する既存テスト `checkDocInternalLinks passes on production repo tree`（`:20`）は、**リンク修正前は 20 件で失敗**するため、修正前に拡張を入れると自然に RED になる。
2. **GREEN**: `listLinkCheckFiles` の拡張と、§3.1 のリンク修正を適用。
3. 全体: 上記 5.2 の手順 1 を再実行。

---

## 6. 実装ステップ

依存のない順。各ステップは別コミットにできる粒度。01 待ちのステップは最後に分離する。

| # | 内容 | 対象 | 01 依存 | 検証 |
|---|------|------|---------|------|
| 1 | SLI/SLO のリンク 6 箇所と `:6` のヘルスエンドポイント出典を修正 | `docs/ops/core-api-optimization-sli-slo.md` | なし | §5.2 手順 1・2 |
| 2 | その他のリンク切れ 14 件（#1-#14）を修正。#2 はリンクを外しテキスト化 | `docs/design/layout-contracts.md`、`docs/migration/app-rust-stack/{README,PROVISIONAL-STACK}.md`、`docs/migration/archive/{README,P6-COMPLETION-CRITERIA}.md` | なし | 同上 |
| 3 | `composition.rs` 参照を現行の記述に修正 | `docs/architecture/LAYER-RULES.md:27`、`CLAUDE.md:51` | なし | `check-layer-rules-md-lib.test.mjs`、§5.2 手順 1 |
| 4 | ADR-002 の「その場更新」（`:11`、`:19-26`、`:66-67`、`:102`、`:117`、`:119-127`。クォータ行 `:17,55` を除く） | `docs/adr/ADR-002-organization-multi-tenancy.md` | なし（`:17,55` を除く） | 目視 + §5.2 手順 1 |
| 5 | data-model の `:62`・`:92` を修正（`:94-104` は除く） | `docs/design/organization-data-model.md` | なし | 同上 |
| 6 | （案 B 採用時のみ）チェッカ拡張。RED → GREEN | `scripts/check-doc-freshness-lib.mjs`、`scripts/check-doc-freshness-lib.test.mjs` | なし（**1・2 の後**） | §5.3 |
| 7 | クォータ記述 Q1〜Q7 を反映。ADR は「その場更新 / 新 ADR」を再判定 | `ARCHITECTURE.md:90-91`、`organization-data-model.md:94-104`、ADR-002 `:17,55` | **あり（01 マージ後）** | §5.2 手順 1・2 |

ステップ 1〜5 と 7 は文書のみで、`test-common` のランナー対象（Rust/R4/Frontend）は無い。文書のみの変更では `rebuild-restart.sh`（`crates/*` 変更時のみ必要）も不要。

---

## 7. リスク・未確定事項

### 課題 01 の決定待ち

- クォータの集計単位（user / organization）と、複数 org 所属時の作成先 org の規則（§2.1 A15、§2.2）。**Q1〜Q7（§3.2）は決定まで着手しない。**
- 01 の結論が「Decision の変更」（テナント単位でのクォータ確定など）にあたる場合、ADR-002 の更新で済ませるか新 ADR を立てるか（§3.1(d) の基準で再判定）。

### 本課題内で判断が必要な事項

| # | 事項 | 選択肢 |
|---|------|--------|
| U1 | チェッカ拡張（案 B）の採否 | 採用（推奨）／文書修正のみ（案 A）。採用時は 1・2 の後に実施 |
| U2 | `ARCHITECTURE.md:9,16`・`README.md:90`・`CLAUDE.md:7` の「Rails shell が残る」記述（§2.7）を本課題に含めるか | 含める（ARCHITECTURE.md を触る 7 番と同時に整理）／別課題（11 など）に送る。`CLAUDE.md` はエージェント入口のため変更の可否をユーザーに確認したい |
| U3 | `LAYER-RULES.md:27` / `CLAUDE.md:51` の代替文言 | §3.1(c) の案でよいか。「配線を集約するモジュールを新設する」設計判断とは別物（本課題では新設しない） |
| U4 | `P7-MIGRATION-RUNBOOK.md:175` の `db/fixtures/india_reference_weather.json`（§2.5） | `Dockerfile.agrr-server` と運用手順を確認したうえで修正するか、履歴として残すか。**現時点は未確認**のため触らない |
| U5 | SLI/SLO `:6` に `/api/v1/ready`（`routes.rs:19`）を併記するか | 任意 |
| U6 | data-model の見出し「データモデル案」の改名 | `docs/README.md:8` の索引文言と同時変更が必要。任意 |

### 実装時のリスク

- `docs/spec-defects/` を含む `docs/` 配下はチェッカ拡張（案 B）の走査対象になる。本書を含む各 `docs/spec-defects/*.md` は相対リンクを実在パスで書く必要がある（本書は `../../` 形式で記載済み。§5.2 手順 1 で確認する）。
- `check-doc-stale-paths.sh` は `docs/` 配下の文書に旧 Ruby ドメイン用ディレクトリや旧 API コントローラのパスをそのまま書くと失敗する（`check-doc-freshness-lib.mjs:4-8`、allowlist は `docs/migration/` のみ `:39-42`）。本書はこれらの文字列を避けて記述している。ADR-002 の更新文面でも同様に避ける。
- `.cursor/skills/clean-architecture-violation-fix-workflow/SKILL.md:25,58,82` と `.cursor/rules/rails-clean-architecture.mdc:22` の `composition.rs` 参照は本課題で直さないため、規範文書間で一時的に表現が食い違う（未修正のまま放置しない: 課題 11 または別 issue で扱う）。
- 一時スクリプトの数値（39 ファイル・374 件・20 件、178 パス・46 件）は 2026-09-29 の `master` での測定値。他課題の文書追加（`docs/spec-defects/` 等）により総数は変わるが、既存の切れ 20 件は影響を受けない。

---

## 8. 受け入れ条件

文書修正（ステップ 1〜5、必要なら 7）の完了条件:

1. `./scripts/check-doc-internal-links.sh` と `./scripts/check-doc-stale-paths.sh` が成功する。
2. `node --test scripts/check-doc-freshness-lib.test.mjs`、`scripts/verify-core-api-optimization-sli-slo-doc-lib.test.mjs`、`scripts/check-layer-rules-md-lib.test.mjs` が成功する。
3. `docs/**/*.md` と `ARCHITECTURE.md`・`README.md`・`CLAUDE.md`・`AGENTS.md` の相対リンクを網羅検査した結果、**切れ 0 件**（一時スクリプトの実行結果を PR に貼る。スクリプト自体はコミットしない）。
4. `docs/ops/core-api-optimization-sli-slo.md:6` のヘルスエンドポイントの出典が `lib.rs`（`/health`, `/up`）と `routes.rs`（`/api/v1/health`）に分かれている。
5. ADR-002 に `V15__organizations.sql` が残っておらず、Context の「現状」表が起票時点と明記され、実装状況（org スコープの認可・一覧）が記載されている。フェーズ進捗表に状態が入っている。
6. `LAYER-RULES.md` と `CLAUDE.md` に存在しない `composition.rs` が残っていない。
7. 差分が編集対象の文書のみで、`crates/`・`frontend/` に変更がない（案 B 採用時は `scripts/check-doc-freshness-lib.{mjs,test.mjs}` を除く）。

クォータ記述（ステップ 7）の完了条件（**01 マージ後**）:

8. `ARCHITECTURE.md:90-91`・`organization-data-model.md:94-104`・ADR-002 `:55` が、01 の決定後の実装（集計単位・所属先規則）と一致している。§3.2 の Q1〜Q7 がすべて処理済み、または「未定義」と明記されている。

案 B 採用時の追加条件:

9. `docs/` 配下の切れリンクを検出するテストが追加され、修正前の master では RED、修正後は GREEN になる。新規スクリプト・新規ワークフローが増えていない。

---

## 9. 関連課題との依存

| 課題 | 関係 | 内容 |
|------|------|------|
| 01 resource-limit-bypass | **依存（本課題が待つ側）** | クォータのスコープ確定（§2.2、§3.2）。01 の決定前に `ARCHITECTURE.md:90-91` 等を書き換えない。01 が決まれば Q1〜Q7 を実施。01 のマージ後に本課題のステップ 7 を実行 |
| 02 contact-recaptcha | 依存なし | 未確認（本書では `routes.rs:26-36` の `/api/v1/health` が `recaptcha_configured` を返す事実のみ読んだ。SLI/SLO 文書の修正内容とは独立） |
| 03 api-key-scope-docs | 編集対象が重ならない | 03 の対象は `docs/api/getting-started.md`。本課題の編集ファイルと重複しない。リンク検査では `docs/api/` に切れなし |
| 04 api-key-query-auth | 依存なし | 未確認。本課題の編集ファイルと重複しない |
| 05 fail-closed-critical / 06 fail-closed-suspected | 競合の可能性（小） | `ARCHITECTURE.md` の fail-closed 節（`:69-73`、`:106-110`）を両課題が編集する可能性がある（各課題の内容は未読・未確認）。本課題は `ARCHITECTURE.md:90-91`（Resource Limits）と、U2 を含める場合は `:9,16` のみを触るため、行は離れている。同一ファイルへの同時 PR は rebase を要する |
| 07 frontend-error-contract | 依存なし | 未確認 |
| 08 openapi-gaps | 弱い依存 | `docs/api/openapi.yaml` に `organizations` の定義が無い（`rg` 0 件）。ADR-002 `:72-78` の API 形状は実装済み（`organizations.rs:44-60`）だが公開仕様書に無い。08 が追加したら、ADR-002 の References に openapi の該当箇所を足す（任意） |
| 10 authorization-consistency | 関連 | ADR-002 §4（`:62-69`）の記述と実装の機構差（A7）は、10 の認可の一貫性の結論と食い違わないよう、ステップ 4 の文面を 10 の確定後に見直す。実装側で気付いた不一致として `organization_access_policy.rs:80-82` の doc コメント（「Only `owner` may update org settings」）と実装（`owner` **または** `admin` を許可）が食い違う。これはコード側なので 10 に引き継ぐ |
| 11 low-priority-misc | 関連（引き継ぎ候補） | `crates/` の `Ruby:` コメント（901 ファイル・1483 件、§2.5）、U2（Rails shell 記述）、`.cursor/` 側の `composition.rs` 参照（§7）、`.cursor/skills/dev-docker/SKILL.md:77-94` の存在しない `rails-up.sh` 参照（`ls` で確認） |

### 実施順の目安

1. 依存なしのステップ 1〜5（並行可）
2. チェッカ拡張（案 B、採用時。1・2 の後）
3. 01 の決定・マージ後にステップ 7
