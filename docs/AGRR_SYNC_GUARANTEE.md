# AGRRバイナリ同期の保証

## 質問: 毎回確認しないといけないのか？

**答え: いいえ、確認は不要です。自動的に同期されます。**

## 仕組み

### Docker Volumeマウント

`docker-compose.yml`の設定により、プロジェクトルート全体がコンテナ内にマウントされます：

```yaml
services:
  web:
    volumes:
      - .:/app  # ローカルの . が コンテナの /app にマウント
```

**これにより**:
- `lib/core/agrr` → `/app/lib/core/agrr` に**リアルタイム同期**
- ローカルでファイルを変更すると、即座にコンテナからも見える
- **コンテナ再起動不要**（daemonを再起動すれば新バージョンが使われる）

### 自動確認メカニズム

`docker compose up`すると、entrypointスクリプトが自動的に：

1. **agrrバイナリの存在確認**
2. **MD5チェックサム表示**
3. **ファイルサイズ・更新日時の表示**
4. **どのバイナリが使われているかの明示**

```
✓ Found volume-mounted agrr: /app/lib/core/agrr
  Size: 168M, Modified: 2025-10-21 04:16:48
  MD5: ce54e632c1c0fff387b5e3fbf30fa743
  → This binary is synced from your local lib/core/agrr
```

## 確実に同期される理由

### Volume Mountの特性

Dockerのvolume mountは**カーネルレベル**で動作します：

1. **ファイルシステムレベルの共有**
   - コンテナとホストで同じinodeを共有
   - ホスト側の変更がコンテナに即座に反映

2. **コピーではなく参照**
   - ビルド時のCOPYとは異なる
   - 常に最新のファイルを参照

3. **リアルタイム同期**
   - ホスト側でファイルを書き換えると
   - コンテナ側でも即座に変更が見える

### 優先順位の保証

環境変数とコード設計により、volume-mountedバイナリが優先されます：

```bash
# 1. 環境変数で明示的に指定
AGRR_BIN_PATH=/app/lib/core/agrr

# 2. entrypointスクリプトでの優先順位
if [ -x "/app/lib/core/agrr" ]; then
    AGRR_BIN="/app/lib/core/agrr"  # これが最優先
elif [ -x "/usr/local/bin/agrr" ]; then
    AGRR_BIN="/usr/local/bin/agrr"  # フォールバック
fi

# 3. Railsアプリケーション内でも環境変数を優先
def agrr_path
  ENV['AGRR_BIN_PATH'] || Rails.root.join('lib/core/agrr').to_s
end
```

## 確認が必要なケース

以下の場合**のみ**、確認スクリプトを実行してください：

### 1. agrrを再ビルドした直後

```bash
# agrrを再ビルド
cd lib/core/agrr_core
./build_standalone.sh --onefile
cp dist/agrr ../agrr

# 確認（任意）
./scripts/check-agrr-sync.sh
```

**実際には確認不要**：volume mountで即座に同期されます。

### 2. トラブルシューティング時

何か問題が発生した場合のみ：

```bash
./scripts/check-agrr-sync.sh
```

### 3. 初回セットアップ時

最初の起動時に一度確認すると安心：

```bash
docker compose up
# ログを見て "✓ Found volume-mounted agrr" が表示されることを確認
```

## トラブルシューティング

### 問題: ローカルで再ビルドしたのに古いバージョンが使われている

**可能性1**: daemonが古いバージョンのまま

```bash
# daemon再起動
docker compose exec web /app/lib/core/agrr daemon stop
docker compose exec web /app/lib/core/agrr daemon start

# または コンテナ再起動
docker compose restart web
```

**可能性2**: volume mountが機能していない

```bash
# 確認
./scripts/check-agrr-sync.sh

# MD5が異なる場合は、コンテナを再作成
docker compose down
docker compose up --build
```

### 問題: "volume-mounted agrr not found"と表示される

**原因**: ローカルに`lib/core/agrr`が存在しない

```bash
# agrrをビルド
cd lib/core/agrr_core
./build_standalone.sh --onefile
cp dist/agrr ../agrr
cd ../../..

# コンテナ再起動
docker compose restart web
```

## まとめ

| 質問 | 答え |
|-----|-----|
| 毎回確認が必要？ | **不要** - volume mountで自動同期 |
| 手動でコピーが必要？ | **不要** - リアルタイム同期 |
| コンテナ再起動が必要？ | **不要** - daemon再起動で十分 |
| 確認スクリプトを実行すべき？ | **任意** - 起動ログで自動確認される |

**結論**: `docker compose up`するだけで、ローカルの最新agrrバイナリが使われることが**保証**されます。

