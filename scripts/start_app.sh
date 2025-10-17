#!/bin/bash

echo "=== Starting Rails Application with Litestream ==="

# Use PORT environment variable (Cloud Run sets this dynamically)
export PORT=${PORT:-3000}
echo "Port: $PORT"

# Restore databases from GCS if they exist
echo "Step 1: Restoring databases from GCS..."

# Restore main database
if litestream restore -if-replica-exists -config /etc/litestream.yml /tmp/production.sqlite3; then
    echo "✓ Main database restored from GCS"
else
    echo "⚠ No main database replica found, starting fresh"
fi

# Restore queue database
if litestream restore -if-replica-exists -config /etc/litestream.yml /tmp/production_queue.sqlite3; then
    echo "✓ Queue database restored from GCS"
else
    echo "⚠ No queue database replica found, starting fresh"
fi

# Restore cache database (optional - cache can be recreated)
if litestream restore -if-replica-exists -config /etc/litestream.yml /tmp/production_cache.sqlite3; then
    echo "✓ Cache database restored from GCS"
else
    echo "⚠ No cache database replica found, will be created"
fi

echo "Step 2: Database setup..."
# Prepare database (creates if needed and runs migrations)
bundle exec rails db:prepare
if [ $? -ne 0 ]; then
    echo "ERROR: Database setup failed"
    exit 1
fi
echo "Database setup completed"

# Check if database needs seeding (disabled for faster startup)
echo "Step 3: Seed disabled for now (run manually after startup if needed)"
# if bundle exec rails runner "exit(User.count == 0 ? 0 : 1)" 2>/dev/null; then
#     echo "Database is empty. Running seed..."
#     bundle exec rails db:seed
#     echo "Seed completed"
# else
#     echo "Database already has data. Skipping seed."
# fi

echo "Step 4: Solid Queue will be started by Puma plugin (no separate process needed)"

echo "Step 5: Starting Litestream replication..."
litestream replicate -config /etc/litestream.yml &
LITESTREAM_PID=$!
echo "Litestream started (PID: $LITESTREAM_PID) - replicating all databases"

echo "Step 6: Starting Rails server..."
exec bundle exec rails server -b 0.0.0.0 -p $PORT -e production
