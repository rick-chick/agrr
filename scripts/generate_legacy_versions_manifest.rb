#!/usr/bin/env ruby
# frozen_string_literal: true

# Generates crates/agrr-migrate/manifest/legacy_versions.yaml from db/migrate_archive/*.rb
require "yaml"
require "fileutils"

ROOT = File.expand_path("..", __dir__)

def classify(path)
  name = File.basename(path, ".rb").sub(/^\d+_/, "")
  body = File.read(path)

  data = name.match?(/\A(seed_|data_migration|load_all_fixtures)/) ||
         (body.include?("seed_") && !body.match?(/\A\s*def\s+change\b/))
  ddl = body.match?(/create_table|add_column|remove_column|drop_table|rename_table|change_table/) ||
        name.match?(/\A(create_|add_|remove_|drop_|rename_|change_)/)
  tag = if data && ddl then "mixed"
        elsif data then "data"
        else "ddl"
        end

  region = if name.include?("japan") || name.match?(/_japan_/) then "jp"
           elsif name.include?("india") || name.match?(/_india_/) then "in"
           elsif name.include?("united_states") || name.match?(/_us_/) then "us"
           else "all"
           end

  kind = if name.include?("pest") then "pests"
         elsif name.include?("crop_task_template") then "templates"
         elsif name.include?("task") && name.include?("reference") then "tasks"
         elsif name.include?("nutrient") then "nutrients"
         elsif name.include?("fixture") then "dev_fixtures"
         elsif name.include?("reference_data") || name.start_with?("seed_") then "base"
         end

  version = File.basename(path, ".rb")[/^\d+/]
  {
    "version" => version,
    "file" => path.delete_prefix("#{ROOT}/"),
    "tag" => tag,
    "region" => region,
    "kind" => kind,
    "name" => name
  }
end

entries = Dir.glob("#{ROOT}/db/migrate_archive/*.rb").sort.map { |p| classify(p) }
cache_entries = Dir.glob("#{ROOT}/db/cache_migrate_archive/*.rb").sort.map do |p|
  classify(p).merge("database" => "cache")
end
cable_entries = Dir.glob("#{ROOT}/db/cable_migrate_archive/*.rb").sort.map do |p|
  classify(p).merge("database" => "cable")
end

manifest = {
  "generated_at" => Time.now.utc.strftime("%Y-%m-%dT%H:%M:%SZ"),
  "primary" => entries,
  "cache" => cache_entries,
  "cable" => cable_entries
}

out = File.join(ROOT, "crates/agrr-migrate/manifest/legacy_versions.yaml")
FileUtils.mkdir_p(File.dirname(out))
File.write(out, manifest.to_yaml)
puts "Wrote #{out} (#{entries.size} primary, #{cache_entries.size} cache, #{cable_entries.size} cable)"
