#!/bin/bash
# Daemon Memory Leak Monitoring Script
# Usage: ./scripts/monitor_daemon_memory.sh [interval_seconds] [duration_minutes]

set -e

# Default parameters
INTERVAL=${1:-5}  # Check every 5 seconds
DURATION=${2:-60} # Monitor for 60 minutes
OUTPUT_DIR="tmp/memory_monitoring"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
OUTPUT_FILE="${OUTPUT_DIR}/memory_log_${TIMESTAMP}.csv"
REPORT_FILE="${OUTPUT_DIR}/memory_report_${TIMESTAMP}.txt"

# Create output directory
mkdir -p "${OUTPUT_DIR}"

# Calculate iterations
ITERATIONS=$((DURATION * 60 / INTERVAL))

echo "=== Daemon Memory Monitoring ==="
echo "Interval: ${INTERVAL} seconds"
echo "Duration: ${DURATION} minutes"
echo "Iterations: ${ITERATIONS}"
echo "Output: ${OUTPUT_FILE}"
echo "Report: ${REPORT_FILE}"
echo ""

# Initialize CSV file
echo "timestamp,process,pid,rss_mb,vsz_mb,cpu_percent,mem_percent,command" > "${OUTPUT_FILE}"

# Function to get memory info for a process
get_process_memory() {
    local process_pattern=$1
    local process_name=$2
    
    # Find PIDs matching the pattern
    pids=$(pgrep -f "${process_pattern}" 2>/dev/null || true)
    
    if [ -z "$pids" ]; then
        echo "$(date +%Y-%m-%d\ %H:%M:%S),${process_name},N/A,0,0,0,0,NOT_RUNNING" >> "${OUTPUT_FILE}"
        return
    fi
    
    for pid in $pids; do
        # Get memory info using ps
        ps_output=$(ps -p "$pid" -o pid,rss,vsz,%cpu,%mem,comm --no-headers 2>/dev/null || true)
        
        if [ -n "$ps_output" ]; then
            read -r pid_val rss vsz cpu mem comm <<< "$ps_output"
            
            # Convert KB to MB
            rss_mb=$(echo "scale=2; $rss / 1024" | bc)
            vsz_mb=$(echo "scale=2; $vsz / 1024" | bc)
            
            timestamp=$(date +%Y-%m-%d\ %H:%M:%S)
            echo "${timestamp},${process_name},${pid_val},${rss_mb},${vsz_mb},${cpu},${mem},${comm}" >> "${OUTPUT_FILE}"
        fi
    done
}

# Function to detect memory leak
detect_memory_leak() {
    local csv_file=$1
    local process_name=$2
    
    # Extract RSS values for the process (skip header and N/A entries)
    rss_values=$(grep "^[0-9]" "${csv_file}" | grep "${process_name}" | grep -v "N/A" | cut -d',' -f4 | grep -v "^$" || true)
    
    if [ -z "$rss_values" ]; then
        echo "No data for ${process_name}"
        return
    fi
    
    # Calculate statistics using awk
    stats=$(echo "$rss_values" | awk '
        BEGIN { min=999999; max=0; sum=0; count=0; }
        {
            sum += $1;
            count++;
            if ($1 < min) min = $1;
            if ($1 > max) max = $1;
            values[count] = $1;
        }
        END {
            avg = sum / count;
            
            # Calculate standard deviation
            sum_sq_diff = 0;
            for (i=1; i<=count; i++) {
                diff = values[i] - avg;
                sum_sq_diff += diff * diff;
            }
            stddev = sqrt(sum_sq_diff / count);
            
            # Calculate growth rate (compare first 10% vs last 10%)
            early_count = int(count * 0.1);
            late_count = int(count * 0.1);
            early_sum = 0;
            late_sum = 0;
            
            for (i=1; i<=early_count; i++) {
                early_sum += values[i];
            }
            for (i=count-late_count+1; i<=count; i++) {
                late_sum += values[i];
            }
            
            early_avg = early_sum / early_count;
            late_avg = late_sum / late_count;
            growth_rate = ((late_avg - early_avg) / early_avg) * 100;
            
            printf "%.2f,%.2f,%.2f,%.2f,%.2f", min, max, avg, stddev, growth_rate;
        }
    ')
    
    IFS=',' read -r min max avg stddev growth_rate <<< "$stats"
    
    # Determine if there is a memory leak
    leak_status="OK"
    if (( $(echo "$growth_rate > 10" | bc -l) )); then
        leak_status="⚠️  POTENTIAL LEAK (${growth_rate}% growth)"
    elif (( $(echo "$growth_rate > 5" | bc -l) )); then
        leak_status="⚠️  WARNING (${growth_rate}% growth)"
    else
        leak_status="✓ OK (${growth_rate}% growth)"
    fi
    
    echo "=== ${process_name} ===" >> "${REPORT_FILE}"
    echo "Min RSS: ${min} MB" >> "${REPORT_FILE}"
    echo "Max RSS: ${max} MB" >> "${REPORT_FILE}"
    echo "Avg RSS: ${avg} MB" >> "${REPORT_FILE}"
    echo "Std Dev: ${stddev} MB" >> "${REPORT_FILE}"
    echo "Growth:  ${growth_rate}% (first 10% vs last 10%)" >> "${REPORT_FILE}"
    echo "Status:  ${leak_status}" >> "${REPORT_FILE}"
    echo "" >> "${REPORT_FILE}"
}

# Monitoring loop
echo "Starting monitoring... (Press Ctrl+C to stop)"
echo ""

for i in $(seq 1 $ITERATIONS); do
    # Monitor each daemon process
    get_process_memory "agrr daemon" "agrr_daemon"
    get_process_memory "solid_queue" "solid_queue"
    get_process_memory "litestream" "litestream"
    get_process_memory "puma" "puma"
    
    # Progress indicator
    echo -ne "\rProgress: ${i}/${ITERATIONS} ($(( i * 100 / ITERATIONS ))%)"
    
    sleep "${INTERVAL}"
done

echo ""
echo ""
echo "=== Monitoring Complete ==="
echo ""

# Generate report
echo "=== Daemon Memory Leak Detection Report ===" > "${REPORT_FILE}"
echo "Generated: $(date)" >> "${REPORT_FILE}"
echo "Duration: ${DURATION} minutes" >> "${REPORT_FILE}"
echo "Interval: ${INTERVAL} seconds" >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"

# Analyze each process
detect_memory_leak "${OUTPUT_FILE}" "agrr_daemon"
detect_memory_leak "${OUTPUT_FILE}" "solid_queue"
detect_memory_leak "${OUTPUT_FILE}" "litestream"
detect_memory_leak "${OUTPUT_FILE}" "puma"

# Display report
cat "${REPORT_FILE}"

echo ""
echo "Full data saved to: ${OUTPUT_FILE}"
echo "Report saved to: ${REPORT_FILE}"
echo ""
echo "To visualize the data, you can use:"
echo "  - scripts/visualize_memory.py ${OUTPUT_FILE}"
echo "  - Import ${OUTPUT_FILE} into Excel/Google Sheets"

