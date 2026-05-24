# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain::CultivationPlan::Interactors
  class CultivationPlanOptimizeInteractorTest < DomainLibTestCase
    test "calculate_planning_period uses prediction target end for public plan without field_cultivations" do
      fixed_today = Date.new(2026, 7, 20)
      target_end = Date.new(2027, 12, 31)

      read_rows = Domain::CultivationPlan::Dtos::OptimizationPlanReadRows.new(
        plan_id: 42,
        plan_type: "public",
        calculated_planning_start_date: nil,
        calculated_planning_end_date: nil,
        prediction_target_end_date: target_end,
        predicted_weather_data: nil,
        total_area: 0,
        weather_location: Domain::CultivationPlan::Dtos::OptimizationPlanReadRows::WeatherLocationRead.new(
          id: 1,
          latitude: 0,
          longitude: 0,
          elevation: 0,
          timezone: "UTC",
          predicted_weather_data: nil
        ),
        farm_weather: nil
      )

      private_read_gateway = mock
      private_read_gateway.stubs(:find_optimization_read_by_plan_id).with(plan_id: 42).returns(read_rows)

      gateway = mock
      gateway.stubs(:field_cultivations_present?).with(42).returns(false)

      advance_phase = mock("advance_phase_interactor")
      advance_phase.stubs(:call)

      optimizer = CultivationPlanOptimizeInteractor.new(
        plan_id: 42,
        channel_class: "OptimizationChannel",
        allocation_gateway: nil,
        interaction_rule_gateway: nil,
        interaction_rule_agrr_format_builder: nil,
        cultivation_plan_gateway: gateway,
        private_read_gateway: private_read_gateway,
        advance_phase_interactor: advance_phase,
        logger: CapturingLogger.new,
        weather_prediction_interactor_factory: ->(**) {},
        clock: Struct.new(:today).new(fixed_today)
      )
      optimizer.send(:load_snapshot!)
      planning_start, planning_end = optimizer.send(:calculate_planning_period)

      assert_equal fixed_today, planning_start
      assert_equal target_end, planning_end
    end
  end
end
