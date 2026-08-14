# 成果物チェーン

すべて `tmp/product-gap/` 配下。リポジトリに commit しない。

| ファイル | フェーズ | 必須 |
|----------|----------|------|
| `current-state.md` | 1 | ✓ |

### `current-state.md` 必須セクション（空欄禁止）

フェーズ 1 成果物。いずれかが空・未記載なら **フェーズ 2 に進まない**（親エージェントは調査を継続）。

| セクション | 内容 |
|------------|------|
| **既存 backlog** | 選定テーマ（またはギャップ候補）に関連する issue 番号・state（OPEN / CLOSED）・タイトル要約（`gh issue list` / `gh issue view`） |
| **実装済み** | 同一テーマのマージ済み PR 番号と触れたコード path（`gh pr list --state merged`） |
| **できること一覧** | 画面・API レベル（コード path 付き） |
| **計画→実行→学習** | ループの薄い箇所（backlog・PR 観測と矛盾しない記述） |

調査手順の正本: [`subagent-prompts.md`](subagent-prompts.md) §1。

| ファイル | フェーズ | 必須 |
|----------|----------|------|
| `gap-backlog.md` | 2 | ✓ |
| `gap-backlog.md` | 2 | ✓ |
| `theme-selection.md` | 3 | ✓（`breadth-depth-scale.md` §theme-selection 形式） |
| `theme-deep-dive.md` | 4 | ✓ |
| `overlap-ux-gate.json` | 5 G2 | ✓ |
| `enhancement-plan.md` | 6 | ✓ |
| `plan-review.json` | 7 G3 | ✓（起票まで行う場合） |
| `screen-mocks.md` | 8 | 起票まで行う場合 ✓ |
| `issue-pack.md` | 9 | 起票まで行う場合 ✓ |

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

## 完了報告に含めるもの

| 終了地点 | 報告 |
|----------|------|
| 調査のみ | `gap-backlog.md` 要約 |
| 方針まで | `enhancement-plan.md` + G2/G3 verdict |
| モックまで | `screen-mocks.md` リンク |
| 起票まで | Epic / 子 issue の URL 一覧 |
