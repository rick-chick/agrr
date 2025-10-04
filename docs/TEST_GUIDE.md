# テストガイド

このドキュメントでは、Rails 8アプリケーションのテスト方法について説明します。

## 📋 テスト環境

このアプリケーションは、Rails公式推奨のMinitestフレームワークを使用しています。

### テストの種類

1. **ユニットテスト（Unit Tests）** - モデルやヘルパーのテスト
2. **コントローラーテスト（Controller Tests）** - APIエンドポイントのテスト
3. **統合テスト（Integration Tests）** - ルーティングやエンドツーエンドのフロー
4. **システムテスト（System Tests）** - ブラウザベースのE2Eテスト

## 🚀 ローカル環境でのテスト実行

### 前提条件

- Ruby 3.3.6以上
- SQLite 3.8.0以上
- （システムテスト用）Chrome/Chromium + ChromeDriver

### セットアップ

```bash
# 依存関係のインストール
bundle install

# テスト用データベースのセットアップ
RAILS_ENV=test bin/rails db:create db:migrate
```

### テストの実行

#### 全テストを実行

```bash
# 方法1: Railsコマンド
bin/rails test

# 方法2: テストスクリプト使用（推奨）
chmod +x scripts/test-local.sh
./scripts/test-local.sh
```

#### 特定のテストを実行

```bash
# 特定のテストファイル
bin/rails test test/controllers/api/v1/base_controller_test.rb

# 特定のテストケース
bin/rails test test/controllers/api/v1/base_controller_test.rb:5

# スクリプトで実行
./scripts/test-local.sh test/controllers/api/v1/base_controller_test.rb
```

#### カテゴリ別にテストを実行

```bash
# コントローラーテストのみ
bin/rails test:controllers

# モデルテストのみ
bin/rails test:models

# 統合テストのみ
bin/rails test:integration

# システムテストのみ
bin/rails test:system
```

### テストオプション

```bash
# 詳細な出力
bin/rails test -v

# 失敗したテストのみ再実行
bin/rails test --fail-fast

# 並列実行（デフォルトで有効）
bin/rails test

# 並列実行を無効化
bin/rails test -j 1
```

## 🐳 Docker環境でのテスト実行

### 前提条件

- Docker
- Docker Compose

### セットアップと実行

```bash
# Dockerイメージをビルド
docker-compose build

# テストスクリプトで実行（推奨）
chmod +x scripts/test-docker.sh
./scripts/test-docker.sh

# または手動で実行
docker-compose up -d
docker-compose exec web bin/rails test
docker-compose down
```

### Docker専用のテスト実行

```bash
# docker-compose.test.ymlを使用
docker-compose -f docker-compose.test.yml run --rm test

# 特定のテストを実行
docker-compose -f docker-compose.test.yml run --rm test bin/rails test test/controllers/api/v1/base_controller_test.rb
```

### Dockerコンテナ内でインタラクティブに実行

```bash
# コンテナに入る
docker-compose exec web bash

# コンテナ内でテスト実行
bin/rails test

# 終了
exit
```

## 📝 テストの書き方

### コントローラーテストの例

```ruby
require "test_helper"

class Api::V1::BaseControllerTest < ActionDispatch::IntegrationTest
  test "health check endpoint returns success" do
    get api_v1_health_url
    assert_response :success
    
    json_response = JSON.parse(response.body)
    assert_equal "ok", json_response["status"]
  end
end
```

### モデルテストの例

```ruby
require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "should not save user without email" do
    user = User.new
    assert_not user.save, "Saved the user without an email"
  end
  
  test "should save user with valid attributes" do
    user = User.new(email: "test@example.com")
    assert user.save, "Failed to save valid user"
  end
end
```

### 統合テストの例

```ruby
require "test_helper"

class ApiFlowTest < ActionDispatch::IntegrationTest
  test "complete API flow" do
    # 1. Health check
    get api_v1_health_url
    assert_response :success
    
    # 2. Create resource
    post api_v1_items_url, params: { item: { name: "Test" } }
    assert_response :created
    
    # 3. Verify resource
    get api_v1_items_url
    assert_response :success
  end
end
```

### システムテストの例

```ruby
require "application_system_test_case"

class HomePageTest < ApplicationSystemTestCase
  test "visiting the home page" do
    visit root_url
    
    assert_selector "h1", text: "Welcome"
    assert_text "API is running"
  end
end
```

## 🎯 テストのベストプラクティス

### 1. テストの構成

```
test/
├── controllers/       # コントローラーテスト
├── models/           # モデルテスト
├── integration/      # 統合テスト
├── system/           # システムテスト
├── fixtures/         # テストデータ
└── test_helper.rb    # テスト設定
```

### 2. Fixture（フィクスチャ）の使用

```yaml
# test/fixtures/users.yml
one:
  email: user1@example.com
  name: User One

two:
  email: user2@example.com
  name: User Two
```

```ruby
# テスト内で使用
test "fixture user has correct email" do
  user = users(:one)
  assert_equal "user1@example.com", user.email
end
```

### 3. テストのDRY原則

```ruby
class Api::V1::ItemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @item = items(:one)
    @valid_params = { item: { name: "Test Item" } }
  end
  
  test "should create item" do
    assert_difference("Item.count") do
      post api_v1_items_url, params: @valid_params
    end
  end
end
```

### 4. アサーションの種類

```ruby
# 基本的なアサーション
assert true
assert_not false
assert_nil nil
assert_equal expected, actual
assert_match /pattern/, string

# レスポンスのアサーション
assert_response :success
assert_response :created
assert_response :not_found
assert_redirected_to root_path

# データベースのアサーション
assert_difference "Item.count", 1
assert_no_difference "Item.count"

# 例外のアサーション
assert_raises(ArgumentError) do
  # コード
end
```

## 🔧 CI/CD統合

### GitHub Actions

`.github/workflows/test.yml` が設定済みです。

```yaml
name: Test
on: [push, pull_request]
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: ruby/setup-ruby@v1
      - run: bundle install
      - run: bin/rails test
```

### ローカルでCIをシミュレート

```bash
# CI環境変数を設定してテスト実行
CI=true bin/rails test

# これにより eager_load が有効になり、本番環境に近い状態でテスト
```

## 📊 カバレッジ測定

### SimpleCov の追加（オプション）

```ruby
# Gemfileに追加
group :test do
  gem 'simplecov', require: false
end

# test/test_helper.rbの先頭に追加
require 'simplecov'
SimpleCov.start 'rails'

ENV["RAILS_ENV"] ||= "test"
# ... 残りのコード
```

```bash
# カバレッジ付きでテスト実行
COVERAGE=true bin/rails test

# カバレッジレポート確認
open coverage/index.html
```

## 🐛 デバッグ

### Pryの使用

```ruby
# テスト内でブレークポイント
test "debug example" do
  binding.pry  # ここで実行が止まる
  get api_v1_health_url
end
```

### テスト実行中のログ確認

```bash
# テストログを表示
tail -f log/test.log

# 詳細なログ出力
VERBOSE=true bin/rails test
```

## 🔍 トラブルシューティング

### データベース関連のエラー

```bash
# テストデータベースをリセット
RAILS_ENV=test bin/rails db:reset

# マイグレーションのみ実行
RAILS_ENV=test bin/rails db:migrate
```

### 並列実行でのエラー

```bash
# 並列実行を無効化
bin/rails test -j 1
```

### システムテストのエラー

```bash
# ChromeDriverのインストール
# macOS
brew install chromedriver

# Ubuntu
sudo apt-get install chromium-chromedriver

# Windows
# https://chromedriver.chromium.org/ からダウンロード
```

### Docker環境でのエラー

```bash
# コンテナとボリュームを完全にクリーンアップ
docker-compose down -v
docker-compose build --no-cache
docker-compose up
```

## 📚 参考リソース

- [Rails Testing Guide](https://guides.rubyonrails.org/testing.html)
- [Minitest Documentation](https://github.com/minitest/minitest)
- [Capybara](https://github.com/teamcapybara/capybara)
- [Rails 8 Release Notes](https://edgeguides.rubyonrails.org/8_0_release_notes.html)

## 🎓 次のステップ

1. 既存のコントローラーにテストを追加
2. モデルバリデーションのテストを作成
3. Active Storageのテストを追加
4. パフォーマンステストの実装
5. セキュリティテストの追加

---

質問やフィードバックがある場合は、GitHubのIssueで報告してください。





