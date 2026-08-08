# UX/UI Issue 起票 — 証拠鎖（Capture Run）

PNG を根拠にする Issue 起票は **Capture Run ボンドル**で束ねる。古い `visual-review-results.md` や古い PNG を単独の正本にしない。

## 証拠の二層

| 層 | 正本 | Issue 起票 |
|----|------|------------|
| **機械** | `audit:css-tokens`、locale catalog spec、axe smoke 等 | CSS / 一部 i18n・a11y は PNG 不要 |
| **視覚** | `agent-review-bundle.json` + 同 runId の PNG | bundle に無い PNG は根拠にしない |

## 必須パイプライン（視覚指摘 → Issue）

```bash
cd frontend
npm run e2e:capture-for-agent          # PNG + agent-review-bundle.json 生成
# frontend-agent-visual-review で visual-review-results.md 更新
npm run e2e:agent-review:stamp-review # メタに captureRunId を刻む
npm run e2e:agent-review:evidence:check:enforce
node ../.cursor/skills/ux-issue-creator/scripts/collect-ux-findings.mjs
```

`collect-ux-findings` は **証拠鎖ゲート未通過なら exit 1**（起票中止）。

## ファイル

| ファイル | git | 役割 |
|----------|-----|------|
| `e2e/agent-review/out/*.png` | ignore | スクリーンショット（再キャプチャで上書き） |
| `e2e/agent-review/agent-review-bundle.json` | ignore（推奨） | runId・sha256・capturedAt（PNG の正本メタ）。**コミットしない** |
| `e2e/agent-review/visual-review-results.md` | **ignore** | レビュー表。**captureRunId 必須**。パイプライン生成物のみ |
| `e2e/agent-review/cognitive-guidance-review.md` | **ignore** | 認知導線レビュー。パイプライン生成物のみ |

## 差分キャプチャ

一部ルートだけ再撮影したあと:

```bash
playwright test e2e/visual/route-manifest-visual.spec.ts --grep 'pattern'
node e2e/agent-review/generate-capture-bundle.mjs --merge
npm run e2e:agent-review:stamp-review
```

## 禁止

- captureRunId なし / bundle なしで `gh issue create`
- 本文に「PNG で確認済み」と書く（collect が証拠鎖通過を記録する）
- `未レビュー` / `未キャプチャ` 行から Issue 起票（collect が除外）
