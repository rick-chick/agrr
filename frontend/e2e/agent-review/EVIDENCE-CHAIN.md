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
| `e2e/agent-review/agent-review-bundle.json` | **追跡** | runId・sha256・capturedAt（PNG の正本メタ） |
| `e2e/agent-review/visual-review-results.md` | 追跡 | レビュー表。**captureRunId 必須** |

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

## 四半期ごとの認知導線再レビュー（運用）

**目的**: ジョブシナリオ（J1–J8）・空状態・エラー回復の導線が、ルート追加後も退行していないかを定期的に確認する。

**頻度**: 四半期ごと（1・4・7・10 月の第 1 週を目安）。ルート manifest の大幅変更（10 件超の追加・削除）があった場合は臨時実施。

**手順**（`ux-cognitive-guidance-review` スキルに準拠）:

1. **キャプチャ** — `cd frontend && npm run e2e:capture-for-agent`（happy path + `empty-state-capture-for-agent`）
2. **ビジュアルレビュー** — `frontend-agent-visual-review` で `visual-review-results.md` を更新
3. **証拠鎖** — `npm run e2e:agent-review:stamp-review` → `npm run e2e:agent-review:evidence:check:enforce`
4. **認知導線レビュー** — `ux-cognitive-guidance-review` で `cognitive-guidance-review.md` を更新（空状態・エラー状態を優先）
5. **Issue 化** — 要確認項目は `ux-issue-pipeline` / `ux-issue-creator` で起票。P1 以上は `agent-ready` 付与

**完了条件**:

- `agent-review-bundle.json` の `captureRunId` と `visual-review-results.md` が一致
- `cognitive-guidance-review.md` のレビュー日が当四半期内
- 新規「要確認」には follow-up issue 番号が本文に列挙されている

**参照**: `.cursor/skills/ux-cognitive-guidance-review/SKILL.md`、`frontend/e2e/agent-review/cognitive-guidance-review.md`
