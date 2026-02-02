# frozen_string_literal: true
#
# Slow test detector for Minitest
# - 設定:
#   - SLOW_TEST_THRESHOLD (秒) デフォルト 0.5
#   - SLOW_TEST_FAIL=1 を設定すると遅いテストが見つかった場合に非0で終了する

require 'benchmark'
require 'minitest'

module SlowTestDetector
  THRESHOLD = (ENV['SLOW_TEST_THRESHOLD'] || '0.5').to_f # seconds
  @slow_tests = []

  class << self
    attr_reader :slow_tests

    def record(name, time, location = nil)
      @slow_tests << { name: name, time: time, location: location }
    end

    def report
      return if @slow_tests.empty?

      puts "\n=== Slow tests detected (threshold: #{THRESHOLD}s) ==="
      @slow_tests.sort_by { |t| -t[:time] }.each do |t|
        loc = t[:location] ? " (#{t[:location]})" : ""
        puts format("  %.3fs - %s%s", t[:time], t[:name], loc)
      end

      if ENV['SLOW_TEST_FAIL'] == '1'
        puts "Failing test run because SLOW_TEST_FAIL=1"
        exit 2
      end
    end
  end
end

module Minitest
  class Test
    unless method_defined?(:run_with_slow_detection)
      alias_method :run_without_slow_detection, :run

      def run
        result = nil
        time = Benchmark.realtime do
          result = run_without_slow_detection
        end

        if time > SlowTestDetector::THRESHOLD
          location = self.class.respond_to?(:name) ? self.class.name : nil
          SlowTestDetector.record(self.name, time, location)
        end

        result
      end
    end
  end
end

Minitest.after_run do
  SlowTestDetector.report
end

