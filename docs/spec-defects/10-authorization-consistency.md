# 10: 認可判定の一貫性（user_id のみ / 組織スコープ / 公開）と R0 違反

本書は**対応計画のみ**であり、コード・テスト・他文書の修正は含まない。記載する事実は 2026-09-29 時点のリポジトリ（`master` を基点とするワーキングツリー）を実際に読んで確認したものだけで、`file:line` を付ける。読んでいない・実行していない・本番データに依存するものは「未確認」と明記する。日数・週数の見積りは記載しない。

参照した規約: [`ARCHITECTURE.md`](../../ARCHITECTURE.md)、[`docs/architecture/LAYER-RULES.md`](../architecture/LAYER-RULES.md)（R0: Policies が認可を決め、Gateways は認可しない）、[`ADR-002`](../adr/ADR-002-organization-multi-tenancy.md)、[`organization-data-model.md`](../design/organization-data-model.md)、[`tdd-on-edit`](../../.cursor/skills/tdd-on-edit/SKILL.md)、[`test-common`](../../.cursor/skills/test-common/SKILL.md)、[`evidence-before-design-and-implementation.mdc`](../../.cursor/rules/evidence-before-design-and-implementation.mdc)、[`ca-violation-fix-architecture-gate.mdc`](../../.cursor/rules/ca-violation-fix-architecture-gate.mdc)。

課題は次の記号で参照する。

| 記号 | 内容 |
|------|------|
| D1 | Crop AI upsert のアダプターが認可を評価している（R0 違反） |
| D2 | 私有 Plan の REST 認可が `private(user_id)`（所有者のみ）で、組織スコープ経路と混在している（**決定により編集系は所有者のみが正**。読み取り系の扱いは要確認） |
| D3 | 削除 undo の予約認可（`schedule_allowed`）は所有者のみ判定で、本番未配線。削除側（組織スコープ）との非対称は、削除側の縮小で解消する |
| D4 | 公開 Plan の無認証読み取り（設計どおりの可能性） |
| D5 | 認証済みユーザーが私有ルート経由で公開 Plan の圃場栽培を更新できる（調査中に新規発見） |
| D6 | Masters 系の user_id のみ判定と組織スコープ判定の混在（網羅表） |
| D7 | **過剰許可の是正**: 組織メンバーに他メンバー所有 Plan の編集を許している経路の縮小（§0 の決定から派生） |

---

## 0. 決定事項

| 項目 | 内容 |
|------|------|
| 決定 | **組織メンバーに、他メンバーが所有する Plan の編集権限を与えない**。組織メンバーに許す場合でも**閲覧のみ**とする（または共有しない）。過剰許可を避ける厳格側に倒す |
| 決定の由来 | ユーザー指示の「**与えない**」を解釈した結果である（[`README.md`](README.md) の決定事項表にも記載）。この語には 2 通りの解釈があり、本書は **(b)** を採る。ユーザーの意図が (a) だけであった場合は、本節と D7 を差し替える |
| 解釈 (a)（本書では採らない） | API キーに書き込みスコープを与えない。[`03-api-key-scope-docs.md`](03-api-key-scope-docs.md) で扱う |
| 解釈 (b)（本書で採用） | 組織メンバーに他メンバー所有 Plan の編集権限を与えない |
| 適用範囲 | **Plan とその配下の編集**（圃場・作物の追加削除、adjust、削除、作業実績、タスクスケジュール、分散学習の更新系）。Farm / Crop / Masters の組織編集は決定の文言に含まれないため対象外とし、§3.1 P9 でユーザー確認に残す |
| 例外の扱い | `admin`（システム管理者）の扱いは決定に含まれない。§3.1 P3 で確認する（ADR-002 §4 は admin の全 org 横断を想定） |
| 影響 | §2、§3、§5〜§9 を本決定に沿って改訂した。D2 は「組織メンバーにも許す」方向へ揃えない。D3 は所有者のみ判定を正とする。D7 を新設し、既に組織メンバーへ編集を許している経路を縮小対象として洗い出した |

決定は「編集は所有者のみ」を**正**とする。したがって、`private_with_scope`（組織メンバー許可）の経路のうち**編集を伴うもの**は不適合であり、`private(user_id)`（所有者のみ）の経路は適合である。ただし、ADR-002 と #612 のコミットは組織単位の Plan 共有を意図しており（§2.3）、今回の決定は #612 が導入した編集許可の**縮小**である。

---

## 1. 概要と重大度

### 概要

ADR-002 の #612（Farm / Crop / Plan の組織スコープ認可、コミット `e020f1c66`）は、認可を「user_id 一致」から「user_id または所属組織一致」へ移す段階移行である。調査の結果、同じ Plan に対して経路ごとに判定方式が異なることを確認した。§0 の決定により、**判定方式の不一致そのものではなく、編集系が組織スコープで許可されているかどうか**が是正の基準になる。

- Plan の `data` 取得、`add_crop` / `add_field` / `remove_field` / `adjust` は `CultivationPlanRestAuth::private(user_id)` で組織 ID を空にして判定する（`cultivation_plans.rs:75`、`cultivation_plans_mutations.rs:320,440,546,751`）。合計 5 箇所のうち、`data` は読み取り、他の 4 箇所は編集である。**編集の 4 箇所は決定どおり（適合）**である。
- 一方、Plan の削除・作業実績（作成・更新・削除・写真）・タスクスケジュールの変更系・分散学習の更新系は組織スコープで**編集を許している**（§2.9）。決定と不整合であり、D7 として縮小対象にする。
- Plan の一覧・詳細・タイムライン・作業実績一覧・Cable 購読は組織スコープで**閲覧を許している**。決定と整合する（閲覧のみ許可）。
- 圃場栽培（field_cultivation）の認可スナップショットには `organization_id` が無く、私有 Plan は user_id（と admin）のみで判定する（§2.5）。編集の判定としては決定に適合する。

これとは独立に、次の 2 点を確認した。

- **D1**: `crop_ai_upsert_sqlite_persistence.rs:195` で、アダプターが `assert_edit_allowed` を呼ぶ。R0 の直接違反である。
- **D5**: 私有ルート `PATCH /api/v1/plans/field_cultivations/{id}` で、公開 Plan の圃場栽培が「認証済みユーザーなら誰でも更新可」になっている。公開 Plan のセッション検証（`X-Public-Plan-Session`）を私有ルートで迂回できる。コード読解のみで確認しており、実行による再現は未実施（§6 の RED で再現する）。

### 重大度

| 課題 | 重大度 | 種別 | 理由 |
|------|--------|------|------|
| D5 | **高（最優先）** | 過剰許可（他者データの改変） | 認証済みの任意ユーザーが、他人が作った公開 Plan の圃場栽培の日付を更新できる（コード読解による）。公開 Plan の ID は連番（§2.4）で列挙可能 |
| D7 | 中〜高 | 過剰許可（組織メンバーによる他メンバー Plan の編集・削除） | Plan の削除、作業実績、タスクスケジュール、分散学習の更新が、組織メンバーに許可されている（§2.9）。ただし本番の Plan INSERT が `organization_id` を書かないため、通常フローでは顕在化しにくい。一方、**組織メンバー追加 API に personal org のガードが無い**ため、personal org の所有者が他ユーザーをメンバーに追加すれば、backfill 済みの Plan が共有される経路がコード上は存在する（§2.3、実行での再現は未実施） |
| D2 | 低（方針確定） | 現行の `private(user_id)` は編集系で**仕様どおり** | 編集系 4 箇所は変更不要。`data` 取得のみ、閲覧のみ共有の是非を要確認（§3.1 P1） |
| D6 | 中〜低 | 過少許可（fail-closed）または対象外 | Crop のネスト Masters（害虫・農薬・ステージ）が組織メンバーに 404。Pest 等の Tier 1 拡張は ADR-002 の #612 スコープ外。編集の拡大を伴うため、決定の精神（厳格側）と照らして推奨を見直した（§3.1 P4） |
| D1 | 中 | 規約違反（R0）＋意図しないフォールスルー | 認可拒否が「作成」に化ける。対象 API は非推奨で、2026-10-18 に廃止予定（#323） |
| D3 | 低 | 規約違反・未配線 | 本番コードから `DeletionUndoScheduleInteractor` を生成する箇所を確認できなかった。削除側の縮小（D7）で非対称も解消する |
| D4 | 低（情報） | 設計どおりの可能性が高い | 共有リンク前提。列挙可能性は実在するが、読み取りは公開 Plan に限られる |

過剰許可（D5、D7）の修正が優先である。過少許可（D2 の `data` 取得、D6）は、閲覧に限れば緩めてよいが、**編集を組織メンバーへ広げる方向の修正は行わない**（§0）。

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

**方針適合の凡例**（§0 の決定「組織メンバーに他メンバー所有 Plan の編集を与えない。閲覧のみ許可または非共有」に対する判定）:

| 値 | 意味 |
|----|------|
| 適合 | 決定に沿っている（編集が所有者のみ、または閲覧のみ） |
| 適合（閲覧・要確認） | 閲覧に限られるので決定に沿う。ただし組織メンバーへ許すかどうかの一貫性は §3.1 P1 で確認 |
| **不適合（過剰許可）** | 編集・削除など変更系を組織メンバーに許している。縮小対象（D7） |
| **不適合（R0）** | 認可をアダプターが評価している（D1） |
| **不適合（過剰許可・公開）** | 公開 Plan を認証済みの誰でも編集できる（D5） |
| 未配線 | 本番から到達しない。到達する状態にする場合は不適合になり得る |
| 対象外 | Plan ではないため決定の適用範囲外（§0） |

| エンドポイント / 機能 | 判定方式 | 方針適合 | 根拠 |
|-----------------------|----------|----------|------|
| `GET /api/v1/plans/cultivation_plans/{id}/data`（読み取り） | **user_id**（組織 ID 空） | 適合（閲覧・要確認）。組織メンバーに閲覧を許すか否かは P1 | ルート `cultivation_plans.rs:24-27`、`CultivationPlanRestAuth::private(user_id)` `:75` |
| `POST .../{id}/add_crop` | **user_id** | **適合（正）** | `cultivation_plans_mutations.rs:320`（ルート `:60-63`）。なお add_crop の作物解決は scope gateway を使う（`add_crop_support.rs:32,126`）ため、Plan 認可と作物解決で方式が異なる。Plan 認可は所有者のみなので方針に影響しない |
| `POST .../{id}/add_field` | **user_id** | **適合（正）** | `cultivation_plans_mutations.rs:440`（ルート `:48-51`） |
| `DELETE .../{id}/remove_field/{field_id}` | **user_id** | **適合（正）** | `cultivation_plans_mutations.rs:546`（ルート `:52-55`） |
| `POST .../{id}/adjust` | **user_id** | **適合（正）** | `cultivation_plans_mutations.rs:751`（ルート `:56-59`）。interactor は `rest_plan_access` を評価（`plan_allocation_adjust_interactor.rs:107-114`） |
| 天候リスケ提案の一覧（読み取り） | **org** | 適合（閲覧・要確認） | `weather_reschedule_proposals_list_interactor.rs:53-55` |
| 天候リスケ提案プレビュー（adjust の dry-run） | 上流は **org**、下流の adjust で **user_id** の `private(self.user_id)` を再構成 | **不適合（過剰許可）**: 上流ゲートが組織メンバーに許している。ただし下流で 404 になるため、現状の実効は所有者のみ | `weather_reschedule_proposal_preview_interactor.rs:126-135`（org 判定）、`:175`（`private(self.user_id)`）。dry-run は永続化しない（`plan_allocation_adjust_interactor.rs:776-786`）が、adjust と同一の最適化を実行する |
| Plan 削除 | **org** | **不適合（過剰許可）** | `cultivation_plan_destroy_interactor.rs:66-69`（`member_organization_ids` → `assert_private_owned`）。ルート `plans.rs:51-52` |
| 私有 Plan 詳細（読み取り） | **org** | 適合（閲覧） | `private_owned_plan_detail_interactor.rs:75-77` |
| 私有 Plan 一覧（読み取り） | **org**（SQL の org サブクエリ） | 適合（閲覧） | `crates/agrr-adapters-sqlite/src/cultivation_plan/private_read_gateway.rs:32-34` |
| Cable の Plan 購読（受信のみ） | **org**（`private_with_scope`） | 適合（閲覧） | `cable_subscription_auth.rs:31-34,40-47`。スコープ解決は `cable.rs:403-407`（`unwrap_or_default`＝解決失敗は空スコープ＝fail-closed） |
| Cable の Farm 購読（受信のみ） | **user_id**（`farm_policy::view_allowed` に組織 ID 無し） | 対象外（Farm、閲覧のみ） | `cable_subscription_auth.rs:59` |
| タスクスケジュール: timeline 取得（読み取り） | **org** | 適合（閲覧） | `task_schedule_timeline_interactor.rs:67-69`、ルート `task_schedules.rs:44-45` |
| タスクスケジュール: item 作成 | **org** | **不適合（過剰許可）** | `task_schedule_item_create_interactor.rs:48-49`、ルート `task_schedules.rs:56-57` |
| タスクスケジュール: item 更新 | **org** | **不適合（過剰許可）** | `task_schedule_item_update_interactor.rs:80-81`、ルート `task_schedules.rs:60-61` |
| タスクスケジュール: item skip / unskip | **org** | **不適合（過剰許可）** | `task_schedule_item_skip_interactor.rs:50-51,69-70`、ルート `task_schedules.rs:48-53` |
| タスクスケジュール: regenerate（最適化ジョブの投入） | **org** | **不適合（過剰許可）** | `regenerate_task_schedule_interactor.rs:44-45`、ルート `task_schedules.rs:64-65` |
| タスクスケジュール: item 削除の undo 予約 | **org** | 未配線（本番から生成する箇所が無い。§2.6）。配線するなら不適合 | `task_schedule_item_schedule_deletion_undo_interactor.rs:55-56` |
| 作業実績: 一覧（読み取り） | **org** | 適合（閲覧） | `work_record_list_interactor.rs:49-50`、`work_record/interactors/private_plan_access.rs:11-17` |
| 作業実績: 作成・更新・削除 | **org** | **不適合（過剰許可）** | `work_record_create_interactor.rs:69-70`、`work_record_update_interactor.rs:64-65`、`work_record_destroy_interactor.rs:52-53`。ルート `work_records.rs:36-41` |
| 作業実績の写真: upload_init / upload_complete / destroy / upload_content | **org** | **不適合（過剰許可）** | `work_record_photo_upload_init_interactor.rs:62-63`、`work_record_photo_upload_complete_interactor.rs:67-68`、`work_record_photo_destroy_interactor.rs:53-54`、`work_record_photos.rs:332`（`upload_content`）。ルート `work_record_photos.rs:40-53` |
| 作業実績の写真: download（読み取り） | **org** | 適合（閲覧） | `work_record_photos.rs:426` |
| 予実サマリー・分散学習の取得（読み取り） | **org** | 適合（閲覧） | `plan_vs_actual_summary_interactor.rs:68-70`、`plan_variance_learning_read_interactor.rs:64-66` |
| 分散学習の更新（proposal / orchestration / handoff の PATCH） | **org** | **不適合（過剰許可）** | `plan_variance_learning_proposal_progress_update_interactor.rs:48-50`、`plan_variance_learning_orchestration_progress_update_interactor.rs:48-50`、`plan_variance_learning_handoff_update_interactor.rs:48-50`。ルート `plan_variance_learning.rs:46-50`、ハンドラー `:297` |
| 分散学習の reoptimize（最適化ジョブの投入） | **org** | **不適合（過剰許可）** | `plan_variance_learning_reoptimize_interactor.rs:51-52`。ルート `plan_variance_learning.rs:53-54` |
| 分散学習の import（`POST variance_learning`）／Plan 作成時の carryover | 対象 Plan（書き込み先）と元 Plan（読み取り元）を **org** で判定 | 書き込み先: **不適合（過剰許可）**。元 Plan の読み取り: 適合（閲覧） | `plan_variance_carryover_interactor.rs:90-97`（書き込み先）、`:99-105`（読み取り元）、`:120`（`save`）。ハンドラー `plan_variance_learning.rs:395-431`、`run_carryover_after_create` `:598-629`、`plans.rs:401-402` |
| 分散ポートフォリオ（読み取り） | 一覧は `user_id` のみで取得し、各行を org で再確認 | 適合（閲覧。他メンバーの Plan は列挙されない） | `variance_portfolio_interactor.rs:81-118`（`list_private_plan_index_rows_by_user_id`） |
| 作業ハブ読み取り | **user_id**（SQL が `f.user_id = ?1`、`cp.user_id = ?1`） | 適合（所有者のみ） | `crates/agrr-adapters-sqlite/src/work_record/work_hub_read_gateway.rs:36,42` |
| `GET/PATCH /api/v1/plans/field_cultivations/{id}`（私有 Plan） | **user_id** | **適合（正）**（編集は所有者と admin のみ） | ルート `field_cultivations.rs:29-34`、`plan_field_cultivation_access.rs:8-30`、`FieldCultivationPlanAccessSnapshot` に `organization_id` 無し |
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
| R4 契約テストで組織 Plan を検証しているのは**閲覧のみ**（`org_member_can_view_team_plan`、`org_non_member_denied_team_plan`）。組織メンバーによる Plan の削除・作業実績・タスクスケジュールの契約テストは確認できなかった | `crates/agrr-r4-contract/tests/contracts.rs:4306,4332`（Farm / Crop は更新まで検証: `:4157,4242`）。`rg` でテスト関数名を列挙して確認。テスト本体の全文精読はしていない |
| 作業実績・タスクスケジュール・削除・分散学習の interactor テストは、`EmptyScopeGateway` と `organization_id: None` のフィクスチャのみで、組織メンバーが編集できることを検証していない | `crates/agrr-domain/test/work_record/interactors_work_record_update_interactor_test.rs:20`、`.../cultivation_plan/interactors_cultivation_plan_destroy_interactor_test.rs:13,145` ほか（`rg -i org` で確認） |
| Plan 作成の INSERT は `organization_id` を書かない | `crates/agrr-adapters-sqlite/src/cultivation_plan/cultivation_plan_gateway.rs:54-57`、`plan_save_plan_copy.rs:105-107` |
| `organization_id` は personal organization の backfill でのみ埋まる（対象表に `cultivation_plans` を含む） | `personal_organization_sqlite_gateway.rs:29-39`（対象表）。詳細は [`01-resource-limit-bypass.md`](01-resource-limit-bypass.md) §2.4 |
| 組織メンバー追加の interactor は、操作者のロールと付与ロールのみを検査し、対象組織が personal org かどうかを検査しない（メンバーシップ系 interactor に `is_personal` の参照が無い。personal org のガードは削除 interactor のみ） | `crates/agrr-domain/src/organization/interactors/organization_membership_create_interactor.rs:47-97`、`organization_delete_interactor.rs:63`。`rg is_personal` で確認 |

**判定（どちらが正か）**: 決定により、**編集系は所有者のみが正**である。`private(user_id)` の編集系 4 箇所（`add_crop` / `add_field` / `remove_field` / `adjust`）は「#612 の適用漏れ」ではなく**仕様どおり**の可能性が高い（#612 が組織メンバーへ編集を許す意図を明記していないこと、閲覧のみが契約テストされていること、決定が所有者のみを求めていることによる）。したがって**「組織メンバーにも許す」方向への揃えは行わない**。むしろ、同じ Plan 配下で編集を組織メンバーに許している経路（§2.9）が決定と不整合であり、縮小対象になる。

`data` 取得（`cultivation_plans.rs:75`）は読み取りである。組織メンバーに閲覧を許すか否かは決定の範囲内でどちらも適合する。現状は、組織メンバーが Plan の一覧・詳細・タイムライン・作業実績一覧を閲覧できる一方で、`data`（Gantt の描画に使う。`frontend/src/app/adapters/plans/plan-api.gateway.ts:34`）と圃場栽培の `climate_data`（`field-climate-api.gateway.ts:22`）は 404 になる。この中途半端な状態の扱いは §3.1 P1 で推奨を出し、ユーザー確認に残す。詳細（`/plans/{id}`）と `data` が同等の情報を返すかは**未確認**（`workbench_payload.rs:6-27` と詳細 DTO を比較していない）。

**顕在性（部分的に未確認）**: Plan の INSERT が `organization_id` を書かないため、通常フローで生成された Plan の `organization_id` は backfill による personal org のみと推測される。personal org のメンバーは所有者本人のみのはずだが、組織メンバー追加 API に personal org のガードが無い（上表）ため、所有者が他ユーザーを追加すれば、backfill 済みの Plan は組織スコープの経路（§2.9）で編集・削除可能になる。実行による再現は未実施（§6 T7-9 で確認する）。他の org へ Plan を割り当てる経路（管理 UI、SQL、他 API）が存在するかは**未確認**。

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

**方針との関係**: D6 は Farm / Crop / Masters が中心で、決定（Plan の編集）の適用範囲外である。ただし、`#1`（Plan REST）と `#2`（プレビュー）は Plan であり、決定により「`#1` の編集系は正、`#2` の上流ゲートは縮小」になる。

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
| 18 | `work_records` / `task_schedules` / 分散学習 / Plan 削除の interactor 群 | org | — | **編集系は決定と不整合（D7）**。閲覧系は適合（§2.9） |

Pest / Pesticide / Fertilize / AgriculturalTask / InteractionRule の組織対応は、ADR-002 では Tier 1 のデータモデル（`organization-data-model.md`）に載っているが、#612 の認可移行スコープは Farm / Crop / Plan に限られる。したがって #8〜#12 は「バグ」ではなく「未展開」として扱う。

### 2.8 組織スコープ判定の共通仕様（過剰許可の前提）

| 事実 | 根拠 |
|------|------|
| `organization_member_access(ids, is_reference, record_org)` は、非参照かつ `record_org` が `ids` に含まれれば true。**役割（owner / admin / member）を見ない** | `crates/agrr-domain/src/shared/org_scope.rs:13-23` |
| `ReferenceRecordAccessFilter` の view / edit は user_id 一致または上記の組織一致で許可。view と edit の差は無い | `crates/agrr-domain/src/shared/reference_record_access_filter.rs`、`reference_record_authorization.rs` |
| Plan 系は、閲覧と編集の両方が同じ関数に流れている: `private_cultivation_plan_access_policy::access_denied`、`work_record::private_plan_access::access_allowed`、`task_schedule_private_plan_access::access_allowed`。**閲覧だけを組織メンバーに許し、編集を所有者のみにするには、この 3 つを閲覧用と編集用に分ける必要がある** | `private_cultivation_plan_access_policy.rs:8-24`、`work_record/interactors/private_plan_access.rs:11-17`、`cultivation_plan/interactors/task_schedule_private_plan_access.rs:14` |
| ADR-002 §4 は「`OrganizationAccessPolicy`（仮称）— メンバーシップ＋ロール＋`organization_id` 一致」を構想している | `docs/adr/ADR-002-organization-multi-tenancy.md` §4 |
| 実装には `OrganizationAccessPolicy` に相当するロール判定が存在しない（`crates/agrr-domain/src/shared/` と `organization/` を確認した範囲） | **未確認**（網羅的な検索はしていない） |

### 2.9 D7: 決定に反して組織メンバーへ編集を許している経路（縮小すべき箇所）

「編集」は、永続化・削除・最適化ジョブ投入を伴う操作とする。読み取りのみの経路は含めない。判定はすべて `private_cultivation_plan_access_policy::access_denied` に帰着する（`task_schedule_private_plan_access.rs:14`、`work_record/interactors/private_plan_access.rs:14`、`cultivation_plan_destroy_interactor.rs:69`）。

| # | 縮小対象 | 現状の根拠 | 縮小後の判定 |
|---|----------|-----------|--------------|
| S1 | Plan 削除 | `cultivation_plan_destroy_interactor.rs:66-69`（ルート `plans.rs:51-52`） | 所有者のみ（admin は P3）。非所有者は現行どおり `plans.errors.not_found`（同 `:69-73` の失敗経路） |
| S2 | タスクスケジュールの item 作成・更新・skip・unskip・regenerate | `task_schedule_item_create_interactor.rs:48-49`、`task_schedule_item_update_interactor.rs:80-81`、`task_schedule_item_skip_interactor.rs:50-51,69-70`、`regenerate_task_schedule_interactor.rs:44-45` | 所有者のみ。非所有者は現行どおり `on_not_found`（`skip` の `:52`）と同型 |
| S3 | 作業実績の作成・更新・削除、写真の upload_init / upload_content / upload_complete / destroy | `work_record_create_interactor.rs:69-70`、`work_record_update_interactor.rs:64-65`、`work_record_destroy_interactor.rs:52-53`、`work_record_photo_upload_init_interactor.rs:62-63`、`work_record_photo_upload_complete_interactor.rs:67-68`、`work_record_photo_destroy_interactor.rs:53-54`、`work_record_photos.rs:332` | 所有者のみ。閲覧（一覧 `work_record_list_interactor.rs:49-50`、写真ダウンロード `work_record_photos.rs:426`）は組織メンバーに許可したままにできる（P1） |
| S4 | 分散学習の更新系（proposal / orchestration / handoff の PATCH、reoptimize、import の書き込み先、Plan 作成時の carryover の書き込み先） | `plan_variance_learning_proposal_progress_update_interactor.rs:48-50`、`plan_variance_learning_orchestration_progress_update_interactor.rs:48-50`、`plan_variance_learning_handoff_update_interactor.rs:48-50`、`plan_variance_learning_reoptimize_interactor.rs:51-52`、`plan_variance_carryover_interactor.rs:90-97` | 所有者のみ。carryover の**元 Plan の読み取り**（`:99-105`）は閲覧なので組織メンバー許可のままにできる |
| S5 | 天候リスケ提案プレビュー（adjust の dry-run）の上流ゲート | `weather_reschedule_proposal_preview_interactor.rs:126-135`。下流の adjust は `private(self.user_id)`（`:175`）で 404 になり、現状の実効は所有者のみ | 上流ゲートを編集用（所有者のみ）にして、上流と下流を揃える。提案の**一覧**（`weather_reschedule_proposals_list_interactor.rs:53-55`）は閲覧として維持できる |
| S6 | D5（公開 Plan の圃場栽培） | §2.5 | 公開 Plan は私有ルートから編集不可 |
| S7 | `task_schedule_item_schedule_deletion_undo_interactor.rs:55-56`（未配線） | §2.6 | 配線されていないため現時点で縮小は不要。将来配線するなら所有者のみにする。D3 の削除案と併せて扱う |

**影響範囲の確認（読み取りのみで確認）**: 上記の interactor は、いずれも `scope_gateway` を受け取って `member_organization_ids` を解決している。縮小後、編集系の interactor は組織 ID を必要としなくなる。コンストラクタから `scope_gateway` を外すか、閲覧用の共通ヘルパーのみが組織 ID を使うかは、§5.7 で選択肢を示す。

---

## 3. あるべき認可方針

### 3.1 判断が必要な論点

決定（§0）により、旧 P1 の選択肢のうち「(b) 全メンバーに編集も許可」「(c) ロールで分ける」は採らない。旧 P1 の論点は、**閲覧のみを組織メンバーに許すか**に置き換えた。

| # | 論点 | 選択肢 | 推奨 | ユーザー確認 |
|---|------|--------|------|--------------|
| P1 | 組織メンバーに他メンバー所有 Plan の**閲覧のみ**を許すか（編集は §0 で所有者のみに確定済み） | (a) 閲覧を許す。現状の閲覧経路（一覧・詳細・タイムライン・作業実績一覧・Cable・予実・分散学習の取得）を維持し、`data` と圃場栽培の `climate_data` も閲覧として許可して一貫させる。(b) 閲覧も許さない（非共有）。現状の閲覧経路も所有者のみに縮小する。(c) 現状維持（閲覧経路は許し、`data` と `climate_data` は所有者のみのまま） | **(a)** を推奨する。理由: 現状すでに一覧・詳細・タイムライン・作業実績一覧を組織メンバーへ許しており、`data` と `climate_data` だけ閉じても秘匿の実益が小さく、共有 Plan を開くと Gantt が 404 になる（`plan-api.gateway.ts:34`）。R4 契約テストも閲覧を組織メンバーに許す前提（`contracts.rs:4306`）。ただし、これは**閲覧権限の新規拡大**を含む（`data` と `climate_data`）ため、「過剰許可を避ける厳格側」を優先するなら (c)（現状維持）または (b) も妥当である。(a) の場合、詳細と `data` が同等の情報かの確認が要る（U13） | **必要** |
| P2 | Plan のロール別制御を今回入れるか | (a) 入れない。(b) `OrganizationAccessPolicy` を導入 | (a)。決定は「所有者のみ」なのでロールの出番が無い。ロール導入は別課題 | 不要（決定により (a) で確定。確認するなら別課題として） |
| P3 | 公開 Plan の圃場栽培を私有ルートで更新できてよいか（D5）、および `admin` の扱い | (a) 不可（公開 Plan の変更は公開ルート＋セッション必須）。(b) 所有者のみ許可 | (a)。`admin` は例外を残すか要確認。編集の縮小（D7）でも `admin` を許すか同時に決める | **必要**（admin の扱い） |
| P4 | Crop のネスト Masters を組織メンバーに許可するか（D6 #3） | (a) Crop 本体と同じ組織スコープにそろえる。(b) 所有者のみ（現行を仕様として明文化） | **(b)（現状維持）を推奨に見直した**。旧推奨は (a) だったが、(a) は組織メンバーの編集を Crop 配下に広げる。決定の適用範囲は Plan だが、精神（過剰許可を避ける）に照らすと、今回は広げない。読み取りだけを広げる場合は、ネスト Masters の閲覧用と編集用の判定を分ける必要があり（現状は `crop_masters_nested_access.rs:12` の 1 系統のみ。全ネスト経路の判定は未精査）、別課題 | **必要** |
| P5 | Pest 等 Tier 1 の組織展開を本課題に含めるか | (a) 含めない。(b) 含める | (a)。別 issue で展開範囲を定義。展開時は閲覧と編集を分ける | **必要** |
| P6 | D1: 認可拒否時の挙動 | (a) 現行維持（拒否→新規作成）。(b) Forbidden を返す | (b)。他ユーザーの `crop_id` を指定した更新が新規作成に化けるのは、意図として不自然。ただし互換性影響あり | **必要** |
| P7 | D3: `schedule_allowed` の扱い | (a) 組織対応にする。(b) 未配線なら削除する | **(b) を確定推奨**。所有者のみが正（決定）で、本番未配線、アダプターも Plan 系に未対応。呼び出し元の再確認（U4）後に削除。(a) は決定に反するため採らない | 必要（削除の可否のみ） |
| P8 | D4: 公開 Plan の読み取り | (a) 許容（現行）。(b) 許容し設計として文書化。(c) 対策（非連番 ID、レート制限） | (b) を最小案とする。(c) は共有リンク仕様が固まってから | **必要** |
| P9 | Farm / Crop の組織編集（`farm_update_interactor.rs:94`、`crop_create_interactor.rs:60`、R4 `contracts.rs:4157,4242`）を決定と同じ厳格側へ縮小するか | (a) 決定の範囲外として維持。(b) Plan と同様に閲覧のみへ縮小 | (a)。決定の文言は Plan のみで、Farm / Crop の組織編集は R4 で明示的にテストされている。厳格側へ寄せる場合は別 issue で契約テストごと見直す | **必要**（決定の解釈範囲） |
| P10 | D7 の縮小を、既存の組織共有データがある環境へ適用する際の扱い | (a) 即時に縮小。(b) 縮小前に、組織メンバーが実際に他メンバーの Plan を編集した実績があるかを本番データで確認する | (b) を推奨。本番の組織メンバー数・共有 Plan 数は本調査で**未確認**（`production-primary-sqlite-query` スキルで確認できる） | **必要** |

### 3.2 ADR-002 の Phase との整合

| 項目 | 整合 |
|------|------|
| ADR-002 Migration phases 6「ポリシー移行」(#612) は Farm / Crop / Plan の組織スコープ認可。**決定は #612 が導入した Plan の編集許可を縮小する**ため、ADR-002 の「リソース共有」の解釈を「閲覧共有」に狭めることになる。ADR-002 と `organization-data-model.md`（`member` ロールは「org 内リソースの CRUD」）の文言と決定が食い違うため、文書の更新が必要（[`09-stale-design-docs`](09-stale-design-docs.md) 側で扱う） | `docs/adr/ADR-002-organization-multi-tenancy.md` Migration phases の表、`docs/design/organization-data-model.md` ロール表 |
| ADR-002 §4「Gateway は `organization_id` による狭い永続化クエリのみ」。D1 は Gateway（Persistence）が認可を評価しており、§4 と R0 の双方に反する | 同 §4、`LAYER-RULES.md`（R0） |
| ADR-002 §4「admin は全 org を横断可能（現行 `user.admin` と同等）」。D5・D7 で `admin` を許可する場合は §4 と整合 | 同 §4 |
| ロール判定は §4 に記載があるが、Phase 6 の実装では未導入（§2.8）。本課題では導入しない（P2 (a)） | — |
| Tier 1 のうち Pest 等の展開は #612 の範囲外（§2.7）。本課題では扱わない（P5 (a)） | `docs/design/organization-data-model.md` |

---

## 4. 影響範囲

| 課題 | 影響を受けるもの |
|------|------------------|
| D1 | `POST` の Crop AI 生成 API（`ai_api.rs:50`）。非推奨で廃止予定（`builtin-generation-sunset.md:67-68`）。呼び出し元フロントの有無は**未確認** |
| D2 | 変更なし（編集系 4 箇所は正）。`data` 取得のみ P1 (a) の場合に変更。フロントの Plan 画面が共有 Plan を開いたときの 404 |
| D3 | 汎用 undo 予約（本番の呼び出し元は確認できず）。削除案の場合、`DeletionUndoScheduleInteractor`、`schedule_authorization.rs`、`find_schedulable_record`（ポートとアダプター）、関連テストが削除対象になり得る（削除の範囲は U4 の再確認後に確定） |
| D4 | 公開 Plan の閲覧 URL、SEO メタ（`public-plan-results-seo-meta.ts`）、公開ウィザード |
| D5 | `PATCH /api/v1/plans/field_cultivations/{id}`（フロントは未使用）。`show` / `climate_data` の私有ルート閲覧は公開 Plan を許可している点で挙動を変える場合は影響あり |
| D6 | Cable の Farm 購読（閲覧の一貫化）。Crop ネスト Masters と Field は現状維持（P4 (b)） |
| D7 | Plan 削除 API、タスクスケジュールの変更系 API、作業実績と写真の変更系 API、分散学習の更新系 API、天候リスケ提案プレビュー。組織メンバーがこれらを使っている場合は 404 に変わる（P10）。フロントが組織メンバーの編集 UI を持つかは**未確認** |
| ドキュメント | `docs/api/openapi.yaml` の該当エンドポイントの認可記述（**未確認**: 現状の記述内容は読んでいない）。ADR-002 と `organization-data-model.md` の「共有」の解釈。関連: [`08-openapi-gaps`](#10-関連課題との依存) |

変更してはならないもの（回帰防止）:

- 公開 Plan の変更系におけるセッション一致検証（`X-Public-Plan-Session`）。
- 所有者本人のアクセス（閲覧・編集・削除のすべて）。
- 組織メンバーの**閲覧**経路のうち、P1 で維持と決めたもの（一覧・詳細・タイムライン・作業実績一覧・Cable の Plan 購読など）。
- 非メンバーの拒否。

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

### 5.2 D2（確定: 編集系は所有者のみが正）

| 層 | 変更 |
|----|------|
| Edge（編集系 4 箇所） | `cultivation_plans_mutations.rs:320,440,546,751` の `CultivationPlanRestAuth::private(user_id)` は**変更しない**。「組織メンバーにも許す」ための `private_with_scope` への置換は行わない |
| Domain（防御の明示化） | `private(user_id)` が所有者のみになるのは、組織 ID が空だから、という暗黙の性質に依存している（§2.3）。将来 `private_with_scope` が編集ハンドラーに誤って渡されると、組織メンバーに編集が開く。これを防ぐため、`rest_plan_access::evaluate` に「閲覧」と「編集」の意図を区別する引数（例: `RestPlanAccessIntent::{View, Edit}`）を持たせ、`Edit` のときは組織 ID があっても所有者のみを許可する。編集系 interactor（`add_crop_interactor.rs:137-141`、`add_field_interactor.rs:63-67`、`remove_field_interactor.rs:61-65`、`plan_allocation_adjust_interactor.rs:107-114`）は `Edit` を渡す。任意の追加防御であり、必須ではない。要否は S1〜S5 の設計（§5.7）と合わせて決める |
| Edge（`data` 取得、P1 (a) の場合のみ） | `cultivation_plans.rs:75` で `private_with_scope(user_id, member_organization_ids)` を構築する。`cable.rs:403-407` と同じ scope gateway を使う。解決失敗は空スコープ（fail-closed）にして、ログを出す。P1 (b) または (c) の場合は変更しない |
| Domain（P1 (a) の場合のみ） | 圃場栽培の `climate_data` を閲覧として組織メンバーに許す場合、スナップショットに `organization_id` を持たせ、**閲覧判定のみ**を組織対応にする（編集判定は §5.1 のとおり所有者と admin のみ）。P1 (c) の場合は変更しない |
| Domain policy | `private_cultivation_plan_access_policy.rs` は §5.7 で閲覧用と編集用に分ける |

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
| 決定との整合 | D1 は Crop の認可であり、決定（Plan の編集）の適用範囲外。組織メンバーの Crop 編集は現行の #612 仕様（R4 `contracts.rs:4242`）を維持する（P9） |

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

### 5.7 D7（過剰許可の是正: 編集系を所有者のみへ縮小）

閲覧用と編集用の判定を分け、S1〜S5 の編集系 interactor を編集用（所有者のみ）へ切り替える。

| 層 | 変更 |
|----|------|
| Domain policy | `private_cultivation_plan_access_policy.rs` に、閲覧用（現行の `access_denied` を維持。組織メンバー許可）と、編集用（例: `edit_denied(plan, user_id)`。私有かつ `plan.user_id == user_id` のみ許可。組織 ID を受け取らない）を分ける。`assert_private_owned` は名称に反して組織メンバーを許すため、閲覧用の意図なら名称を改め、編集用は新しい関数を使う（命名は `plan_field_cultivation_access.rs` の `assert_view_allowed` / `assert_edit_allowed` に合わせる） |
| Domain helper | `work_record/interactors/private_plan_access.rs:11-17` と `cultivation_plan/interactors/task_schedule_private_plan_access.rs:14` を、`view_allowed`（組織 ID を受け取る）と `edit_allowed`（受け取らない）に分ける。閲覧用は既存の閲覧 interactor が使い、編集用は S1〜S5 の interactor が使う |
| Domain interactor | S1〜S5 の interactor（§2.9）が編集用を呼ぶようにする。編集用は組織 ID を必要としないため、`scope_gateway` の注入と `member_organization_ids` の解決が不要になる。**コンストラクタから `scope_gateway` を外す**のが最小構成（`project-necessary-code-only`）だが、呼び出し元（`agrr-server` の各ハンドラー）とテストのフィクスチャ（`EmptyScopeGateway`）の変更を伴う。外さずに未使用の引数として残すのは避ける |
| Domain（プレビュー） | `weather_reschedule_proposal_preview_interactor.rs:126-135` の上流ゲートを編集用にして、`:175` の `private(self.user_id)` と揃える |
| Gateway（SQLite） | 変更なし（認可を足さない） |
| Edge（axum） | S3 の `work_record_photos.rs:332`（`upload_content`）は、ハンドラー内で `plan_access_allowed` を直接呼ぶ構成。編集用へ切り替える（ハンドラーは薄く保つ方針 R7 に反しない範囲で、ドメインの編集用ヘルパーを呼ぶ）。閲覧用の `:426`（download）は維持 |
| 応答の互換 | 非所有者に対する応答は、現行の「所有者でも組織メンバーでもない」ときと同じ 404 系にする（新しい 403 を導入しない） |

### 5.8 補足: 過剰許可の混入を防ぐ機械的な確認

S1〜S5 の縮小後、編集系の interactor が `member_organization_ids` を解決していないことを `rg` で確認する（受け入れ条件 A13）。ガードスクリプトへの追加は任意とし、必須にしない。

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

### 6.2 D2（編集系は所有者のみを固定。読み取りは P1 次第）

| ID | パス案 | given / when / then | 種類 / ランナー |
|----|--------|---------------------|----------|
| T2-1 | `crates/agrr-r4-contract/tests/contracts.rs`（`org_member_cannot_add_crop / add_field / remove_field / adjust_on_team_plan`） | given `seed_org_scoped_plan(org, owner)`、`org` のメンバー `member`（`seed_organization_membership`、`support.rs:1721`） / when 各 POST・DELETE（member のセッション）/ then 404 かつ DB 不変。**現行で GREEN の見込み**（`private(user_id)` により所有者のみ。未実行のため**未確認**）。決定を固定する特性化テストであり、将来 `private_with_scope` が誤って渡された場合の防止になる。`adjust` は最適化バイナリ（`lib/core/agrr`）を要するかが**未確認**のため、認可のみを確認できる入力（不正入力で 422 になる等）を使う | 特性化 / `run-rust-contract-tests.sh` |
| T2-2 | 同上 | given 同じ組織 Plan、所有者 / when 同じ各 API / then 認可は通り、認可以外の入力検証結果が返る（404 でないこと） | 特性化 / 同上 |
| T2-3 | 同上（P1 (a) の場合のみ。`org_member_can_get_private_plan_data`） | given 組織 Plan、member / when `GET /api/v1/plans/cultivation_plans/{id}/data` / then 200。現行は 404 のため RED | RED（P1 (a) のみ）/ 同上 |
| T2-4 | 同上（`non_member_gets_404_for_org_scoped_plan_data`） | given 同じ Plan、org に属さないユーザー / when 同 GET / then 404（過剰許可の防止） | 特性化 / 同上 |
| T2-5 | `crates/agrr-domain/test/cultivation_plan/interactors_rest_plan_access_test.rs`（既存。§5.2 の `Edit` 意図を導入する場合のみ） | given 私有 Plan、所有者でない org メンバーで、組織 ID を含む auth と `Edit` 意図 / when `evaluate` / then `NotFound`。`View` 意図なら `Allowed`。現行は意図の区別が無くコンパイルできないため RED | RED（任意）/ `run-test-rust-domain.sh` |

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

### 6.7 D7（縮小の RED）

前提: 現行の interactor テストは `EmptyScopeGateway` と `organization_id: None` のみを使う（§2.3）。RED を書くには、**組織 ID を返すフェイクのスコープゲートウェイ**（例: `MemberScopeGateway { org_ids: vec![42] }`）と、`organization_id = Some(42)` の他ユーザー所有 Plan のフィクスチャが必要になる。これは現行のコンストラクタ（`scope_gateway` あり）で書ける。GREEN でコンストラクタから `scope_gateway` を外す場合は、テストも同じコミットで更新する（未 GREEN のコミットを残さない）。

| ID | パス案 | given / when / then | 種類 / ランナー |
|----|--------|---------------------|----------|
| T7-1 | `crates/agrr-domain/test/cultivation_plan/policies_private_cultivation_plan_access_policy_test.rs`（既存に追記） | 編集用の判定（§5.7）: given 私有 Plan（`organization_id = Some(42)`、所有者 5）/ when 所有者 5 で編集判定 / then 許可。ユーザー 99（組織 42 のメンバー）で編集判定 / then **拒否**。組織外ユーザー / then 拒否。公開 Plan / then 拒否。あわせて閲覧用（`access_denied`、既存 `:68-93`）が組織メンバーを許可し続けることを固定する。編集用関数が未定義のため RED（コンパイル失敗を含む） | RED / `run-test-rust-domain.sh` |
| T7-2 | `crates/agrr-domain/test/cultivation_plan/interactors_cultivation_plan_destroy_interactor_test.rs`（既存に追記）（S1） | given 組織 42 の Plan（所有者 5）、`MemberScopeGateway` が 42 を返すユーザー 99 / when `call` / then `on_failure` が not_found 相当、ゲートウェイの `delete` が 0 回。所有者の削除は成功。現行は組織メンバーが削除できるため RED | RED / 同上 |
| T7-3 | `crates/agrr-domain/test/cultivation_plan/interactors_task_schedule_item_create_interactor_test.rs` ほか（create / update / skip / unskip / regenerate。既存ファイルの有無は**未確認**で、無ければ新規）（S2） | given 組織 42 の Plan、ユーザー 99 / when 各 `call` / then `on_not_found`、変更用ゲートウェイ（`skip_item_for_plan` など）と enqueue が 0 回。所有者は成功 | RED / 同上 |
| T7-4 | `crates/agrr-domain/test/work_record/interactors_work_record_{create,update,destroy}_interactor_test.rs` と `..._photo_upload_init_interactor_test.rs`、`..._photo_upload_complete_...`、`..._photo_destroy_...`（既存の有無は個別に**未確認**）（S3） | 同じ given / when `call` / then not_found、永続化が 0 回。閲覧（`work_record_list_interactor`）は組織メンバーで成功のまま（特性化） | RED（変更系）/ 特性化（一覧）/ 同上 |
| T7-5 | `crates/agrr-domain/test/cultivation_plan/interactors_plan_variance_learning_{proposal_progress,orchestration_progress,handoff}_update_interactor_test.rs`、`..._reoptimize_interactor_test.rs`、`interactors_plan_variance_carryover_interactor_test.rs`（S4） | 同じ given / when `call` / then not_found（carryover は書き込み先の Plan で `RecordNotFoundError`）、`upsert_*` / `save` / enqueue が 0 回。carryover の元 Plan が他メンバー所有・組織共有の場合は、書き込み先が自分の Plan なら成功（閲覧の維持。特性化） | RED / 同上 |
| T7-6 | `crates/agrr-domain/test/cultivation_plan/interactors_weather_reschedule_proposal_preview_interactor_test.rs`（既存。`:23,31` に `EmptyScopeGateway`）（S5） | given 組織 42 の Plan、`MemberScopeGateway` のユーザー 99 / when プレビュー `call` / then 上流ゲートで `RecordNotFoundError`（現行は上流を通過して下流の adjust で not found になる。**adjust が呼ばれないこと**をスパイで検証。現行は adjust が呼ばれるため RED）。提案一覧は組織メンバーで成功（特性化） | RED / 同上 |
| T7-7 | `crates/agrr-r4-contract/tests/contracts.rs` に追記（S1〜S4 の代表） | given `seed_user_organization` と `seed_organization_membership(.., "member")`（`support.rs:1721`）と `seed_org_scoped_plan`（`support.rs:1882`）、member のセッション / when `DELETE /api/v1/plans/{id}`、`POST /api/v1/plans/{id}/work_records`、`POST .../task_schedule/items`、`PATCH .../task_schedule/items/{item_id}/skip`、`POST .../task_schedule/regenerate`、`PATCH .../variance_learning`、`POST .../variance_learning/reoptimize` / then 404 で DB 不変。現行は 200 系のため RED。所有者は 200 系（特性化） | RED / `run-rust-contract-tests.sh` |
| T7-8 | 同上（閲覧の維持） | given 同じ組織 Plan、member / when `GET /api/v1/plans/{id}`（既存 `org_member_can_view_team_plan` `:4306`）、`GET .../work_records`、`GET .../task_schedule`、`GET .../plan_vs_actual/summary` / then 200。非メンバーは 404（既存 `org_non_member_denied_team_plan` `:4332`） | 特性化 / 同上 |
| T7-9 | 同上（顕在性の確認） | given personal org の所有者と、`POST /api/v1/organizations/{personal_org_id}/memberships` で追加された別ユーザー、backfill 済みの Plan / when そのユーザーが Plan を `DELETE` / then 縮小後は 404。縮小前は組織メンバーとして削除できることを実行で確認する（§2.3 の顕在性の裏取り。personal org へのメンバー追加自体を許すかは別論点で、本書では扱わない） | RED（縮小前に実行して事実を確認）/ 同上 |

### 6.8 完了時の実行

`tdd-on-edit` と `rails-testing-workflow` に従い、個別 GREEN → 全体（`run-test-rust-domain.sh` と `run-rust-contract-tests.sh`）→ 遅延検知（[`test-slow-detection`](../../.cursor/skills/test-slow-detection/SKILL.md)）の順で実行する。`crates/agrr-server/**`、`crates/agrr-domain/**`、`crates/agrr-adapters-*/**` を変更したので、Docker で検証する前に `.cursor/skills/dev-docker/scripts/rebuild-restart.sh` を実行する。

---

## 7. 実装ステップ（順序・コミット粒度）

前提: §3.1 のユーザー確認（少なくとも P1、P3、P6、P9、P10）が済んでいること。確認前は着手しない。ステップごとに RED → GREEN → リファクタで 1 コミットを基本とし、RED のテストは実装と同じコミットに含めてよい（未 GREEN のコミットを残さない）。

| # | ステップ | コミット | 依存 |
|---|----------|----------|------|
| 1 | D5: T5-1〜T5-7 の RED を書く → `plan_field_cultivation_access` と `FieldCultivationUpdateInteractor` を修正して GREEN | `fix(authz): forbid private-route edit of public plan field cultivations` | P3 |
| 2 | D7 の土台: T7-1 の RED → `private_cultivation_plan_access_policy` に編集用判定を追加し、閲覧用と分ける。`work_record` と `task_schedule` の共通ヘルパーを閲覧用と編集用に分ける（呼び出し元はまだ切り替えない） | `refactor(authz): split plan view and edit access policies` | P1、P3 |
| 3 | D7 S1: T7-2、T7-7（削除）の RED → `cultivation_plan_destroy_interactor` を編集用へ | `fix(authz): restrict plan destroy to owner` | 2、P10 |
| 4 | D7 S2 / S5: T7-3、T7-6、T7-7（task_schedule、regenerate）の RED → タスクスケジュールの変更系とプレビューの上流ゲートを編集用へ | `fix(authz): restrict task schedule mutations and preview to owner` | 2、P10 |
| 5 | D7 S3: T7-4、T7-7（work_records）の RED → 作業実績と写真の変更系を編集用へ（写真の `upload_content` を含む） | `fix(authz): restrict work record mutations to owner` | 2、P10 |
| 6 | D7 S4: T7-5、T7-7（variance_learning）の RED → 分散学習の更新系と carryover の書き込み先を編集用へ | `fix(authz): restrict variance learning mutations to owner` | 2、P10 |
| 7 | D7 後始末: 編集系 interactor から未使用になった `scope_gateway` の注入を外し、ハンドラーとテストを更新する。`rg` で編集系に `member_organization_ids` が残っていないことを確認（A13） | `refactor(authz): drop unused org scope from owner-only interactors` | 3〜6 |
| 8 | D2: T2-1、T2-2、T2-4 の特性化テストを追加（コード変更なし）。任意で `Edit` 意図（T2-5）を導入。P1 (a) の場合のみ T2-3 の RED → `data` 取得と `climate_data` を閲覧として組織対応 | `test(authz): pin owner-only plan mutations` ／ 任意 `fix(authz): org-aware view for plan data` | P1 |
| 9 | D6 #13 Cable の Farm 購読（任意）: T6-1 の RED → `farm_subscription_denied` の修正 | `fix(authz): org-aware farm cable subscription` | 1 とは独立。任意 |
| 10 | D1: T1-1〜T1-4 の RED → ポートとインタラクターの再設計 → アダプターの認可削除 | `refactor(crop-ai): move upsert authorization into interactor` | P6（#323 の廃止時期を確認したうえで着手を判断） |
| 11 | D3: 呼び出し元の再確認（U4）→ 削除案（`DeletionUndoScheduleInteractor` ほか）。T3-2 | `chore(deletion-undo): remove unwired schedule authorization` | P7、3（削除側の縮小の後） |
| 12 | D4: 設計としての文書化（必要時） | `docs: document public plan share-link access model` | P8 |
| 13 | 任意: アーキテクチャガードにアダプター認可の検出を追加 | `chore(guard): forbid authorization calls in adapters` | 10 の後 |
| 14 | 全体検証: 全テスト、遅延検知、`rebuild-restart.sh` での Docker 確認 | （コミットなし） | 1〜13 |

順序の理由: ステップ 1 は過剰許可（高重大度）で他に依存しないため最優先。ステップ 2 は D7 の全ステップの土台で、閲覧用と編集用の分離が無いと閲覧を維持したまま編集だけを縮小できない。ステップ 3〜6 は独立に進められるが、互いに同じヘルパーを使うため 2 の後にする。ステップ 11 は、削除側の縮小（3）で非対称が解消したあとに行う。ステップ 10 は廃止予定の API に対する規約違反のため、他より後にする。

---

## 8. リスク・未確定事項

### 8.1 セキュリティ・互換性リスク

| リスク | 内容 | 軽減策 |
|--------|------|--------|
| 過剰許可の残存（D7） | 組織スコープ判定は**役割を見ない**（§2.8）。縮小前は、`member` ロールのユーザーが他メンバーの Plan を削除し、作業実績やタスクを書き換えられる。組織メンバー追加 API に personal org のガードが無い（§2.3）ため、所有者の操作で backfill 済みの Plan が共有される経路がコード上は存在する（実行での再現は未実施） | S1〜S5 の縮小。T7-7、T7-9 を RED に置く。personal org へのメンバー追加を制限するかは別論点（本書の範囲外）として P10 と併せてユーザーへ報告。01 の backfill 拡張（`cultivation_plans.organization_id` を埋める）より先に、または同時に適用する（§10 の 01 の行） |
| 縮小による互換性影響（D7） | 組織メンバーが他メンバーの Plan の作業実績やタスクを編集する運用が既にある場合、縮小で 404 に変わる。フロントに組織メンバー向けの編集 UI があるかは**未確認**。本番の組織メンバー数・共有 Plan 数も**未確認** | P10 で本番データを確認してから適用する（`production-primary-sqlite-query` スキル）。応答は現行の 404 系を維持し、新しい 403 を導入しない |
| 閲覧の縮小・拡大の取り違え | 閲覧用と編集用を分けずに編集用へ一括置換すると、閲覧経路（一覧・詳細・タイムライン・作業実績一覧・Cable）まで所有者のみになる。逆に閲覧用のまま残すと編集が開いたままになる | ステップ 2 で先に分離する。T7-8 で閲覧の維持を固定する |
| `private(user_id)` の暗黙依存 | 編集系 4 箇所が所有者のみになるのは、組織 ID が空だから（§2.3）。将来の変更で `private_with_scope` が渡されると、編集が組織メンバーに開く | T2-1 の特性化テスト。任意で `Edit` 意図の導入（§5.2、T2-5） |
| スコープ解決失敗時の挙動 | `data` を組織対応にする場合（P1 (a)）、ハンドラーでスコープ解決が失敗したときに空スコープで続行する（Cable の `unwrap_or_default`, `cable.rs:403-407`）のは fail-closed だが、失敗を隠す | 空スコープ（fail-closed）を既定とし、ログを出す |
| P1 (a) による閲覧権限の拡大 | `data` と `climate_data` を組織メンバーへ許すと、閲覧権限が新規に広がる。詳細と `data` が同等の情報かは**未確認**（U13） | 情報の同等性を確認してから決める。厳格側を優先するなら (c) または (b) |
| 組織 ID が NULL のレコードの扱い | `organization_member_access` は `record_org` が `None` のとき false。NULL 行は所有者経由のみ許可される。意図どおり | 変更しない。backfill は [`01-resource-limit-bypass.md`](01-resource-limit-bypass.md) §2.4 の扱いに従う |
| D5 の修正で admin をどう扱うか | admin は現在すべての Plan を編集できる（`plan_field_cultivation_access.rs:8-24`）。公開 Plan でも admin を許すと、admin が公開 Plan を編集できる状態が残る。D7 の編集用判定も admin を含めるかを同時に決める必要がある（`private_cultivation_plan_access_policy` は現状 admin を見ない） | P3 で確認。admin の許可を維持するなら明文化する |
| D5 の修正が閲覧を狭めるリスク | `assert_edit_allowed` を分離するとき、`assert_view_allowed` を変えると、公開 Plan の私有ルート閲覧（show / climate_data）が壊れる | T5-2 で閲覧の回帰を固定する |
| D1 で拒否を Forbidden にする互換性 | 現行の「拒否→作成」に依存するクライアントがある場合、Forbidden への変更で挙動が変わる | P6。クライアントの有無は**未確認**。廃止予定 API のため、現行維持（P6 (a)）で R0 違反のみ解消する選択肢もある |
| D3 削除案のとき、トークンのみの復元 | `POST /undo_deletion` は認可を評価しない（§2.6）。D3 の削除案では復元側は変わらない | U12 で別途確認 |
| D4 の対策不備 | 連番 ID による公開 Plan の列挙が可能なまま。個人情報を含むかは未確認 | 応答フィールドの精査（別途）。P8 |

### 8.2 未確定事項

| # | 内容 | 状態 |
|---|------|------|
| U1 | P1、P3〜P10 のユーザー判断（P2 は決定で確定） | §3.1 |
| U2 | AI 更新経路が `expected_updated_at` を渡さず常に stale になる疑い（`crop_gateway.rs:218-234`、`crop_ai_upsert_sqlite_persistence.rs:199-233`） | 未確認（RED で先に実行確認する。事実なら P6 の影響が変わる） |
| U3 | 組織 Plan が通常フローで生成されるか（`organization_id` を書く INSERT が §2.3 の 2 箇所に無い）。他の割り当て経路の有無。personal org へメンバーが追加された実績の有無 | 未確認 |
| U4 | `DeletionUndoScheduleInteractor` と `TaskScheduleItemScheduleDeletionUndoInteractor` の全呼び出し経路（マクロ・動的ディスパッチを含む）。`rg` では本番の構築箇所を確認できなかった | 未確認（`rg` の範囲内では未配線） |
| U5 | 公開 Plan の応答に個人情報が含まれるか（`workbench_payload.rs:6-27` を含む応答全体の精査） | 未確認 |
| U6 | 共有リンク前提を明記した文書の有無（ADR・設計文書の網羅検索） | 未確認 |
| U7 | ~~`work_hub_read_gateway.rs:36,42` の判定方式~~ | **解消**: SQL が `f.user_id = ?1` と `cp.user_id = ?1` のみ（所有者のみ）。§2.2 に反映 |
| U8 | `crop_nested_pests_access.rs:12`、`crop_resolve_by_name_policy.rs`、`field_cultivation_climate_crop_view_policy.rs:16` の組織対応の要否（§2.7 #5） | 未精査 |
| U9 | アダプター／`agrr-server` ユニットテストの規約上の実行入口が `test-common` に無い | 規約上の空白。RED はドメインと R4 に置く方針で回避。恒久対応は別課題 |
| U10 | `openapi.yaml` の該当エンドポイントの認可記述 | 未確認 |
| U11 | D5 の実行による再現 | 未実施（T5-3、T5-4 で確認する） |
| U12 | undo トークンの推測困難性と有効期限（`POST /undo_deletion` が認可を評価しない前提で、実害の範囲を確認する） | 未確認 |
| U13 | 私有 Plan 詳細（`/plans/{id}`）と workbench（`/data`）の応答が同等の情報かどうか（P1 (a) の可否に影響） | 未確認 |
| U14 | 本番の組織メンバー数、共有 Plan 数、組織メンバーによる他メンバー Plan の編集実績（P10） | 未確認（本番データに依存） |
| U15 | D7 の各ルートを実際に叩く組織メンバー向けのフロント UI の有無 | 未確認 |
| U16 | 認可失敗の状態コード統一（403 / 404 / 422）と、403 の書き込みがレート制限に数えられる点。03（R-4）、07、08（D-12）が本課題へ引き継いでいる | 本書は未対応（判定の可否のみ扱う）。別途、統一方針を決める必要がある |

---

## 9. 受け入れ条件

| # | 条件 | 検証 |
|---|------|------|
| A1 | 認証済みの非所有者（かつ非 admin、P3 の決定に従う）が、私有ルートから公開 Plan の圃場栽培を更新できない | T5-1、T5-3、T5-4 |
| A2 | 公開 Plan の変更は公開ルート＋セッション一致でのみ成功し、私有 Plan の所有者は従来どおり更新できる | T5-5、T5-6 |
| A3 | 公開 Plan の閲覧（show / climate_data / public data）が従来どおり動く | T5-2、既存の公開 Plan 契約テスト |
| A4 | **組織メンバー（非所有者）は、他メンバー所有 Plan の編集系 API（`add_crop` / `add_field` / `remove_field` / `adjust`、圃場栽培の PATCH）を実行できず 404 になる**。所有者は従来どおり実行できる | T2-1、T2-2、T5-7 |
| A5 | 組織メンバー（非所有者）は、他メンバー所有 Plan の**削除、作業実績・写真の変更、タスクスケジュールの変更（create / update / skip / unskip / regenerate）、分散学習の更新（PATCH / reoptimize / import / carryover の書き込み先）、天候リスケ提案プレビュー**を実行できず、404 かつ DB 不変になる | T7-2〜T7-7、T7-9 |
| A6 | 組織メンバーの閲覧経路のうち P1 で維持と決めたもの（Plan 一覧・詳細・タイムライン・作業実績一覧・写真ダウンロード・予実・分散学習の取得・Cable の Plan 購読）が従来どおり 200 になる。非メンバーは 404 のまま。P1 (a) の場合は `data` と `climate_data` も 200 になる | T7-8、T2-3（P1 (a) のみ）、T2-4 |
| A7 | `crates/agrr-adapters-*` の非テストコードが `reference_record_authorization` や `*_policy::*_allowed` を呼ばない（Crop AI upsert） | `rg` による確認と T1-1〜T1-4 |
| A8 | 他ユーザーの `crop_id` に対する Crop AI upsert が、P6 で決めた挙動になる | T1-1 |
| A9 | `schedule_authorization.rs` が P7 の決定どおり（削除、または所有者のみ判定の維持）で、組織対応にされていない。削除側（Plan 削除）も所有者のみで、削除と undo の判定が一致している | T3-1 または削除の確認、T7-2 |
| A10 | D4 が設計として文書化されている（P8 (b) の場合） | 文書の存在 |
| A11 | `run-test-rust-domain.sh` と `run-rust-contract-tests.sh` が全体 GREEN、遅延検知に新規の遅いテストが無い | 全体実行と `test-slow-detection` |
| A12 | 過剰許可の回帰が無い: 非メンバー・非所有者の拒否テスト（T2-4、T5-1、T5-4、T5-7、T7-1〜T7-7）がすべて GREEN | 同上 |
| A13 | S1〜S5 の編集系 interactor に、組織 ID の解決（`member_organization_ids`）と組織スコープの許可判定が残っていない | `rg "member_organization_ids"` の結果を編集系ファイルについて確認 |
| A14 | P9 の決定（Farm / Crop の組織編集の扱い）が本書または別 issue に記録されている | 文書の存在 |

---

## 10. 関連課題との依存

`docs/spec-defects/` の他番号との関係。2026-09-29 時点で 01〜11 のファイルが存在する。06、07、08 は初版の時点では存在を確認できなかったが、今回の改訂で存在を確認し、下表の該当箇所のみ（`rg` で認可に触れる行）を読んだ。**各文書の全文は精読していない**。

| 番号 | 課題 | 本書との関係 |
|------|------|--------------|
| 01 `resource-limit-bypass` | Farm / Crop 作成上限がユーザー単位と組織単位で食い違う | **強い依存**。D1 の作成上限判定のアダプター内評価（`crop_ai_upsert_sqlite_persistence.rs:177`）は同じコードを対象にする。D1 の移設と 01 の上限スコープの統一は、同じポート変更で一度に行うのが自然。Plan の `organization_id` が NULL のままである点（§2.3）は 01 §2.4 の backfill と同根。ステップ 10 と 01 の実装順は事前に調整する。**順序の制約（D7）**: 01 は backfill の拡張で `cultivation_plans.organization_id` を埋める予定（01 R10、手順 10・12）。埋まると、組織スコープ経路（§2.9）の過剰許可が顕在化しやすくなる。したがって、**D7 の縮小（ステップ 2〜7）を、01 の `cultivation_plans` backfill より先に、または同時に適用する** |
| 02 `contact-recaptcha` | 問い合わせフォームの reCAPTCHA | 依存なし |
| 03 `api-key-scope-docs` | API キーのスコープ文書と実装の不一致 | **§0 の「与えない」の解釈 (a)（API キーに書き込みスコープを与えない）は本課題ではなく 03 で扱う**。本書の決定 (b) とは独立で、両方を採用しても矛盾しない（03 §0 と README の決定事項表に記載）。03 は、API キーが有効なのは `/api/v1/masters/*` に限られると記す（03 §2.4）。すなわち Plan 系の D7 の経路は API キーの対象外と読める（03 側の根拠は未検証）。03 が課題 10 へ引き継ぐ項目: 403 になる書き込みがレート制限に数えられること（03 §2.9、R-4）。本書は扱っておらず、§8.2 U16 に残す |
| 04 `api-key-query-auth` | API キーのクエリ認証 | 依存なし |
| 05 `fail-closed-critical` | agrr 失敗時の成功形レスポンス | 依存なし。`data` を組織対応にする場合（P1 (a)）の「スコープ解決失敗時の扱い」（§8.1）は fail-closed 方針で整合させる |
| 06 `fail-closed-suspected` | fail-closed 違反の疑い（8 項目） | 06 は認可の一貫性を「独立」とし、`climate_data` 経路の認可チェックには触れないと記す（06 の該当行）。本書の D5・D7 と競合しない。06 の全文は未精査 |
| 07 `frontend-error-contract` | フロントとサーバーのエラー契約 | 07 は、Masters の update の認可失敗の状態コードが揃っていない（pests / pesticides / fertilizes は 403、agricultural_tasks / interaction_rules は 422 + `errors: ["forbidden"]`）ことを「課題 10 の範囲」と記す。**本書は判定の可否（誰に許すか）を扱い、認可失敗の状態コード統一（403 / 404 / 422）は扱っていない**。§8.2 U16 に残す。D7 の縮小で組織メンバーの操作が 404 に変わる点は、07 の「エラー本文を単一形式に統合する」決定と整合させる |
| 08 `openapi-gaps` | `openapi.yaml` と実装の乖離 | 08 の D-12 は、認可の返し方（403 / 404 / 422）の統一を「10 と合わせて判断」と記す。本書は状態コードの統一方針を持たない（U16）。D5、D7 の認可挙動の変更は `openapi.yaml` の記述更新を伴う可能性がある（U10）。08 が扱う範囲と重複しないよう調整する |
| 09 `stale-design-docs` | 設計文書が実装と乖離（ADR-002 / organization-data-model ほか） | **依存が強まった**。決定（組織メンバーに他メンバー Plan の編集を与えない）は、ADR-002 の「リソース共有」と `organization-data-model.md` の `member` ロール（「org 内リソースの CRUD」）の記述と食い違う。本書はロール導入を範囲外にしたため、09 側で文書の更新を扱う（§3.2） |
| 11 `low-priority-misc` | 低優先度の雑多な不整合 | 独立。D4（公開 Plan の列挙可能性）を低優先度として 11 に移す判断もありうるが、本書では P8 の確認対象とした |

依存の要点: 本書のステップ 1（D5）は他の課題に依存せず単独で着手できる。ステップ 2〜7（D7）は P1、P3、P10 の確認後に着手し、09 とは文書更新の整合を取る。ステップ 10（D1）は 01 と同一のポート変更に触れるため、01 と順序調整が必要である。
