#!/usr/bin/env ruby
# frozen_string_literal: true

require 'optparse'
require 'fileutils'
require 'bigdecimal'

require_relative '../config/environment'

class ColorLogger
  COLORS = {
    red: "\e[31m",
    green: "\e[32m",
    yellow: "\e[33m",
    blue: "\e[34m",
    reset: "\e[0m"
  }.freeze

  class << self
    def info(message)
      puts "#{COLORS[:blue]}[INFO] #{message}#{COLORS[:reset]}"
    end

    def success(message)
      puts "#{COLORS[:green]}[OK] #{message}#{COLORS[:reset]}"
    end

    def warn(message)
      puts "#{COLORS[:yellow]}[WARN] #{message}#{COLORS[:reset]}"
    end

    def error(message)
      puts "#{COLORS[:red]}[ERROR] #{message}#{COLORS[:reset]}"
    end
  end
end

Options = Struct.new(:region, :crop_id, :crop_name, keyword_init: true)

class BlueprintMigrationWriter
  def initialize(region:, blueprints:)
    @region = region
    @blueprints = blueprints
  end

  def write!
    timestamp = Time.now.utc.strftime('%Y%m%d%H%M%S')
    file_name = "#{timestamp}_data_migration_#{region}_crop_task_schedule_blueprints.rb"
    path = Rails.root.join('db', 'migrate', file_name)
    File.write(path, render)
    path
  end

  private

  attr_reader :region, :blueprints

  def render
    <<~RUBY
      # frozen_string_literal: true

      class DataMigration#{class_suffix} < ActiveRecord::Migration[8.0]
        class TempBlueprint < ActiveRecord::Base
          self.table_name = 'crop_task_schedule_blueprints'
        end

        BLUEPRINTS = [
      #{render_blueprints}
        ].freeze

        def up
          say_with_time "Inserting crop task schedule blueprints for region #{region}" do
            now = Time.zone.now
            records = BLUEPRINTS.map { |attrs| normalize_attrs(attrs, now) }
            TempBlueprint.insert_all!(records)
          end
        end

        def down
          say_with_time "Removing crop task schedule blueprints for region #{region}" do
            BLUEPRINTS.each do |attrs|
              TempBlueprint.where(
                crop_id: attrs[:crop_id],
                stage_order: attrs[:stage_order],
                task_type: attrs[:task_type],
                agricultural_task_id: attrs[:agricultural_task_id],
                source_agricultural_task_id: attrs[:source_agricultural_task_id]
              ).delete_all
            end
          end
        end

        private

        def normalize_attrs(attrs, timestamp)
          attrs.merge(
            gdd_trigger: decimal_value(attrs[:gdd_trigger]),
            gdd_tolerance: decimal_value(attrs[:gdd_tolerance]),
            amount: decimal_value(attrs[:amount]),
            time_per_sqm: decimal_value(attrs[:time_per_sqm]),
            created_at: timestamp,
            updated_at: timestamp
          )
        end

        def decimal_value(value)
          return nil if value.nil?
          BigDecimal(value.to_s)
        end
      end
    RUBY
  end

  def render_blueprints
    blueprints.map do |attrs|
      "    { #{render_attributes(attrs)} }"
    end.join(",\n")
  end

  def render_attributes(attrs)
    ordered_keys = [
      :crop_id,
      :agricultural_task_id,
      :source_agricultural_task_id,
      :stage_order,
      :stage_name,
      :gdd_trigger,
      :gdd_tolerance,
      :task_type,
      :source,
      :priority,
      :description,
      :amount,
      :amount_unit,
      :weather_dependency,
      :time_per_sqm
    ]

    ordered_keys.map do |key|
      "#{key}: #{ruby_literal(attrs[key])}"
    end.join(', ')
  end

  def ruby_literal(value)
    case value
    when nil
      'nil'
    when Integer
      value.to_s
    when BigDecimal
      "'#{value.to_s('F')}'"
    when Float
      "'#{format('%<val>.3f', val: value)}'"
    when String
      "'#{value.gsub("'", "\\\\'")}'"
    else
      "'#{value}'"
    end
  end

  def class_suffix
    "#{region.camelize}CropTaskScheduleBlueprints"
  end
end

def parse_options(argv)
  options = Options.new

  parser = OptionParser.new do |opts|
    opts.banner = 'Usage: bin/generate_crop_task_schedule_blueprints.rb --region REGION [--crop-id ID | --crop-name NAME]'

    opts.on('--region REGION', 'Target region code (e.g., jp, us, in)') do |region|
      options.region = region
    end

    opts.on('--crop-id ID', Integer, 'Filter by crop ID') do |id|
      options.crop_id = id
    end

    opts.on('--crop-name NAME', 'Filter by crop name') do |name|
      options.crop_name = name
    end

    opts.on('--help', 'Show this help') do
      puts opts
      exit
    end
  end

  parser.parse!(argv)

  if options.region.nil?
    ColorLogger.error('Region is required. Use --region to specify it.')
    puts parser
    exit 1
  end

  options
end

def fetch_crops(options)
  scope = Crop.where(region: options.region, is_reference: true)
  scope = scope.where(id: options.crop_id) if options.crop_id
  scope = scope.where(name: options.crop_name) if options.crop_name

  crops = scope.order(:id).to_a

  if crops.empty?
    ColorLogger.error('No crops matched the given filters.')
    exit 1
  end

  crops
end

def generator_for(crop, templates)
  CropTaskScheduleBlueprintGenerator.new(crop: crop, templates: templates)
end

def build_blueprints(crop, schedule_gateway, fertilize_gateway)
  ColorLogger.info("Processing crop ##{crop.id} (#{crop.name})...")

  templates = crop.crop_task_templates.includes(:agricultural_task).order(:id)

  if templates.empty?
    ColorLogger.warn("Crop ##{crop.id} has no crop task templates. Skipping.")
    return []
  end

  stage_requirements = crop.to_agrr_requirement.fetch('stage_requirements')
  agricultural_tasks = CropTaskTemplate.to_agrr_format_array(templates)

  schedule_response = schedule_gateway.generate(
    crop_name: crop.name,
    variety: crop.variety || 'general',
    stage_requirements: stage_requirements,
    agricultural_tasks: agricultural_tasks
  )

  fertilize_response = fertilize_gateway.plan(
    crop: crop,
    use_harvest_start: true
  )

  generator_for(crop, templates).build_from_responses(
    schedule_response: schedule_response,
    fertilize_response: fertilize_response
  )
end

def normalize_for_migration(attrs)
  {
    crop_id: attrs[:crop_id],
    agricultural_task_id: attrs[:agricultural_task_id],
    source_agricultural_task_id: attrs[:source_agricultural_task_id],
    stage_order: attrs[:stage_order],
    stage_name: attrs[:stage_name],
    gdd_trigger: format_decimal(attrs[:gdd_trigger]),
    gdd_tolerance: format_decimal(attrs[:gdd_tolerance]),
    task_type: attrs[:task_type],
    source: attrs[:source],
    priority: attrs[:priority],
    description: attrs[:description],
    amount: format_decimal(attrs[:amount]),
    amount_unit: attrs[:amount_unit],
    weather_dependency: attrs[:weather_dependency],
    time_per_sqm: format_decimal(attrs[:time_per_sqm])
  }
end

def format_decimal(value)
  return nil if value.nil?
  BigDecimal(value.to_s).to_s('F')
end

options = parse_options(ARGV)
crops = fetch_crops(options)

schedule_gateway = Agrr::ScheduleGateway.new
fertilize_gateway = Agrr::FertilizeGateway.new

all_blueprints = []

crops.each do |crop|
  blueprints = build_blueprints(crop, schedule_gateway, fertilize_gateway)
  if blueprints.empty?
    ColorLogger.error("No blueprints generated for crop ##{crop.id}. Aborting.")
    exit 1
  end
  all_blueprints.concat(
    blueprints.map { |attrs| normalize_for_migration(attrs) }
  )
  ColorLogger.success("Generated #{blueprints.size} templates for crop ##{crop.id}.")
end

if all_blueprints.empty?
  ColorLogger.error('No blueprint records were generated.')
  exit 1
end

writer = BlueprintMigrationWriter.new(region: options.region, blueprints: all_blueprints)
path = writer.write!

ColorLogger.success("Migration written to #{path}")
