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

        test "build_output truncates gdd_data at final cumulative requirement" do
          start_date = Date.new(2026, 3, 1)
          end_date = Date.new(2026, 3, 5)
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
            stages: [
              {
                name: "Stage1",
                order: 1,
                gdd_required: 100.0,
                cumulative_gdd_required: 100.0
              }
            ]
          )

          progress_result = {
            "progress_records" => [
              { "date" => "2026-03-01", "cumulative_gdd" => 40.0, "stage_name" => "S1" },
              { "date" => "2026-03-02", "cumulative_gdd" => 80.0, "stage_name" => "S1" },
              { "date" => "2026-03-03", "cumulative_gdd" => 110.0, "stage_name" => "S1" },
              { "date" => "2026-03-04", "cumulative_gdd" => 130.0, "stage_name" => "S1" },
              { "date" => "2026-03-05", "cumulative_gdd" => 150.0, "stage_name" => "S1" }
            ]
          }

          dto = FieldCultivationClimateDataMapper.build_output(
            context: context,
            weather_records: [],
            progress_result: progress_result
          )

          assert_equal 3, dto.gdd_data.length
          assert_equal "2026-03-03", dto.gdd_data.last[:date]
          assert_in_delta 110.0, dto.gdd_data.last[:cumulative_gdd], 0.01
        end

        test "build_output aligns weather_data span with truncated gdd_data" do
          start_date = Date.new(2026, 3, 1)
          end_date = Date.new(2026, 3, 5)
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
            stages: [
              {
                name: "Stage1",
                order: 1,
                gdd_required: 100.0,
                cumulative_gdd_required: 100.0
              }
            ]
          )

          weather_records = (1..5).map do |day|
            date = Date.new(2026, 3, day)
            {
              "date" => date.to_s,
              "temperature_max" => 30.0,
              "temperature_min" => 20.0,
              "temperature_mean" => 25.0
            }
          end

          progress_result = {
            "progress_records" => [
              { "date" => "2026-03-01", "cumulative_gdd" => 40.0, "stage_name" => "S1" },
              { "date" => "2026-03-02", "cumulative_gdd" => 80.0, "stage_name" => "S1" },
              { "date" => "2026-03-03", "cumulative_gdd" => 110.0, "stage_name" => "S1" },
              { "date" => "2026-03-04", "cumulative_gdd" => 130.0, "stage_name" => "S1" },
              { "date" => "2026-03-05", "cumulative_gdd" => 150.0, "stage_name" => "S1" }
            ]
          }

          dto = FieldCultivationClimateDataMapper.build_output(
            context: context,
            weather_records: weather_records,
            progress_result: progress_result
          )

          assert_equal dto.gdd_data.length, dto.weather_data.length
          assert_equal dto.gdd_data.first[:date], dto.weather_data.first["date"]
          assert_equal dto.gdd_data.last[:date], dto.weather_data.last["date"]
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
