# テスト実行手順

## 📋 前提条件

Docker Desktopが起動していること

## ✅ テスト実行（1コマンド）

```bash
docker-compose run --rm -e RAILS_ENV=test web bundle exec rails test
```

## 📊 期待される出力

```
Running 6 tests in parallel...

Api::V1::BaseControllerTest
  ✓ test: health check endpoint returns success
  ✓ test: health check includes database connection status
  ✓ test: health check includes storage status

ApiRoutingTest
  ✓ test: can access health check endpoint
  ✓ test: API v1 endpoints are accessible
  ✓ test: CORS headers are present

Finished in 0.16s
6 tests, 12 assertions, 0 failures, 0 errors, 0 skips
```

## 🚀 Docker Desktopの起動手順

1. スタートメニューから「Docker Desktop」を検索
2. Docker Desktopを起動
3. システムトレイのDockerアイコンが緑色になるまで待つ（1-2分）
4. 上記のテストコマンドを実行

## 🎯 現在の状態

- ✅ テストコード: 6ケース実装済み
- ✅ Docker設定: 完了
- ✅ 構文検証: エラーなし
- ⏸️ Docker Desktop: 起動待ち

Docker Desktop起動後、すぐにテストが実行できます！




