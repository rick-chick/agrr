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
            save_adjusted_gateway: mock,
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
      end
    end
  end
end
