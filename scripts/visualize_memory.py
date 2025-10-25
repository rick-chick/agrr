#!/usr/bin/env python3
"""
Memory Usage Visualization Script
Usage: python3 scripts/visualize_memory.py <csv_file>
"""

import sys
import csv
from collections import defaultdict
from datetime import datetime
import statistics

def load_memory_data(csv_file):
    """Load memory data from CSV file"""
    data = defaultdict(list)
    
    with open(csv_file, 'r') as f:
        reader = csv.DictReader(f)
        for row in reader:
            if row['pid'] == 'N/A' or row['rss_mb'] == '0':
                continue
            
            process = row['process']
            timestamp = datetime.strptime(row['timestamp'], '%Y-%m-%d %H:%M:%S')
            rss_mb = float(row['rss_mb'])
            
            data[process].append({
                'timestamp': timestamp,
                'rss_mb': rss_mb,
                'cpu_percent': float(row['cpu_percent']),
                'mem_percent': float(row['mem_percent'])
            })
    
    return data

def analyze_process(process_name, measurements):
    """Analyze memory usage for a single process"""
    if not measurements:
        print(f"\n=== {process_name} ===")
        print("No data available")
        return
    
    # Extract RSS values
    rss_values = [m['rss_mb'] for m in measurements]
    
    # Calculate statistics
    min_rss = min(rss_values)
    max_rss = max(rss_values)
    avg_rss = statistics.mean(rss_values)
    stddev_rss = statistics.stdev(rss_values) if len(rss_values) > 1 else 0
    
    # Calculate growth rate (first 10% vs last 10%)
    early_count = max(1, len(rss_values) // 10)
    late_count = max(1, len(rss_values) // 10)
    
    early_avg = statistics.mean(rss_values[:early_count])
    late_avg = statistics.mean(rss_values[-late_count:])
    
    growth_rate = ((late_avg - early_avg) / early_avg) * 100 if early_avg > 0 else 0
    
    # Detect trend
    if growth_rate > 10:
        status = "⚠️  POTENTIAL LEAK"
    elif growth_rate > 5:
        status = "⚠️  WARNING"
    else:
        status = "✓ OK"
    
    # Print analysis
    print(f"\n=== {process_name} ===")
    print(f"Measurements: {len(measurements)}")
    print(f"Min RSS: {min_rss:.2f} MB")
    print(f"Max RSS: {max_rss:.2f} MB")
    print(f"Avg RSS: {avg_rss:.2f} MB")
    print(f"Std Dev: {stddev_rss:.2f} MB")
    print(f"Growth:  {growth_rate:.2f}% (first 10% vs last 10%)")
    print(f"Status:  {status}")
    
    # Print ASCII chart
    print(f"\nMemory Usage Chart (RSS in MB):")
    print_ascii_chart(rss_values, process_name)
    
    # Check for memory spikes
    avg_cpu = statistics.mean([m['cpu_percent'] for m in measurements])
    max_cpu = max([m['cpu_percent'] for m in measurements])
    print(f"\nCPU Usage:")
    print(f"  Average: {avg_cpu:.1f}%")
    print(f"  Max: {max_cpu:.1f}%")

def print_ascii_chart(values, title, width=60, height=15):
    """Print an ASCII chart of the values"""
    if not values:
        return
    
    min_val = min(values)
    max_val = max(values)
    range_val = max_val - min_val if max_val > min_val else 1
    
    # Normalize values to chart height
    normalized = [int((v - min_val) / range_val * (height - 1)) for v in values]
    
    # Downsample if too many points
    if len(normalized) > width:
        step = len(normalized) // width
        normalized = normalized[::step]
    
    # Print chart
    for row in range(height - 1, -1, -1):
        line = ""
        for val in normalized:
            if val >= row:
                line += "█"
            elif val == row - 1:
                line += "▄"
            else:
                line += " "
        
        # Add scale
        scale_val = min_val + (row / (height - 1)) * range_val
        print(f"{scale_val:6.1f} MB │{line}│")
    
    # Print x-axis
    print("          └" + "─" * len(normalized) + "┘")
    print(f"           0" + " " * (len(normalized) - 10) + f"{len(values)} samples")

def generate_recommendations(data):
    """Generate recommendations based on the analysis"""
    print("\n" + "=" * 70)
    print("RECOMMENDATIONS")
    print("=" * 70)
    
    leak_detected = False
    
    for process_name, measurements in data.items():
        if not measurements:
            continue
        
        rss_values = [m['rss_mb'] for m in measurements]
        early_count = max(1, len(rss_values) // 10)
        late_count = max(1, len(rss_values) // 10)
        
        early_avg = statistics.mean(rss_values[:early_count])
        late_avg = statistics.mean(rss_values[-late_count:])
        growth_rate = ((late_avg - early_avg) / early_avg) * 100 if early_avg > 0 else 0
        
        if growth_rate > 10:
            leak_detected = True
            print(f"\n⚠️  {process_name}:")
            print(f"   - Memory grew by {growth_rate:.1f}% during monitoring")
            print(f"   - Starting: {early_avg:.1f} MB → Ending: {late_avg:.1f} MB")
            print(f"   - Action required:")
            
            if process_name == "agrr_daemon":
                print(f"     1. Check agrr daemon logs: agrr daemon logs")
                print(f"     2. Restart daemon: agrr daemon restart")
                print(f"     3. Review Python code in lib/core/agrr_core/")
                print(f"     4. Check for unclosed resources (files, connections)")
            elif process_name == "solid_queue":
                print(f"     1. Check for stuck jobs: rails solid_queue:status")
                print(f"     2. Review job definitions in app/jobs/")
                print(f"     3. Consider reducing JOB_CONCURRENCY")
            elif process_name == "puma":
                print(f"     1. Review Rails logs in log/production.log")
                print(f"     2. Check for memory-heavy requests")
                print(f"     3. Consider adding worker timeout")
                print(f"     4. Profile with rack-mini-profiler or derailed")
    
    if not leak_detected:
        print("\n✓ No significant memory leaks detected!")
        print("\nAll processes show stable memory usage.")
    
    print("\n" + "=" * 70)
    print("NEXT STEPS")
    print("=" * 70)
    print("\n1. For longer-term monitoring, run this script for 24+ hours")
    print("2. Monitor in production environment with real traffic")
    print("3. Set up alerting for memory usage thresholds")
    print("4. Consider using application-level profiling tools:")
    print("   - Ruby: memory_profiler, derailed_benchmarks")
    print("   - Python: memory_profiler, tracemalloc")

def main():
    if len(sys.argv) < 2:
        print("Usage: python3 scripts/visualize_memory.py <csv_file>")
        sys.exit(1)
    
    csv_file = sys.argv[1]
    
    print("=" * 70)
    print("DAEMON MEMORY LEAK ANALYSIS")
    print("=" * 70)
    print(f"Data file: {csv_file}")
    
    # Load data
    data = load_memory_data(csv_file)
    
    if not data:
        print("\nNo data found in CSV file!")
        sys.exit(1)
    
    # Analyze each process
    for process_name in sorted(data.keys()):
        analyze_process(process_name, data[process_name])
    
    # Generate recommendations
    generate_recommendations(data)
    
    print("\n" + "=" * 70)
    print("Analysis complete!")

if __name__ == "__main__":
    main()

