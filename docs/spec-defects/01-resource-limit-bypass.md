# 01: Farm / Crop 作成上限が経路ごとにスコープが異なりすり抜ける

- 状態: 対応計画（本書はドキュメントのみ。コード・テスト・マイグレーションは未変更）。上限のスコープは組織単位（案 A）で確定済み（§0）。未決は §3.5 の U1〜U3
- 対象: Farm(非参照)最大 4 件 / Crop(非参照)最大 20 件の上限
- 根拠ゲート: 本書の「確認済み」記述はすべて実コードを読んで再確認した file:line 付き。読んでいない・実行していないものは「未確認」と明記する（[`evidence-before-design-and-implementation.mdc`](../../.cursor/rules/evidence-before-design-and-implementation.mdc)）。
- 用語: 「Masters」= `POST /api/v1/masters/farms|crops` 系の作成経路（`FarmCreateInteractor` / `CropCreateInteractor`）。「plan-save」= 公開プランのユーザー保存経路（`PublicPlanSaveInteractor` → `PlanSaveEnsureUserFarm/CropsInteractor`）。

---

## 0. 決定事項

| # | 決定 | 状態 |
|---|---|---|
| D-1 | Farm（非参照 最大 4 件）/ Crop（非参照 最大 20 件）の上限は **組織（`organization_id`）単位に統一**する（本書 §3.2 の案 A） | **確定** |
| D-2 | **ユーザー単位カウントは廃止**する。plan-save が使う `count_non_reference_farms(user_id)`（`crates/agrr-domain/src/cultivation_plan/interactors/plan_save_ensure_user_farm_interactor.rs:82`）と `count_user_owned_non_reference_crops(user_id)`（`plan_save_ensure_user_crops_interactor.rs:122`）を組織単位の件数取得に置き換える | **確定** |
| D-3 | plan-save も **作成先組織を解決**して組織単位で上限を判定し、Farm / Crop の **INSERT に `organization_id` を設定**する（現状は INSERT に無い: `plan_save_gateways.rs:112-137`、Crop 属性に無い: `plan_save_ensure_user_crops_interactor.rs:139-178`。§2.3） | **確定** |

- 由来: ユーザー指示の語「**組織**」からの**解釈**である。指示は上限のスコープの単位を「組織」とする一語であり、次の点までは指示していない。したがって決定の範囲は D-1〜D-3 に限り、以下は §3.5 で未決のまま扱う。
  - 複数メンバー組織で枠を共有するか（U1）
  - 複数組織所属ユーザーの作成先組織の規則（U2）
  - `ARCHITECTURE.md` の「per user」文言をどこで直すか（U3）
- D-1 は Masters の現行挙動（組織単位: §2.2）と同じ向きであり、Masters の挙動は変えない。変わるのは plan-save のみ（§5、§10-5）。
- ユーザー単位カウントの残骸: Masters 側の `FarmGateway::count_user_owned_non_reference_farms`（`crates/agrr-domain/src/farm/gateways/farm_gateway.rs:39-43`）/ `CropGateway::count_user_owned_non_reference_crops`（`crates/agrr-domain/src/crop/gateways/crop_gateway.rs:17`）は、プロダクションコードの呼び出し元が無い（`rg '\.count_user_owned_non_reference' crates` のヒットは plan-save の 1 箇所 `plan_save_ensure_user_crops_interactor.rs:122` のみで、これは plan-save 専用トレイト `plan_save_crop_limit_gateway.rs:4` 経由）。D-2 に従い §7 で除去する。

---

## 1. 概要と重大度

### 概要

Farm / Crop の作成上限は、Masters 経路では「所属組織（`organization_id`）単位」、plan-save 経路では「ユーザー（`user_id`）単位」で数えられており、経路ごとにスコープが異なる。さらに plan-save が作成する Farm / Crop 行は `organization_id` を持たない（NULL）ため、組織単位で数える Masters 経路のカウントに入らない。その結果、plan-save で作った行が NULL のままの間は、Masters 側でさらに上限まで作成でき、上限を超えて保有できる。正の仕様は `ARCHITECTURE.md` では「per user」、ADR-002 では「org 単位に集約（personal org は現行と同等）」と文書間で食い違っており、実装は #612 で Masters だけが org 単位に移行済みで plan-save が取り残されている。

### 重大度

**中（Medium）**。

- 認可の破れ・他者データの漏えいではなく、プロダクト上のクォータ（上限）の回避である。
- すり抜け量は有限（確認済みの範囲では、plan-save 由来 NULL 行 + Masters 上限分。§4.1 の経路 X）。データ破壊・可用性影響は確認していない（未確認）。
- ただし Farm 作成は気象データ取得の起動を伴う（`apply_weather_fetch_start`、`crates/agrr-domain/src/farm/interactors/farm_create_interactor.rs:139-143`）ため、上限回避がコスト面の影響を持つ可能性はある（plan-save 経路で同様の起動が走るかは未確認）。
- 仕様の正が文書間で割れていた点（§3.1）は、組織単位（案 A）で確定した（§0）。文書側（`ARCHITECTURE.md` の `per user` など）が実装と食い違ったまま残ると再発するため、文書更新は課題 09 の依存として残る（§11）。

---

## 2. 現状（確認済み事実）

### 2.1 上限値とポリシー

| 項目 | 事実 | 根拠 |
|---|---|---|
| Farm 上限 | `MAX_NON_REFERENCE_FARMS_PER_USER = 4`、`limit_exceeded(count) = count >= 4` | `crates/agrr-domain/src/farm/policies/farm_create_limit.rs:5-9` |
| Crop 上限 | `MAX_NON_REFERENCE_CROPS_PER_USER = 20`、参照 Crop は対象外 | `crates/agrr-domain/src/crop/policies/crop_create_limit_policy.rs:3-10` |
| ポリシーの責務 | 「件数 → 超過か」のみ判定。件数の数え方（スコープ）はポリシーに無く、各 Interactor/Gateway に分散 | 上記 2 ファイル全体 |
| 文書 | 「max 4 non-reference farms per user / max 20 non-reference crops per user」「Enforced in domain policies」 | `ARCHITECTURE.md:88-94` |
| i18n メッセージ | 「作成できるFarmは4件まで」「作成できるCropは20件まで」（主語なし） | `frontend/src/assets/i18n/ja.json:3539,3557`、`config/locales/ja.yml:358,362` |

### 2.2 Masters 経路（組織単位）

| 事実 | 根拠 |
|---|---|
| Farm: 所属組織 ID 群の先頭（無ければ `ensure_personal_organization`）を `organization_id` とし、`count_non_reference_farms_for_organization(organization_id)` で数え、`FarmCreateLimitPolicy::limit_exceeded` で判定 | `farm_create_interactor.rs:70-77`, `:122-135` |
| Farm: 作成属性に `organization_id` を含める（`normalize_attrs_for_create`） | `crates/agrr-domain/src/shared/policies/farm_policy.rs:43-52`, `farm_create_interactor.rs:78-100` |
| Crop: 同様に組織 ID を解決し、非参照のとき `organization_id` を属性に入れて `count_non_reference_crops_for_organization` で判定 | `crates/agrr-domain/src/crop/interactors/crop_create_interactor.rs:59-66`, `:138-153` |
| Crop(AI upsert): `preflight_crop_limit` が同じく組織単位で判定。新規作成は `CropCreateInteractor` を通る | `crates/agrr-adapters-sqlite/src/crop/crop_ai_upsert_sqlite_persistence.rs:152-184`, `:275` |
| 組織 ID 群の並びは `organization_memberships` の `ORDER BY id`。`first()` は最初に作られた所属 | `crates/agrr-adapters-sqlite/src/organization/organization_membership_sqlite_gateway.rs:85-99`, `crates/agrr-domain/src/shared/org_scope.rs:6-11` |
| SQL: `SELECT COUNT(*) FROM farms WHERE organization_id = ?1 AND is_reference = 0`（NULL 行は数えない） | `crates/agrr-adapters-sqlite/src/farm/farm_gateway.rs:297-309` |
| SQL: `SELECT COUNT(*) FROM crops WHERE organization_id = ?1 AND is_reference = 0` | `crates/agrr-adapters-sqlite/src/crop/crop_gateway.rs:138-150` |
| INSERT は `organization_id` を書く | `farm_gateway.rs:381-393`, `crop_gateway.rs:191-202` |
| 組織単位化は #612（PR #628、コミット `e020f1c66`）で「Org-unit create limits (FarmCreateLimitPolicy / CropCreateLimitPolicy)」として意図的に導入された | `git show e020f1c66`（コミットメッセージ） |

### 2.3 plan-save 経路（ユーザー単位・organization_id 無し）

| 事実 | 根拠 |
|---|---|
| 入口: `save_plan` はセッションの `user_id` のみを `PublicPlanSaveInput` に詰める。組織は解決しない | `crates/agrr-server/src/public_plan_save.rs:69-105` |
| `PublicPlanSaveInteractor` は `PublicPlanSaveWorkspace { user_id, session_data }` を作る。組織 ID を持たない | `crates/agrr-domain/src/cultivation_plan/interactors/public_plan_save_interactor.rs:79-82`, `crates/agrr-domain/src/cultivation_plan/dtos/public_plan_save_workspace.rs:6-9` |
| Farm: 既存ユーザー Farm（`user_id` + `source_farm_id`）があれば再利用（件数チェックの前に return） | `plan_save_ensure_user_farm_interactor.rs:67-80` |
| Farm: 再利用でなければ `count_non_reference_farms(input.user_id)`（ユーザー単位）で判定 | `plan_save_ensure_user_farm_interactor.rs:82-94` |
| Farm SQL: `SELECT COUNT(*) FROM farms WHERE user_id = ?1 AND is_reference = 0` | `crates/agrr-adapters-sqlite/src/cultivation_plan/plan_save_gateways.rs:102-110` |
| Farm INSERT に `organization_id` が無い（`user_id, name, latitude, longitude, region, is_reference, weather_location_id, source_farm_id`） | `plan_save_gateways.rs:112-137`（特に `:123-124`） |
| Crop: 参照行ごとに既存（`user_id` + `source_crop_id`）を再利用し、無ければ `enforce_crop_create_limit(user_id)` | `crates/agrr-domain/src/cultivation_plan/interactors/plan_save_ensure_user_crops_interactor.rs:74-90` |
| Crop: 上限判定は `count_user_owned_non_reference_crops(user_id)` | `plan_save_ensure_user_crops_interactor.rs:116-136` |
| Crop SQL: `SELECT COUNT(*) FROM crops WHERE user_id = ?1 AND is_reference = 0` | `plan_save_gateways.rs:276-289` |
| Crop の作成属性に `organization_id` が無い（`name, variety, area_per_unit, revenue_per_area, groups, is_reference, region, source_crop_id`）。`user_id` は Gateway 側で付与 | `plan_save_ensure_user_crops_interactor.rs:139-178`, `plan_save_gateways.rs:257-273` |
| `insert_from_attr_map` は渡した属性キーだけを列にして INSERT する（=属性に入れなければ NULL） | `crates/agrr-adapters-sqlite/src/cultivation_plan/plan_save_support.rs:67-95` |
| `plan_save_*.rs` の非テストコードに `organization_id` は 1 件も無い（`rg organization_id plan_save_*.rs` から fixture / test を除くとヒット無し）。Farm / Crop 以外（fields, cultivation_plans, pests 等）も同様に NULL で作られる | `crates/agrr-adapters-sqlite/src/cultivation_plan/plan_save_*.rs`（rg 実行結果） |
| plan-save が使う狭い Gateway トレイト | `crates/agrr-domain/src/cultivation_plan/gateways/plan_save_farm_gateway.rs:18-21`, `plan_save_crop_limit_gateway.rs:1-7`（コメントに「subset of `CropGateway`」） |
| 組み立て: `plan_save_session.rs` が `PlanSaveFarmGw` / `CropLimitGw` / `PlanSaveUserCropGw` を生成して各 Interactor に注入 | `crates/agrr-adapters-sqlite/src/cultivation_plan/plan_save_session.rs:123-131`, `:164-175` |

### 2.4 organization_id の backfill と NULL 行の扱い

| 事実 | 根拠 |
|---|---|
| スキーマ上 `farms.organization_id` / `crops.organization_id` は NULL 許可（`ALTER TABLE ... ADD COLUMN "organization_id" integer`、NOT NULL 無し） | `crates/agrr-migrate/migrations/schema/V16__organizations.sql:36,40` |
| backfill の実体は `ensure_personal_organization` 内の `backfill_tier1_organization_ids`（`WHERE user_id = ?2 AND organization_id IS NULL` で personal org を設定。fields は farm 経由） | `crates/agrr-adapters-sqlite/src/organization/personal_organization_sqlite_gateway.rs:42-84`（`:81` で呼び出し）, `:114-136`, 対象表 `:29-39` |
| `ensure_personal_organization` の呼び出し元（非テスト）: (a) OAuth コールバック（エラーは `warn` のみで握りつぶし） `crates/agrr-adapters-sqlite/src/auth/omniauth_session.rs:68-73`、(b) 認証テストログイン `crates/agrr-adapters-sqlite/src/auth/auth_test_login.rs:55-59`、(c) バックドアのユーザー作成 `crates/agrr-adapters-sqlite/src/backdoor/backdoor_diagnostics_gateway.rs:172`、(d) `FarmCreateInteractor` / `CropCreateInteractor` / crop AI preflight（ただし所属組織が 0 件のときだけ） `farm_create_interactor.rs:72-77`, `crop_create_interactor.rs:61-66`, `crop_ai_upsert_sqlite_persistence.rs:167-173`、(e) 起動時 backfill | 各 file:line |
| 起動時 backfill は `lib.rs` で spawn され、対象は `list_users_needing_personal_organization`（**personal org を持たないユーザーのみ**）。既に personal org を持つユーザーの NULL 行は起動時 backfill では直らない | `crates/agrr-server/src/lib.rs:124-127`, `crates/agrr-server/src/personal_organization.rs:9-22`, `crates/agrr-domain/src/organization/interactors/personal_organization_backfill_interactor.rs:16-24`, `personal_organization_sqlite_gateway.rs:86-111` |
| よって「personal org 既存ユーザーが plan-save で作った NULL 行」は、次回の OAuth ログイン（(a)）まで NULL のまま残る。Masters の作成（(d)）は所属組織があるため `ensure` を呼ばず、backfill を起動しない | 上記の組み合わせ（`org_ids.first()` が Some の分岐）。**実運用でこの状態が発生していること自体は未確認**（本番データ未照会） |
| Farm 一覧（Masters）は `organization_id IN (...)` のみで、NULL 行は出ない | `farm_gateway.rs:311-330`（`:320` の `is_reference = 0 AND ({org_sql})`）、`crates/agrr-domain/src/farm/interactors/farm_list_interactor.rs:46-63` |
| Crop 一覧・pest 等の一覧は `(organization_id IS NULL AND user_id = ?)` を OR で含むため NULL 行も所有者には出る | `crates/agrr-adapters-sqlite/src/shared/reference_index.rs:41,59`、Crop は `crop_gateway.rs:85-89` が `where_clause` を使用 |
| 補足: Farm 一覧だけ NULL 行を返さず Crop 一覧は返す、という非対称がある（依頼文の「一覧に出ず」は Farm には成立、Crop 一覧には成立しない） | 上記 2 行の比較 |

### 2.5 フロントエンドの事前チェック

| 事実 | 根拠 |
|---|---|
| フロントは Farm 一覧（組織スコープ）の非参照件数で `>= 4` を判定して作成ボタンを制御。コメントは「Matches `FarmCreateLimitPolicy::MAX_NON_REFERENCE_FARMS_PER_USER`」 | `frontend/src/app/domain/farms/farm-create-limit.ts:7-16`, 使用箇所 `frontend/src/app/components/masters/farms/farm-create.component.ts:202`, `frontend/src/app/adapters/private-plan-create/private-plan-create-api.gateway.ts:40` |
| 一覧に NULL 行が出ないため、NULL の Farm はフロント側の件数にも入らない（バックエンドが最終権威） | `farm_gateway.rs:320` と上記の組み合わせ |

### 2.6 テスト現況

| 事実 | 根拠 |
|---|---|
| plan-save Farm のドメインテスト: 上限は Mock の `count` フィールド（ユーザー単位 API）で表現され、組織は登場しない | `crates/agrr-domain/test/cultivation_plan/interactors_plan_save_ensure_user_farm_interactor_test.rs:10-15,131-152` |
| Masters Farm/Crop 作成のドメインテストは存在（組織単位 API を実装したモック） | `crates/agrr-domain/test/farm/interactors_farm_create_interactor_test.rs:188,348`, `crates/agrr-domain/test/crop/interactors_crop_create_interactor_test.rs:134` |
| plan-save の SQLite 統合テストのフィクスチャ DDL の `farms` に `organization_id` 列が無い（`crops` には有る）。`organizations` / `organization_memberships` の DDL も無い | `crates/agrr-adapters-sqlite/src/cultivation_plan/plan_save_integration_fixture.rs:54-66`（farms）, `:76-90`（crops）, rg `organizations` ヒット無し |
| R4 契約に上限超過を検証するケースは無い（`farm_limit` / `crop_limit` / `LimitExceeded` の rg で該当無し）。あるのは上限に達した状態を避けるヘルパのみ | `crates/agrr-r4-contract/tests/support.rs:164-187`（`ensure_farm_create_capacity_via_api`）、`crates/agrr-r4-contract/tests/contracts.rs` の rg 結果 |
| R4 に公開プラン保存（plan-save）を叩くケースは見つからない（`plan_save|public_plans.*save|/save` の rg でヒット無し） | `crates/agrr-r4-contract/tests/contracts.rs` の rg 結果 |
| CI の `agrr-adapters-sqlite` 実行は `cargo test -p agrr-adapters-sqlite -- '_gateway_test'`（名前フィルタ）。`plan_save_session_integration_test` モジュール配下のテスト名はこのフィルタに一致しないように見える（**実行して確認はしていない: 未確認**） | `.github/workflows/rust-domain-test.yml:57-58`、`crates/agrr-adapters-sqlite/src/cultivation_plan/mod.rs:43-46` |

---

## 3. 仕様の正の確定

### 3.1 文書間の食い違い

| 文書 | 記述 | 根拠 |
|---|---|---|
| `ARCHITECTURE.md` | 「per user」 | `ARCHITECTURE.md:90-91` |
| ADR-002（Accepted） | クォータ境界の課題として「Farm / Crop 作成上限は `user_id` 単位。法人契約では組織単位の制限が自然」。責務境界表で「Farm / Crop 上限を org 単位に集約（personal org は現行と同等）」フェーズ 2 | `docs/adr/ADR-002-organization-multi-tenancy.md:17`, `:55` |
| `organization-data-model.md` | 移行後: 「personal org: 現行と同等の上限 / 法人 org: 契約プランに応じた org 単位上限（フェーズ 2 で定義）」 | `docs/design/organization-data-model.md:94-104` |
| 実装（Masters） | 組織単位（#612 で意図的に導入） | §2.2 |
| 実装（plan-save） | ユーザー単位 | §2.3 |
| ソース内の命名 | 定数は `..._PER_USER`、i18n キーは `attributes.user.*_limit_exceeded` | §2.1 |

### 3.2 確定: 案 A（組織単位に統一）

**案 A で確定**（§0 D-1〜D-3）。内容: Masters の現行実装に plan-save を合わせる。件数は「作成先組織」の非参照行数。personal org は 1 ユーザー 1 組織（§3.3-3）なので個人ユーザーにとってはユーザー単位と等価。

不採用とした案（短く残す）:

| 案 | 内容 | 不採用理由（いずれも §2 の確認済み事実に基づく） |
|---|---|---|
| B: ユーザー単位に統一 | Masters の件数を `count_user_owned_non_reference_*`（`farm_gateway.rs:283-295`, `crop_gateway.rs:124-136`）に戻す。plan-save は現状維持 | #612 の意図的な org 移行の巻き戻しになる（§2.2）。ADR-002 のクォータ org 集約（`:55`）・`organization-data-model.md:103-104` の法人 org 方針と逆行する（§3.1）。Farm 一覧・フロントの件数は組織スコープ（`farm_list_interactor.rs:46-63`, `farm-create-limit.ts:7-16`。§2.4, §2.5）のため、判定をユーザー単位に戻すと画面の件数と食い違う |
| C: 両方を上限とする（user かつ org） | どちらか厳しい方で拒否 | 二重スコープで仕様が複雑化する。i18n メッセージの区別が必要になる。現状どの文書にも無い（§3.1） |

### 3.3 案 A の根拠（すべて確認済み）

1. ADR-002 は Accepted で、クォータの org 集約を明示している（`ADR-002:55`）。`organization-data-model.md:94-104` も同方向。
2. Masters は #612（`e020f1c66`）で「Org-unit create limits」として意図的に切り替え済みで、plan-save だけが取り残されている（§2.2, §2.3）。案 A は「取り残し」を直す最小の是正。
3. personal org は 1:1（`personal_organization_sqlite_gateway.rs:50-59`, `:61-79`）なので、個人ユーザーにとっての挙動は変わらない（ADR-002:55「personal org は現行と同等」）。
4. Masters を変えないため、既存挙動の破壊が無い。変更は plan-save の Gateway / DTO / 配線（§5.2）に閉じる。

### 3.4 実装前に調査で埋める項目（ユーザー質問にしない）

- 本番で NULL `organization_id` の非参照 Farm / Crop が実在するか、上限超過ユーザー / 組織が実在するか（§4.3 のクエリで `production-primary-sqlite-query` スキルにより確認する。**未実施・未確認**）。
- 複数組織に所属するユーザー / 非 personal org が本番に実在するか（同上）。存在しなければ U1（共有枠）・U2（作成先組織）は現時点で実害が無い。
- plan-save 経路で Farm 作成時に気象取得が起動されるか（`plan_save_*.rs` を読んで確認する。**未確認**）。

### 3.5 ユーザー確認事項

解消済み:

- 案の選択（旧 §3.5-1: A / B / C のどれを正とするか）→ **案 A で確定**（§0）。

未決（決定事項ではない。推奨案を添えるが、ユーザー回答があるまで確定として扱わない）:

| # | 未決事項 | 推奨案 | 推奨の根拠 | 回答が推奨と異なる場合の影響 |
|---|---|---|---|---|
| U1 | 複数メンバー組織で Farm 4 / Crop 20 を **組織全体で共有**するか。ADR-002 は法人 org の上限を「契約プランに応じて フェーズ 2 で定義」としており数値は未確定（`organization-data-model.md:103-104`） | 当面は現行 Masters と同じ数値（4 / 20）・同じ組織共有枠を維持する。法人 org のプラン別上限は本課題に含めない | 組織単位 COUNT は同一組織の全メンバーの行を数える（`farm_gateway.rs:297-309`, `crop_gateway.rs:138-150`）。Masters を変えずに plan-save を揃えられる | メンバー別枠や数値変更を選ぶ場合は Masters の判定も変わり、§5 の設計・§6 A1 の共有枠テストが変わる |
| U2 | 複数組織所属ユーザーの **作成先組織の規則**。現行 Masters は所属の先頭（`organization_memberships` の `ORDER BY id` の `first()`: `organization_membership_sqlite_gateway.rs:85-99`, `org_scope.rs:6-11`）。先頭が personal org でない場合の意図は文書化されていない（`docs` を rg しても明記なし。**未確認**）。backfill 先は personal org（`personal_organization_sqlite_gateway.rs:50-59,114-136`）で食い違い得る（§8.2） | 現行どおり「所属の先頭」を Masters / crop AI / plan-save の全経路で共通にする（§5.2 手順 9 の共通ヘルパ） | 経路ごとに規則が分かれると、経路 Y（§4.1）と同種のすり抜けが再発する。Masters の挙動を変えない | personal org 優先などに変える場合は Masters の既存挙動も変わり、新規の仕様変更になる（ADR-002 の判断: `09-stale-design-docs.md:209-211`） |
| U3 | `ARCHITECTURE.md:90-91` の「per user」文言を、どの課題で更新するか | 課題 09 の Q1・Q2（`09-stale-design-docs.md:246-247`）で実施する。09 は 01 のマージ後に実施する前提（`09-stale-design-docs.md:242,254,396`）。01 では書き換えない | 09 が文書側の是正を一括で持つ。01 の未決 U1・U2 が確定してから書けば手戻りが無い（Q1 は複数所属時の所属先規則の明記を求める: `:246`） | 01 で更新する場合は §7 ステップ 9 で実施し、09 の Q1〜Q7 との重複を調整する |

---

## 4. 影響範囲

### 4.1 すり抜け経路（確認済みの論理）

前提: 利用者は personal org を持ち、Masters の作成先組織 = その personal org。

- **経路 X（主因）**: plan-save で Farm を作る → `organization_id = NULL`（§2.3）→ Masters の `count_non_reference_farms_for_organization` は NULL 行を数えない（§2.2）→ Masters でさらに 4 件まで作成可能。plan-save 側の判定は `user_id` 単位で Masters 作成分も含めて数えるため（`plan_save_gateways.rs:102-110`）、逆方向（Masters 先 → plan-save）は正しく拒否される。合計の理論上限は Farm で 4（plan-save 由来 NULL）+ 4（Masters）= 8、Crop で 20 + 20 = 40。
- NULL 行は次回 OAuth ログインの `ensure_personal_organization` で personal org に付く（§2.4）ため、backfill 後は組織単位カウントに入り、以降の作成は拒否される。つまりすり抜けは「plan-save で作成 → 次回ログインまで」の間に限られる（**実際に発生したかは未確認**）。
- **経路 Y（複数所属）**: Masters は所属の先頭 1 組織だけを数える。他組織に `user_id` が自分の行があってもカウントされない。plan-save は `user_id` で全組織分を数える。両者の食い違いにより、同一ユーザーの上限が経路で異なる。
- **経路 Z（共有 org）**: 同一 org の他メンバーが作った行は Masters では自分の枠を消費するが、plan-save では消費しない（`user_id` 単位）。
- **フロント表示**: Farm 一覧に NULL 行が出ない（§2.4）ため、フロントの事前チェック（§2.5）は NULL 行を数えず、UI 上は「まだ作れる」と見える。

案 A 確定後の各経路の帰結:

| 経路 | 案 A（D-1〜D-3）での扱い |
|---|---|
| X（NULL 行のすり抜け） | 書き込みで `organization_id` を必ず設定（D-3）し、既存 NULL 行は backfill で消す（§8）ことで解消 |
| Y（複数所属の食い違い） | plan-save も Masters と同じ作成先組織 1 つだけを数えるため、経路間の差は解消。他組織にある自分の行を数えない点は設計上の帰結で、規則自体は U2 で確認 |
| Z（共有 org） | plan-save も同一組織の他メンバーの行で枠を消費する共有枠に揃う。共有枠を維持するかは U1 で確認 |

### 4.2 影響する表・コード

| 種別 | 対象 |
|---|---|
| 表 | `farms`, `crops`（`organization_id` NULL 行）。副次的に plan-save が NULL で作る `fields`, `cultivation_plans`, `pests`, `fertilizes` 等（§2.3 の rg 結果。**上限には無関係だが同根の NULL 問題**） |
| ドメイン | `plan_save_ensure_user_farm_interactor.rs`, `plan_save_ensure_user_crops_interactor.rs`, `public_plan_save_interactor.rs`, DTO `PlanSaveEnsureUserFarmInput` / `PlanSaveEnsureUserCropsInput` / `PublicPlanSaveWorkspace`, トレイト `PlanSaveFarmGateway` / `PlanSaveCropLimitGateway` |
| アダプタ | `plan_save_gateways.rs`（`PlanSaveFarmGw`, `PlanSaveUserCropGw`, `CropLimitGw`）, `plan_save_session.rs` |
| エッジ | `crates/agrr-server/src/public_plan_save.rs`（配線） |
| backfill | `personal_organization_sqlite_gateway.rs`, `personal_organization_backfill_interactor.rs`, `PersonalOrganizationGateway` トレイト |
| フロント | 変更不要の見込み（件数は API の一覧を数える。NULL 行が backfill されれば一覧に出る）。コメント `farm-create-limit.ts:6`（`..._PER_USER`）の文言のみ命名整合の検討対象 |
| 廃止対象（ユーザー単位カウント） | plan-save 専用: `PlanSaveFarmGateway::count_non_reference_farms`（`plan_save_farm_gateway.rs:18`）/ `PlanSaveCropLimitGateway::count_user_owned_non_reference_crops`（`plan_save_crop_limit_gateway.rs:4`）と実装 `plan_save_gateways.rs:102-110,276-289`（組織単位へ置換）。Masters 側の未使用メソッド `FarmGateway::count_user_owned_non_reference_farms` / `CropGateway::count_user_owned_non_reference_crops`（§0）とその実装（`farm_gateway.rs:283-295`, `crop_gateway.rs:124-136`）・スタブ（`farm_gateway_stub.rs:54`, `crop_gateway_stub.rs:43`）・テストモック（`rg -l 'fn count_user_owned_non_reference' crates/agrr-domain/test` で crop 37 / farm 10 / cultivation_plan 2 ファイル。plan-save 専用トレイトのみを実装するファイルの内訳は未確認） |
| 文書（依存: 本書のコード変更後に別課題で実施） | `ARCHITECTURE.md:88-94`（Resource Limits の `per user`: `:90-91`）、`docs/design/organization-data-model.md:94-104`、ADR-002 `:17,55`。更新は課題 09 の Q1〜Q7（`09-stale-design-docs.md:246-252`）。詳細は §11 |

### 4.3 既存データ（NULL organization_id 行）への影響

- 既存の NULL 行は「組織単位カウントに入らない」ため、修正後も backfill されるまでは Masters 判定が過少になる。したがって **コード修正と NULL 行の修復は同一リリースで揃える**（§8）。
- 修復の要否は本番の実データ次第。**本番 DB は未照会（未確認）**。次の読み取り専用クエリを `production-primary-sqlite-query` スキルで実行して確定する（[`SKILL.md`](../../.cursor/skills/production-primary-sqlite-query/SKILL.md)。書き込みはしない）。

```sql
-- 1) NULL 行の実数
SELECT 'farms' AS t, COUNT(*) FROM farms  WHERE is_reference = 0 AND organization_id IS NULL
UNION ALL
SELECT 'crops',      COUNT(*) FROM crops  WHERE is_reference = 0 AND organization_id IS NULL;

-- 2) NULL 行を持つユーザー（personal org 既存か / 所属ゼロか）
SELECT u.id,
       (SELECT COUNT(*) FROM organization_memberships m WHERE m.user_id = u.id) AS memberships,
       (SELECT COUNT(*) FROM organization_memberships m JOIN organizations o ON o.id = m.organization_id
         WHERE m.user_id = u.id AND o.is_personal = 1) AS personal_orgs,
       (SELECT COUNT(*) FROM farms f WHERE f.user_id = u.id AND f.is_reference = 0 AND f.organization_id IS NULL) AS null_farms,
       (SELECT COUNT(*) FROM crops c WHERE c.user_id = u.id AND c.is_reference = 0 AND c.organization_id IS NULL) AS null_crops
FROM users u
WHERE null_farms > 0 OR null_crops > 0;

-- 3) 上限超過の実在（ユーザー単位 / 組織単位）
SELECT user_id, COUNT(*) FROM farms WHERE is_reference = 0 GROUP BY user_id HAVING COUNT(*) > 4;
SELECT user_id, COUNT(*) FROM crops WHERE is_reference = 0 GROUP BY user_id HAVING COUNT(*) > 20;
SELECT organization_id, COUNT(*) FROM farms WHERE is_reference = 0 AND organization_id IS NOT NULL GROUP BY organization_id HAVING COUNT(*) > 4;
SELECT organization_id, COUNT(*) FROM crops WHERE is_reference = 0 AND organization_id IS NOT NULL GROUP BY organization_id HAVING COUNT(*) > 20;

-- 4) 複数所属 / 非 personal org の実在
SELECT user_id, COUNT(*) FROM organization_memberships GROUP BY user_id HAVING COUNT(*) > 1;
SELECT COUNT(*) FROM organizations WHERE is_personal = 0;
```

（クエリ 2 の `WHERE null_farms > 0 ...` は SQLite が SELECT の別名を WHERE で許すことを前提にしている。実行時に通らなければサブクエリ化する。未実行のため構文は未確認。）

- 既に上限を超過している行が見つかった場合の扱い（削除しない、新規作成のみ拒否、が既定の想定）はユーザー確認事項（§9）。
- `farms` / `crops` の削除が物理削除か論理削除か、件数クエリ（`farm_gateway.rs:302-305`, `crop_gateway.rs:143-146`）が論理削除行を除外しているかは未確認（`deletion_undo` コンテキストの実装を未読）。

---

## 5. 対応方針（設計）

案 A（組織単位に統一）は確定済み（§0）。設計は U1・U2 の推奨案（現行 Masters の共有枠・所属の先頭を維持）を前提に書く。U1・U2 に推奨と異なる回答があった場合は §3.5 の「影響」欄に従い、本章を見直してから着手する。U3（文書の更新先）は文書のみで、着手を止めない。

### 5.1 設計原則（LAYER-RULES との照合）

| ルール | 本件での適用 |
|---|---|
| R0: Policy は判定、Interactor は編成、Gateway は認可しない | 上限判定（`limit_exceeded`）は既存 Policy のまま。「どの組織で数えるか」は Interactor が決め、Gateway は「組織 ID → 件数」を返すだけ。Gateway に上限判断を持たせない |
| R1/R2: ドメインはフレームワーク非依存、コンストラクタ注入のみ | 組織解決に必要な `UserOrganizationScopeGateway` / `PersonalOrganizationGateway` はコンストラクタ注入（既存 `FarmCreateInteractor` と同じ形。`farm_create_interactor.rs:19-64`）。サービスロケータ・グローバルは使わない |
| R3: Gateway は狭い永続化 | `count_non_reference_*_for_organization` は既存の狭いクエリと同形。プレゼンタ形状の戻り値を作らない |
| R4: 1 ユースケース = 1 トップレベル Interactor | 組織解決は `PublicPlanSaveInteractor`（トップレベル）で 1 回行い、サブ Interactor（Farm / Crop）には値（`organization_id`）を DTO で渡す。サブ Interactor が別経路で再解決しない |
| R5: 結果は出力ポートで返す | 既存の plan-save は `RecordInvalidError` を `Err` で返す形（`plan_save_ensure_user_farm_interactor.rs:84-93`）。本件はこの既存の振る舞いを変えない（別課題。`10-authorization-consistency` / `05-fail-closed-critical` の範囲） |
| R7: 薄いエッジ | `public_plan_save.rs` はゲートウェイを組み立てて注入するだけ。組織解決ロジックをハンドラに置かない |
| R8: 依存方向を直す（スメルの移設でない） | plan-save の Gateway トレイトに「組織単位で数える」責務を入れ、アダプタ側で `user_id` を使った独自カウントを持たない |
| R9/R10: 契約先行・実装順序 | ポート契約（DTO / トレイト）→ Interactor → Gateway → 配線の順（§7） |
| Fail-closed（`ARCHITECTURE.md:65-73`, `fallback.mdc`） | 組織解決に失敗したら plan-save を失敗させる（`?` で伝播）。「組織が解決できなければ user 単位で数える」等の代替アルゴリズムは入れない |

### 5.2 変更設計（層・ファイル別）

**ドメイン (`crates/agrr-domain/src/`)**

1. `cultivation_plan/dtos/public_plan_save_workspace.rs`: `PublicPlanSaveWorkspace` に `organization_id: i64` を追加。
2. `cultivation_plan/interactors/public_plan_save_interactor.rs`: コンストラクタに `UserOrganizationScopeGateway` と `PersonalOrganizationGateway` を追加し、`FarmCreateInteractor` と同じ規則（所属の先頭、無ければ `ensure_personal_organization`）で `organization_id` を解決して `PublicPlanSaveWorkspace` に入れる（現状の生成箇所: `:79-82`）。解決失敗は `?` で伝播（フォールバック禁止）。
3. `cultivation_plan/dtos/plan_save_farm.rs`: `PlanSaveEnsureUserFarmInput` に `organization_id` を追加。`cultivation_plan/interactors/plan_save_persist_orchestrator.rs`（`ensure_user_farm`）が `PlanSaveSessionRef` 経由で受け取った値を詰める（現状 `user_id` のみ: `:37-40`。組織 ID の受け渡し経路は要設計。**Orchestrator 呼び出し側 `plan_save_session.rs:123-131` の引数変更を伴う**）。
4. `cultivation_plan/gateways/plan_save_farm_gateway.rs`: `count_non_reference_farms(user_id)` を `count_non_reference_farms_for_organization(organization_id)` に置換。`create_user_farm_from_reference` に `organization_id` を追加。`find_user_farm_by_source`（再利用判定）は `user_id` のまま（再利用は所有者単位の同一性であり上限ではない）。
5. `cultivation_plan/interactors/plan_save_ensure_user_farm_interactor.rs`: `:82` の件数取得を組織単位に変更。`:96-101` の作成呼び出しに `organization_id` を渡す。再利用分岐（`:67-80`）は件数チェックの前に return する現行順序を維持。
6. `cultivation_plan/dtos/plan_save_crops.rs`: `PlanSaveEnsureUserCropsInput` に `organization_id` を追加。
7. `cultivation_plan/gateways/plan_save_crop_limit_gateway.rs`: `count_user_owned_non_reference_crops(user_id)` を `count_non_reference_crops_for_organization(organization_id)` に置換（`CropGateway` と同名にして「subset of CropGateway」（`:1`）の実態を揃える）。
8. `cultivation_plan/interactors/plan_save_ensure_user_crops_interactor.rs`: `enforce_crop_create_limit` の件数取得を組織単位に。`crop_attributes_from_row`（`:139-178`）に `("organization_id", AttrValue::Int(organization_id))` を追加（`CropCreateInteractor` の `attrs.insert("organization_id", ...)`、`crop_create_interactor.rs:139` と同じ形）。
9. （U2 の推奨案を採る場合。別コミット）組織解決の重複を共通化: 現在 3 か所（`farm_create_interactor.rs:70-77`, `crop_create_interactor.rs:59-66`, `crop_ai_upsert_sqlite_persistence.rs:166-173`）に同一ロジックが複製されており、`PublicPlanSaveInteractor` で 4 か所目になる。`shared/org_scope.rs`（既に `member_organization_ids` がある: `:6-11`）に解決ヘルパを 1 つ置き、4 か所から使う。**振る舞い不変リファクタ**なので既存テストが GREEN のまま通ることで確認する（TDD 例外規定）。
10. `organization/gateways/personal_organization_gateway.rs`: `list_users_needing_personal_organization` とは別に、`Tier1 の organization_id が NULL の行を持つユーザー` を返すメソッド（例: `list_users_with_unassigned_organization_rows`）を追加（§8）。`organization/interactors/personal_organization_backfill_interactor.rs`: 両方の一覧を処理する（`ensure_personal_organization` は冪等: `personal_organization_gateway.rs:14`）。

**アダプタ (`crates/agrr-adapters-sqlite/src/`)**

11. `cultivation_plan/plan_save_gateways.rs`
    - `PlanSaveFarmGw::count_...`: `SELECT COUNT(*) FROM farms WHERE organization_id = ?1 AND is_reference = 0`（`farm_gateway.rs:297-309` と同一 SQL。重複を避けるため、可能なら `FarmSqliteGateway` へ委譲する形を検討）。
    - `create_user_farm_from_reference`: INSERT に `organization_id` を追加（現状 `:123-124`）。
    - `CropLimitGw`: 組織単位 COUNT に変更（現状 `:276-289`）。`PlanSaveUserCropGw::create` は属性経由で `organization_id` が入る（`insert_from_attr_map` の性質: `plan_save_support.rs:67-95`）ため SQL 変更不要。
12. `organization/personal_organization_sqlite_gateway.rs`: 手順 10 の新メソッドを実装（`farms` / `crops` などの Tier1 表に `organization_id IS NULL AND user_id IS NOT NULL` の行があるユーザーを列挙。対象表は既存の `TIER1_TABLES` `:29-39` を再利用）。

**エッジ (`crates/agrr-server/src/`)**

13. `public_plan_save.rs:98-106`: `PublicPlanSaveInteractor::new` に `UserOrganizationScopeSqliteGateway` と `PersonalOrganizationSqliteGateway` を注入（薄い配線のみ）。
14. `lib.rs:124-127` / `personal_organization.rs`: 起動時 backfill は新しい列挙メソッドを含む形で自動的に効く（呼び出し側の変更は不要の見込み）。

**フロント**

15. 変更なしの見込み。NULL 行が backfill されれば Farm 一覧に出て件数に入る。`farm-create-limit.ts:6` の `PER_USER` 命名は必須の変更ではない（範囲外なら触らない）。

**ユーザー単位カウントの除去（D-2）**

16. 手順 4・7・11 の置換で plan-save 専用のユーザー単位 API は消える。加えて Masters 側の未使用メソッド `FarmGateway::count_user_owned_non_reference_farms`（`farm_gateway.rs:39-43`）/ `CropGateway::count_user_owned_non_reference_crops`（`crop_gateway.rs:17`）を、実装（`farm_gateway.rs:283-295`, `crop_gateway.rs:124-136`）・スタブ・テストモックごと除去する（呼び出し元が無いことは §0 で確認済み）。振る舞い不変のリファクタで、既存テストが GREEN のまま通ることで確認する（TDD 例外規定）。ユーザー単位の件数取得を残すと、再びユーザー単位で数える経路が書かれ得るため残置しない（[`no-convenience-tech-debt.mdc`](../../.cursor/rules/no-convenience-tech-debt.mdc)）。モック更新の対象ファイル数は §4.2 のとおり多いため、他の手順とは別コミットにする。

### 5.3 却下する設計

- 「Masters の件数に `organization_id IS NULL AND user_id = ?` を OR で足す」恒久措置: 読み取り経路（`reference_index.rs:41,59`）には同型があるが、書き込み経路の NULL を残したままカウント側で吸収する形は「NULL を作り続ける原因を残す」ため採らない。書き込みで必ず `organization_id` を入れ、既存 NULL は backfill で消す（§8）。
- plan-save アダプタ内での組織解決: 認可・スコープの判断をアダプタに置くことになり R0/R7 に反する。
- `NOT NULL` 制約の追加を本課題に含めること: 参照行 `is_reference = 1` は `user_id` / `organization_id` が NULL である設計（ADR-002 Decision §2 の 4「参照マスタ … は**グローバル**のまま」）で、テーブル制約での一律 NOT NULL は不可。条件付き CHECK は SQLite の ALTER では追加できず、テーブル再作成を伴う。別課題として扱う（§9）。

---

## 6. TDD 計画

規約: 実装より先に失敗テスト（RED）を書き、`test-common` で意図した理由の失敗を確認してから GREEN へ（[`tdd-on-edit`](../../.cursor/skills/tdd-on-edit/SKILL.md)）。実行は [`test-common`](../../.cursor/skills/test-common/SKILL.md) のスクリプトのみ（`cargo test` / `npm test` の直接実行は禁止）。出力は `./tmp/{UUID}.log` にリダイレクトして grep（`AGENTS.md`）。

### 6.1 実行スクリプト

| 対象 | スクリプト |
|---|---|
| `agrr-domain` | `.cursor/skills/test-common/scripts/run-test-rust-domain.sh [ARGS]`（内部は `cargo test -p agrr-domain "$@"` の後に `cargo test -p agrr-migrate --quiet`。`run-test-rust-domain.sh:1-40` 付近） |
| R4 契約 | `scripts/run-rust-contract-tests.sh` |
| フロント | `.cursor/skills/test-common/scripts/run-test-frontend.sh`（本課題では変更が無ければ回帰確認のみ） |
| `agrr-adapters-sqlite` | **専用スクリプトが `test-common` に無い**（`.cursor/skills/test-common/scripts/` は 4 本のみ。CI は `cargo test -p agrr-adapters-sqlite -- '_gateway_test'` を直接実行: `.github/workflows/rust-domain-test.yml:57-58`）。`run-test-rust-domain.sh` は引数を `cargo test -p agrr-domain` の後ろに付けるだけなので、`-p agrr-adapters-sqlite -- <フィルタ>` を渡せる可能性があるが**未実行・未確認**。RED 着手時に最初に確認し、通らなければ「規約上の障害」としてユーザーへ報告する（直接 `cargo test` で代替しない） |

CI フィルタ `_gateway_test` に拾わせるため、アダプタの新規テスト関数は `..._gateway_test` を含むモジュール/ファイル名（例: `plan_save_gateways_organization_gateway_test.rs`）に置くのが安全。ただし既存 `plan_save_session_integration_test` に追加する場合、CI で実行されない可能性があるため、CI フィルタの見直しを実装ステップに含める（§7 ステップ 3）。

### 6.2 RED テスト一覧

凡例: ファイルは既存ファイルへの追記を基本とする（`agrr-domain/test/**` は各 `src/**` から `include!` される: 例 `plan_save_ensure_user_farm_interactor.rs:131-135`）。Rust では DTO へのフィールド追加が先にテストで参照されると**コンパイルエラーが RED** になる。その場合、「意図した理由 = 該当フィールド/メソッドが存在しない」ことをログで確認し、最小のスタブ（型・シグネチャのみ）を追加してから、**値が誤っていることによる失敗**に RED を進める。

**D1: plan-save Farm を組織単位で判定する**
- ファイル: `crates/agrr-domain/test/cultivation_plan/interactors_plan_save_ensure_user_farm_interactor_test.rs`
- `counts_non_reference_farms_by_organization_not_by_user`
  - given: 参照 Farm あり、既存ユーザー Farm なし。モック Gateway の `count_non_reference_farms_for_organization(7)` は 4 を返し、ユーザー単位の件数 API は 0 を返す（RED 時点で存在する間のみ。D-2 の置換後は API ごと無くなる）。入力 `user_id: 1, organization_id: 7`
  - when: `PlanSaveEnsureUserFarmInteractor::call`
  - then: `RecordInvalidError`（上限超過）。モックは引数 `7` で呼ばれたことを記録し、それを検証
  - 現状の失敗理由: 入力に `organization_id` が無い / 組織単位 API が無い
- `passes_organization_id_when_creating_user_farm_from_reference`
  - given: 件数 0、`organization_id: 7`
  - when: 作成
  - then: モックの `create_user_farm_from_reference` が `organization_id == 7` で呼ばれた
- `does_not_check_limit_when_existing_user_farm_is_reused`
  - given: 既存ユーザー Farm あり、組織件数 4
  - then: 再利用として成功（`farm_reused == true`）、組織件数 API は呼ばれない（現行順序 `:67-94` の保護）
- 既存 `raises_record_invalid_when_farm_create_limit_exceeded`（`:131-152`）を組織単位 API 版へ更新

**D2: plan-save Crop を組織単位で判定し、organization_id を付与する**
- ファイル: `crates/agrr-domain/test/cultivation_plan/interactors_plan_save_ensure_user_crops_interactor_test.rs`
- `raises_record_invalid_when_organization_crop_count_reaches_limit`
  - given: 参照行 1 件、既存ユーザー Crop なし、`count_non_reference_crops_for_organization(7) == 20`、入力 `organization_id: 7`
  - then: `RecordInvalidError`。組織 ID 7 で呼ばれたことを検証
- `created_crop_attributes_include_organization_id`
  - given: 件数 0、`organization_id: 7`
  - then: `PlanSaveUserCropGateway::create` に渡された属性の `organization_id` が `AttrValue::Int(7)`
- `reused_crop_does_not_consume_limit`
  - given: 既存ユーザー Crop あり、組織件数 20
  - then: 成功（`skipped_crop_ids` に含まれる）

**D3: PublicPlanSaveInteractor が作成先組織を解決する**
- ファイル: `crates/agrr-domain/test/cultivation_plan/interactors_public_plan_save_interactor_test.rs`（既存。`:302`, `:344` の `new(...)` 呼び出しを新コンストラクタに更新）
- `resolves_first_member_organization_into_workspace`
  - given: スコープ Gateway が `[11, 12]` を返す
  - then: 永続化ポートに渡された `PublicPlanSaveWorkspace.organization_id == 11`、`ensure_personal_organization` は呼ばれない
- `ensures_personal_organization_when_user_has_no_membership`
  - given: スコープ Gateway が `[]`、`ensure_personal_organization` が `21` を返す
  - then: `organization_id == 21`
- `fails_without_saving_when_organization_resolution_errors`
  - given: スコープ Gateway が `Err`
  - then: 永続化ポートが呼ばれない（フォールバック禁止の担保）

**D4: 組織解決ヘルパ（§5.2 手順 9 を実施する場合）**
- ファイル: 既存の `shared` 配下のテスト配置に合わせる（`crates/agrr-domain/test/shared/` に `org_scope` 用ファイルがあるかは未確認。無ければ新規に `helpers_org_scope_test.rs` を追加し `test/shared/mod.rs` に登録）
- 上記 D3 と同じ 2 ケースをヘルパ単体で。**既存の Masters / crop AI のテストは変更せず GREEN のまま**を確認（振る舞い不変）

**D5: backfill Interactor が「personal org 既存だが NULL 行あり」のユーザーも処理する**
- ファイル: `crates/agrr-domain/test/organization/interactors_personal_organization_backfill_interactor_test.rs`
- `processes_users_with_unassigned_rows_even_when_personal_org_exists`
  - given: `list_users_needing_personal_organization` は空、新メソッドが `[user 5]` を返す
  - then: `ensure_personal_organization(5, ...)` が 1 回呼ばれ、戻り値の処理件数が 1
- `does_not_process_same_user_twice`
  - given: 両方の一覧に user 5
  - then: 呼び出しは 1 回

**A1: SQLite アダプタ（plan-save 保存の観測可能な結果）**
- 前提の RED（テスト基盤）: `plan_save_integration_fixture.rs` の DDL に `farms.organization_id`（`:54-66`）と、`organizations` / `organization_memberships` を追加（テスト基盤の変更であり、追加しただけでは既存テストは GREEN のまま）
- ファイル: `crates/agrr-adapters-sqlite/src/cultivation_plan/plan_save_session_integration_test.rs`（または CI フィルタに拾われる `*_gateway_test` 名の新規ファイル）
- `plan_save_sets_organization_id_on_created_farm_and_crops`
  - given: ユーザー U が組織 O（personal）に所属。参照 Farm / 参照 Crop あり
  - when: plan-save 実行（`invoke_save`）
  - then: 作成された `farms` 行と `crops` 行の `organization_id == O`（現状は NULL のため RED）
- `plan_save_created_farms_count_toward_masters_organization_limit`（バイパスの再現）
  - given: ユーザー U（組織 O）。異なる参照 Farm 4 件に対して plan-save を 4 回実行
  - when: `FarmSqliteGateway::count_non_reference_farms_for_organization(O)`
  - then: `4`（現状は `0` で RED = すり抜けの直接の再現）
- `plan_save_rejects_farm_when_organization_already_has_four_farms_from_other_member`（U1 の推奨案＝組織共有枠のとき。U1 が別回答なら削除または逆転する）
  - given: 組織 O に別メンバー U2 の非参照 Farm が 4 件（`organization_id = O`）。U1 も O 所属
  - then: U1 の plan-save は上限超過で失敗（現状は `user_id` 単位で 0 件のため成功 = RED）
- `plan_save_rejects_crop_when_organization_has_twenty_crops`
  - given: 組織 O に非参照 Crop 20 件
  - then: 失敗

**A2: backfill アダプタ**
- ファイル: `crates/agrr-adapters-sqlite/src/organization/personal_organization_sqlite_gateway_test.rs`（既存。モジュール名に `_gateway_test` を含み CI フィルタに拾われる: `organization/mod.rs:12`）
- `list_users_with_unassigned_rows_returns_user_with_personal_org_and_null_farm`
  - given: ユーザーが personal org を持ち、`farms` に `user_id = U, organization_id = NULL, is_reference = 0` の行
  - then: 新メソッドが U を返す。`ensure_personal_organization(U, ...)` 後は返さない
- `list_users_with_unassigned_rows_excludes_reference_rows`
  - given: `is_reference = 1` かつ `user_id IS NULL` の NULL 行のみ
  - then: 返さない（参照マスタはグローバル: ADR-002 Decision §2 の 4）

**R4（任意・実装可能性は未確認）**
- ファイル: `crates/agrr-r4-contract/tests/contracts.rs`
- `masters_farm_create_returns_422_after_limit_reached_via_personal_org`: ヘルパ `ensure_farm_create_capacity_via_api`（`support.rs:164-187`）の逆で、4 件作成後の 5 件目が上限超過エラーになること。現状カバーが無い上限自体の回帰防止。plan-save を R4 から叩けるか（保存に必要な公開プランの seed）は未確認のため、plan-save 併用のシナリオは A1 で担保し、R4 では Masters 上限の観測のみを対象とする。

**F（フロント）**: 変更が無ければ追加テスト無し。`run-test-frontend.sh` で回帰のみ確認（`farm-create-limit.spec.ts` は不変の見込み）。

### 6.3 RED → GREEN の確認手順

1. D1 → 実行 `run-test-rust-domain.sh`（フィルタ例: `-- plan_save_ensure_user_farm`）→ 想定理由（フィールド/メソッド不在 → 値の不一致）で失敗することをログで確認。
2. 最小実装で GREEN → 同フィルタで GREEN を確認。
3. D2, D3, D5 を同様に。
4. A1/A2 は §6.1 の実行経路確認後に同様に。
5. 個別 GREEN 後、引数なしの `run-test-rust-domain.sh` → `scripts/run-rust-contract-tests.sh` → `run-test-frontend.sh` の順で全体、最後に [`test-slow-detection`](../../.cursor/skills/test-slow-detection/SKILL.md)。長時間コマンドは [`process-monitor`](../../.cursor/skills/process-monitor/SKILL.md) で終了コード取得後に結果を断定する。

---

## 7. 実装ステップ

前提: 案 A は確定済み（§0）。U1・U2（§3.5）は推奨案どおりなら実装差分は本表のとおり（推奨と異なる回答の場合は §5 を見直してから着手）。各ステップは「テスト（RED 確認）＋最小実装（GREEN）」を 1 コミットとし、コミットごとに `agrr-domain` が GREEN を維持する（CI を赤にしない）。git 操作（checkout / switch / reset / restore は許可なしに禁止: `git-operational-constraints.mdc`）は本書の範囲外。

| # | 内容 | 主な変更 | コミット粒度の目安 |
|---|---|---|---|
| 0 | 本番データ照会（§4.3 のクエリ）と結果の記録 | ドキュメント（本書の追記） | 本書更新 1 |
| 1 | ポート契約: `PublicPlanSaveWorkspace` / `PlanSaveEnsureUser{Farm,Crops}Input` に `organization_id`、Gateway トレイトを組織単位へ（R10: 契約が先） | D1・D2 の RED を含む。モック更新 | 1 |
| 2 | `PublicPlanSaveInteractor` に組織解決（D3）と `public_plan_save.rs` の配線 | domain + server 配線 | 1 |
| 3 | テスト基盤の整備（A1 の前提）: fixture DDL 更新、CI フィルタの見直し（A1 が CI で実行されること）。`.github/workflows/rust-domain-test.yml` を変更する場合はその範囲を明示 | fixture / workflow | 1（必要な場合） |
| 4 | plan-save Farm: Interactor（D1）+ `PlanSaveFarmGw` の COUNT / INSERT（A1 の Farm 部分） | domain + adapters-sqlite | 1 |
| 5 | plan-save Crop: Interactor（D2）+ `CropLimitGw` + 属性へ `organization_id`（A1 の Crop 部分） | domain + adapters-sqlite | 1 |
| 6 | backfill 拡張: トレイト追加・Interactor（D5）・SQLite 実装（A2） | domain + adapters-sqlite | 1 |
| 7 | 組織解決ヘルパの共通化（D4。U2 の推奨案を採る場合に実施）。振る舞い不変。既存テスト GREEN で確認 | `org_scope.rs` + 4 呼び出し元 | 1 |
| 8 | 未使用ユーザー単位カウントの除去（§5.2 手順 16、D-2）。振る舞い不変。既存テスト GREEN で確認 | domain（trait / stub / モック）+ adapters-sqlite | 1 |
| 9 | 文書整合（依存: 課題 09）: `ARCHITECTURE.md:90-91` / `organization-data-model.md:94-104` / ADR-002 `:17,55` は 09 の Q1〜Q7 で更新する（U3 の推奨案）。本課題では内容（案 A・U1・U2 の最終回答）を 09 に引き渡すのみ。U3 が別回答なら本ステップで更新し、09 と範囲を分担 | docs（09 側） | 09 で 1 |
| 10 | Docker 検証: `crates/agrr-server/**` / `crates/agrr-domain/**` / `crates/agrr-adapters-*/**` を変更するため、検証前に `.cursor/skills/dev-docker/scripts/rebuild-restart.sh`（`docker compose restart agrr-server` だけでは不十分: `docker-dev-agrr-server-rebuild.mdc`） | 実行のみ | なし |
| 11 | 全体回帰: `run-test-rust-domain.sh` → `run-rust-contract-tests.sh` → `run-test-frontend.sh` → `test-slow-detection` | 実行のみ | なし |
| 12 | 本番反映後のデータ確認（§8）と、`ensure_personal_organization` の再実行が必要なユーザーの残存確認 | 運用 | なし |

技術的難易度: 中。層をまたぐが個々の変更は小さい（DTO 1 フィールド + トレイト 2 メソッドの差し替え + SQL 3 か所 + 配線 1 か所）。難所は (a) Rust のトレイト変更に伴う大量のモック更新（`count_*` を実装するテストモックは `agrr-domain/test/**` に多数ある: 前述の rg 結果。ただし `PlanSaveFarmGateway` / `PlanSaveCropLimitGateway` の実装モックは plan-save 系テストに限られる見込み。数は未確認）、(b) アダプタテストの実行経路（§6.1）。

---

## 8. マイグレーション / データ修復計画

### 8.1 スキーマ変更

不要（`organization_id` 列は V16 で既に存在: `V16__organizations.sql:36,40`）。新規マイグレーション（`V27__...`）は本案では作らない。

### 8.2 データ修復（既存 NULL 行）

- 方法案（推奨）: **既存の `ensure_personal_organization`（冪等・`backfill_tier1_organization_ids` を含む）を再利用**し、起動時 backfill の対象に「personal org は持つが Tier1 に NULL 行があるユーザー」を追加する（§5.2 手順 10・12）。新しい SQL の UPDATE を別途書かないため、backfill の規則（`WHERE user_id = ? AND organization_id IS NULL` → personal org、fields は farm 経由）が 1 か所に保たれる。
  - 利点: コードで再現可能・テスト可能（D5/A2）・デプロイと同時に自動実行・冪等。
  - 欠点: 起動時に非同期実行（`lib.rs:124-127` の `tokio::spawn`）のため、デプロイ直後にごく短時間、修復前の状態が残る。
- 代替（単発 SQL を本番に直接実行）: 確認手順・ロールバックの再現性が乏しく、Litestream レプリカ経由の復元確認が前提になるため採らない。やむを得ず行う場合は `production-admin` スキルの手順に従う（本書では手順を定めない。**同スキルは未読**）。
- 多重所属ユーザーの扱い: `backfill_tier1_organization_ids` は personal org へ割り当てる（`personal_organization_sqlite_gateway.rs:50-59,114-136`）。一方 Masters は「所属の先頭」に作成する（`org_scope.rs` + `ORDER BY id`）。先頭が personal org でないユーザーは、backfill 先と作成先が食い違う。実在性は §4.3 クエリ 4 で確認し、実在する場合の割り当て規則は未決 U2（§3.5）。

### 8.3 順序

1. コード修正（書き込みで `organization_id` を必ず設定）と backfill 拡張を**同一リリース**で出す。
2. 起動時 backfill 完了後、§4.3 クエリ 1・2 を再実行して NULL 行が 0（対象ユーザーが所属ゼロなど例外のみ）であることを確認。
3. 既に上限超過の組織/ユーザーがあれば一覧化して報告（自動削除しない）。

### 8.4 ロールバック

- コード: 通常のリビジョン戻し。`organization_id` が付いた行は戻しても無害（列は既存・NULL 許可、`user_id` は維持されるため旧ロジックの `user_id` 件数にも影響しない）。
- データ: backfill は NULL → 値の更新のみで不可逆な破壊はない。戻す必要が生じたら `organization_id` を NULL に戻すのではなく、旧コードのまま運用する（旧コードは `organization_id` を無視する plan-save と、org 単位の Masters）。

---

## 9. リスク・未確定事項

| # | 内容 | 状態 |
|---|---|---|
| R1 | 仕様の正（案 A/B/C） | **解消済み**: 案 A で確定（§0、§3.2） |
| R2 | 共有 org の枠を org 全体共有にするか（数値・契約プランはフェーズ 2 で未定義: `organization-data-model.md:103-104`） | 未決 U1（§3.5。推奨: 現行 Masters の共有枠・数値を維持） |
| R3 | 複数組織所属ユーザーの作成先組織（所属の先頭）と backfill 先（personal org）が食い違い得る | 本番での実在性は未確認（§4.3 クエリ 4）。規則は未決 U2（§3.5。推奨: 所属の先頭を全経路で共通化） |
| R4 | 既に上限超過のデータがある場合の扱い（新規作成のみ拒否・既存は保持、が想定） | 本番データ未照会。ユーザー確認 |
| R5 | コードのデプロイと backfill の間の短い窓で、旧 NULL 行が組織カウントに入らない | 同一リリース＋起動時 backfill で最小化。完全排除は不可（受容するか、カウントに `organization_id IS NULL AND user_id = ?` を暫定 OR する案 §5.3 は採らない） |
| R6 | 件数取得と INSERT が別接続（`with_read_box` / `with_write_box`）で、同時リクエストにより上限を超え得る（TOCTOU）。プール実装が直列化するか未読 | **未確認**（`crates/agrr-adapters-sqlite` の `SqlitePool` 実装未読）。本課題の範囲外候補。確認結果次第で別課題化 |
| R7 | アダプタテスト（`agrr-adapters-sqlite`）を `test-common` スクリプト経由で実行できるか | **未確認**（§6.1）。不可なら規約上の障害としてユーザーへ報告 |
| R8 | `plan_save_session_integration_test` が CI で実行されていない可能性 | **未確認**（§2.6）。ステップ 3 で見直し |
| R9 | `ensure_personal_organization` の失敗が OAuth で握りつぶされる（`omniauth_session.rs:68-73`）＝ backfill がサイレントに失敗し得る | 本課題の範囲外。`05-fail-closed-critical` / `06-fail-closed-suspected` で扱うか判断（両文書は未作成のため内容は未確認） |
| R10 | plan-save が NULL で作る他の表（fields, cultivation_plans, pests, fertilizes, agricultural_tasks, interaction_rules, pesticides）の `organization_id` | 上限には無関係。本課題では Farm / Crop のみ。他表は backfill 拡張（手順 10・12）で事後修復されるが、書き込み側の是正は別課題（`10-authorization-consistency`） |
| R11 | Farm 一覧が NULL 行を返さない一方 Crop 一覧は返す非対称 | 書き込み側是正＋backfill で NULL が消えれば実害は解消。読み取りの非対称自体の是正は本課題外 |
| R12 | 論理削除行が件数に含まれるか | **未確認**（§4.3 末尾） |
| R13 | 文書が示す `ADR-002` の migration 表記（`V15__organizations.sql`）と実ファイル（`V16__organizations.sql`）の不一致 | 本課題外（`09-stale-design-docs`）。`03-api-key-scope-docs.md` も同じ指摘をしている |
| R14 | 「i18n メッセージの主語（user）」と案 A のずれ（メッセージ本文は主語なしで影響小、キー名は `attributes.user.*`） | 案 A ではキー名は変更しない（フロントが依存: `resolve-activerecord-api-error-i18n-key.ts:2` ほか）。命名変更は行わない |
| R15 | `ARCHITECTURE.md:90-91` の「per user」文言（Resource Limits）が案 A と食い違う | 未決 U3（§3.5。推奨: 課題 09 の Q1・Q2 で更新）。コードのマージ後に更新する依存（§11） |

---

## 10. 受け入れ条件（観測可能な振る舞い）

§0 の決定（案 A）に基づく。U1・U2 は推奨案どおりの場合の条件（推奨と異なる回答があれば見直す）。

1. plan-save（公開プラン保存）で作成された非参照 Farm / Crop 行の `organization_id` は、保存したユーザーの作成先組織（所属の先頭、無ければ personal org）になる（A1: `plan_save_sets_organization_id_on_created_farm_and_crops`）。
2. 同一組織内の非参照 Farm が 4 件に達している状態で plan-save が新規 Farm を作ろうとすると、上限超過（`RecordInvalidError`、メッセージは `activerecord.errors.models.farm.attributes.user.farm_limit_exceeded`）で失敗する。再利用（既存の `source_farm_id` 付き Farm）の場合は失敗しない（D1）。
3. 同一組織内の非参照 Crop が 20 件に達している状態で plan-save が新規 Crop を作ろうとすると、上限超過で失敗する。再利用は失敗しない（D2）。
4. plan-save で 4 件の Farm を作成した後の `count_non_reference_farms_for_organization(O)` は 4 になる（バイパス再現テストが GREEN: A1）。すなわち plan-save → Masters の順でも合計が 4 を超えない。
5. Masters の作成（`FarmCreateInteractor` / `CropCreateInteractor` / crop AI preflight）の既存挙動は変わらず、既存テストが GREEN のまま。
6. 組織解決に失敗した plan-save は永続化を行わずに失敗する（D3: フォールバックなし）。
7. personal org を既に持つが Tier1 に `organization_id` が NULL の行を持つユーザーが、起動時 backfill で修復される（D5・A2）。参照行（`is_reference = 1`）は変更されない。
8. 本番反映後、§4.3 クエリ 1 の非参照 NULL 行が、所属を持たないユーザー由来の例外を除き 0 になる。
9. `run-test-rust-domain.sh`（引数なし）、`scripts/run-rust-contract-tests.sh`、`run-test-frontend.sh` がすべて GREEN。`test-slow-detection` で新規の遅延テストが無い。
10. plan-save にユーザー単位の上限件数取得が残らない（D-2）。`rg 'count_user_owned_non_reference|count_non_reference_farms\(' crates` のヒットが無い（`count_non_reference_farms_for_organization(` は別名でヒットしない）。
11. `crates/*` 変更後に `rebuild-restart.sh` で再ビルドした Docker 環境で、plan-save → Masters の作成順序に依らず Farm が 4 件を超えて作れない（手動確認: 個人ユーザーで公開プラン保存を 4 回行った後、Farm 作成が上限エラーになる）。
12. （依存条件。本課題のコード変更の合否には含めない）課題 09 の Q1〜Q7 が完了し、`ARCHITECTURE.md:90-91` の `per user` が組織単位の記述に、`organization-data-model.md:96-104` と ADR-002 `:55` が実装状況に沿った記述になる（§11）。

---

## 11. 関連課題との依存

`docs/spec-defects/` の作成済みファイル（本書作成時点で `03-api-key-scope-docs.md`, `04-api-key-query-auth.md` を確認）と、依頼文に挙がった番号との関係。未作成の番号は内容を確認できていないため、関係は本書側の想定として書く。

| 番号 | 課題 | 依存・関係 |
|---|---|---|
| 02 | contact-recaptcha | 依存なし（未作成・未確認） |
| 03 | api-key-scope-docs | 依存なし。`03-api-key-scope-docs.md` は本課題（01）を「依存なし」としている（同ファイル依存表） |
| 04 | api-key-query-auth | 依存なし。同様に `04-api-key-query-auth.md` が 01 を「依存なし」としている |
| 05 | fail-closed-critical | 関連: R9（`ensure_personal_organization` 失敗の握りつぶし）。本課題は組織解決失敗を fail-closed にする点で方針一致。05 側の対象範囲は未作成のため未確認 |
| 06 | fail-closed-suspected | 同上（未作成・未確認） |
| 07 | frontend-error-contract | 関連の可能性: 上限超過エラーの i18n キー解決（`resolve-activerecord-api-error-i18n-key.ts`）。本課題ではキー・契約を変えない。07 の内容は未確認 |
| 08 | openapi-gaps | 関連: `08-openapi-gaps.md:97,1046` は Masters `POST /crops` の 422（作成上限超過を含む）を記載し、01 で挙動が変わる場合に追随するとしている。案 A では Masters の挙動は不変（§10-5）のため変更は不要の見込み。plan-save 側の上限超過レスポンスの OpenAPI 記載は未調査（未確認） |
| 09 | stale-design-docs | **依存（クォータ文書の更新が必要）**: 案 A 確定により、`ARCHITECTURE.md:90-91` の `per user` は実装（組織単位）と食い違う文書になる。09 は 01 のマージ後に Q1〜Q7 を実施する前提（`09-stale-design-docs.md:242,254,337,396`）。09 側で必要な更新（内容は案 A 前提。U1・U2 の最終回答が確定してから書く）: Q1・Q2（`ARCHITECTURE.md:90-91`）は集計単位を organization に書き換え、複数所属時の作成先組織の規則（U2）を 1 行明記（`09:246`）。Q3（`organization-data-model.md:96-99`）は「ユーザーあたり」を組織単位へ更新。Q4（`:101-104`）は「masters 経路は既に org 単位」に加え plan-save 統一後の状態を反映し、契約プラン別上限は未定義と明記（`09:249`）。Q5（ADR-002 `:17`）は起票時点の記述として保持。Q6（`:55`）は「実装済み」を書き分け（`09:250-251`）。ADR-002 のクォータ行は既に org 集約を規定している（`:55`）ため、決定は ADR の向きと一致する。ただし複数所属時の org 選択規則を新設する場合は Decision の追加として新 ADR の要否を再判定する（`09:209-211`）。§7 ステップ 9 のとおり、文書更新の帰属は U3。ADR-002 の `V15` 表記は 09 の範囲（R13）。なお `frontend/e2e/smoke/README.md:121`（「ユーザー農場 4 件上限」）は 09 の Q1〜Q7 に載っていないため、更新対象に含めるかは 09 側で判断する |
| 10 | authorization-consistency | **関連**: plan-save が NULL `organization_id` で作る他表（R10）、Farm / Crop 一覧の NULL 扱いの非対称（R11）は認可・スコープ整合の課題。01 の書き込み側是正（Farm / Crop）が入った後に、他表の書き込み是正を 10 で扱うのが自然 |
| 11 | low-priority-misc | R6（TOCTOU）、R14（命名）など、優先度が低く本課題の受け入れに不要な項目の受け皿候補（未作成・未確認） |

順序上の前提: 01 のコード変更は他課題の完了を待たずに着手できる（前提は §3.5 の U1・U2 の回答のみ。推奨案どおりなら本書の設計のまま）。09 のクォータ文書更新（Q1〜Q7）は 01 のマージ後に実施する。案 A の確定自体は §0 で済んでおり、09 が待つのは U1・U2 の最終回答とコードの実装結果。
