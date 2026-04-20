#!/usr/bin/env ruby
# frozen_string_literal: true
#
# エントリ作物スケジュール: 気象ペイロードの形（フラット vs 二重 data）による挙動差を再現・確認する。
#
# 使い方:
#   bundle exec rails runner scripts/reproduce_entry_schedule_weather_payload.rb
#
# 期待: 「ネストした data」でも normalize 後は日次配列・緯度経度が取れること。

rows = (1..3).map do |d|
  {
    'time' => "2026-05-#{d.to_s.rjust(2, '0')}",
    'temperature_2m_min' => 8.0,
    'temperature_2m_max' => 22.0,
    'temperature_2m_mean' => 15.0
  }
end

flat = {
  'latitude' => 35.0,
  'longitude' => 139.0,
  'data' => rows
}

nested = {
  'data' => {
    'data' => rows,
    'latitude' => 35.5,
    'longitude' => 139.7
  },
  'prediction_end_date' => '2026-12-31'
}

norm_flat = CropSchedule::EntryAgrrOptimization.normalize_entry_weather_payload(flat)
norm_nested = CropSchedule::EntryAgrrOptimization.normalize_entry_weather_payload(nested)

puts '=== Entry schedule weather payload reproduction ==='
puts "Flat:   data.size=#{Array(norm_flat['data']).size} lat=#{norm_flat['latitude']} lon=#{norm_flat['longitude']}"
puts "Nested: data.size=#{Array(norm_nested['data']).size} lat=#{norm_nested['latitude']} lon=#{norm_nested['longitude']}"

# 正規化なしだと nested はトップの data が Array ではないため「日次が取れない」状態を再現
raw_top = nested['data']
puts "\nWithout normalization (nested): top['data'].class=#{raw_top.class} (Array needed for CLI weather file)"

if norm_nested['data'].is_a?(Array) && norm_nested['data'].size == rows.size
  puts "\nOK: nested payload normalizes to flat AGRR-shaped JSON."
  exit 0
else
  puts "\nFAIL: nested payload did not normalize correctly."
  exit 1
end
