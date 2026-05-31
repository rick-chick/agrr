# frozen_string_literal: true

# Load JP/US reference masters from db/fixtures/*.json (LoadAllFixtures migration logic).
# Safe to re-run when reference farms are missing (find_or_initialize / upsert).
require Rails.root.join("db/migrate_archive/20260222191715_load_all_fixtures.rb")

m = LoadAllFixtures.new
m.define_singleton_method(:say) { |msg, _subtask = false| puts msg }
m.define_singleton_method(:say_with_time) do |msg, &block|
  print(msg)
  $stdout.flush
  t = Process.clock_gettime(Process::CLOCK_MONOTONIC)
  r = block.call
  elapsed = (Process.clock_gettime(Process::CLOCK_MONOTONIC) - t).round(1)
  puts(" (#{elapsed}s)")
  r
end

jp = Farm.where(is_reference: true, region: "jp").count
us = Farm.where(is_reference: true, region: "us").count
puts "Before: jp_farms=#{jp} us_farms=#{us} ref_crops=#{Crop.where(is_reference: true).count} weather_locs=#{WeatherLocation.count}"

if jp.positive? || us.positive?
  puts "Reference farms already present; skipping (delete reference farms first to reload)."
  exit 0
end

m.send(:seed_admin_user)
m.send(:seed_japan_reference_data)
m.send(:seed_us_reference_data)

puts "After: jp_farms=#{Farm.where(is_reference: true, region: 'jp').count} " \
     "us_farms=#{Farm.where(is_reference: true, region: 'us').count} " \
     "ref_crops=#{Crop.where(is_reference: true).count} " \
     "weather_locs=#{WeatherLocation.count} weather_data=#{WeatherDatum.count}"
