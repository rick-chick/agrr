# AGRR Binary Management Guide

## 概要

AGRRプロジェクトでは、agrrバイナリ（Pythonアプリケーション）を以下の方法で管理しています：

- **開発環境（Docker）**: volumeマウント経由でローカルのagrrバイナリを使用
- **本番環境（Docker）**: Dockerイメージに含まれるagrrバイナリを使用

## 開発環境での設定

### 1. agrrバイナリのビルド

```bash
cd lib/core/agrr_core
./build_standalone.sh --onefile
cp dist/agrr ../agrr
cd ../../..
```

### 2. Docker環境での使用

`docker-compose.yml`の設定により、ローカルの`lib/core/agrr`が自動的にコンテナ内の`/app/lib/core/agrr`にマウントされます。

```yaml
services:
  web:
    volumes:
      - .:/app  # プロジェクトルート全体をマウント
    environment:
      - AGRR_BIN_PATH=/app/lib/core/agrr  # 明示的にパスを指定
```

### 3. agrrバイナリの優先順位

Railsアプリケーション（`app/gateways/agrr/base_gateway.rb`）とentrypointスクリプトは、以下の優先順位でagrrバイナリを探します：

1. **環境変数 `AGRR_BIN_PATH`** - 最優先
2. **`/app/lib/core/agrr`** - volumeマウント経由（開発環境）
3. **`/usr/local/bin/agrr`** - Dockerイメージに含まれる（フォールバック）

### 4. 動作確認

#### 自動確認（推奨）

**`docker compose up`すると自動的にチェックされます！**

起動時のログに以下が表示されます：

```
=========================================
Configuring agrr daemon...
=========================================
✓ Found volume-mounted agrr: /app/lib/core/agrr
  Size: 168M, Modified: 2025-10-21 04:16:48
  MD5: ce54e632c1c0fff387b5e3fbf30fa743
  → This binary is synced from your local lib/core/agrr

Starting daemon with: /app/lib/core/agrr
✓ agrr daemon started successfully (PID: 82)
  Your local agrr binary is now running as a daemon
```

**👉 手動で確認する必要はありません。ローカルのagrrが自動的に使われます。**

#### ワンコマンド確認スクリプト

```bash
./scripts/check-agrr-sync.sh
```

**表示例**:
```
========================================
AGRR Binary Sync Check
========================================

📂 Local binary (lib/core/agrr):
   MD5:      ce54e632c1c0fff387b5e3fbf30fa743
   Size:     168M
   Modified: 2025-10-21 13:16:48

🐳 Container binary (/app/lib/core/agrr):
   MD5:      ce54e632c1c0fff387b5e3fbf30fa743
   Size:     168M
   Modified: 2025-10-21 04:16:48

✅ SYNCED: Local and container binaries are identical
   Your local changes are being used in the container

🔧 Daemon status:
   ✓ Daemon is running (PID: 89)
```

#### 手動確認（トラブルシューティング時のみ）

通常は不要ですが、問題が発生した場合：

```bash
# agrrバイナリの確認
md5sum lib/core/agrr
docker compose exec web md5sum /app/lib/core/agrr

# daemon状態の確認
docker compose exec web /app/lib/core/agrr daemon status

# 起動ログで確認
docker compose logs web | grep -A 10 "Configuring agrr"
```

### 5. トラブルシューティング

#### 問題: 古いagrrバイナリが使われている

**症状**: ローカルでagrrをビルドしたが、コンテナ内で古いバージョンが使われている

**原因**: volumeマウントが正しく動作していない、またはDockerイメージ内の古いバイナリが優先されている

**対処**:

```bash
# 1. MD5チェックサムを確認
md5sum lib/core/agrr
docker compose exec web md5sum /app/lib/core/agrr
# → 異なる場合はvolumeマウントの問題

# 2. コンテナを再起動
docker compose restart web

# 3. それでも解決しない場合は完全再作成
docker compose down
docker compose up --build
```

#### 問題: daemon起動に失敗する

**症状**: "⚠ agrr daemon start failed" と表示される

**原因**: agrrバイナリの権限、または依存ライブラリの問題

**対処**:

```bash
# 1. agrrバイナリの権限を確認
ls -lh lib/core/agrr
# → "-rwxr-xr-x" のように実行権限があることを確認

# 2. 実行権限を付与
chmod +x lib/core/agrr

# 3. agrrバイナリを直接実行してエラーメッセージを確認
docker compose exec web /app/lib/core/agrr daemon start
```

#### 問題: 環境変数が反映されない

**症状**: `AGRR_BIN_PATH`を設定したが、違うパスが使われている

**対処**:

```bash
# 1. 環境変数を確認
docker compose exec web env | grep AGRR

# 2. docker-compose.ymlを確認
cat docker-compose.yml | grep -A 10 "environment:"

# 3. コンテナを再作成
docker compose down
docker compose up
```

## 本番環境での設定

### 1. agrrバイナリのビルド

デプロイ前にagrrバイナリをビルドして、`lib/core/`に配置します：

```bash
cd lib/core/agrr_core
./build_standalone.sh --onefile
cp dist/agrr ../agrr
cd ../../..
```

### 2. Dockerイメージのビルド

`Dockerfile.production`では、agrrバイナリをDockerイメージに含めません（コメントアウト済み）。
本番環境では、デプロイスクリプト内でagrrバイナリをビルドしてから使用します。

### 3. Cloud Runでの使用

Cloud Runでは、環境変数で明示的にagrrバイナリのパスを指定できます：

```yaml
env:
  - name: AGRR_BIN_PATH
    value: /app/lib/core/agrr
```

## まとめ

| 環境 | agrrバイナリの場所 | 管理方法 |
|-----|------------------|---------|
| **開発（Docker）** | `/app/lib/core/agrr` | volumeマウント（ローカルと同期） |
| **本番（Docker）** | `/app/lib/core/agrr` | デプロイ前にビルドして配置 |

**重要な変更点**:
- Dockerfileから`/usr/local/bin/agrr`へのコピーを削除（開発環境）
- 環境変数`AGRR_BIN_PATH`でパスを明示的に制御
- entrypointスクリプトで詳細なログ出力を追加

これにより、**ローカルでagrrバイナリをビルドすると、即座にDockerコンテナでも新しいバージョンが使われる**ようになりました。

