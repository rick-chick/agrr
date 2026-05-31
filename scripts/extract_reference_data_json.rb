#!/usr/bin/env ruby
# frozen_string_literal: true

# Build-time extractor: writes committed JSON under crates/agrr-migrate/data/extracted/.
# Runtime `agrr-migrate data apply` does NOT invoke Ruby.
#
# Usage: bundle exec ruby scripts/extract_reference_data_json.rb

require "json"
require "fileutils"

ROOT = File.expand_path("..", __dir__)
OUT = File.join(ROOT, "crates/agrr-migrate/data/extracted")

TASK_FILES = {
  "jp" => "20251110191500_data_migration_japan_reference_tasks.rb",
  "us" => "20251107193000_data_migration_united_states_reference_tasks.rb",
  "in" => "20251107194500_data_migration_india_reference_tasks.rb"
}.freeze

PEST_ARCHIVE_FILES = {
  "jp" => "20251108134917_data_migration_japan_reference_pests.rb",
  "us" => "20251108112037_data_migration_united_states_reference_pests.rb",
  "in" => "20251108112943_data_migration_india_reference_pests.rb"
}.freeze

def write_json(rel, payload)
  path = File.join(OUT, rel)
  FileUtils.mkdir_p(File.dirname(path))
  File.write(path, JSON.pretty_generate(payload))
  puts "wrote #{path}"
end

def load_migration_class(filename)
  require "bundler/setup"
  require_relative "../config/environment"

  path = File.join(ROOT, "db/migrate_archive", filename)
  contents = File.read(path)
  class_name = contents[/^class (\w+)/, 1]
  raise "no class in #{filename}" unless class_name

  load path
  Object.const_get(class_name)
end

def extract_tasks
  TASK_FILES.each do |region, file|
    klass = load_migration_class(file)
    defs = klass::TASK_DEFINITIONS
    tasks = defs.map do |name, attrs|
      {
        "name" => name,
        "description" => attrs[:description],
        "time_per_sqm" => attrs[:time_per_sqm],
        "weather_dependency" => attrs[:weather_dependency],
        "required_tools" => attrs[:required_tools],
        "skill_level" => attrs[:skill_level]
      }
    end
    write_json("tasks/#{region}.json", { "tasks" => tasks })
  end
end

def extract_templates
  klass = load_migration_class("20251113211624_data_migration_japan_reference_crop_task_templates.rb")
  defs = klass::TASK_DEFINITIONS
  templates = []
  defs.each do |task_name, attrs|
    attrs[:crops].each do |crop_name|
      templates << {
        "task_name" => task_name,
        "crop_name" => crop_name,
        "description" => attrs[:description],
        "time_per_sqm" => attrs[:time_per_sqm],
        "weather_dependency" => attrs[:weather_dependency],
        "required_tools" => attrs[:required_tools],
        "skill_level" => attrs[:skill_level]
      }
    end
  end
  write_json("templates/jp.json", { "templates" => templates })
end

def extract_pests_from_db
  load_migration_class(TASK_FILES["jp"]) # ensure AR loaded once

  %w[jp us in].each do |region|
    pests = []
    Pest.where(is_reference: true, region: region).find_each do |pest|
      pests << {
        "name" => pest.name,
        "name_scientific" => pest.name_scientific,
        "family" => pest.family,
        "order" => pest.order,
        "description" => pest.description,
        "occurrence_season" => pest.occurrence_season,
        "temperature_profile" => pest.pest_temperature_profile&.then { |tp|
          {
            "base_temperature" => tp.base_temperature,
            "max_temperature" => tp.max_temperature
          }
        },
        "thermal_requirement" => pest.pest_thermal_requirement&.then { |tr|
          {
            "required_gdd" => tr.required_gdd,
            "first_generation_gdd" => tr.first_generation_gdd
          }
        },
        "control_methods" => pest.pest_control_methods.map { |cm|
          {
            "method_type" => cm.method_type,
            "method_name" => cm.method_name,
            "description" => cm.description,
            "timing_hint" => cm.timing_hint
          }
        },
        "crop_names" => pest.crops.where(is_reference: true, region: region).pluck(:name)
      }
    end
    write_json("pests/#{region}.json", { "pests" => pests })
  end
end

def crop_links_from_archive(file)
  text = File.read(File.join(ROOT, "db/migrate_archive", file))
  links = Hash.new { |h, k| h[k] = [] }
  current_pest = nil
  text.each_line do |line|
    if (m = line.match(/TempPest\.find_or_initialize_by\(name:\s*"([^"]+)"/))
      current_pest = m[1]
    elsif (m = line.match(/TempCrop\.find_by\(name:\s*"([^"]+)"/))
      next unless current_pest

      crop = m[1]
      links[current_pest] << crop unless links[current_pest].include?(crop)
    end
  end
  links
end

def enrich_pest_crop_names_from_archive
  PEST_ARCHIVE_FILES.each do |region, file|
    path = File.join(OUT, "pests/#{region}.json")
    unless File.exist?(path)
      puts "skip pests/#{region}.json (missing)"
      next
    end

    data = JSON.parse(File.read(path))
    links = crop_links_from_archive(file)
    data["pests"].each do |pest|
      archive_names = links[pest["name"]] || []
      next if archive_names.empty?

      pest["crop_names"] = (pest["crop_names"] + archive_names).uniq
    end
    write_json("pests/#{region}.json", data)
  end
end

def main
  extract_tasks
  extract_templates
  extract_pests_from_db
  enrich_pest_crop_names_from_archive
end

main if __FILE__ == $PROGRAM_NAME
