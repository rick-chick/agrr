#!/bin/bash

# Check if agrr daemon mode is enabled via environment variable
if [ "${USE_AGRR_DAEMON}" = "true" ]; then
    echo "=== Starting Rails Application with Litestream + agrr daemon ==="
else
    echo "=== Starting Rails Application with Litestream ==="
fi

# Use PORT environment variable (Cloud Run sets this dynamically)
export PORT=${PORT:-3000}
echo "Port: $PORT"
echo "AGRR Daemon Mode: ${USE_AGRR_DAEMON:-false}"

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

# Step 3: Start agrr daemon if enabled
if [ "${USE_AGRR_DAEMON}" = "true" ]; then
    echo "Step 3: Starting agrr daemon..."
    # agrr daemonを起動（環境変数またはデフォルトパスを使用）
    AGRR_BIN="${AGRR_BIN_PATH:-/usr/local/bin/agrr}"
    
    if [ -x "$AGRR_BIN" ]; then
        echo "Using agrr binary: $AGRR_BIN"
        # daemon startは即座に戻るため、明示的にバックグラウンド化は不要
        $AGRR_BIN daemon start
        if [ $? -eq 0 ]; then
            # PIDを取得（agrr daemon statusから抽出）
            AGRR_DAEMON_PID=$($AGRR_BIN daemon status 2>/dev/null | grep -oP 'PID: \K[0-9]+' || echo "")
            if [ -n "$AGRR_DAEMON_PID" ]; then
                echo "✓ agrr daemon started (PID: $AGRR_DAEMON_PID)"
            else
                echo "✓ agrr daemon started (PID unknown)"
            fi
        else
            echo "⚠ agrr daemon start failed, continuing without daemon"
        fi
    else
        echo "⚠ agrr binary not found at $AGRR_BIN, skipping daemon"
        echo "   Hint: Build agrr binary or set USE_AGRR_DAEMON=false"
    fi
else
    echo "Step 3: Skipping agrr daemon (USE_AGRR_DAEMON not set to 'true')"
fi

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
    
    # Stop agrr daemon if it was started
    if [ "${USE_AGRR_DAEMON}" = "true" ]; then
        AGRR_BIN="${AGRR_BIN_PATH:-/usr/local/bin/agrr}"
        if [ -x "$AGRR_BIN" ]; then
            echo "Stopping agrr daemon (using: $AGRR_BIN)..."
            $AGRR_BIN daemon stop 2>/dev/null || true
        fi
    fi
    
    exit 0
}

# Register cleanup on signals
trap cleanup SIGTERM SIGINT SIGHUP

# Wait for all background processes
wait $RAILS_PID $SOLID_QUEUE_PID $LITESTREAM_PID
