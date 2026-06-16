---
name: frontend-css-route-audit
description: >-
  AGRR Angular の CSS/トークン当て漏れは npm run audit:css-tokens。
  Agent 向け全ルート PNG は npm run e2e:capture-for-agent のみ（Rails development +
  AuthTest モックログイン・セッション共有、/me はモックしない）。
  verify で全件 PNG。ビジュアルレビューの成果物フォーマットは frontend-agent-visual-review スキルに従う。
  CSS漏れ・capture・route-manifest の依頼で適用する。
---

# Frontend CSS とキャプチャ（AGRR）

## 役割分担

| 目的 | 手段 |
|------|------|
| **トークン直書きなど CSS の当て漏れを機械的に列挙** | `cd frontend && npm run audit:css-tokens`（CI 厳格: `audit:css-tokens:enforce`） |
| **全ルート PNG（Rails + ログイン済みセッション）** | `npm run e2e:capture-for-agent` … `E2E_CAPTURE_DEV_SESSION=1`、`127.0.0.1:3000`＋`dev-session.json` |
| **画面の定性レビュー（成果物としての完了）** | **`frontend-agent-visual-review`** スキル … `visual-review-results.md` 等の必須表 |

**ピクセル差分回帰は前提に含めない。**

---

## スキル必須要件（キャプチャ・CSS）

### 1. 全ルートの PNG を揃える前提

- **`npm run e2e:capture-for-agent`** … Rails development（127.0.0.1:3000）と ng を起動し **AuthTest モックログイン**で **`e2e/.auth/dev-session.json`** を生成。**`/api/v1/auth/me` はモックしない**。`route-manifest` の全 pattern について **`ja` / `en` / `in`** の 3 言語 PNG（`out/{ベース}.{locale}.png`）を書き出し、末尾で **`verify-capture-complete.mjs`** が件数検証する（**production では無効**なルート。詳細 **`frontend/e2e/.auth/README.txt`**）。
- **`npm run test:e2e`** … `route-manifest-visual.spec.ts` は **`E2E_CAPTURE_DEV_SESSION` 未設定時は skip**（キャプチャ専用は上記 npm script）。
- **Playwright の pass は「キャプチャ成功」であり、ビジュアル品質の合格ではない。** 定性レビューは **`frontend-agent-visual-review`** で成果物化する。

**前提と限界（エージェントが誤解しないため）**

- **前提**: `RAILS_ENV=development`、**`auth/test/mock_login_as` が有効**、**開発 DB が応答する**こと。OAuth は不要。
- **並列ワーカー＋非同期 UI**で、極稀に **「読み込み中...」だけの PNG** が混じり得た。**`route-manifest-visual.spec.ts` の `waitForCaptureStable`** はホスト内の `.master-loading:not(.master-error)` の**消滅**まで待つ。`toBeHidden` はマッチ 0 件で即成功し得るため、**一覧・詳細・編集・API キー等ではスピナーが一度でも付くルートに限り**、先にスピナー出現を短時間ポーリングしてから消滅待ちする。それでも **60s 超の遅延・API 不全・404** は撮影品質の範囲外。**画面品質の議論はビジュアルレビュー側で `注意`／`要確認` とし**、キャプチャ spec 以外の原因はアプリ・API を切り分ける。
- **`route-manifest.json` の固定 ID**（例: `/crops/1`、`resolve-capture-urls` で差し替え後も DB に行が無いと 404・空フォームになり得る。キャプチャは通っても中身は期待とずれる。

### 2. ページ指定・URL 逼迫禁止

- **正**: `frontend/e2e/route-manifest.json` と **`frontend/e2e/agent-review/route-to-png.md`**（`npm run e2e:manifest` で同時生成）。
- **ユーザーに「どの URL？」「どのページを見る？」と聞かない。** 不明なら表を読む。

### 3. ビジュアルレビューを依頼するとき

- **`frontend-agent-visual-review`** を読み、**`e2e/agent-review/visual-review-results.md`**（またはスキル記載の必須フォーマット）へ出力させる。
- 参照: `@frontend/e2e/agent-review/out` ＋ `@frontend/e2e/agent-review/route-to-png.md`

---

## コマンド早見

| 操作 | コマンド |
|------|----------|
| ルート一覧 + PNG 対応表の再生成 | `cd frontend && npm run e2e:manifest` |
| Agent 向け全ルートキャプチャ | `npm run e2e:capture-for-agent` |
| Playwright 全件（キャプチャは未設定時 skip） | `npm run test:e2e` |
| トークン直書き列挙（レポート・通常 exit 0） | `npm run audit:css-tokens` |
| トークン違反で **exit 非 0**（CI 想定） | `npm run audit:css-tokens:enforce` |

詳細: **`frontend/e2e/agent-review/README.txt`** ・認証ストレージ: **`frontend/e2e/.auth/README.txt`**

---

## キャプチャ前の妥当性（コード）

- `e2e/route-validity.ts` … pathname + ホストコンポーネント
- `e2e/route-manifest-coverage.spec.ts` … マニフェスト全 pattern のホスト定義

## エージェント禁止（本スキル範囲）

- PNG だけで「CSS 当て漏れを列挙した」と主張する（列挙は `audit:css-tokens`）。
- 「ページが多いから指定して」とユーザーに逃げる。
- 検証を飛ばした `out/` だけで「キャプチャ完了」と同等の**レビュー完了**を主張する（レビュー成果物は別スキル）。

## メンテナンス

- ルート追加: `e2e:manifest` → `HOST_SELECTOR_BY_PATTERN` 更新 → `npm run test:e2e`

## 関連（Issue 起票）

キャプチャ・レビュー・CSS 監査から GitHub Issue 化: **`ux-issue-pipeline`** → **`ux-issue-creator`**
