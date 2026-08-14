---
name: product-gap-to-issues
description: >-
  他アプリとの機能ギャップ洗い出しから、方針・レビュー・画面モック・GitHub Issue 起票までを
  end-to-end で実行する。競合比較、足りない機能、機能追加 issue、プロダクトギャップ、バックログ起票で適用。
  実装は github-issue-worker に委譲（本スキルは起票まで）。
---

# プロダクトギャップ → Issue 起票（AGRR）

市場・他アプリとのギャップを整理し、**既存画面の強化を先に検討**したうえで、Epic / 子 issue まで起票する。新画面が要る場合は G2 で **理由の観測**を必須とする。

```
依頼整合 → 現状把握 → ギャップ列挙 → テーマ選定 → 深掘り
  → 重複・UXゲート(G2) → 方針 → 計画レビュー(G3)
  → 画面モック → issue パック → gh issue create
```

正本: 成果物は [`references/artifacts.md`](references/artifacts.md)。ゲートは [`references/gates.md`](references/gates.md)。

## いつ使うか

- 「農業アプリにあって AGRR にない機能は？」から issue 起票まで一気通貫
- 競合機能の取り込み候補をバックログ化したい
- 深掘りが詳細過多・既存重複に寄ったとき、**G2/G3 で止めてから**起票したい

## 適用範囲

| 経路 | スキル |
|------|--------|
| 本パイプライン（調査〜起票） | **本スキル** |
| 起票のみ（調査済み） | **`github-issue-creator`** |
| UX 監査由来の UI issue | **`ux-issue-pipeline`** / **`ux-issue-creator`** |
| 起票後の実装 | **`github-issue-worker`** |

## 0) 着手前

1. [`user-request-project-alignment.mdc`](../../rules/user-request-project-alignment.mdc) — 依頼とプロジェクト事実の整合
2. `mkdir -p tmp/product-gap`
3. 依頼から **終了地点** を確定する:
   - `調査のみ` → フェーズ 4 まで
   - `方針まで` → フェーズ 7（G3 通過）まで
   - `モックまで` → フェーズ 8 まで
   - `issue 起票まで` → フェーズ 9 まで（ユーザーが「起票」と言っていれば §9 で `gh issue create` 可）

**AGRR のプロダクト芯（照合用）**: 農業**計画**支援（気象 × GDD × 最適化）。フル農場 ERP ではない。

---

## フェーズ一覧

| # | フェーズ | 委譲 | 成果物 |
|---|----------|------|--------|
| 1 | 現状把握 | Task `explore` | `current-state.md` |
| 2 | ギャップ列挙 | Task `generalPurpose` | `gap-backlog.md` |
| 3 | テーマ選定 | 親エージェント | `theme-selection.md` |
| 4 | テーマ深掘り | Task `explore` | `theme-deep-dive.md` |
| 5 | 重複・UXゲート **G2** | Task `generalPurpose` | `overlap-ux-gate.json` |
| 6 | 方針・画面役割 | 親エージェント | `enhancement-plan.md` |
| 7 | 計画レビュー **G3** | Task `generalPurpose` | `plan-review.json` |
| 8 | 画面モック | 親エージェント | `screen-mocks.md` |
| 9 | issue パック起票 | [`github-issue-creator`](../github-issue-creator/SKILL.md) + `gh` | `issue-pack.md`, GitHub #N |

**ゲート未通過なら次フェーズに進まない。**

---

## フェーズ 1 — 現状把握

Task `explore`（thoroughness: `very thorough`）。プロンプト: [`references/subagent-prompts.md`](references/subagent-prompts.md) §1。

`tmp/product-gap/current-state.md` に保存。画面・ルート、ドメイン境界、**計画 → 実行 → 学習** の薄い箇所（観測ベース）。

---

## フェーズ 2 — ギャップ列挙

Task `generalPurpose`。プロンプト: §2。

`tmp/product-gap/gap-backlog.md`: カテゴリ別、差別化との接続、優先度仮説、既存強化 vs 新規の初判、**各候補の幅/深さ**（[`references/breadth-depth-scale.md`](references/breadth-depth-scale.md)）。

---

## フェーズ 3 — テーマ選定

親エージェントが **1 テーマ** を `theme-selection.md` に記録。ユーザー指定を優先。対象セグメント・スコープ外候補を含める。

**幅 vs 深さ**を [`references/breadth-depth-scale.md`](references/breadth-depth-scale.md) のコア 5 で比較し、判定と見送り候補を必ず書く。

---

## フェーズ 4 — テーマ深掘り

Task `explore`。プロンプト: §3。

`theme-deep-dive.md`: 再利用資産、不足、UI 置き場案（画面パスレベル）、既存強化案と新規案の比較。

新画面を含む案は **`new_surface_justification`**（既存で代替できない理由）を必ず書く。

深掘りが過剰なら [`references/breadth-depth-scale.md`](references/breadth-depth-scale.md) の打ち止め条件で幅候補へ回す。

**実装コードは書かない。**

---

## フェーズ 5 — 重複・UXゲート（G2）

Task `generalPurpose`。プロンプト: §4。ルーブリック: [`references/gates.md`](references/gates.md) §G2。

| verdict | 動作 |
|---------|------|
| `pass` | フェーズ 6 へ |
| `fail` | `mandatory_corrections` を反映し G2 を再実行 |
| `blocked` | [`user-request-project-alignment.mdc`](../../rules/user-request-project-alignment.mdc) に従いユーザーへ問い合わせ |

---

## フェーズ 6 — 方針・画面役割

`enhancement-plan.md` の必須セクション:

1. 画面ごとの役割
2. v1 / v2 の境界
3. 対象ユーザーセグメント（テーマに関係する場合）
4. スコープ外
5. 当初案と採用案の対応
6. **集約 API・新ルートの観測**（[`references/gates.md`](references/gates.md) 末尾）
7. **幅 vs 深さと v1/v2 の対応** — `theme-selection.md` の判定と矛盾しないこと（[`references/breadth-depth-scale.md`](references/breadth-depth-scale.md)）

テンプレ: [`references/issue-pack-template.md`](references/issue-pack-template.md) §方針

---

## フェーズ 7 — 計画レビュー（G3）

Task `generalPurpose`。プロンプト: §5。ルーブリック: [`references/gates.md`](references/gates.md) §G3。

| verdict | 動作 |
|---------|------|
| `pass` | フェーズ 8 へ |
| `fail` | `enhancement-plan.md` を修正し G3 を再実行 |
| `blocked` | ユーザー問い合わせ |

---

## フェーズ 8 — 画面モック

`screen-mocks.md`: 変わる画面のみ、Before/After、v1/v2 の区別、遷移図。

- **実装コードは書かない**
- テーマが分析・気候中心ならチャートをモックに含めてよい（G2-3 で過剰でなければ pass）

---

## フェーズ 9 — issue パック起票

1. `issue-pack.md` をテンプレに沿って作成
2. **起票本文の「参照」節から `tmp/product-gap/` path を除去** — リポジトリ内コード path と `#N` のみ残す（[`references/artifacts.md`](references/artifacts.md) §起票時の参照変換）
3. [`github-issue-creator`](../github-issue-creator/SKILL.md) §1–§7 に従う（重複確認・草案・起票・**`agent-ready` は §6 準拠**）
4. 依頼が `issue 起票まで` なら Epic → 子 issue の順に `gh issue create`
5. Epic 本文に子 issue 番号を `gh issue edit` で追記

---

## 部分実行の早見

| 依頼 | フェーズ |
|------|----------|
| ギャップ洗い出しだけ | 1 → 2 |
| 1 テーマ深掘りまで | 1 → 2 → 3 → 4 |
| 方針レビューまで | 1 → … → 7 |
| モックまで | 1 → … → 8 |
| issue 起票まで | 1 → … → 9 |

---

## 禁止

- G2 / G3 未通過で issue 起票
- 本パイプライン内で **実装コード** を書く（起票までがスコープ）
- 本スキル内で PR 作成・`github-issue-worker` による実装
- `ux-issue-pipeline` の代替として UX 監査起票を行う

---

## Automation（Cloud Agent）

[`references/automation-prompt.md`](references/automation-prompt.md)

- 成果物は `tmp/product-gap/`（commit しない）
- G2/G3 が `blocked` のときだけ停止。`fail` は修正して再実行
- **PR を開かない**

---

## 関連

- 起票: [`github-issue-creator`](../github-issue-creator/SKILL.md)
- 依頼整合: [`user-request-project-alignment.mdc`](../../rules/user-request-project-alignment.mdc)
- 実装: **`github-issue-worker`**
