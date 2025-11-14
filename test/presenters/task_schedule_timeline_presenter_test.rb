# frozen_string_literal: true

require 'test_helper'

class TaskScheduleTimelinePresenterTest < ActiveSupport::TestCase
  setup do
    @plan = create(:cultivation_plan, :completed)
    @field = create(:cultivation_plan_field, cultivation_plan: @plan)
    crop = create(:crop, user: @plan.user)
    plan_crop = create(:cultivation_plan_crop, cultivation_plan: @plan, crop: crop)
    @field_cultivation = create(:field_cultivation,
                                cultivation_plan: @plan,
                                cultivation_plan_field: @field,
                                cultivation_plan_crop: plan_crop,
                                start_date: Date.current - 7,
                                completion_date: Date.current + 30,
                                status: 'completed')

    @agricultural_task = create(:agricultural_task, :user_owned, user: @plan.user,
                                                       name: '除草作業',
                                                       description: '雑草を取り除く',
                                                       required_tools: ['ホー'])

    @template = create(
      :crop_task_template,
      crop: plan_crop.crop,
      agricultural_task: @agricultural_task,
      name: '除草テンプレート',
      description: 'テンプレ説明',
      time_per_sqm: BigDecimal('0.5'),
      weather_dependency: 'dry',
      required_tools: ['ホー'],
      skill_level: @agricultural_task.skill_level,
      task_type: @agricultural_task.task_type,
      task_type_id: @agricultural_task.task_type_id,
      is_reference: false
    )

    @schedule = TaskSchedule.create!(
      cultivation_plan: @plan,
      field_cultivation: @field_cultivation,
      category: 'general',
      status: 'active',
      source: 'agrr',
      generated_at: Time.zone.now
    )

    TaskScheduleItem.create!(
      task_schedule: @schedule,
      task_type: 'field_work',
      name: '除草',
      stage_name: '初期管理',
      stage_order: 1,
      gdd_trigger: 120,
      gdd_tolerance: 10,
      scheduled_date: Date.current,
      priority: 2,
      source: 'agrr_schedule',
      weather_dependency: 'no_rain_24h',
      time_per_sqm: BigDecimal('0.75'),
      agricultural_task: @agricultural_task
    )
  end

  test 'provides detail payload for each schedule item' do
    presenter = TaskScheduleTimelinePresenter.new(@plan, {})
    json = presenter.as_json.deep_symbolize_keys

    task = json[:fields].first[:schedules][:general].first

    assert_equal '除草', task[:name]
    assert_equal '初期管理', task[:details][:stage][:name]
    assert_equal 1, task[:details][:stage][:order]
    assert_equal '120.0', task[:details][:gdd][:trigger]
    assert_equal '10.0', task[:details][:gdd][:tolerance]
    assert_equal 'no_rain_24h', task[:details][:weather_dependency]
    assert_equal '0.75', task[:details][:time_per_sqm]
    assert_equal '除草作業', task[:details][:master][:name]
    assert_equal ['ホー'], task[:details][:master][:required_tools]
    assert_equal 'beginner', task[:details][:master][:skill_level]
  end

  test 'includes summary badge info' do
    presenter = TaskScheduleTimelinePresenter.new(@plan, {})
    json = presenter.as_json.deep_symbolize_keys

    task = json[:fields].first[:schedules][:general].first
    assert_equal 'field_work', task[:badge][:type]
    assert_equal 'priority-medium', task[:badge][:priority_level]
    assert_equal 'planned', task[:badge][:status]
  end

  test 'provides task options derived from crop task templates' do
    presenter = TaskScheduleTimelinePresenter.new(@plan, {})
    json = presenter.as_json.deep_symbolize_keys

    options = json[:fields].first[:task_options]
    template_option = options.find { |option| option[:template_id] == @template.id }

    assert_not_nil template_option
    assert_equal @template.name, template_option[:name]
    assert_equal @template.agricultural_task_id, template_option[:agricultural_task_id]
  end

  test 'provides minimap weeks with task counts' do
    presenter = TaskScheduleTimelinePresenter.new(@plan, {})
    json = presenter.as_json.deep_symbolize_keys

    minimap = json[:minimap]
    assert minimap[:weeks].any?

    week_start = Date.current.beginning_of_week.iso8601
    current_week_entry = minimap[:weeks].find { |week| week[:start_date] == week_start }

    assert_not_nil current_week_entry
    assert_equal 1, current_week_entry[:task_count]
    assert_equal 'low', current_week_entry[:density]
    assert_equal Date.current.strftime('%Y-%m'), current_week_entry[:month_key]
  end

  test 'minimap excludes weeks without tasks and assigns density levels' do
    TaskScheduleItem.create!(
      task_schedule: @schedule,
      task_type: 'field_work',
      name: '追肥',
      stage_name: '中期管理',
      stage_order: 2,
      gdd_trigger: 200,
      gdd_tolerance: 15,
      scheduled_date: Date.current + 7,
      priority: 3,
      source: 'agrr_schedule'
    )

    TaskScheduleItem.create!(
      task_schedule: @schedule,
      task_type: 'field_work',
      name: '仕上げ',
      stage_name: '収穫準備',
      stage_order: 3,
      gdd_trigger: 300,
      gdd_tolerance: 20,
      scheduled_date: Date.current + 90,
      priority: 1,
      source: 'agrr_schedule'
    )

    3.times do |i|
      TaskScheduleItem.create!(
        task_schedule: @schedule,
        task_type: 'field_work',
        name: "集中作業#{i + 1}",
        stage_name: '集中期',
        stage_order: 4 + i,
        gdd_trigger: 350 + (i * 10),
        gdd_tolerance: 10,
        scheduled_date: Date.current + 14,
        priority: 2,
        source: 'agrr_schedule'
      )
    end

    presenter = TaskScheduleTimelinePresenter.new(@plan, {})
    weeks = presenter.as_json.deep_symbolize_keys[:minimap][:weeks]

    assert weeks.all? { |week| week[:task_count].positive? }
    densities = weeks.map { |week| week[:density] }.uniq
    assert_includes densities, 'low'
    assert_includes densities, 'medium'
  end

  test 'defaults week start to nearest scheduled task when not specified' do
    @schedule.task_schedule_items.update_all(scheduled_date: Date.current + 10.days)

    presenter = TaskScheduleTimelinePresenter.new(@plan, {})
    json = presenter.as_json.deep_symbolize_keys

    expected_start = (Date.current + 10.days).beginning_of_week.iso8601
    assert_equal expected_start, json[:week][:start_date]
  end
end


