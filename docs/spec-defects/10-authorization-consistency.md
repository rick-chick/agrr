# 10: 認可判定の一貫性（user_id のみ / 組織スコープ / 公開）と R0 違反

本書は**対応計画のみ**であり、コード・テスト・他文書の修正は含まない。記載する事実は 2026-09-29 時点のリポジトリ（`master` を基点とするワーキングツリー）を実際に読んで確認したものだけで、`file:line` を付ける。読んでいない・実行していない・本番データに依存するものは「未確認」と明記する。日数・週数の見積りは記載しない。

参照した規約: [`ARCHITECTURE.md`](../../ARCHITECTURE.md)、[`docs/architecture/LAYER-RULES.md`](../architecture/LAYER-RULES.md)（R0: Policies が認可を決め、Gateways は認可しない）、[`ADR-002`](../adr/ADR-002-organization-multi-tenancy.md)、[`organization-data-model.md`](../design/organization-data-model.md)、[`tdd-on-edit`](../../.cursor/skills/tdd-on-edit/SKILL.md)、[`test-common`](../../.cursor/skills/test-common/SKILL.md)、[`evidence-before-design-and-implementation.mdc`](../../.cursor/rules/evidence-before-design-and-implementation.mdc)、[`ca-violation-fix-architecture-gate.mdc`](../../.cursor/rules/ca-violation-fix-architecture-gate.mdc)。

**改訂（第 2 回決定の反映）**: 第 2 回決定（§0）により、組織メンバーに他メンバー所有 Plan の**閲覧も許さない**ことになった。第 1 回の推奨（旧 P1: 閲覧のみ許して一貫させる）は採らない。組織スコープ判定を Plan 系から外し、Plan とその配下は所有者のみとする。追加した事実（縮小対象の全数、組織スコープ判定の利用箇所、データ影響、テストと文書）は、実際にコードを読み `rg` で確認したものだけを `file:line` 付きで記載し、読んでいないものは「未確認」とする。

課題は次の記号で参照する。

| 記号 | 内容 |
|------|------|
| D1 | Crop AI upsert のアダプターが認可を評価している（R0 違反） |
| D2 | 私有 Plan の REST 認可が `private(user_id)`（所有者のみ）で、組織スコープ経路と混在している（**決定により所有者のみが正**。`data` / `climate_data` の 404 は仕様どおりとして確定。混在の解消は D7 の縮小で行う） |
| D3 | 削除 undo の予約認可（`schedule_allowed`）は所有者のみ判定で、本番未配線。削除側（組織スコープ）との非対称は、削除側の縮小で解消する |
| D4 | 公開 Plan の無認証読み取り（設計どおりの可能性） |
| D5 | 認証済みユーザーが私有ルート経由で公開 Plan の圃場栽培を更新できる（調査中に新規発見） |
| D6 | Masters 系の user_id のみ判定と組織スコープ判定の混在（網羅表） |
| D7 | **過剰許可の是正**: 組織メンバーに他メンバー所有 Plan の**編集・閲覧**を許している経路を、所有者のみへ縮小する（§0 の第 1 回・第 2 回決定から派生）。編集系は S1〜S7、閲覧系は V1〜V11（§2.9） |

---

## 0. 決定事項

### 第 1 回決定（編集は与えない）

| 項目 | 内容 |
|------|------|
| 決定 | **組織メンバーに、他メンバーが所有する Plan の編集権限を与えない**。組織メンバーに許す場合でも**閲覧のみ**とする（または共有しない）。過剰許可を避ける厳格側に倒す。**「閲覧のみ許す」の部分は第 2 回決定で覆された（下記）** |
| 決定の由来 | ユーザー指示の「**与えない**」を解釈した結果である（[`README.md`](README.md) の決定事項表にも記載）。この語には 2 通りの解釈があり、本書は **(b)** を採る。ユーザーの意図が (a) だけであった場合は、本節と D7 を差し替える |
| 解釈 (a)（本書では採らない） | API キーに書き込みスコープを与えない。[`03-api-key-scope-docs.md`](03-api-key-scope-docs.md) で扱う |
| 解釈 (b)（本書で採用） | 組織メンバーに他メンバー所有 Plan の編集権限を与えない |
| 適用範囲 | **Plan とその配下の編集**（圃場・作物の追加削除、adjust、削除、作業実績、タスクスケジュール、分散学習の更新系）。Farm / Crop / Masters の組織編集は決定の文言に含まれないため対象外とし、§3.1 P9 でユーザー確認に残す |
| 例外の扱い | `admin`（システム管理者）の扱いは決定に含まれない。§3.1 P3 で確認する（ADR-002 §4 は admin の全 org 横断を想定） |
| 影響 | §2、§3、§5〜§9 を本決定に沿って改訂した。D2 は「組織メンバーにも許す」方向へ揃えない。D3 は所有者のみ判定を正とする。D7 を新設し、既に組織メンバーへ編集を許している経路を縮小対象として洗い出した |

### 第 2 回決定（閲覧も許さない）

| 項目 | 内容 |
|------|------|
| 決定 | **組織メンバーに、他メンバーが所有する Plan とその配下（field_cultivation、task_schedule、work_record、写真、climate、分散学習ほか）の閲覧も許さない**。Plan 系のアクセス（閲覧・編集・削除・ジョブ投入・購読）は**所有者のみ**とする |
| 決定の由来 | ユーザー指示「**閲覧も許さない**」を、第 1 回決定（組織メンバーに Plan の編集を与えない）への上乗せとして解釈した結果である（[`README.md`](README.md) の「決定事項（第 2 回）」にも同旨を記載）。**文脈からの解釈**であり、指示が Plan 以外（Farm / Crop など）の閲覧まで指す意図であった場合は、本節と D7 の範囲を差し替える |
| 前回推奨の扱い | 第 1 回改訂の推奨（旧 §3.1 P1 の (a): 組織メンバーに閲覧のみ許して `data` と `climate_data` まで一貫させる）は**採らない**。旧 P1 の (b)（閲覧も許さない）を採用したことになる。旧推奨に基づく記述（`data` を組織対応にする案、閲覧用と編集用の判定の分離、閲覧経路の維持）は撤回した |
| 適用範囲 | Plan とその配下のみ。Farm / Crop / Masters の組織スコープ判定は決定の文言に含まれないため**範囲外**とし、§3.1 P9 の未決のままにする（§2.9.3 に Plan 系と Plan 以外の利用箇所を分けて列挙） |
| 例外の扱い | `admin` の扱いは**未決のまま**（§3.1 P3）。ただし Plan 系の共通ポリシー `private_cultivation_plan_access_policy::access_denied` は `admin` を見ないため（`private_cultivation_plan_access_policy.rs:8-24`）、縮小後も admin は所有者以外の Plan に入れない現状と変わらない。admin を許すのは field_cultivation のポリシーだけである（`plan_field_cultivation_access.rs:8-24`） |
| D2 の確定 | `GET /api/v1/plans/cultivation_plans/{id}/data` と圃場栽培の `climate_data` が組織メンバーに 404 になる現状（`cultivation_plans.rs:75`、`plan_field_cultivation_access.rs:8-24`）は**仕様どおり**として確定する。組織対応にする案は撤回 |
| 影響 | D7 に「閲覧系」を追加した（V1〜V11、§2.9.2）。組織スコープ判定を Plan 系から**取り除く**（縮小後は Plan 系で `member_organization_ids` を解決しない）。課題 01 の `cultivation_plans.organization_id` backfill 拡張は Plan 系では不要になる（§3.3）。ADR-002 の「Plan の共有」と食い違うため、ADR の更新または新 ADR が要る（§3.3） |

**旧推奨（P1 (a)）を覆す理由**: 第 1 回改訂では「現状すでに一覧・詳細・タイムライン・作業実績一覧を組織メンバーに許している」ことを閲覧を許す根拠にした。第 2 回決定はその現状自体を過剰許可として是正する指示であり、根拠の前提が変わった。

### 決定の帰結

決定は「Plan 系は所有者のみ」を**正**とする。したがって、`private_with_scope`（組織メンバー許可）と、組織 ID を受け取る `access_denied` / `access_allowed` を通る経路は、閲覧・編集を問わず**すべて不適合**であり、`private(user_id)`（所有者のみ）の経路は適合である。ただし、ADR-002 と #612 のコミットは組織単位の Plan 共有を意図しており（§2.3）、今回の決定は #612 が導入した Plan の組織共有そのものの**撤回**にあたる。

---

## 1. 概要と重大度

### 概要

ADR-002 の #612（Farm / Crop / Plan の組織スコープ認可、コミット `e020f1c66`）は、認可を「user_id 一致」から「user_id または所属組織一致」へ移す段階移行である。調査の結果、同じ Plan に対して経路ごとに判定方式が異なることを確認した。§0 の第 2 回決定により、**Plan 系は閲覧・編集を問わず組織スコープで許可されている経路がすべて是正対象**になる（判定方式を揃える方向は「所有者のみ」である）。

- Plan の `data` 取得、`add_crop` / `add_field` / `remove_field` / `adjust` は `CultivationPlanRestAuth::private(user_id)` で組織 ID を空にして判定する（`cultivation_plans.rs:75`、`cultivation_plans_mutations.rs:320,440,546,751`）。合計 5 箇所すべてが所有者のみで、**決定どおり（適合）**である。`data` の 404 は仕様どおりとして確定した（D2）。
- Plan の削除・作業実績（作成・更新・削除・写真）・タスクスケジュールの変更系・分散学習の更新系は組織スコープで**編集を許している**（S1〜S7、§2.9.1）。決定と不整合であり、D7 として縮小対象にする。
- Plan の一覧・詳細・タイムライン・作業実績一覧・写真ダウンロード・予実・分散学習の取得・天候リスケ提案の一覧・分散ポートフォリオ・Cable 購読・carryover の元 Plan は、組織スコープで**閲覧を許している**（V1〜V11、§2.9.2）。第 1 回決定では整合としていたが、**第 2 回決定により不整合**となり、縮小対象に加わった。
- 圃場栽培（field_cultivation）の認可スナップショットには `organization_id` が無く、私有 Plan は user_id（と admin）のみで判定する（§2.5）。閲覧・編集とも決定に適合する。

これとは独立に、次の 2 点を確認した。

- **D1**: `crop_ai_upsert_sqlite_persistence.rs:195` で、アダプターが `assert_edit_allowed` を呼ぶ。R0 の直接違反である。
- **D5**: 私有ルート `PATCH /api/v1/plans/field_cultivations/{id}` で、公開 Plan の圃場栽培が「認証済みユーザーなら誰でも更新可」になっている。公開 Plan のセッション検証（`X-Public-Plan-Session`）を私有ルートで迂回できる。コード読解のみで確認しており、実行による再現は未実施（§6 の RED で再現する）。

### 重大度

| 課題 | 重大度 | 種別 | 理由 |
|------|--------|------|------|
| D5 | **高（最優先）** | 過剰許可（他者データの改変） | 認証済みの任意ユーザーが、他人が作った公開 Plan の圃場栽培の日付を更新できる（コード読解による）。公開 Plan の ID は連番（§2.4）で列挙可能 |
| D7 | 中〜高 | 過剰許可（組織メンバーによる他メンバー Plan の閲覧・編集・削除） | Plan の閲覧（一覧・詳細・タイムライン・作業実績・写真・予実・分散学習・Cable ほか）と、削除・作業実績・タスクスケジュール・分散学習の更新が、組織メンバーに許可されている（§2.9）。ただし本番の Plan INSERT が `organization_id` を書かないため、通常フローでは顕在化しにくい。一方、**組織メンバー追加 API に personal org のガードが無い**ため、personal org の所有者が他ユーザーをメンバーに追加すれば、backfill 済みの Plan が共有される経路がコード上は存在する（§2.3、実行での再現は未実施） |
| D2 | 低（方針確定） | 現行の `private(user_id)` は**仕様どおり**（閲覧を含む） | `data` 取得と編集系 4 箇所は変更不要。`data` / `climate_data` の 404 も仕様どおりとして確定（§0 第 2 回決定） |
| D6 | 中〜低 | 過少許可（fail-closed）または対象外 | Crop のネスト Masters（害虫・農薬・ステージ）が組織メンバーに 404。Pest 等の Tier 1 拡張は ADR-002 の #612 スコープ外。編集の拡大を伴うため、決定の精神（厳格側）と照らして推奨を見直した（§3.1 P4） |
| D1 | 中 | 規約違反（R0）＋意図しないフォールスルー | 認可拒否が「作成」に化ける。対象 API は非推奨で、2026-10-18 に廃止予定（#323） |
| D3 | 低 | 規約違反・未配線 | 本番コードから `DeletionUndoScheduleInteractor` を生成する箇所を確認できなかった。削除側の縮小（D7）で非対称も解消する |
| D4 | 低（情報） | 設計どおりの可能性が高い | 共有リンク前提。列挙可能性は実在するが、読み取りは公開 Plan に限られる |

過剰許可（D5、D7）の修正が優先である。過少許可（D2 の `data` 取得、D6 の Crop ネスト Masters）は**緩める方向の修正を行わない**（§0 の第 2 回決定により、Plan 系で組織メンバーへ許す方向の変更は無い。Crop ネスト Masters は Plan ではないため P4 の (b) 現状維持のまま）。

---

## 2. 現状（確認済み事実）

### 2.1 D1: Crop AI upsert のアダプター内認可

| 事実 | 根拠 |
|------|------|
| アダプターが `reference_record_authorization` を import している | `crates/agrr-adapters-sqlite/src/crop/crop_ai_upsert_sqlite_persistence.rs:20` |
| `find_existing_crop_for_update` が `gateway.find_by_id` で取得後、`reference_record_authorization::assert_edit_allowed(access_filter, &entity).ok()?` を呼ぶ。拒否は `None` になる | 同 `:186-197`（呼び出しは `:195`） |
| 拒否（`None`）のとき、更新ではなく新規作成へ進む。エラーにも Forbidden にもならない | 同 `:114-135` の `if let Some(existing_id)` / `else create_new_crop`（`update_existing_crop` `:199`、`create_new_crop` `:235`）。更新失敗は 503（`ServiceUnavailable`）に写像される（`:129-131` 付近） |
| 更新経路は `User::new(0, false)` のダミー User で `gateway.update_for_user` を呼ぶ | 同 `:220-221` |
| `CropGateway::update_for_user` は `_user` を使わず、`expected_updated_at` を必須とする | `crates/agrr-adapters-sqlite/src/crop/crop_gateway.rs:218-234` |
| 作成上限の判定（`crop_create_limit_policy::limit_exceeded`）もアダプター内で行う。これも業務ルールのアダプター内評価で、同じ R0 系統の違反 | `crop_ai_upsert_sqlite_persistence.rs:152-184`（判定は `:177`） |
| 呼び出し元 interactor は `record_access_filter_for_user` でフィルターを作り、永続化ポートに**渡すだけ**で評価しない | `crates/agrr-domain/src/crop/interactors/crop_ai_create_interactor.rs:90-91` |
| ポート署名に `access_filter: ReferenceRecordAccessFilter<CropRecordAccessPolicy>` が含まれる（フィルターがアダプターへ漏れている） | `crates/agrr-domain/src/crop/ports/crop_ai_upsert_persistence_port.rs` |
| 準拠例: Pest AI 更新は interactor が `load_authorized_pest_entity` で取得後に policy を評価する | `crates/agrr-domain/src/pest/interactors/pest_ai_update_interactor.rs:149-153` |
| 準拠例: Fertilize AI 更新も同型 | `crates/agrr-domain/src/fertilize/interactors/fertilize_ai_update_interactor.rs:185-187` |
| ルートは `ai_api.rs:50`、アダプター配線は `ai_api.rs:158` | `crates/agrr-server/src/ai_api.rs` |
| 組み込み生成 API は非推奨。廃止予定は 2026-10-18（#323） | `crates/agrr-server/src/builtin_generation_deprecation.rs:9-15`、`docs/api/builtin-generation-sunset.md:3,67-68` |
| 既存テストは作成と失敗のみ。更新・認可拒否のテストは無い | `crop_ai_upsert_sqlite_persistence.rs:629,663`（アダプター）。ドメイン側の既存フェイクは `crates/agrr-domain/test/crop/interactors_crop_ai_create_interactor_test.rs` |
| アダプター内の `record_access_filter(user, vec![])` はテストコード内のみ（本番で空スコープを渡しているわけではない） | `crop_ai_upsert_sqlite_persistence.rs:653,676` |

**未確認**: AI 更新経路が `expected_updated_at` を渡さないため、`update_for_user` が常に stale エラーになる疑い（`crop_gateway.rs:218-234` の必須引数と `update_existing_crop` `:199-233` の入力構成からの推測。実行での再現は未実施）。

### 2.2 認可判定の経路マトリクス

判定方式の凡例: **user_id** = 所有者一致（と admin）のみ。**org** = 所有者一致または所属組織一致（`organization_member_access`、`org_scope.rs:13-23`）。**public** = 認証なしまたはセッショントークン。

**方針適合の凡例**（§0 の第 2 回決定「組織メンバーに他メンバー所有 Plan とその配下の閲覧も編集も許さない。Plan 系は所有者のみ」に対する判定。第 1 回改訂の「適合（閲覧）」「適合（閲覧・要確認）」は廃止した）:

| 値 | 意味 |
|----|------|
| 適合 | 決定に沿っている（Plan 系は所有者のみ。公開 Plan の設計どおりの経路を含む） |
| **不適合（過剰許可・編集）** | 編集・削除・ジョブ投入など変更系を組織メンバーに許している。縮小対象（D7 の S 系） |
| **不適合（過剰許可・閲覧）** | 閲覧・取得・購読を組織メンバーに許している（第 2 回決定で不適合になった）。縮小対象（D7 の V 系） |
| **不適合（R0）** | 認可をアダプターが評価している（D1） |
| **不適合（過剰許可・公開）** | 公開 Plan を認証済みの誰でも編集できる（D5） |
| 未配線 | 本番から到達しない。到達する状態にする場合は不適合になり得る |
| 対象外 | Plan ではないため決定の適用範囲外（§0） |

| エンドポイント / 機能 | 判定方式 | 方針適合 | 根拠 |
|-----------------------|----------|----------|------|
| `GET /api/v1/plans/cultivation_plans/{id}/data`（読み取り） | **user_id**（組織 ID 空） | **適合（確定）**。組織メンバーに 404 になる現状は仕様どおり（D2、§0 第 2 回決定） | ルート `cultivation_plans.rs:24-27`、`CultivationPlanRestAuth::private(user_id)` `:75` |
| `POST .../{id}/add_crop` | **user_id** | **適合（正）** | `cultivation_plans_mutations.rs:320`（ルート `:60-63`）。なお add_crop の作物解決は scope gateway を使う（`add_crop_support.rs:32,126`）ため、Plan 認可と作物解決で方式が異なる。Plan 認可は所有者のみなので方針に影響しない |
| `POST .../{id}/add_field` | **user_id** | **適合（正）** | `cultivation_plans_mutations.rs:440`（ルート `:48-51`） |
| `DELETE .../{id}/remove_field/{field_id}` | **user_id** | **適合（正）** | `cultivation_plans_mutations.rs:546`（ルート `:52-55`） |
| `POST .../{id}/adjust` | **user_id** | **適合（正）** | `cultivation_plans_mutations.rs:751`（ルート `:56-59`）。interactor は `rest_plan_access` を評価（`plan_allocation_adjust_interactor.rs:107-114`） |
| 天候リスケ提案の一覧（読み取り） | **org** | **不適合（過剰許可・閲覧）**（V8） | `weather_reschedule_proposals_list_interactor.rs:53-55` |
| 天候リスケ提案プレビュー（adjust の dry-run） | 上流は **org**、下流の adjust で **user_id** の `private(self.user_id)` を再構成 | **不適合（過剰許可・編集）**: 上流ゲートが組織メンバーに許している。ただし下流で 404 になるため、現状の実効は所有者のみ | `weather_reschedule_proposal_preview_interactor.rs:126-135`（org 判定）、`:175`（`private(self.user_id)`）。dry-run は永続化しない（`plan_allocation_adjust_interactor.rs:776-786`）が、adjust と同一の最適化を実行する |
| Plan 削除 | **org** | **不適合（過剰許可・編集）** | `cultivation_plan_destroy_interactor.rs:66-69`（`member_organization_ids` → `assert_private_owned`）。ルート `plans.rs:51-52` |
| 私有 Plan 詳細（読み取り） | **org** | **不適合（過剰許可・閲覧）**（V2） | `private_owned_plan_detail_interactor.rs:75-77` |
| 私有 Plan 一覧（読み取り） | **org**（SQL の org サブクエリ） | **不適合（過剰許可・閲覧）**（V1） | `crates/agrr-adapters-sqlite/src/cultivation_plan/private_read_gateway.rs:32-34` |
| Cable の Plan 購読（受信のみ。`PlansOptimizationChannel` は `private_with_scope`、`OptimizationChannel` は `access_denied` に組織 ID を渡す） | **org** | **不適合（過剰許可・閲覧）**（V10） | `cable_subscription_auth.rs:31-34,40-47`。スコープ解決は `cable.rs:403-407`（`unwrap_or_default`＝解決失敗は空スコープ＝fail-closed） |
| Cable の Farm 購読（受信のみ） | **user_id**（`farm_policy::view_allowed` に組織 ID 無し） | 対象外（Farm、閲覧のみ） | `cable_subscription_auth.rs:59` |
| タスクスケジュール: timeline 取得（読み取り） | **org** | **不適合（過剰許可・閲覧）**（V3） | `task_schedule_timeline_interactor.rs:67-69`、ルート `task_schedules.rs:44-45` |
| タスクスケジュール: item 作成 | **org** | **不適合（過剰許可・編集）** | `task_schedule_item_create_interactor.rs:48-49`、ルート `task_schedules.rs:56-57` |
| タスクスケジュール: item 更新 | **org** | **不適合（過剰許可・編集）** | `task_schedule_item_update_interactor.rs:80-81`、ルート `task_schedules.rs:60-61` |
| タスクスケジュール: item skip / unskip | **org** | **不適合（過剰許可・編集）** | `task_schedule_item_skip_interactor.rs:50-51,69-70`、ルート `task_schedules.rs:48-53` |
| タスクスケジュール: regenerate（最適化ジョブの投入） | **org** | **不適合（過剰許可・編集）** | `regenerate_task_schedule_interactor.rs:44-45`、ルート `task_schedules.rs:64-65` |
| タスクスケジュール: item 削除の undo 予約 | **org** | 未配線（本番から生成する箇所が無い。§2.6）。配線するなら不適合 | `task_schedule_item_schedule_deletion_undo_interactor.rs:55-56` |
| 作業実績: 一覧（読み取り） | **org** | **不適合（過剰許可・閲覧）**（V4） | `work_record_list_interactor.rs:49-50`、`work_record/interactors/private_plan_access.rs:11-17` |
| 作業実績: 作成・更新・削除 | **org** | **不適合（過剰許可・編集）** | `work_record_create_interactor.rs:69-70`、`work_record_update_interactor.rs:64-65`、`work_record_destroy_interactor.rs:52-53`。ルート `work_records.rs:36-41` |
| 作業実績の写真: upload_init / upload_complete / destroy / upload_content | **org** | **不適合（過剰許可・編集）** | `work_record_photo_upload_init_interactor.rs:62-63`、`work_record_photo_upload_complete_interactor.rs:67-68`、`work_record_photo_destroy_interactor.rs:53-54`、`work_record_photos.rs:332`（`upload_content`）。ルート `work_record_photos.rs:40-53` |
| 作業実績の写真: download（読み取り） | **org** | **不適合（過剰許可・閲覧）**（V5） | `work_record_photos.rs:426` |
| 予実サマリー・分散学習の取得（読み取り） | **org** | **不適合（過剰許可・閲覧）**（V6、V7） | `plan_vs_actual_summary_interactor.rs:68-70`、`plan_variance_learning_read_interactor.rs:64-66` |
| 分散学習の更新（proposal / orchestration / handoff の PATCH） | **org** | **不適合（過剰許可・編集）** | `plan_variance_learning_proposal_progress_update_interactor.rs:48-50`、`plan_variance_learning_orchestration_progress_update_interactor.rs:48-50`、`plan_variance_learning_handoff_update_interactor.rs:48-50`。ルート `plan_variance_learning.rs:46-50`、ハンドラー `:297` |
| 分散学習の reoptimize（最適化ジョブの投入） | **org** | **不適合（過剰許可・編集）** | `plan_variance_learning_reoptimize_interactor.rs:51-52`。ルート `plan_variance_learning.rs:53-54` |
| 分散学習の import（`POST variance_learning`）／Plan 作成時の carryover | 対象 Plan（書き込み先）と元 Plan（読み取り元）を **org** で判定 | 書き込み先: **不適合（過剰許可・編集）**（S4）。元 Plan の読み取り: **不適合（過剰許可・閲覧）**（V11） | `plan_variance_carryover_interactor.rs:90-97`（書き込み先）、`:99-105`（読み取り元）、`:120`（`save`）。ハンドラー `plan_variance_learning.rs:395-431`、`run_carryover_after_create` `:598-629`、`plans.rs:401-402` |
| 分散ポートフォリオ（読み取り） | 行の取得は `list_private_plan_index_rows_by_user_id`（**名称に反して SQL が組織サブクエリを含む**。V1 と同一 SQL）、各行も org で再確認 | **不適合（過剰許可・閲覧）**（V9）。第 1 回改訂の「user_id のみで取得し他メンバーの Plan は列挙されない」は誤りだったため訂正する | `variance_portfolio_interactor.rs:81-86`（取得）、`:113-118`（`task_schedule_private_plan_access::access_allowed` に `org_ids`）、SQL は `private_read_gateway.rs:32-34` |
| 作業ハブ読み取り | **user_id**（SQL が `f.user_id = ?1`、`cp.user_id = ?1`） | 適合（所有者のみ） | `crates/agrr-adapters-sqlite/src/work_record/work_hub_read_gateway.rs:36,42` |
| `GET/PATCH /api/v1/plans/field_cultivations/{id}`（私有 Plan） | **user_id** | **適合（正）**（閲覧・編集とも所有者と admin のみ。`climate_data` が組織メンバーに 404 になるのも仕様どおり） | ルート `field_cultivations.rs:29-34`、`plan_field_cultivation_access.rs:8-30`、`FieldCultivationPlanAccessSnapshot` に `organization_id` 無し |
| `GET/PATCH /api/v1/plans/field_cultivations/{id}`（**公開** Plan） | **user_id**（＋**公開 Plan は誰でも許可**） | **不適合（過剰許可・公開）**（D5） | 同上、`plan_field_cultivation_access.rs:8-24` |
| `PATCH` 公開版 field_cultivation | **public**（セッション一致） | 適合 | `field_cultivations.rs` の公開ルート、`plan_field_cultivation_authorization.rs`（`assert_public_field_cultivation_mutation_access`） |
| `GET /api/v1/public_plans/cultivation_plans/{id}/data` | **public**（認証なし、セッション不要） | 適合（公開の閲覧） | `public_plans.rs:62-65,578-590` |
| 公開 Plan の adjust ほか変更系 | **public**（セッションヘッダ／Cookie 一致） | 適合 | `public_plan_session.rs:22-25`、`rest_plan_access.rs:31-40` |
| Masters: Crop CRUD | **org** | 対象外（Crop。P9 で確認） | `shared/policies/crop_policy.rs`（`record_access_filter_for_user`、`view/edit_allowed`）、`crop_ai_create_interactor.rs:90` |
| Masters: Farm CRUD | **org** | 対象外（Farm。P9 で確認） | `shared/policies/farm_policy.rs:31,36,40` |
| Masters: Crop のネスト（害虫・農薬・ステージ） | **user_id**（空スコープ） | 対象外（所有者のみで、決定より厳格） | `crop/policies/crop_masters_nested_access.rs:12`、`pesticide/policies/crop_masters_nested_access.rs:12`、`masters_crop_context.rs:19-46` |
| Masters: Field | **user_id**（農場所有者経由、空スコープ） | 対象外（所有者のみ） | `field/policies/field_access.rs:21,26`、`field_create_interactor.rs:48` |
| Masters: Pest / Pesticide / Fertilize / AgriculturalTask / InteractionRule | **user_id**（空スコープ） | 対象外（所有者のみ） | §2.7 の表 |
| Crop AI upsert の認可 | アダプターが org フィルターで評価 | **不適合（R0）**（D1） | `crop_ai_upsert_sqlite_persistence.rs:195` |
| 削除 undo の予約（汎用） | **user_id**（`plan_user_id` / `user_id` 一致のみ） | **適合（正）**、ただし未配線 | `deletion_undo/schedule_authorization.rs:34-60` |
| 削除 undo の復元 | トークンのみ（認可判定なし） | 対象外（トークン保持者のみ。§2.6 の注意を参照） | `crates/agrr-server/src/deletion_undo.rs:22,68-88`（`POST /undo_deletion`） |

### 2.3 D2: `CultivationPlanRestAuth::private(user_id)` と組織スコープ

| 事実 | 根拠 |
|------|------|
| `CultivationPlanRestAuth` は `private`（組織 ID 空）、`private_with_scope`（組織 ID あり）、`public`、`public_mutation` を持つ | `crates/agrr-domain/src/cultivation_plan/dtos/cultivation_plan_rest_auth.rs:19-36` |
| `rest_plan_access::evaluate` は Private のとき `private_cultivation_plan_access_policy::access_denied(plan, user_id, &auth.member_organization_ids)` を呼び、拒否は `NotFound`（404）にする。**閲覧と編集の区別は無い** | `crates/agrr-domain/src/cultivation_plan/interactors/rest_plan_access.rs:17-45` |
| `access_denied` は「私有でない→拒否」「`plan.user_id == user_id` →許可」「`organization_member_access(member_organization_ids, false, plan.organization_id)` →許可」の順で判定する。**閲覧と編集の区別が無く**、組織メンバーには両方を許す | `crates/agrr-domain/src/cultivation_plan/policies/private_cultivation_plan_access_policy.rs:8-24` |
| `assert_private_owned` は名称に反して組織メンバーも許可する（`access_denied` の薄いラッパー） | 同 `:26-37` |
| `private(user_id)` を使う 5 箇所（`data` 1 箇所、編集系 4 箇所）は、`member_organization_ids` が空のため、この policy の第 3 分岐が必ず false になり**所有者のみ**の判定になる | `cultivation_plans.rs:75`、`cultivation_plans_mutations.rs:320,440,546,751`、`cultivation_plan_rest_auth.rs:20-26` |
| #612 の意図: コミットメッセージは「org-scoped authorization for Farm/Crop/Plan」と「Work record and task schedule interactors resolve member org IDs」。**編集を含めて組織メンバーに許す意図が明記されているわけではなく、閲覧と編集を区別する記述も無い** | `git show e020f1c66`（コミットメッセージ） |
| ADR-002 は Farm / Crop / Plan の「共有」を挙げるが、Plan の編集を組織メンバーに許すとは書いていない。ロール（owner / admin / member）は「RBAC のフック」とされ、`OrganizationAccessPolicy`（仮称）は構想のみ | `docs/adr/ADR-002-organization-multi-tenancy.md` の「3. Organization の責務境界」表、「4. アクセス制御の移行方針」 |
| `organization-data-model.md` の `member` ロールの説明は「org 内リソースの CRUD（メンバー管理不可）」。決定はこの設計より厳格側にあたる | `docs/design/organization-data-model.md`（ロール表） |
| ドメインのポリシーテストは組織メンバーの許可を検証済み（閲覧と編集を分けていない） | `crates/agrr-domain/test/cultivation_plan/policies_private_cultivation_plan_access_policy_test.rs:68-93` |
| R4 契約テストで組織 Plan を検証しているのは**閲覧のみ**の 2 件（`org_member_can_view_team_plan`: 組織メンバーが `GET /api/v1/plans/{id}` で 200、`org_non_member_denied_team_plan`: 非メンバーが 404）。組織メンバーによる Plan の削除・作業実績・タスクスケジュールの契約テストは確認できなかった。`seed_org_scoped_plan` の使用箇所もこの 2 件のみ | `crates/agrr-r4-contract/tests/contracts.rs:4306,4332`（Farm / Crop は更新まで検証: `:4157,4242`）、`seed_org_scoped_plan` の使用は `contracts.rs:4323,4347`、定義 `support.rs:1882`。`rg` で確認。テスト本体の全文精読はしていない |
| 作業実績・タスクスケジュール・削除・分散学習の interactor テストは、`EmptyScopeGateway` と `organization_id: None` のフィクスチャのみで、組織メンバーが操作できることを検証していない。Plan 系で組織メンバーの許可を検証している単体テストは、ポリシーのテスト 2 件のみ（`access_denied_false_when_org_member_matches_plan_organization` `:69`、`assert_private_owned_allows_org_member_with_matching_organization` `:89`）。同ファイルの不一致・NULL 組織の拒否テスト（`:76`、`:83`）は縮小後も意味を持つ | `crates/agrr-domain/test/work_record/interactors_work_record_update_interactor_test.rs:20`、`.../cultivation_plan/interactors_cultivation_plan_destroy_interactor_test.rs:13,145` ほか（`rg -i org` で確認）、ポリシーは `policies_private_cultivation_plan_access_policy_test.rs:68-93` |
| Plan の `organization_id` を書くのは backfill の `UPDATE {table} SET organization_id`（`user_id` 一致かつ NULL の行に personal org を設定）だけで、非テストの INSERT（`cultivation_plan_gateway.rs:54-57`、`plan_save_plan_copy.rs:105-107`）は書かない。`rg "INSERT INTO cultivation_plans"` の他のヒットはテスト・フィクスチャ | `personal_organization_sqlite_gateway.rs:114-136`（`:81` で呼び出し）。`organization_id =` の代入を `rg` で確認。削除 undo の復元がスナップショットの列（`SELECT *`）を戻す点は未精査 |
| 個人組織の backfill は OAuth ログイン・Farm / Crop 作成・バックドア・起動時に走る | `omniauth_session.rs:68`、`farm_create_interactor.rs:76`、`crop_create_interactor.rs:65`、`backdoor_diagnostics_gateway.rs:172`（詳細は 01 §2.4） |
| Plan 作成の INSERT は `organization_id` を書かない | `crates/agrr-adapters-sqlite/src/cultivation_plan/cultivation_plan_gateway.rs:54-57`、`plan_save_plan_copy.rs:105-107` |
| `organization_id` は personal organization の backfill でのみ埋まる（対象表に `cultivation_plans` を含む） | `personal_organization_sqlite_gateway.rs:29-39`（対象表）。詳細は [`01-resource-limit-bypass.md`](01-resource-limit-bypass.md) §2.4 |
| 組織メンバー追加の interactor は、操作者のロールと付与ロールのみを検査し、対象組織が personal org かどうかを検査しない（メンバーシップ系 interactor に `is_personal` の参照が無い。personal org のガードは削除 interactor のみ） | `crates/agrr-domain/src/organization/interactors/organization_membership_create_interactor.rs:47-97`、`organization_delete_interactor.rs:63`。`rg is_personal` で確認 |

**判定（どちらが正か）**: 第 2 回決定により、**Plan 系は閲覧・編集とも所有者のみが正**である。`private(user_id)` の 5 箇所（`data` と `add_crop` / `add_field` / `remove_field` / `adjust`）は「#612 の適用漏れ」ではなく**仕様どおり**である。したがって**「組織メンバーにも許す」方向への揃えは行わない**。同じ Plan 配下で組織メンバーに閲覧・編集を許している経路（§2.9）が決定と不整合であり、縮小対象になる。

`data` 取得（`cultivation_plans.rs:75`）と圃場栽培の `climate_data`（`plan_field_cultivation_access.rs:8-24`）が組織メンバーに 404 になる現状は**仕様どおり**として確定した。第 1 回改訂で挙げた「一覧・詳細は見えるが Gantt の `data` は 404」という中途半端な状態（`frontend/src/app/adapters/plans/plan-api.gateway.ts:34`、`field-climate-api.gateway.ts:22`）は、`data` を開くのではなく**一覧・詳細側を閉じる**ことで解消する。旧 U13（詳細と `data` の同等性の確認）は、`data` を組織対応にしないため不要になった。

**顕在性（部分的に未確認）**: Plan の INSERT が `organization_id` を書かないため、通常フローで生成された Plan の `organization_id` は backfill による personal org のみと推測される。personal org のメンバーは所有者本人のみのはずだが、組織メンバー追加 API に personal org のガードが無い（上表）ため、所有者が他ユーザーを追加すれば、backfill 済みの Plan は組織スコープの経路（§2.9）で閲覧・編集・削除可能になる。実行による再現は未実施（§6 T7-9 で確認する）。他の org へ Plan を割り当てる経路（管理 UI、SQL、他 API）が存在するかは**未確認**（`organization_id` を Plan に書く非テストコードは backfill だけ、という上表の事実までは確認済み）。既存データへの影響は §4.2、本番確認の SQL は §4.3。

### 2.4 D4: 公開 Plan の無認証読み取り

| 事実 | 根拠 |
|------|------|
| `public_plan_data` は `CultivationPlanRestAuth::public()` で `RetrieveCultivationPlanInteractor` を呼ぶ。ユーザーセッションは見ない | `crates/agrr-server/src/public_plans.rs:578-590`（ルート `:62-65`） |
| `Public` モードの判定は「`plan_type` が公開か」のみ。セッション ID が渡された場合だけ一致検証をする（読み取りは渡さない） | `rest_plan_access.rs:31-40` |
| 変更系は `X-Public-Plan-Session` ヘッダーまたは `public_plan_session` Cookie が `plan.session_id` と一致する必要がある（#1158） | `public_plan_session.rs:22-25`、`rest_plan_access.rs`、`public_plan_session_authorization` |
| ID は `INTEGER PRIMARY KEY AUTOINCREMENT`（連番） | `crates/agrr-migrate/migrations/schema/V1__baseline.sql:93` |
| フロントは共有 URL として `/public-plans/results?planId=<id>` を組み立てる（共有リンクの意図は実装上に存在） | `frontend/src/app/core/seo/public-plan-results-seo-meta.ts`（`buildPublicPlanResultsShareUrl`） |
| 応答には作物・圃場・栽培の内容が含まれる（`workbench_payload.rs:6-27`）。利用者の個人情報を含むかは**未確認**（応答フィールドを個別に精査していない） | `crates/agrr-server/src/workbench_payload.rs:6-27` |
| 公開 Plan の圃場栽培の読み取りも認証なしで許可 | `plan_field_cultivation_authorization.rs`（`assert_public_field_cultivation_plan_access`）、`plan_field_cultivation_access.rs:8-30` |
| 共有リンク前提を明記した ADR・設計文書は確認できなかった（`docs/adr/`、`docs/design/` を対象に読んだ範囲） | **未確認**（全文検索は網羅していない） |
| 列挙対策（レート制限など）は本調査で確認できなかった | **未確認** |

**判定**: 読み取りの無認証公開は、共有リンク機能（フロントの URL 生成）に対応した設計と考えられる。ただし、ID が連番のため、全公開 Plan を列挙して閲覧できる。これは仕様として文書化されていない。**決定との整合**: D4 は読み取りのみで、組織メンバーの編集とは無関係である。決定に抵触しない。

### 2.5 D5: 私有ルートで公開 Plan の圃場栽培を更新できる

| 事実 | 根拠 |
|------|------|
| `PATCH /api/v1/plans/field_cultivations/{id}` は私有ルート（セッション認証あり） | `crates/agrr-server/src/field_cultivations.rs:29-34` |
| ハンドラーは `FieldCultivationUpdateInteractor::with_user` を作り、入力は `public_plan: false`、`public_session_id: None` | 同 `:214-250` |
| interactor は `user_id` と `user_lookup` があれば `assert_field_cultivation_plan_access(&user, &snapshot, true)` を呼ぶ | `crates/agrr-domain/src/field_cultivation/interactors/field_cultivation_update_interactor.rs:71-85` |
| `assert_field_cultivation_plan_access(.., for_edit = true)` は `assert_edit_allowed` へ進み、それは `assert_view_allowed` と同一 | `plan_field_cultivation_authorization.rs`、`plan_field_cultivation_access.rs:28-30` |
| `view_allowed` は**公開 Plan なら無条件で true**。私有 Plan は `admin` または `plan_user_id == user.id` | `crates/agrr-domain/src/field_cultivation/policies/plan_field_cultivation_access.rs:8-24` |
| 公開 Plan の変更に必要なセッション検証（`assert_public_field_cultivation_mutation_access`）は、`else if input.public_plan()` の分岐にあり、`with_user` の私有経路では通らない | `field_cultivation_update_interactor.rs:87-99` |
| 実際の永続化は無条件 UPDATE | `crates/agrr-adapters-sqlite/src/field_cultivation/climate_source_gateway.rs:130-154` |
| スナップショットに `organization_id` が無い（組織メンバーは私有 Plan の圃場栽培を閲覧も編集もできない） | `crates/agrr-domain/src/field_cultivation/dtos/field_cultivation_plan_access_snapshot.rs` |
| 圃場栽培の show / climate_data も同じ `view_allowed` を使う | `field_cultivation_show_interactor.rs`、`field_cultivation_climate_data_interactor.rs:117-160` |
| フロントが使うのは `climate_data` のみ（更新 API は使っていない） | `frontend/.../field-climate-api.gateway.ts:19-22` |

**帰結（コード読解に基づく。実行での再現は未実施）**: 認証済みの任意ユーザーが、所有者でなくても、公開 Plan の圃場栽培の開始日・終了日を更新できる。フロントは更新 API を使わないため、通常の UI 操作では発火しない。API を直接叩ける相手にのみ意味を持つ。

**決定との整合**: 私有 Plan の圃場栽培は所有者と admin のみで編集でき、決定に適合する。D5 の是正で組織メンバーの編集を追加する必要は**無い**（スナップショットに `organization_id` を足さない）。

### 2.6 D3: 削除 undo の予約認可

| 事実 | 根拠 |
|------|------|
| `SchedulableRecord` は `plan_user_id`、`plan_type_private`、`farm_user_id` などを持つが、組織 ID は持たない | `crates/agrr-domain/src/deletion_undo/schedule_authorization.rs:9-18` |
| `TaskScheduleItem`: `user.admin` または（私有 Plan かつ `plan_user_id == user.id`） | 同 `:48-52` |
| `CultivationPlan`: `user.admin` または（私有 Plan かつ `user_id == user.id`） | 同 `:53-57` |
| Farm / Crop / Pest ほかは user_id のみの `edit_allowed(user, is_reference, user_id)`。Field は `farm_user_id` 一致 | 同 `:36-47` |
| 呼び出し元: `DeletionUndoScheduleInteractor::ensure_schedule_authorized` がゲートウェイの `find_schedulable_record` で取得し `schedule_allowed` で判定 | `crates/agrr-domain/src/deletion_undo/interactors/deletion_undo_schedule_interactor.rs:89-101`、ゲートウェイ `deletion_undo_gateway.rs:161-183` |
| 削除側との非対称: Plan 削除 interactor は組織スコープ判定（§2.2）。TaskScheduleItem の undo 予約も組織スコープ判定 | `cultivation_plan_destroy_interactor.rs:66-69`、`task_schedule_item_schedule_deletion_undo_interactor.rs:55-56` |
| 本番コードから `DeletionUndoScheduleInteractor` を生成する箇所は無い（定義・再エクスポート・テストのみ）。`rg DeletionUndoScheduleInteractor` を `crates/` 全体で確認し、テスト（`crates/agrr-domain/test/deletion_undo/interactors_deletion_undo_schedule_interactor_test.rs`）以外に構築箇所は無かった | `crates/agrr-domain/src/deletion_undo/interactors/mod.rs:6`、`deletion_undo/mod.rs:25` |
| `TaskScheduleItemScheduleDeletionUndoInteractor` も本番で生成されていない（定義と再エクスポートのみ） | `cultivation_plan/interactors/mod.rs:82`。`rg` で確認 |
| アダプターの `find_schedulable_record` は `master_table_name` 経由で Pest / Fertilize / Pesticide / AgriculturalTask / InteractionRule の 5 種のみ対応し、`CultivationPlan` / `TaskScheduleItem` / Farm / Crop はエラーになる。取得列も `is_reference, user_id` のみで、`plan_type_private` を埋めない。つまり、仮に配線しても Plan 系の予約認可は動かない | `crates/agrr-adapters-sqlite/src/deletion_undo/deletion_undo_gateway.rs:162-183`、`deletion_undo/schedule.rs:220-229` |
| 実際の削除時の undo 予約は `schedule_destroy` を直接呼ぶ実装 | `crates/agrr-adapters-sqlite/src/deletion_undo/schedule.rs:31,220-229`、`cultivation_plan_gateway.rs:198`、`crop_gateway.rs:351` |
| TaskScheduleItem の削除ルートは無く、ゲートウェイ実装も `Err("not implemented")` | `task_schedules.rs:41-66`、`task_schedule_item_mutation_gateway.rs:405-411` |
| 復元（`POST /undo_deletion`）はトークンのみで、ユーザー認可を評価しない（ハンドラーは `DeletionUndoRestoreInteractor` にトークンのみを渡す） | `crates/agrr-server/src/deletion_undo.rs:22,68-88` |

**判定（決定に沿った確定）**: `schedule_allowed` の Plan / TaskScheduleItem 分岐は**所有者のみ（と admin）**であり、決定に適合するので**これを正として確定する**。「組織対応にする」案は採らない。`DeletionUndoScheduleInteractor` は本番未使用であり、アダプターの `find_schedulable_record` も Plan 系に未対応で、動かない状態のため、**削除案を推奨として維持する**（§5.4）。

**非対称の整理**: 「組織メンバーが Plan を削除できるが undo 予約はできない」という非対称は、コード上は存在する（削除は組織スコープ、`schedule_allowed` は所有者のみ）。しかし、実際の削除は `schedule_destroy` を直接呼び、復元はトークンのみなので、**本番の挙動としての実害は無い**（組織メンバーが削除したときも undo トークンを受け取り、そのトークンで復元できる）。決定に沿った解消方法は「undo 側を組織対応にする」ではなく、**削除側（`cultivation_plan_destroy_interactor.rs:66-69`）を所有者のみに縮小する**ことである（D7 の S1）。縮小後は、削除・undo 予約・復元が所有者に揃う。

**注意（範囲外・要確認）**: 復元 API は undo トークンだけで認可を評価しない。トークンの取得経路が削除の応答のみであれば実害は限定的だが、トークンの推測困難性・有効期限の詳細は未確認（U12）。

### 2.7 D6: user_id のみ判定 vs 組織スコープ判定の網羅表

grep 条件: `record_access_filter(.*vec!\[\])`、`index_list_filter(.*&\[\])`、`CultivationPlanRestAuth::private\(`、`member_organization_ids`（`crates/` の非テストコード）。

**方針との関係**: D6 は Farm / Crop / Masters が中心で、決定（Plan 系は所有者のみ）の適用範囲外である。ただし、`#1`（Plan REST）と `#2`（プレビュー）は Plan であり、決定により「`#1` は 5 箇所とも正、`#2` の上流ゲートは縮小」になる。`#18` の Plan 系 interactor 群は閲覧系・編集系とも縮小する。Plan 以外（`#3`〜`#17`）の組織スコープは範囲外で、P9 は未決のままである。

| # | 箇所 | 方式 | 組織対応の可否 | 判定 |
|---|------|------|----------------|------|
| 1 | `cultivation_plans.rs:75`、`cultivation_plans_mutations.rs:320,440,546,751` | Plan REST を user_id のみ | Plan は `organization_id` を持つ | **編集系 4 箇所は決定どおり（適合）**。`data`（`:75`）は閲覧の扱いを P1 で確認 |
| 2 | `weather_reschedule_proposal_preview_interactor.rs:175` | 上流は org、下流で `private(self.user_id)` | 同上 | **上流ゲートの縮小対象（D7 の S5）**。下流は正 |
| 3 | `crop/policies/crop_masters_nested_access.rs:12`、`pesticide/policies/crop_masters_nested_access.rs:12` | Crop に対し空スコープの `record_access_filter(*user, vec![])` | `CropEntity::organization_id` が実装済み（`crop_entity.rs:71`） | 判定方式の不一致（Crop 本体は org 判定、ネストは user_id のみ）。**Crop の編集は決定の範囲外**。ネストを組織メンバーへ広げると編集権限の拡大になるため、推奨を見直した（P4） |
| 4 | `masters_crop_context.rs:19-46`（`CropLoadUserNonReferenceForMastersInteractor`）、`masters_crop_pests.rs:74,112,177`、`masters_crop_pesticides.rs:49`、`masters_crop_stages.rs:237,276` | 上記 #3 のポリシー経由 | 同上 | #3 と同根 |
| 5 | `shared/policies/crop_nested_pests_access.rs:12`、`crop_resolve_by_name_policy.rs`、`field_cultivation_climate_crop_view_policy.rs:16` | 空スコープ／user_id | Crop は組織対応 | **未精査**（同じ型の可能性。§7 のステップで個別確認） |
| 6 | `field/policies/field_access.rs:21,26`、`field_create_interactor.rs:48` | 空スコープの `farm_policy::record_access_filter(*user, vec![])`、`assert_owned` は `farm.user_id == Some(user.id)` | `FarmEntity::organization_id` 実装済み（`farm_entity.rs:63`）。ただし `field/results/farm_record.rs` は組織 ID を持たない | Farm 本体は org 判定、配下の Field は user_id のみ。編集は所有者のみで、決定より厳格 |
| 7 | `field_gateway.rs:91-95` | フィルターを受け取るが、ゲートウェイは user_id のみ読む | — | **R0 隣接の疑い**（ゲートウェイがフィルターを受け取って実質 user_id 絞り込みをする。判定はしていない） |
| 8 | `pest/interactors/pest_{detail,update,destroy,ai_update}_interactor.rs`（`:49,65,51,150`）、`pest_list_interactor.rs:35` | 空スコープ | Pest エンティティは `organization_id` を実装していない（`RecordRef` の既定 `None`、`record_ref.rs:5-7`。実装は Crop と Farm のみ） | Tier 1 未展開（ADR-002 の #612 スコープ外）。**整合的な未対応** |
| 9 | `pesticide/interactors/pesticide_*_interactor.rs`（`:44,55,50`、list `:41`） | 空スコープ | 同上 | 同上 |
| 10 | `fertilize/interactors/fertilize_*_interactor.rs`（`:49,55,50,185`、list `:41`） | 空スコープ | 同上 | 同上 |
| 11 | `agricultural_task/interactors/agricultural_task_{detail,update,destroy}_interactor.rs`（`:32,56,40`） | 空スコープ | 同上 | 同上 |
| 12 | `interaction_rule/interactors/interaction_rule_{detail,update,destroy,list}_interactor.rs`（`:43,54,47,41`） | 空スコープ | 同上 | 同上 |
| 13 | `cable_subscription_auth.rs:59` | Farm 購読を org 引数なしの `farm_policy::view_allowed` | Farm は組織対応 | 閲覧（受信のみ）。同ファイルの Plan 購読は org 対応。**閲覧の一貫化なので決定に抵触しない** |
| 14 | `field_cultivation/policies/plan_field_cultivation_access.rs:8-30` | user_id/admin＋公開 | スナップショットに組織 ID 無し | **過剰許可（D5、公開 Plan）**。私有 Plan の編集は決定に適合 |
| 15 | `deletion_undo/schedule_authorization.rs:36-57` | user_id | Farm / Crop / Plan は組織対応 | 所有者のみが正（D3）。未配線 |
| 16 | `crop_ai_upsert_sqlite_persistence.rs:195` | アダプターが org フィルターで評価 | — | **R0 違反（D1）** |
| 17 | 参照リスト SQL `agrr-adapters-sqlite/src/shared/reference_index.rs:22-66` | org ID が空なら `user_id` のみ、非空なら org または（`organization_id IS NULL` かつ user_id） | インフラは組織対応済み | 情報: Pest 等は空スコープを渡すため、リスト SQL の org 分岐は未使用 |
| 18 | `work_records` / `task_schedules` / 分散学習 / Plan 削除の interactor 群 | org | — | **編集系・閲覧系とも決定と不整合（D7）**。全数は §2.9.1・§2.9.2 |

Pest / Pesticide / Fertilize / AgriculturalTask / InteractionRule の組織対応は、ADR-002 では Tier 1 のデータモデル（`organization-data-model.md`）に載っているが、#612 の認可移行スコープは Farm / Crop / Plan に限られる。したがって #8〜#12 は「バグ」ではなく「未展開」として扱う。

### 2.8 組織スコープ判定の共通仕様（過剰許可の前提）

| 事実 | 根拠 |
|------|------|
| `organization_member_access(ids, is_reference, record_org)` は、非参照かつ `record_org` が `ids` に含まれれば true。**役割（owner / admin / member）を見ない** | `crates/agrr-domain/src/shared/org_scope.rs:13-23` |
| `ReferenceRecordAccessFilter` の view / edit は user_id 一致または上記の組織一致で許可。view と edit の差は無い | `crates/agrr-domain/src/shared/reference_record_access_filter.rs`、`reference_record_authorization.rs` |
| Plan 系は、閲覧と編集の両方が同じ関数に流れている: `private_cultivation_plan_access_policy::access_denied`、`work_record::private_plan_access::access_allowed`、`task_schedule_private_plan_access::access_allowed`。第 2 回決定により閲覧も所有者のみになるため、**閲覧用と編集用に分ける必要は無い**。この 3 つから組織 ID の引数を取り除けば、全経路が所有者のみに揃う（§5.7） | `private_cultivation_plan_access_policy.rs:8-24`、`work_record/interactors/private_plan_access.rs:11-17`、`cultivation_plan/interactors/task_schedule_private_plan_access.rs:14` |
| ADR-002 §4 は「`OrganizationAccessPolicy`（仮称）— メンバーシップ＋ロール＋`organization_id` 一致」を構想している | `docs/adr/ADR-002-organization-multi-tenancy.md` §4 |
| `organization_access_policy.rs` は実在する（`member_access_allowed`、`resource_access_allowed`、メンバー管理のロール判定）。ただし `resource_access_allowed` は `rg` で確認した範囲で本番コードから呼ばれておらず（定義と再エクスポートのみ）、Plan の認可には使われていない。`resource_access_allowed` はロールを見ず、admin を常に許可する | `crates/agrr-domain/src/organization/policies/organization_access_policy.rs:8-33`、`policies/mod.rs:5-7` |

### 2.9 D7: 決定に反して組織メンバーへ閲覧・編集を許している経路（縮小すべき箇所の全数）

2026-09-29 時点で、次の 3 種の `rg` を実行して洗い出した（非テストコード）。

- `rg "organization_member_access|member_organization_ids|private_with_scope" crates`
- `rg "organization_memberships|organization_id" crates/agrr-adapters-sqlite/src crates/agrr-server/src`（Plan 関連の SQL を特定）
- `rg "private_cultivation_plan_access_policy|assert_private_owned|access_denied\b|plan_access_allowed|task_schedule_private_plan_access|rest_plan_access"`（Plan の共通ポリシーの呼び出し元）

判定はすべて `private_cultivation_plan_access_policy::access_denied` に帰着する（`task_schedule_private_plan_access.rs:14`、`work_record/interactors/private_plan_access.rs:14`、`cultivation_plan_destroy_interactor.rs:69`、`private_owned_plan_detail_interactor.rs:77`、`rest_plan_access.rs:21`、`cable_subscription_auth.rs:44`）。唯一の例外は、一覧の SQL が持つ組織サブクエリ（`private_read_gateway.rs:32-34`）である。

「編集」は、永続化・削除・最適化ジョブ投入を伴う操作とする。「閲覧」は、読み取り・取得・購読とする。

#### 2.9.1 編集系（第 1 回決定。S 系）

| # | 縮小対象 | 現状の根拠 | 縮小後の判定 |
|---|----------|-----------|--------------|
| S1 | Plan 削除 | `cultivation_plan_destroy_interactor.rs:66-69`（ルート `plans.rs:51-52`、ハンドラー `plans.rs:487`） | 所有者のみ（admin は P3）。非所有者は現行どおり `plans.errors.not_found`（同 `:69-73` の失敗経路） |
| S2 | タスクスケジュールの item 作成・更新・skip・unskip・regenerate | `task_schedule_item_create_interactor.rs:48-49`、`task_schedule_item_update_interactor.rs:80-81`、`task_schedule_item_skip_interactor.rs:50-51,69-70`、`regenerate_task_schedule_interactor.rs:44-45` | 所有者のみ。非所有者は現行どおり `on_not_found`（`skip` の `:52`）と同型 |
| S3 | 作業実績の作成・更新・削除、写真の upload_init / upload_content / upload_complete / destroy | `work_record_create_interactor.rs:69-70`、`work_record_update_interactor.rs:64-65`、`work_record_destroy_interactor.rs:52-53`、`work_record_photo_upload_init_interactor.rs:62-63`、`work_record_photo_upload_complete_interactor.rs:67-68`、`work_record_photo_destroy_interactor.rs:53-54`、`work_record_photos.rs:332` | 所有者のみ |
| S4 | 分散学習の更新系（proposal / orchestration / handoff の PATCH、reoptimize、import の書き込み先、Plan 作成時の carryover の書き込み先） | `plan_variance_learning_proposal_progress_update_interactor.rs:48-50`、`plan_variance_learning_orchestration_progress_update_interactor.rs:48-50`、`plan_variance_learning_handoff_update_interactor.rs:48-50`、`plan_variance_learning_reoptimize_interactor.rs:51-52`、`plan_variance_carryover_interactor.rs:90-97` | 所有者のみ |
| S5 | 天候リスケ提案プレビュー（adjust の dry-run）の上流ゲート | `weather_reschedule_proposal_preview_interactor.rs:126-135`。下流の adjust は `private(self.user_id)`（`:175`）で 404 になり、現状の実効は所有者のみ | 上流ゲートを所有者のみにして、上流と下流を揃える |
| S6 | D5（公開 Plan の圃場栽培） | §2.5 | 公開 Plan は私有ルートから編集不可 |
| S7 | `task_schedule_item_schedule_deletion_undo_interactor.rs:55-56`（未配線） | §2.6 | 配線されていないため現時点で挙動は変わらないが、他の 24 個と同じ引数変更（組織 ID の除去）の対象に含めないと、共通ヘルパーの署名変更でコンパイルできなくなる。削除案（D3）を採るなら削除 |

#### 2.9.2 閲覧系（第 2 回決定。V 系）

| # | 縮小対象 | 現状の根拠 | 縮小後の判定 |
|---|----------|-----------|--------------|
| V1 | Plan 一覧 `GET /api/v1/plans` | 取得 SQL が `cp.user_id = ?1 OR cp.organization_id IN (SELECT organization_id FROM organization_memberships WHERE user_id = ?1)`（`private_read_gateway.rs:32-34`）。ハンドラー `plans.rs` の `list_plans` は scope gateway を使わず、この SQL だけで組織共有が成立している。インタラクター `private_owned_plans_list_interactor.rs:50` は行を再判定しない | SQL を `cp.user_id = ?1` のみにする。**判定はドメインではなく SQL 側に埋まっている**ため、政策の変更が Gateway の取得条件の変更になる。R0（Gateway は認可しない）との関係は §5.7 で整理する |
| V2 | Plan 詳細 `GET /api/v1/plans/{id}` | `private_owned_plan_detail_interactor.rs:75-77`（ハンドラー `plans.rs:186`） | 所有者のみ |
| V3 | タスクスケジュール timeline `GET /plans/{id}/task_schedule` | `task_schedule_timeline_interactor.rs:67-69`（ハンドラー `task_schedules.rs:165`） | 所有者のみ |
| V4 | 作業実績の一覧 | `work_record_list_interactor.rs:49-50`（ハンドラー `work_records.rs:321`） | 所有者のみ |
| V5 | 作業実績の写真ダウンロード | `work_record_photos.rs:423-434`（`plan_access_allowed` に `member_org_ids`。`member_organization_ids` の解決は `:426`） | 所有者のみ |
| V6 | 予実サマリー | `plan_vs_actual_summary_interactor.rs:68-70`（ハンドラー `plan_vs_actual.rs:72`） | 所有者のみ |
| V7 | 分散学習の取得 | `plan_variance_learning_read_interactor.rs:64-66`（ハンドラー `plan_variance_learning.rs:173`） | 所有者のみ |
| V8 | 天候リスケ提案の一覧 | `weather_reschedule_proposals_list_interactor.rs:53-55`（ハンドラー `weather_reschedule_proposals.rs:125`） | 所有者のみ |
| V9 | 分散ポートフォリオ `GET /api/v1/work/variance_portfolio` | 行の取得が V1 と同一 SQL（`variance_portfolio_interactor.rs:85` → `private_read_gateway.rs:32-34`）、各行の再確認が組織付きの `access_allowed`（`:113-118`）。ハンドラー `variance_portfolio.rs:97` | V1 の SQL 変更で列挙が所有者のみになり、再確認からも組織 ID を除去 |
| V10 | Cable の Plan 購読 | `PlansOptimizationChannel` は `private_with_scope` → `rest_plan_access_denied`（`cable_subscription_auth.rs:31-35`）、`OptimizationChannel` は `access_denied` に組織 ID（`:44-48`）。セッション文脈が組織 ID を解決する（`cable.rs:403-407`、`CableSessionContext` `cable_subscription_auth.rs:15-19`） | 両チャンネルとも所有者のみ。`CableSessionContext` から `member_organization_ids` を除去し、`cable.rs` の組織スコープ解決を除く |
| V11 | carryover の元 Plan（`POST variance_learning` の `source_plan_id`、Plan 作成時の `carryover_from_plan_id`） | `plan_variance_carryover_interactor.rs:99-105`（元 Plan の閲覧判定。失敗は `carryover_source_not_found`）。入口 `plan_variance_learning.rs:395-431`、`plans.rs:401-402` | 元 Plan も所有者のみ。他メンバー所有の Plan を元にした carryover は失敗する |

`GET /api/v1/plans/cultivation_plans/{id}/data`（`cultivation_plans.rs:75`）、圃場栽培の show / climate_data（`plan_field_cultivation_access.rs:8-24`）、作業ハブ（`work_hub_read_gateway.rs:36,42`）は、すでに所有者のみで縮小対象ではない。公開 Plan の経路（§2.4）も対象外である。

#### 2.9.3 組織スコープ判定の利用箇所（Plan 系と範囲外の切り分け）

**Plan 系（縮小して取り除く）**

| 種別 | 箇所 | 備考 |
|------|------|------|
| ポリシー | `cultivation_plan/policies/private_cultivation_plan_access_policy.rs:4,8-37`（`organization_member_access` を使う唯一の Plan ポリシー） | 第 3 引数 `member_organization_ids` と組織一致の分岐を除去 |
| 共通ヘルパー | `work_record/interactors/private_plan_access.rs:11-17`、`cultivation_plan/interactors/task_schedule_private_plan_access.rs:11-17`（再エクスポート `work_record/mod.rs:11`、`cultivation_plan/interactors/mod.rs:97`）、`rest_plan_access.rs:21-25` | 引数の除去 |
| DTO | `cultivation_plan_rest_auth.rs:13,24,29-33,42,51`（`member_organization_ids` フィールドと `private_with_scope`） | `private_with_scope` の呼び出し元は `cable_subscription_auth.rs:31` のみ。フィールドの読み手は `rest_plan_access.rs:24` と `crop_rows_available_private_gateway.rs:43`（後者は Crop 一覧のスコープ。§下記） |
| interactor（work_record 8 件） | `work_record_create` `:69`、`work_record_destroy` `:52`、`work_record_photo_upload_init` `:62`、`work_record_list` `:49`、`work_record_photo_upload_complete` `:67`、`variance_portfolio` `:81`、`work_record_photo_destroy` `:53`、`work_record_update` `:64`（いずれも `*_interactor.rs`） | `member_organization_ids` の解決と `scope_gateway` の注入を除去 |
| interactor（cultivation_plan 17 件） | `cultivation_plan_destroy` `:66`、`plan_variance_learning_orchestration_progress_update` `:48`、`plan_variance_learning_handoff_update` `:48`、`task_schedule_item_update` `:80`、`task_schedule_item_skip` `:50,69`、`plan_variance_learning_reoptimize` `:51`、`plan_vs_actual_summary` `:68`、`task_schedule_item_schedule_deletion_undo`（未配線）`:55`、`task_schedule_timeline` `:67`、`plan_variance_carryover` `:77`、`private_owned_plan_detail` `:75`、`regenerate_task_schedule` `:44`、`plan_variance_learning_proposal_progress_update` `:48`、`plan_variance_learning_read` `:64`、`weather_reschedule_proposal_preview` `:126`、`task_schedule_item_create` `:48`、`weather_reschedule_proposals_list` `:53` | 同上。合計 25 件（うち 1 件は未配線） |
| アダプター SQL | `private_read_gateway.rs:32-34` | V1、V9 |
| サーバー | `cable.rs:8,17,402-407`、`cable_subscription_auth.rs:17,31-33,44-48,121`、`work_record_photos.rs:11,271,329-340,385,423-434,470`、`work_records.rs:286,321,365,408`、`task_schedules.rs:165,301,358,421`、`plan_variance_learning.rs:173,323,562,610`、`plan_vs_actual.rs:72`、`variance_portfolio.rs:97`、`weather_reschedule_proposals.rs:125,200`、`plans.rs:186,487`（いずれも `UserOrganizationScopeSqliteGateway::new` の生成、または `member_organization_ids` の解決） | interactor のコンストラクタ変更に伴い、scope gateway の生成と引数渡しを除去 |

**範囲外（Plan 以外。P9 は未決のまま）**

| 種別 | 箇所 |
|------|------|
| Farm | `farm_create` `:71`、`farm_temperature_chart` `:68`、`farm_destroy` `:58`、`farm_detail` `:49`、`farm_update` `:94`、`farm_list` `:44`（`farm/interactors/farm_*_interactor.rs`）、`shared/policies/farm_policy.rs:24-26`、`masters_farms.rs`、`masters_farm_temperature_chart.rs:52` |
| Crop | `crop_create_interactor.rs:60`、`shared/policies/crop_policy.rs:31-72`、`masters_crops.rs`、`masters_crop_stages.rs`、`masters_crop_task_schedule_blueprints.rs`、`masters_crop_setup_proposal.rs`、`crop_ai_upsert_sqlite_persistence.rs:166`（D1）、`ai_api.rs:163,166` |
| Plan に隣接する Crop の組織スコープ | Plan の `add_crop` が作物を解決するときの `CropFindPrivatePlanAddCropRecordInteractor`（`add_crop_support.rs:32,48,126`）。所有者が組織共有の Crop を自分の Plan に追加できる。**Crop の共有であり Plan の共有ではない**ため範囲外 |
| Plan REST 認可 DTO 経由の Crop 一覧 | `crop_rows_available_private_gateway.rs:43`（`parsed.member_organization_ids` を `ReferenceIndexListFilter` に渡す）。呼び出し元は `cultivation_plans.rs:71,75` の `private(user_id)`（組織 ID 空）だけで、`private_with_scope` の値はここに届かない。したがって DTO のフィールドを除去しても挙動は変わらないが、Crop 側の読み手なので、除去時にこのゲートウェイの引数も同時に直す |
| Pest / Pesticide / Fertilize / AgriculturalTask / InteractionRule | `shared/policies/*_policy.rs` の `record_access_filter` / `index_list_filter`（組織 ID の引数を受けるが、呼び出しは空スコープ。§2.7 #8〜#12） |
| 共通基盤 | `shared/org_scope.rs:6-23`、`shared/reference_record_access_filter.rs:3,16-63`、`shared/gateways`（`UserOrganizationScopeGateway`）、`shared/user_organization_scope_sqlite_gateway.rs`、`shared/reference_index.rs:21-59`。Farm / Crop が使い続けるため**残す** |

**削除・変更してはならないもの**: `organization_member_access`、`member_organization_ids` 関数自体、`UserOrganizationScopeGateway`、Organization / Membership の API と表（`cultivation_plans.organization_id` 列を含む。§3.3）は、Farm / Crop が使うため、または将来の再開条件（§3.3）のために残す。

**影響範囲の確認（読み取りのみで確認）**: 上記 interactor は、いずれも `scope_gateway` を受け取って `member_organization_ids` を解決している。縮小後は組織 ID を必要としなくなる。コンストラクタから `scope_gateway` を外す設計（§5.7）にするため、呼び出し元のハンドラーとテストのフィクスチャも変わる。

---

## 3. あるべき認可方針

### 3.1 判断が必要な論点

第 1 回決定（§0）で旧 P1 の「(b) 全メンバーに編集も許可」「(c) ロールで分ける」は採らないとした。第 2 回決定（§0）で、旧 P1（閲覧のみを組織メンバーに許すか）も**確定**した（閲覧も許さない）。P1 は決定済みとして表に残し、未決事項は P3、P4、P5、P6、P8、P9、P10 と、今回追加した P11〜P13 である。

| # | 論点 | 選択肢 | 推奨 | ユーザー確認 |
|---|------|--------|------|--------------|
| P1 | 組織メンバーに他メンバー所有 Plan の**閲覧**を許すか | (a) 許す（旧推奨）。(b) 許さない。(c) 現状維持 | **決定済み: (b)**。第 2 回決定（§0）により旧推奨 (a) を覆した。`data` と `climate_data` の 404 は仕様どおり。一覧・詳細ほか閲覧経路は V1〜V11 として所有者のみへ縮小する（§2.9.2） | 不要（決定済み） |
| P2 | Plan のロール別制御を今回入れるか | (a) 入れない。(b) `OrganizationAccessPolicy` を導入 | (a)。決定は「所有者のみ」なのでロールの出番が無い。ロール導入は別課題 | 不要（決定により (a) で確定。確認するなら別課題として） |
| P3 | 公開 Plan の圃場栽培を私有ルートで更新できてよいか（D5）、および `admin` の扱い（**未決のまま**） | (a) 不可（公開 Plan の変更は公開ルート＋セッション必須）。(b) 所有者のみ許可。`admin` は (i) Plan 系の共通ポリシーどおり許可しない、(ii) field_cultivation のポリシーが現に許す範囲（`plan_field_cultivation_access.rs:8-24`）だけ許す、(iii) ADR-002 §4 のとおり全 Plan で許す、のいずれか | D5 は (a)。`admin` は**現状のコードに合わせる (ii)** を仮置きとするが未決。事実: Plan 系の共通ポリシー `access_denied` は `admin` を見ないため（`private_cultivation_plan_access_policy.rs:8-24`）、admin は所有者以外の Plan の詳細・削除・作業実績などに入れない。admin が入れるのは field_cultivation の show / climate_data / PATCH のみ（`plan_field_cultivation_access.rs:8-24`）。縮小（D7）は admin の挙動を変えない | **必要**（admin の扱い） |
| P4 | Crop のネスト Masters を組織メンバーに許可するか（D6 #3） | (a) Crop 本体と同じ組織スコープにそろえる。(b) 所有者のみ（現行を仕様として明文化） | **(b)（現状維持）を推奨に見直した**。旧推奨は (a) だったが、(a) は組織メンバーの編集を Crop 配下に広げる。決定の適用範囲は Plan だが、精神（過剰許可を避ける）に照らすと、今回は広げない。読み取りだけを広げる場合は、ネスト Masters の閲覧用と編集用の判定を分ける必要があり（現状は `crop_masters_nested_access.rs:12` の 1 系統のみ。全ネスト経路の判定は未精査）、別課題 | **必要** |
| P5 | Pest 等 Tier 1 の組織展開を本課題に含めるか | (a) 含めない。(b) 含める | (a)。別 issue で展開範囲を定義。第 2 回決定は Plan のみを対象とし、Pest 等の展開方針は決めていない | **必要** |
| P6 | D1: 認可拒否時の挙動 | (a) 現行維持（拒否→新規作成）。(b) Forbidden を返す | (b)。他ユーザーの `crop_id` を指定した更新が新規作成に化けるのは、意図として不自然。ただし互換性影響あり | **必要** |
| P7 | D3: `schedule_allowed` の扱い | (a) 組織対応にする。(b) 未配線なら削除する | **(b) を確定推奨**。所有者のみが正（決定）で、本番未配線、アダプターも Plan 系に未対応。呼び出し元の再確認（U4）後に削除。(a) は決定に反するため採らない | 必要（削除の可否のみ） |
| P8 | D4: 公開 Plan の読み取り | (a) 許容（現行）。(b) 許容し設計として文書化。(c) 対策（非連番 ID、レート制限） | (b) を最小案とする。(c) は共有リンク仕様が固まってから | **必要** |
| P9 | Farm / Crop の組織スコープ（閲覧・編集。`farm_update_interactor.rs:94`、`crop_create_interactor.rs:60`、R4 `contracts.rs:4157,4242`）を決定と同じ厳格側へ縮小するか（**未決のまま**） | (a) 決定の範囲外として維持。(b) Plan と同様に所有者のみへ縮小 | (a)。第 2 回決定の文言は Plan とその配下のみで、Farm / Crop は含まれない。Farm / Crop の組織共有は R4 で明示的にテストされている（`contracts.rs:4127` の `org_member_can_view_team_farm` 以降の `org_*_team_farm` / `org_*_team_crop`）。厳格側へ寄せる場合は別 issue で契約テストごと見直す。Plan 以外の組織スコープの利用箇所は §2.9.3 の「範囲外」表に列挙した | **必要**（決定の解釈範囲） |
| P10 | D7 の縮小を、既存の組織共有データがある環境へ適用する際の扱い | (a) 即時に縮小。(b) 縮小前に、組織メンバーが実際に他メンバーの Plan を閲覧・編集できる状態（メンバー追加で共有されている Plan）があるかを本番データで確認する（§4.3 の読み取り専用 SQL） | (b) を推奨。本番の組織メンバー数・共有 Plan 数は本調査で**未確認**（`production-primary-sqlite-query` スキルで確認できる）。閲覧の縮小は、共有されていた Plan が組織メンバーから突然見えなくなる挙動変更を伴う | **必要** |
| P11 | ADR-002 の「Plan の組織共有」を、ADR の更新で扱うか、新 ADR で扱うか（§3.3） | (a) ADR-002 に追記（Status を維持し、Plan の共有を撤回した旨と日付を追記）。(b) 新 ADR（例: ADR-0xx「Plan は所有者のみ。組織共有は Farm / Crop に限る」）を起こし、ADR-002 に Superseded-by（部分）を書く | **(b) を推奨**。ADR-002 は B2B 土台の全体決定で、Farm / Crop の共有と Organization モデルはそのまま有効なため、全体を書き換えず、Plan の共有だけを覆す決定として新 ADR に分ける。番号は `docs/adr/` の既存採番に合わせる（採番は本書では決めない） | **必要**（ADR の形式） |
| P12 | 「B2B で組織共有が将来必要になった時の再開条件」を、どこまで先に決めておくか（§3.3） | (a) 条件を ADR に残すだけ（再開時に設計する）。(b) 再開時の設計（閲覧と編集の分離、ロール、招待フロー）まで先に決める | **(a)**。第 2 回決定は「今は共有しない」であり、再開の設計を先取りしない。条件だけを ADR に残す | **必要**（再開条件の合意） |
| P13 | personal org へのメンバー追加を許すか（組織メンバー追加 API に personal org のガードが無い: `organization_membership_create_interactor.rs:47-97`） | (a) 本課題では扱わない。(b) personal org へのメンバー追加を拒否する | **(a)**。Plan の閲覧・編集は縮小で塞がるが、Farm / Crop の共有（P9）と 01 の上限共有枠（U1）には影響が残るため、Farm / Crop の組織スコープ方針（P9）と合わせて別課題で決める | **必要**（別課題化の可否） |

### 3.2 ADR-002 の Phase との整合

| 項目 | 整合 |
|------|------|
| ADR-002 Migration phases 6「ポリシー移行」(#612) は Farm / Crop / Plan の組織スコープ認可（`ADR-002` `:127`）。**第 2 回決定は #612 が導入した Plan の組織共有（閲覧・編集）を撤回する**ため、Plan に関しては ADR-002 の「リソース共有: 同一 `organization_id` 内の Farm / Crop / Plan 共有」（`:54`）と直接衝突する。Farm / Crop の共有は決定の範囲外で有効なまま（P9 未決） | `docs/adr/ADR-002-organization-multi-tenancy.md:54,127` |
| ADR-002 Context は「組織単位で計画共有」を課題として挙げる（`:15`）。この「計画」が Plan（cultivation plan）か広義の計画かは、文言だけでは断定できない（**未確認**）。ただし §3 の表で Plan を明記しているため、Plan の共有を意図していたと読むのが妥当 | `ADR-002:15,54` |
| `organization-data-model.md` の `member` ロールは「org 内リソースの CRUD」（`:41`）、`owner` / `admin` は「リソース CRUD」（`:39-40`）。Plan には当てはまらなくなる。Tier 1 に `cultivation_plans` がある（`:51`）点と、ER 図の organizations と cultivation_plans の「owns」関係（`:114`）も、Plan は組織が所有するのではなく組織列を持つだけになる | `docs/design/organization-data-model.md:39-41,51,114` |
| ADR-002 §4「Gateway は `organization_id` による狭い永続化クエリのみ」。D1 は Gateway（Persistence）が認可を評価しており、§4 と R0 の双方に反する。V1 の一覧 SQL（`private_read_gateway.rs:32-34`）は組織条件を SQL に持つが、縮小で `user_id` のみの取得条件になり、認可を Gateway に埋める形も解消する | 同 §4、`LAYER-RULES.md`（R0） |
| ADR-002 §4「admin は全 org を横断可能（現行 `user.admin` と同等）」（`:68`）。Plan 系の共通ポリシーは admin を見ない（§0、P3）ため、現状でも ADR §4 と食い違う。P3 の決定で整合させる | 同 §4 |
| ロール判定は §4 に記載があるが、Phase 6 の実装では未導入（§2.8）。本課題では導入しない（P2 (a)） | — |
| Tier 1 のうち Pest 等の展開は #612 の範囲外（§2.7）。本課題では扱わない（P5 (a)） | `docs/design/organization-data-model.md` |

### 3.3 ADR・設計文書の更新、`organization_id` 列と backfill、再開条件

**ADR 更新の要否（P11）**: 要。第 2 回決定は、Accepted の ADR-002 が Phase 1 の責務として掲げた「Plan の組織共有」を覆すため、ADR を更新せずに実装だけ縮小すると、ADR と実装が食い違ったまま残る（09 が扱う「設計文書が実装と乖離する」状態を新たに作る）。推奨は**新 ADR**で、内容は次のとおりとする。

- 決定: Plan とその配下（field_cultivation、task_schedule、work_record、写真、climate、分散学習、Cable 購読）は所有者のみとする。組織スコープ判定は Plan 系から取り除く。
- 維持するもの: Organization / Membership のモデルと API、Farm / Crop の組織スコープ（P9 が決まるまで）、`cultivation_plans.organization_id` 列（下記）。
- 覆すもの: ADR-002 §3 の「リソース共有: Farm / Crop / **Plan**」の Plan 部分、Phase 6（#612）が導入した Plan の組織スコープ認可。
- ADR-002 側の変更は、Status 節に「Plan の共有は ADR-0xx で撤回」と 1 行を足す程度にとどめる（本文の全面改訂はしない）。

**`cultivation_plans.organization_id` 列と backfill**:

- 列は**残す**。理由: (1) Tier 1 のスキーマで、削除は不可逆かつ再開の妨げになる。(2) backfill の対象表 `TIER1_TABLES` に含まれ（`personal_organization_sqlite_gateway.rs:29-39`）、Farm / Crop と同じ関数で処理されているため、Plan だけを外す変更は本決定に必須ではない。(3) 再開条件（下記）で使う。
- 縮小後、Plan の `organization_id` を**読む**本番コードは無くなる。`CultivationPlanEntity::organization_id`（`cultivation_plan_entity.rs:8`）と、ゲートウェイの SELECT / マッピング（`cultivation_plan_gateway.rs:226,241,267,280`）は未使用の列・フィールドになる。`project-necessary-code-only` に従い外すかどうかは、ADR の再開条件と合わせて決める（**本書では外さないことを既定**とし、外す場合は別コミット）。
- **課題 01 の `cultivation_plans.organization_id` backfill 拡張は Plan 系では不要になる**。01 は起動時 backfill を「personal org は持つが Tier 1 に NULL 行があるユーザー」まで広げる案で、Plan の NULL 行の修復もその副産物として含む（01 §2.4、R10、手順 10・12）。縮小後は Plan の NULL 行が権限判定に使われないため、Plan のために backfill を拡張する理由は無い。01 が Farm / Crop のために拡張を行うなら Plan 行も更新されるが、無害である（Plan の判定に使われない）。Plan の書き込み側（`plan_save_*` の INSERT に `organization_id` を足す案）も不要。01 側の記述は 01 の改訂で調整する（本書では編集しない）。
- 順序: 縮小が完了するまでは、01 の backfill 拡張が Plan の共有可能性を広げる（NULL だった Plan に組織 ID が入り、組織スコープの経路で見えるようになる）。したがって「D7 の縮小を 01 の backfill より先に、または同時に適用する」方針は維持する（§10）。縮小後は、この制約は不要になる。

**再開条件（P12）**: 「B2B で組織共有が将来必要になった時」に、次のすべてを満たすことを条件として ADR に残す（合意はユーザー確認事項）。

1. 組織共有の対象を Plan 単位で明示する仕様（例: 共有する Plan を所有者が選ぶ、または組織所有の Plan を作る）がある。**既存の Plan を自動で組織へ共有しない**（`cultivation_plans.organization_id` の backfill 値が「共有意図」を表さないため。personal org の値は所有の記録にすぎない）。
2. 閲覧と編集を分ける（ロール、または共有時の権限指定）。組織スコープ判定は `organization_member_access` の一律許可（役割を見ない: §2.8）ではなく、`OrganizationAccessPolicy` 相当のロール判定に基づく。
3. Plan 配下の全経路（§2.9 の V / S 全数と Cable、SQL、写真）を同じ判定に通す。経路ごとの方式の不一致（本書 D2 で見つけた状態）を作らない。
4. 個人組織（personal org）へのメンバー追加のガード（P13）が決まっている。
5. R4 契約テストで、共有された Plan の閲覧・編集の成否を経路ごとに固定する。

**ユーザー確認事項**: (1) 新 ADR にするか、ADR-002 追記にするか（P11）。(2) 上記の再開条件でよいか（P12）。(3) 「閲覧も許さない」の対象が Plan 系だけでよいか（P9。Farm / Crop も含む意図なら本節と D7 を差し替える）。

---

## 4. 影響範囲

| 課題 | 影響を受けるもの |
|------|------------------|
| D1 | `POST` の Crop AI 生成 API（`ai_api.rs:50`）。非推奨で廃止予定（`builtin-generation-sunset.md:67-68`）。呼び出し元フロントの有無は**未確認** |
| D2 | 変更なし（`data` と編集系 4 箇所は正）。`data` / `climate_data` の 404 は仕様どおり（確定）。フロントの Plan 画面が組織メンバーに一覧・詳細を見せない状態になるため、Gantt だけ 404 になる中途半端な状態は解消する（V1〜V2 の縮小） |
| D3 | 汎用 undo 予約（本番の呼び出し元は確認できず）。削除案の場合、`DeletionUndoScheduleInteractor`、`schedule_authorization.rs`、`find_schedulable_record`（ポートとアダプター）、関連テストが削除対象になり得る（削除の範囲は U4 の再確認後に確定） |
| D4 | 公開 Plan の閲覧 URL、SEO メタ（`public-plan-results-seo-meta.ts`）、公開ウィザード |
| D5 | `PATCH /api/v1/plans/field_cultivations/{id}`（フロントは未使用）。`show` / `climate_data` の私有ルート閲覧は公開 Plan を許可している点で挙動を変える場合は影響あり |
| D6 | Cable の Farm 購読（閲覧の一貫化）。Crop ネスト Masters と Field は現状維持（P4 (b)） |
| D7 | 閲覧系: Plan 一覧・詳細、タイムライン、作業実績一覧、写真ダウンロード、予実、分散学習の取得、天候リスケ提案の一覧、分散ポートフォリオ、Cable の Plan 購読、carryover の元 Plan（V1〜V11）。編集系: Plan 削除、タスクスケジュールの変更系、作業実績と写真の変更系、分散学習の更新系、天候リスケ提案プレビュー（S1〜S5）。組織メンバーがこれらを使っている場合は 404（または一覧から消える・購読が拒否される）に変わる（P10）。フロントに組織メンバー向けの UI があるかは §4.1 で確認済み（**無い**） |
| ドキュメント | ADR-002、`organization-data-model.md`、01 / 07 / 09（§4.1、§10）。`docs/api/openapi.yaml` に `organization` の記述は無く（`rg` で確認）、Plan エンドポイントの 404 の意味は変わらないため、更新は不要の見込み（記述内容の全文は読んでいないため**未確認**） |

変更してはならないもの（回帰防止）:

- 公開 Plan の変更系におけるセッション一致検証（`X-Public-Plan-Session`）。
- 所有者本人のアクセス（閲覧・編集・削除のすべて）。
- 非メンバー・非所有者の拒否。
- Farm / Crop の組織スコープ（P9 が決まるまで）と、`organization_member_access`、`member_organization_ids`、`UserOrganizationScopeGateway`（Farm / Crop が使う: §2.9.3）。
- Organization / Membership の API と表、`cultivation_plans.organization_id` 列（§3.3）。

### 4.1 削除・更新が必要なテストと文書

**フロントエンド（確認済み: 影響なし）**

- 組織共有の UI・文言は**存在しない**。`rg -i "organization|membership" frontend/src` のヒットは、i18n の "reorganization"（`en.json`、`plan-learn*.spec.ts` の文言）と、SEO の JSON-LD `Organization` 型（`site-structured-data.ts:19,45,51`。ADR-002 が「無関係」と明記: `ADR-002:28`）のみ。`rg "organizations|memberships"`（`.ts` / `.html` / `.json`）、`ja.json` の「組織|チーム|共有」、`frontend/e2e`、`frontend/docs`、`scripts`、`.github` に該当は無い。フロントは `/api/v1/organizations` を呼ばない。
- したがって、フロントのコード・翻訳・E2E の削除や更新は**不要**。

**Rust テスト（縮小の RED / GREEN で変更）**

| 種別 | ファイル | 変更 |
|------|----------|------|
| R4 契約 | `crates/agrr-r4-contract/tests/contracts.rs:4306`（`org_member_can_view_team_plan`） | **期待を反転**（200 → 404）。名称も `org_member_cannot_view_team_plan` へ。これが第 2 回決定の RED になる |
| R4 契約 | 同 `:4332`（`org_non_member_denied_team_plan`） | 変更なし（非メンバーの拒否。回帰防止） |
| R4 契約 | `support.rs:1882`（`seed_org_scoped_plan`） | 残す（RED / 回帰テストで再利用）。使用箇所は縮小後も `contracts.rs` の Plan 系のみ |
| R4 契約 | Farm / Crop（`contracts.rs:4127,4157,4192,4216,4242,4282`） | 変更なし（P9 未決） |
| ドメイン policy | `crates/agrr-domain/test/cultivation_plan/policies_private_cultivation_plan_access_policy_test.rs:68-93` | 組織メンバーを**許可**する 2 件（`:69`、`:89`）を「組織メンバーでも拒否」に書き換える（RED）。第 3 引数（組織 ID）の除去に伴い、他のテスト（`:42-66,76,83`）の呼び出しも更新 |
| ドメイン helper | `interactors_task_schedule_private_plan_access_test.rs`（`organization_ids_for_user` のフェイク `:14`） | 引数除去に伴う更新。組織メンバーが拒否されることのテストを追加 |
| ドメイン helper | `interactors_rest_plan_access_test.rs:8`（`organization_ids_for_user` のフェイク） | `CultivationPlanRestAuth` から組織 ID を除く場合の更新 |
| ドメイン interactor（`EmptyScopeGateway` を注入しているもの。コンストラクタから `scope_gateway` を外すため更新が必要） | work_record: `interactors_work_record_{create,list,update,destroy}_interactor_test.rs`、`interactors_work_record_photo_upload_init_interactor_test.rs`、`interactors_variance_portfolio_interactor_test.rs`。cultivation_plan: `interactors_cultivation_plan_destroy_interactor_test.rs`、`interactors_task_schedule_item_skip_interactor_test.rs`、`interactors_regenerate_task_schedule_interactor_test.rs`、`interactors_weather_reschedule_proposal_preview_interactor_test.rs`、`interactors_plan_variance_carryover_interactor_test.rs`、`interactors_plan_variance_learning_{reoptimize,proposal_progress_update,orchestration_progress_update,handoff_update}_interactor_test.rs` | 注入の除去。`rg -l EmptyScopeGateway crates/agrr-domain/test` で列挙したうち、上記 25 個の interactor に対応するもの。`interactors_public_plan_save_interactor_test.rs` など、同じ文字列を含むが対象 interactor が別のファイルは対象外（未精査のものは実装時に個別確認） |
| ドメイン interactor（テストファイルが**存在しない**もの） | 詳細、timeline、予実、分散学習の取得、作業実績の写真 complete / destroy、タスクスケジュール item の create / update、提案の一覧 | 新規に RED を追加する（§6.7）。R4 で代表を固定する方針でもよい |
| アダプター | `crates/agrr-adapters-sqlite/src/cultivation_plan/private_read_gateway_test.rs`（`organization_memberships` の表を作成している `:27`） | SQL の変更に伴い、組織メンバーの Plan が一覧に出ないテストを追加。`test-common` の対象外（§6 冒頭の制約） |
| アダプター | `crop_rows_available_private_gateway_test.rs` | `CultivationPlanRestAuth` のフィールドを除去する場合のみ更新（挙動は不変） |
| サーバー | `cable_subscription_auth.rs:121`（`session()` の `member_organization_ids: vec![]`）と `:126-164` のテスト | `CableSessionContext` の変更に伴い更新。`test-common` の対象外 |

**文書（更新・追記が必要）**

| 文書 | 箇所 | 変更 |
|------|------|------|
| `docs/adr/ADR-002-organization-multi-tenancy.md` | Status（`:3-5`）、§3「リソース共有」（`:54`）、Migration phases 6（`:127`）、Context（`:15`） | Plan の共有を撤回した旨を追記（または新 ADR への参照。P11） |
| `docs/design/organization-data-model.md` | ロール表（`:39-41`）、Tier 1 の `cultivation_plans`（`:51`）、ER 図（`:114`） | `member` の「org 内リソースの CRUD」から Plan を除外する注記。Plan は `organization_id` 列を持つが権限判定には使わない旨 |
| 新 ADR（P11 (b) の場合） | `docs/adr/`（採番は既存に合わせる） | §3.3 の内容。再開条件を含める |
| `docs/README.md` | ADR 一覧（`:6-8`） | 新 ADR を足す場合のみ |
| `docs/spec-defects/01-resource-limit-bypass.md` | §2.4、R10、手順 10・12（backfill 拡張） | Plan 系では不要になった旨を注記（01 の改訂で対応。本書は編集しない） |
| `docs/spec-defects/09-stale-design-docs.md` | ADR-002 / organization-data-model の乖離 | 本決定の反映を 09 の対象に加える（§10） |
| `docs/spec-defects/07-frontend-error-contract.md` | 組織メンバーに対する認可失敗 | 縮小後は組織メンバーの Plan 操作が 404 になる点の確認（§10） |
| `ARCHITECTURE.md` / `docs/architecture/LAYER-RULES.md` | — | Plan の組織共有に触れる記述は `rg` で見つからなかった（`ARCHITECTURE.md:46` の bounded contexts 一覧のみ）。更新不要の見込み |

### 4.2 既存データへの影響

コードで確認した事実:

- Plan の `organization_id` を書くのは backfill だけである（§2.3）。backfill が使う組織は、対象ユーザーの **personal org** である（`personal_organization_sqlite_gateway.rs:50-59`。`is_personal = 1` の組織を探し、無ければ作成）。したがって、アプリの通常フローで Plan に入る `organization_id` は、所有者の personal org の ID だけである。非 personal 組織（ユーザーが作成できる: `organizations.rs:44`、`organization_create_interactor.rs:54-59`）に Plan が属する経路は、コード上は確認できない（SQL 直挿入や、削除 undo 復元でスナップショットの列が戻る経路は**未精査**）。R4 の `seed_org_scoped_plan` は SQL で直接挿入している（`support.rs:1882-1897`）。
- 組織 Plan の共有が成立する条件は、(1) Plan の `organization_id` が非 NULL で、かつ (2) その組織に所有者以外のメンバーがいることである。通常フローでは、(2) は「personal org に他ユーザーが追加された」場合に限る。追加を止めるガードは無い（`organization_membership_create_interactor.rs:47-97`）。API は所有者/管理者が使える（`organizations.rs`、R4 `contracts.rs:3940`）。
- 反対に、NULL の Plan（backfill 前に作られたもの、plan-save が作ったもの: 01 §2.4）は、現状でも所有者のみで、縮小の影響を受けない。
- **縮小で挙動が変わる相手**: personal org に追加されたメンバーは、所有者の Plan の一覧・詳細・作業実績ほかが見えなくなり、編集・削除もできなくなる。所有者の Farm / Crop は（P9 が未決のため）引き続き見える。組織メンバー自身が作った Plan は、自分の user_id で所有者のみのため影響しない。
- データの変更は不要。Plan・作業実績・タスクスケジュール・分散学習の行は所有者のもののまま残る。メンバーが他人の Plan に追加した作業実績・タスクは、Plan とともに所有者のものとして残り、メンバーからは見えなくなる。`work_records` には操作者の列が無く（`V5__work_records.sql:1-17`）、誰が作ったかを後から特定できない。
- 既に確立された Cable 購読は、WebSocket 接続時に組織 ID を一度解決する（`resolve_cable_session` `cable.rs:398-408`、呼び出し `:418`）。購読時の判定は `cable.rs:483`。縮小後は新規の購読が拒否される。接続済みの購読が残るかどうかは**未確認**。
- ロールバック: 縮小を戻せば共有は復活する（列とメンバーシップを消さないため）。

未確認（本番データに依存）:

- 本番に、所有者以外のメンバーがいる組織に属する Plan があるか、その数（U14）。
- 組織メンバーが他メンバーの Plan を実際に閲覧・編集した履歴。閲覧のログは確認していない。編集は、削除だけが `deletion_undo_events.deleted_by_id` で部分的に追える（§4.3 のクエリ 7）。

### 4.3 本番データ確認の手順案（読み取り専用）

前提: [`production-primary-sqlite-query`](../../.cursor/skills/production-primary-sqlite-query/SKILL.md) のとおり、GCS の Litestream レプリカから復元した DB に対して `sqlite3` を**読み取りのみ**で実行する。書き込みは行わない。レプリカは本番ライブより遅れる可能性がある。

```bash
DBPATH=$(KEEP_DB=1 ./.cursor/skills/production-primary-sqlite-query/scripts/query_production_primary_sqlite.sh)
sqlite3 -readonly -header -column "$DBPATH" "<SQL>"
```

各 SQL は、`V16__organizations.sql`、`V5__work_records.sql`、`V1__baseline.sql`（`deletion_undo_events`）のスキーマと `schedule.rs` のスナップショット構造を読んで書いた案であり、**実データに対して実行していない**（列名の誤りがあれば実行時に判明する）。

```sql
-- 1. Plan の organization_id の分布（NULL は縮小の影響なし）
SELECT plan_type,
       CASE WHEN organization_id IS NULL THEN 'null' ELSE 'set' END AS org,
       COUNT(*) AS plans
FROM cultivation_plans
GROUP BY plan_type, org;

-- 2. organization_id が非 NULL の私有 Plan の所属組織の種別（is_personal = -1 は組織行が無い Plan）
SELECT COALESCE(o.is_personal, -1) AS is_personal, COUNT(*) AS plans
FROM cultivation_plans cp
LEFT JOIN organizations o ON o.id = cp.organization_id
WHERE cp.plan_type = 'private' AND cp.organization_id IS NOT NULL
GROUP BY 1;

-- 3. 共有されている Plan（所有者以外のメンバーがいる組織に属する私有 Plan）の一覧。縮小で見えなくなる相手
SELECT cp.id AS plan_id, cp.user_id AS owner_id, cp.organization_id, o.is_personal,
       m.user_id AS other_member_id, m.role, m.created_at AS joined_at
FROM cultivation_plans cp
JOIN organizations o ON o.id = cp.organization_id
JOIN organization_memberships m ON m.organization_id = cp.organization_id
WHERE cp.plan_type = 'private' AND m.user_id <> cp.user_id
ORDER BY cp.organization_id, cp.id, m.user_id;

-- 4. 3 の組織単位の集計
SELECT cp.organization_id, o.is_personal,
       COUNT(DISTINCT cp.id) AS shared_plans,
       COUNT(DISTINCT m.user_id) AS other_members
FROM cultivation_plans cp
JOIN organizations o ON o.id = cp.organization_id
JOIN organization_memberships m ON m.organization_id = cp.organization_id
WHERE cp.plan_type = 'private' AND m.user_id <> cp.user_id
GROUP BY cp.organization_id, o.is_personal;

-- 5. メンバーが 2 人以上の組織（personal / 非 personal を含む。Farm / Crop の共有（P9）や 01 の共有枠にも関係する）
SELECT o.id, o.is_personal, COUNT(m.id) AS members
FROM organizations o
LEFT JOIN organization_memberships m ON m.organization_id = o.id
GROUP BY o.id
HAVING members > 1
ORDER BY members DESC;

-- 6. Plan の organization_id が所有者の所属と食い違うもの（データの不整合。0 件が期待値）
SELECT cp.id, cp.user_id, cp.organization_id
FROM cultivation_plans cp
WHERE cp.organization_id IS NOT NULL
  AND NOT EXISTS (
    SELECT 1 FROM organization_memberships m
    WHERE m.organization_id = cp.organization_id AND m.user_id = cp.user_id
  );

-- 7. 所有者以外による Plan 削除の実績（削除 undo イベント。snapshot の構造は schedule.rs の cultivation_plan_snapshot に基づく）
SELECT e.id, e.state, e.created_at, e.deleted_by_id,
       json_extract(e.snapshot, '$.attributes.user_id') AS owner_id,
       json_extract(e.snapshot, '$.attributes.organization_id') AS organization_id
FROM deletion_undo_events e
WHERE e.resource_type = 'CultivationPlan'
  AND e.deleted_by_id IS NOT NULL
  AND e.deleted_by_id <> json_extract(e.snapshot, '$.attributes.user_id');
```

判定の目安（P10 の判断材料）:

- クエリ 3 が 0 件: 現時点で共有されている Plan は無く、縮小の影響を受けるユーザーはいない。即時に縮小してよい。
- 1 件以上: 該当ユーザー（`other_member_id`）に、Plan が見えなくなることを事前に連絡するかを決める（P10）。個人情報を含むため、結果は Issue やコミットに貼らず、件数と種別のみを記録する。
- クエリ 5 で personal org にメンバーが 2 人以上いる場合: P13（personal org へのメンバー追加のガード）を優先して起票する。
- クエリ 6 が 1 件以上: backfill 以外の書き込み経路が存在する可能性があるため、§4.2 の「Plan の `organization_id` を書くのは backfill だけ」を再確認する。

---

## 5. 対応方針（層ごとの変更）

方針は R0（Policies が認可、Gateways は取得のみ）に従う。

### 5.1 D5（最優先）

| 層 | 変更 |
|----|------|
| Domain policy | `plan_field_cultivation_access.rs` の `assert_edit_allowed` を `assert_view_allowed` から分離する。編集は「私有 Plan かつ（所有者または admin）」のみ許可し、公開 Plan は私有ルートからの編集を拒否する。**組織メンバーの許可は入れない**（決定） |
| Domain DTO | `FieldCultivationPlanAccessSnapshot` に `organization_id` を**追加しない** |
| Domain interactor | `FieldCultivationUpdateInteractor` の私有経路で、公開 Plan は Forbidden にする。公開経路は既存の `assert_public_field_cultivation_mutation_access` を維持 |
| Gateway（SQLite） | 変更なし（取得と UPDATE のみ。認可を足さない） |
| Edge（axum） | `field_cultivations.rs:214-250` は変更しない（判定はドメイン側で行う） |

### 5.2 D2（確定: Plan 系は閲覧・編集とも所有者のみが正）

| 層 | 変更 |
|----|------|
| Edge（`data` と編集系 4 箇所） | `cultivation_plans.rs:75`、`cultivation_plans_mutations.rs:320,440,546,751` の `CultivationPlanRestAuth::private(user_id)` は**変更しない**。「組織メンバーにも許す」ための `private_with_scope` への置換は行わない |
| Domain（防御の明示化） | `private(user_id)` が所有者のみになるのは、組織 ID が空だから、という暗黙の性質に依存していた（§2.3）。§5.7 で `CultivationPlanRestAuth` から組織 ID のフィールドと `private_with_scope` を**取り除く**ため、この暗黙の依存は構造上なくなる。旧案の `RestPlanAccessIntent::{View, Edit}`（閲覧と編集の意図の区別）は**不要になったので採らない** |
| 圃場栽培の `climate_data` | 変更なし。スナップショットに `organization_id` を持たせる案（旧 P1 (a)）は撤回 |
| Domain policy | `private_cultivation_plan_access_policy.rs` は §5.7 で組織 ID の引数を除去する |

### 5.3 D1（R0 準拠設計）

現状の流れ:

```
crop_ai_create_interactor.rs:90-91  → フィルターを作る
  → persistence.upsert(&user, .., access_filter)   … 渡すだけ
     → crop_ai_upsert_sqlite_persistence.rs:195     … アダプターが assert_edit_allowed
```

目標の流れ:

```
CropAiCreateInteractor
  1. persistence(取得専用メソッド)で crop_id の既存 Crop を取得
  2. crop_policy / reference_record_authorization で assert_edit_allowed を interactor が評価
  3. 拒否 → P6 の決定に従い Forbidden、または作成に進む
  4. 許可 → persistence.upsert(target = Update{crop_id} | Create) に「解決済みの意図」だけ渡す

アダプター
  - 取得と保存のみ。access_filter を受け取らない
```

| 層 | 変更 |
|----|------|
| Domain port | `CropAiUpsertPersistencePort` から `access_filter` 引数を削除する。取得専用メソッド（例: `find_crop_for_update(crop_id) -> Option<CropEntity>`）と、更新／作成の対象を表す値（例: `CropAiUpsertTarget::{Create, Update(i64)}`）を追加する（R3: 狭いゲートウェイ） |
| Domain interactor | `crop_ai_create_interactor.rs:90-91` の位置で取得→policy 評価→ターゲット決定を行う |
| Domain policy | 作成上限の判定（`crop_create_limit_policy::limit_exceeded`）も interactor へ移す（`crop_ai_upsert_sqlite_persistence.rs:177` の同一系統違反）。関連: [`01-resource-limit-bypass.md`](01-resource-limit-bypass.md) |
| Adapter | `find_existing_crop_for_update` を取得のみに変える。`reference_record_authorization` の import（`:20`）を削除 |
| 範囲判断 | #323 で API が廃止されるなら、この改修は廃止で消える。**廃止時期が近い場合は、廃止を待つか、R0 違反として先に直すかをユーザーが決める**（P6 と併せて確認） |
| 決定との整合 | D1 は Crop の認可であり、決定（Plan 系は所有者のみ）の適用範囲外。組織メンバーの Crop 編集は現行の #612 仕様（R4 `contracts.rs:4242`）を維持する（P9） |

補助として、アダプター層の認可再発を防ぐため、`scripts/run-architecture-guard-lib.mjs` に「`crates/agrr-adapters-*` で `reference_record_authorization` / `*_policy::*_allowed` を参照しない」ルールを足す案がある。現状のガードは R6 とフロントのルールが中心で、アダプター認可の機械検出は無い（**未確認**: ガードの全ルールを読み切ってはいない）。ガード追加は必須とせず、任意の項目とする。

### 5.4 D3（所有者のみ判定を確定、削除案を維持）

| 案 | 内容 |
|----|------|
| 削除案（推奨・維持） | 本番の呼び出し元が無いことを再確認したうえで、`schedule_authorization.rs`、`DeletionUndoScheduleInteractor`、`find_schedulable_record`（ゲートウェイのトレイトとアダプター実装）、関連テストを削除する（`project-necessary-code-only`）。`TaskScheduleItemScheduleDeletionUndoInteractor` と `DeletionUndoSchedulePort` も本番未使用のため、同時に整理するか別 issue にするかを U4 の再確認後に決める。削除の是非はユーザー確認（P7） |
| ~~組織対応案~~（採らない） | 決定に反するため採用しない。`SchedulableRecord` に `plan_organization_id` を足す変更は行わない |
| 非対称の解消 | 「組織メンバーが Plan を削除できるが undo 予約はできない」非対称は、**削除側の縮小（D7 の S1）**で解消する。undo 側を組織対応にする案は採らない |

削除案を採る場合は、削除側の縮小（S1）と独立に進められる。削除案を採らずに配線する場合は、`schedule_allowed` の所有者のみ判定を維持し、アダプターの `find_schedulable_record` が Plan 系（`plan_type_private` と `plan_user_id`）を返すよう拡張する必要がある（現状は Plan 系に未対応。§2.6）。

### 5.5 D6

| 対象 | 変更 |
|------|------|
| Crop ネスト（#3、#4） | **変更しない**（P4 (b)）。組織メンバーへ広げる案は編集権限の拡大を伴うため、今回は採らない |
| Field（#6） | 変更しない。所有者のみで、決定より厳格 |
| Cable の Farm（#13） | `farm_subscription_denied` に `ctx.member_organization_ids` を渡し、閲覧判定のみを組織対応にする（Farm の組織スコープは #612 の対象）。**受信のみ**で編集権限を伴わないため、決定に抵触しない。任意（必須ではない） |
| Pest 等（#8〜#12） | 変更しない（P5 (a)）。展開が決まった時点で別 issue |

### 5.6 D4

推奨は P8 (b): 設計として文書化する。読み取りの無認証公開を維持し、次を記載する。

- 共有リンクとしての意図。
- ID が連番で列挙可能であること。
- 応答に含めない情報の一覧（個人情報が含まれないことの確認は別途）。

記載先の候補は `docs/api/`（該当エンドポイントの説明）または ADR。どちらにするかは既存文書の構成に依存するため未決。対策 (c) は共有リンクの仕様確定後の別課題とする。

### 5.7 D7（過剰許可の是正: 閲覧・編集とも所有者のみへ縮小）

第 2 回決定により、閲覧用と編集用の判定を分ける必要は無い。**組織 ID を判定から取り除く**ことで、S1〜S5 と V1〜V11 が同時に所有者のみになる。

| 層 | 変更 |
|----|------|
| Domain policy | `private_cultivation_plan_access_policy.rs` に、組織 ID を受け取らない所有者判定（例: `owner_access_denied(plan, user_id)`。私有かつ `plan.user_id == user_id` のみ許可）と `assert_private_owned` 相当（`user` と `plan` のみ）を追加する。移行の最後に、組織 ID を受け取る現行の `access_denied` / `assert_private_owned`（`:8-37`）を削除する。名称の `assert_private_owned` は、組織 ID を外せば実態と一致する |
| Domain helper | `work_record/interactors/private_plan_access.rs:11-17` と `cultivation_plan/interactors/task_schedule_private_plan_access.rs:11-17`（同一の実装が 2 か所にある）から `member_organization_ids` 引数を除去する。2 つの統合は振る舞い不変の別リファクタで、本課題では行わない |
| Domain interactor（25 個。§2.9.3） | 所有者判定を呼び、**`scope_gateway` の注入と `member_organization_ids` の解決を外す**。未使用の引数を残さない（`project-necessary-code-only`）。呼び出し元のハンドラーとテストのフィクスチャ（`EmptyScopeGateway`）も同じ変更で更新する |
| Domain DTO | `CultivationPlanRestAuth` から `member_organization_ids` と `private_with_scope` を除去する（`cultivation_plan_rest_auth.rs:13,24,29-33,42,51`）。`rest_plan_access::evaluate`（`rest_plan_access.rs:21-25`）は所有者判定を呼ぶ。読み手のもう 1 つ `crop_rows_available_private_gateway.rs:43` は、呼び出し元が `private(user_id)`（組織 ID 空）だけであるため、`organization_ids: vec![]` に置き換えても挙動は変わらない（Crop 側のゲートウェイだが、フィールド除去に伴う機械的な変更。Crop の組織スコープの方針（P9）は変えない） |
| Gateway（SQLite） | V1 / V9 の一覧 SQL（`private_read_gateway.rs:32-34`）を `WHERE cp.plan_type = 'private' AND cp.user_id = ?1` のみにする。**現状は認可の一部（組織共有）が SQL の条件に埋まっている**。縮小後は「所有者 ID による狭い永続化クエリ」（ADR-002 §4、R0）になる。メソッド名 `list_private_plan_index_rows_by_user_id` は実態と一致する。他の Gateway は変更しない |
| Edge（cable） | `CableSessionContext` から `member_organization_ids` を除去（`cable_subscription_auth.rs:17`）。`plan_subscription_denied` は `PlansOptimizationChannel` で `CultivationPlanRestAuth::private(ctx.user_id)`、`OptimizationChannel` で所有者判定を使う。`resolve_cable_session`（`cable.rs:398-408`）の組織スコープ解決と、未使用になる import（`cable.rs:8,17`）を除く。Farm 購読（`cable_subscription_auth.rs:59`）は変更しない（範囲外） |
| Edge（写真） | `work_record_photos.rs:329-340`（`upload_content`）と `:423-434`（download）は、ハンドラー内で `plan_access_allowed` を直接呼ぶ構成（ハンドラーが認可を呼ぶ形は現行のまま）。組織 ID の引数と scope gateway の生成（`:329,423`）を除く。`upload_init` / `upload_complete` / `destroy_photo`（`:271,385,470`）は interactor のコンストラクタ変更に追随する |
| Edge（その他のハンドラー） | `task_schedules.rs:165,301,358,421`、`work_records.rs:286,321,365,408`、`plan_variance_learning.rs:173,323,562,610`、`plan_vs_actual.rs:72`、`variance_portfolio.rs:97`、`weather_reschedule_proposals.rs:125,200`、`plans.rs:186,487` の scope gateway の生成と引数渡しを除く |
| 応答の互換 | 非所有者に対する応答は、現行の「所有者でも組織メンバーでもない」ときと同じ 404 系にする（新しい 403 を導入しない）。一覧（V1）は、他メンバーの Plan が単に含まれなくなる。Cable は購読拒否（`cable.rs:483` の `reject_subscription`）になる |
| 残すもの | `organization_member_access`、`member_organization_ids`、`UserOrganizationScopeGateway` 系、Organization / Membership の API と表、`cultivation_plans.organization_id` 列（§2.9.3、§3.3）。Farm / Crop が使うため、または再開条件のため |
| 触らないもの | Farm / Crop の組織スコープ（P9）、Crop の `CropFindPrivatePlanAddCropRecordInteractor`（`add_crop_support.rs:32,48,126`: 所有者が組織共有の Crop を自分の Plan に追加する経路。Crop の共有であり Plan の共有ではない） |

### 5.8 補足: 過剰許可の回帰を防ぐ機械的な確認

縮小後、次を `rg` で確認する（受け入れ条件 A13）。ガードスクリプトへの追加は任意とし、必須にしない。

- `rg "member_organization_ids|organization_member_access|private_with_scope" crates/agrr-domain/src/cultivation_plan crates/agrr-domain/src/work_record` のヒットが 0 件。
- `rg "member_organization_ids|UserOrganizationScope" crates/agrr-server/src/{cable,cable_subscription_auth,work_record_photos,work_records,task_schedules,plan_variance_learning,plan_vs_actual,variance_portfolio,weather_reschedule_proposals,plans}.rs` のヒットが 0 件。
- `rg "organization" crates/agrr-adapters-sqlite/src/cultivation_plan/private_read_gateway.rs` のヒットが 0 件（テスト内の表作成を除く）。

---

## 6. TDD 計画（RED の失敗テスト）

規約: 実装より先に RED を書き、`test-common` のスクリプトで RED を確認してから GREEN に進む（[`tdd-on-edit`](../../.cursor/skills/tdd-on-edit/SKILL.md)）。テストは次のスクリプトのみで実行する。`bundle exec rails test` と直接の `npm test` は使わない。

| 対象 | スクリプト |
|------|-----------|
| agrr-domain（＋`agrr-migrate`） | `.cursor/skills/test-common/scripts/run-test-rust-domain.sh` |
| R4 契約 | `scripts/run-rust-contract-tests.sh` |

実行方法は AGENTS.md に従い、出力を `./tmp/{UUID}.log` へリダイレクトし、その後に grep で結果を読む（テストランナーを grep や tail にパイプしない）。

**制約（確認済み）**: `run-test-rust-domain.sh` は `cargo test -p agrr-domain "$@"` と `cargo test -p agrr-migrate --quiet` を実行する。`agrr-adapters-sqlite` と `agrr-server` のユニットテストは `test-common` のスクリプトに含まれない。CI（`.github/workflows/rust-domain-test.yml:51-58`）はアダプターを `_gateway_test` フィルターでのみ実行する。したがって、RED は**ドメインテストと R4 契約テスト**に置く。アダプターのみでしか検証できないものは、その旨を明記し、`test-common` 経由で実行できない点を残す。

テスト名とパスは**案**であり、既存の命名（`interactors_<name>_test.rs`、`policies_<name>_test.rs`、src 側 `include!`）に合わせる。

**テストの種類**: 「RED」は現行の実装で失敗するテスト。「特性化」は現行で GREEN のまま維持することを固定するテストで、RED を要しない（回帰防止）。

### 6.1 D5

| ID | パス案 | given / when / then | 種類 / ランナー |
|----|--------|---------------------|----------|
| T5-1 | `crates/agrr-domain/test/field_cultivation/policies_plan_field_cultivation_access_test.rs`（既存ファイルの有無は**未確認**。無ければ新規） | given 公開 Plan のスナップショット、所有者でも admin でもない User / when `assert_edit_allowed` / then `Err(PolicyPermissionDenied)`。現行は `Ok` のため RED | RED / `run-test-rust-domain.sh` |
| T5-2 | 同上 | given 公開 Plan、User / when `assert_view_allowed` / then `Ok`（読み取りは維持。回帰防止） | 特性化 / 同上 |
| T5-3 | `crates/agrr-domain/test/field_cultivation/interactors_field_cultivation_update_interactor_test.rs`（既存の有無は**未確認**） | given 公開 Plan の圃場栽培、`with_user` で所有者でないユーザー、`public_plan = false` / when `call` / then `on_failure(Forbidden)`、ゲートウェイの更新が呼ばれない（スパイで 0 回）。現行は更新が呼ばれるため RED | RED / 同上 |
| T5-4 | `crates/agrr-r4-contract/tests/contracts.rs` に追記 | given 公開 Plan（`seed_public_cultivation_plan_with_session`、`support.rs:1918`）と別ユーザーのセッション / when `PATCH /api/v1/plans/field_cultivations/{id}` / then 403 または 404、DB の日付が不変。現行は 200 になる疑いのため RED | RED / `run-rust-contract-tests.sh` |
| T5-5 | 同上 | given 公開 Plan と一致するセッション / when 公開 PATCH ルート / then 200（回帰防止。既存の `public_plan_mutation_rejects_mismatched_session` `contracts.rs` 約 4423 行と対で置く） | 特性化 / 同上 |
| T5-6 | 同上 | given 私有 Plan の所有者 / when PATCH / then 200（回帰防止） | 特性化 / 同上 |
| T5-7 | 同上 | given 組織 Plan（`seed_org_scoped_plan`）と組織メンバー（非所有者）/ when 私有 PATCH / then 404 または 403、DB の日付が不変（決定「組織メンバーに編集を与えない」を圃場栽培でも固定する。現行で GREEN の見込みだが、未実行のため**未確認**） | 特性化 / 同上 |

### 6.2 D2（Plan 系は所有者のみを固定。特性化）

| ID | パス案 | given / when / then | 種類 / ランナー |
|----|--------|---------------------|----------|
| T2-1 | `crates/agrr-r4-contract/tests/contracts.rs`（`org_member_cannot_add_crop / add_field / remove_field / adjust_on_team_plan`） | given `seed_org_scoped_plan(org, owner)`、`org` のメンバー `member`（`seed_organization_membership`、`support.rs:1721`） / when 各 POST・DELETE（member のセッション）/ then 404 かつ DB 不変。**現行で GREEN の見込み**（`private(user_id)` により所有者のみ。未実行のため**未確認**）。決定を固定する特性化テストであり、DTO から組織 ID を除去する変更（§5.7）の回帰防止になる。`adjust` は最適化バイナリ（`lib/core/agrr`）を要するかが**未確認**のため、認可のみを確認できる入力（不正入力で 422 になる等）を使う | 特性化 / `run-rust-contract-tests.sh` |
| T2-2 | 同上 | given 同じ組織 Plan、所有者 / when 同じ各 API / then 認可は通り、認可以外の入力検証結果が返る（404 でないこと） | 特性化 / 同上 |
| T2-3 | 同上（`org_member_gets_404_for_team_plan_data`） | given 組織 Plan、member / when `GET /api/v1/plans/cultivation_plans/{id}/data` / then **404**（D2 の確定: 仕様どおり）。現行で GREEN の見込み（`private(user_id)`。未実行のため**未確認**）。旧案の「200 になる RED」は撤回 | 特性化 / 同上 |
| T2-4 | 同上（`non_member_gets_404_for_org_scoped_plan_data`） | given 同じ Plan、org に属さないユーザー / when 同 GET / then 404（過剰許可の防止） | 特性化 / 同上 |
| T2-5 | 同上（`org_member_gets_404_for_team_plan_field_cultivation_climate_data`） | given 組織 Plan の圃場栽培（既存のシード関数の有無は**未確認**。無ければ `seed_org_scoped_plan` に圃場栽培の行を足す）、member / when `GET /api/v1/plans/field_cultivations/{id}/climate_data` / then 404（D2 の確定）。現行で GREEN の見込み（スナップショットに組織 ID が無い: `field_cultivation_plan_access_snapshot.rs`。未実行のため**未確認**） | 特性化 / 同上 |

### 6.3 D1

| ID | パス案 | given / when / then | 種類 / ランナー |
|----|--------|---------------------|----------|
| T1-1 | `crates/agrr-domain/test/crop/interactors_crop_ai_create_interactor_test.rs` に追記 | given 他ユーザー所有の非参照 Crop の `crop_id` を含む入力、フェイク永続化（取得メソッドが該当 Crop を返し、`upsert` の対象を記録） / when `call` / then P6 (b) なら `on_failure(Forbidden)` かつ `upsert` 未呼び出し、P6 (a) なら `upsert` のターゲットが `Create`。現行は interactor が評価しないため RED（新ポートメソッドが未定義でコンパイルエラーになる。RED はコンパイル失敗を含む点に注意） | RED / `run-test-rust-domain.sh` |
| T1-2 | 同上 | given 自分の Crop の `crop_id` / when `call` / then `upsert` のターゲットが `Update(crop_id)` | RED / 同上 |
| T1-3 | 同上 | given 組織メンバーの Crop の `crop_id`（`EmptyScopeGateway` ではなく組織 ID を返すフェイクスコープ）/ when `call` / then `Update`（Crop の組織スコープ許可は現行仕様を維持。P9） | RED / 同上 |
| T1-4 | 同上 | given 作成上限に達したユーザー、`crop_id` なし / when `call` / then 上限超過が interactor で判定される（上限判定の移設。関連: 01） | RED / 同上 |
| T1-5 | アダプター側 `crop_ai_upsert_sqlite_persistence.rs` のテスト | 認可を評価しないこと（他人の crop_id でも取得のみで拒否しない）。`test-common` の対象外のため、実行は `cargo test -p agrr-adapters-sqlite` を別途行う必要がある。**規約上の実行入口が無い点は未解決**（§8.2） | （対象外） |
| T1-6 | `crates/agrr-r4-contract/tests/contracts.rs` | AI Crop 作成エンドポイントの契約テストの有無は**未確認**。あれば、他人の `crop_id` で P6 の決定どおりの応答になることを追加する | `run-rust-contract-tests.sh` |

### 6.4 D3

| ID | パス案 | given / when / then | 種類 / ランナー |
|----|--------|---------------------|----------|
| T3-1 | `crates/agrr-domain/test/deletion_undo/schedule_authorization_test.rs`（既存。`schedule_authorization.rs:65` の `include!` 先） | 削除案を採らない場合のみ: given 組織 Plan に属する CultivationPlan、所有者でない組織メンバー / when `schedule_allowed` / then **false**（所有者のみが正であることを固定する特性化テスト）。既存テストがすでに同等の検証をしているかは**未確認** | 特性化 / `run-test-rust-domain.sh` |
| T3-2 | 同上 | 削除案を採る場合: 対象コードとテストの削除のみ。RED は不要（振る舞い不変の削除。`tdd-on-edit` の例外に該当）。削除後に全体テストが GREEN であることを確認する | — / 同上 |

### 6.5 D6

| ID | パス案 | given / when / then | 種類 / ランナー |
|----|--------|---------------------|----------|
| T6-1 | `crates/agrr-r4-contract/tests/contracts.rs`（Cable テスト群、約 4356-4420 行に追記。任意） | given 組織 Farm、org メンバーの Cable セッション / when Farm 購読 / then 購読が許可される（閲覧のみ。#13 を実施する場合）。`agrr-server` の `cable_subscription_auth.rs` のユニットテスト（`:121` 付近）は `test-common` の対象外 | RED（#13 実施時のみ）/ `run-rust-contract-tests.sh` |
| T6-2 | 同上 | given 組織 Crop、member / when `GET /api/v1/masters/crops/{id}/pests` 等のネスト API / then 現行どおり 404（P4 (b) を固定する特性化テスト。現行で GREEN の見込み。未実行のため**未確認**） | 特性化 / 同上 |

### 6.6 D4

コード変更なし（文書化のみ）。RED は不要。既存の公開 Plan 読み取り・変更系の契約テスト（`contracts.rs` 約 4423 行の `public_plan_mutation_rejects_mismatched_session` など）が回帰しないことを、全体実行で確認する。

### 6.7 D7（縮小の RED: 組織メンバーが他メンバー Plan を閲覧・編集できない各経路）

前提: 現行の interactor テストは `EmptyScopeGateway` と `organization_id: None` のみを使う（§2.3）。RED を書くには、**組織 ID を返すフェイクのスコープゲートウェイ**（例: `MemberScopeGateway { org_ids: vec![42] }`）と、`organization_id = Some(42)` の他ユーザー所有 Plan のフィクスチャが必要になる。これは現行のコンストラクタ（`scope_gateway` あり）で書けるため、**振る舞いの RED（組織メンバーが許可されてしまう）をコンパイルエラーではなく assert の失敗として確認できる**。GREEN で `scope_gateway` をコンストラクタから外す場合は、テストも同じコミットで更新する（未 GREEN のコミットを残さない）。

**各経路の RED 一覧（V 系・S 系の全数を網羅する）**

| ID | 経路 | パス案 | given / when / then | 種類 / ランナー |
|----|------|--------|---------------------|----------|
| T7-1 | 基盤（policy） | `crates/agrr-domain/test/cultivation_plan/policies_private_cultivation_plan_access_policy_test.rs`（既存に追記・書き換え） | 所有者判定（§5.7）: given 私有 Plan（`organization_id = Some(42)`、所有者 5）/ when 所有者 5 / then 許可。ユーザー 99（組織 42 のメンバー）/ then **拒否**。組織外ユーザー / then 拒否。公開 Plan / then 拒否。既存の組織メンバー許可テスト（`:69`、`:89`）は「組織メンバーでも拒否」へ書き換える。新関数が未定義のため RED（コンパイル失敗を含む） | RED / `run-test-rust-domain.sh` |
| T7-2 | S1 Plan 削除 | `interactors_cultivation_plan_destroy_interactor_test.rs`（既存に追記） | given 組織 42 の Plan（所有者 5）、`MemberScopeGateway` が 42 を返すユーザー 99 / when `call` / then `on_failure` が not_found 相当、ゲートウェイの `delete` が 0 回。所有者の削除は成功。現行は組織メンバーが削除できるため RED | RED / 同上 |
| T7-3 | S2 タスクスケジュール変更 | `interactors_task_schedule_item_{create,update}_interactor_test.rs`（**存在しない**ため新規）、`interactors_task_schedule_item_skip_interactor_test.rs`（skip / unskip。既存）、`interactors_regenerate_task_schedule_interactor_test.rs`（既存） | 同じ given / when 各 `call` / then `on_not_found`、変更用ゲートウェイ（`skip_item_for_plan` など）と enqueue が 0 回。所有者は成功 | RED / 同上 |
| T7-4 | S3 作業実績と写真の変更 | `interactors_work_record_{create,update,destroy}_interactor_test.rs`（既存）、`interactors_work_record_photo_upload_init_interactor_test.rs`（既存）、`..._photo_upload_complete_...`、`..._photo_destroy_...`（**存在しない**ため新規） | 同じ given / when `call` / then not_found、永続化が 0 回。`upload_content` はハンドラー内の判定のため R4（T7-7）で固定 | RED / 同上 |
| T7-5 | S4 分散学習の更新 | `interactors_plan_variance_learning_{proposal_progress,orchestration_progress,handoff}_update_interactor_test.rs`、`..._reoptimize_interactor_test.rs`、`interactors_plan_variance_carryover_interactor_test.rs`（すべて既存） | 同じ given / when `call` / then not_found（carryover は書き込み先の Plan で `RecordNotFoundError`）、`upsert_*` / `save` / enqueue が 0 回 | RED / 同上 |
| T7-6 | S5 プレビュー | `interactors_weather_reschedule_proposal_preview_interactor_test.rs`（既存。`:23,31` に `EmptyScopeGateway`） | given 組織 42 の Plan、`MemberScopeGateway` のユーザー 99 / when プレビュー `call` / then 上流ゲートで `RecordNotFoundError`。**adjust が呼ばれないこと**をスパイで検証（現行は上流を通過して下流の adjust で not found になるため RED） | RED / 同上 |
| T7-7 | S1〜S4 の代表（HTTP） | `crates/agrr-r4-contract/tests/contracts.rs` に追記 | given `seed_user_organization`（`support.rs:1697`）と `seed_organization_membership(.., "member")`（`:1721`）と `seed_org_scoped_plan`（`:1882`）、member のセッション / when `DELETE /api/v1/plans/{id}`、`POST /api/v1/plans/{id}/work_records`、`POST .../task_schedule/items`、`PATCH .../task_schedule/items/{item_id}/skip`、`POST .../task_schedule/regenerate`、`PATCH .../variance_learning`、`POST .../variance_learning/reoptimize`、`PUT .../photos/{photo_id}/content` / then 404 で DB 不変。現行は 200 系のため RED。所有者は 200 系（特性化） | RED / `run-rust-contract-tests.sh` |
| T7-8 | V2 詳細（HTTP） | 同上。既存の `org_member_can_view_team_plan`（`:4306`）を**反転**して `org_member_cannot_view_team_plan` に改名 | given 組織 Plan、member / when `GET /api/v1/plans/{id}` / then 404。現行は 200 のため RED。非メンバーは 404（既存 `org_non_member_denied_team_plan` `:4332`。回帰防止） | RED / 同上 |
| T7-9 | V3〜V8 の閲覧（domain） | `interactors_task_schedule_timeline_interactor_test.rs`、`interactors_plan_vs_actual_summary_interactor_test.rs`、`interactors_plan_variance_learning_read_interactor_test.rs`、`interactors_private_owned_plan_detail_interactor_test.rs`（いずれも**存在しない**ため新規）、`interactors_work_record_list_interactor_test.rs`（既存）、`interactors_weather_reschedule_proposals_list_interactor_test.rs`（**存在しない**ため新規）。carryover の元 Plan は `interactors_plan_variance_carryover_interactor_test.rs`（既存。元 Plan が他メンバー所有なら `carryover_source_not_found` の `RecordInvalidError`。V11） | given 組織 42 の Plan、ユーザー 99 / when `call` / then not_found（詳細・timeline・予実・分散学習・提案一覧・作業実績一覧）、gateway の読み取りが 0 回。所有者は成功。現行は組織メンバーが許可されるため RED | RED / `run-test-rust-domain.sh` |
| T7-10 | V3〜V8 の閲覧（HTTP） | `contracts.rs` に追記 | given 同じ組織 Plan、member / when `GET .../task_schedule`、`GET .../work_records`、`GET .../plan_vs_actual/summary`、`GET .../variance_learning`、`GET .../weather_reschedule_proposals`、`GET .../photos/{photo_id}/content` / then 404。現行は 200 系のため RED | RED / 同上 |
| T7-11 | V1 一覧・V9 ポートフォリオ（HTTP） | `contracts.rs` に追記（`get_work_variance_portfolio_returns_farm_plan_rows_with_variance_stats` `:118` の近傍） | given 組織 Plan（所有者 A）、member B / when B が `GET /api/v1/plans` と `GET /api/v1/work/variance_portfolio` / then A の Plan が**含まれない**。A 自身の一覧には含まれる。現行は含まれるため RED。アダプター側の SQL は `private_read_gateway_test.rs` にも追加するが `test-common` の対象外（実行は `cargo test -p agrr-adapters-sqlite` を別途） | RED / 同上 |
| T7-12 | V9 ポートフォリオ（domain） | `interactors_variance_portfolio_interactor_test.rs`（既存） | given ゲートウェイが他メンバーの Plan 行を返すフェイク、ユーザー 99 / when `call` / then その行が結果に含まれない（再確認の判定）。現行は `MemberScopeGateway` の組織 ID で通過するため RED | RED / `run-test-rust-domain.sh` |
| T7-13 | V10 Cable | `contracts.rs` に追記（`cable_rejects_cross_user_private_plans_optimization_channel` `:4356` の近傍） | given 組織 Plan（所有者 A）、member B / when B が `PlansOptimizationChannel` と `OptimizationChannel` を購読 / then `reject_subscription`。A は `confirm_subscription`。現行は B も confirm されるため RED。`agrr-server` の `cable_subscription_auth.rs` のユニットテストにも組織メンバーのケースを足す（`test-common` の対象外） | RED / `run-rust-contract-tests.sh` |
| T7-14 | 顕在性の確認 | 同上 | given personal org の所有者と、`POST /api/v1/organizations/{personal_org_id}/memberships` で追加された別ユーザー、backfill 済みの Plan / when そのユーザーが Plan を `GET` / `DELETE` / then 縮小後は 404。**縮小前**に実行して、組織メンバーとして閲覧・削除できることを確認する（§2.3 の顕在性の裏取り。personal org へのメンバー追加自体を許すかは P13 で別課題） | RED（縮小前に実行して事実を確認）/ 同上 |
| T7-15 | 特性化（所有者・非メンバー） | 同上 | 所有者は上記の全経路で従来どおり成功。非メンバーは 404。P9 の Farm / Crop（`contracts.rs:4127` 以降）は変更しないので既存テストが GREEN のまま | 特性化 / 同上 |

**網羅の確認**: V1〜V11 は T7-8〜T7-13（V1 と V9 は T7-11、V10 は T7-13、V11 は T7-9）、S1〜S5 は T7-2〜T7-7 で固定される。S6 は D5（§6.1）、S7 は未配線のため D3（§6.4）の削除案で扱う。

### 6.8 完了時の実行

`tdd-on-edit` と `rails-testing-workflow` に従い、個別 GREEN → 全体（`run-test-rust-domain.sh` と `run-rust-contract-tests.sh`）→ 遅延検知（[`test-slow-detection`](../../.cursor/skills/test-slow-detection/SKILL.md)）の順で実行する。`crates/agrr-server/**`、`crates/agrr-domain/**`、`crates/agrr-adapters-*/**` を変更したので、Docker で検証する前に `.cursor/skills/dev-docker/scripts/rebuild-restart.sh` を実行する。

---

## 7. 実装ステップ（順序・コミット粒度）

前提: §3.1 のユーザー確認のうち、P3（admin の扱い）、P6、P10（本番データの確認: §4.3）、P11（ADR の形式）が済んでいること。P1 は第 2 回決定で確定済み、P9 は範囲外のまま（未決でも着手できる）。確認前は着手しない。ステップごとに RED → GREEN → リファクタで 1 コミットを基本とし、RED のテストは実装と同じコミットに含めてよい（未 GREEN のコミットを残さない）。

**縮小の進め方**: 全 interactor が共通ヘルパーとポリシーの組織付きの関数を呼んでいるため、それらの署名を一度に変えると全経路が同時に壊れる。そこで、(1) 組織 ID を取らない所有者判定を**追加**し、(2) 経路のグループごとに呼び出しを切り替え（RED → GREEN）、(3) 最後に組織付きの旧関数を**削除**する。各グループのコミットで、そのグループの interactor から `scope_gateway` の注入も外す。

| # | ステップ | コミット | 依存 |
|---|----------|----------|------|
| 0 | 本番データの確認（§4.3 の読み取り専用 SQL）。結果を P10 に記録する。コミットなし | — | P10 の合意 |
| 1 | D5: T5-1〜T5-7 の RED を書く → `plan_field_cultivation_access` と `FieldCultivationUpdateInteractor` を修正して GREEN | `fix(authz): forbid private-route edit of public plan field cultivations` | P3 |
| 2 | D2 の特性化テスト T2-1〜T2-5 を追加（コード変更なし）。以降の縮小・DTO 変更の回帰防止として**先に**固定する | `test(authz): pin owner-only plan data and mutations` | — |
| 3 | 縮小の土台: T7-1 の RED → 組織 ID を取らない所有者判定を `private_cultivation_plan_access_policy` と 2 つの共通ヘルパーに追加（旧関数は残し、呼び出し元はまだ切り替えない） | `refactor(authz): add owner-only plan access policy` | P3 |
| 4 | Plan グループ（S1、V1、V2、V9）: T7-14（縮小前に実行して事実を確認）、T7-2、T7-8、T7-11、T7-12 の RED → 削除・詳細・一覧の SQL・ポートフォリオを所有者のみへ | `fix(authz): restrict plan destroy, detail, list to owner` | 3、P10 |
| 5 | タスクスケジュール・提案グループ（S2、S5、V3、V8）: T7-3、T7-6、T7-9（該当分）、T7-10（該当分）の RED → 変更系・timeline・提案の一覧とプレビューを所有者のみへ | `fix(authz): restrict task schedule and reschedule proposals to owner` | 3、P10 |
| 6 | 作業実績・写真グループ（S3、V4、V5）: T7-4、T7-7（work_records と写真）、T7-9（該当分）、T7-10（該当分）の RED → 一覧・変更系・写真（`upload_content` とダウンロードのハンドラーを含む）を所有者のみへ | `fix(authz): restrict work records and photos to owner` | 3、P10 |
| 7 | 分散学習・予実グループ（S4、V6、V7、V11）: T7-5、T7-7（variance_learning）、T7-9（該当分）、T7-10（該当分）の RED → 取得・更新・reoptimize・carryover（書き込み先と元 Plan）・予実を所有者のみへ | `fix(authz): restrict variance learning and plan-vs-actual to owner` | 3、P10 |
| 8 | Cable（V10）: T7-13 の RED → `PlansOptimizationChannel` と `OptimizationChannel` を所有者のみへ。`CableSessionContext` から組織 ID を除去 | `fix(authz): restrict plan cable subscriptions to owner` | 3、P10 |
| 9 | 後始末: 組織付きの旧ポリシー・旧ヘルパー・`CultivationPlanRestAuth` の `member_organization_ids` と `private_with_scope`・`crop_rows_available_private_gateway.rs:43`・未使用の import を削除。S7（未配線の undo interactor）は D3 の削除案（ステップ 13）と同時に整理する。§5.8 の `rg` が 0 件であることを確認（A13）。振る舞い不変のため RED 不要（`tdd-on-edit` の例外） | `refactor(authz): remove organization scope from plan authorization` | 4〜8 |
| 10 | 文書: 新 ADR（または ADR-002 追記。P11）、`organization-data-model.md` の更新、01 / 07 / 09 への反映依頼（各文書の改訂側で実施）。P12 の再開条件を含める | `docs(adr): plans are owner-only; org sharing scoped to farms and crops` | P11、P12。縮小（4〜9）と同一リリースまたは直後 |
| 11 | D6 #13 Cable の Farm 購読（任意）: T6-1 の RED → `farm_subscription_denied` の修正 | `fix(authz): org-aware farm cable subscription` | 独立。任意（Farm の組織スコープ P9 の方針と整合を取る） |
| 12 | D1: T1-1〜T1-4 の RED → ポートとインタラクターの再設計 → アダプターの認可削除 | `refactor(crop-ai): move upsert authorization into interactor` | P6（#323 の廃止時期を確認したうえで着手を判断） |
| 13 | D3: 呼び出し元の再確認（U4）→ 削除案（`DeletionUndoScheduleInteractor` ほか、S7 の未配線 interactor を含む）。T3-2 | `chore(deletion-undo): remove unwired schedule authorization` | P7、4（削除側の縮小の後） |
| 14 | D4: 設計としての文書化（必要時） | `docs: document public plan share-link access model` | P8 |
| 15 | 任意: アーキテクチャガードにアダプター認可の検出を追加 | `chore(guard): forbid authorization calls in adapters` | 12 の後 |
| 16 | 全体検証: 全テスト、遅延検知、`rebuild-restart.sh` での Docker 確認 | （コミットなし） | 1〜15 |

**他課題との順序**

- **01（`cultivation_plans.organization_id` の backfill 拡張）より先に、または同時に**、ステップ 4〜9 を出す。縮小前に backfill を広げると、NULL だった Plan に組織 ID が入り、組織スコープの経路で共有される可能性が広がる（§3.3）。縮小後は、Plan のために backfill を拡張する理由が無くなる。
- 01 の D1 とのポート変更（ステップ 12）は、縮小と独立に進められる。
- ステップ 1（D5）は他に依存しない最優先。
- ステップ 2 を 3 より先にする理由: DTO と署名の変更で所有者のみの性質が崩れないことを、変更前に固定するため。
- ステップ 4〜8 は互いに独立に進められるが、いずれも 3 の所有者判定に依存する。
- ステップ 9 は 4〜8 がすべて終わってから。旧関数を先に消すと未移行の経路がコンパイルできなくなる。
- ステップ 13 は、削除側の縮小（4）で非対称が解消したあとに行う。
- ステップ 12 は廃止予定の API に対する規約違反のため、他より後にする。
- 09（設計文書の是正）は、ステップ 10 の ADR を参照して書く。

---

## 8. リスク・未確定事項

### 8.1 セキュリティ・互換性リスク

| リスク | 内容 | 軽減策 |
|--------|------|--------|
| 過剰許可の残存（D7） | 組織スコープ判定は**役割を見ない**（§2.8）。縮小前は、`member` ロールのユーザーが他メンバーの Plan を閲覧し、削除し、作業実績やタスクを書き換えられる。組織メンバー追加 API に personal org のガードが無い（§2.3）ため、所有者の操作で backfill 済みの Plan が共有される経路がコード上は存在する（実行での再現は未実施） | S1〜S5 と V1〜V11 の縮小。T7-7〜T7-14 を RED に置く。personal org へのメンバー追加を制限するかは別論点（P13）としてユーザーへ報告。01 の backfill 拡張（`cultivation_plans.organization_id` を埋める）より先に、または同時に適用する（§10 の 01 の行） |
| 縮小による互換性影響（D7） | 組織メンバーが他メンバーの Plan を閲覧・編集する運用が既にある場合、縮小で 404（一覧からは消える、Cable は購読拒否）に変わる。フロントに組織メンバー向けの UI は**無い**ことを確認済み（§4.1）。本番の組織メンバー数・共有 Plan 数は**未確認** | P10 で本番データを確認してから適用する（§4.3。`production-primary-sqlite-query` スキル）。応答は現行の 404 系を維持し、新しい 403 を導入しない |
| 縮小漏れ（V / S の取りこぼし） | 経路が 25 個の interactor、SQL、Cable、写真ハンドラーに散らばっており、1 か所でも組織付きの判定が残ると、閲覧または編集が組織メンバーに開いたままになる。特に V1 / V9 は判定が SQL にあり、ドメインのテストだけでは検出できない | §2.9 の全数を RED 一覧（§6.7）に 1 対 1 で対応させる。ステップ 9 で旧関数を削除してコンパイルで取りこぼしを検出し、§5.8 の `rg` で確認する。SQL は R4（T7-11）で固定 |
| `private(user_id)` の暗黙依存 | 5 箇所が所有者のみになるのは、組織 ID が空だから、という性質に依存していた（§2.3）。DTO から組織 ID を除去する（§5.7）ため、構造上この依存は無くなる | T2-1〜T2-5 の特性化テストを DTO 変更の前に追加する（ステップ 2） |
| Cable の組織スコープ解決の除去 | `cable.rs:403-407` の `unwrap_or_default`（解決失敗は空スコープ）は、縮小後は不要になる。除去で fail-closed の性質が変わらないこと（所有者以外は拒否）を T7-13 で確認する | T7-13 |
| ADR と実装の食い違い | 縮小だけを行い ADR-002 を更新しないと、ADR が「Plan の組織共有」を掲げたまま実装が閉じている状態になる（§3.3） | ステップ 10 で新 ADR。09 と調整 |
| 組織 ID が NULL のレコードの扱い | 縮小後は Plan の判定に組織 ID を使わないため、NULL 行と非 NULL 行の差は無くなる（どちらも所有者のみ）。Farm / Crop では引き続き `organization_member_access` が `record_org` が `None` のとき false を返す | Farm / Crop は変更しない。backfill は [`01-resource-limit-bypass.md`](01-resource-limit-bypass.md) §2.4 の扱いに従う |
| admin の扱い（P3、未決） | Plan 系の共通ポリシーは admin を見ない（`private_cultivation_plan_access_policy.rs:8-24`）が、field_cultivation のポリシーは admin を許す（`plan_field_cultivation_access.rs:8-24`）。D5 の修正で公開 Plan に admin を許すと、admin が公開 Plan を編集できる状態が残る。ADR-002 §4（admin は全 org を横断）とも食い違う | P3 で確認。縮小（D7）は admin の挙動を変えない。admin の許可を維持するなら明文化する |
| D5 の修正が閲覧を狭めるリスク | `assert_edit_allowed` を分離するとき、`assert_view_allowed` を変えると、公開 Plan の私有ルート閲覧（show / climate_data）が壊れる | T5-2 で閲覧の回帰を固定する |
| D1 で拒否を Forbidden にする互換性 | 現行の「拒否→作成」に依存するクライアントがある場合、Forbidden への変更で挙動が変わる | P6。クライアントの有無は**未確認**。廃止予定 API のため、現行維持（P6 (a)）で R0 違反のみ解消する選択肢もある |
| D3 削除案のとき、トークンのみの復元 | `POST /undo_deletion` は認可を評価しない（§2.6）。D3 の削除案では復元側は変わらない | U12 で別途確認 |
| D4 の対策不備 | 連番 ID による公開 Plan の列挙が可能なまま。個人情報を含むかは未確認 | 応答フィールドの精査（別途）。P8 |

### 8.2 未確定事項

| # | 内容 | 状態 |
|---|------|------|
| U1 | P3、P4、P5、P6、P8〜P13 のユーザー判断（P1 は第 2 回決定で確定、P2 は第 1 回決定で確定、P9 は範囲外のまま） | §3.1 |
| U2 | AI 更新経路が `expected_updated_at` を渡さず常に stale になる疑い（`crop_gateway.rs:218-234`、`crop_ai_upsert_sqlite_persistence.rs:199-233`） | 未確認（RED で先に実行確認する。事実なら P6 の影響が変わる） |
| U3 | 組織 Plan が通常フローで生成されるか。**部分的に解消**: Plan の `organization_id` を書く非テストコードは backfill（personal org）だけで、非 personal 組織に Plan が属する経路はコード上は無い（§4.2）。SQL 直挿入と undo 復元の経路、personal org へメンバーが追加された実績は未確認 | 一部未確認 |
| U4 | `DeletionUndoScheduleInteractor` と `TaskScheduleItemScheduleDeletionUndoInteractor` の全呼び出し経路（マクロ・動的ディスパッチを含む）。`rg` では本番の構築箇所を確認できなかった | 未確認（`rg` の範囲内では未配線） |
| U5 | 公開 Plan の応答に個人情報が含まれるか（`workbench_payload.rs:6-27` を含む応答全体の精査） | 未確認 |
| U6 | 共有リンク前提を明記した文書の有無（ADR・設計文書の網羅検索） | 未確認 |
| U7 | ~~`work_hub_read_gateway.rs:36,42` の判定方式~~ | **解消**: SQL が `f.user_id = ?1` と `cp.user_id = ?1` のみ（所有者のみ）。§2.2 に反映 |
| U8 | `crop_nested_pests_access.rs:12`、`crop_resolve_by_name_policy.rs`、`field_cultivation_climate_crop_view_policy.rs:16` の組織対応の要否（§2.7 #5） | 未精査 |
| U9 | アダプター／`agrr-server` ユニットテストの規約上の実行入口が `test-common` に無い | 規約上の空白。RED はドメインと R4 に置く方針で回避。恒久対応は別課題 |
| U10 | `openapi.yaml` の該当エンドポイントの認可記述 | 未確認 |
| U11 | D5 の実行による再現 | 未実施（T5-3、T5-4 で確認する） |
| U12 | undo トークンの推測困難性と有効期限（`POST /undo_deletion` が認可を評価しない前提で、実害の範囲を確認する） | 未確認 |
| U13 | ~~私有 Plan 詳細（`/plans/{id}`）と workbench（`/data`）の応答が同等の情報かどうか~~ | **解消（不要）**: `data` を組織対応にしないため、同等性の確認は要らない（§0 第 2 回決定） |
| U14 | 本番の Plan の `organization_id` の分布、所有者以外のメンバーがいる組織に属する Plan の数、他メンバーによる Plan 削除の実績（P10。読み取り専用 SQL は §4.3） | 未確認（本番データに依存。SQL は未実行） |
| U15 | ~~D7 の各ルートを実際に叩く組織メンバー向けのフロント UI の有無~~ | **解消**: フロントに組織関連の UI・API 呼び出し・文言は無い（§4.1） |
| U16 | 認可失敗の状態コード統一（403 / 404 / 422）と、403 の書き込みがレート制限に数えられる点。03（R-4）、07、08（D-12）が本課題へ引き継いでいる | 本書は未対応（判定の可否のみ扱う）。別途、統一方針を決める必要がある |
| U17 | §4.3 の SQL の実行（列名・JSON パスの妥当性、実データの件数） | 未実行 |
| U18 | 縮小後、接続済みの Cable 購読が残るか（購読時にのみ判定: `cable.rs:483`。組織 ID は接続時に一度だけ解決: `cable.rs:398-418`） | 未確認 |
| U19 | 削除 undo の復元がスナップショットの `organization_id` を戻す経路の有無、SQL 直挿入で非 personal 組織へ Plan を割り当てた実績 | 未確認 |
| U20 | ADR-002 Context の「組織単位で計画共有」（`:15`）の「計画」が Plan を指すか | 未確認（§3 の表の「Plan 共有」（`:54`）から Plan を意図していたと読む） |

---

## 9. 受け入れ条件

| # | 条件 | 検証 |
|---|------|------|
| A1 | 認証済みの非所有者（かつ非 admin、P3 の決定に従う）が、私有ルートから公開 Plan の圃場栽培を更新できない | T5-1、T5-3、T5-4 |
| A2 | 公開 Plan の変更は公開ルート＋セッション一致でのみ成功し、私有 Plan の所有者は従来どおり更新できる | T5-5、T5-6 |
| A3 | 公開 Plan の閲覧（show / climate_data / public data）が従来どおり動く | T5-2、既存の公開 Plan 契約テスト |
| A4 | **組織メンバー（非所有者）は、他メンバー所有 Plan の編集系 API（`add_crop` / `add_field` / `remove_field` / `adjust`、圃場栽培の PATCH）を実行できず 404 になる**。`data` と圃場栽培の `climate_data` も 404 のまま（D2 の確定）。所有者は従来どおり実行できる | T2-1〜T2-5、T5-7 |
| A5 | 組織メンバー（非所有者）は、他メンバー所有 Plan の**削除、作業実績・写真の変更、タスクスケジュールの変更（create / update / skip / unskip / regenerate）、分散学習の更新（PATCH / reoptimize / import / carryover の書き込み先）、天候リスケ提案プレビュー**を実行できず、404 かつ DB 不変になる（S1〜S5） | T7-2〜T7-7 |
| A6 | 組織メンバー（非所有者）は、他メンバー所有 Plan の**閲覧経路**（Plan 一覧・詳細・タイムライン・作業実績一覧・写真ダウンロード・予実・分散学習の取得・天候リスケ提案の一覧・分散ポートフォリオ・Cable の Plan 購読・carryover の元 Plan）にアクセスできない。詳細・タイムラインなどは 404、一覧とポートフォリオは他メンバーの Plan を含まない、Cable は購読拒否（V1〜V11）。非メンバーは 404 のまま。所有者は従来どおり 200 | T7-8〜T7-13、T7-15 |
| A7 | `crates/agrr-adapters-*` の非テストコードが `reference_record_authorization` や `*_policy::*_allowed` を呼ばない（Crop AI upsert） | `rg` による確認と T1-1〜T1-4 |
| A8 | 他ユーザーの `crop_id` に対する Crop AI upsert が、P6 で決めた挙動になる | T1-1 |
| A9 | `schedule_authorization.rs` が P7 の決定どおり（削除、または所有者のみ判定の維持）で、組織対応にされていない。削除側（Plan 削除）も所有者のみで、削除と undo の判定が一致している | T3-1 または削除の確認、T7-2 |
| A10 | D4 が設計として文書化されている（P8 (b) の場合） | 文書の存在 |
| A11 | `run-test-rust-domain.sh` と `run-rust-contract-tests.sh` が全体 GREEN、遅延検知に新規の遅いテストが無い | 全体実行と `test-slow-detection` |
| A12 | 過剰許可の回帰が無い: 非メンバー・非所有者の拒否テスト（T2-1〜T2-5、T5-1、T5-4、T5-7、T7-1〜T7-13）がすべて GREEN | 同上 |
| A13 | Plan 系の interactor・ハンドラー・SQL・DTO に、組織 ID の解決と組織スコープの許可判定が残っていない（§5.8 の `rg` が 0 件） | `rg` の結果 |
| A14 | P9 の決定（Farm / Crop の組織スコープの扱い）が本書または別 issue に記録されている。**Farm / Crop の R4 契約テスト（`contracts.rs:4127` 以降）は変更されていない** | 文書の存在、既存テストの GREEN |
| A15 | 新 ADR（または ADR-002 追記）が存在し、Plan の共有撤回と再開条件（§3.3）を記す。`organization-data-model.md` の `member` ロール表と ER 図が Plan について更新されている | 文書の存在 |
| A16 | 縮小の前に §4.3 の SQL を実行し、共有されている Plan の件数（クエリ 3・4）と personal org のメンバー数（クエリ 5）が記録されている。0 件でない場合は、P10 の判断（連絡の要否）が記録されている | 記録の存在 |
| A17 | `cultivation_plans.organization_id` 列とバックフィル、`organization_member_access`、`member_organization_ids`、Organization / Membership API は削除されていない（Farm / Crop と再開条件のため） | `rg` と既存テストの GREEN |

---

## 10. 関連課題との依存

`docs/spec-defects/` の他番号との関係。2026-09-29 時点で 01〜11 のファイルが存在する。06、07、08 は初版の時点では存在を確認できなかったが、今回の改訂で存在を確認し、下表の該当箇所のみ（`rg` で認可に触れる行）を読んだ。**各文書の全文は精読していない**。

| 番号 | 課題 | 本書との関係 |
|------|------|--------------|
| 01 `resource-limit-bypass` | Farm / Crop 作成上限がユーザー単位と組織単位で食い違う | **強い依存**。D1 の作成上限判定のアダプター内評価（`crop_ai_upsert_sqlite_persistence.rs:177`）は同じコードを対象にする。D1 の移設と 01 の上限スコープの統一は、同じポート変更で一度に行うのが自然。ステップ 12 と 01 の実装順は事前に調整する。**Plan の `organization_id` については、第 2 回決定で 01 の backfill 拡張は Plan 系では不要になった**（Plan の判定に組織 ID を使わなくなるため。§3.3）。01 が Farm / Crop のために `TIER1_TABLES` の backfill を広げる場合、Plan 行も更新されるが無害。01 の R10（Plan の NULL 行の修復）と手順 10・12 の Plan に関する記述は、01 の改訂で更新する（本書は編集しない）。**順序の制約（D7）**: 縮小（ステップ 4〜9）が完了するまでは、01 の backfill が Plan の共有可能性を広げるため、**縮小を 01 の `cultivation_plans` backfill より先に、または同時に適用する** |
| 02 `contact-recaptcha` | 問い合わせフォームの reCAPTCHA | 依存なし |
| 03 `api-key-scope-docs` | API キーのスコープ文書と実装の不一致 | **§0 の「与えない」の解釈 (a)（API キーに書き込みスコープを与えない）は本課題ではなく 03 で扱う**。本書の決定 (b) とは独立で、両方を採用しても矛盾しない（03 §0 と README の決定事項表に記載）。03 は、API キーが有効なのは `/api/v1/masters/*` に限られると記す（03 §2.4）。すなわち Plan 系の D7 の経路は API キーの対象外と読める（03 側の根拠は未検証）。03 が課題 10 へ引き継ぐ項目: 403 になる書き込みがレート制限に数えられること（03 §2.9、R-4）。本書は扱っておらず、§8.2 U16 に残す |
| 04 `api-key-query-auth` | API キーのクエリ認証 | 依存なし |
| 05 `fail-closed-critical` | agrr 失敗時の成功形レスポンス | 依存なし。旧案（`data` を組織対応にする）は撤回したため、スコープ解決失敗時の扱いの整合は不要になった |
| 06 `fail-closed-suspected` | fail-closed 違反の疑い（8 項目） | 06 は認可の一貫性を「独立」とし、`climate_data` 経路の認可チェックには触れないと記す（06 の該当行）。本書の D5・D7 と競合しない。06 の全文は未精査 |
| 07 `frontend-error-contract` | フロントとサーバーのエラー契約 | 07 は、Masters の update の認可失敗の状態コードが揃っていない（pests / pesticides / fertilizes は 403、agricultural_tasks / interaction_rules は 422 + `errors: ["forbidden"]`）ことを「課題 10 の範囲」と記す。**本書は判定の可否（誰に許すか）を扱い、認可失敗の状態コード統一（403 / 404 / 422）は扱っていない**。§8.2 U16 に残す。縮小後、組織メンバーの Plan 系操作は 404 になる（新しい 403 を導入しない: §5.7）。この 404 の本文は、07 の「エラー本文を `errors` に統合する」決定と整合させる |
| 08 `openapi-gaps` | `openapi.yaml` と実装の乖離 | 08 の D-12 は、認可の返し方（403 / 404 / 422）の統一を「10 と合わせて判断」と記す。本書は状態コードの統一方針を持たない（U16）。D5、D7 の認可挙動の変更は `openapi.yaml` の記述更新を伴う可能性がある（U10）。08 が扱う範囲と重複しないよう調整する |
| 09 `stale-design-docs` | 設計文書が実装と乖離（ADR-002 / organization-data-model ほか） | **依存が強まった**。第 2 回決定（組織メンバーに他メンバー Plan の閲覧も編集も与えない）は、ADR-002 の「リソース共有: Farm / Crop / Plan」（`:54`）と `organization-data-model.md` の `member` ロール（「org 内リソースの CRUD」: `:41`）の記述と食い違う。ADR 更新の要否と方針は本書 §3.3（P11）で示し、ADR の起票（ステップ 10）は本書で扱う。09 側は、他の乖離と合わせて文書の整合を取る |
| 11 `low-priority-misc` | 低優先度の雑多な不整合 | 独立。D4（公開 Plan の列挙可能性）を低優先度として 11 に移す判断もありうるが、本書では P8 の確認対象とした |

依存の要点: 本書のステップ 1（D5）は他の課題に依存せず単独で着手できる。ステップ 2（特性化）と 3〜9（D7 の縮小）は P3、P10 の確認後に着手し、01 の backfill 拡張より先または同時に出す。ステップ 10（ADR）は 09 と整合を取る。ステップ 12（D1）は 01 と同一のポート変更に触れるため、01 と順序調整が必要である。
