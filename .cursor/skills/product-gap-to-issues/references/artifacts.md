# 成果物チェーン

すべて `tmp/product-gap/` 配下。リポジトリに commit しない。

| ファイル | フェーズ | 必須 |
|----------|----------|------|
| `current-state.md` | 1 | ✓ |
| `gap-backlog.md` | 2 | ✓ |
| `theme-selection.md` | 3 | ✓ |
| `theme-deep-dive.md` | 4 | ✓ |
| `overlap-ux-gate.json` | 5 G2 | ✓ |
| `enhancement-plan.md` | 6 | ✓ |
| `plan-review.json` | 7 G3 | ✓（起票まで行う場合） |
| `screen-mocks.md` | 8 | 起票まで行う場合 ✓ |
| `issue-pack.md` | 9 | 起票まで行う場合 ✓ |

## ゲート JSON の最小例

**G2 pass:**

```json
{
  "gate": "overlap-ux-guard",
  "verdict": "pass",
  "summary": "新画面不要。/work を入口、/plans/:id/work を実行本体に強化",
  "findings": [],
  "mandatory_corrections": []
}
```

**G3 fail:**

```json
{
  "gate": "plan-review",
  "verdict": "fail",
  "summary": "v1 が5項目あり上限超過",
  "findings": ["天候1行とGDD補足がv1に残っている"],
  "mandatory_corrections": ["天候・GDDをv2へ移動", "v1を3 issueに固定"]
}
```

## 完了報告に含めるもの

| 終了地点 | 報告 |
|----------|------|
| 調査のみ | `gap-backlog.md` 要約 |
| 方針まで | `enhancement-plan.md` + G2/G3 verdict |
| モックまで | `screen-mocks.md` リンク |
| 起票まで | Epic / 子 issue の URL 一覧 |
