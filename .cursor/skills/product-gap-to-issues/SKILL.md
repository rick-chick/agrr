---
name: product-gap-to-issues
description: >-
  他アプリとの機能ギャップ洗い出しから、既存画面強化方針・レビュー・画面モック・GitHub Issue 起票までを
  end-to-end で実行する。競合比較、足りない機能、機能追加 issue、プロダクトギャップ、バックログ起票で適用。
  実装は github-issue-worker に委譲（本スキルは起票まで）。
---

# プロダクトギャップ → Issue 起票（AGRR）

市場・他アプリとのギャップを整理し、**新画面を増やさないことをデフォルト**に、既存画面強化の Epic / 子 issue まで起票する。

```
依頼整合 → 現状把握 → ギャップ列挙 → テーマ選定 → 深掘り
  → 重複・UXゲート(G2) → 強化方針 → 計画レビュー(G3)
  → 画面モック → issue パック → gh issue create
```

正本: 成果物パスは [`references/artifacts.md`](references/artifacts.md)。ゲート判定は [`references/gates.md`](references/gates.md)。

## いつ使うか

- 「農業アプリにあって AGRR にない機能は？」から issue 起票まで一気通貫
- 競合機能の取り込み候補をバックログ化したい
- 深掘りで新ダッシュボード等に寄りかかったとき、**既存画面との重複を機械的に潰してから**起票したい

## 適用範囲

| 経路 | スキル |
|------|--------|
| 本パイプライン（調査〜起票） | **本スキル** |
| 起票のみ（調査済み） | **`github-issue-creator`** |
| UX 監査由来の UI issue | **`ux-issue-pipeline`** / **`ux-issue-creator`** |
| 起票後の実装 | **`github-issue-worker`** |

## 0) 着手前

1. [`user-request-project-alignment.mdc`](../../rules/user-request-project-alignment.mdc) — 依頼とプロジェクト事実の整合
2. 作業ディレクトリを作成: `mkdir -p tmp/product-gap`
3. 依頼から **終了地点** を確定する:
   - `調査のみ` → フェーズ 4 まで
   - `方針まで` → フェーズ 6（G3 通過）まで
   - `モックまで` → フェーズ 7 まで
   - `issue 起票まで` → フェーズ 9 まで（ユーザーが「起票」と言っていれば §9 で `gh issue create` 可）

**AGRR のプロダクト芯（照合用・固定）**: 農業**計画**支援（気象 × GDD × 最適化）。フル農場 ERP ではない。

---

## フェーズ一覧

| # | フェーズ | 委譲 | 成果物 |
|---|----------|------|--------|
| 1 | 現状把握 | Task `explore` | `current-state.md` |
| 2 | ギャップ列挙 | Task `generalPurpose` | `gap-backlog.md` |
| 3 | テーマ選定 | 親エージェント | `theme-selection.md` |
| 4 | テーマ深掘り | Task `explore` | `theme-deep-dive.md` |
| 5 | 重複・UXゲート **G2** | Task `generalPurpose` | `overlap-ux-gate.json` |
| 6 | 強化方針・画面役割 | 親エージェント | `enhancement-plan.md` |
| 7 | 計画レビュー **G3** | Task `generalPurpose` | `plan-review.json` |
| 8 | 画面モック | 親エージェント | `screen-mocks.md` |
| 9 | issue パック起票 | `github-issue-creator` 手順 + `gh` | `issue-pack.md`, GitHub #N |

**ゲート未通過なら次フェーズに進まない。** 詳細: [`references/gates.md`](references/gates.md)

---

## フェーズ 1 — 現状把握

Task `explore`（thoroughness: `very thorough`）。プロンプト: [`references/subagent-prompts.md`](references/subagent-prompts.md) §1。

出力を `tmp/product-gap/current-state.md` に保存する。含めること:

- 画面・ルート一覧、主要ユースケース
- ドメイン境界（`crates/agrr-domain`）
- **計画 → 実行 → 学習** のループのどこが薄いか（観測ベース）

---

## フェーズ 2 — ギャップ列挙

Task `generalPurpose`。プロンプト: §2。

出力 `tmp/product-gap/gap-backlog.md`:

- カテゴリ別（実行・コンプライアンス・販売・IoT 等）
- 各候補に **自社差別化との接続**（GDD/気象/最適化と連動するか）
- 優先度の仮説（P1/P2）
- **新画面が要るか / 既存強化で足りるか** の初判

---

## フェーズ 3 — テーマ選定

親エージェントが **1 テーマだけ** 選ぶ。`tmp/product-gap/theme-selection.md` に記録:

- 選んだテーマと理由（ユーザー指定があればそれを優先）
- 対象ユーザーセグメント（農場1件 / 複数）
- スコープ外にする関連候補

---

## フェーズ 4 — テーマ深掘り

Task `explore`。プロンプト: §3。

出力 `tmp/product-gap/theme-deep-dive.md`:

- 再利用できる既存画面・API・use case
- 新規に要るもの
- 初回の UI 置き場案（画面名レベル。コード・コンポーネント名は書かない）

**このフェーズではコードを書かない。**

---

## フェーズ 5 — 重複・UXゲート（G2）【人間介入の代替】

Task `generalPurpose`。プロンプト: §4。ルーブリック: [`references/gates.md`](references/gates.md) §G2。

`tmp/product-gap/overlap-ux-gate.json` を出力する。

| verdict | 動作 |
|---------|------|
| `pass` | フェーズ 6 へ |
| `fail` | **新画面案を破棄**し、既存画面強化案に差し替えてからフェーズ 6 へ（深掘りをやり直さない。差分だけ `enhancement-plan` に反映） |
| `blocked` | 依頼と事実が矛盾。[`user-request-project-alignment.mdc`](../../rules/user-request-project-alignment.mdc) に従いユーザーへ問い合わせ |

**G2 で潰す論点（今回の人間指摘の自動化）:**

- 既存画面と役割が被る → 新画面禁止
- 詳細設計が UX を肥やす → 情報を削る（天候/GDD は短い注意のみ、チャートは既存気候画面）
- 実装コードの先行禁止

---

## フェーズ 6 — 強化方針・画面役割

親エージェントが `tmp/product-gap/enhancement-plan.md` を書く。必須セクション:

1. **画面ごとの役割**（1 画面 1 役割。重複禁止）
2. **v1 / v2 の境界**（v1 は 3 点以内を推奨）
3. **誰に効くか**（農場1件 vs 複数）
4. **やらないこと**（新ルート、集約 API、横断1リスト等）
5. 前回深掘り（新機能案）との対応表

テンプレ: [`references/issue-pack-template.md`](references/issue-pack-template.md) §強化方針

---

## フェーズ 7 — 計画レビュー（G3）

Task `generalPurpose`。プロンプト: §5。ルーブリック: [`references/gates.md`](references/gates.md) §G3。

`tmp/product-gap/plan-review.json` を出力する。

| verdict | 動作 |
|---------|------|
| `pass` | フェーズ 8 へ |
| `fail` | `enhancement-plan.md` を修正し G3 を再実行（最大 2 回） |
| `blocked` | ユーザー問い合わせ |

---

## フェーズ 8 — 画面モック

親エージェントが `tmp/product-gap/screen-mocks.md` を書く。

- **変わる画面だけ**（ナビ、既存ルート）
- Before / After、v1 と v2（v2 は点線・注記のみ）
- 画面遷移（mermaid 可）
- **コード・コンポーネント名・API 設計は書かない**
- 画像が必要なら `GenerateImage` は任意（テキストモックを正とする）

---

## フェーズ 9 — issue パック起票

1. `tmp/product-gap/issue-pack.md` を [`references/issue-pack-template.md`](references/issue-pack-template.md) に沿って作成
2. [`github-issue-creator`](../github-issue-creator/SKILL.md) §3 重複確認
3. §4 草案を `issue-pack.md` に含める
4. 依頼が `issue 起票まで` なら `gh issue create` で Epic → v1 子 issue の順に起票
5. Epic 本文に子 issue 番号を `gh issue edit` で追記
6. **`agent-ready` は付けない**（プロダクト issue は人間確認後に付与が既定。ユーザーが「agent-ready まで」と明示した場合のみ付与）

起票後: issue 番号・URL を報告する。

---

## 部分実行の早見

| 依頼 | 実行するフェーズ |
|------|------------------|
| ギャップ洗い出しだけ | 1 → 2 |
| 1 テーマ深掘りまで | 1 → 2 → 3 → 4 |
| 方針レビューまで | 1 → … → 7 |
| モックまで | 1 → … → 8 |
| issue 起票まで | 1 → … → 9 |

---

## 禁止

- G2 / G3 未通過で issue 起票
- 新ダッシュボード・新ルートをデフォルト案にする（G2 で却下されるべき）
- フェーズ 4 以降で **実装コード** を書く（本スキルは起票まで）
- 天候・GDD チャートを v1 モックに載せる
- 全農場タスク横断1リストを v1 に含める
- 本スキル内で PR 作成・`github-issue-worker` 実装
- UX 監査パイプライン（`ux-issue-pipeline`）の代替

---

## Automation（Cloud Agent）

ユーザーが end-to-end 起票を依頼した場合のプロンプト: [`references/automation-prompt.md`](references/automation-prompt.md)

- フェーズ 1–8 の成果物を `tmp/product-gap/` に残す
- G2/G3 が `blocked` のときだけ停止（それ以外は `fail` 時リトライで完走）
- **PR を開かない**

---

## 関連

- 起票テンプレ: [`github-issue-creator/references/issue-body-template.md`](../github-issue-creator/references/issue-body-template.md)
- 依頼整合: [`user-request-project-alignment.mdc`](../../rules/user-request-project-alignment.mdc)
- 実装: **`github-issue-worker`**
