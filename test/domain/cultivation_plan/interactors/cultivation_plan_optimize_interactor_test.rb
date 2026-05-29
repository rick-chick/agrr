# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain::CultivationPlan::Interactors
  class CultivationPlanOptimizeInteractorTest < DomainLibTestCase
    test "calculate_planning_period uses prediction target end for public plan without field_cultivations" do
      fixed_today = Date.new(2026, 7, 20)
      target_end = Date.new(2027, 12, 31)

      snapshot = Domain::CultivationPlan::Dtos::OptimizationPlanSnapshot.new(
        plan_id: 42,
        plan_type_private: false,
        calculated_planning_start_date: nil,
        calculated_planning_end_date: nil,
        prediction_target_end_date: target_end,
        predicted_weather_data: nil,
        total_area: 0,
        weather_location_present: true,
        weather_location_input: Domain::WeatherData::Dtos::WeatherLocation.new(
          id: 1,
          latitude: 0,
          longitude: 0,
          elevation: 0,
          timezone: "UTC",
          predicted_weather_data: nil
        ),
        farm_weather_input: nil
      )

      optimization_plan_read_gateway = mock
      Domain::CultivationPlan::Mappers::OptimizationPlanReadSnapshotMapper
        .stubs(:load_snapshot)
        .with(read_gateway: optimization_plan_read_gateway, plan_id: 42)
        .returns(snapshot)

      gateway = mock
      gateway.stubs(:field_cultivations_present?).with(42).returns(false)

      advance_phase = mock("advance_phase_interactor")
      advance_phase.stubs(:call)

      optimizer = CultivationPlanOptimizeInteractor.new(
        plan_id: 42,
        channel_class: "OptimizationChannel",
        plan_allocation_allocate_gateway: nil,
        interaction_rule_gateway: nil,
        interaction_rule_agrr_format_builder: nil,
        cultivation_plan_gateway: gateway,
        optimization_plan_read_gateway: optimization_plan_read_gateway,
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
