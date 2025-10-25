namespace :memory do
  desc "Profile memory usage of a specific job"
  task :profile_job, [:job_class] => :environment do |t, args|
    require 'benchmark'
    
    job_class = args[:job_class]
    
    unless job_class
      puts "Usage: rails memory:profile_job[JobClassName]"
      puts "Example: rails memory:profile_job[PredictWeatherDataJob]"
      exit 1
    end
    
    begin
      klass = job_class.constantize
    rescue NameError
      puts "Error: Job class '#{job_class}' not found"
      exit 1
    end
    
    unless klass < ApplicationJob
      puts "Error: #{job_class} is not a job class"
      exit 1
    end
    
    puts "=" * 70
    puts "MEMORY PROFILING: #{job_class}"
    puts "=" * 70
    puts ""
    
    # Get GC stats before
    GC.start
    gc_stat_before = GC.stat
    memory_before = `ps -o rss= -p #{Process.pid}`.to_i
    
    puts "Memory before: #{memory_before / 1024} MB"
    puts ""
    
    # Run job with timing
    start_time = Time.current
    result = nil
    
    begin
      result = Benchmark.measure do
        # Perform job synchronously
        klass.perform_now
      end
      
      puts "Job completed successfully"
    rescue => e
      puts "Job failed with error: #{e.message}"
      puts e.backtrace.first(5)
    end
    
    end_time = Time.current
    
    # Get GC stats after
    GC.start
    gc_stat_after = GC.stat
    memory_after = `ps -o rss= -p #{Process.pid}`.to_i
    
    puts ""
    puts "Results:"
    puts "-" * 70
    puts "Execution time: #{(end_time - start_time).round(2)}s"
    puts "Memory before:  #{memory_before / 1024} MB"
    puts "Memory after:   #{memory_after / 1024} MB"
    puts "Memory delta:   #{(memory_after - memory_before) / 1024} MB"
    puts ""
    puts "GC Statistics:"
    puts "  Total allocations: #{gc_stat_after[:total_allocated_objects] - gc_stat_before[:total_allocated_objects]}"
    puts "  Total freed:       #{gc_stat_after[:total_freed_objects] - gc_stat_before[:total_freed_objects]}"
    puts "  GC runs:           #{gc_stat_after[:count] - gc_stat_before[:count]}"
    puts "  Major GC runs:     #{gc_stat_after[:major_gc_count] - gc_stat_before[:major_gc_count]}"
    puts "  Minor GC runs:     #{gc_stat_after[:minor_gc_count] - gc_stat_before[:minor_gc_count]}"
    puts ""
    
    if result
      puts "Benchmark:"
      puts result.to_s
    end
    
    puts "=" * 70
  end
  
  desc "Show current memory usage of all processes"
  task :status => :environment do
    puts "=" * 70
    puts "MEMORY STATUS"
    puts "=" * 70
    puts ""
    
    # Current process
    current_rss = `ps -o rss= -p #{Process.pid}`.to_i / 1024
    puts "Rails process (current): #{current_rss} MB"
    puts ""
    
    # Find related processes
    processes = {
      "agrr daemon" => "agrr daemon",
      "Solid Queue" => "solid_queue",
      "Litestream" => "litestream",
      "Puma workers" => "puma"
    }
    
    processes.each do |name, pattern|
      pids = `pgrep -f "#{pattern}"`.split.map(&:strip).reject(&:empty?)
      
      if pids.any?
        total_memory = 0
        pids.each do |pid|
          memory = `ps -o rss= -p #{pid}`.to_i / 1024
          total_memory += memory
        end
        
        puts "#{name}: #{total_memory} MB (#{pids.size} process#{pids.size > 1 ? 'es' : ''})"
      else
        puts "#{name}: Not running"
      end
    end
    
    puts ""
    puts "System memory:"
    if system("which free > /dev/null 2>&1")
      system("free -h | grep -E 'Mem:|Swap:'")
    else
      puts "(free command not available)"
    end
    
    puts ""
    puts "=" * 70
  end
  
  desc "Monitor memory usage over time"
  task :monitor, [:duration] => :environment do |t, args|
    duration = (args[:duration] || 60).to_i
    interval = 5
    iterations = duration * 60 / interval
    
    puts "=" * 70
    puts "MEMORY MONITORING"
    puts "=" * 70
    puts "Duration: #{duration} minutes"
    puts "Interval: #{interval} seconds"
    puts ""
    
    output_dir = Rails.root.join('tmp', 'memory_monitoring')
    FileUtils.mkdir_p(output_dir)
    
    timestamp = Time.current.strftime('%Y%m%d_%H%M%S')
    output_file = output_dir.join("rails_memory_#{timestamp}.csv")
    
    File.open(output_file, 'w') do |f|
      f.puts "timestamp,rss_mb,heap_used_mb,heap_free_mb,gc_count"
      
      iterations.times do |i|
        GC.start if i % 12 == 0  # Force GC every minute
        
        rss = `ps -o rss= -p #{Process.pid}`.to_i / 1024
        stat = GC.stat
        heap_used = stat[:heap_live_slots] * 40 / 1024.0 / 1024.0  # Approximate
        heap_free = stat[:heap_free_slots] * 40 / 1024.0 / 1024.0
        gc_count = stat[:count]
        
        timestamp = Time.current.strftime('%Y-%m-%d %H:%M:%S')
        f.puts "#{timestamp},#{rss},#{heap_used.round(2)},#{heap_free.round(2)},#{gc_count}"
        f.flush
        
        print "\rProgress: #{i + 1}/#{iterations} (#{((i + 1) * 100.0 / iterations).round(1)}%) - RSS: #{rss} MB"
        
        sleep interval
      end
    end
    
    puts ""
    puts ""
    puts "Monitoring complete!"
    puts "Data saved to: #{output_file}"
    puts ""
    puts "To analyze:"
    puts "  rails memory:analyze[#{output_file}]"
  end
  
  desc "Analyze memory monitoring data"
  task :analyze, [:csv_file] => :environment do |t, args|
    unless args[:csv_file]
      puts "Usage: rails memory:analyze[path/to/csv]"
      exit 1
    end
    
    unless File.exist?(args[:csv_file])
      puts "Error: File not found: #{args[:csv_file]}"
      exit 1
    end
    
    require 'csv'
    
    data = CSV.read(args[:csv_file], headers: true)
    
    if data.empty?
      puts "Error: No data in CSV file"
      exit 1
    end
    
    rss_values = data['rss_mb'].map(&:to_f)
    
    min_rss = rss_values.min
    max_rss = rss_values.max
    avg_rss = rss_values.sum / rss_values.size
    
    # Calculate growth rate
    early_count = [rss_values.size / 10, 1].max
    late_count = [rss_values.size / 10, 1].max
    
    early_avg = rss_values.first(early_count).sum / early_count
    late_avg = rss_values.last(late_count).sum / late_count
    
    growth_rate = ((late_avg - early_avg) / early_avg * 100).round(2)
    
    puts "=" * 70
    puts "MEMORY ANALYSIS"
    puts "=" * 70
    puts "File: #{args[:csv_file]}"
    puts "Samples: #{data.size}"
    puts ""
    puts "RSS Memory:"
    puts "  Min:     #{min_rss.round(2)} MB"
    puts "  Max:     #{max_rss.round(2)} MB"
    puts "  Average: #{avg_rss.round(2)} MB"
    puts "  Growth:  #{growth_rate}% (first 10% vs last 10%)"
    puts ""
    
    if growth_rate > 10
      puts "⚠️  WARNING: Significant memory growth detected!"
      puts "   This may indicate a memory leak."
      puts ""
      puts "   Recommended actions:"
      puts "   1. Review recent code changes"
      puts "   2. Check for unclosed resources (files, DB connections)"
      puts "   3. Profile specific jobs with: rails memory:profile_job[JobName]"
      puts "   4. Enable detailed Ruby profiling with memory_profiler gem"
    elsif growth_rate > 5
      puts "⚠️  Memory usage increased moderately."
      puts "   Continue monitoring for trends."
    else
      puts "✓ Memory usage appears stable."
    end
    
    puts ""
    puts "=" * 70
  end
end

