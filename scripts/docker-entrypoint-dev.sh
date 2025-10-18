#!/bin/bash
set -e

# サーバーPIDファイルを削除
rm -f /app/tmp/pids/server.pid

# schema.rbを削除（volumeマウントで混入を防ぐ）
# db:migrateがschema.rbを見つけると、それを使ってDBを作成してしまい
# schema_migrationsに全マイグレーション実行済みと記録されるため
echo "Removing schema files for clean migration run..."
rm -f /app/db/schema.rb /app/db/queue_schema.rb /app/db/cache_schema.rb

# すべてのDBをマイグレーション実行（primary, queue, cache）
echo "Running migrations for all databases (primary, queue, cache)..."
bundle exec rails db:migrate

# Railsサーバー起動
exec "$@"
