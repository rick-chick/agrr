# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module CultivationPlan
    module Mappers
      class OptimizationPlanReadSnapshotMapperTest < DomainLibTestCase
        test "load_snapshot delegates to gateway narrow reads and composes via OptimizationPlanSnapshotMapper" do
          core = Dtos::OptimizationPlanReadPlanCoreSnapshot.new(
            plan_id: 1,
            plan_type_private: true,
            calculated_planning_start_date: nil,
            calculated_planning_end_date: nil,
            prediction_target_end_date: Date.new(2027, 12, 31),
            predicted_weather_data: nil,
            total_area: 10.0,
            weather_location_present: true
          )
          read_gateway = Object.new
          read_gateway.define_singleton_method(:find_optimization_plan_core_snapshot_by_plan_id) { |**| core }
          read_gateway.define_singleton_method(:find_optimization_weather_location_by_plan_id) { |**| nil }
          read_gateway.define_singleton_method(:find_optimization_farm_weather_by_plan_id) { |**| nil }

          snapshot = OptimizationPlanReadSnapshotMapper.load_snapshot(
            read_gateway: read_gateway,
            plan_id: 1
          )

          assert_instance_of Dtos::OptimizationPlanSnapshot, snapshot
          assert_equal 1, snapshot.plan_id
          assert snapshot.plan_type_private
        end
      end
    end
  end
end
