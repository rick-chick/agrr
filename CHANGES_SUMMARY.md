# AGRRバイナリ管理の改善

## 変更日
2025-10-21

## 概要
docker環境で、ローカルのagrrバイナリが確実に使われるように修正しました。

## 変更内容

### 1. Dockerfile の修正
- **変更前**: `lib/core/agrr`を`/usr/local/bin/agrr`にコピーしていた
- **変更後**: volumeマウント経由でローカルのagrrバイナリを使用するため、コピー処理を削除
- **ファイル**: `Dockerfile` (行50-53)

**理由**: 開発環境ではvolumeマウントされた最新のローカルバイナリを使いたいため。

### 2. docker-compose.yml の修正
- 環境変数`AGRR_BIN_PATH=/app/lib/core/agrr`を追加（web, web-cli, test サービス）
- **ファイル**: `docker-compose.yml`

**理由**: Railsアプリケーションとentrypointスクリプトで、明示的にvolume-mountedバイナリを使うため。

### 3. Railsゲートウェイの修正
- `agrr_path`メソッドで環境変数`AGRR_BIN_PATH`を優先するように変更
- **ファイル**: `app/gateways/agrr/base_gateway.rb` (行99-106)

**変更後**:
```ruby
def agrr_path
  @agrr_path ||= begin
    ENV['AGRR_BIN_PATH'] || Rails.root.join('lib/core/agrr').to_s
  end
end
```

### 4. Entrypointスクリプトの修正
- daemon起動時の詳細ログを追加
- エラー時のデバッグ情報を強化
- **ファイル**: `scripts/docker-entrypoint-dev-daemon.sh` (行47-84)

**追加ログ**:
- "Using volume-mounted agrr: /app/lib/core/agrr"
- バイナリのファイル情報（ls -lh）
- daemon起動の詳細な出力とexit code

### 5. 本番環境スクリプトの修正
- 環境変数`AGRR_BIN_PATH`のサポートを追加
- **ファイル**: `scripts/start_app.sh` (行49-76, 103-110)

### 6. ドキュメント追加・更新
- **新規**: `docs/AGRR_BINARY_MANAGEMENT.md` - agrrバイナリ管理の完全ガイド
- **更新**: `DOCKER_COMPOSE_GUIDE.md` - agrrバイナリ確認コマンドを追加
- **更新**: `README.md` - 新規ドキュメントへのリンクを追加

## 動作確認

### ローカルとコンテナで同じバイナリが使われているか確認
```bash
# MD5チェックサム一致
$ md5sum lib/core/agrr
ce54e632c1c0fff387b5e3fbf30fa743  lib/core/agrr

$ docker compose exec web md5sum /app/lib/core/agrr
ce54e632c1c0fff387b5e3fbf30fa743  /app/lib/core/agrr
```
✅ **一致している**

### Daemon起動確認
```bash
$ docker compose logs web | grep -A 3 "agrr daemon"
web-1  | Starting agrr daemon...
web-1  | Using volume-mounted agrr: /app/lib/core/agrr
web-1  | -rwxr-xr-x 1 appuser appuser 168M Oct 21 04:16 /app/lib/core/agrr
web-1  | ✓ agrr daemon started (PID: 82)
```
✅ **volume-mounted agrrが使われている**

### Railsアプリケーションが使うパス
```bash
$ docker compose exec web bash -c 'ruby -r /app/config/environment.rb -e "puts Agrr::BaseGateway.new.send(:agrr_path)"'
/app/lib/core/agrr
```
✅ **正しいパスが使われている**

## 効果

### Before（変更前）
- コンテナ内に古いagrrバイナリ（`/usr/local/bin/agrr`）が存在
- PATHで`/usr/local/bin/agrr`が優先されていた
- ローカルでagrrを再ビルドしても、コンテナ再起動まで反映されなかった

### After（変更後）
- **ローカルでagrrを再ビルドすると、即座にコンテナでも新しいバージョンが使われる**
- 環境変数で明示的にパスを制御できる
- 詳細なログでトラブルシューティングが容易

## トラブルシューティング

問題が発生した場合は、`docs/AGRR_BINARY_MANAGEMENT.md`を参照してください。

主な確認コマンド：
```bash
# MD5チェックサム確認
md5sum lib/core/agrr
docker compose exec web md5sum /app/lib/core/agrr

# Daemon状態確認
docker compose exec web /app/lib/core/agrr daemon status

# 環境変数確認
docker compose exec web env | grep AGRR
```

## 関連ドキュメント
- [docs/AGRR_BINARY_MANAGEMENT.md](docs/AGRR_BINARY_MANAGEMENT.md) - 完全ガイド
- [DOCKER_COMPOSE_GUIDE.md](DOCKER_COMPOSE_GUIDE.md) - Docker使い方

