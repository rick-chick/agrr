# frozen_string_literal: true

require "domain_lib_test_helper"
require "net/protocol"
require "json"

module Domain
  module CultivationPlan
    module Interactors
      class PlanAllocationAdjustInteractorTest < DomainLibTestCase
        Failure = Dtos::PlanAllocationAdjustFailure

        FakeTranslator = Struct.new(:dummy) do
          def translate(key, **options)
            "#{key}:#{options[:message]}"
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
            plan_gateway: mock,
            weather_prediction_gateway: mock,
            agrr_adjust_gateway: agrr_gateway,
            save_adjusted_result_interactor: mock,
            optimization_events_gateway: mock,
            adjust_plan_growth_read_gateway: mock,
            debug_dump_gateway: Domain::CultivationPlan::Gateways::PlanAllocationAdjustDebugDumpNullGateway.new
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

        test "call routes growth read through list_by_plan_id_and_user_id for private auth" do
          output = mock
          growth = mock
          plan_gateway = mock
          plan_gateway.stubs(:end_adjust_session!)
          logger = FakeLogger.new
          translator = FakeTranslator.new(nil)
          auth = Dtos::CultivationPlanRestAuth.new(mode: :private, user_id: 1)
          snapshot = Dtos::CultivationPlanAdjustPlanCropGrowthSnapshot.new(
            crop_name: "C",
            growth_stage_count: 1
          )
          growth.expects(:list_by_plan_id_and_user_id).with(plan_id: 2, user_id: 1).returns([snapshot])
          output.expects(:on_success).with do |output:|
            output.skipped == true && output.message.include?("調整不要")
          end

          PlanAllocationAdjustInteractor.new(
            output_port: output,
            logger: logger,
            translator: translator,
            clock: FakeClock.new(Time.utc(2026, 1, 1)),
            plan_gateway: plan_gateway,
            weather_prediction_gateway: mock,
            agrr_adjust_gateway: mock,
            save_adjusted_result_interactor: mock,
            optimization_events_gateway: mock,
            adjust_plan_growth_read_gateway: growth,
            debug_dump_gateway: Domain::CultivationPlan::Gateways::PlanAllocationAdjustDebugDumpNullGateway.new
          ).call(
            Dtos::PlanAllocationAdjustInput.new(
              plan_id: 2,
              moves: [],
              auth: auth
            )
          )
        end

        test "call dispatches crop_missing_growth_stages when growth read finds zero stages" do
          output = mock
          growth = mock
          plan_gateway = mock
          plan_gateway.stubs(:end_adjust_session!)
          translator = mock
          translator.expects(:translate).with(
            "api.errors.cultivation_plan.crop_missing_growth_stages",
            crop_name: "X"
          ).returns("missing stages")
          auth = Dtos::CultivationPlanRestAuth.new(mode: :private, user_id: 1)
          snapshot = Dtos::CultivationPlanAdjustPlanCropGrowthSnapshot.new(
            crop_name: "X",
            growth_stage_count: 0
          )
          growth.expects(:list_by_plan_id_and_user_id).returns([snapshot])
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
            plan_gateway: plan_gateway,
            weather_prediction_gateway: mock,
            agrr_adjust_gateway: mock,
            save_adjusted_result_interactor: mock,
            optimization_events_gateway: mock,
            adjust_plan_growth_read_gateway: growth,
            debug_dump_gateway: Domain::CultivationPlan::Gateways::PlanAllocationAdjustDebugDumpNullGateway.new
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
