#!/bin/bash

echo "=== Starting Rails Application ==="

echo "Step 1: Database preparation..."
bundle exec rails db:prepare
if [ $? -ne 0 ]; then
    echo "ERROR: Database preparation failed"
    exit 1
fi
echo "Database preparation completed"

echo "Step 2: Running Solid Queue migrations..."
bundle exec rails db:migrate
if [ $? -ne 0 ]; then
    echo "ERROR: Solid Queue migrations failed"
    exit 1
fi
echo "Solid Queue migrations completed"

echo "Step 3: Starting Solid Queue worker..."
bundle exec rails solid_queue:start &
SOLID_QUEUE_PID=$!
echo "Solid Queue worker started (PID: $SOLID_QUEUE_PID)"

echo "Step 4: Starting Rails server..."
bundle exec rails server -b 0.0.0.0 -e production
