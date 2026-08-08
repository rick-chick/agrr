# WCAG 2.2 アクセシビリティ監査チェックリスト

AGRR フロントエンドの四半期手動監査と、自動 smoke（`npm run test:e2e:smoke:a11y`）の補完用チェックリストです。

## 実施頻度

| 種別 | 頻度 | 担当 |
|------|------|------|
| axe smoke（CI / ローカル） | PR ごと（`.github/workflows/frontend-e2e-smoke.yml`） | 自動 |
| 手動 WCAG 監査 | **四半期**（1・4・7・10 月の第 1 週を目安） | フロント担当 |

## 手動監査の手順

1. `npm run test:e2e:smoke:a11y` を GREEN にする（test-common 経由: `.cursor/skills/test-common/scripts/run-test-frontend.sh test:e2e:smoke:a11y`）。
2. 代表ルートをキーボードのみで操作する（Tab / Shift+Tab / Enter / Escape）。
3. スクリーンリーダー（VoiceOver または NVDA）で代表画面を読み上げ確認する。
4. 本チェックリストの各項目を記録する（日付・担当・結果・issue 番号）。
5. 未対応項目は GitHub issue 化し `agent-ready` を付与する。

## 代表ルート（最低限）

| ルート | 確認観点 |
|--------|----------|
| `/`（ホーム） | スキップリンク、フォーカス可視、ランドマーク |
| `/plans` | 認証後リスト、空状態、削除確認 |
| `/plans/:id` | ガントチャート SR ラベル、栽培選択、気候パネル |
| `/crops` | マスタ一覧、フォーム |
| `/public-plans/new` | 未認証フロー |

## WCAG 2.2 主要項目（Level A / AA）

### 1. 知覚可能（Perceivable）

- [ ] **1.1.1** 非テキストコンテンツにテキスト代替（ガント・気候チャートの `aria-label` / `role="img"`）
- [ ] **1.3.1** 情報と関係のプログラム的決定（見出し階層、ランドマーク、フォームラベル）
- [ ] **1.4.3** コントラスト（通常テキスト 4.5:1、大きいテキスト 3:1）— allowlist 残件は issue で追跡
- [ ] **1.4.11** 非テキストコントラスト（UI コンポーネント、グラフの識別可能な部分）

### 2. 操作可能（Operable）

- [ ] **2.1.1** キーボード操作（全機能にキーボード代替があること）
- [ ] **2.4.1** ブロックスキップ（スキップリンク）
- [ ] **2.4.3** フォーカス順序の論理性
- [ ] **2.4.7** フォーカスの可視化（`:focus-visible`）
- [ ] **2.5.7** ドラッグ操作の代替（ガント: モバイルメニュー経由）

### 3. 理解可能（Understandable）

- [ ] **3.1.1** ページ言語（`html lang`、i18n 切替）
- [ ] **3.2.2** 入力時のコンテキスト変更なし（意図しない画面遷移）
- [ ] **3.3.1** エラー識別（フォーム・API エラーの `role="alert"`）

### 4. 堅牢（Robust）

- [ ] **4.1.2** 名前・役割・値（ARIA 属性の妥当性）
- [ ] **4.1.3** ステータスメッセージ（`aria-live` / `role="status"`）

## 監査記録テンプレート

```markdown
## WCAG 2.2 四半期監査 — YYYY-QN

- **実施日**:
- **担当**:
- **環境**: ローカル Docker / agrr-test / 本番（読み取りのみ）
- **axe smoke**: PASS / FAIL（ログ path）
- **手動キーボード**: PASS / FAIL（メモ）
- **SR 読み上げ**: PASS / FAIL（メモ）
- **新規 issue**: #N, …
- **allowlist 変更**: あり / なし（`frontend/e2e/smoke/a11y-allowlist.json`）
```

## 関連ファイル

- `frontend/e2e/smoke/a11y-smoke.spec.ts` — axe 自動スキャン
- `frontend/e2e/smoke/a11y-allowlist.json` — 既知違反の allowlist（削減を優先）
- `frontend/e2e/smoke/gantt-keyboard-alternative.spec.ts` — ガント代替操作・SR 属性
- `frontend/src/app/core/a11y/form-card-field-a11y.ts` — フォーム a11y ヘルパ
