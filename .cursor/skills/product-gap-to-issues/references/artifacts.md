# 成果物チェーン

すべて `tmp/product-gap/` 配下。リポジトリに commit しない。

| ファイル | フェーズ | 必須 |
|----------|----------|------|
| `current-state.md` | 1 | ✓（必須セクション下記） |
| `gap-backlog.md` | 2 | ✓ |
| `theme-selection.md` | 3 | ✓（`breadth-depth-scale.md` §theme-selection 形式） |
| `theme-deep-dive.md` | 4 | ✓ |
| `overlap-ux-gate.json` | 5 G2 | ✓ |
| `enhancement-plan.md` | 6 | ✓ |
| `plan-review.json` | 7 G3 | ✓（起票まで行う場合） |
| `screen-mocks.md` | 8 | 起票まで行う場合 ✓ |
| `issue-pack.md` | 9 | 起票まで行う場合 ✓ |

## `current-state.md` 必須セクション（フェーズ 1）

[`subagent-prompts.md`](subagent-prompts.md) §1 の調査・出力と対応する。いずれかが空なら親エージェントは **フェーズ 2 に進まず** 調査を継続する。

| セクション | 内容 |
|------------|------|
| **既存 backlog** | 選定テーマ（またはギャップ候補）に関連する issue の番号・state（OPEN / CLOSED）・タイトル要約。`gh issue list` / `gh issue view` による観測 |
| **実装済み** | 同一テーマのマージ済み PR 番号と触れたコード path。`gh pr list --state merged` による観測 |
| **できること一覧** | 画面・API レベルの機能とコード path |
| **計画→実行→学習** | ループの薄い箇所。上記 backlog・PR 観測と矛盾しない記述 |

## ゲート JSON の例

**G2 pass（既存強化）:**

```json
{
  "gate": "overlap-ux-guard",
  "verdict": "pass",
  "summary": "既存 /work と /plans/:id/work で役割分担。新画面なし",
  "findings": [],
  "mandatory_corrections": []
}
```

**G2 pass（新ルートあり・justification 済み）:**

```json
{
  "gate": "overlap-ux-guard",
  "verdict": "pass",
  "summary": "新ルート /reports/compliance は既存画面では帳票導線を賄えないため採用",
  "findings": [],
  "mandatory_corrections": []
}
```

**G3 fail:**

```json
{
  "gate": "plan-review",
  "verdict": "fail",
  "summary": "v1 と v2 の境界が未記載",
  "findings": ["天候注意と GDD 補足が v1 issue に混在"],
  "mandatory_corrections": ["enhancement-plan に v1/v2 を分離", "v2 を Epic の後続に移動"]
}
```

**G2 fail（backlog 重複 — OPEN 同一要求）:**

```json
{
  "gate": "overlap-ux-guard",
  "verdict": "fail",
  "summary": "既存 backlog #412 OPEN が同一要求",
  "findings": ["current-state.md 既存 backlog: #412 OPEN — 作業一覧 UX 改善"],
  "mandatory_corrections": ["新規 Epic / 子 issue 起票不可", "既存 #412 へ調査結果をコメント追記する方針に差し替え"]
}
```

**G3 blocked（backlog 部分重複）:**

```json
{
  "gate": "plan-review",
  "verdict": "blocked",
  "summary": "v1 issue 案が #388 と部分重複",
  "findings": ["#388 CLOSED already_fixed 相当の範囲と v1-2 が重なる"],
  "mandatory_corrections": ["統合方針: v1-2 を #388 追記に統合するか Epic に統合するかを確定"],
  "blocked_reason": "部分重複の統合方針が enhancement-plan に未記載"
}
```

## 完了報告に含めるもの

| 終了地点 | 報告 |
|----------|------|
| 調査のみ | `gap-backlog.md` 要約 |
| 方針まで | `enhancement-plan.md` + G2/G3 verdict |
| モックまで | `screen-mocks.md` リンク |
| 起票まで | Epic / 子 issue の URL 一覧 |
