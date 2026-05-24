# frozen_string_literal: true

require "domain_lib_test_helper"

module Domain
  module FieldCultivation
    module Mappers
      class FieldCultivationClimateContextSnapshotMapperTest < DomainLibTestCase
        test "to_context_snapshot builds stages and base temperature from crop entity" do
          temp_req = Domain::Crop::Entities::TemperatureRequirementEntity.new(
            id: 1,
            crop_stage_id: 1,
            base_temperature: 8.0,
            optimal_min: 15.0,
            optimal_max: 25.0,
            low_stress_threshold: 10.0,
            high_stress_threshold: 30.0,
            frost_threshold: nil,
            sterility_risk_threshold: nil,
            max_temperature: nil
          )
          thermal_req = Domain::Crop::Entities::ThermalRequirementEntity.new(
            id: 1,
            crop_stage_id: 1,
            required_gdd: 100.0
          )
          stage = Domain::Crop::Entities::CropStageEntity.new(
            id: 1,
            crop_id: 5,
            name: "Vegetative",
            order: 1,
            temperature_requirement: temp_req,
            thermal_requirement: thermal_req
          )
          crop = Domain::Crop::Entities::CropEntity.new(
            id: 5,
            user_id: 1,
            name: "Tomato",
            variety: nil,
            is_reference: false,
            crop_stages: [ stage ]
          )
          source = Dtos::FieldCultivationClimateSourceSnapshot.new(
            field_cultivation_id: 10,
            field_name: "Field A",
            crop_name: "Tomato",
            start_date: Date.new(2024, 4, 1),
            completion_date: Date.new(2024, 8, 1),
            farm_id: 2,
            farm_name: "Farm",
            farm_latitude: 35.0,
            farm_longitude: 135.0,
            weather_location_id: 3,
            weather_location_present: true,
            weather_location_timezone: "Asia/Tokyo",
            plan_id: 7,
            plan_type_public: false,
            plan_predicted_weather_present: true,
            prediction_target_end_date: Date.new(2025, 12, 31),
            calculated_planning_end_date: Date.new(2025, 12, 31),
            predicted_weather_data: { "data" => [] },
            plan_crop_crop_id: 5
          )

          ctx = FieldCultivationClimateContextSnapshotMapper.to_context_snapshot(source: source, crop: crop)

          assert_equal 10, ctx.field_cultivation_id
          assert_equal 5, ctx.crop_id
          assert_equal 8.0, ctx.base_temperature
          assert_equal 1, ctx.stages.length
          assert_equal 100.0, ctx.stages.first[:cumulative_gdd_required]
        end
      end
    end
  end
end
