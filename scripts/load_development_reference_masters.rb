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
  run_migration_up("db/migrate/20251108134917_data_migration_japan_reference_pests.rb")
else
  puts "Japan reference pests already present (#{jp_pests})"
end

us_pests = Pest.where(is_reference: true, region: "us").count
if us_pests.zero?
  puts "Loading US reference pests..."
  run_migration_up("db/migrate/20251108112037_data_migration_united_states_reference_pests.rb")
else
  puts "US reference pests already present (#{us_pests})"
end

jp_tasks = AgriculturalTask.where(is_reference: true, region: "jp").count
if jp_tasks.zero?
  if ActiveRecord::Base.connection.table_exists?(:agricultural_task_crops)
    puts "Loading Japan reference agricultural tasks..."
    run_migration_up("db/migrate/20251110191500_data_migration_japan_reference_tasks.rb")
  else
    puts "Skipping Japan reference agricultural tasks (agricultural_task_crops table removed; US tasks still load)"
  end
else
  puts "Japan reference tasks already present (#{jp_tasks})"
end

us_tasks = AgriculturalTask.where(is_reference: true, region: "us").count
if us_tasks.zero?
  puts "Loading US reference agricultural tasks..."
  run_migration_up("db/migrate/20251107193000_data_migration_united_states_reference_tasks.rb")
else
  puts "US reference tasks already present (#{us_tasks})"
end

puts "Done: jp_pests=#{Pest.where(is_reference: true, region: 'jp').count} " \
     "us_pests=#{Pest.where(is_reference: true, region: 'us').count} " \
     "jp_tasks=#{AgriculturalTask.where(is_reference: true, region: 'jp').count} " \
     "us_tasks=#{AgriculturalTask.where(is_reference: true, region: 'us').count}"
