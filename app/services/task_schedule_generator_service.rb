# frozen_string_literal: true

class TaskScheduleGeneratorService
  class Error < StandardError; end
  class WeatherDataMissingError < Error; end
  class ProgressDataMissingError < Error; end
  class GddTriggerMissingError < Error; end
  class TemplateMissingError < Error; end

  def initialize(schedule_gateway: Agrr::ScheduleGateway.new,
                 fertilize_gateway: Agrr::FertilizeGateway.new,
                 progress_gateway: Agrr::ProgressGateway.new,
                 clock: Time.zone)
    @schedule_gateway = schedule_gateway
    @fertilize_gateway = fertilize_gateway
    @progress_gateway = progress_gateway
    @clock = clock
  end

  def generate!(cultivation_plan_id:)
    plan = CultivationPlan.includes(field_cultivations: { cultivation_plan_crop: :crop })
                          .find(cultivation_plan_id)

    unless plan.predicted_weather_data.present?
      raise WeatherDataMissingError, "CultivationPlan##{plan.id} に気象予測データが存在しません"
    end

    blueprint_cache = {}

    ActiveRecord::Base.transaction do
      plan.field_cultivations.find_each do |field_cultivation|
        generate_for_field(plan, field_cultivation, blueprint_cache)
      end
    end
  end

  private

  attr_reader :schedule_gateway, :fertilize_gateway, :progress_gateway, :clock

  def generate_for_field(plan, field_cultivation, blueprint_cache)
    crop = field_cultivation.cultivation_plan_crop&.crop
    return unless crop

    blueprints = blueprints_for(crop, blueprint_cache)
    if blueprints.empty?
      raise TemplateMissingError, "Crop##{crop.id} (#{crop.name}) の作業テンプレートが登録されていません"
    end

    general_blueprints, fertilizer_blueprints = partition_blueprints(blueprints)
    if general_blueprints.empty?
      raise TemplateMissingError, "Crop##{crop.id} (#{crop.name}) の一般作業テンプレートが不足しています"
    end

    agricultural_tasks_lookup = index_agricultural_tasks(crop)

    start_date = field_cultivation.start_date || plan.calculated_planning_start_date
    filtered_weather_data = filtered_weather_data(plan.predicted_weather_data, start_date)

    progress_data = progress_gateway.calculate_progress(
      crop: crop,
      start_date: start_date,
      weather_data: filtered_weather_data
    )

    progress_records = Array(progress_data['progress_records'])
    filtered_records = if start_date.present?
      progress_records.select do |record|
        record_date = safe_parse_date(record['date'])
        record_date && record_date >= start_date
      end
    else
      []
    end
    progress_records = filtered_records if filtered_records.present?
    if progress_records.empty?
      raise ProgressDataMissingError, "GDD進捗データが空です (cultivation_plan_id=#{plan.id})"
    end

    create_schedule!(
      plan: plan,
      field_cultivation: field_cultivation,
      category: 'general'
    ) do |schedule|
      general_blueprints.each do |blueprint|
        build_task_from_blueprint(
          schedule: schedule,
          blueprint: blueprint,
          agricultural_tasks_lookup: agricultural_tasks_lookup,
          progress_records: progress_records,
          fallback_start_date: field_cultivation.start_date
        )
      end
    end

    if fertilizer_blueprints.any?
      create_schedule!(
        plan: plan,
        field_cultivation: field_cultivation,
        category: 'fertilizer'
      ) do |schedule|
        fertilizer_blueprints.each do |blueprint|
          build_task_from_blueprint(
            schedule: schedule,
            blueprint: blueprint,
            agricultural_tasks_lookup: agricultural_tasks_lookup,
            progress_records: progress_records,
            fallback_start_date: field_cultivation.start_date
          )
        end
      end
    else
      clear_schedule(plan: plan, field_cultivation: field_cultivation, category: 'fertilizer')
    end
  end

  def index_agricultural_tasks(crop)
    lookup = {}
    crop.crop_task_templates.includes(:agricultural_task).each do |template|
      task = template.agricultural_task
      if task
        lookup[task.id] = task
        lookup[task.id.to_s] = task
      end
    end
    lookup
  end

  def blueprints_for(crop, cache)
    return cache[crop.id] if cache.key?(crop.id)

    cache[crop.id] = crop.crop_task_schedule_blueprints
                         .includes(:agricultural_task)
                         .ordered
                         .to_a
  end

  def partition_blueprints(blueprints)
    general = []
    fertilizer = []

    blueprints.each do |blueprint|
      case blueprint.task_type
      when TaskScheduleItem::FIELD_WORK_TYPE
        general << blueprint
      when TaskScheduleItem::BASAL_FERTILIZATION_TYPE, TaskScheduleItem::TOPDRESS_FERTILIZATION_TYPE
        fertilizer << blueprint
      end
    end

    [general, fertilizer]
  end

  def build_task_from_blueprint(schedule:, blueprint:, agricultural_tasks_lookup:, progress_records:, fallback_start_date:)
    gdd_trigger = blueprint.gdd_trigger
    if gdd_trigger.nil?
      raise GddTriggerMissingError, 'GDDトリガーが設定されていません'
    end

    task = find_agricultural_task_for_blueprint(blueprint, agricultural_tasks_lookup)

    schedule.task_schedule_items.build(
      task_type: blueprint.task_type,
      agricultural_task: task,
      name: name_for_blueprint(blueprint, task),
      description: blueprint.description.presence || task&.description,
      stage_name: blueprint.stage_name,
      stage_order: blueprint.stage_order,
      gdd_trigger: gdd_trigger,
      gdd_tolerance: blueprint.gdd_tolerance,
      scheduled_date: date_for_gdd(progress_records, gdd_trigger, fallback_start_date),
      priority: blueprint.priority,
      source: blueprint.source,
      weather_dependency: blueprint.weather_dependency || task&.weather_dependency,
      time_per_sqm: blueprint.time_per_sqm || task&.time_per_sqm,
      amount: blueprint.amount,
      amount_unit: blueprint.amount_unit || (blueprint.amount.present? ? 'g/m2' : nil)
    )
  end

  def find_agricultural_task_for_blueprint(blueprint, lookup)
    blueprint.agricultural_task
  end

  def name_for_blueprint(blueprint, task)
    # 関連作業が設定されている場合は、その名前を優先
    return task.name if task&.name.present?
    # 関連作業が未設定の場合、agrrが返した作業名（description）を優先的に使用
    # agrrが返したnameを優先し、stage_nameは使用しない
    return blueprint.description if blueprint.description.present?

    case blueprint.task_type
    when TaskScheduleItem::BASAL_FERTILIZATION_TYPE
      '基肥施用'
    when TaskScheduleItem::TOPDRESS_FERTILIZATION_TYPE
      '追肥施用'
    else
      'field_task'
    end
  end

  def clear_schedule(plan:, field_cultivation:, category:)
    TaskSchedule.where(
      cultivation_plan: plan,
      field_cultivation: field_cultivation,
      category: category
    ).delete_all
  end

  def create_schedule!(plan:, field_cultivation:, category:)
    TaskSchedule.where(
      cultivation_plan: plan,
      field_cultivation: field_cultivation,
      category: category
    ).delete_all

    schedule = TaskSchedule.new(
      cultivation_plan: plan,
      field_cultivation: field_cultivation,
      category: category,
      status: TaskSchedule::STATUSES[:active],
      source: 'agrr',
      generated_at: clock.now
    )

    yield schedule

    schedule.save!
  end

  def date_for_gdd(progress_records, target_gdd, fallback_date)
    target_value = decimal_value(target_gdd)
    if target_value.nil?
      raise GddTriggerMissingError, 'GDDトリガーが設定されていません'
    end

    progress_records.each do |record|
      cumulative = decimal_value(record['cumulative_gdd'])
      next if target_value.present? && cumulative < target_value

      return Date.parse(record['date'])
    end

    raise ProgressDataMissingError, "GDD #{target_value} に対応する日付が見つかりません"
  rescue ArgumentError
    fallback_date
  end

  def decimal_value(value)
    return nil if value.nil?

    BigDecimal(value.to_s)
  end

  def safe_parse_date(value)
    return value if value.is_a?(Date)

    Date.parse(value.to_s)
  rescue ArgumentError, TypeError
    nil
  end

  def filtered_weather_data(weather_data, start_date)
    return weather_data unless start_date && weather_data.is_a?(Hash)

    duplicated = weather_data.deep_dup
    data_array = Array(duplicated['data'] || duplicated[:data])

    filtered = data_array.select do |entry|
      entry_time = entry['time'] || entry[:time]
      entry_time.present? && safe_parse_date(entry_time) && safe_parse_date(entry_time) >= start_date
    end

    if filtered.any?
      if duplicated.key?('data')
        duplicated['data'] = filtered
      else
        duplicated[:data] = filtered
      end
    end

    duplicated
  end
end

