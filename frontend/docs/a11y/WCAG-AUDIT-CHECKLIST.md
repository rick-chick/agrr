# WCAG 2.2 アクセシビリティ監査チェックリスト

AGRR フロントエンドの四半期手動監査に使うチェックリスト。自動 smoke（`npm run test:e2e:smoke:a11y`）は回帰検知用であり、本リストは体系的な手動確認の記録用とする。

## 監査の頻度と手順

1. **四半期ごと**（1・4・7・10 月の第 1 週を目安）に 1 回実施する。
2. 監査前に `main` を pull し、`npm run test:e2e:smoke:a11y` が GREEN であることを確認する。
3. 代表ルート（公開 prerender、`/plans`、`/crops`、認証後の計画詳細 `/plans/:id`）をキーボードのみ・スクリーンリーダー（VoiceOver / NVDA）で巡回する。
4. 各項目を **Pass / Fail / N/A** で記録し、Fail は GitHub issue（`enhancement` + `agent-ready`）に起票する。
5. 監査結果（日付・担当・Pass/Fail サマリ）を PR または issue コメントに残す。

## WCAG 2.2 主要項目（レベル A / AA）

| 原則 | 基準 | 確認内容（AGRR 向け） |
|------|------|----------------------|
| 知覚可能 | 1.1.1 非テキストコンテンツ | ガント・気候チャートに `aria-label` / データ表代替。装飾 SVG に `aria-hidden`。 |
| 知覚可能 | 1.3.1 情報と関係性 | 見出し階層、フォームラベル、landmark（`main` / `nav`）の一意性。 |
| 知覚可能 | 1.4.3 コントラスト（最低限） | 本文・ボタン・フォーカスリングが AA（4.5:1 / 3:1 UI）。allowlist 外の違反ゼロ。 |
| 操作可能 | 2.1.1 キーボード | 全インタラクティブ要素が Tab / Enter / Space で操作可能。 |
| 操作可能 | 2.4.1 ブロックのスキップ | `#main-content` スキップリンクが全認証後画面で機能する。 |
| 操作可能 | 2.4.7 フォーカスの可視化 | `:focus-visible` が全カスタムコンポーネントで視認できる。 |
| 操作可能 | 2.5.7 ドラッグ操作の代替 | ガントのモバイルメニュー（作物・圃場）でドラッグなし操作が可能。 |
| 理解可能 | 3.3.2 ラベルまたは説明 | `form-card-field-a11y` 経由のフォームにラベル・`aria-describedby`。 |
| 堅牢 | 4.1.2 名前・役割・値 | 動的 UI（ガント選択 `aria-selected`、気候タブ `role="tab"`）が AT に通知される。 |

## 自動テストとの役割分担

| 手段 | スコープ |
|------|----------|
| `test:e2e:smoke:a11y` | axe-core による既知 allowlist 外違反の検知。公開 prerender + `/plans` / `/crops` サンプル。 |
| `gantt-keyboard-alternative.spec.ts` | WCAG 2.5.7 ガント代替操作 + SR 属性の存在。 |
| 本チェックリスト（手動） | スクリーンリーダーでの読み上げ品質、文脈・エラー回復、実機タッチターゲット。 |

## allowlist の見直し（毎監査）

`frontend/e2e/smoke/a11y-allowlist.json` の各エントリについて:

- 修正済みなら **エントリを削除**し smoke を再実行する。
- 削減不能なら `reason` に **再現ルート・根本原因・解消条件** を明記する（例: マーケティング色トークンの AA 未達）。

## 記録テンプレート

```
監査日: YYYY-MM-DD
担当:
ブランチ / コミット:
自動 smoke: PASS / FAIL
手動結果: Pass N / Fail M / N/A K
Fail 起票: #NNN, ...
備考:
```
