# frozen_string_literal: true

require "test_helper"

module Adapters
  module CultivationPlan
    module Mappers
      class OptimizationPlanReadSnapshotMapperTest < ActiveSupport::TestCase
        test "from_cultivation_plan builds OptimizationPlanSnapshot" do
          user = create(:user)
          weather_location = create(:weather_location)
          farm = create(:farm, user: user, weather_location: weather_location)
          plan = create(:cultivation_plan, farm: farm, user: user, plan_type: "private")

          snapshot = OptimizationPlanReadSnapshotMapper.from_cultivation_plan(plan)

          assert_instance_of Domain::CultivationPlan::Dtos::OptimizationPlanSnapshot, snapshot
          assert_equal plan.id, snapshot.plan_id
          assert snapshot.plan_type_private
          assert snapshot.weather_location_present
          assert_equal weather_location.id, snapshot.weather_location_input.id
        end
      end
    end
  end
end
