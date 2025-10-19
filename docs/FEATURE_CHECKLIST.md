# 新機能実装チェックリスト

**このチェックリストは必ず守ること。「動いているはずです！」と言う前に、全項目を確認する。**

## 1. アセット（CSS/JavaScript）を追加した場合

### 1.1 ファイル配置の確認
- [ ] npmライブラリを使う → `app/javascript/` に配置
- [ ] カスタムスクリプト → `app/assets/javascripts/` に配置（Propshaft）
- [ ] カスタムCSS → `app/assets/stylesheets/` に配置

### 1.2 レイアウトファイルでの読み込み確認
**使用しているレイアウトファイルを確認する！**

コントローラーで `layout 'public'` などを指定している場合：
- [ ] 該当するレイアウトファイル（`app/views/layouts/public.html.erb` など）を編集
- [ ] `application.html.erb` ではなく、**実際に使われるレイアウト**を編集する

#### CSS読み込み
```erb
<!-- features/配下のCSSファイルの場合 -->
<%= stylesheet_link_tag "features/ファイル名", "data-turbo-track": "reload" %>
```

#### JavaScript読み込み（Propshaft）
ビュー側で `content_for` を使う：
```erb
<% content_for :javascripts do %>
  <%= javascript_include_tag "ファイル名", defer: true, "data-turbo-track": "reload" %>
<% end %>
```

レイアウト側で `yield` を確認：
```erb
<%= yield :javascripts %>
```

### 1.3 manifest.js の確認
`app/assets/config/manifest.js` に以下が含まれているか：
```javascript
//= link_tree ../javascripts
//= link_tree ../stylesheets
```

### 1.4 アセットのプリコンパイル確認
```bash
# Dockerコンテナ内で実行
docker compose exec web bin/rails assets:precompile

# ファイルが生成されているか確認
docker compose exec web ls -la public/assets/features/  # CSSの場合
docker compose exec web ls -la public/assets/*.js | grep ファイル名  # JSの場合
```

### 1.5 ブラウザでの実際の動作確認
- [ ] Dockerコンテナを再起動（必要に応じて）
- [ ] ブラウザのキャッシュをクリア（Ctrl+Shift+R）
- [ ] 開発者ツールのNetworkタブでアセットが読み込まれているか確認
- [ ] Consoleタブでエラーが出ていないか確認

## 2. ルート（routes.rb）を追加した場合

### 2.1 ルート名の確認
```bash
docker compose exec web bin/rails routes | grep コントローラー名
```

### 2.2 ビューでの使用確認
- [ ] `link_to` や `redirect_to` で正しいルート名を使っているか
- [ ] 例: `public_plans_results_path` ではなく `public_plans_result_path` など

## 3. コントローラー・ビューを追加した場合

### 3.1 レイアウトファイルの確認
コントローラーで指定しているレイアウトを確認：
```ruby
class PublicPlansController < ApplicationController
  layout 'public'  # ← これを確認！
end
```

- [ ] 使用しているレイアウトファイルが正しいか
- [ ] `application.html.erb` を使うのか、`public.html.erb` を使うのか

### 3.2 i18n（翻訳）の確認
- [ ] `config/locales/` に翻訳ファイルを追加したか
- [ ] `ja.yml`, `en.yml`, `hi.yml` の3ファイルを更新したか

## 4. データベースを変更した場合

### 4.1 マイグレーションの確認
```bash
docker compose exec web bin/rails db:migrate
docker compose exec web bin/rails db:migrate:status
```

### 4.2 スキーマの確認
```bash
docker compose exec web cat db/schema.rb | grep テーブル名
```

## 5. テストを追加した場合

### 5.1 テストの実行
```bash
# 単体テスト
docker compose exec web bin/rails test test/controllers/コントローラー名_test.rb

# システムテスト
docker compose exec web bin/rails test:system test/system/ファイル名_test.rb
```

### 5.2 テストカバレッジの確認
- [ ] 主要な機能にテストが書かれているか
- [ ] 異常系のテストも書かれているか

## 6. 最終確認（必須）

### 6.1 Dockerでの動作確認
```bash
# コンテナを再起動
docker compose restart web

# ログを確認
docker compose logs -f web
```

### 6.2 ブラウザでの動作確認
- [ ] 実際にブラウザでアクセスして動作するか
- [ ] JavaScriptのコンソールエラーがないか
- [ ] CSSが正しく適用されているか
- [ ] 想定通りの動作をするか

### 6.3 エラーログの確認
```bash
# Railsログ
docker compose exec web tail -f log/development.log

# Nginxログ（本番環境の場合）
docker compose exec nginx tail -f /var/log/nginx/error.log
```

---

## チェックリスト自動検証スクリプト

自動検証スクリプト `scripts/validate_feature.rb` を使用して、基本的なチェックを自動化できます：

```bash
docker compose exec web ruby scripts/validate_feature.rb --feature crop_palette
```

---

## 重要な原則

1. **fallbackを作って隠ぺいするより、エラーを上げること。そのエラーをつぶすこと。**
2. **「動いているはずです！」と言う前に、このチェックリストを全て確認する。**
3. **実装したら必ずDockerコンテナで動作確認する。**
4. **ブラウザの開発者ツールで実際に確認する。**
5. **テストを書いて、テストが通ることを確認する。**

---

## よくある間違い

### ❌ 間違い1: レイアウトファイルを間違える
```ruby
# コントローラーで layout 'public' を指定しているのに
# application.html.erb を編集してしまう
```

### ❌ 間違い2: ルート名を間違える
```ruby
# routes.rb では resource :result (単数形)
# ビューでは public_plans_results_path (複数形) を使ってしまう
```

### ❌ 間違い3: アセットの配置場所を間違える
```javascript
// カスタムスクリプトを app/javascript/ に置いてバンドルに含めてしまう
// → app/assets/javascripts/ に置くべき
```

### ❌ 間違い4: ブラウザキャッシュを考慮しない
```
// アセットを更新したのに、ブラウザキャッシュのせいで古いファイルが読み込まれている
// → Ctrl+Shift+R でハードリロード
```

---

## このチェックリストを守れば

- ✅ 「動いているはずです！」「動いてない」のやり取りがなくなる
- ✅ バグのない状態で提示できる
- ✅ ユーザーが疲れることがなくなる
- ✅ 開発効率が上がる

