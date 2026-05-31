#!/usr/bin/env ruby
# frozen_string_literal: true

# Rails path: agrr-migrate schema + migrate_archive data + extracted tasks JSON
# Rust path:  agrr-migrate schema + data apply
# Parity: sqlite3 .schema diff (structure) and normalized .dump INSERT diff (data).
#
#   bundle exec ruby scripts/compare_rails_rust_migration_parity.rb
#   bundle exec ruby scripts/compare_rails_rust_migration_parity.rb --schema-only

require "open3"
require "fileutils"
require "yaml"

ROOT = File.expand_path("..", __dir__)
TMP = File.join(ROOT, "tmp", "migration_parity")
RAILS_DB = File.join(TMP, "rails.sqlite3")
RUST_DB = File.join(TMP, "rust.sqlite3")
MANIFEST = File.join(ROOT, "crates/agrr-migrate/manifest/legacy_versions.yaml")

SKIP_FILES = [
  "db/migrate_archive/20260222191715_load_all_fixtures.rb"
].freeze

NUTRIENT_SEED_METHODS = %i[
  seed_japan_nutrient_requirements
  seed_india_nutrient_requirements
  seed_united_states_nutrient_requirements
].freeze

DUMP_IGNORE_TABLES = %w[
  sqlite_sequence
  refinery_schema_history
  data_migration_history
].freeze

def run!(cmd, env: {}, chdir: ROOT)
  puts ">> #{cmd.join(' ')}"
  stdout, stderr, status = Open3.capture3(env, *cmd, chdir: chdir)
  puts stdout unless stdout.empty?
  warn stderr unless stderr.empty?
  raise "command failed: #{cmd.join(' ')}" unless status.success?
end

def manifest_entries
  YAML.load_file(MANIFEST).fetch("primary").sort_by { |e| e.fetch("version") }
end

def prepare_dirs
  FileUtils.mkdir_p(TMP)
  [RAILS_DB, RUST_DB].each { |f| File.delete(f) if File.exist?(f) }
end

def agrr_env(db_path, cache_label)
  {
    "AGRR_APP_ROOT" => ROOT,
    "AGRR_SQLITE_PATH" => db_path,
    "AGRR_CACHE_SQLITE_PATH" => File.join(TMP, "#{cache_label}_cache.sqlite3")
  }
end

def agrr_migrate_cmd(*args)
  bin = File.join(ROOT, "target/debug/agrr-migrate")
  if File.executable?(bin)
    [bin, *args]
  else
    ["cargo", "run", "-p", "agrr-migrate", "--", *args]
  end
end

def apply_schema!(db_path, cache_label)
  run!(agrr_migrate_cmd("schema", "run"), env: agrr_env(db_path, cache_label))
end

def apply_rust_data!
  kinds = "base,nutrients,pests,tasks,templates"
  puts "  agrr-migrate data apply --kind #{kinds}"
  run!(
    agrr_migrate_cmd("data", "apply", "--region", "jp,in,us", "--kind", kinds),
    env: agrr_env(RUST_DB, "rust")
  )
end

def setup_rails_db!
  require "bundler/setup"
  require_relative "../config/environment"
  ActiveRecord::Base.establish_connection(adapter: "sqlite3", database: RAILS_DB)
  ActiveRecord::Base.connection.schema_cache.clear!
  [User, Farm, Crop, Pest, AgriculturalTask].each(&:reset_column_information)
end

def run_migration_up(path)
  full = File.join(ROOT, path)
  class_name = File.read(full).match(/^class (\w+)/)&.[](1)
  raise "No class in #{path}" unless class_name

  load full
  m = class_name.constantize.new
  m.define_singleton_method(:say) { |msg, _subtask = false| puts "    #{msg}" }
  m.define_singleton_method(:say_with_time) do |msg, &block|
    print("    #{msg}")
    $stdout.flush
    r = block.call
    puts
    r
  end
  m.up
end

def run_migration_seed_only(path)
  full = File.join(ROOT, path)
  class_name = File.read(full).match(/^class (\w+)/)&.[](1)
  raise "No class in #{path}" unless class_name

  load full
  m = class_name.constantize.new
  m.define_singleton_method(:say) { |msg, _subtask = false| puts "    #{msg}" }
  m.define_singleton_method(:say_with_time) do |msg, &block|
    print("    #{msg}")
    $stdout.flush
    r = block.call
    puts
    r
  end

  method = NUTRIENT_SEED_METHODS.find { |meth| m.respond_to?(meth, true) }
  raise "no nutrient seed method in #{path}" unless method

  puts "    (seed only via #{method})"
  m.send(method)
end

def run_archive_data_migration(path, kind)
  run_migration_up(path)
rescue ActiveRecord::StatementInvalid => e
  if kind == "nutrients" && (e.message.include?("duplicate column name") || e.message.include?("already exists"))
    puts "    (DDL in baseline; running seed only)"
    run_migration_seed_only(path)
  else
    raise
  end
end

def apply_rails_data_migrations!
  setup_rails_db!

  data_entries = manifest_entries.select do |e|
    %w[data mixed].include?(e["tag"]) &&
      e["kind"].present? &&
      e["kind"] != "blueprints" &&
      e["kind"] != "dev_fixtures" &&
      !SKIP_FILES.include?(e["file"])
  end

  data_entries.reject { |e| %w[tasks templates].include?(e["kind"]) }.each do |entry|
    next if entry["kind"] == "tasks"

    puts "  [archive] #{entry['name']} (#{entry['region']}/#{entry['kind']})"
    run_archive_data_migration(entry["file"], entry["kind"])
  end

  puts "  [json] reference tasks (jp/in/us)"
  load File.join(ROOT, "scripts/apply_extracted_reference_tasks.rb")

  data_entries.select { |e| e["kind"] == "nutrients" }.each do |entry|
    puts "  [archive] #{entry['name']} (#{entry['region']}/nutrients)"
    run_archive_data_migration(entry["file"], "nutrients")
  end

  data_entries.select { |e| e["kind"] == "templates" }.each do |entry|
    puts "  [archive] #{entry['name']} (#{entry['region']}/templates)"
    run_migration_up(entry["file"])
  end
end

def sqlite3_capture(db_path, *args)
  stdout, stderr, status = Open3.capture3("sqlite3", db_path, *args)
  raise "sqlite3 failed: #{stderr}" unless status.success?

  stdout
end

def schema_dump_text(db_path)
  sqlite3_capture(db_path, ".schema").lines.map(&:rstrip).reject(&:empty?).sort.join("\n")
end

def normalize_insert_line(line)
  # sqlite3 .dump uses INSERT INTO farms VALUES(...) (often unquoted identifiers).
  table = line[/INSERT INTO (?:"([^"]+)"|([A-Za-z_][A-Za-z0-9_]*))/, 1] || line[/INSERT INTO (?:"([^"]+)"|([A-Za-z_][A-Za-z0-9_]*))/, 2]
  return nil if table.nil? || DUMP_IGNORE_TABLES.include?(table)

  line = line.rstrip
  line = line.gsub(/'\d{4}-\d{2}-\d{2}[ T][^']*'/, "'TS'")
  line.sub(/VALUES\(\d+,/, "VALUES(?,")
end

def data_dump_text(db_path)
  sqlite3_capture(db_path, ".dump")
    .lines
    .filter_map { |line| normalize_insert_line(line.rstrip) }
    .sort
    .join("\n")
end

def write_diff(left_path, right_path, left_body, right_body)
  File.write(left_path, left_body)
  File.write(right_path, right_body)
  out, status = Open3.capture2e("diff", "-u", left_path, right_path)
  return [] if status.success?

  out.lines
end

def diff_databases!(label)
  left = File.join(TMP, "rails.#{label}.txt")
  right = File.join(TMP, "rust.#{label}.txt")
  rails_body = yield(RAILS_DB)
  rust_body = yield(RUST_DB)
  write_diff(left, right, rails_body, rust_body)
end

def report_diffs(label, diffs)
  if diffs.empty?
    puts "  OK (#{label})"
    return true
  end

  puts "  FAIL (#{label}, #{diffs.size} diff lines):"
  diffs.first(80).each { |line| puts "    #{line.chomp}" }
  puts "    ..." if diffs.size > 80
  puts "    full: diff -u #{File.join(TMP, "rails.#{label}.txt")} #{File.join(TMP, "rust.#{label}.txt")}"
  false
end

def main
  schema_only = ARGV.include?("--schema-only")

  prepare_dirs

  if schema_only
    puts "\n==> Schema only"
    apply_schema!(RAILS_DB, "rails")
    apply_schema!(RUST_DB, "rust")
  else
    puts "\n==> Rust: schema + data apply"
    apply_schema!(RUST_DB, "rust")
    apply_rust_data!

    puts "\n==> Rails: schema + migrate_archive data + tasks JSON"
    apply_schema!(RAILS_DB, "rails")
    apply_rails_data_migrations!
  end

  puts "\n==> Schema (.schema diff)"
  schema_ok = report_diffs("schema", diff_databases!("schema") { |db| schema_dump_text(db) })

  if schema_only
    exit(schema_ok ? 0 : 1)
  end

  puts "\n==> Data (INSERT lines from .dump, id/timestamp normalized)"
  data_ok = report_diffs("data", diff_databases!("data") { |db| data_dump_text(db) })
  exit(schema_ok && data_ok ? 0 : 1)
end

main if __FILE__ == $PROGRAM_NAME
