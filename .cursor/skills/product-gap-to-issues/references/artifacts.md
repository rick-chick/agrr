# 成果物チェーン

すべて `tmp/product-gap/` 配下。リポジトリに commit しない。

| ファイル | フェーズ | 必須 |
|----------|----------|------|
| `current-state.md` | 1 | ✓ |
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
