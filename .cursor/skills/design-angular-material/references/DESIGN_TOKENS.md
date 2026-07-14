# デザイントークン詳細（一貫性担保用）

SKILL.md で参照するトークンのスケール・命名・Angular Material テーマとの対応。

---

## 1. 余白スケール（4px ベース）

| 変数 | 値 | 用途例 |
|------|-----|--------|
| `--space-1` | 4px | アイコンとテキストの gap、密な padding |
| `--space-2` | 8px | ボタン内 padding、小さい gap |
| `--space-3` | 12px | フォーム要素間、ナビリンク間 |
| `--space-4` | 16px | カード内 padding、セクション間 |
| `--space-5` | 20px | 中程度のブロック間 |
| `--space-6` | 24px | ナビ・ヘッダー padding |
| `--space-8` | 32px | セクション区切り、大きなブロック間 |

**ルール**: `padding` / `margin` / `gap` はこのスケールのみ使用。中間値（例: 10px）が必要な場合はスケールに追加してから使う。

---

## 2. 角丸スケール

| 変数 | 値 | 用途例 |
|------|-----|--------|
| `--radius-sm` | 4px | バッジ、小さなボタン |
| `--radius-md` | 6px | ボタン、入力欄、ナビリンク |
| `--radius-lg` | 8px | カード、ドロップダウンパネル |
| `--radius-xl` | 12px | モーダル、大きなカード |

---

## 3. 色トークン（セマンティック命名）

**背景・表面**

- `--color-surface`: カード・パネル・ナビの背景（通常は白）
- `--color-background`: ページ全体の背景（薄いグレー可）
- `--color-surface-hover`: ホバー時の背景
- `--color-surface-selected`: 選択状態の背景

**テキスト**

- `--color-text`: 本文・見出し
- `--color-text-secondary`: 補足・キャプション
- `--color-text-disabled`: 無効テキスト
- `--color-text-on-primary`: 主色の上に載せるテキスト（例: プライマリボタン内）

**インタラクション**

- `--color-primary`: 主アクション・リンク
- `--color-primary-hover`: 主アクションのホバー
- `--color-accent`: 副アクション（任意）
- `--color-warning` / `--color-error`: 警告・エラー表示

**境界・区切り**

- `--color-border`: 入力枠・カード枠
- `--color-divider`: リスト区切り線

**フォーム入力（Material なし・ネイティブ HTML 向け）**

- `--color-input-focus`: 入力欄フォーカス時の枠色（通常は `--color-primary` と同一）
- `--color-input-hover`: 入力欄ホバー時の枠色（`--color-border` よりやや濃い色）
- `--color-input-arrow`: select のカスタム矢印アイコン色（`--color-text-secondary` と同一可）
- `--shadow-input-focus`: 入力欄フォーカス時のリング状の影（例: `0 0 0 2px rgba(37, 99, 235, 0.2)`）
- `--form-textarea-min-height`: textarea の最小高さ（例: 80px）

---

## 4. タイポグラフィ

| 変数 | 推奨値 | 用途 |
|------|--------|------|
| `--font-size-xs` | 12px | キャプション・ラベル |
| `--font-size-sm` | 14px | 本文補助・ナビ・ボタン |
| `--font-size-md` | 16px | 本文 |
| `--font-size-lg` | 18px | 小見出し |
| `--font-size-xl` | 20px | 見出し |
| `--font-weight-regular` | 400 | 本文 |
| `--font-weight-medium` | 500 | ラベル・強調 |
| `--font-weight-bold` | 700 | 見出し・ボタン |
| `--line-height-tight` | 1.25 | 見出し |
| `--line-height-normal` | 1.5 | 本文 |
| `--line-height-relaxed` | 1.75 | 長文 |

---

## 5. Angular Material テーマとの対応

Material を導入する場合、テーマ定義でパレットをトークンと揃える。

```scss
@use '@angular/material' as mat;

$primary-palette: mat.define-palette((
  500: #2563eb,  // --color-primary と同一に
  600: #1d4ed8,  // --color-primary-hover と同一に
  contrast: (500: white, 600: white)
));

$theme: mat.define-light-theme((
  color: (
    primary: $primary-palette,
    accent: $primary-palette
  )
));

@include mat.all-component-themes($theme);
```

- **色**: Material の `primary` / `accent` の 500/600 を CSS 変数 `--color-primary` / `--color-primary-hover` と一致させる。
- **余白**: コンポーネントの density や padding を `var(--space-*)` で上書きする場合は、`::ng-deep` を避け、テーマの mixin や CSS 変数で対応する。

---

## 7. レスポンシブ

メディアクエリで参照するブレークポイントはトークン化し、プロジェクトで値を統一する。

| 変数 | 値 | 用途例 |
|------|-----|--------|
| `--breakpoint-sm` | 480px | スマホ縦 |
| `--breakpoint-md` | 768px | タブレット・スマホ横 |
| `--breakpoint-lg` | 1024px | デスクトップ |
| `--form-card-max-width` | 480px | ダイアログ・モーダル等の最大幅。一覧・編集・詳細のメインカードには適用しない（幅制限なし） |

**ルール**

- **モバイルファースト**: 基本スタイルを小画面用に書き、`min-width` で段階的に拡張することを推奨する。
- **max-width を使う場合**: 既存レイアウトを上書きするときは `@media (max-width: 768px)` のように書く。768 は `--breakpoint-md` の値と一致させる（CSS のメディアクエリでは変数が使えないため、DESIGN_TOKENS の表と値を揃えておく）。

---

## 8. タッチ・操作（スマホで操作しやすくする）

ボタン・リンク・フォーム送信など、タップする要素は最小サイズを満たす。

| 変数 | 値 | 用途例 |
|------|-----|--------|
| `--touch-target-min` | 44px | ボタン・リンク・ナビの最小タップ領域（WCAG 2.5.5 を参照） |

**ルール**

- ボタン・ナビリンクには `min-height: var(--touch-target-min)` および必要に応じて `min-width` を指定し、タップ領域が 44px 以上になるようにする。
- アイコンのみのボタンも、クリック可能な領域は `--touch-target-min` 以上にする（padding で拡張する）。

---

## 6. トークン追加時のルール

1. **名前**: 用途が分かるセマンティック名（`--color-*`, `--space-*`, `--radius-*`, `--font-*`）。
2. **値**: 既存スケールにない場合は、スケールを拡張してから使用する（例: 余白 10px が必要なら `--space-2_5: 10px` を定義）。
3. **配置**: グローバルは `styles.css` の `:root`。テーマ専用は `angular-material-theme.scss` 等に集約。

これにより、一貫した見た目とメンテナンス性を両立できる。
