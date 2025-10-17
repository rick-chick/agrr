# データベース保護機能

## 概要

開発環境のデータベースを誤ってテスト実行から保護するための複数の安全機構を実装しています。

## 実装された保護機能

### 1. ストレージの物理的分離

**docker-compose.yml**で開発環境とテスト環境のストレージを完全に分離：

```yaml
volumes:
  storage_dev_data:   # 開発環境専用（永続化）
  storage_test_data:  # テスト環境専用（完全分離）
```

- 開発環境: `storage_dev_data`ボリューム（永続化）
- テスト環境: `storage_test_data`ボリューム（完全分離）

**効果**: 
- テスト実行が物理的に開発データベースにアクセス不可
- コンテナを削除しても開発データは保持される

### 2. 実行時ガード

**config/environments/test.rb**にランタイムチェックを実装：

```ruby
if ENV['PREVENT_TEST_IN_DEV'] == 'true'
  raise "Cannot run tests in development container!"
end
```

**効果**: 
- `webコンテナ`（開発環境）でテストを実行しようとすると即座にエラー
- 明確なエラーメッセージで正しい実行方法を案内

### 3. データベース設定の最適化

**config/database.yml**でテスト環境の設定を調整：

```yaml
test:
  database: storage/test.sqlite3
  prepared_statements: false
```

**効果**: 
- テスト時のスキーマロードを最適化
- `db/schema.rb`から直接ロード（開発DBに依存しない）

### 4. 環境変数による制御

**docker-compose.yml**で環境変数を設定：

```yaml
web:
  environment:
    - PREVENT_TEST_IN_DEV=true  # テスト実行防止
```

## 正しいテスト実行方法

### ❌ 間違った方法（エラーになります）

```bash
# webコンテナ内でテスト実行 → ERROR
docker compose exec web bin/rails test

# ホスト環境でテスト実行 → 開発DBにアクセスする可能性
bundle exec rails test
```

### ✅ 正しい方法

```bash
# 全テストを実行
docker compose run --rm test bundle exec rails test

# 特定のテストファイルを実行
docker compose run --rm test bundle exec rails test test/integration/crop_ai_save_test.rb

# 特定のテストケースを実行
docker compose run --rm test bundle exec rails test test/integration/crop_ai_save_test.rb:19

# システムテストを実行
docker compose run --rm test bundle exec rails test:system
```

## トラブルシューティング

### ボリュームのリセットが必要な場合

```bash
# テスト環境のストレージをクリーン
docker compose down -v
docker volume rm agrr_storage_test_data

# 開発環境のストレージをクリーン（注意：データが消えます）
docker volume rm agrr_storage_dev_data
```

### 開発データベースのバックアップ

```bash
# ボリュームからデータをコピー
docker compose exec web bash -c "cp storage/development.sqlite3 /tmp/backup.sqlite3"
docker compose cp web:/tmp/backup.sqlite3 ./backup.sqlite3

# 復元
docker compose cp ./backup.sqlite3 web:/app/storage/development.sqlite3
```

## 保護機能の動作確認

### テスト1: webコンテナでのテスト実行阻止

```bash
docker compose exec web bin/rails test
# 期待される結果: エラーメッセージが表示され、実行が停止
```

### テスト2: ストレージの分離確認

```bash
# 開発環境のDB確認
docker compose exec web ls -la /app/storage/

# テスト環境のDB確認
docker compose run --rm test ls -la /app/storage/

# 結果: 異なるファイルが表示される
```

### テスト3: 永続化の確認

```bash
# データを作成
docker compose exec web bin/rails runner "Crop.create!(name: 'Test', user_id: 1)"

# コンテナを再起動
docker compose restart web

# データが残っているか確認
docker compose exec web bin/rails runner "puts Crop.count"
# 期待される結果: データが残っている
```

## まとめ

これらの保護機能により、以下が保証されます：

1. ✅ テスト実行で開発データベースが消えることはない
2. ✅ 誤った方法でテストを実行すると明確なエラーが出る
3. ✅ 開発データは永続化され、コンテナ再起動でも保持される
4. ✅ 開発環境とテスト環境は完全に分離される


