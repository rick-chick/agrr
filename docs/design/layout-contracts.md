# Layout Design Contracts

レイアウト smoke の **L2 設計契約**（意味の単一ソース）です。  
機械可読な定義は [`frontend/e2e/smoke/layout-archetype-design-contracts.mjs`](../frontend/e2e/smoke/layout-archetype-design-contracts.mjs) を正とします。

## 層の役割

| 層 | ファイル | 役割 |
|---|---|---|
| L1 | `layout-invariants.ts` | 全ルート共通（横スクロール、見出し、`.item-card__actions` 行数・重なり） |
| L2 | `layout-archetype-design-contracts.mjs` | archetype ごとの**構造・密度・はみ出し** |
| 画面 override | `layout-contracts.ts` | `plans` など個別の追加検証 |

## 契約フィールド

| フィールド | 意味 |
|---|---|
| `contentBlockSelectors` | 存在・横はみ出しを検査する主要ブロック |
| `requireAnyContentBlock` | `true` のとき、可視ブロックが 0 件なら **RED**（サイレントパス禁止） |
| `pageTitleSelectors` | ページタイトル相当が可視であること |
| `conditionalVisibleSelectors` | DOM にあれば可視であること（例: plan context header） |
| `maxItemCardVisibleActionButtons` | カード上の可視 `.btn` 上限（溢れは overflow menu へ） |
| `checkFormCardActionRows` | `.form-card__actions` の折り返し行数上限 |
| `checkDetailCardActionOverlap` | `.detail-card__actions` のボタン重なり禁止 |
| `requiredShellSelectors` | L1+ でホスト内に必須のシェル要素 |
| `wizardProgressSelectors` | wizard 進捗バーが DOM にあるとき `display: flex` + `min-height >= 40px`（欠如時はスキップ） |

## archetype 一覧

| archetype | 意図 |
|---|---|
| `master-list` | マスタ一覧。空リストは許容。カードアクション密度を制限 |
| `master-detail` | `.detail-card` 必須。アクション重なり禁止 |
| `master-form` | `.form-card` 必須。フォームアクション折り返し制限 |
| `wizard-step` | 公開プラン wizard シェル |
| `plan-hub` | 計画コンテキスト配下（ガント・作業・最適化など） |
| `plan-form` | 計画作成・オンボーディング |
| `section-hub` | 作業ハブ・生育ステージ・エントリースケジュール等 |
| `settings-page` | アカウント・API キー |
| `static-page` | ホーム・静的ページ |

## 新ルート追加時

1. `layout-contract-bindings.mjs` に pattern → archetype を追加
2. 既存 archetype で足りなければ `layout-archetype-design-contracts.mjs` に契約を追加
3. `layout-contract-archetype-keys.mjs` に runner key を追加
4. `npm run e2e:layout-contract:check:enforce` が GREEN であること

## 観点（レビュー・AI 診断用）

L2 が拾えない領域は以下の観点で人間/AI レビューする。

- **情報階層**:  primary / secondary の視線誘導
- **アクション密度**: カード・ヘッダの操作数（3 超は menu 化）
- **状態別 UI**: loading / empty / error / success で構造が一貫しているか
- **viewport**: mobile で横スクロール・タップ領域が十分か
- **一貫性**: 同一 archetype 間で余白・見出し・カード構造が揃っているか
