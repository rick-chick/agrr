#!/bin/bash
# Docker Memory Monitoring Wrapper
# Usage: ./scripts/docker_monitor_memory.sh [interval_seconds] [duration_minutes]

set -e

INTERVAL=${1:-5}
DURATION=${2:-60}

echo "=== Docker Daemon Memory Monitoring ==="
echo "Starting memory monitoring in Docker container..."
echo ""

# Check if container is running
if ! docker compose ps web | grep -q "running"; then
    echo "Error: web container is not running!"
    echo "Start the container with: docker compose up -d web"
    exit 1
fi

# Execute monitoring script inside container
docker compose exec web bash -c "
    # Install bc if not available
    if ! command -v bc &> /dev/null; then
        echo 'Installing bc...'
        apt-get update -qq && apt-get install -y -qq bc > /dev/null 2>&1
    fi
    
    # Run monitoring script
    /app/scripts/monitor_daemon_memory.sh ${INTERVAL} ${DURATION}
"

# Copy results to host
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
CONTAINER_OUTPUT_DIR="/app/tmp/memory_monitoring"
HOST_OUTPUT_DIR="./tmp/memory_monitoring"

echo ""
echo "Copying results from container to host..."
mkdir -p "${HOST_OUTPUT_DIR}"

# Find the latest log file
LATEST_LOG=$(docker compose exec web bash -c "ls -t ${CONTAINER_OUTPUT_DIR}/memory_log_*.csv 2>/dev/null | head -1" | tr -d '\r')
LATEST_REPORT=$(docker compose exec web bash -c "ls -t ${CONTAINER_OUTPUT_DIR}/memory_report_*.txt 2>/dev/null | head -1" | tr -d '\r')

if [ -n "$LATEST_LOG" ]; then
    docker compose cp "web:${LATEST_LOG}" "${HOST_OUTPUT_DIR}/"
    echo "✓ CSV log copied to: ${HOST_OUTPUT_DIR}/$(basename ${LATEST_LOG})"
fi

if [ -n "$LATEST_REPORT" ]; then
    docker compose cp "web:${LATEST_REPORT}" "${HOST_OUTPUT_DIR}/"
    echo "✓ Report copied to: ${HOST_OUTPUT_DIR}/$(basename ${LATEST_REPORT})"
fi

echo ""
echo "To visualize the data:"
echo "  python3 scripts/visualize_memory.py ${HOST_OUTPUT_DIR}/$(basename ${LATEST_LOG})"

