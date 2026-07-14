---
name: agent-route-manifest-png-capture
description: >-
  Agent 向け全ルート PNG キャプチャ（npm run e2e:capture-for-agent）の入口。
  手順は frontend-css-route-audit スキルの「全ルートの PNG を揃える前提」節を参照する。
  route-manifest キャプチャ、e2e/agent-review/out、e2e:capture-for-agent の依頼で適用する。
disable-model-invocation: true
---

# Agent 用 route-manifest PNG キャプチャ

**手順・前提・限界**: [`frontend-css-route-audit`](../frontend-css-route-audit/SKILL.md) の **「全ルートの PNG を揃える前提」** 節を参照する。本スキルは入口のみで、手順は同スキルから分岐させない（**重複記述による drift を避けるため**）。

## 入口の要点（詳細は参照先へ）

- **キャプチャコマンド**: `cd frontend && npm run e2e:capture-for-agent`
- **前提**: Rails development（`127.0.0.1:3000`）、`AuthTestController` の `mock_login` が有効、`/api/v1/auth/me` はモックしない、開発 DB が応答する。
- **出力**: `frontend/e2e/agent-review/out/*.png`（末尾で `verify-capture-complete.mjs` が件数検証）。
- **`npm run test:e2e`** の `route-manifest-visual.spec.ts` は `E2E_CAPTURE_DEV_SESSION` 未設定時に skip（キャプチャだけなら上記 npm script のみで足りる）。
- **ルート変更後のみ** `npm run e2e:manifest` で `route-manifest.json` / `route-to-png.md` を再生成。

## ビジュアルレビューを伴う依頼の流れ

1. 本スキル（または `frontend-css-route-audit`）でキャプチャを取る。
2. レビュー成果物の型は [`frontend-agent-visual-review`](../frontend-agent-visual-review/SKILL.md) に従い、`frontend/e2e/agent-review/visual-review-results.md` 等に書き出す。
3. CSS トークン当て漏れの列挙は **PNG ではなく `npm run audit:css-tokens`** で行う（[`frontend-css-route-audit`](../frontend-css-route-audit/SKILL.md) の役割分担表）。

## 参照

- 参照: [`frontend-css-route-audit`](../frontend-css-route-audit/SKILL.md)
- レビュー成果物: [`frontend-agent-visual-review`](../frontend-agent-visual-review/SKILL.md)
- README: `frontend/e2e/agent-review/README.txt`、`frontend/e2e/.auth/README.txt`
