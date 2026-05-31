# frozen_string_literal: true

# Idempotent load for reference pests / agricultural tasks (data migrations).
# Run after scripts/load_development_reference_fixtures.rb (needs reference crops).

def run_migration_up(path)
  full = Rails.root.join(path)
  class_name = File.read(full).match(/^class (\w+)/)&.[](1)
  raise "No class in #{path}" unless class_name

  load full
  m = class_name.constantize.new
  m.define_singleton_method(:say) { |msg, _subtask = false| puts msg }
  m.up
end

jp_pests = Pest.where(is_reference: true, region: "jp").count
if jp_pests.zero?
  puts "Loading Japan reference pests..."
  run_migration_up("db/migrate_archive/20251108134917_data_migration_japan_reference_pests.rb")
else
  puts "Japan reference pests already present (#{jp_pests})"
end

us_pests = Pest.where(is_reference: true, region: "us").count
if us_pests.zero?
  puts "Loading US reference pests..."
  run_migration_up("db/migrate_archive/20251108112037_data_migration_united_states_reference_pests.rb")
else
  puts "US reference pests already present (#{us_pests})"
end

in_pests = Pest.where(is_reference: true, region: "in").count
if in_pests.zero?
  puts "Loading India reference pests..."
  run_migration_up("db/migrate_archive/20251108112943_data_migration_india_reference_pests.rb")
else
  puts "India reference pests already present (#{in_pests})"
end

# Task migrations reference dropped agricultural_task_crops; use same JSON as agrr-migrate.
jp_tasks = AgriculturalTask.where(is_reference: true, region: "jp").count
us_tasks = AgriculturalTask.where(is_reference: true, region: "us").count
in_tasks = AgriculturalTask.where(is_reference: true, region: "in").count
if jp_tasks.zero? || us_tasks.zero? || in_tasks.zero?
  puts "Loading reference agricultural tasks from extracted JSON (jp/in/us)..."
  load Rails.root.join("scripts/apply_extracted_reference_tasks.rb")
else
  puts "Reference tasks already present (jp=#{jp_tasks} us=#{us_tasks} in=#{in_tasks})"
end

puts "Done: jp_pests=#{Pest.where(is_reference: true, region: 'jp').count} " \
     "us_pests=#{Pest.where(is_reference: true, region: 'us').count} " \
     "in_pests=#{Pest.where(is_reference: true, region: 'in').count} " \
     "jp_tasks=#{AgriculturalTask.where(is_reference: true, region: 'jp').count} " \
     "us_tasks=#{AgriculturalTask.where(is_reference: true, region: 'us').count} " \
     "in_tasks=#{AgriculturalTask.where(is_reference: true, region: 'in').count}"
