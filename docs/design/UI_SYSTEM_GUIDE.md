# AGRR UI System ガイド

## 概要

AGRRのUIシステムは、統一されたデザイントークンとコンポーネントベースのアーキテクチャで構築されています。このガイドでは、デザインシステムの使用方法とベストプラクティスを説明します。

## デザイントークン

### カラーパレット

#### Primary Colors（農業テーマの緑）
- `--color-primary`: `#2d5016` - メインブランドカラー
- `--color-primary-light`: `#4a7c23`
- `--color-primary-dark`: `#1a3009`

#### Secondary Colors（アクセント紫）
- `--color-secondary`: `#667eea` - AI/テクノロジー感
- `--color-secondary-light`: `#8b9dff`
- `--color-secondary-dark`: `#4a5fc5`

#### Functional Colors
- `--color-success`: `#48bb78` - 成功・完了
- `--color-warning`: `#f6ad55` - 警告
- `--color-error`: `#fc8181` - エラー
- `--color-info`: `#4299e1` - 情報

#### Neutral Colors
- `--color-gray-50` から `--color-gray-900` まで段階的に定義
- `--color-white`: `#ffffff`
- `--color-black`: `#000000`

#### Text Colors
- `--text-primary`: `#333333` - 主要テキスト
- `--text-secondary`: `#666666` - 補助テキスト
- `--text-tertiary`: `#999999` - 第三テキスト
- `--text-inverse`: `#ffffff` - 反転テキスト

### スペーシングシステム

8pxベースのスペーシングスケールを使用：

- `--space-0`: `0`
- `--space-1`: `0.25rem` (4px)
- `--space-2`: `0.5rem` (8px)
- `--space-3`: `0.75rem` (12px)
- `--space-4`: `1rem` (16px)
- `--space-5`: `1.5rem` (24px)
- `--space-6`: `2rem` (32px)
- `--space-8`: `3rem` (48px)
- `--space-10`: `4rem` (64px)
- `--space-12`: `6rem` (96px)

### タイポグラフィ

#### Font Families
- `--font-family-base`: システムフォントスタック（日本語対応）
- `--font-family-mono`: 等幅フォントスタック

#### Font Sizes
- `--font-size-xs`: `0.75rem` (12px)
- `--font-size-sm`: `0.875rem` (14px)
- `--font-size-base`: `1rem` (16px)
- `--font-size-lg`: `1.125rem` (18px)
- `--font-size-xl`: `1.25rem` (20px)
- `--font-size-2xl`: `1.5rem` (24px)
- `--font-size-3xl`: `2rem` (32px)
- `--font-size-4xl`: `2.5rem` (40px)
- `--font-size-5xl`: `3rem` (48px)
- `--font-size-6xl`: `3.5rem` (56px)

#### Font Weights
- `--font-weight-light`: `300`
- `--font-weight-normal`: `400`
- `--font-weight-medium`: `500`
- `--font-weight-semibold`: `600`
- `--font-weight-bold`: `700`
- `--font-weight-extrabold`: `800`
- `--font-weight-black`: `900`

### ボーダー

#### Border Radius
- `--radius-none`: `0`
- `--radius-sm`: `0.25rem` (4px)
- `--radius-base`: `0.375rem` (6px)
- `--radius-md`: `0.5rem` (8px)
- `--radius-lg`: `0.75rem` (12px)
- `--radius-xl`: `1rem` (16px)
- `--radius-2xl`: `1.5rem` (24px)
- `--radius-full`: `9999px` (完全な円形)

### シャドウ

- `--shadow-xs`: 最小のシャドウ
- `--shadow-sm`: 小さいシャドウ
- `--shadow-base`: 基本シャドウ
- `--shadow-md`: 中程度のシャドウ
- `--shadow-lg`: 大きいシャドウ
- `--shadow-xl`: 非常に大きいシャドウ
- `--shadow-2xl`: 最大のシャドウ

### トランジション

- `--transition-fast`: `150ms ease-in-out`
- `--transition-base`: `250ms ease-in-out`
- `--transition-slow`: `350ms ease-in-out`

## コンポーネント

### ボタン

#### 基本クラス
```html
<button class="btn btn-primary">プライマリボタン</button>
<button class="btn btn-secondary">セカンダリボタン</button>
<button class="btn btn-success">成功ボタン</button>
<button class="btn btn-error">エラーボタン</button>
```

#### サイズ
```html
<button class="btn btn-primary btn-sm">小さい</button>
<button class="btn btn-primary btn-md">標準</button>
<button class="btn btn-primary btn-lg">大きい</button>
<button class="btn btn-primary btn-xl">特大</button>
```

詳細は `app/assets/stylesheets/components/buttons.css` を参照。

### フォーム

#### 基本構造
```html
<div class="form-group">
  <label class="form-label">ラベル</label>
  <input type="text" class="form-control" />
  <span class="form-text">補助テキスト</span>
</div>
```

#### エラー表示
```html
<div class="form-group">
  <input type="text" class="form-control is-invalid" />
  <span class="error-message">エラーメッセージ</span>
</div>
```

詳細は `app/assets/stylesheets/components/forms.css` を参照。

### カード

```html
<div class="field-card">
  <h3 class="field-name">カードタイトル</h3>
  <div class="field-actions">
    <button class="btn btn-primary">アクション</button>
  </div>
</div>
```

詳細は `app/assets/stylesheets/components/cards.css` を参照。

### フッター

```html
<footer class="footer">
  <div class="footer-container">
    <div class="footer-grid">
      <!-- セクション -->
    </div>
    <div class="footer-divider">
      <p class="footer-copyright">Copyright</p>
    </div>
  </div>
</footer>
```

詳細は `app/assets/stylesheets/components/footer.css` を参照。

## ユーティリティクラス

### スペーシング

```html
<div class="mt-4 mb-6">マージン</div>
<div class="pt-4 pb-6">パディング</div>
```

### テキスト

```html
<p class="text-center text-primary">中央揃え・プライマリ色</p>
<p class="text-sm font-bold">小さい・太字</p>
```

### 表示

```html
<div class="d-flex justify-between align-center">Flexbox</div>
<div class="d-none d-md-block">レスポンシブ表示</div>
```

## ベストプラクティス

### 1. インラインスタイルの禁止

❌ **悪い例:**
```html
<div style="padding: 20px; background: #fff; border-radius: 8px;">
```

✅ **良い例:**
```html
<div class="card" style="padding: var(--space-5); background: var(--bg-card); border-radius: var(--radius-md);">
```

さらに良い例（CSSクラスを使用）:
```html
<div class="card">
```

### 2. デザイントークンの使用

すべての色、スペーシング、タイポグラフィはデザイントークンを使用してください。

❌ **悪い例:**
```css
.my-component {
  color: #333;
  padding: 20px;
  font-size: 18px;
}
```

✅ **良い例:**
```css
.my-component {
  color: var(--text-primary);
  padding: var(--space-5);
  font-size: var(--font-size-lg);
}
```

### 3. コンポーネントの再利用

既存のコンポーネントクラスを優先的に使用してください。

❌ **悪い例:**
```html
<button style="background: blue; color: white; padding: 10px;">ボタン</button>
```

✅ **良い例:**
```html
<button class="btn btn-primary">ボタン</button>
```

### 4. レスポンシブデザイン

ブレークポイントはデザイントークンを使用：

```css
@media (max-width: 768px) {
  /* モバイル用スタイル */
}
```

または、ユーティリティクラスを使用：

```html
<div class="d-none d-md-block">デスクトップのみ表示</div>
```

## ファイル構造

```
app/assets/stylesheets/
├── core/
│   ├── variables.css    # デザイントークン定義
│   └── reset.css        # リセットとベーススタイル
├── components/
│   ├── buttons.css      # ボタンコンポーネント
│   ├── forms.css        # フォームコンポーネント
│   ├── cards.css        # カードコンポーネント
│   ├── navbar.css       # ナビゲーションバー
│   └── footer.css       # フッター
├── features/
│   ├── plans.css        # 計画機能
│   ├── gantt_chart.css  # ガントチャート
│   └── ...
├── layouts/
│   └── admin.css        # 管理画面レイアウト
├── application.css      # ユーティリティクラス
└── utilities.css        # 追加ユーティリティ
```

## レイアウトファイルの読み込み順序

すべてのレイアウトファイルで、以下の順序でCSSを読み込んでください：

1. Core Design System（variables, reset）
2. Utilities
3. Components
4. Feature-specific styles
5. Layout-specific styles

## 参考資料

- `app/assets/stylesheets/core/variables.css` - 全デザイントークンの定義
- `app/assets/stylesheets/components/` - コンポーネントスタイル
- `app/views/demo/ui_system.html.erb` - UIシステムのデモページ

## 更新履歴

- 2025-01-27: 初版作成

