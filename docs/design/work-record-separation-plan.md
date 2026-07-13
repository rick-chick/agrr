# work_record 分離計画（作業予定と作業実績のモデル分離）

最終更新: 2026-06-12 / ステータス: 計画（未着手）

GUI 側の計画は [`work-record-gui-plan.md`](work-record-gui-plan.md)。本書はバックエンド（スキーマ・ドメイン・アダプタ・サーバ配線）のみを扱う。

---

## 0. この文書の読み方（実装者向け）

- 本書は**全体像を知らない実装者がフェーズ単位で着手できる**ことを目的とする。各フェーズは「スコープ / 作成・変更ファイル / 受け入れ条件 / テスト」を自己完結で記す。
- 着手前に必ず読むもの:
  - リポジトリ直下 [`ARCHITECTURE.md`](../../ARCHITECTURE.md) — 該当層の `What we require` / `Prohibited practices`（最上位規約）
  - [`CLAUDE.md`](../../CLAUDE.md) — テストコマンド・ワークフロー
  - `.cursor/skills/clean-architecture-violation-fix-workflow/SKILL.md` — 新規実装も同じワークフロー（セクション0〜6）を踏む
- **注意**: `CLAUDE.md` には Rails 時代の記述が残るが、ランタイムの正は Rust（`crates/agrr-server` + `crates/agrr-domain` + `crates/agrr-adapters-sqlite`）。`app/` ディレクトリは存在しない。
- フェーズの依存関係: P1 → P2 → P3 → P4 → P5 → P6 の順。P2 は P1 と並行可（スキーマに依存しないドメイン単体テストのため）。**フェーズ単位でコミット可能**だが、P4 完了まではユーザー向け機能は出ない。

## 1. 背景・目的

### 1.1 何を作るか

作付け計画（cultivation_plan）から生成される**作業予定**（task_schedule_items）に対し、**作業実績**（work_records、新設）を別エンティティとして記録できるようにする。

### 1.2 なぜ分離するか（設計判断の根拠）

予定と実績は性質が異なる:

| | 作業予定 (task_schedule_items) | 作業実績 (work_records) |
|---|---|---|
| 性質 | **導出データ**。lib/core/agrr の GDD 計算から再生成可能 | **事実の記録**。不変、ユーザー入力 |
| ライフサイクル | 気象予測更新・作付け変更で**全置換したい** | 再生成で**消えてはいけない** |
| 生成IF | `lib/core/agrr` 由来でまだ流動的 | 安定（ユーザー操作のみ） |

現行スキーマは `task_schedule_items` 1 行に実績カラム（`status` / `actual_date` / `actual_notes` / `completed_at` / `rescheduled_at` / `cancelled_at`）を埋め込んでいる（`crates/agrr-migrate/migrations/schema/V1__baseline.sql:249`）。このままだと:

1. 予定の再生成（`replace_schedule_for_field_category` は全置換IF）が実績を破壊する
2. 「予定にない実績」「1 予定に複数日の実績」「部分実施」が表現できない
3. agrr 生成IFの変更のたびに実績保全ロジックが gateway に染み出す

分離後の不変条件:

- **work_records は task_schedule_items の再生成・削除で消えない**（FK は `ON DELETE SET NULL`）
- 予定の「完了」は work_records からの**導出**（リンクされた record の有無）であり、items 側に二重に真実を持たない
- 予定外実績（`task_schedule_item_id IS NULL`）は第一級の正常データ

### 1.3 用語

- **予定 (schedule item)**: `task_schedule_items` の 1 行。`source` が `agrr`（生成）か手動か
- **実績 (work record)**: 実際に行った作業の記録。新設 `work_records` の 1 行
- **予定由来実績**: `task_schedule_item_id` が非 NULL の work_record。「予定を完了する」操作の実体
- **予定外実績**: `task_schedule_item_id IS NULL` の work_record
- **skip**: 「この予定はやらない」という予定側への意思決定。実績ではない

## 2. 現状インベントリ（2026-06-12 調査）

実装者は着手フェーズに関係する箇所だけ読めばよいが、「何が無いか」は重要なので全体を記す。

### 2.1 スキーマ（`crates/agrr-migrate/migrations/schema/`）

- `V1__baseline.sql:249` — `task_schedule_items`: 予定カラム + 実績カラム混在。`status` DEFAULT `'planned'`
- `V1__baseline.sql:262` — `task_schedules`: `cultivation_plan_id` NOT NULL / `field_cultivation_id` NULL / `category` / `source` DEFAULT `'agrr'`。items はこの配下
- 現行最新マイグレーションは `V4`。**新規テーブルは V5**
- Rails 時代に complete 操作が稼働していたため、**本番 DB に `actual_date` / `completed_at` 入りの行が存在しうる** → バックフィル必須（P1）

### 2.2 ドメイン（`crates/agrr-domain/src/`）

| パス | 状態 |
|---|---|
| `cultivation_plan/interactors/task_schedule_timeline_interactor.rs` | **稼働中**（唯一サーバ配線済み） |
| `cultivation_plan/interactors/task_schedule_item_complete_interactor.rs` | Ruby 移植済みだが**サーバ未配線・SQLite gateway 実装なし** |
| `cultivation_plan/interactors/task_schedule_item_create_interactor.rs` / `..._update_interactor.rs` / `..._schedule_deletion_undo_interactor.rs` | 同上（未配線） |
| `cultivation_plan/gateways/task_schedule_item_mutation_gateway.rs` | インターフェースのみ。実装ゼロ |
| `cultivation_plan/policies/task_schedule_item_update_policy.rs` | `scheduled_date` 変更で `status: rescheduled` を付与 |
| `agricultural_task/interactors/task_schedule_generate_interactor.rs` | 生成（agrr 連携）。`replace_schedule_for_field_category` / `delete_all_for_field_category` を呼ぶ。**SQLite 実装なし** |
| `agricultural_task/constants/task_schedule_item_statuses.rs` | `planned` / `rescheduled` / `completed` の 3 定数 |

**重要**: complete 系は Rust ランタイムでは**未出荷**。API 互換の制約はなく、work_record 方式へ直接置き換えてよい（旧 complete IF の温存は不要）。

### 2.3 サーバ（`crates/agrr-server/src/`）

- `task_schedules.rs` — `GET /api/v1/plans/{id}/task_schedule` のみ。presenter を route モジュール内に定義し、gateway を `state.sqlite` から組む**この形が配線の参照実装**
- `lib.rs:111` で `.merge(task_schedules::routes())`
- R4 契約テスト（`crates/agrr-r4-contract/tests/contracts.rs`）に task_schedule 関連は**ゼロ**

### 2.4 アダプタ（`crates/agrr-adapters-sqlite/src/`）

- `cultivation_plan/task_schedule_timeline_read.rs` — timeline 読み出し実装（稼働中）
- mutation / generate 系 gateway の実装は**なし**

## 3. 目標モデル

### 3.1 新テーブル `work_records`（V5）

```sql
CREATE TABLE "work_records" (
  "id" integer PRIMARY KEY AUTOINCREMENT NOT NULL,
  "cultivation_plan_id" integer NOT NULL,
  "field_cultivation_id" integer,          -- 予定外実績で圃場不明なら NULL 可
  "task_schedule_item_id" integer,         -- 予定由来なら参照。予定外は NULL
  "agricultural_task_id" integer,          -- タスクマスタ参照（予定が消えても作業種別を同定）
  "name" varchar NOT NULL,                 -- 作業名スナップショット（マスタ・予定の後変更に依存しない）
  "task_type" varchar,
  "actual_date" date NOT NULL,
  "amount" decimal(10,3),
  "amount_unit" varchar,
  "time_spent_minutes" integer,
  "notes" text,
  "created_at" datetime(6) NOT NULL,
  "updated_at" datetime(6) NOT NULL,
  FOREIGN KEY ("cultivation_plan_id") REFERENCES "cultivation_plans" ("id"),
  FOREIGN KEY ("task_schedule_item_id") REFERENCES "task_schedule_items" ("id") ON DELETE SET NULL
);
CREATE INDEX "index_work_records_on_plan_and_date" ON "work_records" ("cultivation_plan_id", "actual_date");
CREATE INDEX "index_work_records_on_task_schedule_item_id" ON "work_records" ("task_schedule_item_id");
```

設計上の決定（実装時に変えないこと。変える必要が出たら実装を止めてユーザーに確認）:

- `name` は**スナップショット**。予定やマスタの後編集・削除に実績が引きずられない
- `ON DELETE SET NULL`: 予定の再生成（delete + insert）で実績は**自動的に予定外実績へ降格**して生き残る。再リンクは v1 スコープ外（§7）
- 所有権は `cultivation_plan_id` 経由（既存の `task_schedule_private_plan_access::access_allowed` と同じ認可チェーン）。`user_id` カラムは持たない
- 1 つの予定に**複数の work_record を許す**（複数日にまたがる作業・部分実施）

### 3.2 「完了」の意味論の変更

- 予定 item が完了 ⇔ `EXISTS (SELECT 1 FROM work_records WHERE task_schedule_item_id = item.id)`。**読み出し時に導出**（timeline read の LEFT JOIN）
- `task_schedule_items.status` への `'completed'` の**書き込みは廃止**。`status` は予定側の状態（`planned` / `rescheduled` / `skipped`）のみを表す
- `skipped` を新設（P5）: 「やらない」決定。`cancelled_at`（既存カラム）にタイムスタンプ。skip された item は work_record を持てる（後から気が変わってやった場合は skip 解除せず record を作れば完了扱い、と単純化する）
- `actual_date` / `actual_notes` / `completed_at` カラムは P6 で削除（それまで**書き込み禁止・読み出しは互換のためのみ**）

### 3.3 予定の再生成との整合

**方針転換（issue #206）**: ユーザー優先は「予定表に完了した作業が残り続けること」。再生成は未完了の agrr 生成予定のみ置換し、次を温存する:

| 温存対象 | 条件 |
|---|---|
| 実績付き予定 | `work_records.task_schedule_item_id` が紐づく item（timeline の `completed: true` 維持） |
| 手動追加予定 | `source` が `manual_entry` または `agricultural_task_entry`（実績なしでも温存） |

- 保護判定・重複抑制マッチングは **domain**（`task_schedule_item_preservation_policy` + `task_schedule_protected_merge_mapper`）。gateway は `preserved_item_ids` + `items_to_insert` の永続化のみ。
- 温存 item の `scheduled_date` は更新しない（完了作業の可視性 > GDD 追随）。
- 同一 `field_cultivation_id` + `category` で両方に `agricultural_task_id` がある場合、`(agricultural_task_id, stage_order)` が一致する新 item は INSERT しない（重複抑制）。
- `work_records` は引き続き `ON DELETE SET NULL`。温存は **ID 温存**でリンク維持（自動再リンクは §7 非スコープ）。

## 4. API 契約

全エンドポイントはセッション認証必須（`session_auth::user_id_from_session`）、plan 所有チェック（`task_schedule_private_plan_access` 相当）で他人の plan は 404。

### 4.1 `POST /api/v1/plans/{plan_id}/work_records` — 実績作成

```jsonc
// リクエスト（予定由来: item からサーバ側でプリフィル）
{ "work_record": { "task_schedule_item_id": 123, "actual_date": "2026-06-12",
                   "amount": "1.5", "amount_unit": "kg", "notes": "雨上がりに実施" } }
// リクエスト（予定外: name 必須）
{ "work_record": { "name": "緊急防除", "task_type": "pesticide", "actual_date": "2026-06-12",
                   "field_cultivation_id": 45, "notes": "アブラムシ発生" } }
```

- `task_schedule_item_id` 指定時: item が同一 plan に属することを検証（違えば 422）。`name` / `task_type` / `agricultural_task_id` / `field_cultivation_id` / `amount` / `amount_unit` は**未指定なら item から複写**、指定があれば上書き
- `task_schedule_item_id` 未指定時: `name` と `actual_date` が必須（欠落で 422）
- 201: `{ "work_record": { ...全カラム..., "task_schedule_item": { "id", "name", "scheduled_date" } | null } }`
- 422: `{ "errors": { "<field>": ["<i18n key>"] } }`（既存の `shared::validation::from_errors` 形式）

### 4.2 `GET /api/v1/plans/{plan_id}/work_records?from=&to=&field_cultivation_id=` — 一覧

- 200: `{ "work_records": [ ... ] }`、`actual_date` 降順。`from` / `to` は `actual_date` の閉区間フィルタ（任意）

### 4.3 `PATCH /api/v1/plans/{plan_id}/work_records/{id}` — 実績修正

- 更新可能: `actual_date` / `amount` / `amount_unit` / `time_spent_minutes` / `notes` / `name`。**`task_schedule_item_id` の付け替えは v1 では不可**（指定されたら 422）

### 4.4 `DELETE /api/v1/plans/{plan_id}/work_records/{id}` — 実績削除

- 200: `{ "deleted": true }`。deletion_undo 統合は v1 スコープ外（§7）

### 4.5 既存 `GET /api/v1/plans/{id}/task_schedule`（timeline）の拡張

各 item の JSON に追加（既存フィールドの削除・改名はしない）:

```jsonc
{
  "completed": true,                    // work_record リンク有無から導出
  "work_records": [ { "id": 9, "actual_date": "2026-06-12", "notes": "..." } ]
}
```

`status` フィールドは当面従来値を返す（フロントの表示互換）が、`completed` の真実は導出値側。

### 4.6 `PATCH /api/v1/plans/{plan_id}/task_schedule/items/{id}/skip` / `unskip`（P5）

- skip: `status: "skipped"` + `cancelled_at` 記録。unskip: `planned` に戻し `cancelled_at` を NULL
- 200: `{ "item": { "id", "status", "cancelled_at" } }`

## 5. 実装フェーズ

各フェーズ共通:

- ドメイン変更時は `ARCHITECTURE.md` の禁止 1–39 と照合（ゲート手順: `.cursor/rules/ca-violation-fix-architecture-gate.mdc`）
- テストは**個別ファイル指定で GREEN → 指定なしで全体**の順
- コマンド:
  - domain: `.cursor/skills/test-common/scripts/run-test-rust-domain.sh [ARGS]`
  - 契約（adapters/server 込みフルスタック）: `scripts/run-rust-contract-tests.sh`
- 完了報告は exit code 確認後のみ（`.cursor/rules/dont-finish-task-while-process-is-running.mdc`）

### P1 — スキーマ: `work_records` テーブル + バックフィル

**作成**: `crates/agrr-migrate/migrations/schema/V5__work_records.sql`

1. §3.1 の DDL
2. バックフィル（Rails 時代の完了データ救済）:

```sql
INSERT INTO work_records (cultivation_plan_id, field_cultivation_id, task_schedule_item_id,
                          agricultural_task_id, name, task_type, actual_date, amount, amount_unit,
                          notes, created_at, updated_at)
SELECT ts.cultivation_plan_id, ts.field_cultivation_id, i.id,
       i.agricultural_task_id, i.name, i.task_type,
       COALESCE(i.actual_date, date(i.completed_at)), i.amount, i.amount_unit,
       i.actual_notes, COALESCE(i.completed_at, i.updated_at), COALESCE(i.completed_at, i.updated_at)
FROM task_schedule_items i JOIN task_schedules ts ON ts.id = i.task_schedule_id
WHERE i.status = 'completed' OR i.completed_at IS NOT NULL;
```

**注意**: `actual_date` と `completed_at` が両方 NULL で `status='completed'` の行が理論上ありうる。その場合 `i.updated_at` の日付で代替する COALESCE を 1 段足すこと。カラム削除は**ここではしない**（P6）。

**受け入れ条件**: `agrr-migrate` 既存テストが GREEN / 新規 DB と V4 既存 DB の両方でマイグレーションが通る / `status='completed'` の行数と work_records 挿入行数が一致

### P2 — ドメイン: 新文脈 `work_record`

**作成**: `crates/agrr-domain/src/work_record/`（`mod.rs` + 下記）。`crates/agrr-domain/src/lib.rs` に `pub mod work_record;` 追加。

```
entities/work_record_entity.rs
dtos/work_record_create_input.rs      // from_params: 4.1 の検証（予定外は name 必須 等）
dtos/work_record_update_input.rs
dtos/work_record_list_input.rs        // from/to/field_cultivation_id
dtos/work_record_read.rs              // 出力用
gateways/work_record_gateway.rs       // trait: create/list_for_plan/update/destroy/find_for_plan
gateways/task_schedule_item_lookup_gateway.rs
                                      // trait: item の plan 帰属確認 + プリフィル元属性取得
interactors/work_record_create_interactor.rs
interactors/work_record_list_interactor.rs
interactors/work_record_update_interactor.rs
interactors/work_record_destroy_interactor.rs
ports/（各 interactor の output port。on_success / on_not_found / on_record_invalid）
```

**実装規約**（違反しやすい点のみ）:

- 認可は既存 `cultivation_plan::interactors::task_schedule_private_plan_access::access_allowed` と同じパターン（plan gateway を注入し interactor 冒頭で確認、不許可は `on_not_found`）。re-export せず、`work_record` 文脈に同等の薄いアクセス関数を置いてよい（文脈間の interactor 直 import を避ける）
- 日時は `ClockPort` 注入（`crate::shared::ports::ClockPort`）。`time::OffsetDateTime::now_utc()` 直呼び禁止
- create のプリフィル（item からの複写）は **interactor 内のロジック**。gateway に「プリフィル済み blob を返させる」のは境界違反（gateway は item 属性をそのまま返すだけ）
- エラーモデルは既存踏襲: `RecordInvalidError` / `RecordNotFoundError` + `call_rescuing` パターン（参照実装: `task_schedule_item_complete_interactor.rs:68`）

**テスト**: `crates/agrr-domain/test/work_record/interactors_work_record_*_test.rs`。既存の inline `include!` パターン踏襲（参照: `task_schedule_item_complete_interactor.rs:96-100`）。最低限のケース:

- 予定由来 create（プリフィル動作 / item が他 plan → 422 相当）
- 予定外 create（name 欠落 → record_invalid / 正常系）
- 他ユーザー plan → on_not_found
- update で `task_schedule_item_id` 指定 → record_invalid
- list の date 範囲フィルタ

**受け入れ条件**: `run-test-rust-domain.sh` 全体 GREEN / ARCHITECTURE.md ゲート記録（1 回目・2 回目）出力済み

### P3 — アダプタ: SQLite gateway 実装

**作成**: `crates/agrr-adapters-sqlite/src/work_record/`（`mod.rs` + `work_record_gateway.rs` + `task_schedule_item_lookup_gateway.rs`）。`lib.rs` に公開。

- 参照実装: `crates/agrr-adapters-sqlite/src/cultivation_plan/task_schedule_timeline_read.rs`（pool の受け方・行マッピング）
- 統合テストは同 crate 内 `*_integration_test.rs` パターン（参照: `cultivation_plan/plan_save_session_integration_test.rs`）。fixture で plan + task_schedule + item を作って CRUD 一巡を検証

**受け入れ条件**: adapters の cargo テスト GREEN（`scripts/run-rust-contract-tests.sh` が adapters を含むためこれで可）

### P4 — サーバ: ルート配線 + R4 契約

**作成**: `crates/agrr-server/src/work_records.rs`。**変更**: `crates/agrr-server/src/lib.rs`（`pub mod` + `.merge(work_records::routes())`）。

- **参照実装は `crates/agrr-server/src/task_schedules.rs` を丸ごと読む**こと: presenter（output port 実装）をモジュール内に定義し、`state.sqlite` から gateway を構築し、interactor に注入する。`rescue_from` 相当の横断エラーハンドラを作らない
- ルート: §4.1〜4.4 の 4 本
- R4 契約テスト追加: `crates/agrr-r4-contract/tests/contracts.rs` に最低限「未認証 → 401」「認証 + 正常 create → 201」「予定外 create の name 欠落 → 422」を追加（既存テストの `ContractClient` パターン踏襲）

**受け入れ条件**: `scripts/run-rust-contract-tests.sh` 全体 GREEN / 0.5 秒超テストなし（`.cursor/skills/test-slow-detection/SKILL.md`）

### P5 — timeline 拡張 + skip

1. **timeline 読み出し**（`crates/agrr-adapters-sqlite/src/cultivation_plan/task_schedule_timeline_read.rs` と `crates/agrr-server/src/task_schedule_timeline_json.rs`）: work_records LEFT JOIN を追加し、item ごとに `completed`（導出 bool）と `work_records` サマリ配列を出す（§4.5）。既存 JSON フィールドは**削除・改名しない**（フロント互換）
2. **skip**: `agricultural_task/constants/task_schedule_item_statuses.rs` に `SKIPPED` 追加。`cultivation_plan` 文脈に `task_schedule_item_skip_interactor`（skip/unskip 両対応、`cancelled_at` を ClockPort で記録）。gateway は `task_schedule_item_mutation_gateway.rs` にメソッド追加 + SQLite 実装。サーバは §4.6 の 2 ルート
3. timeline の `status` 表示はそのまま、`skipped` が新たに流れてくる点だけ JSON マッパーで素通しする

**受け入れ条件**: domain + 契約テスト GREEN / 既存 timeline 契約（フィールド互換）が壊れていないこと

### P6 — レガシー整理

1. `crates/agrr-migrate/migrations/schema/V6__drop_task_schedule_item_actuals.sql`: `task_schedule_items` から `actual_date` / `actual_notes` / `completed_at` を削除（SQLite は `ALTER TABLE ... DROP COLUMN` 可。FK/インデックス依存に注意）。`status` の `'completed'` 行は `'planned'` へ正規化（実績は P1 で work_records に移済み）
2. **削除**: `task_schedule_item_complete_interactor.rs` + `TaskScheduleItemCompleteInput` + mutation gateway の `complete_item_for_plan` + 対応テスト。未配線コードの温存は `.cursor/rules/project-necessary-code-only.mdc` 違反
3. timeline JSON から `details.actual` / `details.history.completed_at` を**フロントの移行完了後に**削除（GUI 計画 F4 とセットで。先にバックエンドだけ消さない)
4. `CLAUDE.md` のドメイン文脈リストに `work_record` を追記

**受け入れ条件**: 全テスト GREEN / `grep -r "actual_notes" crates/` がマイグレーションファイル以外でゼロ

## 6. ARCHITECTURE.md ゲート（本計画で特に踏みやすい違反）

- gateway に「画面用 blob」を組ませない（プリフィルや completed 導出の**組み立ては interactor / JSON マッパー**で）
- interactor から `CompositionRoot` / アダプタ直 new をしない（配線は `crates/agrr-server` の route モジュール）
- `on_failure` 後の `raise` 二重経路を作らない（`call_rescuing` パターンに従う）
- domain で `time` の now 系直呼び禁止（ClockPort）
- 「とりあえず items.status に completed も書いておく」は二重真実であり**禁止**（§3.2）

## 7. 非スコープ（v1 でやらない。やりたくなったら実装を止めてユーザーに確認）

- 再生成後の work_record 自動再リンク（`agricultural_task_id` + `stage_order` でのマッチング）— ID 温存でリンク維持。予定外実績への降格は温存対象外 item 削除時のみ
- work_record の deletion_undo 統合
- `task_schedule_item_id` の付け替え（実績の予定への後付けリンク）
- 予定生成の保護付き部分置換（`TaskScheduleFieldMutation::MergeReplace`）— issue #206 で実装済み
- 写真添付・作業者複数名・天候スナップショット等のリッチ化
