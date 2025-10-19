# Docker Compose使い方ガイド

## 🎯 デフォルト設定

**デフォルトはDaemon版になりました！**

```bash
# デフォルト起動（daemon版）
docker compose up

# または
docker compose up web
```

## 📊 サービス一覧

| サービス | 説明 | ポート | daemon | 起動方法 |
|---------|------|--------|--------|---------|
| **web** | 開発環境（daemon版、デフォルト） | 3000 | ✅ 有効 | `docker compose up` |
| web-cli | 開発環境（CLI版、オプション） | 3001 | ❌ 無効 | `docker compose --profile cli up web-cli` |
| test | テスト環境 | - | - | `docker compose run --rm test` |
| selenium | Seleniumブラウザ | 4444, 7900 | - | 自動起動（testプロファイル） |

## 🚀 使い方

### デフォルト（Daemon版）

```bash
# 起動
docker compose up

# バックグラウンド起動
docker compose up -d

# ログ確認
docker compose logs -f

# 停止
docker compose down
```

**アクセス**: http://localhost:3000

**特徴**:
- ✅ agrr daemonが自動起動
- ✅ 2回目以降のagrr実行が高速（2.4s → 0.5s）
- ✅ 開発環境（development）
- ✅ ホットリロード有効
- ✅ volumeマウント有効

### CLI版（オプション）

daemon無しで動作確認したい場合：

```bash
# 起動
docker compose --profile cli up web-cli

# バックグラウンド起動
docker compose --profile cli up web-cli -d

# ログ確認
docker compose --profile cli logs web-cli -f
```

**アクセス**: http://localhost:3001

**特徴**:
- ❌ agrr daemonなし
- ✅ 開発環境（development）
- ✅ ホットリロード有効
- ✅ volumeマウント有効

### テスト実行

```bash
# テスト環境起動（バックグラウンド）
docker compose --profile test up -d

# テスト実行
docker compose run --rm test bundle exec rails test

# システムテスト
docker compose run --rm test bundle exec rails test:system

# 特定のテスト
docker compose run --rm test bundle exec rails test test/models/user_test.rb

# テスト環境停止
docker compose --profile test down
```

## 🔍 daemon動作確認

### コンテナ内でdaemon状態を確認

```bash
# デフォルト（web）でdaemon確認
docker compose exec web /app/lib/core/agrr daemon status

# 期待される出力
# ✓ Daemon is running (PID: xxx)
```

### ログで確認

```bash
# 起動ログを確認
docker compose logs web | grep daemon

# 期待される出力
# AGRR Daemon Mode: true
# Starting agrr daemon...
# ✓ agrr daemon started (PID: xxx)
```

## 📝 環境変数

開発環境で設定されている環境変数：

```yaml
# docker-compose.yml (webサービス)
environment:
  - RAILS_ENV=development
  - DATABASE_URL=sqlite3:storage/development.sqlite3
  - PREVENT_TEST_IN_DEV=true
  - USE_AGRR_DAEMON=true  # Daemon有効
```

## 🔄 切り替え方法

### Daemon版 → CLI版

```bash
# 現在のdaemon版を停止
docker compose down

# CLI版を起動
docker compose --profile cli up web-cli
```

### CLI版 → Daemon版

```bash
# CLI版を停止
docker compose --profile cli down

# デフォルト（daemon版）を起動
docker compose up
```

## 💡 Tips

### 両方同時に起動（ポートが異なるため可能）

```bash
# daemon版（3000）とCLI版（3001）を同時起動
docker compose up web &
docker compose --profile cli up web-cli

# またはバックグラウンド
docker compose up web -d
docker compose --profile cli up web-cli -d
```

### 再ビルド

```bash
# イメージを再ビルドして起動
docker compose up --build

# または
docker compose build web
docker compose up web
```

### ログ確認のコツ

```bash
# 最新50行
docker compose logs web --tail 50

# リアルタイムフォロー
docker compose logs web -f

# daemonに関するログのみ
docker compose logs web | grep daemon

# エラーのみ
docker compose logs web 2>&1 | grep -i error
```

## 🐛 トラブルシューティング

### daemon起動失敗

**症状**: ログに「agrr binary not found」

**対処**:
```bash
# agrr binaryをビルド
cd lib/core/agrr_core
./build_standalone.sh --onefile
cp dist/agrr ../agrr
cd ../../..

# コンテナ再起動
docker compose restart web
```

### ポート競合

**症状**: `port is already allocated`

**対処**:
```bash
# 既存のコンテナを停止
docker compose down

# または特定のポートを使っているコンテナを確認
docker ps | grep 3000

# 強制削除
docker rm -f $(docker ps -q --filter "publish=3000")
```

### volumeが古い

**症状**: コードを変更してもdaemonが古いまま

**対処**:
```bash
# コンテナ再起動（volumeマウントなので即座に反映）
docker compose restart web

# または完全に再作成
docker compose down
docker compose up --build
```

## 📚 関連ドキュメント

- [README.md](README.md) - プロジェクト概要
- [README_DEPLOYMENT.md](README_DEPLOYMENT.md) - デプロイ方法
- [ENV_CONTROL_SUMMARY.md](ENV_CONTROL_SUMMARY.md) - 環境変数制御

## ✅ まとめ

- **デフォルトはdaemon版** - `docker compose up`で起動
- **CLI版はオプション** - `docker compose --profile cli up web-cli`で起動
- **どちらも開発環境** - RAILS_ENV=development
- **ポート**: daemon版（3000）、CLI版（3001）

デフォルトでdaemon版が使えるようになりました！

