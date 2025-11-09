# frozen_string_literal: true

class TaskScheduleGeneratorService
  class Error < StandardError; end
  class WeatherDataMissingError < Error; end
  class ProgressDataMissingError < Error; end
  class GddTriggerMissingError < Error; end

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

    schedule_cache = {}
    fertilize_cache = {}

    ActiveRecord::Base.transaction do
      plan.field_cultivations.find_each do |field_cultivation|
        generate_for_field(plan, field_cultivation, schedule_cache, fertilize_cache)
      end
    end
  end

  private

  attr_reader :schedule_gateway, :fertilize_gateway, :progress_gateway, :clock

  def generate_for_field(plan, field_cultivation, schedule_cache, fertilize_cache)
    crop = field_cultivation.cultivation_plan_crop&.crop
    return unless crop

    agricultural_tasks_lookup = index_agricultural_tasks(crop)

    start_date = field_cultivation.start_date || plan.planning_start_date
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

    schedule_response = schedule_response_for(crop, schedule_cache)
    if schedule_response.present? && Array(schedule_response['task_schedules']).any?
      create_schedule!(
        plan: plan,
        field_cultivation: field_cultivation,
        category: 'general'
      ) do |schedule|
        Array(schedule_response['task_schedules']).each do |task|
          task_id = integer_value(task['task_id'])
          task_id_str = task_id&.to_s
          agricultural_task = agricultural_tasks_lookup[task_id_str] || agricultural_tasks_lookup[task_id_str&.to_i]

      schedule.task_schedule_items.build(
            task_type: TaskScheduleItem::FIELD_WORK_TYPE,
            agricultural_task: agricultural_task,
            source_agricultural_task_id: task_id,
            name: task['name'] || agricultural_task&.name || 'field_task',
            description: task['description'] || agricultural_task&.description,
            stage_name: task['stage_name'],
            stage_order: task['stage_order'],
            gdd_trigger: decimal_value(task['gdd_trigger']),
            gdd_tolerance: decimal_value(task['gdd_tolerance']),
            scheduled_date: date_for_gdd(progress_records, task['gdd_trigger'], field_cultivation.start_date),
            priority: task['priority'],
            source: 'agrr_schedule',
            weather_dependency: task['weather_dependency'] || agricultural_task&.weather_dependency,
            time_per_sqm: decimal_value(task['time_per_sqm']) || agricultural_task&.time_per_sqm
          )
        end
      end
    end

    fertilize_response = fertilize_response_for(crop, fertilize_cache)
    fertilize_schedule = Array(fertilize_response['schedule'])
    if fertilize_schedule.any?
      create_schedule!(
        plan: plan,
        field_cultivation: field_cultivation,
        category: 'fertilizer'
      ) do |schedule|
        fertilize_schedule.each_with_index do |entry, index|
          task_type = index.zero? ? TaskScheduleItem::BASAL_FERTILIZATION_TYPE : TaskScheduleItem::TOPDRESS_FERTILIZATION_TYPE
          schedule.task_schedule_items.build(
            task_type: task_type,
            name: task_type == TaskScheduleItem::BASAL_FERTILIZATION_TYPE ? '基肥施用' : '追肥施用',
            description: entry['description'],
            stage_name: entry['stage_name'],
            stage_order: entry['stage_order'],
            gdd_trigger: decimal_value(entry['gdd_trigger']),
            gdd_tolerance: decimal_value(entry['gdd_tolerance']),
            scheduled_date: date_for_gdd(progress_records, entry['gdd_trigger'], field_cultivation.start_date),
            priority: entry['priority'],
            source: 'agrr_fertilize_plan',
            weather_dependency: entry['weather_dependency'],
            amount: decimal_value(entry['amount_g_per_m2']),
            amount_unit: entry['amount_unit'] || 'g/m2'
          )
        end
      end
    end
  end

  def crop_stage_requirements(crop)
    requirement = crop.to_agrr_requirement
    Array(requirement['stage_requirements'])
  end

  def crop_agricultural_tasks(crop)
    tasks = crop.agricultural_tasks.order(:id)
    AgriculturalTask.to_agrr_format_array(tasks)
  end

  def index_agricultural_tasks(crop)
    lookup = {}
    crop.agricultural_tasks.each do |task|
      lookup[task.id] = task
      lookup[task.id.to_s] = task
    end
    lookup
  end

  def schedule_response_for(crop, cache)
    return cache[crop.id] if cache.key?(crop.id)

    agricultural_tasks = crop_agricultural_tasks(crop)
    if agricultural_tasks.any?
      cache[crop.id] = schedule_gateway.generate(
        crop_name: crop.name,
        variety: crop.variety || 'general',
        stage_requirements: crop_stage_requirements(crop),
        agricultural_tasks: agricultural_tasks
      )
    else
      cache[crop.id] = nil
    end
  end

  def fertilize_response_for(crop, cache)
    return cache[crop.id] if cache.key?(crop.id)

    cache[crop.id] = fertilize_gateway.plan(
      crop: crop,
      use_harvest_start: true
    )
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

  def integer_value(value)
    return nil if value.nil?

    str = value.to_s
    return nil unless str.match?(/\A-?\d+\z/)

    str.to_i
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

