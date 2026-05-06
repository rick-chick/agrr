# frozen_string_literal: true

require "test_helper"

class TaskScheduleTimelineInteractorTest < ActiveSupport::TestCase
  class StubOutputPort < Domain::CultivationPlan::Ports::TaskScheduleTimelineOutputPort
    attr_reader :success_dto, :failure_dto

    def on_success(dto)
      @success_dto = dto
    end

    def on_failure(error_dto)
      @failure_dto = error_dto
    end
  end

  setup do
    @user = create(:user)
    @plan = create(:cultivation_plan, :completed, user: @user, plan_type: "private")
    @field = create(:cultivation_plan_field, cultivation_plan: @plan)
    crop = create(:crop, user: @user)
    plan_crop = create(:cultivation_plan_crop, cultivation_plan: @plan, crop: crop)
    @field_cultivation = create(
      :field_cultivation,
      cultivation_plan: @plan,
      cultivation_plan_field: @field,
      cultivation_plan_crop: plan_crop,
      start_date: Date.new(2025, 1, 1),
      completion_date: Date.new(2025, 2, 1),
      status: "completed"
    )

    @task = create(
      :agricultural_task,
      :user_owned,
      user: @user,
      name: "除草作業",
      description: "雑草を取り除く",
      required_tools: [ "ホー" ]
    )

    @template = create(
      :crop_task_template,
      crop: plan_crop.crop,
      agricultural_task: @task,
      name: "除草テンプレート",
      description: "テンプレ説明",
      time_per_sqm: BigDecimal("0.5"),
      weather_dependency: "dry",
      required_tools: [ "ホー" ],
      skill_level: @task.skill_level,
      task_type: @task.task_type,
      task_type_id: @task.task_type_id,
      is_reference: false
    )

    @schedule = TaskSchedule.create!(
      cultivation_plan: @plan,
      field_cultivation: @field_cultivation,
      category: "general",
      status: "active",
      source: "agrr",
      generated_at: Time.zone.now
    )

    @item = TaskScheduleItem.create!(
      task_schedule: @schedule,
      task_type: "field_work",
      name: "除草",
      stage_name: "初期管理",
      stage_order: 1,
      gdd_trigger: 120,
      gdd_tolerance: 10,
      scheduled_date: Date.new(2025, 1, 10),
      priority: 2,
      source: "agrr_schedule",
      weather_dependency: "no_rain_24h",
      time_per_sqm: BigDecimal("0.75"),
      agricultural_task: @task
    )

    @gateway = Adapters::CultivationPlan::Gateways::CultivationPlanActiveRecordGateway.new(
      translator: Adapters::Translators::RailsTranslator.new
    )
    @output_port = StubOutputPort.new
    @clock = Struct.new(:today).new(Date.new(2025, 1, 10))
    @logger = Adapters::Logger::Gateways::RailsLoggerGateway.new
    @user_lookup = Adapters::Shared::Gateways::UserActiveRecordGateway.new
  end

  test "loads timeline snapshot and passes dto to output port" do
    Domain::CultivationPlan::Interactors::TaskScheduleTimelineInteractor.new(
      output_port: @output_port,
      user_id: @user.id,
      plan_id: @plan.id,
      gateway: @gateway,
      translator: Adapters::Translators::RailsTranslator.new,
      logger: @logger,
      user_lookup: @user_lookup,
      clock: @clock
    ).call

    assert_nil @output_port.failure_dto
    dto = @output_port.success_dto

    assert_equal @plan.id, dto.plan.id
    assert_equal @clock.today, dto.today
    assert_equal 1, dto.fields.size
    assert_equal @field_cultivation.id, dto.fields.first.field_cultivation_id
    assert_equal @template.id, dto.fields.first.task_options.first.template_id
    assert_includes dto.scheduled_dates, @item.scheduled_date
  end
end
