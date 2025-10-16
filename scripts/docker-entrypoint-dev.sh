#!/bin/bash
set -e

# サーバーPIDファイルを削除
rm -f /app/tmp/pids/server.pid

# マイグレーション実行
echo "Running migrations..."
bundle exec rails db:migrate

# データベースが空の場合のみseedを実行
if ! bundle exec rails runner 'exit(User.exists? ? 0 : 1)' 2>/dev/null; then
  echo "Database is empty. Running seeds..."
  bundle exec rails db:seed
else
  echo "Database already seeded. Skipping seeds."
fi

# Railsサーバー起動
exec "$@"

