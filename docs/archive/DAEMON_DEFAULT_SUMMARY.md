# デフォルトをDaemon版に変更 - 完了サマリー

## ✅ 変更内容

**デフォルトがDaemon版になりました！**

### Before（変更前）
```bash
docker compose up        # CLI版（daemon無し）
docker compose --profile daemon up web-daemon  # Daemon版
```

### After（変更後）
```bash
docker compose up        # Daemon版（デフォルト）✨
docker compose --profile cli up web-cli  # CLI版（オプション）
```

## 📊 サービス構成

| サービス | モード | ポート | デフォルト | 起動方法 |
|---------|--------|--------|-----------|---------|
| **web** | Daemon版 | 3000 | ✅ YES | `docker compose up` |
| web-cli | CLI版 | 3001 | ❌ NO | `docker compose --profile cli up web-cli` |

## 🚀 使い方

### デフォルト起動（Daemon版）

```bash
# 起動
docker compose up

# または明示的に
docker compose up web

# バックグラウンド
docker compose up -d
```

**アクセス**: http://localhost:3000

**ログ確認**:
```
=== Development mode with agrr daemon ===
AGRR Daemon Mode: true
Starting agrr daemon...
✓ Daemon started (PID: xxx)
✓ agrr daemon started (PID: xxx)
=> Booting Puma
* Listening on http://0.0.0.0:3000
```

### CLI版（オプション）

```bash
# CLI版を起動
docker compose --profile cli up web-cli
```

**アクセス**: http://localhost:3001

## 🔧 更新されたファイル

### docker-compose.yml
- `web` → Daemon版（デフォルト）
- `web-cli` → CLI版（profile: cli）

### Dockerfile（開発用）
- agrr binaryと_internalディレクトリをコピー
- /tmpのパーミッション設定

### scripts/docker-entrypoint-dev-daemon.sh
- ホスト側のagrr binary（`/app/lib/core/agrr`）を優先使用
- volumeマウント対応

## 📁 ファイル構成

```
開発環境（docker-compose.yml）:
├── web（デフォルト）        → Daemon版、ポート3000 ✅
└── web-cli（profile: cli） → CLI版、ポート3001

本番環境（GCP）:
└── gcp-deploy.sh          → USE_AGRR_DAEMON環境変数で制御
```

## ✨ メリット

1. **デフォルトで高速** - 普段の開発でdaemon効果を体感
2. **必要なときCLI版に切り替え** - profile指定で簡単
3. **本番と同じ構成** - 本番もdaemon版を使う場合、開発環境で事前検証可能

## 🎯 daemon動作確認

### コンテナ内で確認

```bash
# daemon状態を確認
docker compose exec web /app/lib/core/agrr daemon status

# 期待される出力
# ✓ Daemon is running (PID: xxx)
```

### 性能テスト

```bash
# コンテナ内で実行時間測定
docker compose exec web bash -c "time /app/lib/core/agrr crop --query tomato > /dev/null"

# 1回目: 約2.4s
# 2回目: 約0.5s（4.8倍高速！）
```

## 🔄 CLI版に戻す方法

デフォルトをCLI版に戻したい場合：

```bash
# docker-compose.ymlで以下を入れ替え
# web → entrypoint: ["/app/scripts/docker-entrypoint-dev.sh"]
# web → USE_AGRR_DAEMON=true を削除

# または
# webとweb-cliの定義を入れ替える
```

## 📚 関連ドキュメント

- [DOCKER_COMPOSE_GUIDE.md](DOCKER_COMPOSE_GUIDE.md) - 詳細な使い方
- [README_DEPLOYMENT.md](README_DEPLOYMENT.md) - デプロイ方法
- [ENV_CONTROL_SUMMARY.md](ENV_CONTROL_SUMMARY.md) - 環境変数制御

## ✅ まとめ

- **デフォルトはDaemon版** - `docker compose up`で起動
- **開発環境でもdaemon効果** - 2回目以降のagrr実行が高速
- **CLI版も使える** - `docker compose --profile cli up web-cli`
- **本番とスクリプトは別** - `./scripts/gcp-deploy.sh`（環境変数で制御）

デフォルトがDaemon版になり、普段の開発でagrrが高速に動作します！

