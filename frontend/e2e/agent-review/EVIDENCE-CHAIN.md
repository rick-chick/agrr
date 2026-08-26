# UX/UI Issue 起票 — 証拠鎖（Capture Run）

PNG を根拠にする Issue 起票は **Capture Run ボンドル**で束ねる。レビュー成果物は **リポジトリに置かない**（`frontend/tmp/agent-review/` のみ）。

## 証拠の二層

| 層 | 正本 | Issue 起票 |
|----|------|------------|
| **機械** | `audit:css-tokens`、locale catalog spec、axe smoke 等 | CSS / 一部 i18n・a11y は PNG 不要 |
| **視覚** | `tmp/agent-review/agent-review-bundle.json` + 同 runId の PNG | bundle に無い PNG は根拠にしない |
| **Pattern カタログ** | `docs/design/pattern-manifest.json`（メタのみ、commit 可） | Pattern ID・routes・L2 レビュー日 |

`visual-review.json` と PNG は **tmp のみ**（リポジトリに commit しない）。

## 必須パイプライン（視覚指摘 → Issue）

```bash
cd frontend
npm run e2e:capture-for-agent          # PNG + bundle 生成（tmp/agent-review/）
# frontend-agent-visual-review で visual-review.json 生成（captureRunId = bundle.runId）
npm run e2e:agent-review:evidence:check:enforce
node ../.cursor/skills/ux-issue-creator/scripts/collect-ux-findings.mjs
```

`collect-ux-findings` は **証拠鎖ゲート未通過なら exit 1**（起票中止）。

## ファイル（すべて gitignore）

| ファイル | 役割 |
|----------|------|
| `e2e/agent-review/out/*.png` | スクリーンショット（再キャプチャで上書き） |
| `tmp/agent-review/agent-review-bundle.json` | runId・sha256・capturedAt（PNG の正本メタ） |
| `tmp/agent-review/visual-review.json` | ビジュアルレビュー。**captureRunId 必須** |
| `tmp/agent-review/cognitive-guidance-review.json` | 認知導線レビュー（任意） |
| `tmp/agent-review/ux-findings-draft.json` | collect 出力 |

## 差分キャプチャ

一部ルートだけ再撮影したあと:

```bash
playwright test e2e/visual/route-manifest-visual.spec.ts --grep 'pattern'
node e2e/agent-review/generate-capture-bundle.mjs --merge
# visual-review.json を captureRunId 付きで再生成
```

## 禁止

- captureRunId なし / bundle なしで `gh issue create`
- 本文に「PNG で確認済み」と書く（collect が証拠鎖通過を記録する）
- `未レビュー` / `未キャプチャ` 行から Issue 起票（collect が除外）
- レビュー成果物を `e2e/agent-review/` 配下にコミットする
