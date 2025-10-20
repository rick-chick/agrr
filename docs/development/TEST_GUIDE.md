# テストガイド

このドキュメントでは、Rails 8アプリケーションのテスト方法について説明します。

## 📋 目次

- [テスト環境](#テスト環境)
- [ローカル環境でのテスト実行](#ローカル環境でのテスト実行)
- [Docker環境でのテスト実行](#docker環境でのテスト実行)
- [テストの書き方](#テストの書き方)
- [テストのベストプラクティス](#テストのベストプラクティス)
- [CI/CD統合](#cicd統合)
- [カバレッジ測定](#カバレッジ測定)
- [デバッグ](#デバッグ)
- [トラブルシューティング](#トラブルシューティング)
- [参考リソース](#参考リソース)
- [次のステップ](#次のステップ)

## 📋 テスト環境

このアプリケーションは、Rails公式推奨のMinitestフレームワークを使用しています。

### テストの種類

1. **ユニットテスト（Unit Tests）** - モデルやヘルパーのテスト
2. **コントローラーテスト（Controller Tests）** - APIエンドポイントのテスト
3. **統合テスト（Integration Tests）** - ルーティングやエンドツーエンドのフロー
4. **システムテスト（System Tests）** - ブラウザベースのE2Eテスト

## 🚀 ローカル環境でのテスト実行

### 前提条件

- Ruby 3.3.9
- SQLite 3.8.0以上
- （システムテスト用）Chrome/Chromium + ChromeDriver

## 🔧 推奨開発環境

### Method 1: GitHub Codespaces ⭐ (最推奨)

```bash
# GitHubリポジトリで:
Code → Codespaces → Create codespace on main

# 自動的に全てセットアップされます！
# ターミナルで即座に実行:
bundle exec rails test
```

### Method 2: Docker Compose

```bash
# テスト実行（推奨）- 専用のtestサービスを使用
docker compose run --rm test bundle exec rails test
```

## ⚙️ セットアップ

```bash
# 依存関係のインストール
bundle install

# テスト用データベースのセットアップ（Docker環境）
# 注: testサービスのentrypointで自動実行されるため、通常は不要
docker compose run --rm test bundle exec rails db:prepare
```

## 🧪 テストの実行

#### 全テストを実行

```bash
# Docker Compose（推奨）- 専用のtestサービスを使用
docker compose run --rm test bundle exec rails test
```

### 特定のテストを実行

```bash
# 特定のテストファイル
docker compose run --rm test bundle exec rails test test/controllers/api/v1/base_controller_test.rb

# 特定のテストケース
docker compose run --rm test bundle exec rails test test/controllers/api/v1/base_controller_test.rb:5
```

#### カテゴリ別にテストを実行

```bash
# コントローラーテストのみ
docker compose run --rm test bundle exec rails test:controllers

# モデルテストのみ
docker compose run --rm test bundle exec rails test:models

# 統合テストのみ
docker compose run --rm test bundle exec rails test:integration

# システムテストのみ
docker compose run --rm test bundle exec rails test:system
```

### テストオプション

```bash
# 詳細な出力
docker compose run --rm test bundle exec rails test -v

# 失敗したテストのみ再実行
docker compose run --rm test bundle exec rails test --fail-fast

# 並列実行（デフォルトで有効）
docker compose run --rm test bundle exec rails test

# 並列実行を無効化
docker compose run --rm test bundle exec rails test -j 1
```

## 🐳 Docker環境でのテスト実行

### 前提条件

- Docker
- Docker Compose

### セットアップと実行

```bash
# Dockerイメージをビルド
docker compose build

# テストサービスを起動（バックグラウンド）
docker compose --profile test up -d

# テスト実行（推奨）
docker compose run --rm test bundle exec rails test

# テスト環境を停止
docker compose --profile test down
```

### Dockerコンテナ内でインタラクティブに実行

```bash
# testコンテナに入る
docker compose exec test bash

# コンテナ内でテスト実行
bundle exec rails test

# 終了
exit
```

## 📝 テストの書き方

### テストの書き方の例

```ruby
# コントローラーテスト
class Api::V1::BaseControllerTest < ActionDispatch::IntegrationTest
  test "health check endpoint" do
    get api_v1_health_url
    assert_response :success
  end
end

# モデルテスト
class UserTest < ActiveSupport::TestCase
  test "validates email presence" do
    user = User.new
    assert_not user.save
  end
end

# システムテスト
class HomePageTest < ApplicationSystemTestCase
  test "home page loads" do
    visit root_url
    assert_selector "h1"
  end
end
```

## 🎯 テストのベストプラクティス

### 基本的なポイント

- **1つのテストに1つのアサーション**を心がける
- **setup**でテストデータを準備する
- **fixture**を使ってテストデータを管理する
- **assert_response**でHTTPステータスを確認する
- **assert_difference**でデータベースの変更を確認する

```ruby
# 良い例
class ItemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @item = items(:one)
  end
  
  test "creates item" do
    assert_difference("Item.count") do
      post items_url, params: { item: { name: "Test" } }
    end
    assert_response :created
  end
end
```

## 🔧 CI/CD統合

GitHub Actionsでテストが自動実行されます。

```bash
# ローカルでCIをシミュレート
CI=true bundle exec rails test
```

## 📊 カバレッジ測定

SimpleCovを使用してテストカバレッジを測定できます。

```bash
# カバレッジ付きでテスト実行
COVERAGE=true bundle exec rails test
```

## 🐛 デバッグ

```ruby
# テスト内でブレークポイント
test "debug example" do
  binding.pry  # ここで実行が止まる
  get api_v1_health_url
end
```

```bash
# 詳細なログ出力
VERBOSE=true bundle exec rails test
```

## 🔍 トラブルシューティング

### データベース関連のエラー

```bash
# テストデータベースをリセット
RAILS_ENV=test bundle exec rails db:reset

# マイグレーションのみ実行
RAILS_ENV=test bundle exec rails db:migrate
```

### 並列実行でのエラー

```bash
# 並列実行を無効化
bundle exec rails test -j 1
```

### システムテストのエラー

ChromeDriverが必要です。OSに応じてインストールしてください。

### Docker環境でのエラー

```bash
# コンテナをクリーンアップ
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

- 既存のコントローラーにテストを追加
- モデルバリデーションのテストを作成
- Active Storageのテストを追加





