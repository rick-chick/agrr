# frozen_string_literal: true

require "test_helper"

class TaskScheduleTimelinePresenterTest < ActiveSupport::TestCase
  ReadModel = Domain::CultivationPlan::Dtos::TaskScheduleTimelineReadModel

  setup do
    @today = Date.new(2025, 1, 10)
    @plan = ReadModel::PlanRead.new(
      id: 12,
      display_name: "夏野菜計画",
      status: "completed",
      planning_start_date: Date.new(2025, 1, 1),
      planning_end_date: Date.new(2025, 12, 31),
      timeline_generated_at: Time.new(2025, 1, 5, 9, 30, 0),
      farm_display_name: "テスト農場",
      total_area: 1_500.5
    )

    @task_master = ReadModel::AgriculturalTaskRead.new(
      name: "除草作業",
      description: "雑草を取り除く",
      time_per_sqm: BigDecimal("0.5"),
      weather_dependency: "dry",
      required_tools: [ "ホー" ],
      skill_level: "beginner",
      task_type: "field_work"
    )

    @item = ReadModel::ItemRead.new(
      id: 99,
      name: "除草",
      task_type: "field_work",
      scheduled_date: @today,
      stage_name: "初期管理",
      stage_order: 1,
      gdd_trigger: BigDecimal("120.0"),
      gdd_tolerance: BigDecimal("10.0"),
      priority: 2,
      source: "agrr_schedule",
      weather_dependency: "no_rain_24h",
      time_per_sqm: BigDecimal("0.75"),
      amount: nil,
      amount_unit: nil,
      status: nil,
      agricultural_task_id: 42,
      field_cultivation_id: 5,
      agricultural_task: @task_master,
      actual_date: Date.new(2025, 1, 12),
      actual_notes: "完了メモ",
      rescheduled_at: Time.new(2025, 1, 6, 12, 0, 0),
      cancelled_at: nil,
      completed_at: Time.new(2025, 1, 12, 17, 0, 0)
    )

    @schedule = ReadModel::ScheduleRead.new(category: "general", items: [ @item ])
    @task_option = ReadModel::TaskOptionRead.new(
      template_id: 123,
      name: "除草テンプレート",
      task_type: "field_work",
      agricultural_task_id: 42,
      description: "テンプレ説明",
      weather_dependency: "dry",
      time_per_sqm: BigDecimal("0.5"),
      required_tools: [ "ホー" ],
      skill_level: "beginner"
    )

    @field = ReadModel::FieldRead.new(
      id: 5,
      name: "A-1",
      crop_name: "にんじん",
      area_sqm: 120.5,
      field_cultivation_id: 5,
      crop_id: 77,
      task_options: [ @task_option ],
      schedules: [ @schedule ]
    )
  end

  test "provides detail payload for each schedule item" do
    presenter = presenter_for(build_dto)
    json = presenter.as_json.deep_symbolize_keys

    task = json[:fields].first[:schedules][:general].first

    assert_equal "除草", task[:name]
    assert_equal "初期管理", task[:details][:stage][:name]
    assert_equal 1, task[:details][:stage][:order]
    assert_equal "120.0", task[:details][:gdd][:trigger]
    assert_equal "10.0", task[:details][:gdd][:tolerance]
    assert_equal "no_rain_24h", task[:details][:weather_dependency]
    assert_equal "0.75", task[:details][:time_per_sqm]
    assert_equal "除草作業", task[:details][:master][:name]
    assert_equal [ "ホー" ], task[:details][:master][:required_tools]
    assert_equal "beginner", task[:details][:master][:skill_level]
  end

  test "includes summary badge info" do
    presenter = presenter_for(build_dto)
    json = presenter.as_json.deep_symbolize_keys

    task = json[:fields].first[:schedules][:general].first
    assert_equal "field_work", task[:badge][:type]
    assert_equal "priority-medium", task[:badge][:priority_level]
    assert_equal "planned", task[:badge][:status]
  end

  test "provides task options derived from crop task templates" do
    presenter = presenter_for(build_dto)
    json = presenter.as_json.deep_symbolize_keys

    options = json[:fields].first[:task_options]
    template_option = options.find { |option| option[:template_id] == @task_option.template_id }

    assert_not_nil template_option
    assert_equal @task_option.name, template_option[:name]
    assert_equal @task_option.agricultural_task_id, template_option[:agricultural_task_id]
  end

  test "provides minimap weeks with task counts" do
    presenter = presenter_for(build_dto)
    json = presenter.as_json.deep_symbolize_keys

    minimap = json[:minimap]
    assert minimap[:weeks].any?

    week_start = @today.beginning_of_week.iso8601
    current_week_entry = minimap[:weeks].find { |week| week[:start_date] == week_start }

    assert_not_nil current_week_entry
    assert_equal 1, current_week_entry[:task_count]
    assert_equal "low", current_week_entry[:density]
    assert_equal Date.iso8601(week_start).strftime("%Y-%m"), current_week_entry[:month_key]
  end

  test "minimap excludes weeks without tasks and assigns density levels" do
    scheduled_dates = [
      @today,
      @today + 7,
      @today + 14,
      @today + 15,
      @today + 16
    ]

    presenter = presenter_for(build_dto(scheduled_dates: scheduled_dates))
    weeks = presenter.as_json.deep_symbolize_keys[:minimap][:weeks]

    assert weeks.all? { |week| week[:task_count].positive? }
    densities = weeks.map { |week| week[:density] }.uniq
    assert_includes densities, "low"
    assert_includes densities, "medium"
  end

  test "defaults week start to nearest scheduled task when not specified" do
    scheduled_dates = [ @today + 10 ]

    presenter = presenter_for(build_dto(scheduled_dates: scheduled_dates))
    json = presenter.as_json.deep_symbolize_keys

    expected_start = (@today + 10).beginning_of_week.iso8601
    assert_equal expected_start, json[:week][:start_date]
  end

  test "html_shell_plan は成功 DTO からページヘッダ用シェルを組み立てる" do
    presenter = presenter_for(build_dto)
    shell = presenter.html_shell_plan

    assert_equal 12, shell.id
    assert_equal "夏野菜計画", shell.display_name
    assert_equal "テスト農場", shell.farm.display_name
    assert_in_delta 1_500.5, shell.total_area.to_f, 0.001
  end

  private

  def build_dto(scheduled_dates: [ @today ])
    Domain::CultivationPlan::Dtos::TaskScheduleTimelineDto.new(
      plan: @plan,
      fields: [ @field ],
      scheduled_dates: scheduled_dates,
      today: @today
    )
  end

  def presenter_for(dto)
    presenter = Presenters::Html::Plans::TaskScheduleTimelinePresenter.new(view: Object.new, params: {})
    presenter.on_success(dto)
    presenter
  end
end
