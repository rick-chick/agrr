# JavaScriptのi18n対応ガイド

## 概要

AGRRプロジェクトでは、JavaScriptの文言も多言語対応（i18n）されています。  
すべてのユーザー向けメッセージ（alert、confirm、placeholderなど）は、翻訳ファイルを通じて管理されます。

## アーキテクチャ

### 1. 翻訳ファイル（YAMLで定義）

翻訳は`config/locales/`以下で管理：

```
config/locales/
├── ja.yml  (日本語)
└── en.yml  (英語)
```

JavaScript用の翻訳は`js:`セクションに定義：

```yaml
ja:
  js:
    gantt:
      optimization_failed: "最適化に失敗しました"
      confirm_delete_field: "%{field_name}を削除しますか？"
```

###

 2. ヘルパーメソッド（Railsビュー側）

`app/helpers/application_helper.rb`に定義された`js_i18n_data`と`js_i18n_templates`が、
翻訳をHTMLの`data`属性として埋め込みます：

```ruby
def js_i18n_data
  {
    js_gantt_optimization_failed: t('js.gantt.optimization_failed'),
    # ...
  }
end
```

### 3. レイアウトファイル（bodyタグに属性追加）

`app/views/layouts/application.html.erb`で`body`タグにdata属性として翻訳を埋め込み：

```erb
<body <%= raw (js_i18n_data.merge(js_i18n_templates)).map { |k, v| "data-#{k.to_s.dasherize}=\"#{ERB::Util.html_escape(v)}\"" }.join(' ') %>>
```

### 4. JavaScript側（i18nヘルパー関数）

`app/assets/javascripts/i18n_helper.js`で共通のヘルパー関数を提供：

```javascript
// 単純なメッセージ取得
getI18nMessage('jsGanttOptimizationFailed', 'Optimization failed')

// パラメータ付きメッセージ（テンプレート）
getI18nTemplate('jsGanttConfirmDeleteField', {field_name: '圃場A'}, 'Delete field?')
```

## 対応済みファイル

以下のJavaScriptファイルがi18n対応されています：

### 1. `custom_gantt_chart.js`
- alert/confirmメッセージ（14箇所）
- エラーメッセージ
- 削除確認ダイアログ

### 2. `crop_form.js`
- 入力フィールドのplaceholder（11箇所）
- フォームヒント

### 3. `crop_selection.js`
- 作物選択時のヒントメッセージ
- 上限到達時のメッセージ

### 4. `cultivation_results.js`
- グラフのラベル
- エラーメッセージ
- データ読み込みエラー

### 5. `plans_show.js`
- データ読み込みエラーメッセージ

## 新しい文言を追加する手順

### Step 1: 翻訳ファイルに追加

`config/locales/ja.yml`と`en.yml`に翻訳を追加：

```yaml
# ja.yml
js:
  my_feature:
    success_message: "成功しました！"
    confirm_delete: "%{item_name}を削除しますか？"

# en.yml
js:
  my_feature:
    success_message: "Success!"
    confirm_delete: "Delete %{item_name}?"
```

### Step 2: ヘルパーに登録

`app/helpers/application_helper.rb`にキーを追加：

```ruby
def js_i18n_data
  {
    # ... 既存のキー
    js_my_feature_success_message: t('js.my_feature.success_message'),
  }
end

def js_i18n_templates
  {
    # ... 既存のテンプレート
    js_my_feature_confirm_delete: t('js.my_feature.confirm_delete', item_name: '__ITEM_NAME__'),
  }
end
```

### Step 3: JavaScript側で使用

```javascript
// 単純なメッセージ
alert(getI18nMessage('jsMyFeatureSuccessMessage', 'Success!'));

// パラメータ付きメッセージ
const message = getI18nTemplate('jsMyFeatureConfirmDelete', 
  {item_name: itemName}, 
  `Delete ${itemName}?`
);
if (confirm(message)) {
  // 削除処理
}
```

## 命名規則

### data属性名の変換ルール

YAMLキー → data属性名への変換：
- `js.gantt.optimization_failed` → `jsGanttOptimizationFailed` (キャメルケース)
- HTMLでは `data-js-gantt-optimization-failed` となる

## デフォルトメッセージ（フォールバック）

`getI18nMessage()`と`getI18nTemplate()`の第2引数は、翻訳が見つからない場合のデフォルトメッセージです。
**必ず英語でデフォルトメッセージを設定してください。**

```javascript
// ✅ Good: デフォルトメッセージは英語
getI18nMessage('jsMyMessage', 'Loading data...')

// ❌ Bad: デフォルトメッセージが日本語
getI18nMessage('jsMyMessage', '読み込み中...')
```

## 動作確認

### ブラウザで確認

1. Dockerで開発環境を起動：
   ```bash
   docker compose up
   ```

2. ブラウザで http://localhost:3000 にアクセス

3. 開発者ツールのConsoleで確認：
   ```javascript
   // data属性の確認
   document.body.dataset.jsGanttOptimizationFailed
   // => "最適化に失敗しました" (日本語の場合)
   
   // ヘルパー関数の確認
   getI18nMessage('jsGanttOptimizationFailed', 'Optimization failed')
   // => "最適化に失敗しました"
   ```

4. 言語を切り替えて確認（NavbarのLanguageリンクから）

### 対象のダイアログを表示させる

各機能の以下の操作で、i18n化されたメッセージを確認できます：

- **custom_gantt_chart.js**: 
  - ガントチャートで作物をドラッグ＆ドロップ
  - 圃場や作物を削除しようとする
  
- **crop_form.js**: 
  - 作物の新規作成/編集画面を開く
  - 入力フィールドのplaceholderを確認
  
- **crop_selection.js**: 
  - 作物選択画面で5種類以上選択しようとする

## トラブルシューティング

### メッセージが日本語のまま変わらない

**原因**: data属性がbodyタグに設定されていない

**解決策**:
1. `app/helpers/application_helper.rb`にキーが追加されているか確認
2. `app/views/layouts/application.html.erb`（または使用中のレイアウト）にヘルパーが呼ばれているか確認
3. サーバーを再起動

### デフォルトメッセージが表示される

**原因**: data属性のキー名が間違っている

**解決策**:
1. ブラウザのConsoleで `document.body.dataset` を確認
2. キー名がキャメルケースになっているか確認（例: `jsGanttOptimizationFailed`）
3. YAMLのキーとヘルパーのキーが一致しているか確認

### パラメータが置換されない

**原因**: テンプレートの placeholder が間違っている

**解決策**:
1. YAMLで `%{parameter_name}` 形式で定義されているか確認
2. JavaScriptで `{parameter_name: value}` の形式で渡しているか確認
3. プレースホルダー名が一致しているか確認

## ベストプラクティス

1. **常にフォールバックを提供**: `getI18nMessage()`の第2引数は必須
2. **一貫した命名**: YAMLのキー構造は `js.feature_name.message_type` の形式
3. **テンプレートの活用**: 動的な値を含むメッセージは `%{placeholder}` を使用
4. **デフォルトは英語**: フォールバックメッセージは常に英語で記述

## 参考資料

- [Rails i18n Guide](https://guides.rubyonrails.org/i18n.html)
- `config/locales/ja.yml` - 日本語翻訳
- `config/locales/en.yml` - 英語翻訳
- `app/helpers/application_helper.js` - ヘルパーメソッド
- `app/assets/javascripts/i18n_helper.js` - JavaScript i18nヘルパー

