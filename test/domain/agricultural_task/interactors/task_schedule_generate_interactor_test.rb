# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module AgriculturalTask
    module Interactors
      # TaskScheduleGenerateInteractor の純粋ユニットテスト（memory gateway 注入・Rails 非依存）。
      # 旧 test/integration/domain/... の実 AR + FactoryBot 版を ARCHITECTURE.md Testing 規約
      # （interactor は memory gateway で test/domain/ に置く）に沿って書き直したもの。
      class TaskScheduleGenerateInteractorTest < DomainLibTestCase
        Types = Domain::AgriculturalTask::Constants::ScheduleItemTypes
        Statuses = Domain::AgriculturalTask::Constants::TaskScheduleItemStatuses

        # --- fake entities（AR モデル相当の形だけを満たす素の値オブジェクト）---
        Blueprint = Struct.new(
          :id, :task_type, :gdd_trigger, :gdd_tolerance, :description, :stage_name,
          :stage_order, :priority, :source, :weather_dependency, :time_per_sqm,
          :amount, :amount_unit, :agricultural_task, keyword_init: true
        )
        RelatedTask = Struct.new(:id, :name, :description, :weather_dependency, :time_per_sqm, keyword_init: true)
        Crop = Struct.new(:id, :name, :crop_task_templates, :crop_task_schedule_blueprints, keyword_init: true) do
          def to_agrr_requirement
            { "crop" => { "name" => name } }
          end
        end
        FieldCultivation = Struct.new(:id, :crop, :start_date, keyword_init: true)
        Plan = Struct.new(:id, :predicted_weather_data, :field_cultivations, :calculated_planning_start_date, keyword_init: true)
        Ctx = Struct.new(:plan, keyword_init: true)
        FixedClock = Struct.new(:now)

        # --- memory gateways ---
        class FakeCultivationPlanGateway
          def within_transaction
            yield
          end
        end

        PlanRowSnapshot = Data.define(:id, :predicted_weather_data, :calculated_planning_start_date)
        FieldCultivationRowWire = Data.define(:id, :start_date, :crop_id)
        CropRowWire = Data.define(:id, :name)
        TemplateRowWire = Data.define(:agricultural_task)
        BlueprintRowWire = Data.define(
          :id, :task_type, :gdd_trigger, :gdd_tolerance, :description, :stage_name,
          :stage_order, :priority, :source, :weather_dependency, :time_per_sqm,
          :amount, :amount_unit, :agricultural_task
        )

        class FakeTaskScheduleReadGateway
          def initialize(test_case)
            @test = test_case
          end

          def find_plan_row(plan_id:)
            plan = @test.instance_variable_get(:@plan)
            PlanRowSnapshot.new(
              id: plan.id,
              predicted_weather_data: plan.predicted_weather_data,
              calculated_planning_start_date: plan.calculated_planning_start_date
            )
          end

          def list_field_cultivation_rows(plan_id:)
            fc = @test.instance_variable_get(:@field_cultivation)
            crop = fc.crop
            [
              FieldCultivationRowWire.new(
                id: fc.id,
                start_date: fc.start_date,
                crop_id: crop&.id
              )
            ]
          end

          def find_crop_row(crop_id:)
            crop = @test.instance_variable_get(:@crop)
            CropRowWire.new(id: crop.id, name: crop.name)
          end

          def list_crop_task_template_rows(crop_id:)
            crop = @test.instance_variable_get(:@crop)
            crop.crop_task_templates.map do |template|
              TemplateRowWire.new(agricultural_task: template.agricultural_task)
            end
          end

          def list_crop_task_schedule_blueprint_rows(crop_id:)
            crop = @test.instance_variable_get(:@crop)
            crop.crop_task_schedule_blueprints.map do |blueprint|
              BlueprintRowWire.new(
                id: blueprint.id,
                task_type: blueprint.task_type,
                gdd_trigger: blueprint.gdd_trigger,
                gdd_tolerance: blueprint.gdd_tolerance,
                description: blueprint.description,
                stage_name: blueprint.stage_name,
                stage_order: blueprint.stage_order,
                priority: blueprint.priority,
                source: blueprint.source,
                weather_dependency: blueprint.weather_dependency,
                time_per_sqm: blueprint.time_per_sqm,
                amount: blueprint.amount,
                amount_unit: blueprint.amount_unit,
                agricultural_task: blueprint.agricultural_task
              )
            end
          end

          def build_crop_agrr_requirement(crop_id:)
            { "crop" => { "crop_id" => crop_id.to_s, "name" => "stub" } }
          end
        end

        class CapturingTaskScheduleGateway
          attr_reader :replaced, :cleared

          def initialize
            @replaced = []
            @cleared = []
          end

          def replace_schedule_for_field_category!(cultivation_plan_id:, field_cultivation_id:, category:, generated_at:, items:)
            @replaced << {
              cultivation_plan_id: cultivation_plan_id,
              field_cultivation_id: field_cultivation_id,
              category: category,
              generated_at: generated_at,
              items: items
            }
          end

          def delete_all_for_field_category(cultivation_plan_id:, field_cultivation_id:, category:)
            @cleared << {
              cultivation_plan_id: cultivation_plan_id,
              field_cultivation_id: field_cultivation_id,
              category: category
            }
          end
        end

        class StubProgressGateway
          attr_reader :received_payloads

          def initialize(response)
            @response = response
            @received_payloads = []
          end

          def calculate_progress(crop_requirement:, start_date:, weather_data:, crop: nil)
            @received_payloads << {
              crop_requirement: crop_requirement,
              start_date: start_date,
              weather_data: weather_data,
              crop: crop
            }
            @response
          end
        end

        setup do
          @soil_task = RelatedTask.new(id: 11, name: "土壌準備", description: "soil", weather_dependency: "low", time_per_sqm: BigDecimal("0.1"))
          @basal_task = RelatedTask.new(id: 12, name: "基肥", description: nil, weather_dependency: nil, time_per_sqm: nil)
          @topdress_task = RelatedTask.new(id: 13, name: "追肥", description: nil, weather_dependency: nil, time_per_sqm: nil)

          @general_blueprint = Blueprint.new(
            id: 1, task_type: Types::FIELD_WORK, gdd_trigger: BigDecimal("0.0"), gdd_tolerance: BigDecimal("5.0"),
            description: nil, stage_name: "土壌準備", stage_order: 1, priority: 1, source: "agrr_schedule",
            weather_dependency: "low", time_per_sqm: BigDecimal("0.1"), amount: nil, amount_unit: nil,
            agricultural_task: @soil_task
          )
          @basal_blueprint = Blueprint.new(
            id: 2, task_type: Types::BASAL_FERTILIZATION, gdd_trigger: BigDecimal("0.0"), gdd_tolerance: BigDecimal("5.0"),
            description: nil, stage_name: "定植前", stage_order: 0, priority: 1, source: "agrr_schedule",
            weather_dependency: nil, time_per_sqm: nil, amount: nil, amount_unit: nil,
            agricultural_task: @basal_task
          )
          @topdress_blueprint = Blueprint.new(
            id: 3, task_type: Types::TOPDRESS_FERTILIZATION, gdd_trigger: BigDecimal("160.0"), gdd_tolerance: BigDecimal("10.0"),
            description: nil, stage_name: "生育期", stage_order: 2, priority: 2, source: "agrr_schedule",
            weather_dependency: nil, time_per_sqm: nil, amount: BigDecimal("4.0"), amount_unit: nil,
            agricultural_task: @topdress_task
          )

          @crop = Crop.new(
            id: 1, name: "トマト", crop_task_templates: [],
            crop_task_schedule_blueprints: [ @general_blueprint, @basal_blueprint, @topdress_blueprint ]
          )
          @field_cultivation = FieldCultivation.new(id: 7, crop: @crop, start_date: Date.new(2025, 4, 1))
          @plan = Plan.new(
            id: 99, predicted_weather_data: mocked_weather_data,
            field_cultivations: [ @field_cultivation ], calculated_planning_start_date: nil
          )
          @ctx = Ctx.new(plan: @plan)

          @task_schedule_gateway = CapturingTaskScheduleGateway.new
          @cultivation_plan_gateway = FakeCultivationPlanGateway.new
          @task_schedule_read_gateway = FakeTaskScheduleReadGateway.new(self)
          @clock = FixedClock.new(Time.utc(2025, 1, 1, 0, 0, 0))
        end

        test "generate! produces general + fertilizer schedules with blueprint-derived items" do
          interactor = build_interactor(progress_gateway: StubProgressGateway.new(progress_response))

          interactor.generate!(cultivation_plan_id: @plan.id)

          assert_equal 2, @task_schedule_gateway.replaced.size
          general = @task_schedule_gateway.replaced.find { |r| r[:category] == "general" }
          fertilizer = @task_schedule_gateway.replaced.find { |r| r[:category] == "fertilizer" }
          assert_not_nil general
          assert_not_nil fertilizer

          assert_equal 1, general[:items].size
          general_item = general[:items].first
          assert_equal Types::FIELD_WORK, general_item[:task_type]
          assert_equal @soil_task.id, general_item[:agricultural_task_id]
          assert_equal BigDecimal("0.0"), general_item[:gdd_trigger]
          assert_equal Date.new(2025, 4, 1), general_item[:scheduled_date]
          assert_equal "agrr_schedule", general_item[:source]
          assert_equal Statuses::PLANNED, general_item[:status]

          assert_equal 2, fertilizer[:items].size
          assert_equal Types::BASAL_FERTILIZATION, fertilizer[:items].first[:task_type]
          assert_equal Date.new(2025, 4, 1), fertilizer[:items].first[:scheduled_date]
          assert_equal BigDecimal("160.0"), fertilizer[:items].last[:gdd_trigger]
          assert_equal Date.new(2025, 4, 6), fertilizer[:items].last[:scheduled_date]
        end

        test "generate! raises TemplateMissingError when crop has no blueprints" do
          @crop.crop_task_schedule_blueprints = []
          interactor = build_interactor(progress_gateway: StubProgressGateway.new(progress_response))

          assert_raises TaskScheduleGenerateInteractor::TemplateMissingError do
            interactor.generate!(cultivation_plan_id: @plan.id)
          end
        end

        test "generate! raises ProgressDataMissingError when progress has no records" do
          interactor = build_interactor(
            progress_gateway: StubProgressGateway.new(progress_response.merge("progress_records" => []))
          )

          assert_raises TaskScheduleGenerateInteractor::ProgressDataMissingError do
            interactor.generate!(cultivation_plan_id: @plan.id)
          end
        end

        test "progress gateway receives weather data filtered from the start date" do
          progress_gateway = StubProgressGateway.new(progress_response)

          build_interactor(progress_gateway: progress_gateway).generate!(cultivation_plan_id: @plan.id)

          weather = progress_gateway.received_payloads.last[:weather_data]
          assert_not_nil weather
          times = Array(weather["data"]).map { |entry| entry["time"] }
          refute_empty times
          assert(times.all? { |time| Date.parse(time) >= @field_cultivation.start_date })
        end

        test "generate! ignores progress records before the field cultivation start date" do
          early = progress_response.merge(
            "progress_records" => [
              { "date" => "2025-03-20T00:00:00", "cumulative_gdd" => 0.0 },
              { "date" => "2025-04-01T00:00:00", "cumulative_gdd" => 0.0 },
              { "date" => "2025-04-06T00:00:00", "cumulative_gdd" => 165.0 }
            ]
          )

          build_interactor(progress_gateway: StubProgressGateway.new(early)).generate!(cultivation_plan_id: @plan.id)

          scheduled_dates = @task_schedule_gateway.replaced.flat_map { |r| r[:items] }.map { |item| item[:scheduled_date] }
          assert_equal Date.new(2025, 4, 1), scheduled_dates.min
        end

        test "generate! raises GddTriggerMissingError when a blueprint has no gdd trigger" do
          @general_blueprint.gdd_trigger = nil
          interactor = build_interactor(progress_gateway: StubProgressGateway.new(progress_response))

          assert_raises TaskScheduleGenerateInteractor::GddTriggerMissingError do
            interactor.generate!(cultivation_plan_id: @plan.id)
          end
        end

        test "items with higher gdd triggers are scheduled on later dates" do
          @topdress_blueprint.gdd_trigger = BigDecimal("200.0")
          staggered = progress_response.merge(
            "progress_records" => [
              { "date" => "2025-04-01T00:00:00", "cumulative_gdd" => 0.0 },
              { "date" => "2025-04-03T00:00:00", "cumulative_gdd" => 120.0 },
              { "date" => "2025-04-10T00:00:00", "cumulative_gdd" => 205.0 }
            ]
          )

          build_interactor(progress_gateway: StubProgressGateway.new(staggered)).generate!(cultivation_plan_id: @plan.id)

          fertilizer = @task_schedule_gateway.replaced.find { |r| r[:category] == "fertilizer" }
          dates = fertilizer[:items].map { |item| item[:scheduled_date] }.sort
          assert_equal Date.new(2025, 4, 1), dates.first
          assert dates.last > Date.new(2025, 4, 1), "higher GDD threshold must move the task to a later date"
        end

        private

        def build_interactor(progress_gateway:)
          TaskScheduleGenerateInteractor.new(
            progress_gateway: progress_gateway,
            task_schedule_gateway: @task_schedule_gateway,
            clock: @clock,
            cultivation_plan_gateway: @cultivation_plan_gateway,
            task_schedule_read_gateway: @task_schedule_read_gateway
          )
        end

        def mocked_weather_data
          {
            "location" => { "latitude" => 35.0, "longitude" => 135.0, "timezone" => "Asia/Tokyo" },
            "data" => [
              { "time" => "2025-03-20T00:00:00", "temperature_2m_mean" => 10.0 },
              { "time" => "2025-03-25T00:00:00", "temperature_2m_mean" => 12.0 },
              { "time" => "2025-04-01T00:00:00", "temperature_2m_mean" => 15.0 },
              { "time" => "2025-04-05T00:00:00", "temperature_2m_mean" => 18.0 },
              { "time" => "2025-04-10T00:00:00", "temperature_2m_mean" => 20.0 }
            ]
          }
        end

        def progress_response
          {
            "progress_records" => [
              { "date" => "2025-04-01T00:00:00", "cumulative_gdd" => 0.0 },
              { "date" => "2025-04-04T00:00:00", "cumulative_gdd" => 120.0 },
              { "date" => "2025-04-06T00:00:00", "cumulative_gdd" => 165.0 }
            ],
            "total_gdd" => 600.0
          }
        end
      end
    end
  end
end
