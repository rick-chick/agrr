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

**目的**: happy path 偏重を防ぎ、空状態・ブロック・API エラー画面の L0–L4 導線を定期的に再評価する。

**頻度**: 四半期ごと（1・4・7・10 月の第 1 週を目安。ルート大幅変更時は臨時実施可）。

**手順**（正本スキル: `.cursor/skills/ux-cognitive-guidance-review/SKILL.md`）:

1. **キャプチャ** — `npm run e2e:capture-for-agent`（manifest 全ルート + `empty-state-capture-for-agent` の 4 シナリオ ja PNG）
2. **ビジュアル** — `frontend-agent-visual-review` で `visual-review-results.md` 更新 → `npm run e2e:agent-review:stamp-review`
3. **認知導線** — `ux-cognitive-guidance-review` で `cognitive-guidance-review.md` を J1–J8 軸で更新（空状態セクション必須）
4. **証拠鎖** — `npm run e2e:agent-review:evidence:check:enforce` が exit 0
5. **起票** — `collect-ux-findings` → `ux-issue-creator`（P1 以上の `要確認` は follow-up issue 化）

**成果物チェックリスト**:

| 成果物 | 更新 |
|--------|------|
| `cognitive-guidance-review.md` | ジョブ表・画面表・空状態セクション |
| `visual-review-results.md` | captureRunId が bundle と一致 |
| `agent-review-bundle.json` | 最新キャプチャ runId |
| `docs/product/USER-FLOW-REVIEW.md` | 対応済み項目のステータス（必要時） |

**CI との関係**: 週次 `frontend-e2e-capture.yml` が PNG artifact を生成。四半期レビューは artifact 取得後に上記 2–5 を実施してもよい（ローカルキャプチャと同等）。
