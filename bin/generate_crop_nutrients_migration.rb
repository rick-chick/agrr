#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'open3'
require 'time'
require 'timeout'

require_relative '../config/environment'

class ColorLogger
  COLORS = { red: "\e[31m", green: "\e[32m", yellow: "\e[33m", blue: "\e[34m", reset: "\e[0m" }
  def self.log(message, color = :reset); puts "#{COLORS[color]}#{message}#{COLORS[:reset]}"; end
  def self.info(m); log("ℹ️  #{m}", :blue); end
  def self.success(m); log("✅ #{m}", :green); end
  def self.warning(m); log("⚠️  #{m}", :yellow); end
  def self.error(m); log("❌ #{m}", :red); end
end

def print_help
  puts <<~HELP
Usage: bin/generate_crop_nutrients_migration.rb --region REGION [--config PATH] [--crops-file PATH] [--language CODE] [--dry-run]

Options:
  --region, -r REGION     Region code (jp, us, in)
  --config, -c PATH       Region config JSON (default: config/crop_nutrients_regions.json)
  --crops-file PATH       Override crops list JSON path
  --language CODE         Override language (ja, en, hi, ...)
  --dry-run               Print migration to STDOUT instead of writing file
  --help, -h              Show this help

Examples:
  bin/generate_crop_nutrients_migration.rb --region jp
  bin/generate_crop_nutrients_migration.rb -r us --language en
  bin/generate_crop_nutrients_migration.rb -r in --crops-file db/fixtures/india_reference_crops.json
HELP
end

region = nil
config_path = Rails.root.join('config', 'crop_nutrients_regions.json').to_s
crops_file_override = nil
language_override = nil
dry_run = false

ARGV.each_with_index do |arg, i|
  case arg
  when '--region', '-r' then region = ARGV[i + 1]
  when '--config', '-c' then config_path = ARGV[i + 1]
  when '--crops-file' then crops_file_override = ARGV[i + 1]
  when '--language' then language_override = ARGV[i + 1]
  when '--dry-run' then dry_run = true
  when '--help', '-h' then print_help; exit 0
  end
end

unless region
  ColorLogger.error('Missing --region')
  print_help
  exit 1
end

unless File.exist?(config_path)
  ColorLogger.error("Config not found: #{config_path}")
  exit 1
end

config = JSON.parse(File.read(config_path))
region_cfg = config[region]
unless region_cfg
  ColorLogger.error("Region not defined in config: #{region}")
  exit 1
end

region_name = region_cfg['name'] || region
language = language_override || region_cfg['language']
crops_file = crops_file_override || region_cfg['crops_file']

unless crops_file && File.exist?(Rails.root.join(crops_file))
  ColorLogger.error("Crops file not found: #{crops_file}")
  exit 1
end

def load_crop_names(crops_path)
  data = JSON.parse(File.read(crops_path))
  # Accept array[string], array[object{name}], or object{name=>...}
  names = []
  if data.is_a?(Array)
    data.each do |item|
      if item.is_a?(String)
        names << item
      elsif item.is_a?(Hash)
        names << item['name'] if item['name']
      end
    end
  elsif data.is_a?(Hash)
    # If exported as { "Tomato": {...}, ... }
    names = data.keys
  end
  names.uniq.compact
end

def run_agrr_crop(query, language: nil, max_retries: 3, timeout_seconds: 120)
  agrr_path = Rails.root.join('lib', 'core', 'agrr').to_s
  # Note: agrr crop doesn't support --language option, language is inferred from query
  cmd = [agrr_path, 'crop', '--query', query, '--json']
  
  attempt = 0
  while attempt < max_retries
    attempt += 1
    begin
      stdout, stderr, status = Timeout.timeout(timeout_seconds) do
        Open3.capture3(*cmd)
      end
      
      if status.success?
        return JSON.parse(stdout)
      else
        error_msg = stderr.strip
        if attempt < max_retries && (error_msg =~ /(timeout|Connection|Network|decompress)/i)
          sleep(2 ** attempt)
          next
        else
          ColorLogger.error("agrr crop failed: #{error_msg}")
          return nil
        end
      end
    rescue Timeout::Error => e
      ColorLogger.warning("agrr crop timed out after #{timeout_seconds}s (attempt #{attempt}/#{max_retries})")
      if attempt < max_retries
        sleep(2 ** attempt)
        next
      else
        ColorLogger.error("agrr crop timed out after #{max_retries} attempts")
        return nil
      end
    rescue IOError => e
      ColorLogger.warning("IO error (attempt #{attempt}/#{max_retries}): #{e.message}")
      if attempt < max_retries
        sleep(2 ** attempt)
        next
      else
        ColorLogger.error("IO error after #{max_retries} attempts: #{e.message}")
        return nil
      end
    rescue JSON::ParserError => e
      ColorLogger.error("JSON parse error: #{e.message}")
      return nil
    rescue => e
      ColorLogger.warning("Error (attempt #{attempt}/#{max_retries}): #{e.class} - #{e.message}")
      if attempt < max_retries
        sleep(2 ** attempt)
        next
      else
        ColorLogger.error("Error after #{max_retries} attempts: #{e.message}")
        return nil
      end
    end
  end
  nil
end

def extract_nutrients(profile)
  return {} unless profile.is_a?(Hash)
  reqs = profile['stage_requirements'] || []
  out = []
  reqs.each do |r|
    stage = r['stage'] || {}
    order = stage['order']
    name = stage['name']
    uptake = (((r['nutrients'] || {})['daily_uptake']) || {})
    n = uptake['N']
    p = uptake['P']
    k = uptake['K']
    next if n.nil? && p.nil? && k.nil?
    out << {
      'order' => order,
      'stage_name' => name,
      'N' => n,
      'P' => p,
      'K' => k
    }
  end
  { 'stages' => out }
end

ColorLogger.info("Region: #{region} (#{region_name}), language=#{language}")
crop_names = load_crop_names(Rails.root.join(crops_file))
if crop_names.empty?
  ColorLogger.error('No crop names found in crops file')
  exit 1
end
ColorLogger.success("Found #{crop_names.size} crop names")

all = {}
skipped = []
crop_names.each_with_index do |name, idx|
  ColorLogger.info("[#{idx + 1}/#{crop_names.size}] Fetch: #{name}")
  prof = run_agrr_crop(name, language: language)
  if prof.nil?
    ColorLogger.warning("Skip (agrr failed): #{name}")
    skipped << name
    next
  end
  nutrients = extract_nutrients(prof)
  if nutrients['stages'].nil? || nutrients['stages'].empty?
    ColorLogger.warning("Skip (no nutrients): #{name}")
    skipped << name
    next
  end
  all[name] = nutrients['stages']
  sleep 1 if idx < crop_names.size - 1
end

if all.empty?
  ColorLogger.error('No nutrients data collected; aborting')
  exit 1
end

def region_to_class(region)
  case region
  when 'jp' then 'Japan'
  when 'us' then 'UnitedStates'
  when 'in' then 'India'
  else region.capitalize
  end
end

def build_migration(region_code, region_name, stages_map)
  migration_class = "DataMigration#{region_to_class(region_code)}ReferenceCropNutrients"
  embedded = JSON.pretty_generate(stages_map)
  <<~RUBY
# frozen_string_literal: true

class #{migration_class} < ActiveRecord::Migration[8.0]
  # Temporary models (migration-only)
  class TempCrop < ActiveRecord::Base; self.table_name = 'crops'; end
  class TempCropStage < ActiveRecord::Base; self.table_name = 'crop_stages'; end
  class TempNutrientRequirement < ActiveRecord::Base; self.table_name = 'nutrient_requirements'; end

  NUTRIENTS = #{embedded}

  def up
    say "🌱 Seeding #{region_name} (#{region_code}) crop nutrients..."

    ActiveRecord::Base.transaction do
      NUTRIENTS.each do |crop_name, stages|
        crop = TempCrop.where(is_reference: true, region: '#{region_code}', name: crop_name).first
        unless crop
          say "⚠️  Crop not found: \#{crop_name}", true
          next
        end

        stages.each do |s|
          order = s['order']
          stage = TempCropStage.where(crop_id: crop.id, order: order).first
          unless stage
            # try by stage name as fallback
            stage = TempCropStage.where(crop_id: crop.id).where('LOWER(name) = ?', (s['stage_name'] || '').to_s.downcase).first
          end
          unless stage
            say "⚠️  Stage not found for crop=\#{crop_name}, order=\#{order}", true
            next
          end

          rec = TempNutrientRequirement.where(crop_stage_id: stage.id).first_or_initialize
          rec.daily_uptake_n = s['N']
          rec.daily_uptake_p = s['P']
          rec.daily_uptake_k = s['K']
          rec.save!
        end
      end
    end

    say "✅ #{region_name} crop nutrients seeding completed!"
  end

  def down
    say "🗑️  Removing #{region_name} (#{region_code}) crop nutrients..."

    crop_ids = TempCrop.where(is_reference: true, region: '#{region_code}', name: NUTRIENTS.keys).pluck(:id)
    stage_ids = TempCropStage.where(crop_id: crop_ids).pluck(:id)
    TempNutrientRequirement.where(crop_stage_id: stage_ids).delete_all

    say "✅ Removed nutrient requirements for #{region_name} crops"
  end
end
  RUBY
end

timestamp = Time.now.strftime('%Y%m%d%H%M%S')
region_file = case region
              when 'jp' then 'japan'
              when 'us' then 'united_states'
              when 'in' then 'india'
              else region
              end
filename = "#{timestamp}_data_migration_#{region_file}_reference_crop_nutrients.rb"
migration_path = Rails.root.join('db', 'migrate', filename)

content = build_migration(region, region_name, all)

if dry_run
  puts content
  ColorLogger.info('Dry run complete (no file written)')
else
  File.open(migration_path, 'w', encoding: 'UTF-8') { |f| f.write(content) }
  ColorLogger.success("Generated migration file: #{migration_path}")
  ColorLogger.info("Run 'rails db:migrate' to apply the migration")
end


