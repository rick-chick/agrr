# 09: 設計文書が実装と乖離・リンク切れ（ADR-002 / organization-data-model / SLI-SLO ほか）

本書は**対応計画のみ**であり、コード・文書の修正は含まない。記載する事実は 2026-09-29 時点のリポジトリ（`master`）を実際に読んで確認したものだけで、`file:line` を付ける。読んでいない・実行していないものは「未確認」と明記する。

**決定事項の反映（§0）**: `README.md` の決定事項 3 回分と、課題 01（第 3 回決定を含む最新版）・02（Turnstile）・10（第 3 回決定を含む最新版）を読んで追記した（2026-10-07 時点のワークツリー）。§0 の追加主張は、`ARCHITECTURE.md`・ADR-002・`organization-data-model.md`・`frontend/e2e/smoke/README.md` と該当 `crates/` を実際に読んで確認した。§1〜§9 のうち、決定により状態が変わった記述（クォータの「決定待ち」など）は §0 に合わせて更新した。

参照した規約: [`ARCHITECTURE.md`](../../ARCHITECTURE.md)、[`docs/architecture/LAYER-RULES.md`](../architecture/LAYER-RULES.md)、[`tdd-on-edit`](../../.cursor/skills/tdd-on-edit/SKILL.md)、[`evidence-before-design-and-implementation.mdc`](../../.cursor/rules/evidence-before-design-and-implementation.mdc)、[`project-necessary-code-only.mdc`](../../.cursor/rules/project-necessary-code-only.mdc)。

---

## 0. 決定事項の反映

課題 01 のクォータの集計単位は確定した。旧版が「01 の決定待ち」として書き換えを止めていた Q1〜Q7（旧 §3.2）は、**決定待ちではなく反映対象**になった。本章は、確定内容に基づく文書差分案、ADR-002 の扱いの再評価、課題 02（reCAPTCHA → Turnstile）に伴う docs 更新対象、依存の最新化をまとめる。本書は計画のみで、下の差分はどのファイルにも適用していない。

### 0.1 09 に影響する確定事項と、書かない事項

| 由来 | 確定内容 | 09 への影響 |
|------|----------|-------------|
| 01 第 1 回 D-1〜D-3 | Farm / Crop の上限は組織単位に統一。ユーザー単位カウントは廃止し、公開計画保存（plan-save）も組織単位で数えて `organization_id` を書く | Q1〜Q4・Q6 の文言は「組織単位」。「ユーザー単位」の記述はすべて対象 |
| 01 第 2 回 D-4 | 複数組織所属はスコープ外。作成先組織の規則は現状維持（所属の先頭）で、規則は新設しない | 文書には作成先の規則を**書かない**。「未規定」と 1 行で明示する（Q1 の追加行、Q4）。規則を決める別課題（01 §13）が出た時点で新 ADR の要否を再判定する |
| 01 第 3 回 D-5 | 複数メンバー組織では枠を組織で共有する（現行 Masters の挙動の維持。数値 4 / 20 は不変、メンバー別枠は採らない） | Q1〜Q4 に「組織の全メンバーで共有」を入れる。法人 org の契約プラン別上限は決めていないので「未定義」のまま |
| 10 第 2 回 | 組織メンバーは他メンバー所有 Plan の閲覧も編集もできない（Plan 系は所有者のみ） | ADR-002 `:54`（リソース共有に Plan を含む）と衝突する。§0.3 |
| 10 第 3 回 | Farm / Crop の組織スコープ編集も所有者のみへ縮小。閲覧は P14 が未決（推奨は組織単位のまま残す） | ADR-002 `:54`・`:67` と衝突する。閲覧の扱いが未決のため、ADR・data-model に「閲覧も共有しない」とは書けない。§0.3 |
| 02 D-1〜D-3 | CAPTCHA は Cloudflare Turnstile。reCAPTCHA は併用せず置換。fail-closed は維持 | §0.4 |

**本書が書かない事項（未決のまま）**: 01 の U3（`ARCHITECTURE.md` の更新先。01 の推奨は「09 の Q1・Q2 で実施」で、本書がその担当を引き受ける前提で書いた）、01 §3.6.5 の C1〜C4（閲覧範囲・ヒント文言・枠の回収・Plan での Crop 利用）、10 の P3（admin）・P11（ADR の形式）・P12（再開条件）・P14（閲覧範囲）・P15。これらの回答前に、閲覧・admin・枠の回収に関する断定を文書へ入れない。

**着手の条件の変化**: 解消したのは「決定待ち」だけである。**実装待ちは残る**。公開計画保存は現コードではユーザー単位のまま（`plan_save_ensure_user_farm_interactor.rs:82`、`plan_save_ensure_user_crops_interactor.rs:122-123`、SQL は `plan_save_gateways.rs:105`, `:283`）で、`ARCHITECTURE.md` に「per organization」と書くと、01 のコード変更が入るまで実装と食い違う。したがって Q1〜Q4・Q6 は **01 のコード変更（01 §7 ステップ 4・5）と同一 PR、またはその後**に入れる。先行して書く案は、移行中である旨の注記が要り、後で削る一時的な文面になるため採らない。

### 0.2 Q1〜Q7 の Before / After（確定内容に基づく差分案）

行番号は 2026-10-07 時点のワークツリーで確認した。`FarmCreateLimitPolicy` は実在する構造体（`farm_create_limit.rs:2`）だが、`CropCreateLimitPolicy` は Rust に存在せず、`crop_create_limit_policy.rs:1` の Ruby 由来コメントにだけ現れる。Crop の実体はモジュール `crop_create_limit_policy`（関数 `limit_exceeded`、定数 `MAX_NON_REFERENCE_CROPS_PER_USER`、`:3-10`）である。そのため After では実在する識別子へ直す。

#### Q1・Q2: `ARCHITECTURE.md:90-91`（L1 規範文書）

```diff
 ## Resource Limits
 
-- **Farm:** max 4 non-reference farms per user (`is_reference: false`)
-- **Crop:** max 20 non-reference crops per user
+- **Farm:** max 4 non-reference farms per organization, shared by all its members (`is_reference: false`)
+- **Crop:** max 20 non-reference crops per organization, shared by all its members
+- Counted in the organization the record is created in. Users who belong to several organizations are out of scope (creation target and quota are unspecified).
 - **Reference data:** `is_reference: true` excluded from limits
```

- 根拠（確認済み）: 組織単位の件数は `organization_id = ?1 AND is_reference = 0`（`farm_gateway.rs:297-309`、`crop_gateway.rs:138-150`）。行の `user_id` は条件に無いので、メンバー全員の行が数えられる（共有枠）。判定は `farm_create_interactor.rs:122-125`、`crop_create_interactor.rs:138-143`、crop AI upsert は `crop_ai_upsert_sqlite_persistence.rs:175-177`。
- 追加した 3 行目（複数所属）は 01 D-4 に由来する。作成先は所属の先頭（`farm_create_interactor.rs:70-77`、`crop_create_interactor.rs:59-66`）だが、これを規範として書くと、別課題で規則を変えるときに L1 を直す必要が出るため、規則は書かず「未規定」とする。**この 1 行を入れるか**は §7 の U7。入れない場合も 1・2 行目は変更する。
- 末尾の `Enforced in domain policies; DB constraints are safety net only.`（`ARCHITECTURE.md:94`）は変更しない。上限値の判定は引き続きポリシー（`FarmCreateLimitPolicy::limit_exceeded`、`crop_create_limit_policy::limit_exceeded`）が持つ。

#### Q3・Q4: `docs/design/organization-data-model.md:94-104`

```diff
-## クォータ移行（フェーズ 2 — 参考）
+## クォータ（組織単位）
 
-現行:
-
-- Farm: ユーザーあたり非参照最大 4 件（`FarmCreateLimitPolicy`）
-- Crop: ユーザーあたり非参照最大 20 件（`CropCreateLimitPolicy`）
-
-移行後:
-
-- personal org: 現行と同等の上限
-- 法人 org: 契約プランに応じた org 単位上限（フェーズ 2 で定義）
+上限は組織単位で、組織の全メンバーが同じ枠を共有する（メンバー別の枠は持たない）。判定は作成先組織の非参照件数（`organization_id = ?` かつ `is_reference = 0`）で行い、Masters・Crop AI upsert・公開計画保存のどの経路でも同じ。
+
+- Farm: 組織あたり非参照最大 4 件（`FarmCreateLimitPolicy`）
+- Crop: 組織あたり非参照最大 20 件（`crop_create_limit_policy`）
+- personal org（1 ユーザー 1 組織）: ユーザー単位の上限と一致する
+- 法人 org: 契約プラン別の上限は未定義（現行は全組織で定数 4 / 20 のみ）
+- 複数の組織に所属するユーザーの作成先組織と枠の扱いは本設計の範囲外（現行は所属の先頭に作成する。規則は別課題で定める）
```

- 見出しの `クォータ移行` を指すリンク・アンカーはリポジトリ内に無い（`rg 'クォータ移行'` のヒットは本文書と 09 のみ）。
- 「法人 org の契約プラン別上限は未定義」の根拠: 上限ポリシーは定数のみ（`farm_create_limit.rs:5-9`、`crop_create_limit_policy.rs:3-10`）で、プラン・契約に言及する記述は 2 ファイルに無い（`rg -i 'plan|契約|tier|subscription'` で 0 件）。
- 「personal org は 1 ユーザー 1 組織」の根拠: `personal_organization_sqlite_gateway.rs:93-98`（未所属ユーザーのみ作成）。ただしシステムが単一所属を強制するわけではない（01 §12-1）。文書では「1 ユーザー 1 組織」を personal org の定義として書き、強制の有無には触れない。

#### Q5・Q6: ADR-002 `:17`、`:55`（Decision は変更しない。§0.3 で「その場更新」と判定）

```diff
-| クォータ境界 | Farm / Crop 作成上限は `user_id` 単位（`FarmCreateLimitPolicy` / `CropCreateLimitPolicy`）。法人契約では組織単位の制限が自然 |
+| クォータ境界 | （起票時点）Farm / Crop 作成上限は `user_id` 単位（`FarmCreateLimitPolicy` / `crop_create_limit_policy`）。法人契約では組織単位の制限が自然（現在は組織単位に統一済み。下記「実装状況」） |
```

```diff
-| **クォータ** | Farm / Crop 上限を org 単位に集約（personal org は現行と同等） | 2 |
+| **クォータ** | Farm / Crop 上限を org 単位に集約。組織の全メンバーで枠を共有（personal org は現行と同等）。契約プラン別上限は未定義 | 1（集計単位）/ 2（プラン別上限） |
```

- Q6 の「フェーズ」列を `2` から書き分けるのは、集計単位の組織化が #612 で先行実装済み（`farm_create_interactor.rs:122-125`）で、フェーズ 2 に残るのは契約プラン別上限だけだからである（§2.1 A5）。
- Context の「実装状況」表（§3.1(d) の `:19-26` 差分案）に次の 1 行を足す。**01 のコード変更が入った後の文面**で、前提は §0.1 のとおり。

```diff
+| クォータ | 全経路が組織単位で、メンバー全員で枠を共有する。Masters: `farm_gateway.rs:297-309`、`crop_gateway.rs:138-150`。公開計画保存も同じ条件（`organization_id` と `is_reference = 0`）で数える |
```

#### Q7: 用語（定数名 `..._PER_USER`）

- 確認結果: 定数名 `MAX_NON_REFERENCE_FARMS_PER_USER`（`farm_create_limit.rs:5`、フロント `farm-create-limit.ts:8`）と `MAX_NON_REFERENCE_CROPS_PER_USER`（`crop_create_limit_policy.rs:3`）を引用する文書は、`docs/spec-defects/` を除き無い（`rg 'PER_USER'` は `ARCHITECTURE.md`・`docs/` 配下の他文書で 0 件）。したがって**文書側の追随は不要**で、01 §7 ステップ 14（任意のリネーム）を実施しても本書の差分は増えない。i18n のキー名 `attributes.user.*_limit_exceeded` も文書に出ない（キーは 01 R14 のとおり変更しない）。
- 例外: `frontend/e2e/` の識別子 `USER_FARM_LIMIT` / `countUserOwnedFarms`（`frontend/e2e/smoke/smoke-helpers.ts:84`、`frontend/e2e/shared/baseline-ids-lib.mjs:58`）は実態（一覧の非参照件数）と食い違うが、コード側の命名で、文書の更新対象ではない。

#### 01 が指摘した追加の更新箇所: `frontend/e2e/smoke/README.md:121`

旧版では「Q1〜Q7 に載っていないため 09 側で判断」としていた（§9 の 01 の行）。結論: **更新対象に含める**。同じ「ユーザー単位」の記述を文書に残さないためである。

```diff
-| `user farm limit reached (max 4)` | ユーザー農場 4 件上限（farms UI CRUD） |
+| `user farm limit reached (max 4)` | 農場の上限（非参照 4 件。組織単位で、同じ組織の他メンバーの農場も数える）に達している（farms UI CRUD） |
```

- 左のセルは、skip 理由の実際の文字列（`frontend/e2e/smoke/operation-smoke.spec.ts:168` の `'user farm limit reached (max 4)'`）の引用なので**変更しない**。この文字列を変えるのはコード変更で、本書の範囲外。
- 右のセルの根拠: skip 判定の件数は `GET /api/v1/masters/farms`（組織スコープの一覧）の非参照行数（`smoke-helpers.ts:87-98` の `getUserOwnedFarmCount` と、`baseline-ids-lib.mjs:58-60` の `countUserOwnedFarms`（`is_reference === false` の行数））で、バックエンドの枠（組織の非参照件数）と同じ集合を数える。ただしこの一致は、一覧を組織単位のまま残す前提（01 の C1 (a)、10 の P14 (a)。いずれも未決）に依存する。**C1 が (b)（閲覧も所有者のみ）に決まった場合は、この行を 01 の件数判定に合わせて再度更新する**。
- 同ファイルの `:36`（`farms-zero`）と `:38`（`crops-zero`）の「ユーザー農場 0 件」「ユーザー作物 0 件」は、空状態の再現（`e2e_empty` ユーザー）の説明で、上限と無関係のため対象外。

### 0.3 ADR-002 の扱い: その場更新で足りるか、新 ADR が必要か（再評価）

旧版（§3.1(d)）の判断基準（Decision 自体の変更・追加は新 ADR、事実の更新・仮称の確定はその場更新）をそのまま適用し、01 と 10 の確定内容を当てはめた。旧版は「A4・A5・A15 は 01 の決定内容を見て再判定」としていた。

| # | 確定内容（由来） | ADR-002 の該当箇所 | Decision の変更か | 措置 |
|---|------------------|-------------------|-------------------|------|
| 1 | 上限は組織単位（01 D-1〜D-3） | `:17`（Context）、`:55`（クォータ行） | **いいえ**。`:55` は起票時から「org 単位に集約」と定めている。確定は Decision の実現 | その場更新（Q5・Q6） |
| 2 | 複数メンバー組織は枠を共有（01 D-5） | `:55` | **いいえ**。「org 単位に集約」の帰結で、現行 Masters の挙動の維持（`farm_gateway.rs:297-309`） | その場更新（Q6 の文言に含める） |
| 3 | 複数所属はスコープ外・作成先規則は現状維持（01 D-4） | 記載なし（§2.1 A15） | **いいえ**（規則を新設しないため）。ただし「ADR に規則の記載が無い」事実は残る | その場更新で「未規定」の注記のみ。**規則を定める別課題（01 §13）が出たら新 ADR** |
| 4 | Plan は所有者のみ。組織共有を撤回（10 第 2 回） | `:54`（リソース共有に Plan を含む）、`:15`、`:127`（フェーズ 6 の Plan の org スコープ認可） | **はい**。Accepted の Decision 表の 1 行を覆す | **新 ADR** |
| 5 | Farm / Crop の組織スコープ編集も所有者のみ（10 第 3 回） | `:54`、`:67`（`user_id` 単独判定を段階的に縮小） | **はい**。`:67` の方向が編集については逆になる | **新 ADR**（4 と同じ ADR にまとめる） |
| 6 | 組織共有の再開条件（10 §3.3 の P12） | 記載なし | **はい**（新しい決定の一部） | 新 ADR に記載 |
| 7 | 実装状況（org スコープ認可・一覧、`OrganizationAccessPolicy` の確定名、`V16`、進捗表） | `:11`、`:19-26`、`:66-67`、`:102`、`:117-127` | いいえ（事実の更新） | その場更新（§3.1(d)） |

**推奨: 新 ADR（ADR-003）を起票し、ADR-002 は最小限の注記にとどめる。** 理由:

- 4〜6 は Decision の変更で、旧版が定めた基準では新 ADR になる。10 も P11 で (b)（新 ADR）を推奨しており、判断が一致する。
- Accepted の ADR-002 の `:54` を書き換えると、「なぜ組織共有を意図したか」と「なぜ撤回したか」が 1 文書に混ざる。B2B 向けの共有が将来必要になったとき（再開条件）に、判断の履歴を追えなくなる。
- 01 だけを見れば、1〜3 はその場更新で足りた（旧版が保留していた A4・A5 の再判定結果）。新 ADR が必要になった原因は 10 だけである。クォータの確定（1〜2）は、ADR-003 に「維持するもの」として 1 節を設けるが、ADR-002 の `:55` 自体は Q6 のとおりその場更新で足りる。
- 現時点で `docs/adr/` は ADR-001・ADR-002 の 2 本だけで（`ls docs/adr` で確認）、次の番号は ADR-003。ただし 10 は採番を決めていない（10 §3.1 P11）ため、**番号は起票時に確定する**。

**ADR-002 側のその場変更（最小）**: 旧 §3.1(d) の差分（`:11`、`:19-26`、`:66`、`:102`、`:117`、`:119-127`）に加えて、次を足す。

| 箇所 | 追加する内容 | 条件 |
|------|--------------|------|
| `:3-5`（Status） | 1 行: 「Plan の組織共有、および Farm / Crop の編集の組織共有は ADR-003 で撤回された（Accepted のまま）」 | ADR-003 と**同一コミット**（参照先が無い状態を作らない） |
| `:54`（リソース共有の行） | 行は変更せず、脚注または直後の 1 行で「Plan は共有しない・Farm / Crop は編集を共有しない: ADR-003」と参照する | 同上 |
| `:67`（既存ポリシー） | 同様に ADR-003 を参照（`user_id` 単独判定を縮小する方向は、編集については採らない） | 同上 |
| `:127`（フェーズ 6） | 「#612 が導入した Plan の org スコープ認可は ADR-003 で撤回」と注記 | 同上 |
| `:15`（Context の「組織単位で計画共有」） | 起票時点の記述として保持（変更しない）。10 の U20 のとおり、この「計画」が Plan を指すかは文言だけでは断定できない（未確認） | なし |

**ADR-002 の「実装状況」表（旧 §3.1(d) の `:19-26` 差分）の書き方の変更**: 現コードの `ReferenceRecordAccessFilter` は、`view_allows` と `edit_allows` の両方が組織分岐を持つ（`reference_record_access_filter.rs:37-51`, `:53-67`）。10 の縮小で `edit_allows` の組織分岐は除かれ、`view_allows` は P14 の回答まで残る。さらに Plan の認可は現在 `organization_member_access` を使う（`private_cultivation_plan_access_policy.rs:4,19-22`）が、縮小で外れる。したがって、`farm_policy.rs` / `reference_record_access_filter.rs` / Plan に関する実装状況の行を**今の実装のまま**書くと、10 のマージ後に再び陳腐化する。よって次のように分ける。

- 4a（今すぐ可。10 に依存しない）: `:11` の起票時点化、`:17`・`:55`（Q5・Q6）、`:66` の仮称の確定、`:102` の `V16`、`:117` の削除、`:119-127` の進捗表の状態列、`reference_index.rs:13-64` の行。
- 4b（10 の縮小実装と同時、または ADR-003 と同時）: `farm_policy.rs` / `ReferenceRecordAccessFilter` に関する行と `:67` の差分。書く内容は「閲覧: policy または組織メンバーシップ（`view_allows`）。編集: policy（所有者・admin）のみ（ADR-003）」とし、10 が Plan・Farm / Crop の組織分岐を除いた**後の**状態を記述する。閲覧（P14）が (b) に決まった場合は「閲覧も policy のみ」へ変える。

**併せて更新が必要な設計文書**（10 §3.3 が列挙する `organization-data-model.md` の箇所。本書の確認: `:39-41` ロール表の「リソース CRUD」「org 内リソースの CRUD」、`:51` Tier 1 の `cultivation_plans`、`:114` ER 図の `organizations ||--o{ cultivation_plans : owns`）:

- 4b と同時に、ロール表へ「リソースの編集は自分の行に限る（組織メンバーシップでは他メンバーの行を編集できない。`organization_member_access` は役割を見ない: `org_scope.rs:14-23`）」旨を注記する。`cultivation_plans` の行は「組織列を持つが、組織で共有しない（所有者のみ）」とする。ER 図の `owns` は、Plan だけ関係の意味が変わるため、ER 図内の表現（`owns` のまま `organization_id` 列を持つ関係を示すか）は ADR-003 の確定後に決める（本書では案を出さない）。
- これらは 10 の P14 が未決の間は、閲覧に関する記述を足さない。

**起票の前提（本書が決めないこと）**: ADR-003 の起票は、10 の P11（形式）・P12（再開条件）・P14（閲覧範囲）の回答を待つ。回答前に起票する場合の Status は、既存 ADR（`Accepted (YYYY-MM-DD)` の形式）に合わせられない（Proposed を使う規約が `docs/adr/` に無い）ため、**回答後に Accepted で起票する**のを推奨する。起票は 10 のステップ 10 の担当で、本書は ADR-002 側の参照追記（上表）と `organization-data-model.md` の追随を担当する。

### 0.4 課題 02（reCAPTCHA → Turnstile）に伴う docs 更新対象

02 の決定（D-1〜D-3）が docs に及ぶ範囲を、`rg -i 'recaptcha|turnstile|captcha'` と `rg 'contact'` で確認した。

- `docs/` 配下（`docs/spec-defects/` を除く）に reCAPTCHA / CAPTCHA / Turnstile の記述は **0 件**。置換対象の既存記述は無く、新規追記の要否だけが論点になる。
- リポジトリ全体で `recaptcha` を含むファイルは `crates/`（13 ファイル）と `scripts/`（4 ファイル）の計 17 ファイルだけ（02 §5.7 と一致）。フロント、`docker-compose.yml`、`env*.example`、デプロイスクリプト、`.cursor/` には 0 件。

| # | 対象 | 現状（確認済み） | 更新の要否・内容 | 担当 |
|---|------|------------------|------------------|------|
| T1 | 本書 §2.3 `:92`（`/api/v1/health` の JSON キー） | `recaptcha_configured` を返す（`routes.rs:33,45`）。契約テストが断言（`contracts.rs:4471`）。02 の Q7 は `captcha_configured` への改名を推奨 | 02 が実装されるまで現行の記述が正しい。本書の記述は**キー名の将来変更を明記**する（本書内で更新済み: §2.3） | 本書 |
| T2 | 本書 §9 の 02 の行 | 旧版は「未確認」「依存なし」 | 02 を読んだ結果で更新済み（§9） | 本書 |
| T3 | `docs/ops/core-api-optimization-sli-slo.md:6` | ヘルスの**エンドポイントのパス**だけを列挙。JSON のキー（`recaptcha_configured`、`warnings`）には言及しない（同文書内を `warnings`・`contact` で検索して 0 件） | **更新不要**。§3.1(a) のリンク修正と出典の修正（`lib.rs` と `routes.rs`）は 02 と独立 | — |
| T4 | `docs/api/openapi.yaml` | `contact_messages` の記述が **0 件**（`rg` で確認）。ヘルスの JSON スキーマも本調査では未確認 | 09 の範囲外。02 の確定契約（Turnstile トークンのワイヤ名 Q8、201 / 422 / 429 / 503、`code`）と `captcha_configured`（Q7）を **08 に渡す**。08 が追加する時点で本書の追記は不要 | 08 |
| T5 | `docs/api/getting-started.md`、`docs/design/`、`docs/ops/`（SLI/SLO 以外） | 問い合わせ・CAPTCHA に言及なし。`docs/` で `contact_message`・`/contact`・`問い合わせ` を検索したヒットは、移行台帳（`docs/migration/lib-domain-rust/TRACKING.*`）、`docs/seo/gsc-crux-operations-runbook.md:39`、`organization-data-model.md:80`、`docs/ROADMAP.md:140`（利用者の問い合わせという一般語）のみ | 更新不要。`organization-data-model.md:80`（`contact_messages` はテナント非スコープ）は CAPTCHA と無関係で変更しない | — |
| T6 | `docs/seo/gsc-crux-operations-runbook.md:39`、`docs/seo/seo-review-perspectives.md:71` | `/contact` の canonical と、観点 5.3（CSP 等）の列挙のみ | 更新不要。Turnstile のために CSP を広げる作業は `security_headers.rs` と `scripts/agrr-security-response-headers.yaml` に閉じる（02 §5.5） | 02 |
| T7 | 運用文書（Secret Manager への secret 登録、本番 LB への CSP 適用） | `docs/ops/` に secret 一覧・CSP 適用手順は無い（`rg -i 'secret'` は `docs/ops/litestream-rpo-rto-runbook.md:144` の `GCS_BUCKET` のみ） | 新規文書は**作らない**（`project-necessary-code-only`）。手順は 02 §5.6 のとおりデプロイスクリプトとスキル（`.cursor/skills/deploy-server`、`deploy-frontend`）、`env.example` に置く。これらは `docs/` の外 | 02 |
| T8 | プライバシーポリシー本文 | `docs/` ではなくフロントの i18n（`ja.json` ほか 3 ロケール）にある（02 Q4） | 本書の対象外 | 02 |
| T9 | `docs/spec-defects/README.md` の更新履歴 | 「06 §9 と 08, 09, 11 の一部記述は、この決定（特に 02 の reCAPTCHA→Turnstile）への追随が未実施」 | 本書は 02 への追随を済ませた。README の該当記述の更新は README の担当（本書の編集範囲外） | README |

結論: 09 が**今**直すべき docs は T1・T2（本書の内部記述）のみで、02 の実装後に直す docs は無い。02 実装後の追随は、本書に残る `routes.rs` の行番号（§2.3 の `routes.rs:18,26` ほか）が動くだけで、本書は日付付きのスナップショットとして扱う。

### 0.5 この反映で変わる実施ステップと依存

詳細は §6（ステップ 7〜9）、§7、§8、§9 に反映した。要点:

- Q1〜Q7 と e2e README は**決定待ちではなく、01 のコード変更（plan-save の組織化）に従属**する。
- ADR-002 は 4a（今すぐ可）と 4b（10 の縮小と同時、または ADR-003 と同時）に分け、ADR-003 の起票は 10 の担当で、10 の P11・P12・P14 の回答待ち。
- 02 に伴う docs の新規更新は無い（§0.4）。

---

## 1. 概要と重大度

### 概要

設計文書（ADR・設計メモ・運用文書）が実装・ファイル配置と乖離している。5 系統ある。

| # | 系統 | 要旨 |
|---|------|------|
| A | ADR-002 の記述ずれ | Context の「現状」表、参照ファイル名、フェーズ進捗表が実装（2026-08-06 に epic #604 の子 issue がすべて close 済み）に追随していない |
| B | クォータの記述 | `ARCHITECTURE.md` / `organization-data-model.md` / ADR-002 / `frontend/e2e/smoke/README.md` が「ユーザー単位」。実装は経路により「組織単位」と「ユーザー単位」が混在している。**課題 01 で「組織単位・メンバー全員で枠共有」に確定済み**（§0）。文書は**反映対象**で、01 のコード変更（plan-save の組織化）と同一 PR またはその後に直す |
| C | SLI/SLO 文書 | 相対リンク 6 箇所（5, 54, 135, 141 行の 4 行に 6 リンク）が `docs/.cursor/...` を指して切れている。ヘルスエンドポイントの出典が 1 ファイルのみ |
| D | 全 Markdown のリンク切れ | 対象 39 ファイル・ローカルリンク 374 件のうち **20 件が切れ**。既存 CI（`doc-freshness.yml`）は検査対象が 6 ファイル固定のため検知していない |
| E | 存在しないパス参照 | `LAYER-RULES.md:27` と `CLAUDE.md:51` の `composition.rs`、ADR-002 の `V15__organizations.sql` など。追加で `ARCHITECTURE.md` の「Rails shell が残る」記述も実態と乖離（§2.7、スコープ判断が必要） |

### 重大度

| 項目 | 重大度 | 理由 |
|------|--------|------|
| A ADR-002 の記述ずれ | 中 | ADR は設計判断の正本。「現状は `user_id` のみ」を信じると、実装済みの org スコープ認可を見落として重複実装・誤修正を招く。実行時の不具合はない。加えて、課題 10 の決定（Plan の組織共有の撤回、Farm / Crop の編集共有の撤回）は ADR-002 `:54`・`:67` の Decision と食い違うため、ADR を更新せずに 10 を実装すると「ADR が掲げる共有を実装が閉じている」状態が新たに生じる（§0.3） |
| B クォータ記述 | 中（01 のコード変更に従属） | `ARCHITECTURE.md` は L1 の規範文書。実装と食い違うまま放置すると、01 の修正後も文書が誤る。正解は確定した（§0）ので書き換え案を用意した。ただし plan-save が組織化される前に「per organization」と書くと現コードと食い違うため、01 のコード変更と同時またはその後に入れる |
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

### 2.2 クォータの実装状況（課題 01 が統一対象とした現状。方針は 01 で確定済み: §0）

| 経路 | 数え方 | 根拠 |
|------|--------|------|
| Farm 作成（masters） | **組織単位** | `crates/agrr-domain/src/farm/interactors/farm_create_interactor.rs:122-125`、SQL は `crates/agrr-adapters-sqlite/src/farm/farm_gateway.rs:303`（`WHERE organization_id = ?1 AND is_reference = 0`） |
| Crop 作成（masters） | **組織単位** | `crop_create_interactor.rs:140-143`、`crop_gateway.rs:144` |
| Crop 作成（AI upsert） | **組織単位** | `crates/agrr-adapters-sqlite/src/crop/crop_ai_upsert_sqlite_persistence.rs:175-177` |
| 公開計画の保存に伴う Farm 作成 | **ユーザー単位** | `crates/agrr-domain/src/cultivation_plan/interactors/plan_save_ensure_user_farm_interactor.rs:82-83`、SQL は `crates/agrr-adapters-sqlite/src/cultivation_plan/plan_save_gateways.rs:105`（`WHERE user_id = ?1`） |
| 公開計画の保存に伴う Crop 作成 | **ユーザー単位** | `plan_save_ensure_user_crops_interactor.rs:122-123`、`plan_save_gateways.rs:283` |

- 上限値の定数名は `MAX_NON_REFERENCE_FARMS_PER_USER = 4`（`farm_create_limit.rs:5`）、`MAX_NON_REFERENCE_CROPS_PER_USER = 20`（`crop_create_limit_policy.rs:3`）のまま。
- エラーメッセージは「作成できるFarmは4件までです」等（`config/locales/ja.yml:358,362`、`en.yml:226,230`）。
- 文書側の記述は次の 5 箇所が「ユーザー単位」または「現行と同等」:`ARCHITECTURE.md:90-91`、`organization-data-model.md:96-104`、ADR-002 `:17,55`、`frontend/e2e/smoke/README.md:121`（「ユーザー農場 4 件上限」）。
- 上表の「組織単位／ユーザー単位」の混在は、課題 01 で**組織単位に統一**と確定した（plan-save の 2 経路が変更対象。メンバー全員で枠を共有）。本書は確定内容に基づく Before / After を §0.2 に置いた。

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
- `/api/v1/health`: `crates/agrr-server/src/routes.rs:18`（ルート定義）、ハンドラ `routes.rs:26` の `api_v1_health`（JSON。`status` / `database` / `recaptcha_configured` 等を返す。キー名は課題 02 の Q7 で `captcha_configured` へ改名される場合がある。改名されるまでは現行の記述が正しい。`routes.rs:33,45`、契約テスト `contracts.rs:4471`）。`lib.rs:179` の `merge(routes::api_routes())` で組み込まれる
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
| Decision 自体の変更・追加 | ADR の記載（クォータは org 単位）と異なる集計単位の採用、複数所属時の org 選択規則の新設（A15）、role 別権限の変更、リソース共有の範囲の変更 | **新 ADR（ADR-003 以降）** を追加し、ADR-002 の該当節に「Amended by ADR-00x」を 1 行追記 |

**判定（01・10 の確定内容で再評価済み。詳細は §0.3）**: A1〜A3・A6〜A8・A13 は事実の更新なので**その場更新**。A4・A5（クォータ）は、01 が ADR-002 `:55` の「org 単位に集約」をそのまま実現する決定（Decision の変更ではない）だったため、**その場更新で足りる**。A15（所属先の選択規則）は 01 が規則を新設せず現状維持としたため、ADR には「未規定」の注記のみ入れる（規則を定める別課題が出たら新 ADR）。一方、10 の決定（Plan の組織共有の撤回、Farm / Crop の編集共有の撤回）は `:54`・`:67` の Decision を覆すため、**新 ADR が必要**。

**その場更新の差分案**（A4・A5・A15 以外）:

| 箇所 | Before | After（案） |
|------|--------|-------------|
| `:11` | `AGRR は現状 **ユーザー単位のテナント分離** のみを持つ。…` | `AGRR は起票時点（2026-08-06）で **ユーザー単位のテナント分離** のみを持っていた。現在は organization 単位のアクセス制御が併存する（下記「実装状況」）。…`（以降の `user_id` スコープの説明は起票時点として保持） |
| `:19-26` 見出しと表 | `現状の参照実装:`（`farm_policy.rs — user_id == Some(user.id)`、`reference_index.rs — user_id = ?`） | 見出しを `起票時点の参照実装:` に改め、表はそのまま保持。直後に `実装状況（YYYY-MM-DD 時点）` 表を追加し、`reference_index.rs:13-64`（`organization_id IN` を org 所属時に使用）とクォータ行（§0.2）を記載（4a）。`farm_policy.rs:22-27` と `reference_record_access_filter.rs:37-67` の行は、閲覧は policy または org メンバーシップ、編集は 10 の縮小後に policy のみ、という状態で書くため 4b（§0.3）。今の `edit_allows` の組織分岐（`:53-67`）をそのまま記載しない |
| `:66` | `OrganizationAccessPolicy`（仮称） | `OrganizationAccessPolicy`（`crates/agrr-domain/src/organization/policies/organization_access_policy.rs`） |
| `:67` | `FarmPolicy 等は organization_id チェックを追加し…` | **4b（§0.3）。10 の縮小実装と同時、または ADR-003 と同時に記載**: `既存ポリシーの org 対応は ReferenceRecordAccessFilter（crates/agrr-domain/src/shared/reference_record_access_filter.rs）を介して行う。user_id 単独判定は policy 側に残る` に加え、編集は組織メンバーシップでは許可しない旨（ADR-003）を参照。今の実装（`edit_allows` が組織分岐を持つ）のまま書くと 10 のマージ後に再び陳腐化する |
| `:102` | `V15__organizations.sql（新規）` | `V16__organizations.sql` |
| `:106` | `org 切替 UI・コンテキスト（フェーズ 1 以降の子 issue）` | 変更しない（未実装のまま。任意で「未着手」と明記） |
| `:117` | `…起票後に issue 番号を本表へ追記する。` | 該当文を削除（追記済み） |
| `:119-127` 表 | 列: フェーズ / Issue / 内容 | 列名を `ステップ` に改め（`:49-58` の製品フェーズとの衝突回避）、`状態` 列を追加。#606〜#612 を `完了（2026-08-06）`。日付は各 issue の `closedAt` を実装時に再取得して記入 |

`:17`・`:55`（クォータ）は 01 が確定済みのため決定待ちではなく、§0.2 の Q5・Q6 の差分で処理する（その場更新）。10 に由来する `:3-5`・`:54`・`:67`・`:127` の ADR-003 参照は §0.3 に記載した。

#### (e) `docs/design/organization-data-model.md`

| 箇所 | Before | After（案） | 依存 |
|------|--------|-------------|------|
| `:1`, `docs/README.md:9` | `Organization データモデル案` | 任意: 実装済みの旨を 1 行追記（見出し改名は index 文言との同期が要るため §7 の判断事項） | なし |
| `:62` | `新規作成時は organization_id を必須とし` | `新規作成時は domain 層で organization_id を必須とし（DB 列は nullable: V16__organizations.sql:1）` 。根拠 `farm_policy.rs:43-50`（`organization_id: i64` を必須引数） | なし |
| `:92` | `バックフィルスクリプトは is_personal = 1 の org が既に存在するユーザーはスキップ。` | `バックフィルは起動時に実行され（crates/agrr-server/src/lib.rs:124-127）、personal org を持たないユーザーのみ対象（personal_organization_sqlite_gateway.rs:93-98）。` | なし |
| `:94-104` クォータ移行 | 「現行: ユーザーあたり…」「personal org: 現行と同等」 | §0.2 の Q3・Q4（組織単位・枠共有。契約プラン別は未定義） | 01 のコード変更（決定は確定済み） |
| `:39-41`, `:51`, `:114` ロール表・Tier 1 の `cultivation_plans`・ER 図 | 「リソース CRUD」「org 内リソースの CRUD」、ER 図の organizations と cultivation_plans の `owns` 関係 | §0.3（10 の決定の追随。閲覧に関する記述は 10 の P14 回答まで足さない） | 10 の縮小・ADR-003（4b） |
| `:119-126` 関連ファイル | パス | 変更不要（実在確認済み） | なし |

`:83-90` の移行手順（slug `user-{id}`、name は email か `Personal`）は `personal_organization_policy.rs:4-16` と一致しており、修正不要。

### 3.2 課題 01 の確定内容を反映する文書修正箇所（Q1〜Q7）

旧版は 01 の決定まで「書き換えない」としていたが、01 は確定した。Q1〜Q7 は**反映対象**で、Before / After の差分案は §0.2 に移した（重複を避けるため本節には再掲しない）。対応表:

| # | 箇所 | 状態 | 差分案 |
|---|------|------|--------|
| Q1 | `ARCHITECTURE.md:90` | 反映対象（`per user` → 組織単位・メンバー全員で枠共有） | §0.2 Q1・Q2 |
| Q2 | `ARCHITECTURE.md:91` | 同上。複数所属の「未規定」1 行は U7 | §0.2 Q1・Q2 |
| Q3 | `organization-data-model.md:96-99` | 反映対象（識別子は `FarmCreateLimitPolicy` と `crop_create_limit_policy`） | §0.2 Q3・Q4 |
| Q4 | `organization-data-model.md:101-104` | 反映対象（契約プラン別上限は未定義と明記） | §0.2 Q3・Q4 |
| Q5 | ADR-002 `:17` | 反映対象（その場更新。起票時点の注記） | §0.2 Q5・Q6 |
| Q6 | ADR-002 `:55` | 反映対象（その場更新。フェーズ列を書き分け） | §0.2 Q5・Q6 |
| Q7 | 用語（定数名 `..._PER_USER`） | **追随不要**（文書は定数名を引用しない。再確認済み） | §0.2 Q7 |
| （追加） | `frontend/e2e/smoke/README.md:121` | 反映対象（旧版は 09 側の判断としていたが、含めると決定） | §0.2 |

実施順: Q1〜Q7 と追加の 1 件は、01 のコード変更（plan-save の組織化）と同一 PR またはその後に入れる（§0.1）。決定待ちはもう無いが、先行すると現コードと食い違う記述が残る。

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

依存のない順。各ステップは別コミットにできる粒度。01・10・02 に従属するステップは最後に分離する。01 は決定が確定済みで、残る従属は**実装**（コード変更）であり、決定待ちのステップは無い（§0.1）。

| # | 内容 | 対象 | 依存 | 検証 |
|---|------|------|---------|------|
| 1 | SLI/SLO のリンク 6 箇所と `:6` のヘルスエンドポイント出典を修正 | `docs/ops/core-api-optimization-sli-slo.md` | なし | §5.2 手順 1・2 |
| 2 | その他のリンク切れ 14 件（#1-#14）を修正。#2 はリンクを外しテキスト化 | `docs/design/layout-contracts.md`、`docs/migration/app-rust-stack/{README,PROVISIONAL-STACK}.md`、`docs/migration/archive/{README,P6-COMPLETION-CRITERIA}.md` | なし | 同上 |
| 3 | `composition.rs` 参照を現行の記述に修正 | `docs/architecture/LAYER-RULES.md:27`、`CLAUDE.md:51` | なし | `check-layer-rules-md-lib.test.mjs`、§5.2 手順 1 |
| 4 | ADR-002 の「その場更新」4a（`:11`、`:19-26` のうち起票時点化と `reference_index.rs` の行、`:66`、`:102`、`:117`、`:119-127`。クォータ `:17,55` と、`farm_policy.rs` / `ReferenceRecordAccessFilter` の行・`:67` は除く） | `docs/adr/ADR-002-organization-multi-tenancy.md` | なし | 目視 + §5.2 手順 1 |
| 5 | data-model の `:62`・`:92` を修正（`:94-104` は除く） | `docs/design/organization-data-model.md` | なし | 同上 |
| 6 | （案 B 採用時のみ）チェッカ拡張。RED → GREEN | `scripts/check-doc-freshness-lib.mjs`、`scripts/check-doc-freshness-lib.test.mjs` | なし（**1・2 の後**） | §5.3 |
| 7 | クォータ記述 Q1〜Q7 を反映（§0.2 の差分）。`frontend/e2e/smoke/README.md:121` を含む。ADR-002 の判定は済み（Q5・Q6 はその場更新: §0.3） | `ARCHITECTURE.md:90-91`、`organization-data-model.md:94-104`、ADR-002 `:17,55`、ADR-002 の実装状況表のクォータ行、`frontend/e2e/smoke/README.md:121` | **01 のコード変更（plan-save の組織化）と同一 PR またはその後**。決定は確定済み | §5.2 手順 1・2 |
| 8 | ADR-003 の起票に合わせた ADR-002 の参照追記と 4b（`:3-5`、`:54`、`:67`、`:127`、`farm_policy.rs` / `ReferenceRecordAccessFilter` の実装状況行）、`organization-data-model.md` の `:39-41`・`:51`・`:114`、`docs/README.md` の ADR 一覧への ADR-003 追加（§0.3）。ADR-003 本体の起票は 10 のステップ 10 の担当 | `docs/adr/ADR-002-organization-multi-tenancy.md`、`docs/design/organization-data-model.md`、`docs/README.md` | **10**（P11・P12・P14 の回答。10 の Plan・Farm / Crop の縮小実装と同一リリースまたは直後。ADR-003 と同一コミットで参照を追記） | §5.2 手順 1・2。ADR-002 の参照先 ADR-003 が実在すること |
| 9 | 02 の実装後に、本書 §2.3 のヘルスキーの記述（`recaptcha_configured` → 実装後のキー）と `routes.rs` の行番号を確認し直す。docs 側に新規更新は無い（§0.4） | 本書のみ | 02（Q7 の採否と実装） | 記述の確認のみ |

ステップ 1〜5・7〜9 は文書のみで、`test-common` のランナー対象（Rust/R4/Frontend）は無い。文書のみの変更では `rebuild-restart.sh`（`crates/*` 変更時のみ必要）も不要。ただしステップ 7・8 が従属する 01・10 のコード変更側は `crates/*` を変更するため、そちらでは `rebuild-restart.sh` が要る。

---

## 7. リスク・未確定事項

### 課題 01 の決定は確定済み（旧「決定待ち」の更新）

- クォータの集計単位は**組織単位・メンバー全員で枠共有**に確定した（01 D-1〜D-3、D-5）。Q1〜Q7（§0.2、§3.2）は決定待ちではなく反映対象。
- 複数 org 所属時の作成先 org の規則（§2.1 A15）は、01 D-4 によりスコープ外（規則は現状維持）。文書には規則を書かず「未規定」と明記する。規則を定める別課題（01 §13）が出たら、新 ADR の要否を再判定する。
- ADR-002 を更新で済ませるか新 ADR を立てるかは判定済み: 01 の内容だけならその場更新で足りる。10 の決定（Plan の組織共有の撤回、Farm / Crop の編集共有の撤回）が `:54`・`:67` の Decision を覆すため、**新 ADR（ADR-003）を推奨**（§0.3）。
- **残る従属は実装**: plan-save が組織化される前に ARCHITECTURE.md 等を「組織単位」と書くと現コードと食い違う。ステップ 7 は 01 のコード変更と同一 PR またはその後（§0.1）。

### 課題 10 の未決に従属する事項（本書は決めない）

- ADR-003 の起票とステップ 8 は、10 の P11（形式）・P12（再開条件）・P14（Farm / Crop の閲覧を組織単位で残すか）の回答待ち。P14 が未決の間、ADR・data-model に閲覧の範囲を書かない。
- 10 の P3（admin）。ADR-002 `:68`（admin は全 org を横断）と、Plan 系の共通ポリシーが admin を見ない現状（10 §3.2）の食い違いは、P3 の決定後に ADR-003 に含めるかを決める。
- 01 の C1〜C4（閲覧範囲、ヒント文言、所有者不在の枠の回収、Plan での Crop 利用）。C1 が (b) に決まった場合は、ステップ 7 の `frontend/e2e/smoke/README.md:121` の文言を再度更新する（§0.2）。

### 本課題内で判断が必要な事項

| # | 事項 | 選択肢 |
|---|------|--------|
| U1 | チェッカ拡張（案 B）の採否 | 採用（推奨）／文書修正のみ（案 A）。採用時は 1・2 の後に実施 |
| U2 | `ARCHITECTURE.md:9,16`・`README.md:90`・`CLAUDE.md:7` の「Rails shell が残る」記述（§2.7）を本課題に含めるか | 含める（ARCHITECTURE.md を触る 7 番と同時に整理）／別課題（11 など）に送る。`CLAUDE.md` はエージェント入口のため変更の可否をユーザーに確認したい |
| U3 | `LAYER-RULES.md:27` / `CLAUDE.md:51` の代替文言 | §3.1(c) の案でよいか。「配線を集約するモジュールを新設する」設計判断とは別物（本課題では新設しない） |
| U4 | `P7-MIGRATION-RUNBOOK.md:175` の `db/fixtures/india_reference_weather.json`（§2.5） | `Dockerfile.agrr-server` と運用手順を確認したうえで修正するか、履歴として残すか。**現時点は未確認**のため触らない |
| U5 | SLI/SLO `:6` に `/api/v1/ready`（`routes.rs:19`）を併記するか | 任意 |
| U6 | data-model の見出し「データモデル案」の改名 | `docs/README.md:9` の索引文言と同時変更が必要。任意 |
| U7 | `ARCHITECTURE.md` の Resource Limits に「複数所属は範囲外（作成先・枠は未規定）」の 1 行を足すか（§0.2 Q1・Q2） | 足す（推奨。01 の既知の制限 §12 を L1 から辿れ、別課題で規則を決めるときの更新点が明確になる）／足さない（L1 を最小に保つ。01 U3 の推奨のもう一方の選択肢「別課題の完了後に回す」に相当）。足さなくても 1・2 行目の変更は行う |
| U8 | ADR-002 の「実装状況」表のクォータ行・data-model の追随を、ステップ 7（01 のコード変更と同一 PR）に含めるか、ステップ 8 に回すか | 7 に含める（推奨。クォータは 10 に依存しないため）。8 に回すと、10 の回答待ちが 01 の文書更新まで遅らせる |
| U9 | ADR-003 の Status を、回答前に Proposed で出すか、回答後に Accepted で出すか | 回答後に Accepted（推奨）。`docs/adr/` に Proposed を使う前例が無い（ADR-001・002 は Accepted）。確定するのは 10 の担当 |

### 実装時のリスク

- `docs/spec-defects/` を含む `docs/` 配下はチェッカ拡張（案 B）の走査対象になる。本書を含む各 `docs/spec-defects/*.md` は相対リンクを実在パスで書く必要がある（本書は `../../` 形式で記載済み。§5.2 手順 1 で確認する）。
- `check-doc-stale-paths.sh` は `docs/` 配下の文書に旧 Ruby ドメイン用ディレクトリや旧 API コントローラのパスをそのまま書くと失敗する（`check-doc-freshness-lib.mjs:4-8`、allowlist は `docs/migration/` のみ `:39-42`）。本書はこれらの文字列を避けて記述している。ADR-002 の更新文面でも同様に避ける。
- `.cursor/skills/clean-architecture-violation-fix-workflow/SKILL.md:25,58,82` と `.cursor/rules/rails-clean-architecture.mdc:22` の `composition.rs` 参照は本課題で直さないため、規範文書間で一時的に表現が食い違う（未修正のまま放置しない: 課題 11 または別 issue で扱う）。
- 一時スクリプトの数値（39 ファイル・374 件・20 件、178 パス・46 件）は 2026-09-29 の `master` での測定値。他課題の文書追加（`docs/spec-defects/` 等）により総数は変わるが、既存の切れ 20 件は影響を受けない。

---

## 8. 受け入れ条件

文書修正（ステップ 1〜5。従属するステップ 7・8 は後述）の完了条件:

1. `./scripts/check-doc-internal-links.sh` と `./scripts/check-doc-stale-paths.sh` が成功する。
2. `node --test scripts/check-doc-freshness-lib.test.mjs`、`scripts/verify-core-api-optimization-sli-slo-doc-lib.test.mjs`、`scripts/check-layer-rules-md-lib.test.mjs` が成功する。
3. `docs/**/*.md` と `ARCHITECTURE.md`・`README.md`・`CLAUDE.md`・`AGENTS.md` の相対リンクを網羅検査した結果、**切れ 0 件**（一時スクリプトの実行結果を PR に貼る。スクリプト自体はコミットしない）。
4. `docs/ops/core-api-optimization-sli-slo.md:6` のヘルスエンドポイントの出典が `lib.rs`（`/health`, `/up`）と `routes.rs`（`/api/v1/health`）に分かれている。
5. ADR-002 に `V15__organizations.sql` が残っておらず、Context の「現状」表が起票時点と明記され、実装状況（org スコープの認可・一覧）が記載されている。フェーズ進捗表に状態が入っている。
6. `LAYER-RULES.md` と `CLAUDE.md` に存在しない `composition.rs` が残っていない。
7. 差分が編集対象の文書のみで、`crates/`・`frontend/` に変更がない（案 B 採用時は `scripts/check-doc-freshness-lib.{mjs,test.mjs}` を除く）。

クォータ記述（ステップ 7）の完了条件（**01 のコード変更と同一 PR またはその後**。決定は確定済み）:

8. `ARCHITECTURE.md:90-91`・`organization-data-model.md:94-104`・ADR-002 `:17,55` が、01 の確定内容（組織単位・メンバー全員で枠共有。契約プラン別上限は未定義。複数所属は範囲外で作成先規則は未規定）および 01 のコード変更後の実装と一致している。`frontend/e2e/smoke/README.md:121` から「ユーザー農場」の表現が消え、skip 理由の文字列（`operation-smoke.spec.ts:168`）の引用は変わっていない。§0.2 の Q1〜Q7 がすべて処理済み（Q7 は追随不要を確認済み）。
8a. ドキュメント中に実在しない識別子 `CropCreateLimitPolicy` が残っていない（`rg 'CropCreateLimitPolicy' docs ARCHITECTURE.md` が、履歴文書（`docs/spec-defects/`、`docs/migration/`）を除いて 0 件）。

ADR・設計文書の追随（ステップ 8。**10 の P11・P12・P14 の回答後**、10 の縮小実装と同一リリースまたは直後）の完了条件:

8b. ADR-003 が `docs/adr/` に存在し、ADR-002 の Status・`:54`・`:67`・`:127` から参照されている（参照先が存在しない状態を作らない）。ADR-002 の本文の Decision は書き換えていない。
8c. ADR-002 の実装状況表（`farm_policy.rs` / `ReferenceRecordAccessFilter`）が、10 の縮小後の状態（編集は policy のみ。閲覧は P14 の回答どおり）と一致している。
8d. `organization-data-model.md` の `:39-41`・`:51`・`:114` が ADR-003 と矛盾しない（owner / admin も他メンバーの行は編集できない旨、Plan は組織共有しない旨）。`docs/README.md` の ADR 一覧に ADR-003 がある。

課題 02 の追随（ステップ 9）:

8e. 02 の実装後、§2.3 のヘルスのキーの記述が実装（`captcha_configured` に改名した場合は新キー）と一致している。docs 側（`docs/spec-defects/` を除く）に reCAPTCHA の記述が無い（§0.4）。

案 B 採用時の追加条件:

9. `docs/` 配下の切れリンクを検出するテストが追加され、修正前の master では RED、修正後は GREEN になる。新規スクリプト・新規ワークフローが増えていない。

---

## 9. 関連課題との依存

| 課題 | 関係 | 内容 |
|------|------|------|
| 01 resource-limit-bypass | **依存（本課題が待つ側）。決定は確定済みで、残るのはコード変更（実装）への従属** | 01 は組織単位・メンバー全員で枠共有を確定（D-1〜D-3、D-5）し、複数所属は範囲外（D-4）とした。Q1〜Q7 と `frontend/e2e/smoke/README.md:121` は反映対象（§0.2）。**01 のコード変更（01 §7 ステップ 4・5。plan-save の組織化）と同一 PR またはその後**に本課題のステップ 7 を実行する。01 の U3（`ARCHITECTURE.md` の更新先）は、本書が担当する前提（01 の推奨と一致）。01 は §11 などで本書の行番号（`09-stale-design-docs.md:246-252`、`:242,254,396` ほか）を引いているが、§0 の追加で行番号がずれたため、01 の改訂時に本書の §0.2・§3.2 へ向け直す（01 は本書の編集範囲外）。01 §11 が「09 側で判断」とした `frontend/e2e/smoke/README.md:121` は、本書で更新対象に「含める」と決定した |
| 02 contact-recaptcha | 弱い関連（docs 上の更新は無い）。Turnstile への方針変更は反映済み | 02 は CAPTCHA を Cloudflare Turnstile に置換する（D-1〜D-3）。`docs/`（`spec-defects` を除く）に reCAPTCHA の記述は 0 件で、更新対象は本書 §2.3 のヘルスキー（`recaptcha_configured`。02 の Q7 で `captcha_configured` に改名されうる）の記述のみ（§0.4）。02 から本書へ渡す事項: キーの改名の採否（Q7）。本書から 02・08 へ渡す事項: `docs/api/openapi.yaml` に `contact_messages` が無いこと（§0.4 T4） |
| 03 api-key-scope-docs | 編集対象が重ならない | 03 の対象は `docs/api/getting-started.md`。本課題の編集ファイルと重複しない。リンク検査では `docs/api/` に切れなし |
| 04 api-key-query-auth | 依存なし | 未確認。本課題の編集ファイルと重複しない |
| 05 fail-closed-critical / 06 fail-closed-suspected | 競合の可能性（小） | `ARCHITECTURE.md` の fail-closed 節（`:69-73`、`:106-110`）を両課題が編集する可能性がある（各課題の内容は未読・未確認）。本課題は `ARCHITECTURE.md:90-91`（Resource Limits）と、U2 を含める場合は `:9,16` のみを触るため、行は離れている。同一ファイルへの同時 PR は rebase を要する |
| 07 frontend-error-contract | 依存なし | 未確認 |
| 08 openapi-gaps | 弱い依存 | `docs/api/openapi.yaml` に `organizations` の定義が無い（`rg` 0 件）。ADR-002 `:72-78` の API 形状は実装済み（`organizations.rs:44-60`）だが公開仕様書に無い。08 が追加したら、ADR-002 の References に openapi の該当箇所を足す（任意） |
| 10 authorization-consistency | **依存が強まった（ADR・data-model の追随が 10 の決定に従属）** | 10 の第 2 回・第 3 回決定（Plan の組織共有の撤回、Farm / Crop の組織スコープ編集も所有者のみ）は ADR-002 `:54`・`:67` と食い違い、**新 ADR（ADR-003）を推奨**する（§0.3。10 の P11 (b) と一致）。ADR-003 の起票は 10 のステップ 10 の担当で、P11・P12・P14 の回答待ち。本書はその後に ADR-002 の参照追記（4b）と `organization-data-model.md` の追随（ステップ 8）を担当する。10 の縮小と同一リリースまたは直後に出す。ADR-002 §4（`:62-69`）の記述と実装の機構差（A7）は、10 の縮小後の状態で書く（4b）。実装側で気付いた不一致として `organization_access_policy.rs:80-82` の doc コメント（「Only `owner` may update org settings」）と実装（`owner` **または** `admin` を許可）が食い違う。これはコード側なので 10 に引き継ぐ |
| 11 low-priority-misc | 関連（引き継ぎ候補） | `crates/` の `Ruby:` コメント（901 ファイル・1483 件、§2.5）、U2（Rails shell 記述）、`.cursor/` 側の `composition.rs` 参照（§7）、`.cursor/skills/dev-docker/SKILL.md:77-94` の存在しない `rails-up.sh` 参照（`ls` で確認） |

### 実施順の目安

1. 依存なしのステップ 1〜5（並行可）
2. チェッカ拡張（案 B、採用時。1・2 の後）
3. 01 のコード変更（plan-save の組織化）と同一 PR またはその後にステップ 7（決定は確定済み）
4. 10 の P11・P12・P14 の回答と縮小実装に合わせてステップ 8（ADR-003 の起票は 10 の担当）
5. 02 の実装後にステップ 9（確認のみ）
