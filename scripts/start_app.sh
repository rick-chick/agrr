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
# Run migrations for all databases (primary, queue, cache)
echo "Running migrations for all databases (primary, queue, cache)..."
bundle exec rails db:migrate
if [ $? -ne 0 ]; then
    echo "ERROR: Database migration failed"
    exit 1
fi
echo "All databases migrated successfully"

echo "Step 4: Starting Litestream replication..."
litestream replicate -config /etc/litestream.yml &
LITESTREAM_PID=$!
echo "Litestream started (PID: $LITESTREAM_PID) - replicating all databases"

echo "Step 5: Starting Solid Queue worker in background..."
bundle exec rails solid_queue:start &
SOLID_QUEUE_PID=$!
echo "Solid Queue worker started (PID: $SOLID_QUEUE_PID)"

# Wait a moment for worker to initialize
sleep 3

echo "Step 6: Starting Rails server..."
bundle exec rails server -b 0.0.0.0 -p $PORT -e production &
RAILS_PID=$!
echo "Rails server started (PID: $RAILS_PID)"

# Cleanup function
cleanup() {
    echo "Shutting down services..."
    kill -TERM $RAILS_PID 2>/dev/null || true
    kill -TERM $SOLID_QUEUE_PID 2>/dev/null || true
    kill -TERM $LITESTREAM_PID 2>/dev/null || true
    exit 0
}

# Register cleanup on signals
trap cleanup SIGTERM SIGINT SIGHUP

# Wait for all background processes
wait $RAILS_PID $SOLID_QUEUE_PID $LITESTREAM_PID
