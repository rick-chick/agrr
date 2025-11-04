#!/usr/bin/env ruby
# frozen_string_literal: true

# Generate pest data migration using agrr pest-to-crop command
# This script generates a migration file with pest data using AI
#
# Usage:
#   bin/generate_pest_data_migration.rb --region jp
#   bin/generate_pest_data_migration.rb --region us
#   bin/generate_pest_data_migration.rb --region in

require 'json'
require 'open3'
require 'tempfile'

require_relative '../config/environment'

# Region-specific pest lists
PEST_LISTS = {
  'jp' => [
    "アオムシ",
    "アザミウマ",
    "アブラムシ",
    "イラガ",
    "ウリハムシ",
    "ウンカ",
    "カイガラムシ",
    "カミキリムシ",
    "カメムシ",
    "キアゲハの幼虫",
    "コガネムシ",
    "コナジラミ",
    "コオロギ",
    "ジャンボタニシ",
    "シロイチモジヨトウ",
    "センチュウ",
    "タバコガ・オオタバコガ",
    "ツマジロクサヨトウ",
    "テントウムシ",
    "テントウムシダマシ",
    "ナミアゲハの幼虫",
    "ナメクジ",
    "ネキリムシ",
    "ハダニ",
    "ハムシ",
    "ハモグリバエ",
    "マダニ",
    "メイガ",
    "ヨトウムシ"
  ].freeze,
  'us' => [
    "Spotted Lanternfly",
    "Japanese Beetle",
    "Citrus Longhorned Beetle",
    "Colorado Potato Beetle",
    "Corn Rootworm",
    "Aphid",
    "Whitefly",
    "Thrips",
    "Spider Mite",
    "Cutworm",
    "Armyworm",
    "Fall Armyworm",
    "Corn Earworm",
    "Tomato Hornworm",
    "Squash Bug",
    "Stink Bug",
    "Wireworm",
    "Flea Beetle",
    "Cabbage Looper",
    "Diamondback Moth",
    "Corn Borer",
    "Soybean Cyst Nematode",
    "Root Knot Nematode"
  ].freeze,
  'in' => [
    "टिड्डी",
    "कपास बोलवर्म",
    "धान हिस्पा",
    "गन्ना पिरिला",
    "आम मिलीबग",
    "ब्राउन प्लांट हॉपर",
    "सफेद पीठ वाला प्लांटहॉपर",
    "हरा पत्ता हॉपर",
    "धान स्टेम बोरर",
    "पीला स्टेम बोरर",
    "धान गाल मिज",
    "धान पत्ता फोल्डर",
    "धान झुंड कैटरपिलर",
    "आर्मीवर्म",
    "कपास एफिड",
    "कपास व्हाइटफ्लाई",
    "लाल कपास बग",
    "गन्ना टॉप बोरर",
    "गन्ना शूट बोरर",
    "गन्ना पत्ता हॉपर",
    "गन्ना मिलीबग",
    "लाल ताड़ वीविल",
    "नारियल गेंडा बीटल",
    "बैंगन फल और शूट बोरर",
    "टमाटर फल बोरर",
    "भिंडी फल बोरर",
    "मिर्च थ्रिप्स",
    "गोभी डायमंडबैक मोथ"
  ].freeze
}.freeze

# Region configuration
REGION_CONFIG = {
  'jp' => { name: 'Japan', code: 'jp', language: 'ja' },
  'us' => { name: 'United States', code: 'us', language: 'en' },
  'in' => { name: 'India', code: 'in', language: 'hi' }
}.freeze

# Logger with color output
class ColorLogger
  COLORS = {
    red: "\e[31m",
    green: "\e[32m",
    yellow: "\e[33m",
    blue: "\e[34m",
    reset: "\e[0m"
  }

  def self.log(message, color = :reset)
    puts "#{COLORS[color]}#{message}#{COLORS[:reset]}"
  end

  def self.info(message)
    log("ℹ️  #{message}", :blue)
  end

  def self.success(message)
    log("✅ #{message}", :green)
  end

  def self.warning(message)
    log("⚠️  #{message}", :yellow)
  end

  def self.error(message)
    log("❌ #{message}", :red)
  end
end

# Get reference crops from DB to use as affected crops
def get_reference_crops(region_code)
  crops = Crop.where(is_reference: true, region: region_code)
  crops.map do |crop|
    {
      'crop_id' => crop.id.to_s,
      'crop_name' => crop.name
    }
  end
end

# Fetch pest info from agrr pest-to-crop command (with retry logic)
def fetch_pest_info_from_agrr(pest_name, crops_json, language: 'ja', max_retries: 3)
  agrr_path = Rails.root.join('lib', 'core', 'agrr').to_s
  
  # Create temporary file for crops JSON if needed
  crops_file = nil
  if crops_json.is_a?(Array) && crops_json.length > 10
    # If crops list is long, use a file
    crops_file = Tempfile.new(['crops', '.json'])
    crops_file.write(crops_json.to_json)
    crops_file.flush
    crops_arg = crops_file.path
  else
    crops_arg = crops_json.to_json
  end

  command = [
    agrr_path,
    'pest-to-crop',
    '--pest', pest_name,
    '--crops', crops_arg,
    '--language', language
  ]

  max_retries.times do |retry_count|
    attempt = retry_count + 1
    
    begin
      stdout, stderr, status = Open3.capture3(*command)

      unless status.success?
        error_msg = stderr.strip
        
        # Retry on transient errors
        if (error_msg.include?('Connection') || 
            error_msg.include?('timeout') || 
            error_msg.include?('Network') ||
            error_msg.include?('decompressing')) && attempt < max_retries
          
          sleep_time = 2 ** attempt
          ColorLogger.warning("Transient error (attempt #{attempt}/#{max_retries}): #{error_msg}. Retrying in #{sleep_time}s...")
          sleep(sleep_time)
          next
        end
        
        ColorLogger.error("agrr command failed after #{attempt} attempts: #{error_msg}")
        return nil
      end

      parsed_data = JSON.parse(stdout)
      
      if parsed_data['success'] == false
        ColorLogger.error("agrr returned error: #{parsed_data['error']}")
        return nil
      end
      
      if attempt > 1
        ColorLogger.success("Succeeded after #{attempt} attempts")
      end
      
      return parsed_data
      
    rescue JSON::ParserError => e
      ColorLogger.error("JSON parse error: #{e.message}")
      ColorLogger.error("Raw output: #{stdout[0..500]}")
      return nil
    rescue => e
      if attempt < max_retries
        sleep_time = 2 ** attempt
        ColorLogger.warning("Error (attempt #{attempt}/#{max_retries}): #{e.message}. Retrying in #{sleep_time}s...")
        sleep(sleep_time)
        next
      end
      
      ColorLogger.error("Error after #{attempt} attempts: #{e.message}")
      return nil
    ensure
      crops_file&.close
      crops_file&.unlink
    end
  end
  
  ColorLogger.error("Failed to fetch pest info after #{max_retries} attempts")
  nil
end

# Build migration file content
def build_migration_content(pests_data, region_code, region_name)
  migration_class = case region_code
                    when 'jp' then 'DataMigrationJapanReferencePests'
                    when 'us' then 'DataMigrationUnitedStatesReferencePests'
                    when 'in' then 'DataMigrationIndiaReferencePests'
                    else "DataMigration#{region_code.upcase}ReferencePests"
                    end
  
  indent = '    '
  
  content = <<~RUBY
# frozen_string_literal: true

class #{migration_class} < ActiveRecord::Migration[8.0]
  # 一時モデル定義（マイグレーション内でのみ使用）
  # モデルクラスへの依存を避け、スキーマ変更に強い設計
  
  class TempPest < ActiveRecord::Base
    self.table_name = 'pests'
    has_one :pest_temperature_profile, class_name: '#{migration_class}::TempPestTemperatureProfile', foreign_key: 'pest_id'
    has_one :pest_thermal_requirement, class_name: '#{migration_class}::TempPestThermalRequirement', foreign_key: 'pest_id'
    has_many :pest_control_methods, class_name: '#{migration_class}::TempPestControlMethod', foreign_key: 'pest_id'
    has_many :crop_pests, class_name: '#{migration_class}::TempCropPest', foreign_key: 'pest_id'
  end
  
  class TempPestTemperatureProfile < ActiveRecord::Base
    self.table_name = 'pest_temperature_profiles'
    belongs_to :pest, class_name: '#{migration_class}::TempPest', foreign_key: 'pest_id'
  end
  
  class TempPestThermalRequirement < ActiveRecord::Base
    self.table_name = 'pest_thermal_requirements'
    belongs_to :pest, class_name: '#{migration_class}::TempPest', foreign_key: 'pest_id'
  end
  
  class TempPestControlMethod < ActiveRecord::Base
    self.table_name = 'pest_control_methods'
    belongs_to :pest, class_name: '#{migration_class}::TempPest', foreign_key: 'pest_id'
  end
  
  class TempCropPest < ActiveRecord::Base
    self.table_name = 'crop_pests'
    belongs_to :pest, class_name: '#{migration_class}::TempPest', foreign_key: 'pest_id'
    belongs_to :crop, class_name: '#{migration_class}::TempCrop', foreign_key: 'crop_id'
  end
  
  class TempCrop < ActiveRecord::Base
    self.table_name = 'crops'
  end
  
  def up
    say "🌱 Seeding #{region_name} (#{region_code}) reference pests..."
    
    seed_reference_pests
    
    say "✅ #{region_name} reference pests seeding completed!"
  end
  
  def down
    say "🗑️  Removing #{region_name} (#{region_code}) reference pests..."
    
    # Find pests by region
    pest_ids = TempPest.where(region: '#{region_code}', is_reference: true).pluck(:id)
    
    # Delete related records
    TempCropPest.where(pest_id: pest_ids).delete_all
    TempPestControlMethod.where(pest_id: pest_ids).delete_all
    TempPestThermalRequirement.where(pest_id: pest_ids).delete_all
    TempPestTemperatureProfile.where(pest_id: pest_ids).delete_all
    TempPest.where(region: '#{region_code}', is_reference: true).delete_all
    
    say "✅ #{region_name} reference pests removed"
  end
  
  private
  
  def seed_reference_pests
RUBY
  
  # Add pest data
  pests_data.each do |pest_name, pest_data|
    content << "#{indent}  # #{pest_name}\n"
    content << "#{indent}  pest = TempPest.find_or_initialize_by(name: #{pest_data['name'].inspect}, is_reference: true, region: '#{region_code}')\n"
    content << "#{indent}  pest.assign_attributes(\n"
    content << "#{indent}    user_id: nil,\n"
    content << "#{indent}    name_scientific: #{pest_data['name_scientific'].inspect},\n"
    content << "#{indent}    family: #{pest_data['family'].inspect},\n"
    content << "#{indent}    order: #{pest_data['order'].inspect},\n"
    content << "#{indent}    description: #{pest_data['description'].inspect},\n"
    content << "#{indent}    occurrence_season: #{pest_data['occurrence_season'].inspect}\n"
    content << "#{indent}  )\n"
    content << "#{indent}  pest.save!\n"
    content << "\n"
    
    # Temperature profile
    if pest_data['temperature_profile']
      temp_profile = pest_data['temperature_profile']
      content << "#{indent}  # Temperature Profile\n"
      content << "#{indent}  if pest.pest_temperature_profile.nil?\n"
      content << "#{indent}    pest.create_pest_temperature_profile!(\n"
      content << "#{indent}      base_temperature: #{temp_profile['base_temperature']},\n"
      content << "#{indent}      max_temperature: #{temp_profile['max_temperature']}\n"
      content << "#{indent}    )\n"
      content << "#{indent}  end\n"
      content << "\n"
    end
    
    # Thermal requirement
    if pest_data['thermal_requirement']
      thermal_req = pest_data['thermal_requirement']
      content << "#{indent}  # Thermal Requirement\n"
      content << "#{indent}  if pest.pest_thermal_requirement.nil?\n"
      content << "#{indent}    pest.create_pest_thermal_requirement!(\n"
      content << "#{indent}      required_gdd: #{thermal_req['required_gdd']},\n"
      content << "#{indent}      first_generation_gdd: #{thermal_req['first_generation_gdd'].inspect}\n"
      content << "#{indent}    )\n"
      content << "#{indent}  end\n"
      content << "\n"
    end
    
    # Control methods
    if pest_data['control_methods'] && pest_data['control_methods'].any?
      content << "#{indent}  # Control Methods\n"
      content << "#{indent}  pest.pest_control_methods.destroy_all\n"
      pest_data['control_methods'].each do |method|
        content << "#{indent}  pest.pest_control_methods.create!(\n"
        content << "#{indent}    method_type: #{method['method_type'].inspect},\n"
        content << "#{indent}    method_name: #{method['method_name'].inspect},\n"
        content << "#{indent}    description: #{method['description'].inspect},\n"
        content << "#{indent}    timing_hint: #{method['timing_hint'].inspect}\n"
        content << "#{indent}  )\n"
      end
      content << "\n"
    end
    
    # Affected crops (crop_pests association)
    if pest_data['affected_crops'] && pest_data['affected_crops'].any?
      content << "#{indent}  # Affected Crops\n"
      pest_data['affected_crops'].each do |crop_info|
        content << "#{indent}  crop = TempCrop.find_by(name: #{crop_info['crop_name'].inspect}, is_reference: true, region: '#{region_code}')\n"
        content << "#{indent}  if crop && !TempCropPest.exists?(crop_id: crop.id, pest_id: pest.id)\n"
        content << "#{indent}    TempCropPest.create!(crop_id: crop.id, pest_id: pest.id)\n"
        content << "#{indent}  end\n"
      end
      content << "\n"
    end
  end
  
  content << <<~RUBY
  end
end
RUBY
  
  content
end

# Parse command line options
region = nil

ARGV.each_with_index do |arg, i|
  case arg
  when '--region', '-r'
    region = ARGV[i + 1] if ARGV[i + 1]
  when '--help', '-h'
    puts <<~HELP
Usage: bin/generate_pest_data_migration.rb --region REGION

Options:
  --region, -r REGION    Region code (jp, us, in)
  --help, -h             Show this help message

Examples:
  bin/generate_pest_data_migration.rb --region jp
  bin/generate_pest_data_migration.rb --region us
  bin/generate_pest_data_migration.rb --region in
HELP
    exit 0
  end
end

# Validate region
unless region && PEST_LISTS[region]
  ColorLogger.error("Invalid or missing region. Available regions: #{PEST_LISTS.keys.join(', ')}")
  ColorLogger.info("Usage: bin/generate_pest_data_migration.rb --region REGION")
  exit 1
end

# Get region configuration
region_config = REGION_CONFIG[region]
pests_list = PEST_LISTS[region]

# Header
ColorLogger.log("\n" + "=" * 80, :blue)
ColorLogger.log("#{region_config[:name]} Reference Pests - Generate Data Migration using agrr", :blue)
ColorLogger.log("=" * 80, :blue)
puts ""

# Get reference crops for affected crops list
ColorLogger.info("Loading reference crops (region: '#{region_config[:code]}')...")
crops_list = get_reference_crops(region_config[:code])

if crops_list.empty?
  ColorLogger.warning("No reference crops found. Using empty crops list.")
  crops_list = []
else
  ColorLogger.success("Found #{crops_list.count} reference crops")
end

puts ""

# Generate migration timestamp
migration_timestamp = Time.now.strftime('%Y%m%d%H%M%S')
# Use full region name for filename to match class name
region_name_for_file = case region_config[:code]
                      when 'jp' then 'japan'
                      when 'us' then 'united_states'
                      when 'in' then 'india'
                      else region_config[:code]
                      end
migration_filename = "#{migration_timestamp}_data_migration_#{region_name_for_file}_reference_pests.rb"
migration_path = Rails.root.join('db', 'migrate', migration_filename)

ColorLogger.info("Output migration file: #{migration_path}")
puts ""

# Process each pest
all_pests_data = {}
skipped_pests = []

pests_list.each_with_index do |pest_name, index|
  ColorLogger.log("\n[#{index + 1}/#{pests_list.count}] Processing: #{pest_name}", :blue)
  
  # Fetch pest info from agrr
  ColorLogger.info("  Fetching AI information from agrr...")
  pest_info = fetch_pest_info_from_agrr(pest_name, crops_list, language: region_config[:language])
  
  if pest_info.nil?
    ColorLogger.warning("  Failed to fetch data (skipped)")
    skipped_pests << pest_name
    next
  end

  pest_data = pest_info['data']
  
  unless pest_data && pest_data['pest']
    ColorLogger.warning("  Invalid response format (skipped)")
    skipped_pests << pest_name
    next
  end

  pest = pest_data['pest']
  
  # Store pest data
  all_pests_data[pest_name] = {
    'name' => pest['name'],
    'name_scientific' => pest['name_scientific'],
    'family' => pest['family'],
    'order' => pest['order'],
    'description' => pest['description'],
    'occurrence_season' => pest['occurrence_season'],
    'temperature_profile' => pest['temperature_profile'],
    'thermal_requirement' => pest['thermal_requirement'],
    'control_methods' => pest['control_methods'] || [],
    'affected_crops' => pest_data['affected_crops'] || []
  }
  
  ColorLogger.success("  ✓ Fetched data for #{pest_name}")
  
  # Reduce API load
  sleep 2 if index < pests_list.count - 1
end

# Generate migration file
ColorLogger.log("\n" + "=" * 80, :blue)
ColorLogger.info("Generating migration file...")

# Build migration content
migration_content = build_migration_content(all_pests_data, region_config[:code], region_config[:name])

File.open(migration_path, 'w', encoding: 'UTF-8') do |f|
  f.write(migration_content)
end

ColorLogger.success("Generated migration file: #{migration_filename}")

# Summary
puts ""
ColorLogger.log("=" * 80, :green)
ColorLogger.success("Completed!")
ColorLogger.log("=" * 80, :green)
puts ""

ColorLogger.info("Summary:")
puts "  Region: #{region_config[:name]} (#{region_config[:code]})"
puts "  Total pests: #{pests_list.count}"
puts "  Successfully fetched: #{all_pests_data.count}"
puts "  Failed/Skipped: #{skipped_pests.count}"

if skipped_pests.any?
  puts ""
  ColorLogger.warning("Failed/Skipped pests:")
  skipped_pests.each { |name| puts "  - #{name}" }
end

puts ""
ColorLogger.info("Migration file generated successfully!")
ColorLogger.info("Run 'rails db:migrate' to apply the migration")

