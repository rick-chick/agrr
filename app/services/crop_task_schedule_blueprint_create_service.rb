# frozen_string_literal: true

class CropTaskScheduleBlueprintCreateService
  class Error < StandardError; end
  class MissingCropTaskTemplatesError < Error; end
  class GenerationFailedError < Error; end

  MissingAgriculturalTasksError = MissingCropTaskTemplatesError

  def initialize(schedule_gateway: Agrr::ScheduleGateway.new,
                 fertilize_gateway: Agrr::FertilizeGateway.new)
    @schedule_gateway = schedule_gateway
    @fertilize_gateway = fertilize_gateway
  end

  def regenerate!(crop:)
    templates = crop.crop_task_templates.includes(:agricultural_task).order(:id)

    if templates.empty?
      raise MissingCropTaskTemplatesError, "作業テンプレート生成には作物の作業テンプレート登録が必要です"
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

    generator = CropTaskScheduleBlueprintGenerator.new(crop: crop, templates: templates)
    blueprints = generator.build_from_responses(
      schedule_response: schedule_response,
      fertilize_response: fertilize_response
    )

    if blueprints.empty?
      raise GenerationFailedError, "AGRRの応答から作業テンプレートを生成できませんでした"
    end

    persist_blueprints!(crop: crop, blueprint_attributes: blueprints)
  end

  private

  attr_reader :schedule_gateway, :fertilize_gateway

  def persist_blueprints!(crop:, blueprint_attributes:)
    timestamp = Time.current

    sanitized_attributes = blueprint_attributes.map do |attrs|
      normalized_attrs = attrs.dup
      normalized_attrs[:gdd_trigger] = normalize_decimal(attrs[:gdd_trigger])
      normalized_attrs[:gdd_tolerance] = normalize_decimal(attrs[:gdd_tolerance])
      normalized_attrs[:amount] = normalize_decimal(attrs[:amount])
      normalized_attrs[:time_per_sqm] = normalize_decimal(attrs[:time_per_sqm])
      normalized_attrs.merge(created_at: timestamp, updated_at: timestamp)
    end

    CropTaskScheduleBlueprint.transaction do
      crop.crop_task_schedule_blueprints.delete_all
      CropTaskScheduleBlueprint.insert_all!(sanitized_attributes)
    end

    crop.crop_task_schedule_blueprints.reset
  end

  def normalize_decimal(value)
    return nil if value.nil?

    decimal = value.is_a?(BigDecimal) ? value : BigDecimal(value.to_s)
    decimal.to_s('F')
  end
end
