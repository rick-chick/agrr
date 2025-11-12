# frozen_string_literal: true

class CropTaskTemplateBackfillService
  def initialize(logger: Rails.logger)
    @logger = logger
  end

  def call(crop_ids: nil)
    scope = AgriculturalTaskCrop.includes(:crop, :agricultural_task)
    scope = scope.where(crop_id: Array(crop_ids)) if crop_ids.present?

    scope.find_each do |link|
      crop = link.crop
      task = link.agricultural_task
      next unless crop && task

      template = CropTaskTemplate.find_or_initialize_by(
        crop_id: crop.id,
        source_agricultural_task_id: task.id
      )

      next if template.persisted?

      template.name = task.name
      template.description = task.description
      template.time_per_sqm = task.time_per_sqm
      template.weather_dependency = task.weather_dependency
      template.required_tools = normalized_required_tools(task.required_tools)
      template.skill_level = task.skill_level
      template.agricultural_task = task
      template.task_type = task.task_type
      template.task_type_id = task.task_type_id
      template.is_reference = task.is_reference

      template.save!
    rescue ActiveRecord::RecordInvalid => e
      logger.error("❌ CropTaskTemplateBackfillService failed: #{e.message}")
      raise
    end
  end

  private

  attr_reader :logger

  def normalized_required_tools(value)
    case value
    when Array
      value
    when String
      begin
        parsed = JSON.parse(value)
        parsed.is_a?(Array) ? parsed : []
      rescue JSON::ParserError
        value.split(/\r?\n|,/).map(&:strip).reject(&:blank?)
      end
    else
      []
    end
  end
end

