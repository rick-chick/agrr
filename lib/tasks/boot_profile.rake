# frozen_string_literal: true

namespace :boot do
  desc "Profile Rails cold boot time (spawns subprocess for accurate measurement)"
  task profile: [] do
    require "benchmark"

    puts "=" * 60
    puts "Rails Cold Boot Profiling"
    puts "=" * 60
    puts ""
    puts "Measuring cold boot via 'rails runner' (subprocess)..."
    puts ""

    elapsed = Benchmark.realtime do
      system("bundle exec rails runner 'puts :loaded'", out: $stdout, err: $stderr)
    end

    puts ""
    puts "Cold boot time: #{(elapsed * 1000).round}ms (#{elapsed.round(2)}s)"
    puts ""
    puts "For production-like measurement, run:"
    puts "  RAILS_ENV=production bundle exec rails boot:profile"
    puts ""
    puts "For flamegraph with rbspy:"
    puts "  rbspy record -f summary -- bundle exec rails server"
    puts "  (Ctrl+C to stop, then inspect rbspy output)"
    puts ""
  end
end
