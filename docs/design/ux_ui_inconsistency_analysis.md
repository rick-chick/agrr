# UX/UI統一感阻害要素の洗い出し

## 概要
本ドキュメントは、AGRRアプリケーション内で統一感のあるUX/UIを阻害している画面・要素を洗い出したものです。

## 1. レイアウト構造の不統一

### 1.1 レイアウトファイルの不統一
- **問題**: レイアウトファイルが複数存在し、それぞれ異なる構造を持っている
- **影響範囲**: 全画面

| レイアウト | コンテナクラス | フッター | 特徴 |
|-----------|-------------|---------|------|
| `application.html.erb` | `main.container` | あり | 標準レイアウト |
| `public.html.erb` | `main.container` | あり | 公開プラン用 |
| `auth.html.erb` | `main.container` | なし | 認証画面用 |
| `admin.html.erb` | `div.admin-container` | なし | 管理画面用 |
| `home/index.html.erb` | **独自HTML構造** | あり | **レイアウトファイル未使用** |

**問題点**:
- `home/index.html.erb`がレイアウトファイルを使わず、独自のHTML構造を持っている
- `admin.html.erb`だけ`admin-container`を使用（他のレイアウトは`container`）

### 1.2 スタイルシート読み込み方法の不統一
- **問題**: スタイルシートの読み込み方法が統一されていない
- **影響範囲**: 全画面

| ファイル | 読み込み方法 |
|---------|------------|
| `application.html.erb` | `render_core_stylesheets`等のヘルパー使用 |
| `public.html.erb` | `render_core_stylesheets`等のヘルパー使用 |
| `auth.html.erb` | `render_core_stylesheets`等のヘルパー使用 |
| `admin.html.erb` | `render_core_stylesheets`等のヘルパー使用 |
| `home/index.html.erb` | **直接`stylesheet_link_tag`を使用** |

**問題点**:
- `home/index.html.erb`だけ直接`stylesheet_link_tag`を使用しており、他の画面と異なる

## 2. ボタンスタイルの不統一

### 2.1 ボタンクラスの種類
- **問題**: 複数のボタンスタイルが混在している
- **影響範囲**: 全画面

| ボタンクラス | 使用箇所 | 定義場所 | 問題点 |
|------------|---------|---------|--------|
| `btn btn-primary` | 標準画面（farms, crops等） | `components/buttons.css` | 標準 |
| `btn btn-secondary` | 標準画面 | `components/buttons.css` | 標準 |
| `btn btn-success` | 標準画面 | `components/buttons.css` | 標準 |
| `btn btn-error` | 標準画面 | `components/buttons.css` | 標準 |
| `btn btn-info` | 標準画面 | `components/buttons.css` | 標準 |
| `btn-plans-primary` | Plans関連画面 | `features/plans.css` | **Plans専用** |
| `btn-plans-secondary` | Plans関連画面 | `features/plans.css` | **Plans専用** |
| `hero-button` | ホームページ | `features/home.css` | **ホーム専用** |
| `btn-white` | 公開プラン結果画面等 | `features/public-plans.css` | **非標準** |
| `back-button` | 公開プラン画面 | `features/public-plans.css` | **非標準** |

**問題点**:
- Plans関連画面で`btn-plans-*`を使用（標準の`btn-*`と重複）
- ホームページで`hero-button`を使用（標準ボタンと異なる）
- `btn-white`が定義されているが、標準ボタンシステムに含まれていない
- `back-button`が個別に定義されている

### 2.2 ボタン使用例の不統一

**標準的な使用例** (`farms/index.html.erb`):
```erb
<%= link_to t('.new_farm'), new_farm_path, class: "btn btn-success" %>
```

**Plans画面での使用例** (`plans/index.html.erb`):
```erb
<%= link_to new_plan_path, class: "btn-plans-primary" do %>
```

**ホームページでの使用例** (`home/index.html.erb`):
```erb
<%= link_to t('.hero.cta_button'), public_plans_path, class: "hero-button" %>
```

**公開プラン結果画面での使用例** (`public_plans/results.html.erb`):
```erb
<%= link_to plans_path, class: "btn-white" do %>
```

## 3. ページヘッダーの不統一

### 3.1 ヘッダークラスの種類
- **問題**: 複数のページヘッダースタイルが混在している
- **影響範囲**: 全画面

| ヘッダークラス | タイトルクラス | 使用箇所 | 定義場所 |
|--------------|--------------|---------|---------|
| `page-header` | `page-title` | farms, crops, pages等 | `features/fields-crops.css` |
| `plans-header` | `plans-header-title` | Plans関連画面 | `features/plans.css` |
| `gantt-header` | `gantt-title` | ガントチャート画面 | `features/plans.css` |
| `content-card-header` | `content-card-header-title` | Plans詳細画面 | `features/plans.css` |
| `compact-header-card` | - | 公開プラン画面 | `features/public-plans.css` |

**問題点**:
- 標準の`page-header`と`page-title`があるが、Plans関連画面では独自のヘッダーを使用
- ガントチャート画面でさらに別のヘッダーを使用
- 公開プラン画面で`compact-header-card`を使用

### 3.2 ヘッダー使用例の不統一

**標準的な使用例** (`farms/index.html.erb`):
```erb
<div class="page-header">
  <h1 class="page-title"><%= t('.title') %></h1>
  <%= link_to t('.new_farm'), new_farm_path, class: "btn btn-success" %>
</div>
```

**Plans画面での使用例** (`plans/index.html.erb`):
```erb
<div class="plans-header">
  <div class="plans-header-main">
    <div>
      <h1 class="plans-header-title">
        <%= t('plans.index.title') %>
      </h1>
      <p class="plans-header-subtitle">
        <%= t('plans.index.subtitle') %>
      </p>
    </div>
    <div>
      <%= link_to new_plan_path, class: "btn-plans-primary" do %>
```

**静的ページでの使用例** (`pages/about.html.erb`):
```erb
<h1 class="page-header"><%= t('.heading') %></h1>
```

**問題点**:
- `pages/about.html.erb`では`page-header`が`h1`タグに直接適用されている（他の画面では`div`に適用）

## 4. コンテナの不統一

### 4.1 コンテナクラスの種類
- **問題**: 複数のコンテナクラスが混在している
- **影響範囲**: 全画面

| コンテナクラス | 使用箇所 | 定義場所 | 問題点 |
|--------------|---------|---------|--------|
| `container` | 標準レイアウト | `application.css`, `utilities.css` | 標準（重複定義あり） |
| `admin-container` | 管理画面 | `layouts/admin.css` | **管理画面専用** |
| `login-container` | 認証画面 | `auth.css` | **認証画面専用** |
| `plans-wrapper` + `plans-container` | Plans関連画面 | `components/layouts.css` | **Plans専用** |
| `page-content-container` | 静的ページ | `features/pages.css` | **静的ページ専用** |

**問題点**:
- `container`が`application.css`と`utilities.css`の両方で定義されている（重複）
- 各機能ごとに独自のコンテナクラスが定義されている

## 5. フォームスタイルの不統一

### 5.1 フォームコンテナの不統一
- **問題**: フォームのコンテナクラスが統一されていない
- **影響範囲**: フォームを含む画面

| フォームコンテナ | 使用箇所 | 定義場所 |
|----------------|---------|---------|
| `form-card` | 標準フォーム | `components/forms.css` |
| なし（直接フォーム） | 一部のフォーム | - |

**問題点**:
- 一部のフォームで`form-card`が使用されていない

## 6. カードコンポーネントの不統一

### 6.1 カードクラスの種類
- **問題**: 複数のカードスタイルが混在している
- **影響範囲**: カードを使用する画面

| カードクラス | 使用箇所 | 定義場所 |
|------------|---------|---------|
| `field-card` | Fields画面 | `components/cards.css` |
| `crop-card` | Crops画面 | `components/cards.css` |
| `farm-card` | Farms画面 | `components/farm-cards.css` |
| `feature-card` | ホームページ、Aboutページ | `features/home.css`, `features/pages.css` |
| `content-card` | Plans詳細画面 | `features/plans.css` |

**問題点**:
- `feature-card`が`features/home.css`と`features/pages.css`の両方で定義されている（重複の可能性）
- 各機能ごとに独自のカードクラスが定義されている

## 7. 空状態（Empty State）の不統一

### 7.1 空状態クラスの種類
- **問題**: 空状態のスタイルが統一されていない
- **影響範囲**: リスト表示画面

| 空状態クラス | 使用箇所 | 定義場所 |
|------------|---------|---------|
| `empty-state` | farms, crops等 | `features/fields-crops.css` |
| `plans-empty` | Plans画面 | `features/plans.css` |

**問題点**:
- 標準の`empty-state`があるが、Plans画面では独自の`plans-empty`を使用

## 8. セクションタイトルの不統一

### 8.1 セクションタイトルクラスの種類
- **問題**: セクションタイトルのスタイルが統一されていない
- **影響範囲**: 複数セクションを持つ画面

| セクションタイトルクラス | 使用箇所 | 定義場所 |
|------------------------|---------|---------|
| `section-title` | ホームページ | `features/home.css` |
| `section-header` | farms画面 | `features/fields-crops.css` |
| `page-section-title` | 静的ページ | `features/pages.css` |
| `gantt-title` | ガントチャート画面 | `features/plans.css` |

**問題点**:
- 複数のセクションタイトルクラスが存在し、用途が重複している

## 9. CSS定義の重複

### 9.1 重複定義の一覧
- **問題**: 同じクラスが複数のファイルで定義されている
- **影響範囲**: 全画面

| クラス名 | 定義場所 | 問題点 |
|---------|---------|--------|
| `container` | `application.css`, `utilities.css` | **重複定義** |
| `alert` | `application.css`, `utilities.css`, `layouts/admin.css` | **重複定義** |
| `feature-card` | `features/home.css`, `features/pages.css` | **重複定義の可能性** |

## 10. 推奨される統一化方針

### 10.1 優先度: 高
1. **レイアウト構造の統一**
   - `home/index.html.erb`をレイアウトファイルを使用するように修正
   - `admin-container`を`container`に統一するか、明確な理由を文書化

2. **ボタンスタイルの統一**
   - `btn-plans-*`を標準の`btn-*`に統一
   - `hero-button`を標準ボタンシステムに統合
   - `btn-white`を標準ボタンシステムに追加するか削除

3. **ページヘッダーの統一**
   - `plans-header`を標準の`page-header`に統一
   - `gantt-header`を標準の`page-header`に統一
   - `pages/about.html.erb`の`page-header`使用を修正

### 10.2 優先度: 中
4. **コンテナの統一**
   - `container`の重複定義を解消
   - 各機能専用コンテナの必要性を検討し、可能な限り`container`に統一

5. **カードコンポーネントの統一**
   - `feature-card`の重複定義を解消
   - 可能な限り標準のカードコンポーネントを使用

6. **空状態の統一**
   - `plans-empty`を標準の`empty-state`に統一

### 10.3 優先度: 低
7. **セクションタイトルの統一**
   - セクションタイトルクラスを1つに統一

8. **CSS定義の重複解消**
   - 重複定義を解消し、1つのファイルに集約

## 11. 影響範囲の大きい変更

以下の変更は影響範囲が大きいため、慎重に検討が必要です：

1. **Plans関連画面のボタン・ヘッダー統一**
   - `btn-plans-*` → `btn-*`への変更
   - `plans-header` → `page-header`への変更
   - 影響範囲: Plans関連の全画面

2. **ホームページのレイアウト統一**
   - レイアウトファイルを使用するように変更
   - `hero-button` → 標準ボタンへの変更
   - 影響範囲: ホームページ全体

3. **管理画面のコンテナ統一**
   - `admin-container` → `container`への変更
   - 影響範囲: 管理画面全体

## 12. 次のステップ

1. 優先度の高い項目から順に統一化を実施
2. 各変更前に影響範囲を確認し、テストを実施
3. 統一化の進捗をこのドキュメントで追跡
4. 統一化完了後、このドキュメントを更新

