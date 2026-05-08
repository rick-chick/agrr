# frozen_string_literal: true

class Presenters::Html::Plans::TaskScheduleTimelinePresenter < Domain::CultivationPlan::Ports::TaskScheduleTimelineOutputPort
  WEEK_LENGTH = 6
  CATEGORY_GENERAL = "general"
  CATEGORY_FERTILIZER = "fertilizer"

  def initialize(view:, params: {})
    @view = view
    @params = params || {}
    @timeline = nil
  end

  def on_success(dto)
    @timeline = dto
  end

  def on_failure(error_dto)
    msg = error_dto.respond_to?(:message) ? error_dto.message : error_dto.to_s
    if @view.request.format.json?
      @view.render json: { errors: [ msg ] }, status: :not_found
    else
      @view.redirect_to @view.plans_path, alert: msg
    end
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

  def html_shell_plan
    return nil unless @timeline

    p = @timeline.plan
    Domain::CultivationPlan::Dtos::TaskScheduleTimelineShellPlan.new(
      id: p.id,
      display_name: p.display_name,
      total_area: p.total_area,
      farm_display_name: p.farm_display_name
    )
  end

  private

  attr_reader :timeline, :params

  def task_options_for(field)
    field.task_options.map do |template|
      {
        template_id: template.template_id,
        name: template.name,
        task_type: template.task_type,
        agricultural_task_id: template.agricultural_task_id,
        description: template.description,
        weather_dependency: template.weather_dependency,
        time_per_sqm: template.time_per_sqm&.to_s,
        required_tools: template.required_tools,
        skill_level: template.skill_level
      }.compact
    end
  end

  def plan_payload
    {
      id: timeline.plan.id,
      name: timeline.plan.display_name,
      status: timeline.plan.status,
      planning_start_date: timeline.plan.planning_start_date&.iso8601,
      planning_end_date: timeline.plan.planning_end_date&.iso8601,
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
      empty_cell: I18n.t("plans.task_schedules.empty_cell"),
      unscheduled_title: I18n.t("plans.task_schedules.unscheduled_title"),
      general_label: I18n.t("plans.task_schedules.general_label"),
      fertilizer_label: I18n.t("plans.task_schedules.fertilizer_label"),
      generated_unknown: I18n.t("plans.task_schedules.timeline_generated_unknown"),
      generated_label: I18n.t("plans.task_schedules.generated_label"),
      add_task: I18n.t("plans.task_schedules.add_task"),
      detail: {
        title: I18n.t("plans.task_schedules.detail.title"),
        empty: I18n.t("plans.task_schedules.detail.empty"),
        scheduled_date: I18n.t("plans.task_schedules.detail.scheduled_date"),
        stage: I18n.t("plans.task_schedules.detail.stage"),
        time_per_sqm: I18n.t("plans.task_schedules.detail.time_per_sqm"),
        amount: I18n.t("plans.task_schedules.detail.amount"),
        amount_unit: I18n.t("plans.task_schedules.detail.amount_unit"),
        not_applicable: I18n.t("plans.task_schedules.detail.not_applicable"),
        statuses: {
          completed: I18n.t("plans.task_schedules.detail.statuses.completed"),
          delayed: I18n.t("plans.task_schedules.detail.statuses.delayed"),
          adjusted: I18n.t("plans.task_schedules.detail.statuses.adjusted")
        },
        actions: {
          reschedule: I18n.t("plans.task_schedules.detail.actions.reschedule"),
          reschedule_label: I18n.t("plans.task_schedules.detail.actions.reschedule_label"),
          updated: I18n.t("plans.task_schedules.detail.actions.updated"),
          update_failed: I18n.t("plans.task_schedules.detail.actions.update_failed"),
          date_required: I18n.t("plans.task_schedules.detail.actions.date_required"),
          submit: I18n.t("plans.task_schedules.detail.actions.submit"),
          cancel_form: I18n.t("plans.task_schedules.detail.actions.cancel_form"),
          complete: I18n.t("plans.task_schedules.detail.actions.complete"),
          completed: I18n.t("plans.task_schedules.detail.actions.completed"),
          complete_failed: I18n.t("plans.task_schedules.detail.actions.complete_failed"),
          actual_date: I18n.t("plans.task_schedules.detail.actions.actual_date"),
          notes: I18n.t("plans.task_schedules.detail.actions.notes"),
          notes_placeholder: I18n.t("plans.task_schedules.detail.actions.notes_placeholder"),
          confirm_cancel: I18n.t("plans.task_schedules.detail.actions.confirm_cancel"),
          cancel: I18n.t("plans.task_schedules.detail.actions.cancel"),
          cancel_failed: I18n.t("plans.task_schedules.detail.actions.cancel_failed"),
          task_name: I18n.t("plans.task_schedules.detail.actions.task_name"),
          task_name_placeholder: I18n.t("plans.task_schedules.detail.actions.task_name_placeholder"),
          crop: I18n.t("plans.task_schedules.detail.actions.crop"),
          crop_required: I18n.t("plans.task_schedules.detail.actions.crop_required"),
          scheduled_date: I18n.t("plans.task_schedules.detail.actions.scheduled_date"),
          name_required: I18n.t("plans.task_schedules.detail.actions.name_required"),
          created: I18n.t("plans.task_schedules.detail.actions.created"),
          create_failed: I18n.t("plans.task_schedules.detail.actions.create_failed")
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
          month_key: week_start_date.strftime("%Y-%m")
        }
      end
    }
  end

  def fields_payload
    filtered_fields.each_with_object([]) do |field, collection|
      serialized = serialize_field(field)
      collection << serialized if serialized
    end
  end

  def serialize_field(field)
    field_info = field_information(field)

    categorized = {
      CATEGORY_GENERAL => [],
      CATEGORY_FERTILIZER => [],
      "unscheduled" => []
    }

    field.schedules.each do |schedule|
      next unless include_category?(schedule.category)

      schedule.items.each do |item|
        serialized_item = serialize_item(item, schedule.category)
        if item.scheduled_date.nil?
          categorized["unscheduled"] << serialized_item
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
    categorized[CATEGORY_GENERAL].sort_by! { |item| item["scheduled_date"] || "" }
    categorized[CATEGORY_FERTILIZER].sort_by! { |item| item["scheduled_date"] || "" }
    categorized["unscheduled"].sort_by! { |item| item["name"] }
  end

  def field_information(field)
    {
      id: field.id,
      name: field.name || I18n.t("plans.task_schedules.plan_level_field"),
      crop_name: field.crop_name,
      area_sqm: field.area_sqm,
      field_cultivation_id: field.field_cultivation_id,
      crop_id: field.crop_id,
      task_options: task_options_for(field)
    }
  end

  def serialize_item(item, category)
    payload = {
      "item_id" => item.id,
      "name" => item.name,
      "task_type" => item.task_type,
      "category" => category,
      "scheduled_date" => item.scheduled_date&.iso8601,
      "stage_name" => item.stage_name,
      "stage_order" => item.stage_order,
      "gdd_trigger" => item.gdd_trigger&.to_s,
      "gdd_tolerance" => item.gdd_tolerance&.to_s,
      "priority" => item.priority,
      "source" => item.source,
      "weather_dependency" => item.weather_dependency,
      "time_per_sqm" => item.time_per_sqm&.to_s,
      "amount" => item.amount&.to_s,
      "amount_unit" => item.amount_unit,
      "status" => derive_status(item),
      "agricultural_task_id" => item.agricultural_task_id,
      "field_cultivation_id" => item.field_cultivation_id
    }
    payload["details"] = detail_payload(item)
    payload["badge"] = badge_payload(item, category)
    payload
  end

  def derive_status(item)
    item.status.present? ? item.status : "planned"
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
      master: master_payload(item.agricultural_task),
      actual: {
        date: item.actual_date&.iso8601,
        notes: item.actual_notes
      },
      history: {
        rescheduled_at: item.rescheduled_at&.iso8601,
        cancelled_at: item.cancelled_at&.iso8601,
        completed_at: item.completed_at&.iso8601
      }
    }
  end

  def master_payload(task)
    return nil unless task

    {
      name: task.name,
      description: task.description,
      time_per_sqm: task.time_per_sqm&.to_s,
      weather_dependency: task.weather_dependency,
      required_tools: task.required_tools,
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
    return "priority-none" if value.nil?

    case value
    when 0, 1
      "priority-high"
    when 2
      "priority-medium"
    else
      "priority-low"
    end
  end

  def timeline_generated_at
    timeline.plan.timeline_generated_at
  end

  def days_payload
    week_range.map do |date|
      {
        date: date.iso8601,
        weekday: date.strftime("%a").downcase,
        is_today: date == today
      }
    end
  end

  def week_label
    I18n.t(
      "plans.task_schedules.week_label",
      start: I18n.l(week_start, format: :short),
      end: I18n.l(week_end, format: :short)
    )
  end

  def timeline_generated_at_display
    timeline_generated_at ? I18n.l(timeline_generated_at, format: :long) : nil
  end

  def include_category?(category)
    selected_category == "all" || selected_category == category
  end

  def selected_category
    @selected_category ||= begin
      value = params[:category].to_s
      case value
      when CATEGORY_GENERAL, CATEGORY_FERTILIZER
        value
      else
        "all"
      end
    end
  end

  def selected_field_id
    return @selected_field_id if defined?(@selected_field_id)

    @selected_field_id = params[:field_cultivation_id].presence&.to_i
  end

  def filtered_fields
    return timeline.fields if selected_field_id.nil?

    timeline.fields.select { |field| field.field_cultivation_id == selected_field_id }
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
    return today.beginning_of_week if minimap_counts.empty?

    today_week = today.beginning_of_week
    upcoming = minimap_counts.keys.select { |d| d >= today_week }.min
    target = upcoming || minimap_counts.keys.min
    (target || today).beginning_of_week
  end

  def scheduled_dates
    timeline.scheduled_dates
  end

  def minimap_counts
    @minimap_counts ||= scheduled_dates.each_with_object(Hash.new(0)) do |date, counts|
      counts[date.beginning_of_week] += 1
    end
  end

  def minimap_density(count)
    case count
    when 0
      "none"
    when 1..2
      "low"
    when 3..5
      "medium"
    else
      "high"
    end
  end

  def minimap_range
    @minimap_range ||= begin
      start_candidates = [ timeline.plan.planning_start_date, minimap_counts.keys.min, today ].compact
      finish_candidates = [ timeline.plan.planning_end_date, minimap_counts.keys.max, today ].compact

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

  def today
    timeline.today
  end
end
