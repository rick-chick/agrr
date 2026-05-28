# frozen_string_literal: true

require "domain_lib_test_helper"
require "net/protocol"
require "json"

module Domain
  module CultivationPlan
    module Interactors
      class PlanAllocationAdjustInteractorTest < DomainLibTestCase
        Failure = Dtos::PlanAllocationAdjustFailure
        Snapshot = Dtos::PlanAllocationAdjustReadSnapshot
        PlanCropEntry = Snapshot::PlanCropEntry

        FakeTranslator = Struct.new(:dummy) do
          def translate(key, **options)
            "#{key}:#{options[:message] || options[:crop_name]}"
          end
        end

        FakeLogger = Struct.new(:entries) do
          def initialize
            super([])
          end

          def info(message, _progname = nil) = entries << [ :info, message ]
          def error(message, _progname = nil) = entries << [ :error, message ]
        end

        FakeClock = Struct.new(:fixed) do
          def now = fixed
        end

        def build_adjust_read_snapshot(crop_name:, has_growth_stages:)
          Snapshot.new(
            plan_id: 2,
            field_source_rows: [],
            plan_fields: [],
            plan_crop_entries: [
              PlanCropEntry.new(
                crop_id: 1,
                crop_name: crop_name,
                groups: [],
                has_growth_stages: has_growth_stages,
                agrr_requirement: nil
              )
            ],
            cultivation_planning_periods: [],
            planning_period_boundaries: Dtos::PlanAllocationAdjustPlanningBoundaries.new(
              planning_start_date: nil,
              planning_end_date: nil
            ),
            cultivation_plan_weather_dto: Domain::WeatherData::Dtos::CultivationPlanWeather.new(
              id: 2,
              prediction_target_end_date: nil,
              calculated_planning_end_date: nil,
              predicted_weather_data: nil
            ),
            weather_prediction_targets: Domain::WeatherData::Dtos::WeatherPredictionTargets.new(
              weather_location: nil,
              farm: nil
            ),
            weather_location_facts: {},
            farm_without_weather_location: true
          )
        end

        test "run_adjust_and_persist dispatches on_failure when adjust gateway raises AdjustExecutionError" do
          fixed_time = Time.utc(2026, 1, 1, 12, 0, 0)
          agrr_gateway = mock
          agrr_gateway.expects(:adjust).raises(
            Domain::CultivationPlan::Errors::AdjustExecutionError,
            "agrr failed"
          )
          output = mock
          output.expects(:on_failure).with do |failure:|
            failure.kind == Failure::KIND_ADJUST_EXECUTION_FAILED &&
              failure.message.include?("agrr failed") &&
              failure.message.include?("api.errors.optimization.adjust_failed")
          end

          interactor = PlanAllocationAdjustInteractor.new(
            output_port: output,
            logger: FakeLogger.new,
            translator: FakeTranslator.new(nil),
            clock: FakeClock.new(fixed_time),
            plan_allocation_adjust_read_gateway: mock,
            weather_prediction_gateway: mock,
            plan_allocation_adjust_gateway: agrr_gateway,
            field_cultivation_sync: mock,
            agrr_adjust_result_sync_mapper: mock,
            optimization_events_gateway: mock,
            debug_dump_gateway: Domain::CultivationPlan::Gateways::PlanAllocationAdjustDebugDumpNullGateway.new,
            interaction_rule_random_hex: -> { "abcd1234" }
          )

          interactor.send(
            :run_adjust_and_persist,
            plan_id: 1,
            moves: [],
            fields: [],
            crops: [],
            weather_data: { "data" => [] },
            interaction_rules: [],
            effective_planning_start: Date.new(2026, 1, 1),
            effective_planning_end: Date.new(2026, 12, 31),
            current_allocation: {},
            perf_start: fixed_time,
            perf_db_load: fixed_time
          )
        end

        test "call loads adjust read snapshot via user scope for private auth" do
          output = mock
          read_gateway = mock
          logger = FakeLogger.new
          translator = FakeTranslator.new(nil)
          auth = Dtos::CultivationPlanRestAuth.new(mode: :private, user_id: 1)
          snapshot = build_adjust_read_snapshot(crop_name: "C", has_growth_stages: true)
          read_gateway.expects(:find_adjust_read_snapshot_by_plan_id_and_user_id)
                      .with(plan_id: 2, user_id: 1)
                      .returns(snapshot)
          output.expects(:on_success).with do |output:|
            output.skipped == true && output.message.include?("調整不要")
          end

          PlanAllocationAdjustInteractor.new(
            output_port: output,
            logger: logger,
            translator: translator,
            clock: FakeClock.new(Time.utc(2026, 1, 1)),
            plan_allocation_adjust_read_gateway: read_gateway,
            weather_prediction_gateway: mock,
            plan_allocation_adjust_gateway: mock,
            field_cultivation_sync: mock,
            agrr_adjust_result_sync_mapper: mock,
            optimization_events_gateway: mock,
            debug_dump_gateway: Domain::CultivationPlan::Gateways::PlanAllocationAdjustDebugDumpNullGateway.new,
            interaction_rule_random_hex: -> { "abcd1234" }
          ).call(
            Dtos::PlanAllocationAdjustInput.new(
              plan_id: 2,
              moves: [],
              auth: auth
            )
          )
        end

        test "call dispatches crop_missing_growth_stages when plan crop has no growth stages" do
          output = mock
          read_gateway = mock
          translator = mock
          translator.expects(:translate).with(
            "api.errors.cultivation_plan.crop_missing_growth_stages",
            crop_name: "X"
          ).returns("missing stages")
          auth = Dtos::CultivationPlanRestAuth.new(mode: :private, user_id: 1)
          snapshot = build_adjust_read_snapshot(crop_name: "X", has_growth_stages: false)
          read_gateway.expects(:find_adjust_read_snapshot_by_plan_id_and_user_id).returns(snapshot)
          output.expects(:on_failure).with do |failure:|
            failure.kind == Failure::KIND_CROP_MISSING_GROWTH_STAGES &&
              failure.message == "missing stages"
          end
          output.expects(:on_success).never

          PlanAllocationAdjustInteractor.new(
            output_port: output,
            logger: FakeLogger.new,
            translator: translator,
            clock: FakeClock.new(Time.utc(2026, 1, 1)),
            plan_allocation_adjust_read_gateway: read_gateway,
            weather_prediction_gateway: mock,
            plan_allocation_adjust_gateway: mock,
            field_cultivation_sync: mock,
            agrr_adjust_result_sync_mapper: mock,
            optimization_events_gateway: mock,
            debug_dump_gateway: Domain::CultivationPlan::Gateways::PlanAllocationAdjustDebugDumpNullGateway.new,
            interaction_rule_random_hex: -> { "abcd1234" }
          ).call(
            Dtos::PlanAllocationAdjustInput.new(
              plan_id: 2,
              moves: [],
              auth: auth
            )
          )
        end
      end
    end
  end
end
