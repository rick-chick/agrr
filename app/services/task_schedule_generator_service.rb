# frozen_string_literal: true

class TaskScheduleGeneratorService
  class Error < StandardError; end
  class WeatherDataMissingError < Error; end
  class ProgressDataMissingError < Error; end

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

    ActiveRecord::Base.transaction do
      plan.field_cultivations.find_each do |field_cultivation|
        generate_for_field(plan, field_cultivation)
      end
    end
  end

  private

  attr_reader :schedule_gateway, :fertilize_gateway, :progress_gateway, :clock

  def generate_for_field(plan, field_cultivation)
    crop = field_cultivation.cultivation_plan_crop&.crop
    return unless crop

    progress_data = progress_gateway.calculate_progress(
      crop: crop,
      start_date: field_cultivation.start_date || plan.planning_start_date,
      weather_data: plan.predicted_weather_data
    )

    progress_records = Array(progress_data['progress_records'])
    if progress_records.empty?
      raise ProgressDataMissingError, "GDD進捗データが空です (cultivation_plan_id=#{plan.id})"
    end

    stage_requirements = crop_stage_requirements(crop)
    agricultural_tasks = crop_agricultural_tasks(crop)

    if agricultural_tasks.any?
      schedule_response = schedule_gateway.generate(
        crop_name: crop.name,
        variety: crop.variety || 'general',
        stage_requirements: stage_requirements,
        agricultural_tasks: agricultural_tasks
      )

      create_schedule!(
        plan: plan,
        field_cultivation: field_cultivation,
        category: 'general'
      ) do |schedule|
        Array(schedule_response['task_schedules']).each do |task|
          schedule.task_schedule_items.build(
            task_type: TaskScheduleItem::FIELD_WORK_TYPE,
            name: task['task_id'] || task['name'] || 'field_task',
            description: task['description'],
            stage_name: task['stage_name'],
            stage_order: task['stage_order'],
            gdd_trigger: decimal_value(task['gdd_trigger']),
            gdd_tolerance: decimal_value(task['gdd_tolerance']),
            scheduled_date: date_for_gdd(progress_records, task['gdd_trigger'], field_cultivation.start_date),
            priority: task['priority'],
            source: 'agrr_schedule',
            weather_dependency: task['weather_dependency'],
            time_per_sqm: decimal_value(task['time_per_sqm'])
          )
        end
      end
    end

    fertilize_response = fertilize_gateway.plan(
      crop: crop,
      use_harvest_start: true
    )

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
end

