# 10: 認可判定の一貫性（user_id のみ / 組織スコープ / 公開）と R0 違反

本書は**対応計画のみ**であり、コード・テスト・他文書の修正は含まない。記載する事実は 2026-09-29 時点のリポジトリ（`master`）を実際に読んで確認したものだけで、`file:line` を付ける。読んでいない・実行していない・本番データに依存するものは「未確認」と明記する。日数・週数の見積りは記載しない。

参照した規約: [`ARCHITECTURE.md`](../../ARCHITECTURE.md)、[`docs/architecture/LAYER-RULES.md`](../architecture/LAYER-RULES.md)（R0: Policies が認可を決め、Gateways は認可しない）、[`ADR-002`](../adr/ADR-002-organization-multi-tenancy.md)、[`organization-data-model.md`](../design/organization-data-model.md)、[`tdd-on-edit`](../../.cursor/skills/tdd-on-edit/SKILL.md)、[`test-common`](../../.cursor/skills/test-common/SKILL.md)、[`evidence-before-design-and-implementation.mdc`](../../.cursor/rules/evidence-before-design-and-implementation.mdc)、[`ca-violation-fix-architecture-gate.mdc`](../../.cursor/rules/ca-violation-fix-architecture-gate.mdc)。

課題は次の記号で参照する。

| 記号 | 内容 |
|------|------|
| D1 | Crop AI upsert のアダプターが認可を評価している（R0 違反） |
| D2 | 私有 Plan の REST 認可が組織スコープを渡していない |
| D3 | 削除 undo の予約認可が user_id のみで、削除側と非対称 |
| D4 | 公開 Plan の無認証読み取り（設計どおりの可能性） |
| D5 | 認証済みユーザーが私有ルート経由で公開 Plan の圃場栽培を更新できる（調査中に新規発見） |
| D6 | Masters 系の user_id のみ判定と組織スコープ判定の混在（網羅表） |

---

## 1. 概要と重大度

### 概要

ADR-002 の #612（Farm / Crop / Plan の組織スコープ認可、コミット `e020f1c66`）は、認可を「user_id 一致」から「user_id または所属組織一致」へ移す段階移行である。調査の結果、移行が**一部の経路で止まったまま**であり、同じ Plan に対して経路ごとに判定方式が異なることを確認した。

- Plan の一覧・詳細・削除・作業実績・タスクスケジュール・Cable 購読は組織スコープで判定する（§2.2）。
- Plan の `data` 取得、`add_crop` / `add_field` / `remove_field` / `adjust` は `CultivationPlanRestAuth::private(user_id)` で組織 ID を空にして判定する（`cultivation_plans.rs:75`、`cultivation_plans_mutations.rs:320,440,546,751`）。
- 圃場栽培（field_cultivation）の認可スナップショットには `organization_id` が無く、user_id のみで判定する（§2.5）。

これとは独立に、次の 2 点を確認した。

- **D1**: `crop_ai_upsert_sqlite_persistence.rs:195` で、アダプターが `assert_edit_allowed` を呼ぶ。R0 の直接違反である。
- **D5**: 私有ルート `PATCH /api/v1/plans/field_cultivations/{id}` で、公開 Plan の圃場栽培が「認証済みユーザーなら誰でも更新可」になっている。公開 Plan のセッション検証（`X-Public-Plan-Session`）を私有ルートで迂回できる。コード読解のみで確認しており、実行による再現は未実施（§6 の RED で再現する）。

### 重大度

| 課題 | 重大度 | 種別 | 理由 |
|------|--------|------|------|
| D5 | **高** | 過剰許可（他者データの改変） | 認証済みの任意ユーザーが、他人が作った公開 Plan の圃場栽培の日付を更新できる（コード読解による）。公開 Plan の ID は連番（§2.4）で列挙可能 |
| D2 | 中 | 過少許可（fail-closed） | 組織メンバーが共有 Plan を一覧では見られるのに、データ取得・編集は 404 になる。ただし Plan 作成 INSERT が `organization_id` を書かないため、現状は顕在化しにくい（§2.3） |
| D6 | 中〜低 | 過少許可（fail-closed） | Crop のネスト Masters（害虫・農薬・ステージ）が組織メンバーに対して 404 になる。Pest 等の Tier 1 拡張は ADR-002 の #612 スコープ外 |
| D1 | 中 | 規約違反（R0）＋意図しないフォールスルー | 認可拒否が「作成」に化ける。対象 API は非推奨で、2026-10-18 に廃止予定（#323） |
| D3 | 低 | 規約違反・非対称（未配線の疑い） | 本番コードから `DeletionUndoScheduleInteractor` を生成する箇所を確認できなかった |
| D4 | 低（情報） | 設計どおりの可能性が高い | 共有リンク前提。列挙可能性は実在するが、読み取りは公開 Plan に限られる |

過剰許可（D5）は修正の優先度が最も高い。過少許可（D2、D6）を直す際は、組織メンバー全員に読み取りだけでなく編集・削除を許すことになる点に注意する（§8.1）。

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

| エンドポイント / 機能 | 判定方式 | 根拠 |
|-----------------------|----------|------|
| `GET /api/v1/plans/cultivation_plans/{id}/data` | **user_id**（組織 ID 空） | ルート `cultivation_plans.rs:24-27`、`CultivationPlanRestAuth::private(user_id)` `:75` |
| `POST .../{id}/add_crop` | **user_id** | `cultivation_plans_mutations.rs:320`（ルート `:60-63`）。なお add_crop の作物解決は scope gateway を使う（`add_crop_support.rs`）ため、Plan 認可と作物解決で方式が食い違う |
| `POST .../{id}/add_field` | **user_id** | `cultivation_plans_mutations.rs:440`（ルート `:48-51`） |
| `DELETE .../{id}/remove_field/{field_id}` | **user_id** | `cultivation_plans_mutations.rs:546`（ルート `:52-55`） |
| `POST .../{id}/adjust` | **user_id** | `cultivation_plans_mutations.rs:751`（ルート `:56-59`）。interactor は `rest_plan_access` を評価（`plan_allocation_adjust_interactor.rs:107-114`） |
| 天候リスケ提案プレビュー | org の判定後、下流で **user_id** の `private(self.user_id)` を再構成 | `weather_reschedule_proposal_preview_interactor.rs:126-135`（org 判定）、`:175`（`private(self.user_id)`） |
| Plan 削除 | **org** | `cultivation_plan_destroy_interactor.rs:66-69`（`member_organization_ids` → `assert_private_owned`） |
| 私有 Plan 詳細 | **org** | `private_owned_plan_detail_interactor.rs:77` |
| 私有 Plan 一覧 | **org**（SQL の org サブクエリ） | `crates/agrr-adapters-sqlite/src/cultivation_plan/private_read_gateway.rs:32-34` |
| Cable の Plan 購読 | **org**（`private_with_scope`） | `cable_subscription_auth.rs:31-34,40-47`。スコープ解決は `cable.rs:403-407`（`unwrap_or_default`＝解決失敗は空スコープ＝fail-closed） |
| Cable の Farm 購読 | **user_id**（`farm_policy::view_allowed` に組織 ID 無し） | `cable_subscription_auth.rs:59` |
| タスクスケジュール（timeline / item 作成・更新・skip / regenerate / undo） | **org** | `task_schedules.rs:165,301,358,421`（scope gateway）、`task_schedule_private_plan_access.rs`、`task_schedule_item_schedule_deletion_undo_interactor.rs` |
| 作業実績（一覧・作成・更新・削除） | **org** | `work_record/interactors/private_plan_access.rs:11-17`、`work_record_list_interactor.rs` ほか `work_record/interactors/*` |
| 作業実績の写真 | **org** | `work_record_photos.rs:332,426` |
| 作業ハブ読み取り | 未確認（`work_hub_read_gateway.rs:36,42` は user_id と org の双方を読む形跡があるが、判定方式は精査していない） | `crates/agrr-adapters-sqlite/src/work_record/work_hub_read_gateway.rs:36,42` |
| `GET/PATCH /api/v1/plans/field_cultivations/{id}` | **user_id**（＋**公開 Plan は誰でも許可**、D5） | ルート `field_cultivations.rs:29-34`、`plan_field_cultivation_access.rs:8-30`、`FieldCultivationPlanAccessSnapshot` に `organization_id` 無し |
| `PATCH` 公開版 field_cultivation | **public**（セッション一致） | `field_cultivations.rs` の公開ルート、`plan_field_cultivation_authorization.rs`（`assert_public_field_cultivation_mutation_access`） |
| `GET /api/v1/public_plans/cultivation_plans/{id}/data` | **public**（認証なし、セッション不要） | `public_plans.rs:62-65,578-590` |
| 公開 Plan の adjust ほか変更系 | **public**（セッションヘッダ／Cookie 一致） | `public_plan_session.rs:22-25`、`rest_plan_access.rs:31-40` |
| Masters: Crop CRUD | **org** | `shared/policies/crop_policy.rs`（`record_access_filter_for_user`、`view/edit_allowed`）、`crop_ai_create_interactor.rs:90` |
| Masters: Farm CRUD | **org** | `shared/policies/farm_policy.rs:31,36,40` |
| Masters: Crop のネスト（害虫・農薬・ステージ） | **user_id**（空スコープ） | `crop/policies/crop_masters_nested_access.rs:12`、`pesticide/policies/crop_masters_nested_access.rs:12`、`masters_crop_context.rs:19-46` |
| Masters: Field | **user_id**（農場所有者経由、空スコープ） | `field/policies/field_access.rs:21,26`、`field_create_interactor.rs:48` |
| Masters: Pest / Pesticide / Fertilize / AgriculturalTask / InteractionRule | **user_id**（空スコープ） | §2.7 の表 |
| 削除 undo の予約（汎用） | **user_id**（`plan_user_id` / `user_id` 一致のみ） | `deletion_undo/schedule_authorization.rs:34-60` |
| 削除 undo の復元 | トークンのみ（認可判定なし） | `deletion_undo.rs:22,71-88`（`POST /undo_deletion`） |

### 2.3 D2: `CultivationPlanRestAuth::private(user_id)` と組織スコープ

| 事実 | 根拠 |
|------|------|
| `CultivationPlanRestAuth` は `private`（組織 ID 空）、`private_with_scope`（組織 ID あり）、`public`、`public_mutation` を持つ | `crates/agrr-domain/src/cultivation_plan/dtos/cultivation_plan_rest_auth.rs:19-36` |
| `rest_plan_access::evaluate` は Private のとき `private_cultivation_plan_access_policy::access_denied(plan, user_id, &auth.member_organization_ids)` を呼び、拒否は `NotFound`（404）にする | `crates/agrr-domain/src/cultivation_plan/interactors/rest_plan_access.rs:17-45` |
| `access_denied` は「私有でない→拒否」「`plan.user_id == user_id` →許可」「`organization_member_access(member_organization_ids, false, plan.organization_id)` →許可」の順で判定する。組織メンバーの許可が**意図された仕様**として実装されている | `crates/agrr-domain/src/cultivation_plan/policies/private_cultivation_plan_access_policy.rs:8-24` |
| 意図の一次根拠: #612「Farm / Crop / Plan の org スコープ認可」（コミット `e020f1c66`） | ADR-002 Migration phases の #612 行、および `git log` で確認したコミットメッセージ |
| ドメインのポリシーテストは組織メンバー許可を検証済み | `crates/agrr-domain/test/cultivation_plan/policies_private_cultivation_plan_access_policy_test.rs:68-93` |
| R4 契約テストに組織スコープの Plan 検証がある（一覧・詳細・削除など） | `crates/agrr-r4-contract/tests/contracts.rs` の組織関連テスト群（約 3685-4353 行）、`support.rs:1882` の `seed_org_scoped_plan` |
| `private(user_id)` を使う 5 箇所のハンドラーには、組織メンバー用の契約テストが確認できない | `contracts.rs` を `add_crop` / `add_field` / `remove_field` / `adjust` / `data` の組織メンバーで探したが該当なし（網羅的な目視はしていない。**未確認**の余地あり） |
| Plan 作成の INSERT は `organization_id` を書かない | `crates/agrr-adapters-sqlite/src/cultivation_plan/cultivation_plan_gateway.rs:54-57`、`plan_save_plan_copy.rs:105-107` |
| `organization_id` は personal organization の backfill でのみ埋まる（対象表に `cultivation_plans` を含む） | `personal_organization_sqlite_gateway.rs:29-39`（対象表）。詳細は [`01-resource-limit-bypass.md`](01-resource-limit-bypass.md) §2.4 |

**判定（どちらが正か）**: `private_cultivation_plan_access_policy.rs` と #612 の意図は「組織メンバーは共有 Plan にアクセスできる」であり、**`private_with_scope` 側（Cable、削除、詳細、一覧、作業実績、タスクスケジュール）が正**である。`private(user_id)` を使う 5 箇所のハンドラーと、プレビュー interactor の下流（`weather_reschedule_proposal_preview_interactor.rs:175`）は、#612 の適用漏れである。`private(user_id)` は fail-closed（NotFound）側に倒れるため、現状の害は「組織メンバーが共有 Plan を編集できない」という機能上の欠落であり、情報漏えいではない。

**顕在性（部分的に未確認）**: Plan の INSERT が `organization_id` を書かないため、通常フローで生成された Plan の `organization_id` は backfill による personal org のみと推測される。personal org のメンバーは所有者本人だけのはずなので、現状のデータでは組織メンバー経路が顕在化しにくい。他の org へ Plan を割り当てる経路（管理 UI、SQL、他 API）が存在するかは**未確認**。

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

**判定**: 読み取りの無認証公開は、共有リンク機能（フロントの URL 生成）に対応した設計と考えられる。ただし、ID が連番のため、全公開 Plan を列挙して閲覧できる。これは仕様として文書化されていない。

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
| スナップショットに `organization_id` が無い（組織メンバーは私有 Plan の圃場栽培も扱えない） | `crates/agrr-domain/src/field_cultivation/dtos/field_cultivation_plan_access_snapshot.rs` |
| 圃場栽培の show / climate_data も同じ `view_allowed` を使う | `field_cultivation_show_interactor.rs`、`field_cultivation_climate_data_interactor.rs:117-160` |
| フロントが使うのは `climate_data` のみ（更新 API は使っていない） | `frontend/.../field-climate-api.gateway.ts:19-22` |

**帰結（コード読解に基づく。実行での再現は未実施）**: 認証済みの任意ユーザーが、所有者でなくても、公開 Plan の圃場栽培の開始日・終了日を更新できる。フロントは更新 API を使わないため、通常の UI 操作では発火しない。API を直接叩ける相手にのみ意味を持つ。

### 2.6 D3: 削除 undo の予約認可

| 事実 | 根拠 |
|------|------|
| `SchedulableRecord` は `plan_user_id`、`plan_type_private`、`farm_user_id` などを持つが、組織 ID は持たない | `crates/agrr-domain/src/deletion_undo/schedule_authorization.rs:9-18` |
| `TaskScheduleItem`: `user.admin` または（私有 Plan かつ `plan_user_id == user.id`） | 同 `:48-52` |
| `CultivationPlan`: `user.admin` または（私有 Plan かつ `user_id == user.id`） | 同 `:53-57` |
| Farm / Crop / Pest ほかは user_id のみの `edit_allowed(user, is_reference, user_id)`。Field は `farm_user_id` 一致 | 同 `:36-47` |
| 呼び出し元: `DeletionUndoScheduleInteractor::ensure_schedule_authorized` がゲートウェイの `find_schedulable_record` で取得し `schedule_allowed` で判定 | `crates/agrr-domain/src/deletion_undo/interactors/deletion_undo_schedule_interactor.rs:89-101`、ゲートウェイ `deletion_undo_gateway.rs:161-183` |
| 削除側との非対称: Plan 削除 interactor は組織スコープ判定（§2.2）。TaskScheduleItem の undo 予約も組織スコープ判定 | `cultivation_plan_destroy_interactor.rs:66-69`、`task_schedule_item_schedule_deletion_undo_interactor.rs` |
| 本番コードから `DeletionUndoScheduleInteractor::new` を呼ぶ箇所は grep で見つからなかった（テストと自身の定義のみ） | `rg "DeletionUndoScheduleInteractor"` の結果（`crates/` 全体） |
| 実際の削除時の undo 予約は `schedule_destroy` を直接呼ぶ実装 | `crates/agrr-adapters-sqlite/src/deletion_undo/schedule.rs:31,220-229`、`cultivation_plan_gateway.rs:198`、`crop_gateway.rs:351` |
| TaskScheduleItem の削除ルートは無く、ゲートウェイ実装も `Err("not implemented")` | `task_schedules.rs:41-66`、`task_schedule_item_mutation_gateway.rs:405-411` |
| 復元（`POST /undo_deletion`）はトークンのみで、ユーザー認可を評価しない | `crates/agrr-domain/src/deletion_undo/deletion_undo.rs:22,71-88` |

**判定**: `schedule_allowed` の TaskScheduleItem / CultivationPlan 分岐は、削除側と非対称（組織メンバーを考慮しない）だが、本番の呼び出し元が確認できず、現状は到達しない可能性が高い（**未確認**: 全呼び出し経路の網羅は、動的ディスパッチやマクロ経由を含めて確認していない）。

### 2.7 D6: user_id のみ判定 vs 組織スコープ判定の網羅表

grep 条件: `record_access_filter(.*vec!\[\])`、`index_list_filter(.*&\[\])`、`CultivationPlanRestAuth::private\(`、`member_organization_ids`（`crates/` の非テストコード）。

| # | 箇所 | 方式 | 組織対応の可否 | 判定 |
|---|------|------|----------------|------|
| 1 | `cultivation_plans.rs:75`、`cultivation_plans_mutations.rs:320,440,546,751` | Plan REST を user_id のみ | Plan は `organization_id` を持つ | **不整合（D2）** |
| 2 | `weather_reschedule_proposal_preview_interactor.rs:175` | 上流は org、下流で `private(self.user_id)` | 同上 | **不整合（D2）** |
| 3 | `crop/policies/crop_masters_nested_access.rs:12`、`pesticide/policies/crop_masters_nested_access.rs:12` | Crop に対し空スコープの `record_access_filter(*user, vec![])` | `CropEntity::organization_id` が実装済み（`crop_entity.rs:71`） | **不整合**: Crop 本体は org 判定なのにネストは user_id のみ |
| 4 | `masters_crop_context.rs:19-46`（`CropLoadUserNonReferenceForMastersInteractor`）、`masters_crop_pests.rs:74,112,177`、`masters_crop_pesticides.rs:49`、`masters_crop_stages.rs:237,276` | 上記 #3 のポリシー経由 | 同上 | **不整合**（#3 と同根） |
| 5 | `shared/policies/crop_nested_pests_access.rs:12`、`crop_resolve_by_name_policy.rs`、`field_cultivation_climate_crop_view_policy.rs:16` | 空スコープ／user_id | Crop は組織対応 | **未精査**（同じ型の可能性。§7 のステップで個別確認） |
| 6 | `field/policies/field_access.rs:21,26`、`field_create_interactor.rs:48` | 空スコープの `farm_policy::record_access_filter(*user, vec![])`、`assert_owned` は `farm.user_id == Some(user.id)` | `FarmEntity::organization_id` 実装済み（`farm_entity.rs:63`）。ただし `field/results/farm_record.rs` は組織 ID を持たない | **不整合**: Farm 本体は org 判定、配下の Field は user_id のみ |
| 7 | `field_gateway.rs:91-95` | フィルターを受け取るが、ゲートウェイは user_id のみ読む | — | **R0 隣接の疑い**（ゲートウェイがフィルターを受け取って実質 user_id 絞り込みをする。判定はしていない） |
| 8 | `pest/interactors/pest_{detail,update,destroy,ai_update}_interactor.rs`（`:49,65,51,150`）、`pest_list_interactor.rs:35` | 空スコープ | Pest エンティティは `organization_id` を実装していない（`RecordRef` の既定 `None`、`record_ref.rs:5-7`。実装は Crop と Farm のみ） | Tier 1 未展開（ADR-002 の #612 スコープ外）。**整合的な未対応** |
| 9 | `pesticide/interactors/pesticide_*_interactor.rs`（`:44,55,50`、list `:41`） | 空スコープ | 同上 | 同上 |
| 10 | `fertilize/interactors/fertilize_*_interactor.rs`（`:49,55,50,185`、list `:41`） | 空スコープ | 同上 | 同上 |
| 11 | `agricultural_task/interactors/agricultural_task_{detail,update,destroy}_interactor.rs`（`:32,56,40`） | 空スコープ | 同上 | 同上 |
| 12 | `interaction_rule/interactors/interaction_rule_{detail,update,destroy,list}_interactor.rs`（`:43,54,47,41`） | 空スコープ | 同上 | 同上 |
| 13 | `cable_subscription_auth.rs:59` | Farm 購読を org 引数なしの `farm_policy::view_allowed` | Farm は組織対応 | **不整合**: 同ファイルの Plan 購読は org 対応 |
| 14 | `field_cultivation/policies/plan_field_cultivation_access.rs:8-30` | user_id/admin＋公開 | スナップショットに組織 ID 無し | **不整合＋過剰許可（D5）** |
| 15 | `deletion_undo/schedule_authorization.rs:36-57` | user_id | Farm / Crop / Plan は組織対応 | **不整合（D3、未配線の疑い）** |
| 16 | `crop_ai_upsert_sqlite_persistence.rs:195` | アダプターが org フィルターで評価 | — | **R0 違反（D1）** |
| 17 | 参照リスト SQL `agrr-adapters-sqlite/src/shared/reference_index.rs:22-66` | org ID が空なら `user_id` のみ、非空なら org または（`organization_id IS NULL` かつ user_id） | インフラは組織対応済み | 情報: Pest 等は空スコープを渡すため、リスト SQL の org 分岐は未使用 |
| 18 | `work_records` / `task_schedules` の interactor 群 | org | — | **整合**（`member_organization_ids` 使用、§2.2） |

Pest / Pesticide / Fertilize / AgriculturalTask / InteractionRule の組織対応は、ADR-002 では Tier 1 のデータモデル（`organization-data-model.md`）に載っているが、#612 の認可移行スコープは Farm / Crop / Plan に限られる。したがって #8〜#12 は「バグ」ではなく「未展開」として扱う。ただし ADR-002 §4 が「`user_id` 単独判定を段階的に縮小」と述べている以上、展開の有無は要確認である（§3、§8.2）。

### 2.8 組織スコープ判定の共通仕様（過剰許可の前提）

| 事実 | 根拠 |
|------|------|
| `organization_member_access(ids, is_reference, record_org)` は、非参照かつ `record_org` が `ids` に含まれれば true。**役割（owner / admin / member）を見ない** | `crates/agrr-domain/src/shared/org_scope.rs:13-23` |
| `ReferenceRecordAccessFilter` の view / edit は user_id 一致または上記の組織一致で許可。view と edit の差は無い | `crates/agrr-domain/src/shared/reference_record_access_filter.rs`、`reference_record_authorization.rs` |
| ADR-002 §4 は「`OrganizationAccessPolicy`（仮称）— メンバーシップ＋ロール＋`organization_id` 一致」を構想している | `docs/adr/ADR-002-organization-multi-tenancy.md` §4 |
| 実装には `OrganizationAccessPolicy` に相当するロール判定が存在しない（`crates/agrr-domain/src/shared/` と `organization/` を確認した範囲） | **未確認**（網羅的な検索はしていない） |

---

## 3. あるべき認可方針

### 3.1 判断が必要な論点

| # | 論点 | 選択肢 | 推奨 | ユーザー確認 |
|---|------|--------|------|--------------|
| P1 | 組織メンバーに Plan の**編集**（add_crop / add_field / remove_field / adjust）まで許すか | (a) 読み取りのみ許可し、編集は所有者のみ。(b) 全メンバーに編集も許可（現行の削除・作業実績と同じ）。(c) ロール（owner / admin / member）で分ける | ADR-002 §4 と #612 の実装（削除・作業実績が (b)）に揃えるなら (b)。ただし過剰許可のリスクがあるため要確認 | **必要** |
| P2 | Plan のロール別制御を今回入れるか | (a) 入れない（現行どおり全メンバー同権）。(b) `OrganizationAccessPolicy` を導入 | (a)。ロール導入は別課題 | **必要** |
| P3 | 公開 Plan の圃場栽培を私有ルートで更新できてよいか（D5） | (a) 不可（公開 Plan の変更は公開ルート＋セッション必須）。(b) 所有者のみ許可 | (a)。`admin` は例外を残すか要確認 | **必要**（admin の扱い） |
| P4 | Crop のネスト Masters を組織メンバーに許可するか（D6 #3） | (a) Crop 本体と同じ組織スコープ。(b) 所有者のみ（現行を仕様として明文化） | Crop 本体が組織対応である以上 (a)。ただし P1 と同じく編集権限の拡大になる | **必要** |
| P5 | Pest 等 Tier 1 の組織展開を本課題に含めるか | (a) 含めない。(b) 含める | (a)。別 issue で展開範囲を定義 | **必要** |
| P6 | D1: 認可拒否時の挙動 | (a) 現行維持（拒否→新規作成）。(b) Forbidden を返す | (b)。他ユーザーの `crop_id` を指定した更新が新規作成に化けるのは、意図として不自然。ただし互換性影響あり | **必要** |
| P7 | D3: `schedule_allowed` の扱い | (a) 組織対応にする。(b) 未配線なら削除する | 本番の呼び出し元が無いなら (b)。あるなら (a) | 必要（呼び出し元の再確認後） |
| P8 | D4: 公開 Plan の読み取り | (a) 許容（現行）。(b) 許容し設計として文書化。(c) 対策（非連番 ID、レート制限） | (b) を最小案とする。(c) は共有リンク仕様が固まってから | **必要** |

### 3.2 ADR-002 の Phase との整合

| 項目 | 整合 |
|------|------|
| ADR-002 Migration phases 6「ポリシー移行」(#612) は Farm / Crop / Plan の組織スコープ認可。D2 と D6 #3、#6 は**このフェーズの取りこぼし**と位置づけられる | `docs/adr/ADR-002-organization-multi-tenancy.md` Migration phases の表 |
| ADR-002 §4「Gateway は `organization_id` による狭い永続化クエリのみ」。D1 は Gateway（Persistence）が認可を評価しており、§4 と R0 の双方に反する | 同 §4、`LAYER-RULES.md`（R0） |
| ADR-002 §4「admin は全 org を横断可能（現行 `user.admin` と同等）」。D5 で `admin` を許可する場合は §4 と整合 | 同 §4 |
| ロール判定は §4 に記載があるが、Phase 6 の実装では未導入（§2.8）。本課題では導入しない（P2 (a)） | — |
| Tier 1 のうち Pest 等の展開は #612 の範囲外（§2.7）。本課題では扱わない（P5 (a)） | `docs/design/organization-data-model.md` |

---

## 4. 影響範囲

| 課題 | 影響を受けるもの |
|------|------------------|
| D1 | `POST` の Crop AI 生成 API（`ai_api.rs:50`）。非推奨で廃止予定（`builtin-generation-sunset.md:67-68`）。呼び出し元フロントの有無は**未確認** |
| D2 | 私有 Plan の `data` 取得と 4 つの変更系 API、天候リスケ提案プレビュー。フロントの Plan 編集画面が共有 Plan を開いたときの 404 |
| D3 | 汎用 undo 予約（本番の呼び出し元は確認できず） |
| D4 | 公開 Plan の閲覧 URL、SEO メタ（`public-plan-results-seo-meta.ts`）、公開ウィザード |
| D5 | `PATCH /api/v1/plans/field_cultivations/{id}`（フロントは未使用）。`show` / `climate_data` の私有ルート閲覧は公開 Plan を許可している点で挙動を変える場合は影響あり |
| D6 | Crop ネスト Masters API（害虫・農薬・ステージ）、Field API、Cable の Farm 購読 |
| ドキュメント | `docs/api/openapi.yaml` の該当エンドポイントの認可記述（**未確認**: 現状の記述内容は読んでいない）。関連: [`08-openapi-gaps`](#10-関連課題との依存) |

変更してはならないもの（回帰防止）:

- 公開 Plan の変更系におけるセッション一致検証（`X-Public-Plan-Session`）。
- 所有者本人のアクセス。
- 既に組織対応済みの経路（削除・詳細・一覧・作業実績・タスクスケジュール・Cable の Plan 購読）。

---

## 5. 対応方針（層ごとの変更）

方針は R0（Policies が認可、Gateways は取得のみ）に従う。

### 5.1 D5（最優先）

| 層 | 変更 |
|----|------|
| Domain policy | `plan_field_cultivation_access.rs` の `assert_edit_allowed` を `assert_view_allowed` から分離する。編集は「私有 Plan かつ（所有者または admin または P1 (b) に応じて組織メンバー）」のみ許可し、公開 Plan は私有ルートからの編集を拒否する |
| Domain DTO | 組織対応（P1 (b)）を選ぶ場合のみ、`FieldCultivationPlanAccessSnapshot` に `organization_id` を追加し、ポリシーに `member_organization_ids` を渡す。選ばない場合は追加しない |
| Domain interactor | `FieldCultivationUpdateInteractor` の私有経路で、公開 Plan は Forbidden にする。公開経路は既存の `assert_public_field_cultivation_mutation_access` を維持 |
| Gateway（SQLite） | 変更なし（取得と UPDATE のみ。認可を足さない） |
| Edge（axum） | `field_cultivations.rs:214-250` は変更しない（判定はドメイン側で行う）。組織対応を選ぶ場合のみ、scope gateway の配線を追加 |

### 5.2 D2

| 層 | 変更 |
|----|------|
| Edge | 5 箇所のハンドラーで、`member_organization_ids`（`UserOrganizationScopeSqliteGateway` 経由）から `CultivationPlanRestAuth::private_with_scope` を構築する。重複を避けるため、`agrr-server` 内に組み立てヘルパー 1 個を置く（`cable.rs:403-407` と同じ scope gateway を使う）。解決失敗は `unwrap_or_default` ではなく 500 にするか、fail-closed の空スコープにするかを P1 と併せて決める（Cable は空スコープ＝fail-closed） |
| Domain interactor | プレビュー interactor は `:126-135` で解決済みの `org_ids` を保持し、`:175` を `private_with_scope(self.user_id, org_ids.clone())` に変える |
| Domain policy | 変更なし（`private_cultivation_plan_access_policy.rs:8-24` は既に組織対応） |
| 代替案 | ハンドラーではなく interactor が `UserOrganizationScopeGateway` を受け取って解決する。R7（ハンドラーは薄く）に忠実だが、5 つの interactor のコンストラクタ変更が必要になる。**推奨はハンドラー側ヘルパー**（既存の Cable と同じ形で、変更が小さい） |

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

補助として、アダプター層の認可再発を防ぐため、`scripts/run-architecture-guard-lib.mjs` に「`crates/agrr-adapters-*` で `reference_record_authorization` / `*_policy::*_allowed` を参照しない」ルールを足す案がある。現状のガードは R6 とフロントのルールが中心で、アダプター認可の機械検出は無い（**未確認**: ガードの全ルールを読み切ってはいない）。ガード追加は必須とせず、任意の項目とする。

### 5.4 D3

| 案 | 内容 |
|----|------|
| 削除案（推奨） | 本番の呼び出し元が無いことを再確認したうえで、`schedule_authorization.rs` と `DeletionUndoScheduleInteractor` を削除する（`project-necessary-code-only`）。削除の是非はユーザー確認（P7） |
| 組織対応案 | 呼び出し元がある場合、`SchedulableRecord` に `plan_organization_id` を足し、`ensure_schedule_authorized` で `member_organization_ids` を解決して `private_cultivation_plan_access_policy::access_denied` を使う。削除側 interactor と同じ判定に揃える |

### 5.5 D6

| 対象 | 変更 |
|------|------|
| Crop ネスト（#3、#4） | P4 (a) を選ぶ場合、`crop_masters_nested_access.rs` に `member_organization_ids` を渡す。`CropLoadUserNonReferenceForMastersInteractor` に scope gateway を注入する（R2: コンストラクタ注入） |
| Field（#6） | Farm が組織対応のため Field も組織スコープに揃える案があるが、`FarmRecord` に組織 ID が無く追加が必要。**本課題の必須範囲外**とし、P4/P5 の回答後に別 issue を推奨 |
| Cable の Farm（#13） | `farm_subscription_denied` に `ctx.member_organization_ids` を渡し、`record_access_filter` を使う形にする。Farm の組織スコープは #612 の対象 |
| Pest 等（#8〜#12） | 変更しない（P5 (a)）。展開が決まった時点で別 issue |

### 5.6 D4

推奨は P8 (b): 設計として文書化する。読み取りの無認証公開を維持し、次を記載する。

- 共有リンクとしての意図。
- ID が連番で列挙可能であること。
- 応答に含めない情報の一覧（個人情報が含まれないことの確認は別途）。

記載先の候補は `docs/api/`（該当エンドポイントの説明）または ADR。どちらにするかは既存文書の構成に依存するため未決。対策 (c) は共有リンクの仕様確定後の別課題とする。

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

### 6.1 D5

| ID | パス案 | given / when / then | ランナー |
|----|--------|---------------------|----------|
| T5-1 | `crates/agrr-domain/test/field_cultivation/policies_plan_field_cultivation_access_test.rs`（既存ファイルの有無は**未確認**。無ければ新規） | given 公開 Plan のスナップショット、所有者でも admin でもない User / when `assert_edit_allowed` / then `Err(PolicyPermissionDenied)`。現行は `Ok` のため RED | `run-test-rust-domain.sh` |
| T5-2 | 同上 | given 公開 Plan、User / when `assert_view_allowed` / then `Ok`（読み取りは維持。回帰防止） | 同上 |
| T5-3 | `crates/agrr-domain/test/field_cultivation/interactors_field_cultivation_update_interactor_test.rs`（既存の有無は**未確認**） | given 公開 Plan の圃場栽培、`with_user` で所有者でないユーザー、`public_plan = false` / when `call` / then `on_failure(Forbidden)`、ゲートウェイの更新が呼ばれない（スパイで 0 回）。現行は更新が呼ばれるため RED | 同上 |
| T5-4 | `crates/agrr-r4-contract/tests/contracts.rs` に追記 | given 公開 Plan（`seed_public_cultivation_plan_with_session`、`support.rs:1918`）と別ユーザーのセッション / when `PATCH /api/v1/plans/field_cultivations/{id}` / then 403 または 404、DB の日付が不変。現行は 200 になる疑いのため RED | `run-rust-contract-tests.sh` |
| T5-5 | 同上 | given 公開 Plan と一致するセッション / when 公開 PATCH ルート / then 200（回帰防止。既存の `public_plan_mutation_rejects_mismatched_session` `contracts.rs` 約 4423 行と対で置く） | 同上 |
| T5-6 | 同上 | given 私有 Plan の所有者 / when PATCH / then 200（回帰防止） | 同上 |

### 6.2 D2

| ID | パス案 | given / when / then | ランナー |
|----|--------|---------------------|----------|
| T2-1 | `crates/agrr-r4-contract/tests/contracts.rs`（`org_member_can_get_private_plan_data`） | given `seed_org_scoped_plan(org, owner)`、`org` のメンバー `member`（`seed_organization_membership`、`support.rs:1721`） / when `GET /api/v1/plans/cultivation_plans/{id}/data`（member のセッション） / then 200。現行は 404 のため RED | `run-rust-contract-tests.sh` |
| T2-2 | 同上（`non_member_gets_404_for_org_scoped_plan_data`） | given 同じ Plan、org に属さないユーザー / when 同 GET / then 404（過剰許可の防止） | 同上 |
| T2-3 | 同上（`org_member_can_add_crop / add_field / remove_field / adjust`） | given 組織 Plan、member / when 各 POST・DELETE / then 認可は通り、認可以外の入力検証結果が返る（404 でないこと）。`adjust` は最適化バイナリ（`lib/core/agrr`）を要するかが**未確認**のため、認可のみを確認できる入力（不正入力で 422 になる等）を使う | 同上 |
| T2-4 | 同上 | given 組織 Plan、非メンバー / when 各変更系 / then 404 かつ DB 不変 | 同上 |
| T2-5 | `crates/agrr-domain/test/cultivation_plan/interactors_weather_reschedule_proposal_preview_interactor_test.rs`（既存の有無は**未確認**） | given 組織 Plan、org メンバーの user_id / when プレビュー `call` / then 下流の `RetrieveCultivationPlan` 相当が組織メンバーとして許可される（フェイクの `auth.member_organization_ids` が空でないことを検証）。現行は空のため RED | `run-test-rust-domain.sh` |
| T2-6 | `crates/agrr-server/src/` 内のヘルパーのユニットテスト | ヘルパーが `private_with_scope` を作ることの確認。`agrr-server` のテストは `test-common` スクリプトの対象外（cargo で直接実行）。RED は T2-1〜T2-4 で担保する | （対象外） |

### 6.3 D1

| ID | パス案 | given / when / then | ランナー |
|----|--------|---------------------|----------|
| T1-1 | `crates/agrr-domain/test/crop/interactors_crop_ai_create_interactor_test.rs` に追記 | given 他ユーザー所有の非参照 Crop の `crop_id` を含む入力、フェイク永続化（取得メソッドが該当 Crop を返し、`upsert` の対象を記録） / when `call` / then P6 (b) なら `on_failure(Forbidden)` かつ `upsert` 未呼び出し、P6 (a) なら `upsert` のターゲットが `Create`。現行は interactor が評価しないため RED（新ポートメソッドが未定義でコンパイルエラーになる。RED はコンパイル失敗を含む点に注意） | `run-test-rust-domain.sh` |
| T1-2 | 同上 | given 自分の Crop の `crop_id` / when `call` / then `upsert` のターゲットが `Update(crop_id)` | 同上 |
| T1-3 | 同上 | given 組織メンバーの Crop の `crop_id`（`EmptyScopeGateway` ではなく組織 ID を返すフェイクスコープ）/ when `call` / then `Update`（組織スコープ許可） | 同上 |
| T1-4 | 同上 | given 作成上限に達したユーザー、`crop_id` なし / when `call` / then 上限超過が interactor で判定される（上限判定の移設。関連: 01） | 同上 |
| T1-5 | アダプター側 `crop_ai_upsert_sqlite_persistence.rs` のテスト | 認可を評価しないこと（他人の crop_id でも取得のみで拒否しない）。`test-common` の対象外のため、実行は `cargo test -p agrr-adapters-sqlite` を別途行う必要がある。**規約上の実行入口が無い点は未解決**（§8.2） | （対象外） |
| T1-6 | `crates/agrr-r4-contract/tests/contracts.rs` | AI Crop 作成エンドポイントの契約テストの有無は**未確認**。あれば、他人の `crop_id` で P6 の決定どおりの応答になることを追加する | `run-rust-contract-tests.sh` |

### 6.4 D3

| ID | パス案 | given / when / then | ランナー |
|----|--------|---------------------|----------|
| T3-1 | `crates/agrr-domain/test/deletion_undo/`（既存の `schedule_authorization` テストの有無は**未確認**） | P7 (a) を選んだ場合: given 組織 Plan に属する TaskScheduleItem／CultivationPlan、所有者でない組織メンバー / when `schedule_allowed`（または組織対応後の新関数） / then true。非メンバーは false | `run-test-rust-domain.sh` |
| T3-2 | 同上 | P7 (b) を選んだ場合: テストの削除のみ。RED は不要（振る舞い不変の削除） | 同上 |

### 6.5 D6

| ID | パス案 | given / when / then | ランナー |
|----|--------|---------------------|----------|
| T6-1 | `crates/agrr-domain/test/crop/policies_crop_masters_nested_access_test.rs`（新規） | P4 (a) の場合: given 組織メンバーが所有する Crop（`organization_id` あり）、組織メンバーの別ユーザー / when `assert_edit_allowed_for_masters` 相当（組織 ID を渡す新シグネチャ）/ then Ok。現行は空スコープのため RED | `run-test-rust-domain.sh` |
| T6-2 | `crates/agrr-r4-contract/tests/contracts.rs` | given 組織 Crop、member / when `GET /api/v1/masters/crops/{id}/pests` 等のネスト API / then 200。非メンバーは 404 | `run-rust-contract-tests.sh` |
| T6-3 | `crates/agrr-server/src/cable_subscription_auth.rs` の既存テスト（`:121` 付近に空スコープのフィクスチャあり）に追加 | given 組織 Farm、org メンバーの Cable セッション / when `farm_subscription_denied` / then false。`agrr-server` のテストは `test-common` の対象外。契約側は `contracts.rs` 約 4356-4420 行の Cable テスト群に追記して担保する | `run-rust-contract-tests.sh` |

### 6.6 D4

コード変更なし（文書化のみ）。RED は不要。既存の公開 Plan 読み取り・変更系の契約テスト（`contracts.rs` 約 4423 行の `public_plan_mutation_rejects_mismatched_session` など）が回帰しないことを、全体実行で確認する。

### 6.7 完了時の実行

`tdd-on-edit` と `rails-testing-workflow` に従い、個別 GREEN → 全体（`run-test-rust-domain.sh` と `run-rust-contract-tests.sh`）→ 遅延検知（[`test-slow-detection`](../../.cursor/skills/test-slow-detection/SKILL.md)）の順で実行する。`crates/agrr-server/**`、`crates/agrr-domain/**`、`crates/agrr-adapters-*/**` を変更したので、Docker で検証する前に `.cursor/skills/dev-docker/scripts/rebuild-restart.sh` を実行する。

---

## 7. 実装ステップ（順序・コミット粒度）

前提: §3.1 のユーザー確認（少なくとも P1、P3、P6）が済んでいること。確認前は着手しない。ステップごとに RED → GREEN → リファクタで 1 コミットを基本とし、RED のテストは実装と同じコミットに含めてよい（未 GREEN のコミットを残さない）。

| # | ステップ | コミット | 依存 |
|---|----------|----------|------|
| 1 | D5: T5-1〜T5-6 の RED を書く → `plan_field_cultivation_access` と `FieldCultivationUpdateInteractor` を修正して GREEN | `fix(authz): forbid private-route edit of public plan field cultivations` | P3 |
| 2 | D2: T2-1〜T2-5 の RED → `agrr-server` のヘルパーで `private_with_scope` を構築 → プレビュー interactor を修正して GREEN | `fix(authz): pass org scope to private cultivation plan REST auth` | P1 |
| 3 | D6 #13 Cable の Farm 購読: T6-3 の RED → `farm_subscription_denied` の修正 | `fix(authz): org-aware farm cable subscription` | P4 の回答、1 とは独立 |
| 4 | D6 #3/#4 Crop ネスト Masters: T6-1、T6-2 の RED → ポリシーと interactor に組織スコープを注入 | `fix(authz): org scope for crop nested masters` | P4 |
| 5 | D1: T1-1〜T1-4 の RED → ポートとインタラクターの再設計 → アダプターの認可削除 | `refactor(crop-ai): move upsert authorization into interactor` | P6（#323 の廃止時期を確認したうえで着手を判断） |
| 6 | D3: 呼び出し元の再確認 → 削除案または組織対応案 | `chore(deletion-undo): remove unwired schedule authorization`（または組織対応） | P7 |
| 7 | D4: 設計としての文書化（必要時） | `docs: document public plan share-link access model` | P8 |
| 8 | 任意: アーキテクチャガードにアダプター認可の検出を追加 | `chore(guard): forbid authorization calls in adapters` | 5 の後 |
| 9 | 全体検証: 全テスト、遅延検知、`rebuild-restart.sh` での Docker 確認 | （コミットなし） | 1〜8 |

順序の理由: ステップ 1 は過剰許可（高重大度）なので最優先である。ステップ 2 は fail-closed 側の機能修正で、P1 の確認が要る。ステップ 5 は廃止予定の API に対する規約違反のため、他より後にする。

---

## 8. リスク・未確定事項

### 8.1 過剰許可によるセキュリティリスク

| リスク | 内容 | 軽減策 |
|--------|------|--------|
| 組織メンバーへの権限拡大（D2、D6 #3） | 組織スコープ判定は**役割を見ない**（§2.8）。`private_with_scope` を 5 箇所へ広げると、ロールが `member` のユーザーも add_crop / add_field / remove_field / adjust ができる。既存の削除・作業実績と同じ水準だが、編集系の対象が広がる | P1 の確認。T2-2、T2-4（非メンバー拒否）を必須の RED にする。ロール別制御は別課題（P2） |
| 組織 ID が NULL のレコードの扱い | `organization_member_access` は `record_org` が `None` のとき false。NULL 行は所有者経由のみ許可される。これは意図どおりだが、backfill 前の行が組織共有にならない点は機能欠落として残る | 変更しない。backfill は [`01-resource-limit-bypass.md`](01-resource-limit-bypass.md) §2.4 の扱いに従う |
| スコープ解決失敗時の挙動 | ハンドラーでスコープ解決が失敗したときに空スコープで続行する（Cable の `unwrap_or_default`, `cable.rs:403-407`）のは fail-closed だが、失敗を隠す。500 にするか空スコープにするかで、可用性と安全性のトレードオフがある | 空スコープ（fail-closed）を既定とし、ログを出す。決定は P1 と併せて確認 |
| D5 の修正で admin をどう扱うか | admin は現在すべての Plan を編集できる（`plan_field_cultivation_access.rs:8-24`）。公開 Plan でも admin を許すと、admin が公開 Plan を編集できる状態が残る | P3 で確認。admin の許可を維持するなら明文化する |
| D5 の修正が閲覧を狭めるリスク | `assert_edit_allowed` を分離するとき、`assert_view_allowed` を変えると、公開 Plan の私有ルート閲覧（show / climate_data）が壊れる | T5-2 で閲覧の回帰を固定する |
| D1 で拒否を Forbidden にする互換性 | 現行の「拒否→作成」に依存するクライアントがある場合、Forbidden への変更で挙動が変わる | P6。クライアントの有無は**未確認**。廃止予定 API のため、現行維持（P6 (a)）で R0 違反のみ解消する選択肢もある |
| D4 の対策不備 | 連番 ID による公開 Plan の列挙が可能なまま。個人情報を含むかは未確認 | 応答フィールドの精査（別途）。P8 |

### 8.2 未確定事項

| # | 内容 | 状態 |
|---|------|------|
| U1 | P1〜P8 のユーザー判断 | §3.1 |
| U2 | AI 更新経路が `expected_updated_at` を渡さず常に stale になる疑い（`crop_gateway.rs:218-234`、`crop_ai_upsert_sqlite_persistence.rs:199-233`） | 未確認（RED で先に実行確認する。事実なら P6 の影響が変わる） |
| U3 | 組織 Plan が通常フローで生成されるか（`organization_id` を書く INSERT が §2.3 の 2 箇所に無い）。他の割り当て経路の有無 | 未確認 |
| U4 | `DeletionUndoScheduleInteractor` の全呼び出し経路（マクロ・動的ディスパッチを含む） | 未確認 |
| U5 | 公開 Plan の応答に個人情報が含まれるか（`workbench_payload.rs:6-27` を含む応答全体の精査） | 未確認 |
| U6 | 共有リンク前提を明記した文書の有無（ADR・設計文書の網羅検索） | 未確認 |
| U7 | `work_hub_read_gateway.rs:36,42` の判定方式 | 未確認 |
| U8 | `crop_nested_pests_access.rs:12`、`crop_resolve_by_name_policy.rs`、`field_cultivation_climate_crop_view_policy.rs:16` の組織対応の要否（§2.7 #5） | 未精査 |
| U9 | アダプター／`agrr-server` ユニットテストの規約上の実行入口が `test-common` に無い | 規約上の空白。RED はドメインと R4 に置く方針で回避。恒久対応は別課題 |
| U10 | `openapi.yaml` の該当エンドポイントの認可記述 | 未確認 |
| U11 | D5 の実行による再現 | 未実施（T5-3、T5-4 で確認する） |

---

## 9. 受け入れ条件

| # | 条件 | 検証 |
|---|------|------|
| A1 | 認証済みの非所有者（かつ非 admin、P3 の決定に従う）が、私有ルートから公開 Plan の圃場栽培を更新できない | T5-1、T5-3、T5-4 |
| A2 | 公開 Plan の変更は公開ルート＋セッション一致でのみ成功し、私有 Plan の所有者は従来どおり更新できる | T5-5、T5-6 |
| A3 | 公開 Plan の閲覧（show / climate_data / public data）が従来どおり動く | T5-2、既存の公開 Plan 契約テスト |
| A4 | 組織メンバーが共有 Plan の `data` 取得と変更系 API（P1 で許可した範囲）にアクセスでき、非メンバーは 404 のまま | T2-1〜T2-4 |
| A5 | プレビュー interactor が組織メンバーの許可を下流へ引き継ぐ | T2-5 |
| A6 | `crates/agrr-adapters-*` の非テストコードが `reference_record_authorization` や `*_policy::*_allowed` を呼ばない（Crop AI upsert） | `rg` による確認と T1-1〜T1-4 |
| A7 | 他ユーザーの `crop_id` に対する Crop AI upsert が、P6 で決めた挙動になる | T1-1 |
| A8 | Crop ネスト Masters と Cable の Farm 購読が、P4 で決めたスコープで動く | T6-1〜T6-3 |
| A9 | `schedule_authorization.rs` が P7 の決定どおり（削除または組織対応）で、削除側と非対称でない | T3-1 または削除の確認 |
| A10 | D4 が設計として文書化されている（P8 (b) の場合） | 文書の存在 |
| A11 | `run-test-rust-domain.sh` と `run-rust-contract-tests.sh` が全体 GREEN、遅延検知に新規の遅いテストが無い | 全体実行と `test-slow-detection` |
| A12 | 過剰許可の回帰が無い: 非メンバー・非所有者の拒否テスト（T2-2、T2-4、T5-1、T5-4）がすべて GREEN | 同上 |

---

## 10. 関連課題との依存

`docs/spec-defects/` の他番号との関係。2026-09-29 時点で存在するファイルは 01、02、03、04、05、09、11。06、07、08 は本調査時点で存在を確認できなかった（作成前または未着手）。

| 番号 | 課題 | 本書との関係 |
|------|------|--------------|
| 01 `resource-limit-bypass` | Farm / Crop 作成上限がユーザー単位と組織単位で食い違う | **強い依存**。D1 の作成上限判定のアダプター内評価（`crop_ai_upsert_sqlite_persistence.rs:177`）は同じコードを対象にする。D1 の移設と 01 の上限スコープの統一は、同じポート変更で一度に行うのが自然。Plan の `organization_id` が NULL のままである点（§2.3）は 01 §2.4 の backfill と同根。ステップ 5 と 01 の実装順は事前に調整する |
| 02 `contact-recaptcha` | 問い合わせフォームの reCAPTCHA | 依存なし |
| 03 `api-key-scope-docs` | API キーのスコープ文書と実装の不一致 | 弱い関連。Masters の書き込み認可（`masters:write`）が別軸のスコープ制御を持つため、D6 の Masters 変更時に API キー経路の回帰を確認する |
| 04 `api-key-query-auth` | API キーのクエリ認証 | 依存なし |
| 05 `fail-closed-critical` | agrr 失敗時の成功形レスポンス | 依存なし。D2 の「スコープ解決失敗時の扱い」（§8.1）は fail-closed 方針で整合させる |
| 06 `fail-closed-suspected` | （未作成） | 未確認。D2 の空スコープ既定は fail-closed で、06 が扱う内容と競合しない見込みだが、06 の内容を読めていない |
| 07 `frontend-error-contract` | （未作成） | 未確認。D2 の修正で共有 Plan の 404 が 200 に変わる、D1 で拒否の応答形が変わる場合は、フロントのエラー契約への影響を 07 と確認する |
| 08 `openapi-gaps` | （未作成） | 未確認。D2、D5、D6 の認可挙動の変更は `openapi.yaml` の記述更新を伴う可能性がある（U10）。08 が扱う範囲と重複しないよう調整する |
| 09 `stale-design-docs` | 設計文書が実装と乖離（ADR-002 / organization-data-model ほか） | **弱い依存**。§3.2 の ADR-002 §4（ロール判定を含む `OrganizationAccessPolicy`）と実装の差は 09 の対象になりうる。本書はロール導入を範囲外にしたため、09 側で文書の更新を扱う |
| 11 `low-priority-misc` | 低優先度の雑多な不整合 | 独立。D4（公開 Plan の列挙可能性）を低優先度として 11 に移す判断もありうるが、本書では P8 の確認対象とした |

依存の要点: 本書のステップ 1（D5）とステップ 2（D2）は他の課題に依存せず単独で着手できる。ステップ 5（D1）は 01 と同一のポート変更に触れるため、01 と順序調整が必要である。
