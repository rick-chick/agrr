# UI/UX統一性ガイドライン

## 📋 概要

このドキュメントは、AGRRアプリケーション全体で一貫したUI/UXを維持するためのガイドラインです。デザインシステムの統一的な使用を促進し、ユーザー体験の一貫性を確保します。

## 🎯 現状の問題点

### 1. レイアウトファイル間のCSS読み込み順序の不一致

#### 問題
- `application.html.erb`: 完全なCSS読み込み順序が定義されている
- `public.html.erb`: 一部のCSSが欠けている（`components/cards`, `components/layouts`など）
- `admin.html.erb`: 一部のCSSが欠けている
- `auth.html.erb`: 最小限のCSSのみ

#### 影響
- レイアウト間でスタイルの一貫性が失われる可能性
- コンポーネントが正しく表示されない可能性

### 2. アラートメッセージのクラス名の不一致

#### 問題
- `application.html.erb`, `public.html.erb`: `alert alert-danger` を使用
- `admin.html.erb`: `alert alert-error` を使用
- `utilities.css`では両方サポートされているが、統一されていない

#### 推奨
- **統一クラス名**: `alert alert-danger` を使用（Bootstrap互換性のため）

### 3. ボタンクラスの使用の不一致

#### 問題
- `btn btn-primary` と `btn-plans-primary` が混在
- `btn-secondary` と `btn-plans-secondary` が混在
- 一部のビューで `btn-gradient` などの非標準クラスが使用されている

#### 推奨
- **標準ボタン**: `btn btn-primary`, `btn btn-secondary` を使用
- **Plans専用ボタン**: `btn-plans-primary`, `btn-plans-secondary` は既存コードとの互換性のために残すが、新規実装では使用しない

### 4. コンテナクラスの使用の不一致

#### 問題
- `application.html.erb`, `public.html.erb`: `main.container` を使用
- `admin.html.erb`: `div.admin-container` を使用
- `pages/*.html.erb`: インラインスタイル付きの `div.container` を使用

#### 推奨
- **標準コンテナ**: `main.container` または `div.container` を使用
- **インラインスタイル**: 使用を避け、CSSクラスで対応

### 5. インラインスタイルの使用

#### 問題
- `pages/contact.html.erb`, `pages/privacy.html.erb`, `pages/terms.html.erb`, `pages/about.html.erb` でインラインスタイルを使用

#### 推奨
- インラインスタイルを削除し、CSSクラスで対応

## 📐 統一ガイドライン

### CSS読み込み順序（標準）

すべてのレイアウトファイルで以下の順序を守ること：

```erb
<!-- Bundled CSS (Leaflet など npm パッケージ) -->
<%= stylesheet_link_tag "application", "data-turbo-track": "reload" %>

<!-- Core Design System - 必ず最初に読み込む -->
<%= stylesheet_link_tag "core/variables", "data-turbo-track": "reload" %>
<%= stylesheet_link_tag "core/reset", "data-turbo-track": "reload" %>

<!-- Utility CSS classes -->
<%= stylesheet_link_tag "utilities", "data-turbo-track": "reload" %>

<!-- Components -->
<%= stylesheet_link_tag "components/buttons", "data-turbo-track": "reload" %>
<%= stylesheet_link_tag "components/forms", "data-turbo-track": "reload" %>
<%= stylesheet_link_tag "components/navbar", "data-turbo-track": "reload" %>
<%= stylesheet_link_tag "components/cards", "data-turbo-track": "reload" %>
<%= stylesheet_link_tag "components/layouts", "data-turbo-track": "reload" %>
<%= stylesheet_link_tag "components/footer", "data-turbo-track": "reload" %>
<%= stylesheet_link_tag "components/crop_selection", "data-turbo-track": "reload" %>
<%= stylesheet_link_tag "components/farm-cards", "data-turbo-track": "reload" %>
<%= stylesheet_link_tag "components/undo_toast", "data-turbo-track": "reload" %>

<!-- Feature-specific styles -->
<!-- 必要に応じて追加 -->
```

### アラートメッセージ

#### 標準パターン
```erb
<% if flash[:notice] %>
  <div class="alert alert-success" role="status" aria-live="polite">
    <%= flash[:notice] %>
  </div>
<% end %>

<% if flash[:alert] %>
  <div class="alert alert-danger" role="alert" aria-live="assertive">
    <%= flash[:alert] %>
  </div>
<% end %>
```

#### 使用禁止
- `alert alert-error` → `alert alert-danger` を使用

### ボタンクラス

#### 標準ボタン（推奨）
```erb
<!-- プライマリアクション -->
<%= button_to "保存", path, class: "btn btn-primary" %>
<%= link_to "保存", path, class: "btn btn-primary" %>

<!-- セカンダリアクション -->
<%= button_to "キャンセル", path, class: "btn btn-secondary" %>
<%= link_to "キャンセル", path, class: "btn btn-secondary" %>

<!-- 削除アクション -->
<%= button_to "削除", path, method: :delete, class: "btn btn-error", data: { turbo_confirm: "削除しますか？" } %>

<!-- 成功アクション -->
<%= button_to "承認", path, class: "btn btn-success" %>

<!-- 警告アクション -->
<%= button_to "警告", path, class: "btn btn-warning" %>

<!-- 情報アクション -->
<%= button_to "詳細", path, class: "btn btn-info" %>

<!-- ゴーストボタン（控えめなアクション） -->
<%= button_to "閉じる", path, class: "btn btn-ghost" %>

<!-- リンクボタン（テキストのみ） -->
<%= link_to "詳細を見る", path, class: "btn btn-link" %>
```

#### ボタンサイズ
```erb
<!-- 小さいボタン -->
<%= button_to "保存", path, class: "btn btn-primary btn-sm" %>

<!-- 標準サイズ（デフォルト） -->
<%= button_to "保存", path, class: "btn btn-primary" %>

<!-- 大きいボタン -->
<%= button_to "保存", path, class: "btn btn-primary btn-lg" %>

<!-- 特大ボタン -->
<%= button_to "保存", path, class: "btn btn-primary btn-xl" %>
```

#### アイコンボタン
```erb
<!-- 標準アイコンボタン -->
<button type="button" class="btn-icon" title="編集">
  <svg>...</svg>
</button>

<!-- 小さいアイコンボタン -->
<button type="button" class="btn-icon btn-icon-sm" title="編集">
  <svg>...</svg>
</button>

<!-- 大きいアイコンボタン -->
<button type="button" class="btn-icon btn-icon-lg" title="編集">
  <svg>...</svg>
</button>
```

#### 使用禁止
- `btn-gradient` → `btn btn-primary` を使用
- インラインスタイルでのボタンスタイル指定

### コンテナクラス

#### 標準パターン
```erb
<main class="container">
  <%= yield %>
</main>
```

#### コンテナサイズバリエーション
```erb
<!-- 小さいコンテナ -->
<div class="container container-sm">...</div>

<!-- 標準コンテナ（デフォルト） -->
<div class="container">...</div>

<!-- 大きいコンテナ -->
<div class="container container-lg">...</div>
```

#### 使用禁止
- インラインスタイルでのコンテナスタイル指定
- `admin-container` などの独自クラス（標準の `container` を使用）

### フォーム

#### 標準パターン
```erb
<div class="form-card">
  <%= form_with model: @model do |f| %>
    <div class="form-group">
      <%= f.label :name, class: "form-label" %>
      <%= f.text_field :name, class: "form-control" %>
      <% if @model.errors[:name].any? %>
        <span class="error-message"><%= @model.errors[:name].first %></span>
      <% end %>
    </div>
    
    <div class="form-actions">
      <%= f.submit "保存", class: "btn btn-primary" %>
      <%= link_to "キャンセル", path, class: "btn btn-secondary" %>
    </div>
  <% end %>
</div>
```

### カードコンポーネント

#### 標準パターン
```erb
<div class="field-card">
  <h3 class="field-name">フィールド名</h3>
  <div class="field-actions">
    <%= link_to "編集", path, class: "btn btn-secondary btn-sm" %>
    <%= button_to "削除", path, method: :delete, class: "btn btn-error btn-sm" %>
  </div>
</div>
```

### 空状態（Empty State）

#### 標準パターン
```erb
<div class="empty-state">
  <div class="empty-state-icon">📭</div>
  <h3>データがありません</h3>
  <p>新しいデータを作成してください。</p>
  <%= link_to "作成", path, class: "btn btn-primary" %>
</div>
```

## 🔧 修正が必要なファイル

### 優先度: 高

1. **`app/views/layouts/admin.html.erb`**
   - `alert alert-error` → `alert alert-danger` に変更
   - CSS読み込み順序を統一

2. **`app/views/pages/*.html.erb`**
   - インラインスタイルを削除し、CSSクラスで対応

### 優先度: 中

3. **`app/views/layouts/public.html.erb`**
   - 不足しているCSSファイルを追加

4. **`app/views/layouts/auth.html.erb`**
   - 必要に応じてCSSファイルを追加

### 優先度: 低

5. **ボタンクラスの統一**
   - 既存の `btn-plans-primary` などは互換性のために残す
   - 新規実装では標準の `btn btn-primary` を使用

## 📝 チェックリスト

新しいビューを作成する際は、以下を確認してください：

- [ ] CSS読み込み順序が標準に従っているか
- [ ] アラートメッセージに `alert alert-danger` を使用しているか（`alert-error` ではない）
- [ ] ボタンに標準の `btn btn-*` クラスを使用しているか
- [ ] コンテナに `container` クラスを使用しているか（インラインスタイルではない）
- [ ] フォームに `form-card`, `form-group`, `form-control` クラスを使用しているか
- [ ] カードコンポーネントに標準のクラスを使用しているか
- [ ] インラインスタイルを使用していないか

## 🎨 デザイントークンの使用

すべてのスタイルは `core/variables.css` で定義されたデザイントークンを使用してください：

- カラー: `var(--color-primary)`, `var(--color-secondary)` など
- スペーシング: `var(--space-1)` から `var(--space-12)` まで
- タイポグラフィ: `var(--font-size-base)`, `var(--font-weight-semibold)` など
- ボーダー: `var(--border-width-1)`, `var(--radius-md)` など
- シャドウ: `var(--shadow-sm)`, `var(--shadow-md)` など

## 📚 参考資料

- [デザイントークン定義](app/assets/stylesheets/core/variables.css)
- [ボタンコンポーネント](app/assets/stylesheets/components/buttons.css)
- [フォームコンポーネント](app/assets/stylesheets/components/forms.css)
- [カードコンポーネント](app/assets/stylesheets/components/cards.css)

