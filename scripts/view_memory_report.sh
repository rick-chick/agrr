#!/bin/bash
# Quick script to view the latest memory monitoring report
# Usage: ./scripts/view_memory_report.sh

set -e

MEMORY_DIR="tmp/memory_monitoring"

if [ ! -d "$MEMORY_DIR" ]; then
    echo "Error: Memory monitoring directory not found: $MEMORY_DIR"
    echo "Have you started Docker Compose with ENABLE_MEMORY_MONITOR=true?"
    exit 1
fi

# Find the latest CSV file
LATEST_CSV=$(ls -t "$MEMORY_DIR"/memory_log_*.csv 2>/dev/null | head -1)

if [ -z "$LATEST_CSV" ]; then
    echo "No memory monitoring data found in $MEMORY_DIR"
    echo ""
    echo "To start monitoring:"
    echo "  1. Ensure ENABLE_MEMORY_MONITOR=true in docker-compose.yml"
    echo "  2. Run: docker compose up"
    echo "  3. Wait a few minutes for data collection"
    exit 1
fi

echo "========================================================================"
echo "Latest Memory Monitoring Data"
echo "========================================================================"
echo "CSV File: $LATEST_CSV"
echo ""

# Show line count
LINE_COUNT=$(wc -l < "$LATEST_CSV")
SAMPLE_COUNT=$((LINE_COUNT - 1))  # Subtract header
echo "Total samples: $SAMPLE_COUNT"

# Calculate duration
if [ $SAMPLE_COUNT -gt 0 ]; then
    FIRST_TIME=$(head -2 "$LATEST_CSV" | tail -1 | cut -d',' -f1)
    LAST_TIME=$(tail -1 "$LATEST_CSV" | cut -d',' -f1)
    echo "First sample: $FIRST_TIME"
    echo "Last sample:  $LAST_TIME"
fi

echo ""
echo "========================================================================"

# Find the corresponding report file
LATEST_REPORT="${LATEST_CSV/memory_log_/memory_report_}"
LATEST_REPORT="${LATEST_REPORT/.csv/.txt}"

if [ -f "$LATEST_REPORT" ]; then
    echo "Report File: $LATEST_REPORT"
    echo ""
    cat "$LATEST_REPORT"
else
    echo "Report file not found. Generating analysis..."
    echo ""
    
    # Generate analysis using Python script
    if command -v python3 &> /dev/null; then
        python3 scripts/visualize_memory.py "$LATEST_CSV"
    else
        echo "Python3 not found. Showing raw data summary instead:"
        echo ""
        
        # Show quick summary using awk
        echo "Process Memory Usage (MB):"
        tail -n +2 "$LATEST_CSV" | awk -F',' '
        {
            process = $2
            rss = $4
            if (rss != "0" && rss != "") {
                sum[process] += rss
                count[process]++
                if (min[process] == "" || rss < min[process]) min[process] = rss
                if (max[process] == "" || rss > max[process]) max[process] = rss
            }
        }
        END {
            printf "%-20s %8s %8s %8s\n", "Process", "Min", "Avg", "Max"
            printf "%-20s %8s %8s %8s\n", "-------", "---", "---", "---"
            for (p in sum) {
                avg = sum[p] / count[p]
                printf "%-20s %8.1f %8.1f %8.1f\n", p, min[p], avg, max[p]
            }
        }'
    fi
fi

echo ""
echo "========================================================================"
echo "Quick Actions"
echo "========================================================================"
echo ""
echo "View full CSV data:"
echo "  less $LATEST_CSV"
echo ""
echo "Generate detailed visualization:"
echo "  python3 scripts/visualize_memory.py $LATEST_CSV"
echo ""
echo "Monitor live (in another terminal):"
echo "  watch -n 5 'tail -20 $LATEST_CSV'"
echo ""
echo "Copy to spreadsheet:"
echo "  cat $LATEST_CSV | pbcopy  # macOS"
echo "  cat $LATEST_CSV | xclip -selection clipboard  # Linux"
echo ""

