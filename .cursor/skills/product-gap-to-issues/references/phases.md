# フェーズ手順

終了地点語彙・必須成果物・完了報告の正本は [`artifacts.md`](artifacts.md)。確定した終了フェーズまでだけ実行する。

各フェーズは **終了チェックを満たしてから** 次フェーズへ進む。

---

## フェーズ 1 — 現状把握

Task `explore`（`model: "composer-2.5"`, thoroughness: `very thorough`）。プロンプト: [`subagent-prompts.md`](subagent-prompts.md) §1。

サブエージェントは `tmp/product-gap/current-state.md` に直接書く。

**終了チェック:** ファイルが存在し、画面・API・再利用資産がパス付きで記載されている。

---

## フェーズ 2 — ギャップ列挙

Task `generalPurpose`（`model: "composer-2.5"`）。プロンプト: §2。

サブエージェントは `tmp/product-gap/gap-backlog.md` に直接書く。

**終了チェック:** `gap-backlog.md` が存在し、候補ごとに差別化接続・優先度仮説・出典区分がある。

**F2 で終了:** [`artifacts.md`](artifacts.md)「完了報告」に従い報告して終了。

---

## フェーズ 3 — テーマ選定

親エージェントが **1 テーマ** を `tmp/product-gap/theme-selection.md` に記録する。

### `theme-selection.md` 必須構造

| セクション | 内容 |
|------------|------|
| **テーマ** | 選定した 1 件の要約 |
| **根拠** | なぜこのテーマか（評価基準への当てはめ） |
| **対象セグメント** | 主に効くユーザー層 |
| **スコープ外** | 今回の深掘り・方針に含めないもの |
| **同点順位** | 同点時は `gap-backlog.md` の掲載順である旨 |

### ユーザー指定がある場合

ユーザー指定を優先する。上記必須構造を満たす。

### テーマ未指定の自動選定

`gap-backlog.md` から 1 件を選ぶ。評価基準（同点は `gap-backlog` の掲載順）:

1. **プロダクト芯適合** — 気象 × GDD × 最適化の計画支援と接続できるか
2. **ユーザー影響** — 計画→実行→学習ループのどこを閉じるか
3. **既存重複** — 既存画面・issue との被りが少ないか
4. **観測可能性** — 完了条件を観測可能に書けるか
5. **依存の少なさ** — 他テーマ・未完了 issue への依存が少ないか

**終了チェック:** `theme-selection.md` が必須構造を満たす。

---

## フェーズ 4 — テーマ深掘り

Task `explore`（`model: "composer-2.5"`）。プロンプト: §3。

サブエージェントは `tmp/product-gap/theme-deep-dive.md` に直接書く。

必須内容: 再利用資産、不足、UI 置き場案（画面パスレベル）、既存強化案と新規案の比較。新画面を含む案は **`new_surface_justification`** を必ず書く（**F4 で記載。G2 で検証**）。

**実装コード・コンポーネント設計は書かない**（観測可能な振る舞い・画面役割まで）。

**終了チェック:** `theme-deep-dive.md` が存在し、新画面案があれば `new_surface_justification` がある。

**F4 で終了:** [`artifacts.md`](artifacts.md)「完了報告」に従い報告して終了。

---

## フェーズ 5 — 重複・UXゲート（G2）

Task `generalPurpose`（`model: "composer-2.5"`）。プロンプト: §4。ルーブリック: [`gates.md`](gates.md) §G2。

サブエージェントは `tmp/product-gap/overlap-ux-gate.json` に直接書く。親は JSON 検証（[`gates.md`](gates.md)「ゲート JSON 検証」）後に verdict を処理する。

| verdict | 動作 |
|---------|------|
| `pass` | フェーズ 6 へ |
| `fail` | **`theme-deep-dive.md` を修正**し G2 を再実行（収束条件は [`gates.md`](gates.md)「fail ループ」） |
| `blocked` | [`user-request-project-alignment.mdc`](../../../rules/user-request-project-alignment.mdc) に従いユーザーへ問い合わせ |

**終了チェック:** `overlap-ux-gate.json` の `verdict` が `pass`。

---

## フェーズ 6 — 方針・画面役割

親エージェントが `tmp/product-gap/enhancement-plan.md` を書く。必須セクションは [`issue-pack-template.md`](issue-pack-template.md) §方針・[`gates.md`](gates.md) 末尾（集約 API・新ルートの観測）。

**実装コード・コンポーネント設計は書かない。**

**終了チェック:** 方針テンプレの必須セクションが埋まっている。

---

## フェーズ 7 — 計画レビュー（G3）

Task `generalPurpose`（`model: "composer-2.5"`）。プロンプト: §5。ルーブリック: [`gates.md`](gates.md) §G3。

サブエージェントは `tmp/product-gap/plan-review.json` に直接書く。親は JSON 検証後に verdict を処理する。

| verdict | 動作 |
|---------|------|
| `pass` | フェーズ 8 へ |
| `fail` | **`enhancement-plan.md` を修正**し G3 を再実行（収束条件は [`gates.md`](gates.md)「fail ループ」） |
| `blocked` | [`user-request-project-alignment.mdc`](../../../rules/user-request-project-alignment.mdc) に従いユーザーへ問い合わせ |

**終了チェック:** `plan-review.json` の `verdict` が `pass`。

**F7 で終了:** [`artifacts.md`](artifacts.md)「完了報告」に従い報告して終了。

---

## フェーズ 8 — 画面モック

親エージェントが `tmp/product-gap/screen-mocks.md` を書く: 変わる画面のみ、Before/After、v1/v2 の区別、遷移図。

- **実装コードは書かない**
- テーマが分析・気候中心ならチャートをモックに含めてよい（G2-3 で過剰でなければ `pass`）

### 自己チェック（新ゲートは設けない）

次を満たしてから次へ:

- G2-3 の過剰（根拠なしのチャート・カード積み上げ）を再発していない
- モックが `enhancement-plan.md` の **v1 方針**と一致している
- 各画面に **Before / After / 遷移**の必要要素がある

**終了チェック:** 上記自己チェックを満たし `screen-mocks.md` が存在する。

**F8 で終了:** [`artifacts.md`](artifacts.md)「完了報告」に従い報告して終了。

---

## フェーズ 9 — issue パック起票

[`github-issue-creator`](../../github-issue-creator/SKILL.md) に従う。重複判定の正本は同スキル **§3**（CLOSED `already_fixed` 含む。本フェーズで再定義しない）。

### 手順

1. **§1 事実確認** — 起票前に対象・期待振る舞い・根拠・スコープ境界を確認
2. **§2 議論ゲート** — 仕様未確定・部分重複あいまい等は起票前にユーザーと議論。**Automation で人間議論が必要な部分重複は `blocked` として停止**（§2 を省略せず問い合わせ待ち）
3. **§3 重複確認** — [`github-issue-creator`](../../github-issue-creator/SKILL.md) §3 に従い `gh issue list` で確認。同一 OPEN へのコメント追記等の外部書き込みは、ユーザーの起票依頼範囲内で本スキルに従う
4. 問題なければ **`issue-pack.md` を作成**（[`issue-pack-template.md`](issue-pack-template.md) に沿った草案）
5. **§4 草案** — 通常パス: チャットへ草案提示しユーザー明示承認を待つ。**F9 確定時**（[`artifacts.md`](artifacts.md)「終了地点語彙」）: `issue-pack.md` を一括ドライランとみなし、§2・§3 済みなら同一実行で §5 へ
6. **§5 起票** — Epic → 子 issue の順に `gh issue create`。Epic 本文に子 issue 番号を `gh issue edit` で追記
7. **§6 `agent-ready`** — 起票内容確定後にブロッカー評価して付与（正本: [`github-issue-creator`](../../github-issue-creator/SKILL.md) §6。product-gap 補足: [`issue-pack-template.md`](issue-pack-template.md) §agent-ready 補足）

Issue 本文にモック要約・観測事実を埋め込む。**Issue 本文に `tmp/` パスは書かない**（作業用 `--body-file` の tmp 使用は可）。

**終了チェック:** [`github-issue-creator`](../../github-issue-creator/SKILL.md) §7 を満たす。

**F9 で終了:** [`artifacts.md`](artifacts.md)「完了報告」に従い報告して終了。
