---
name: product-gap-to-issues
description: >-
  他アプリとの機能ギャップ洗い出しから、方針・レビュー・画面モック・GitHub Issue 起票までを
  end-to-end で実行する。競合比較、足りない機能、機能追加 issue、プロダクトギャップ、バックログ起票で適用。
  実装は github-issue-worker に委譲（本スキルは起票まで）。
---

# プロダクトギャップ → Issue 起票（AGRR）

市場・他アプリとのギャップを整理し、**既存画面の強化を先に検討**したうえで Epic / 子 issue まで起票する。

正本: [`references/artifacts.md`](references/artifacts.md)（終了地点語彙・成果物・完了報告）・[`references/gates.md`](references/gates.md)（G2/G3）・[`references/phases.md`](references/phases.md)（フェーズ手順）。

新規画面の理由（`new_surface_justification`）は **フェーズ 4 で記載**し、**フェーズ 5（G2）で検証**する。

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
3. 依頼から **終了地点**（最終フェーズ）を確定する — 語彙・F9 明示依頼の扱いは [`references/artifacts.md`](references/artifacts.md)「終了地点語彙（正本）」

**AGRR のプロダクト芯（照合用）**: 農業**計画**支援（気象 × GDD × 最適化）。フル農場 ERP ではない。

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
| 9 | issue パック起票 | 親 + [`github-issue-creator`](../github-issue-creator/SKILL.md) | `issue-pack.md`, GitHub #N |

**ゲート未通過は次フェーズに進まない。** 手順・終了チェック・収束条件: [`references/phases.md`](references/phases.md)・[`references/gates.md`](references/gates.md)。

**委譲**: Task は毎回 `model: "composer-2.5"`。サブエージェントは成果物パスへ**直接書く**。親はファイル存在・内容を確認してから次へ。

## 部分実行の早見

終了地点コード（F2〜F9）の詳細は [`references/artifacts.md`](references/artifacts.md)「終了地点語彙（正本）」。

| 依頼の例 | フェーズ |
|----------|----------|
| ギャップ洗い出しだけ（F2） | 1 → 2 |
| 1 テーマ深掘りまで（F4） | 1 → 2 → 3 → 4 |
| 方針レビューまで（F7） | 1 → … → 7 |
| モックまで（F8） | 1 → … → 8 |
| issue 起票まで（F9） | 1 → … → 9 |

## 禁止

- G2 / G3 未通過で issue 起票
- 重複確認失敗・部分重複の自動判定不能時の起票（`blocked` で停止）
- 本パイプライン内で **実装コード** を書く（起票までがスコープ）
- 本スキル内で PR 作成・`github-issue-worker` による実装
- `ux-issue-pipeline` の代替として UX 監査起票を行う
- Issue 本文への `tmp/` 参照（モック要約・観測は本文に埋め込む）

## Automation（Cloud Agent）

[`references/automation-prompt.md`](references/automation-prompt.md) — 確定した終了フェーズまでのみ実行。`blocked` は依頼と事実の矛盾・確定不能時に正しく停止する。

## 関連

- 起票: [`github-issue-creator`](../github-issue-creator/SKILL.md)
- 依頼整合: [`user-request-project-alignment.mdc`](../../rules/user-request-project-alignment.mdc)
- 実装: **`github-issue-worker`**
