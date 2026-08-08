# ADR-003: ダークモード方針（将来対応・トークン設計）

## Status

Accepted (2026-08-08)

親 issue: [#731](https://github.com/rick-chick/agrr/issues/731)（デザインシステム AI-ready 仕様）。関連: [#712](https://github.com/rick-chick/agrr/issues/712)（クローズ済み・実装は未着手）。

## Context

- `frontend/src/styles.css` がデザイントークンの単一ソースであり、`:root` にセマンティック色・余白・タイポグラフィを定義している。
- `rg 'prefers-color-scheme|data-theme' frontend/` は **0 件**（2026-08 時点）。ライトテーマのみで稼働している。
- Issue #712 は方針記録なしでクローズされたため、エージェント・実装者がダークモードの扱いを判断できない状態だった。
- UX 観点 2（デザインシステム）では、未決定のまま issue を閉じず **明示的な方針** が必要。

## Decision

**方針 (B): 将来対応予定とトークン設計方針を採用する。**

1. **現行リリースはライトテーマのみ** — `prefers-color-scheme: dark` や `data-theme` の実装は行わない。
2. **トークン拡張で備える** — 新規 UI は必ず `styles.css` のセマンティックトークン（`--color-surface`, `--color-text` 等）を使い、コンポーネント CSS に色の直書きをしない（`audit:css-tokens:enforce` 準拠）。
3. **将来実装時の経路** — ダークモード対応時は `styles.css` に `@media (prefers-color-scheme: dark) { :root { … } }` または `[data-theme="dark"]` ブロックでトークンを上書きする。シェル（`app` ルート）と `form-card` から段階的に適用し、WCAG AA コントラストを検証する。
4. **コンポーネント単位の dark ブロックは禁止** — 画面ごとに `prefers-color-scheme` を書かず、トークン差し替えに集約する。

方針 (A) 非対応明示は、農業 SaaS の夜間利用・OS 設定追随の需要を無視するため不採用。方針 (C) 即時実装は #731 のスコープ（仕様文書化）を超えるため別 issue とする。

## Consequences

### Positive

- エージェントは [`COMPONENT-GUIDE.md`](../../frontend/docs/design-system/COMPONENT-GUIDE.md) と本 ADR でダークモード未実装を正しく理解できる。
- 既存のトークン監査 CI を維持したまま、将来の dark 対応コストを下げられる。

### Negative

- ダークモード利用者には OS ライト固定相当の体験が続く（許容。別 issue で (C) を実装可能）。

## Compliance

- `npm run audit:css-tokens:enforce` — GREEN 維持必須
- `npm run check:btn-base-class:enforce` — GREEN 維持必須
- ダークモード実装 issue 起票時は本 ADR の「将来実装時の経路」に従う
