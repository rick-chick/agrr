# 「最適化中」が白地で見えない箇所の特定

## 該当箇所（白地の最適化中）

| 場所 | 要素 | テンプレート |
|------|------|--------------|
| **public-plan-optimizing.component.ts** L44 | `<span class="status-badge optimizing">` | `{{ 'public_plans.optimizing.status_badge' | translate }}` → 「最適化中」 |

- 親: `.compact-header-title` > `.compact-header-card`（背景 `--color-surface-hover` = #f1f5f9）
- 適用CSS: `public-plan.component.css` の `.status-badge`（ベース）と `.status-badge.optimizing`（背景・文字色）

## 白地になりうる理由

1. **変数が効いていない**: `.status-badge.optimizing` が `var(--color-info-light)`, `var(--color-info-dark)` を参照。これらは **app.css の :root のみ**で定義。読み込み順・スコープで未定義だとフォールバック (#90cdf4, #2b6cb0) に依存するが、フォールバックも効かない環境がある可能性。
2. **継承**: 親から `color` が継承され、バッジの `color` が上書きされている可能性（調査の結果、.title-text は .title-icon と .title-text にのみ影響し、.status-badge は別指定のため通常は継承で白にはならない）。

## 対応方針

変数に一切依存せず、**ハードコードの色**で「最適化中」バッジを常に視認可能にする。
