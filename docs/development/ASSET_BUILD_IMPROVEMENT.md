# アセットビルド問題の根本原因と対策

## 🔴 問題の症状

「`docker compose up` でアセットのコンパイル・配信が意識せずに確実に終わってほしい」
「開発が終わっているのか終わっていないのかが議論になる」

## 🔍 根本原因

### 1. **ビルドプロセスの可視性がゼロ**

**旧コード**:
```bash
echo "Building assets (JavaScript and CSS)..."
npm run build
```

**問題点**:
- `npm run build` の実行結果が表示されない
- 成功したのか失敗したのか不明
- どのファイルがビルドされたのか不明
- ビルド時間も不明

**影響**:
- 開発者が「ビルドが終わったか」を確認できない
- Railsサーバーが起動してもアセットが無い可能性がある
- デバッグが困難

### 2. **Watchモードの状態が完全に不明**

**旧コード**:
```bash
echo "Starting asset watcher for development..."
npm run build -- --watch &
WATCHER_PID=$!
```

**問題点**:
- バックグラウンドで起動するため、起動成功/失敗が分からない
- ファイル変更を検知しているのか不明
- エラーが発生してもログに出ない（標準出力に流れない）
- プロセスが死んでいても気づかない

**影響**:
- JavaScriptを修正しても反映されない
- 「Watchモードが動いているはず」という思い込みで時間を無駄にする

### 3. **ビルド失敗時もRailsサーバーが起動してしまう**

**旧コード**:
```bash
npm run build  # エラーが出ても続行
# ...
exec bundle exec rails server  # Railsサーバー起動
```

**問題点**:
- ビルドエラーがあっても無視して起動
- アセットが無い状態でRailsが動く
- 「画面が真っ白」「JavaScriptが動かない」という報告が増える

### 4. **ログ出力が不十分**

**旧コード**:
```bash
echo "AGRR Daemon Mode: ${USE_AGRR_DAEMON:-false}"
# ...（大量のログ）
echo "Starting asset watcher for development..."
```

**問題点**:
- 各ステップの区切りが不明確
- どこまで処理が進んでいるのか分からない
- エラーが埋もれる

## ✅ 対策の実装

### 1. **ビルドプロセスの可視化**

**新コード**:
```bash
echo "========================================="
echo "Building assets (JavaScript and CSS)..."
echo "========================================="
if npm run build; then
    echo "✓ Initial asset build completed successfully"
    echo ""
else
    echo "✗ Initial asset build FAILED"
    echo "Please check your JavaScript/CSS code for errors"
    exit 1
fi
```

**改善点**:
- ✅ `npm run build` の出力がそのまま表示される
- ✅ 成功/失敗が明確に表示される
- ✅ 失敗時はRailsサーバーを起動しない（`exit 1`）
- ✅ セクション区切りで視認性向上

**出力例（成功時）**:
```
=========================================
Building assets (JavaScript and CSS)...
=========================================

> build
> npx esbuild app/javascript/application.js ...

  app/assets/builds/application.js        1.2mb ⚠️
  app/assets/builds/application.css      12.8kb
  app/assets/builds/application.js.map    2.4mb
  app/assets/builds/application.css.map  24.2kb

⚡ Done in 162ms

✓ Initial asset build completed successfully
```

### 2. **Watchモードの状態確認**

**新コード**:
```bash
echo "========================================="
echo "Starting asset watcher for development..."
echo "========================================="
npm run build -- --watch > /tmp/esbuild-watch.log 2>&1 &
WATCHER_PID=$!

# Wait a moment and check if watcher started successfully
sleep 2
if kill -0 $WATCHER_PID 2>/dev/null; then
    echo "✓ Asset watcher is running (PID: $WATCHER_PID)"
    echo "  Logs: /tmp/esbuild-watch.log"
    echo "  Watching for file changes..."
    echo ""
else
    echo "✗ Asset watcher failed to start"
    cat /tmp/esbuild-watch.log
    exit 1
fi
```

**改善点**:
- ✅ Watchモードの出力を `/tmp/esbuild-watch.log` に保存
- ✅ 2秒後にプロセスの生存確認
- ✅ PIDを表示して追跡可能に
- ✅ 失敗時はログを表示して終了

**出力例（成功時）**:
```
=========================================
Starting asset watcher for development...
=========================================
✓ Asset watcher is running (PID: 123)
  Logs: /tmp/esbuild-watch.log
  Watching for file changes...
```

### 3. **Railsサーバー起動の明確化**

**新コード**:
```bash
echo "========================================="
echo "Starting Rails server..."
echo "========================================="
echo ""
exec "$@"
```

**改善点**:
- ✅ Railsサーバー起動が明確に分かる
- ✅ アセットビルドとの区切りが明確

### 4. **完全な起動フロー**

```
=========================================
Building assets (JavaScript and CSS)...
=========================================
[esbuildの出力]
✓ Initial asset build completed successfully

Starting agrr daemon...
✓ agrr daemon started (PID: 26)

=========================================
Starting asset watcher for development...
=========================================
✓ Asset watcher is running (PID: 123)
  Logs: /tmp/esbuild-watch.log
  Watching for file changes...

=========================================
Starting Rails server...
=========================================
[Railsの起動ログ]
```

## 📊 Before / After 比較

| 項目 | Before | After |
|------|--------|-------|
| ビルド成功/失敗 | 不明 | ✅ 明確に表示 |
| ビルド内容 | 不明 | ✅ esbuildの出力が見える |
| Watchモード状態 | 不明 | ✅ PIDとログファイルを表示 |
| ビルド失敗時の挙動 | Railsサーバーが起動 | ✅ 起動を中断 |
| デバッグ方法 | 不明 | ✅ `/tmp/esbuild-watch.log` で確認 |
| 起動完了の判断 | 議論になる | ✅ 一目瞭然 |

## 🎯 効果

### 1. **「開発が終わっているのか」が一目瞭然**

起動ログを見れば、以下が明確に分かる：
- ✅ アセットビルドが完了したか
- ✅ Watchモードが動いているか
- ✅ Railsサーバーが起動したか

### 2. **ビルドエラーの早期発見**

- ビルド失敗時は即座に終了
- エラー内容が表示される
- 無駄な起動待ち時間がゼロ

### 3. **デバッグが容易**

- Watchモードのログが `/tmp/esbuild-watch.log` に保存
- プロセスIDが表示される
- 何が動いているのか追跡可能

### 4. **議論が不要**

もう「動いているはずです！」「動いてない」というやり取りは不要。
ログを見れば全てが分かる。

## 🔧 デバッグ方法

### アセットが読み込まれない場合

1. **初回ビルドが成功しているか確認**:
```bash
docker compose logs web | grep "Initial asset build"
```

期待される出力：
```
✓ Initial asset build completed successfully
```

2. **Watchモードが動いているか確認**:
```bash
docker compose exec web cat /tmp/esbuild-watch.log
```

または：
```bash
docker compose exec web ps aux | grep esbuild
```

3. **ビルドファイルが存在するか確認**:
```bash
docker compose exec web ls -lh /app/app/assets/builds/
```

期待される出力：
```
application.js (約1.2MB)
application.css (約13KB)
```

### JavaScriptを修正しても反映されない場合

**esbuildでバンドルされるファイル**（`app/javascript/`）:
```bash
# Watchモードのログを確認
docker compose exec web cat /tmp/esbuild-watch.log

# 最新のビルドログを監視
docker compose exec web tail -f /tmp/esbuild-watch.log
```

**Propshaftで配信されるファイル**（`app/assets/javascripts/`）:
- ブラウザのキャッシュをクリア（Ctrl+Shift+R）
- 開発環境では即座に反映されるはず

## 📚 関連ドキュメント

- [ASSET_MANAGEMENT.md](ASSET_MANAGEMENT.md) - アセット管理の全体像
- [DOCKER_COMPOSE_GUIDE.md](DOCKER_COMPOSE_GUIDE.md) - Docker Compose使い方
- [docs/ASSET_LOADING_GUIDE.md](docs/ASSET_LOADING_GUIDE.md) - アセット読み込み方法

## 🎓 学び

### 問題の本質

「アセットのコンパイル・配信が意識せずに確実に終わる」ためには：

1. **プロセスの可視化が必須**
   - 何が起きているのか分からなければ、確認のしようがない
   - ログ出力を充実させることで、問題の早期発見が可能

2. **失敗時の明確な対処**
   - ビルド失敗時はRailsサーバーを起動しない
   - エラーメッセージを表示して即座に終了

3. **状態の確認可能性**
   - Watchモードのようなバックグラウンドプロセスは、状態確認手段を用意
   - ログファイル、PID、プロセス生存確認

4. **ドキュメント化**
   - 「当たり前」を文書化する
   - トラブルシューティング手順を整備

### Rails 8 + Propshaft + esbuildの特性

- **esbuild**: 高速だがエラーメッセージが簡潔
- **Propshaft**: `@import`が使えない、個別読み込み必須
- **開発環境**: `config.assets.compile = true` で動的配信
- **本番環境**: プリコンパイルが必要

これらの特性を理解した上で、適切なツールを選択する必要がある。

## ✨ まとめ

**もう「開発が終わっているのか終わっていないのか」で議論しない。**

改善後は：
- ✅ ビルドの進行状況が一目瞭然
- ✅ エラーが即座に表示される
- ✅ Watchモードの状態が確認できる
- ✅ デバッグが容易

これにより、開発効率が大幅に向上し、無駄な議論がゼロになります。

