# frozen_string_literal: true

class CropTaskScheduleBlueprintGenerator
  def initialize(crop:, templates: nil)
    @crop = crop
    @templates = Array(templates).presence || crop.crop_task_templates.includes(:agricultural_task).to_a
  end

  def build_from_responses(schedule_response:, fertilize_response:)
    blueprint_attributes = []

    blueprint_attributes.concat(
      Array(schedule_response&.dig('task_schedules')).map do |task|
        build_general_blueprint(task)
      end.compact
    )

    blueprint_attributes.concat(
      Array(fertilize_response&.dig('schedule')).each_with_index.map do |entry, index|
        build_fertilizer_blueprint(entry, index)
      end.compact
    )

    blueprint_attributes
  end

  private

  attr_reader :crop, :templates

  def build_general_blueprint(task)
    task_id = integer_value(task['task_id'])
    template = template_for_task(task_id)
    agricultural_task = template&.agricultural_task || AgriculturalTask.find_by(id: task_id)

    {
      crop_id: crop.id,
      agricultural_task_id: agricultural_task&.id,
      stage_order: integer_value(task['stage_order']),
      stage_name: task['stage_name'],
      gdd_trigger: decimal_value(task['gdd_trigger']),
      gdd_tolerance: decimal_value(task['gdd_tolerance']),
      task_type: TaskScheduleItem::FIELD_WORK_TYPE,
      source: 'agrr_schedule',
      priority: integer_value(task['priority']),
      description: task['description'] || template&.description,
      amount: nil,
      amount_unit: nil,
      weather_dependency: task['weather_dependency'] || template&.weather_dependency,
      time_per_sqm: decimal_value(task['time_per_sqm']) || template&.time_per_sqm
    }
  end

  def build_fertilizer_blueprint(entry, index)
    task_type = entry['task_type'] ||
      (index.zero? ? TaskScheduleItem::BASAL_FERTILIZATION_TYPE : TaskScheduleItem::TOPDRESS_FERTILIZATION_TYPE)
    task_id = integer_value(entry['task_id'])
    agricultural_task = AgriculturalTask.find_by(id: task_id)

    {
      crop_id: crop.id,
      agricultural_task_id: agricultural_task&.id,
      stage_order: integer_value(entry['stage_order']),
      stage_name: entry['stage_name'],
      gdd_trigger: decimal_value(entry['gdd_trigger']),
      gdd_tolerance: decimal_value(entry['gdd_tolerance']),
      task_type: task_type,
      source: 'agrr_fertilize_plan',
      priority: integer_value(entry['priority']),
      description: entry['description'],
      amount: decimal_value(entry['amount_g_per_m2']),
      amount_unit: entry['amount_unit'] || (entry['amount_g_per_m2'].present? ? 'g/m2' : nil),
      weather_dependency: entry['weather_dependency'],
      time_per_sqm: decimal_value(entry['time_per_sqm'])
    }
  end

  def template_lookup
    @template_lookup ||= templates.each_with_object({}) do |template, memo|
      if template.agricultural_task_id.present?
        memo[template.agricultural_task_id] = template
        memo[template.agricultural_task_id.to_s] = template
      end
    end
  end

  def template_for_task(task_id)
    return nil if task_id.nil?

    template_lookup[task_id] || template_lookup[task_id.to_s]
  end

  def decimal_value(value)
    return nil if value.nil? || (value.respond_to?(:empty?) && value.empty?)
    return value if value.is_a?(BigDecimal)

    BigDecimal(value.to_s)
  end

  def integer_value(value)
    return value if value.is_a?(Integer)
    return nil if value.nil?

    str = value.to_s
    return nil unless str.match?(/\A-?\d+\z/)

    str.to_i
  end
end
