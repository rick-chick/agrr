#!/usr/bin/env ruby
# frozen_string_literal: true

# Applies committed extracted JSON (same source as agrr-migrate tasks/*.json).
# Used when legacy task migrations noop on current schema (jp) or for parity with Rust.

require "json"

ROOT = File.expand_path("..", __dir__)
EXTRACTED = File.join(ROOT, "crates/agrr-migrate/data/extracted/tasks")

def apply_region(region)
  path = File.join(EXTRACTED, "#{region}.json")
  raise "missing #{path}" unless File.exist?(path)

  payload = JSON.parse(File.read(path))
  now = Time.current
  count = 0

  payload["tasks"].each do |row|
    task = AgriculturalTask.find_or_initialize_by(
      name: row["name"],
      region: region,
      is_reference: true
    )
    task.assign_attributes(
      description: row["description"],
      time_per_sqm: row["time_per_sqm"],
      weather_dependency: row["weather_dependency"],
      required_tools: row["required_tools"].to_json,
      skill_level: row["skill_level"],
      user_id: nil,
      is_reference: true,
      region: region
    )
    task.save!
    count += 1
  end

  puts "  tasks/#{region}: #{count} agricultural_tasks upserted from JSON"
  count
end

%w[jp in us].each { |r| apply_region(r) }
