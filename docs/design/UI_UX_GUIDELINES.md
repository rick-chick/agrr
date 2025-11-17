# UI/UX統一ガイドライン

## 概要

AGRRアプリケーションのUI/UXを統一するためのガイドラインです。このガイドラインに従うことで、一貫性のあるユーザーインターフェースを実現できます。

## デザインシステム

### デザイントークン

すべてのスタイリングは `app/assets/stylesheets/core/variables.css` で定義されたデザイントークンを使用します。

**使用例:**
```css
/* ❌ 悪い例 - ハードコードされた値 */
.my-component {
  color: #2d5016;
  padding: 16px;
  border-radius: 8px;
}

/* ✅ 良い例 - デザイントークンを使用 */
.my-component {
  color: var(--color-primary);
  padding: var(--space-4);
  border-radius: var(--radius-md);
}
```

### カラーパレット

- **Primary**: `var(--color-primary)` - メインブランドカラー（農業テーマの緑）
- **Secondary**: `var(--color-secondary)` - アクセントカラー（AI/テクノロジー感の紫）
- **Success**: `var(--color-success)` - 成功状態
- **Warning**: `var(--color-warning)` - 警告状態
- **Error**: `var(--color-error)` - エラー状態
- **Info**: `var(--color-info)` - 情報表示

### スペーシング

8pxベースのスペーシングシステムを使用します。

- `var(--space-1)` = 4px
- `var(--space-2)` = 8px
- `var(--space-3)` = 12px
- `var(--space-4)` = 16px
- `var(--space-5)` = 24px
- `var(--space-6)` = 32px
- `var(--space-8)` = 48px

## インラインスタイルの禁止

インラインスタイル（`style="..."`）は使用せず、CSSクラスを使用します。

**使用例:**
```erb
<!-- ❌ 悪い例 -->
<div style="display: none;">非表示要素</div>
<div style="display: flex; gap: 8px;">フレックスコンテナ</div>

<!-- ✅ 良い例 -->
<div class="hidden">非表示要素</div>
<div class="flex gap-2">フレックスコンテナ</div>
```

### よく使われるユーティリティクラス

#### 表示制御
- `.hidden` - `display: none`
- `.visible` - `display: block`
- `.d-none`, `.d-block`, `.d-flex`, `.d-grid` - 表示タイプ

#### フレックスボックス
- `.flex` - `display: flex`
- `.flex-wrap`, `.flex-nowrap` - 折り返し
- `.gap-1`, `.gap-2`, `.gap-3`, `.gap-4` - 間隔
- `.justify-start`, `.justify-center`, `.justify-end`, `.justify-between` - 主軸配置
- `.align-start`, `.align-center`, `.align-end` - 交差軸配置

#### スペーシング
- `.mt-1` ~ `.mt-10` - マージントップ
- `.mb-1` ~ `.mb-10` - マージンボトム
- `.pt-1` ~ `.pt-10` - パディングトップ
- `.pb-1` ~ `.pb-10` - パディングボトム

#### テキスト
- `.text-left`, `.text-center`, `.text-right` - テキスト配置
- `.text-primary`, `.text-secondary`, `.text-success`, `.text-warning`, `.text-error`, `.text-info` - テキスト色
- `.text-xs`, `.text-sm`, `.text-base`, `.text-lg`, `.text-xl`, `.text-2xl` - フォントサイズ
- `.font-light`, `.font-normal`, `.font-medium`, `.font-semibold`, `.font-bold` - フォントウェイト

#### 幅
- `.w-full` - `width: 100%`
- `.w-auto` - `width: auto`
- `.max-w-sm` - `max-width: 400px`
- `.max-w-md` - `max-width: 600px`
- `.max-w-lg` - `max-width: 800px`

## コンポーネントシステム

### ボタン

統一されたボタンコンポーネントを使用します。

```erb
<!-- プライマリボタン -->
<button class="btn btn-primary">保存</button>

<!-- セカンダリボタン -->
<button class="btn btn-secondary">キャンセル</button>

<!-- 成功ボタン -->
<button class="btn btn-success">完了</button>

<!-- 危険ボタン -->
<button class="btn btn-danger">削除</button>
```

### フォーム

統一されたフォームコンポーネントを使用します。

```erb
<div class="form-group">
  <label class="form-label">ラベル</label>
  <input type="text" class="form-control" />
  <span class="form-text">ヘルプテキスト</span>
</div>
```

### カード

統一されたカードコンポーネントを使用します。

```erb
<div class="card">
  <div class="card-header">
    <h3 class="card-title">タイトル</h3>
  </div>
  <div class="card-body">
    コンテンツ
  </div>
</div>
```

### アラート

統一されたアラートコンポーネントを使用します。

```erb
<div class="alert alert-success">成功メッセージ</div>
<div class="alert alert-info">情報メッセージ</div>
<div class="alert alert-warning">警告メッセージ</div>
<div class="alert alert-danger">エラーメッセージ</div>
```

## JavaScriptでのスタイル操作

JavaScriptでスタイルを操作する場合は、クラスの追加/削除を使用します。

**使用例:**
```javascript
// ❌ 悪い例 - インラインスタイルを直接操作
element.style.display = 'none';
element.style.color = '#2d5016';

// ✅ 良い例 - クラスを追加/削除
element.classList.add('hidden');
element.classList.remove('hidden');
element.classList.toggle('text-primary');
```

## ファイル構造

### スタイルシートの読み込み順序

1. **Core Design System** (`core/variables.css`, `core/reset.css`)
2. **Utilities** (`utilities.css`)
3. **Components** (`components/*.css`)
4. **Features** (`features/*.css`)

この順序は `app/helpers/application_helper.rb` の `render_core_stylesheets`, `render_utility_stylesheets`, `render_component_stylesheets`, `render_feature_stylesheets` メソッドで管理されています。

## チェックリスト

新しいUIコンポーネントを作成する際は、以下を確認してください:

- [ ] デザイントークンを使用しているか
- [ ] インラインスタイルを使用していないか
- [ ] 既存のユーティリティクラスを活用しているか
- [ ] 既存のコンポーネントを再利用できるか
- [ ] レスポンシブデザインに対応しているか
- [ ] アクセシビリティを考慮しているか（ARIA属性など）

## 参考資料

- [デザイントークン定義](../app/assets/stylesheets/core/variables.css)
- [ユーティリティクラス](../app/assets/stylesheets/utilities.css)
- [コンポーネントスタイル](../app/assets/stylesheets/components/)

