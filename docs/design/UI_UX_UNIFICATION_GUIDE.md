# UI/UX統一ガイドライン

## 概要

このドキュメントは、AGRRアプリケーション全体で一貫したUI/UXを維持するためのガイドラインです。デザインシステムの使用方法、コンポーネントの使い方、スタイルの適用方法などを定義しています。

## デザインシステムの構造

### 1. 読み込み順序（重要）

すべてのレイアウトファイルでは、以下の順序でスタイルシートを読み込む必要があります：

```
1. application.css (npmパッケージ: Leafletなど)
2. core/variables.css (デザイントークン)
3. core/reset.css (リセットCSS)
4. utilities.css (ユーティリティクラス)
5. components/*.css (共通コンポーネント)
6. features/*.css (機能固有のスタイル)
```

**実装方法**: ヘルパーメソッドを使用して統一

```erb
<!-- レイアウトファイルでの使用例 -->
<%= render_core_stylesheets %>
<%= render_utility_stylesheets %>
<%= render_component_stylesheets %>
<%= render_feature_stylesheets(features: ["features/your_feature"]) %>
```

### 2. デザイントークン（CSS変数）

すべての色、スペーシング、タイポグラフィは `core/variables.css` で定義されたCSS変数を使用します。

#### 色の使用

**❌ 悪い例**: ハードコードされた色
```css
.button {
  background-color: #2d5016;
  color: #ffffff;
}
```

**✅ 良い例**: CSS変数を使用
```css
.button {
  background-color: var(--color-primary);
  color: var(--text-inverse);
}
```

#### 利用可能な色変数

- **Primary**: `--color-primary`, `--color-primary-light`, `--color-primary-dark`
- **Secondary**: `--color-secondary`, `--color-secondary-light`, `--color-secondary-dark`
- **Functional**: `--color-success`, `--color-warning`, `--color-error`, `--color-info`
- **Neutral**: `--color-gray-50` から `--color-gray-900`
- **Background**: `--bg-body`, `--bg-card`, `--bg-elevated`
- **Text**: `--text-primary`, `--text-secondary`, `--text-tertiary`, `--text-inverse`

#### スペーシング

8pxベースのスペーシングシステムを使用：

- `--space-0`: 0
- `--space-1`: 4px (0.25rem)
- `--space-2`: 8px (0.5rem)
- `--space-3`: 12px (0.75rem)
- `--space-4`: 16px (1rem)
- `--space-5`: 24px (1.5rem)
- `--space-6`: 32px (2rem)
- `--space-8`: 48px (3rem)
- `--space-10`: 64px (4rem)
- `--space-12`: 96px (6rem)

**❌ 悪い例**:
```css
.card {
  padding: 20px;
  margin-bottom: 15px;
}
```

**✅ 良い例**:
```css
.card {
  padding: var(--space-5);
  margin-bottom: var(--space-4);
}
```

#### タイポグラフィ

- **Font Sizes**: `--font-size-xs` から `--font-size-6xl`
- **Font Weights**: `--font-weight-light` から `--font-weight-black`
- **Line Heights**: `--line-height-none` から `--line-height-loose`

#### ボーダーとシャドウ

- **Border Radius**: `--radius-sm` から `--radius-full`
- **Shadows**: `--shadow-xs` から `--shadow-2xl`
- **Border Widths**: `--border-width-0` から `--border-width-4`

## コンポーネントの使用

### 共通コンポーネント

再利用可能なコンポーネントは `app/views/shared/` に配置されています：

- `_navbar.html.erb`: ナビゲーションバー
- `_footer.html.erb`: フッター
- `_gantt_chart.html.erb`: ガントチャート
- `_crop_palette.html.erb`: 作物パレット
- `_meta_tags.html.erb`: メタタグ

### ボタンコンポーネント

ボタンは `components/buttons.css` で定義されたクラスを使用：

```erb
<!-- プライマリボタン -->
<%= button_to "保存", path, class: "btn btn-primary" %>

<!-- セカンダリボタン -->
<%= button_to "キャンセル", path, class: "btn btn-secondary" %>

<!-- 危険な操作 -->
<%= button_to "削除", path, class: "btn btn-danger" %>
```

### カードコンポーネント

カードは `components/cards.css` で定義されたクラスを使用：

```erb
<div class="card">
  <div class="card-header">
    <h3>タイトル</h3>
  </div>
  <div class="card-body">
    <!-- コンテンツ -->
  </div>
</div>
```

### フォームコンポーネント

フォーム要素は `components/forms.css` で定義されたクラスを使用：

```erb
<div class="form-group">
  <%= form.label :name, class: "form-label" %>
  <%= form.text_field :name, class: "form-control" %>
  <small class="form-text">ヘルプテキスト</small>
</div>
```

### アラートメッセージ

フラッシュメッセージは統一されたアラートクラスを使用：

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

利用可能なアラートタイプ：
- `alert-success` / `notice`: 成功メッセージ
- `alert-info`: 情報メッセージ
- `alert-warning`: 警告メッセージ
- `alert-danger` / `alert-error`: エラーメッセージ

## レイアウトの統一

### コンテナ

ページコンテンツは `.container` クラスでラップ：

```erb
<main class="container">
  <%= yield %>
</main>
```

利用可能なコンテナサイズ：
- `.container-sm`: 640px
- `.container-md`: 768px
- `.container-lg`: 1024px
- `.container`: 1280px (デフォルト)

### 空状態（Empty State）

データがない場合の表示は `.empty-state` クラスを使用：

```erb
<div class="empty-state">
  <div class="empty-state-icon">🌾</div>
  <h3>データがありません</h3>
  <p>新しいデータを追加してください</p>
  <%= link_to "追加", new_path, class: "btn btn-primary" %>
</div>
```

## ユーティリティクラス

### スペーシングユーティリティ

マージンとパディングのユーティリティクラス：

```erb
<div class="mt-4 mb-6">上マージン16px、下マージン32px</div>
<div class="pt-5 pb-3">上パディング24px、下パディング12px</div>
```

### テキストユーティリティ

```erb
<p class="text-center text-primary">中央揃え、プライマリ色</p>
<p class="text-sm text-secondary">小さいフォント、セカンダリ色</p>
```

### 表示ユーティリティ

```erb
<div class="d-flex justify-between align-center">Flexboxレイアウト</div>
<div class="d-none d-md-block">モバイルで非表示、デスクトップで表示</div>
```

## 機能固有のスタイル

機能固有のスタイルは `features/` ディレクトリに配置：

- `features/fields-crops.css`: フィールド・作物関連
- `features/plans.css`: 計画関連
- `features/gantt_chart.css`: ガントチャート
- `features/optimizing.css`: 最適化関連

**原則**: 機能固有のスタイルは、共通コンポーネントを拡張する形で実装します。

## レスポンシブデザイン

### ブレークポイント

CSS変数で定義されたブレークポイントを使用：

- `--breakpoint-sm`: 640px
- `--breakpoint-md`: 768px
- `--breakpoint-lg`: 1024px
- `--breakpoint-xl`: 1280px
- `--breakpoint-2xl`: 1536px

### メディアクエリの例

```css
@media (min-width: 768px) {
  .card {
    padding: var(--space-6);
  }
}
```

## JavaScriptの統一

### 共通JavaScript

共通のJavaScriptは `render_common_javascripts` ヘルパーで読み込み：

```erb
<%= render_common_javascripts(include_shared_systems: true) %>
```

含まれるJavaScript：
- `application.js`: メインアプリケーションJS
- `i18n_helper.js`: 国際化ヘルパー
- `svg_drag_utils.js`: SVGドラッグユーティリティ
- `shared/notification_system.js`: 通知システム
- `shared/dialog_system.js`: ダイアログシステム
- `shared/loading_system.js`: ローディングシステム

## チェックリスト

新しい機能を実装する際は、以下を確認：

- [ ] デザイントークン（CSS変数）を使用しているか
- [ ] ハードコードされた色やスペーシングがないか
- [ ] 共通コンポーネントを使用しているか
- [ ] レイアウトファイルで統一されたヘルパーメソッドを使用しているか
- [ ] レスポンシブデザインに対応しているか
- [ ] アクセシビリティ属性（`role`, `aria-live`など）を適切に使用しているか
- [ ] フラッシュメッセージに統一されたアラートクラスを使用しているか

## トラブルシューティング

### スタイルが適用されない

1. スタイルシートの読み込み順序を確認
2. CSS変数が正しく定義されているか確認
3. ブラウザの開発者ツールでスタイルの継承を確認

### 色が統一されていない

1. ハードコードされた色がないか検索: `grep -r "#[0-9a-fA-F]\{6\}" app/assets/stylesheets`
2. CSS変数に置き換える

### レイアウトが崩れる

1. コンテナクラスの使用を確認
2. スペーシングユーティリティの使用を確認
3. レスポンシブデザインのメディアクエリを確認

## 参考資料

- [デザイントークン定義](../app/assets/stylesheets/core/variables.css)
- [共通コンポーネント](../app/views/shared/)
- [ヘルパーメソッド](../app/helpers/application_helper.rb)

