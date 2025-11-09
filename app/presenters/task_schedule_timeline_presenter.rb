# frozen_string_literal: true

class TaskScheduleTimelinePresenter
  WEEK_LENGTH = 6
  CATEGORY_GENERAL = 'general'
  CATEGORY_FERTILIZER = 'fertilizer'

  def initialize(cultivation_plan, params = {})
    @cultivation_plan = cultivation_plan
    @params = params || {}
  end

  def as_json(_options = nil)
    {
      plan: plan_payload,
      week: week_payload,
      milestones: milestones_payload,
      fields: fields_payload,
      labels: labels_payload,
      minimap: minimap_payload
    }
  end

  private

  attr_reader :cultivation_plan, :params

  def plan_payload
    {
      id: cultivation_plan.id,
      name: cultivation_plan.display_name,
      status: cultivation_plan.status,
      planning_start_date: cultivation_plan.planning_start_date&.iso8601,
      planning_end_date: cultivation_plan.planning_end_date&.iso8601,
      timeline_generated_at: timeline_generated_at&.iso8601,
      timeline_generated_at_display: timeline_generated_at_display
    }
  end

  def week_payload
    {
      start_date: week_start.iso8601,
      end_date: week_end.iso8601,
      label: week_label,
      days: days_payload
    }
  end

  def milestones_payload
    [] # 将来的に播種日や収穫日などを設定
  end

  def labels_payload
    {
      empty_cell: I18n.t('plans.task_schedules.empty_cell'),
      unscheduled_title: I18n.t('plans.task_schedules.unscheduled_title'),
      general_label: I18n.t('plans.task_schedules.general_label'),
      fertilizer_label: I18n.t('plans.task_schedules.fertilizer_label'),
      generated_unknown: I18n.t('plans.task_schedules.timeline_generated_unknown'),
      generated_label: I18n.t('plans.task_schedules.generated_label'),
      detail: {
        title: I18n.t('plans.task_schedules.detail.title'),
        empty: I18n.t('plans.task_schedules.detail.empty'),
        scheduled_date: I18n.t('plans.task_schedules.detail.scheduled_date'),
        stage: I18n.t('plans.task_schedules.detail.stage'),
        priority: I18n.t('plans.task_schedules.detail.priority'),
        priority_levels: {
          high: I18n.t('plans.task_schedules.detail.priority_high'),
          medium: I18n.t('plans.task_schedules.detail.priority_medium'),
          low: I18n.t('plans.task_schedules.detail.priority_low'),
          unknown: I18n.t('plans.task_schedules.detail.priority_unknown')
        },
        weather_dependency: I18n.t('plans.task_schedules.detail.weather_dependency'),
        gdd_trigger: I18n.t('plans.task_schedules.detail.gdd_trigger'),
        gdd_tolerance: I18n.t('plans.task_schedules.detail.gdd_tolerance'),
        time_per_sqm: I18n.t('plans.task_schedules.detail.time_per_sqm'),
        amount: I18n.t('plans.task_schedules.detail.amount'),
        amount_unit: I18n.t('plans.task_schedules.detail.amount_unit'),
        source: I18n.t('plans.task_schedules.detail.source'),
        not_applicable: I18n.t('plans.task_schedules.detail.not_applicable'),
        statuses: {
          completed: I18n.t('plans.task_schedules.detail.statuses.completed'),
          delayed: I18n.t('plans.task_schedules.detail.statuses.delayed'),
          adjusted: I18n.t('plans.task_schedules.detail.statuses.adjusted')
        }
      }
    }
  end

  def minimap_payload
    weeks = minimap_weeks.select { |week_start_date| (minimap_counts[week_start_date] || 0).positive? }
    {
      start_date: minimap_range[:start].iso8601,
      end_date: minimap_range[:end].iso8601,
      weeks: weeks.map do |week_start_date|
        count = minimap_counts[week_start_date] || 0
        {
          start_date: week_start_date.iso8601,
          label: I18n.l(week_start_date, format: :short),
          task_count: count,
          density: minimap_density(count),
          month_key: week_start_date.strftime('%Y-%m')
        }
      end
    }
  end

  def fields_payload
    grouped_schedules.each_with_object([]) do |(field_cultivation, schedules), collection|
      serialized = serialize_field(field_cultivation, schedules)
      collection << serialized if serialized
    end
  end

  def serialize_field(field_cultivation, schedules)
    field_info = field_information(field_cultivation)

    categorized = {
      CATEGORY_GENERAL => [],
      CATEGORY_FERTILIZER => [],
      'unscheduled' => []
    }

    schedules.each do |schedule|
      next unless include_category?(schedule.category)

      schedule.task_schedule_items.each do |item|
        serialized_item = serialize_item(item, schedule.category)
        if item.scheduled_date.nil?
          categorized['unscheduled'] << serialized_item
        elsif week_range.cover?(item.scheduled_date)
          bucket_key = schedule.category == CATEGORY_FERTILIZER ? CATEGORY_FERTILIZER : CATEGORY_GENERAL
          categorized[bucket_key] << serialized_item
        end
      end
    end

    sort_items!(categorized)

    return nil if categorized.values.all?(&:empty?)

    field_info.merge(schedules: categorized)
  end

  def sort_items!(categorized)
    categorized[CATEGORY_GENERAL].sort_by! { |item| item['scheduled_date'] || '' }
    categorized[CATEGORY_FERTILIZER].sort_by! { |item| item['scheduled_date'] || '' }
    categorized['unscheduled'].sort_by! { |item| item['name'] }
  end

  def field_information(field_cultivation)
    {
      id: field_cultivation&.id,
      name: field_cultivation&.cultivation_plan_field&.name || I18n.t('plans.task_schedules.plan_level_field'),
      crop_name: field_cultivation&.cultivation_plan_crop&.name || field_cultivation&.cultivation_plan_crop&.crop&.name,
      area_sqm: field_cultivation&.area,
      field_cultivation_id: field_cultivation&.id
    }
  end

  def serialize_item(item, category)
    payload = {
      'item_id' => item.id,
      'name' => item.name,
      'task_type' => item.task_type,
      'category' => category,
      'scheduled_date' => item.scheduled_date&.iso8601,
      'stage_name' => item.stage_name,
      'stage_order' => item.stage_order,
      'gdd_trigger' => item.gdd_trigger&.to_s,
      'gdd_tolerance' => item.gdd_tolerance&.to_s,
      'priority' => item.priority,
      'source' => item.source,
      'weather_dependency' => item.weather_dependency,
      'time_per_sqm' => item.time_per_sqm&.to_s,
      'amount' => item.amount&.to_s,
      'amount_unit' => item.amount_unit,
      'status' => derive_status(item),
      'agricultural_task_id' => item.agricultural_task_id
    }
    payload['details'] = detail_payload(item)
    payload['badge'] = badge_payload(item, category)
    payload
  end

  def derive_status(item)
    item.respond_to?(:status) && item.status.present? ? item.status : 'planned'
  end

  def detail_payload(item)
    {
      stage: {
        name: item.stage_name,
        order: item.stage_order
      },
      gdd: {
        trigger: item.gdd_trigger&.to_s,
        tolerance: item.gdd_tolerance&.to_s
      },
      priority: item.priority,
      weather_dependency: item.weather_dependency,
      time_per_sqm: item.time_per_sqm&.to_s,
      amount: item.amount&.to_s,
      amount_unit: item.amount_unit,
      source: item.source,
      master: master_payload(item.agricultural_task)
    }
  end

  def master_payload(task)
    return nil unless task

    {
      name: task.name,
      description: task.description,
      time_per_sqm: task.time_per_sqm&.to_s,
      weather_dependency: task.weather_dependency,
      required_tools: Array(task.required_tools).presence,
      skill_level: task.skill_level,
      task_type: task.task_type
    }.compact
  end

  def badge_payload(item, category)
    {
      type: item.agricultural_task&.task_type || item.task_type,
      priority_level: priority_level(item.priority),
      status: derive_status(item),
      category: category
    }
  end

  def priority_level(value)
    return 'priority-none' if value.nil?

    case value
    when 0, 1
      'priority-high'
    when 2
      'priority-medium'
    else
      'priority-low'
    end
  end

  def timeline_generated_at
    @timeline_generated_at ||= TaskSchedule.where(cultivation_plan: cultivation_plan).maximum(:generated_at)
  end

  def days_payload
    week_range.map do |date|
      {
        date: date.iso8601,
        weekday: date.strftime('%a').downcase,
        is_today: date == Date.current
      }
    end
  end

  def week_label
    I18n.t(
      'plans.task_schedules.week_label',
      start: I18n.l(week_start, format: :short),
      end: I18n.l(week_end, format: :short)
    )
  end

  def timeline_generated_at_display
    timeline_generated_at ? I18n.l(timeline_generated_at, format: :long) : nil
  end

  def grouped_schedules
    @grouped_schedules ||= begin
      schedules = base_scope.includes(
        :task_schedule_items,
        field_cultivation: [:cultivation_plan_field, { cultivation_plan_crop: :crop }]
      )

      schedules = schedules.select { |schedule| include_category?(schedule.category) }

      schedules.group_by(&:field_cultivation)
    end
  end

  def base_scope
    scope = TaskSchedule.where(cultivation_plan: cultivation_plan)
    scope = scope.where(field_cultivation_id: selected_field_id) if selected_field_id
    scope
  end

  def include_category?(category)
    selected_category == 'all' || selected_category == category
  end

  def selected_category
    @selected_category ||= begin
      value = params[:category].to_s
      case value
      when CATEGORY_GENERAL, CATEGORY_FERTILIZER
        value
      else
        'all'
      end
    end
  end

  def selected_field_id
    return @selected_field_id if defined?(@selected_field_id)

    @selected_field_id = params[:field_cultivation_id].presence&.to_i
  end

  def week_start
    @week_start ||= begin
      if params[:week_start].present?
        Date.parse(params[:week_start]).beginning_of_week
      else
        initial_week_start
      end
    rescue ArgumentError
      initial_week_start
    end
  end

  def week_end
    week_start + WEEK_LENGTH.days
  end

  def week_range
    week_start..week_end
  end

  def initial_week_start
    return Date.current.beginning_of_week if minimap_counts.empty?

    today_week = Date.current.beginning_of_week
    upcoming = minimap_counts.keys.select { |d| d >= today_week }.min
    target = upcoming || minimap_counts.keys.min
    (target || Date.current).beginning_of_week
  end

  def scheduled_dates
    @scheduled_dates ||= TaskScheduleItem
                           .joins(:task_schedule)
                           .where(task_schedules: { cultivation_plan_id: cultivation_plan.id })
                           .where.not(scheduled_date: nil)
                           .pluck(:scheduled_date)
  end

  def minimap_counts
    @minimap_counts ||= scheduled_dates.each_with_object(Hash.new(0)) do |date, counts|
      counts[date.beginning_of_week] += 1
    end
  end

  def minimap_density(count)
    case count
    when 0
      'none'
    when 1..2
      'low'
    when 3..5
      'medium'
    else
      'high'
    end
  end

  def minimap_range
    @minimap_range ||= begin
      start_candidates = [cultivation_plan.planning_start_date, minimap_counts.keys.min, Date.current].compact
      finish_candidates = [cultivation_plan.planning_end_date, minimap_counts.keys.max, Date.current].compact

      start_date = start_candidates.min.beginning_of_week
      end_date = finish_candidates.max.end_of_week

      { start: start_date, end: end_date }
    end
  end

  def minimap_weeks
    start_date = minimap_range[:start]
    end_date = minimap_range[:end]
    weeks = []
    current = start_date
    while current <= end_date
      weeks << current
      current += 1.week
    end
    weeks
  end
end


