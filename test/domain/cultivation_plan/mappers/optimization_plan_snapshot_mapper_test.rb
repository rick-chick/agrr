# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module CultivationPlan
    module Mappers
      class OptimizationPlanSnapshotMapperTest < DomainLibTestCase
        test "to_snapshot builds OptimizationPlanSnapshot from weather DTOs" do
          target_end = Date.new(2027, 12, 31)
          weather_location = Domain::WeatherData::Dtos::WeatherLocation.new(
            id: 1,
            latitude: 35.0,
            longitude: 139.0,
            elevation: 0,
            timezone: "Asia/Tokyo",
            predicted_weather_data: { "x" => 1 }
          )
          farm_weather = Domain::WeatherData::Dtos::FarmWeatherPrediction.new(
            id: 2,
            weather_location_id: 1,
            predicted_weather_data: { "y" => 2 }
          )

          snapshot = OptimizationPlanSnapshotMapper.to_snapshot(
            plan_id: 42,
            plan_type_private: false,
            calculated_planning_start_date: nil,
            calculated_planning_end_date: nil,
            prediction_target_end_date: target_end,
            predicted_weather_data: nil,
            total_area: 10,
            weather_location_present: true,
            weather_location: weather_location,
            farm_weather: farm_weather
          )

          assert_instance_of Dtos::OptimizationPlanSnapshot, snapshot
          assert_equal 42, snapshot.plan_id
          refute snapshot.plan_type_private
          assert snapshot.weather_location_present
          assert_equal 1, snapshot.weather_location_input.id
          assert_equal 2, snapshot.farm_weather_input.id
        end
      end
    end
  end
end
