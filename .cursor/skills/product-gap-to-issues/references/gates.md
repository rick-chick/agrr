# ゲート判定（G2 / G3）

人間が行っていた **方針転換・レビュー** をサブエージェントが機械判定する。出力は JSON。

## 共通 JSON 形

```json
{
  "gate": "overlap-ux-guard | plan-review",
  "verdict": "pass | fail | blocked",
  "summary": "一行要約",
  "findings": ["観測ベースの指摘"],
  "mandatory_corrections": ["次の修正で必須"],
  "blocked_reason": "blocked のときのみ"
}
```

| verdict | 意味 |
|---------|------|
| `pass` | 次フェーズへ |
| `fail` | 親エージェントが `mandatory_corrections` を反映し、同ゲートを再実行 |
| `blocked` | ユーザー問い合わせ（依頼と事実の矛盾） |

---

## G2: 重複・UXガード（overlap-ux-guard）

**タイミング**: フェーズ 4 深掘りの直後。

### 入力

- `tmp/product-gap/current-state.md`（**既存 backlog** セクション必須）
- `tmp/product-gap/theme-deep-dive.md`

### 判定の順序

1. **既存強化で足りるか**を先に検討する（推奨順序。自動 fail にはしない）
2. 新画面・新ルートを含む場合は **`new_surface_justification`**（なぜ既存では不可か）が深掘りに書かれているか確認する
3. 下表の **fail 条件**に該当するか判定する

### fail 条件（1つでも該当 → `fail`）

| # | 質問 | fail 時の修正 |
|---|------|----------------|
| G2-1 | 既存画面と **同じタスク一覧・同じ操作** を二重に載せるか？ | 一覧・操作は1画面に限定し、他は導線のみ |
| G2-2 | 深掘り成果物に **実装コード・コンポーネント設計** が含まれるか？ | 削除し画面役割・振る舞いレベルに戻す |
| G2-3 | テーマに対し **情報量が過剰**か？（根拠なしのチャート・カード・横断一覧の積み上げ） | 削減案を書く。詳細は既存分析画面へ |
| G2-4 | **新画面・新ルート**があり、既存で代替不可の理由が **観測ベースで未記載**か？ | `new_surface_justification` を追記するか、既存強化に差し替え |
| G2-5 | **既存 backlog**（`current-state.md`）に、計画・深掘りと **同一要求**の **OPEN** issue があるか？ | 新規 Epic / 子 issue 起票不可。既存 #N へコメント追記方針を `mandatory_corrections` に書く |
| G2-6 | **既存 backlog** に **CLOSED** で `already_fixed` 相当（同等修正済み）の issue があるか？ | 起票不可。理由を `findings` に記録し、代替（既存機能の強化のみ等）を `mandatory_corrections` に書く |
| G2-7 | **既存 backlog** と **部分重複**（同一要求ではないが統合要）か？ | `blocked` または `fail`。統合方針（新規 / コメント追記 / Epic 統合）を `mandatory_corrections` に書く |

G2-5〜7 は [`github-issue-creator` §3](../../github-issue-creator/SKILL.md) の重複確認と **同等の観測・動作**。フェーズ 9 の §3 は起票直前の最終確認として **二重でも矛盾しない**（G2 で fail ならフェーズ 6 以降に進まない）。

### pass の条件

- 画面ごとの **役割分担**が言える
- 新画面を含む場合は **justification が深掘りにある**
- UX の追加がテーマとユーザーセグメントに **比例**している

### blocked の例

- 既存機能の有無が調査で確定できない
- 依頼とプロダクト芯（計画アプリ）が両立せず、ユーザー判断が必要

### 人間指摘との対応

| 指摘 | ゲートでの扱い |
|------|----------------|
| 既存と被る | G2-1 |
| コード書くな | G2-2 |
| 詳細に引きずられて UX 悪化 | G2-3（テーマに応じた過剰判定） |
| 新機能要る？ | 自動 fail しない。G2-4 で justification の有無を確認 |

---

## G3: 計画レビュー（plan-review）

**タイミング**: `enhancement-plan.md` 完成後、モック・起票の前。

### 入力

- `tmp/product-gap/enhancement-plan.md`
- `tmp/product-gap/overlap-ux-gate.json`（G2 pass 前提）
- `tmp/product-gap/current-state.md`（**既存 backlog** セクション必須）

### fail 条件

| # | 質問 | fail 時 |
|---|------|---------|
| G3-1 | **画面ごとの役割**が表または同等の構造で明示されているか？ | 役割表を追加 |
| G3-2 | **v1 と v2 の境界**が書かれているか？ | v2 へ送る項目を分離 |
| G3-3 | **完了条件**が観測可能か（issue 化できるか）？ | 曖昧語を具体化 |
| G3-4 | **スコープ外**が列挙されているか？ | 追記 |
| G3-5 | 入口画面と実行画面の **両方**がある場合、同じリストの **重複**が残っていないか？ | サマリ vs 実行に再分割 |
| G3-6 | `enhancement-plan.md` の v1 issue 案が **既存 backlog** と **同一要求**の **OPEN** issue と重複するか？ | 新規起票不可。既存 #N へコメント追記または Epic 統合を `mandatory_corrections` に書く |
| G3-7 | v1 issue 案が **CLOSED** で `already_fixed` 相当の backlog と重複するか？ | 起票不可。理由を `findings` に記録 |
| G3-8 | v1 issue 案が **既存 backlog** と **部分重複**するか？ | `blocked` または `fail`。統合方針を `mandatory_corrections` に書く |

G3-6〜8 は G2-5〜7 と同じ [`github-issue-creator` §3](../../github-issue-creator/SKILL.md) 判定を **計画レビュー時**に再確認する。G2 で pass でも計画段階で重複が顕在化したら fail。

### 推奨（fail にしない）

- 対象ユーザーセグメント（農場1件 / 複数）への影響の記載
- v1 issue 数の抑制（境界が明確なら issue 数自体は固定しない）
- 集約 API・新ルートの要否は **観測**（農場数・API 呼び出し・既存上限）を `enhancement-plan.md` に書くこと
- `theme-selection.md` の幅 vs 深さ判定と `enhancement-plan.md` の v1/v2 が矛盾していないこと

### pass の条件

- 計画が **起票可能な粒度**になっている
- G2 の `mandatory_corrections` が反映されている

---

## 集約 API・新ルートの判断（G2/G3 共通の観測項目）

fail 条件ではない。`enhancement-plan.md` に必ず書く:

| 観測 | 記載例 |
|------|--------|
| 対象リソース上限 | 農場数・計画数（`ARCHITECTURE.md` 等） |
| 想定 API 呼び出し回数 | 農場あたり・セッションあたり |
| 新ルートの要否 | 既存ルートで足りない理由 |
| 集約 API の要否 | フロント並列で足りるか / 後続 issue か |
