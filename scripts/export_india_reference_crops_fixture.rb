#!/usr/bin/env ruby
# frozen_string_literal: true

# Export db/fixtures/india_reference_crops.json from a SQLite primary DB.
# Source of truth: production reference crops (region=in, is_reference=1) with crop_stages.
#
# Usage:
#   bundle exec ruby scripts/export_india_reference_crops_fixture.rb [path/to/primary.sqlite3]
#   DBPATH=$(KEEP_DB=1 .../query_production_primary_sqlite.sh 2>&1 | tail -1) && \
#     bundle exec ruby scripts/export_india_reference_crops_fixture.rb "$DBPATH"

require "json"
require "sqlite3"

ROOT = File.expand_path("..", __dir__)
OUT = File.join(ROOT, "db/fixtures/india_reference_crops.json")

db_path = ARGV[0] || ENV.fetch("AGRR_SQLITE_PATH", nil)
raise "usage: #{$PROGRAM_NAME} path/to/primary.sqlite3" unless db_path && File.file?(db_path)

db = SQLite3::Database.new(db_path)
db.results_as_hash = true

crops = db.execute(<<~SQL)
  SELECT id, name, variety, area_per_unit, revenue_per_area, groups
  FROM crops
  WHERE region = 'in' AND is_reference = 1
  ORDER BY id
SQL

fixture = {}

crops.each do |crop|
  crop_id = crop["id"]
  key = crop["name"]
  groups = JSON.parse(crop["groups"].to_s.empty? ? "[]" : crop["groups"])

  stage_rows = db.execute(<<~SQL, [crop_id])
    SELECT id, name, "order" AS stage_order
    FROM crop_stages
    WHERE crop_id = ?
    ORDER BY "order"
  SQL

  stages = stage_rows.map do |stage|
    stage_id = stage["id"]
    temp = db.get_first_row(<<~SQL, [stage_id])
      SELECT base_temperature, optimal_min, optimal_max, low_stress_threshold,
             high_stress_threshold, frost_threshold, sterility_risk_threshold, max_temperature
      FROM temperature_requirements WHERE crop_stage_id = ?
    SQL

    sun = db.get_first_row(<<~SQL, [stage_id])
      SELECT minimum_sunshine_hours, target_sunshine_hours
      FROM sunshine_requirements WHERE crop_stage_id = ?
    SQL

    thermal = db.get_first_row(<<~SQL, [stage_id])
      SELECT required_gdd FROM thermal_requirements WHERE crop_stage_id = ?
    SQL

    entry = {
      "name" => stage["name"],
      "order" => stage["stage_order"]
    }
    if temp
      entry["temperature_requirement"] = {
        "base_temperature" => temp["base_temperature"],
        "optimal_min" => temp["optimal_min"],
        "optimal_max" => temp["optimal_max"],
        "low_stress_threshold" => temp["low_stress_threshold"],
        "high_stress_threshold" => temp["high_stress_threshold"],
        "frost_threshold" => temp["frost_threshold"],
        "sterility_risk_threshold" => temp["sterility_risk_threshold"],
        "max_temperature" => temp["max_temperature"]
      }
    end
    if sun
      entry["sunshine_requirement"] = {
        "minimum_sunshine_hours" => sun["minimum_sunshine_hours"],
        "target_sunshine_hours" => sun["target_sunshine_hours"]
      }
    end
    if thermal
      entry["thermal_requirement"] = { "required_gdd" => thermal["required_gdd"] }
    end
    entry
  end

  fixture[key] = {
    "name" => key,
    "variety" => crop["variety"],
    "is_reference" => true,
    "region" => "in",
    "area_per_unit" => crop["area_per_unit"],
    "revenue_per_area" => crop["revenue_per_area"],
    "groups" => groups,
    "crop_stages" => stages
  }
end

raise "no in reference crops in #{db_path}" if fixture.empty?

File.write(OUT, JSON.pretty_generate(fixture))
puts "wrote #{OUT} (#{fixture.size} crops)"
