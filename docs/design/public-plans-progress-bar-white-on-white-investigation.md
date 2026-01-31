# 進捗バー（1 地域 / 2 サイズ / 3 作物）白地に白背景の調査

## 該当しうる箇所

| 要素 | 現在のスタイル | 変数定義 | 白になりうる理由 |
|------|----------------|----------|------------------|
| `.compact-header-card` | `background: var(--color-surface-hover)` | styles.css | 変数未読込時は透明→ページ背景と同化 |
| `.compact-step` | 背景なし | - | 透明のためヘッダーと同色。カードが白っぽいとステップも溶け込む |
| `.step-number`（未完了） | `background: var(--color-gray-200)`, `color: var(--color-gray-500)` | **app.css** | 変数が app.css のみで、未読込・未定義だと背景・文字とも未設定→白に近い |
| `.step-number`（完了/現在） | success / info + 白文字 | app.css, styles.css | 変数未定義時は背景が透ける可能性 |
| `.step-label` | `color: var(--color-text-secondary)` | styles.css | 未定義時は継承で薄い色になる可能性 |

## 結論

- **主因**: `.step-number` の未完了状態が **app.css** の `--color-gray-200` / `--color-gray-500` に依存。読み込み順・スコープで未定義だと背景・文字が白っぽくなる。
- **副因**: `.compact-step` に背景がなく、ヘッダーカード（薄いグレー）上でステップの塊が区別しづらい。

## 対応方針（実施済み）

1. **`.step-number`** にフォールバック値を付与（`var(--color-gray-200, #e2e8f0)` 等）。変数未定義でも視認できるようにした。
2. **`.compact-step`** に薄い背景と枠を付与（`background: rgba(255,255,255,0.7)`、`border: 1px solid var(--color-border)`）。ステップをヘッダーから区切った。
3. **`.step-label`** の色にもフォールバックを付与（`--color-text-secondary, #4a5568` 等）。
