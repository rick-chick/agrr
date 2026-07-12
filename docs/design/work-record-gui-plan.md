# work_record GUI 対応計画（作業予定・実績のフロントエンド）

最終更新: 2026-06-12 / ステータス: 計画（未着手）

バックエンド側の計画は [`work-record-separation-plan.md`](work-record-separation-plan.md)（以下「BE 計画」）。**本書の各フェーズは BE 計画の対応フェーズが完了してから着手する**（依存表は §5 冒頭）。

---

## 0. この文書の読み方（実装者向け）

- 全体像を知らない実装者がフェーズ（F1〜F4）単位で着手できるよう、「スコープ / 作成・変更ファイル / 受け入れ条件」を自己完結で記す。
- 対象は `frontend/`（Angular 21 SPA、standalone components）。レイヤ規約:
  - 依存方向 **`components → usecase → domain`**。HTTP は `adapters/` が gateway token を実装。`models/` に型。
  - 新しいユースケースは **input-port / output-port / usecase / providers** の 4 点セット（参照実装: `frontend/src/app/usecase/plans/load-plan-task-schedule.*` と `delete-plan.*`）
  - i18n は `@ngx-translate`。**`frontend/src/assets/i18n/ja.json` と `en.json` の両方**に必ずキーを足す
- テスト: `.cursor/skills/test-common/scripts/run-test-frontend.sh [ARGS]`。**直接 `npm test` を実行しない**。個別ファイル指定で GREEN → 全体実行の順。
- 着手前に [`ARCHITECTURE.md`](../../ARCHITECTURE.md) のフロントエンド該当節と `docs/design/frontend-design-review.md` / `private-plan-create-entry-ux.md`（既存の UX 設計判断）に目を通す。

## 1. 背景・ゴール

BE 計画により、予定（task_schedule_items）と実績（work_records）が分離される。GUI のゴール:

1. **「今日やること」が見え、1〜2 タップで実績登録できる**（主動線。畑でスマホ操作を想定）
2. 予定外の作業もその場で記録できる
3. 予定の操作（日付変更・skip・手動追加）と実績の操作（記録・修正）が**画面上で混ざらない**
4. 実績の履歴を見返し、修正・削除できる

### 1.1 操作モデル（迷ったらここに戻る）

| ユーザーの意図 | 操作対象 | UI |
|---|---|---|
| 「やった」 | work_record 作成（予定からプリフィル） | 予定行の完了ボタン → 登録シート |
| 「予定にない作業をやった」 | work_record 作成（予定外） | 「+ 作業を記録」 |
| 「やらないことにした」 | 予定の skip | 予定行のメニュー → スキップ |
| 「日程をずらす」 | 予定の編集 | 予定表ページ（月別リスト）の日付編集 |
| 「記録を間違えた」 | work_record の修正・削除 | 実績履歴から |

「完了」は実績の存在から導出される（BE 計画 §3.2）。**フロントで status を直接 completed にする操作は存在しない**。

## 2. 現状インベントリ（2026-06-12 調査）

| パス | 状態 |
|---|---|
| `frontend/src/app/components/plans/plan-task-schedule.component.ts` | 予定表示ページ（`/plans/:id/task_schedule` 相当のルートは `routes/plans.routes.ts`）。`task-schedule-month-list` で月別表示 |
| `frontend/src/app/components/plans/task-schedule-month-list.component.ts` | general/fertilizer 切替付きの月別リスト。**旧 `task-schedule-timeline`（cdkDragDrop）は削除済み** |
| `frontend/src/app/models/plans/task-schedule.ts` | `TaskScheduleItem` 等の型。`details.actual` / `details.history` に旧実績フィールドあり |
| `frontend/src/app/adapters/plans/plan-api.gateway.ts:33` | `GET /api/v1/plans/${planId}/task_schedule` のみ |
| `frontend/src/app/usecase/plans/load-plan-task-schedule.*` | 読み込みユースケース（参照実装として使う） |

実績の登録・閲覧 UI は**一切存在しない**。

## 3. 画面設計

### 3.1 新ページ「作業」`/plans/:id/work`（F1）

日付中心のタスクリスト。plan 中心の月別予定表（`/plans/:id/task_schedule`）とは役割を分ける。

```
┌──────────────────────────────────┐
│ ◀ 計画に戻る   [作業] [予定表] [実績履歴] │  ← タブ or リンク
├──────────────────────────────────┤
│ ⚠ 期限超過 (2)                      │
│  ├ 6/8 追肥 第1圃場 トマト  [完了] [⋮] │
│  └ 6/10 芽かき 第1圃場     [完了] [⋮] │
│ ── 今日 6/12 ──                    │
│  ├ 防除 第2圃場 ナス       [完了] [⋮] │
│  └ ✓ 潅水 第1圃場（実績 6/12 登録済）   │
│ ── 今後7日 ──                      │
│  └ 6/14 収穫 第1圃場       [完了] [⋮] │
├──────────────────────────────────┤
│            [+ 作業を記録]            │
└──────────────────────────────────┘
```

- データ源は既存 `GET /api/v1/plans/{id}/task_schedule`（BE P5 拡張後は item に `completed` / `work_records` が付く）。フロント側で `scheduled_date` を「期限超過 / 今日 / 今後 7 日」にグルーピング
- 表示対象: `completed: false` かつ `status !== 'skipped'` の item ＋ 完了済みは当日分のみ ✓ 付きで表示（達成感のため）。skip 済みはデフォルト非表示（「skip を表示」トグル）
- `[完了]` → 実績登録シート（§3.2）をプリフィルで開く
- `[⋮]` メニュー: スキップ / 日付を変更（F3）
- `[+ 作業を記録]` → 実績登録シートを空で開く（予定外実績）

### 3.2 実績登録シート（F1。予定由来・予定外の共用コンポーネント）

```
┌─ 作業を記録 ─────────────────┐
│ 作業名   [追肥          ]      │ ← 予定由来: プリフィル(編集可) / 予定外: 必須入力
│ 実施日   [2026-06-12 ▼]      │ ← デフォルト今日
│ 量      [1.5] [kg ▼]         │ ← 予定由来: 予定量プリフィル
│ 所要時間 [   ] 分(任意)        │
│ メモ    [              ](任意) │
│ 圃場    [第1圃場 トマト ▼]      │ ← 予定由来: 固定表示 / 予定外: 選択(任意)
│        [キャンセル] [記録する]   │
└─────────────────────────────┘
```

- 予定由来の最短動線: シートを開いて**そのまま「記録する」を押すだけで完了**（全項目プリフィル済み）。1 予定への 2 回目以降の記録も同じ動線（部分実施の追記）
- 送信は `POST /api/v1/plans/{plan_id}/work_records`（BE 計画 §4.1）。予定由来は `task_schedule_item_id` だけ送り、ユーザーが編集した項目のみ上書き送信
- 422 はフィールド単位でエラー表示（既存フォームのエラー表示パターンに合わせる）
- 成功後: シートを閉じ、リストの該当行を ✓ 化（リスト再フェッチでよい。楽観更新は不要）

### 3.3 実績履歴ページ `/plans/:id/work_records`（F2）

- `GET /api/v1/plans/{plan_id}/work_records` を日付降順リスト表示。月単位の区切り見出し
- 各行: 実施日 / 作業名 / 圃場 / 量 / メモ抜粋 / 予定由来バッジ（予定外実績は「予定外」バッジ）
- 行タップ → §3.2 と同じシートを編集モードで開く（`PATCH`）。削除ボタンは確認ダイアログ付き（`DELETE`、undo なし — BE 計画 §7）

### 3.4 予定編集（F3）

- skip / unskip: 作業ページの `[⋮]` から。`PATCH .../task_schedule/items/{id}/skip|unskip`（BE P5）
- 日付変更: v1 は `[⋮]` → 日付ピッカーのみ。予定表は月別リスト表示のみ（DnD timeline は削除済み）。予定 update API の配線は BE 側で別途必要
- 手動予定追加はスコープ外（§6）

## 4. レイヤ別の実装マップ（共通規約）

新規ファイルは既存 plans 系の命名に揃える。**1 ユースケース = input-port + output-port + usecase + providers + spec** のセット。

```
models/plans/work-record.ts                  // WorkRecord, WorkRecordCreateRequest 等の型
adapters/plans/work-record-api.gateway.ts    // HTTP 実装（gateway token を実装）
adapters/plans/work-record-api.gateway.spec.ts
domain/plans/work-record.gateway.ts          // token + インターフェース（既存 plans の token 配置に合わせる）
usecase/plans/create-work-record.*           // F1
usecase/plans/load-work-day-list.*           // F1（task_schedule 読込 + 日付グルーピングはここ。component に置かない）
usecase/plans/load-work-records.*            // F2
usecase/plans/update-work-record.* / delete-work-record.*   // F2
usecase/plans/skip-task-schedule-item.*      // F3
components/plans/plan-work.component.ts      // 作業ページ（F1）
components/plans/work-record-sheet.component.ts   // 登録/編集シート（F1, F2 共用）
components/plans/plan-work-records.component.ts   // 実績履歴（F2）
routes/plans.routes.ts                       // ルート追加（既存の plans children に追記）
assets/i18n/ja.json, en.json                 // plans.work.* / plans.work_records.* キー
```

規約上の注意（違反しやすい点）:

- **日付グルーピング・「完了済みは当日のみ表示」等の表示ルールは usecase/presenter 層**に置く。component はビュー状態の保持と描画のみ（参照: `plan-task-schedule.component.ts` の View/Presenter 分離）
- adapters 以外から `HttpClient` を触らない。API パスは adapter 内のみ
- 既存 `models/plans/task-schedule.ts` の `TaskScheduleItem` に `completed: boolean` / `work_records` を**追加**する（BE P5 拡張）。`details.actual` / `details.history` は F4 まで削除しない
- i18n キーは ja/en 同時追加。ハードコード文字列禁止

## 5. 実装フェーズ

| GUI フェーズ | 依存する BE フェーズ | 出るもの |
|---|---|---|
| F1 作業ページ + 登録シート | BE P4（work_records API）+ P5（timeline の `completed`） | 主動線一式 |
| F2 実績履歴・修正・削除 | BE P4 | 履歴ページ |
| F3 skip・日付変更 | BE P5 | 予定操作 |
| F4 レガシー整理 | F1〜F3 完了後、BE P6 と同時 | 旧フィールド除去 |

F1 と F2 は並行可（シートコンポーネントだけ共有なので、先行する側が作る）。

### F1 — 作業ページ + 実績登録シート

**作成**: §4 の models / domain token / adapter / `create-work-record.*` / `load-work-day-list.*` / `plan-work.component` / `work-record-sheet.component`、ルート `plans/:id/work`、i18n キー。
**変更**: `models/plans/task-schedule.ts`（`completed` / `work_records` 追加）、`plan-task-schedule.component.ts` に作業ページへのリンク。

受け入れ条件:

- 予定行 [完了] → プリフィル済みシート → 記録する → 行が ✓ になる（手動確認: `.cursor/skills/dev-docker/SKILL.md` のローカル環境 + `ng serve`）
- [+ 作業を記録] から name 入力で予定外実績が作れる。name 空で送るとフィールドエラー表示
- グルーピング（期限超過/今日/今後 7 日）のロジックに spec がある（usecase 層のテスト。日付は注入可能にし `new Date()` を usecase 内で直呼びしない）
- `run-test-frontend.sh` 全体 GREEN

### F2 — 実績履歴・修正・削除

**作成**: `load-work-records.*` / `update-work-record.*` / `delete-work-record.*` / `plan-work-records.component`、ルート、i18n。シートコンポーネントに編集モード追加。

受け入れ条件: 一覧表示 / 編集保存 / 確認付き削除が動く。`task_schedule_item_id` は編集 UI に出さない（BE 計画 §4.3 で付け替え不可）。テスト全体 GREEN。

### F3 — 予定操作（skip / 日付変更）

**作成**: `skip-task-schedule-item.*`、`[⋮]` メニュー、日付ピッカー（既存 update API の配線状況を BE 側と確認すること。skip のみ先行リリース可）。
**変更**: skip 済み行の非表示 + トグル。

受け入れ条件: skip → リストから消える → トグルで表示 → unskip で復帰。テスト全体 GREEN。

### F4 — レガシー整理（BE P6 と同時にやる）

- `models/plans/task-schedule.ts` から `details.actual` / `details.history.completed_at` を削除し、参照箇所を一掃
- `status === 'completed'` 依存の表示ロジックが残っていないこと（`completed` 導出値のみ参照）を grep で確認

受け入れ条件: `grep -rn "details.actual\|'completed'" frontend/src/app` で意図的な残置以外ゼロ。テスト全体 GREEN。

## 6. 非スコープ（やりたくなったら実装を止めてユーザーに確認）

- 手動の予定追加 UI（BE の item create 配線が先）
- 予定表 UI での DnD による日程変更（現行は月別リスト表示のみ。予定 update API の配線が先）
- オフライン対応・PWA 化（畑での電波問題は将来課題）
- 写真添付、複数作業者、作業時間の自動計測
- 実績からのレポート/集計画面

## 7. UX 上の決定事項（実装時に変えない）

- 実績登録は**常にシート経由**（ワンタップ即時完了にしない）。誤タップで事実が記録されるのを防ぐ。ただしシートはプリフィル済みなので実質 2 タップ
- 「完了の取り消し」は実績の削除（履歴 or 行の ✓ から）であり、予定側の操作ではない
- 予定外実績の登録時、近傍の未完了予定への自動マッチング・サジェストは**やらない**（v1 はシンプルに。BE 計画 §7 の再リンクと同様の将来課題）
