# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module FieldCultivation
    module Mappers
      class FieldCultivationClimateDataMapperTest < DomainLibTestCase
        test "build_output assembles climate dto from context and progress" do
          start_date = Date.new(2026, 3, 1)
          end_date = Date.new(2026, 3, 2)
          context = Dtos::FieldCultivationClimateContextSnapshot.new(
            field_cultivation_id: 1,
            field_name: "A",
            crop_name: "Tomato",
            start_date: start_date,
            completion_date: end_date,
            farm_id: 10,
            farm_name: "Farm",
            farm_latitude: 35.0,
            farm_longitude: 139.0,
            plan_id: 5,
            plan_type_public: false,
            plan_predicted_weather_present: true,
            prediction_target_end_date: nil,
            calculated_planning_end_date: nil,
            predicted_weather_data: {},
            crop_id: 2,
            base_temperature: 10.0,
            optimal_temperature_range: { min: 15, max: 25 },
            stages: []
          )

          weather_records = [
            {
              "date" => start_date.to_s,
              "temperature_max" => 20.0,
              "temperature_min" => 10.0,
              "temperature_mean" => 15.0
            }
          ]

          progress_result = {
            "progress_records" => [
              { "date" => start_date.to_s, "cumulative_gdd" => 5.0, "stage_name" => "S1" }
            ]
          }

          dto = FieldCultivationClimateDataMapper.build_output(
            context: context,
            weather_records: weather_records,
            progress_result: progress_result
          )

          assert_equal 1, dto.field_cultivation[:id]
          assert_equal 10, dto.farm[:id]
          assert_equal 1, dto.weather_data.length
          assert_equal 5.0, dto.gdd_data.first[:gdd]
          assert_equal true, dto.debug_info[:using_agrr_progress]
        end

        test "extract_weather_records filters by cultivation period" do
          payload = {
            "data" => [
              { "time" => "2026-01-01", "temperature_2m_max" => 10, "temperature_2m_min" => 0 },
              { "time" => "2026-06-01", "temperature_2m_max" => 20, "temperature_2m_min" => 10 }
            ]
          }

          records = FieldCultivationClimateDataMapper.extract_weather_records(
            payload,
            Date.new(2026, 5, 1),
            Date.new(2026, 6, 30)
          )

          assert_equal 1, records.length
          assert_equal "2026-06-01", records.first["date"]
        end
      end
    end
  end
end
