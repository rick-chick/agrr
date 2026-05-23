# frozen_string_literal: true

module Adapters
  module Crop
    module Gateways
      module CropStageRequirementEntitySupport
        module_function

        def crop_stage_entity_from_record(record)
          temperature_req = record.temperature_requirement ? temperature_requirement_entity_from_record(record.temperature_requirement) : nil
          thermal_req = record.thermal_requirement ? thermal_requirement_entity_from_record(record.thermal_requirement) : nil
          sunshine_req = record.sunshine_requirement ? sunshine_requirement_entity_from_record(record.sunshine_requirement) : nil
          nutrient_req = record.nutrient_requirement ? nutrient_requirement_entity_from_record(record.nutrient_requirement) : nil

          Domain::Crop::Entities::CropStageEntity.new(
            id: record.id,
            crop_id: record.crop_id,
            name: record.name,
            order: record.order,
            temperature_requirement: temperature_req,
            thermal_requirement: thermal_req,
            sunshine_requirement: sunshine_req,
            nutrient_requirement: nutrient_req,
            created_at: record.created_at,
            updated_at: record.updated_at
          )
        end

        def temperature_requirement_entity_from_record(record)
          Domain::Crop::Entities::TemperatureRequirementEntity.new(
            id: record.id,
            crop_stage_id: record.crop_stage_id,
            base_temperature: record.base_temperature,
            optimal_min: record.optimal_min,
            optimal_max: record.optimal_max,
            low_stress_threshold: record.low_stress_threshold,
            high_stress_threshold: record.high_stress_threshold,
            frost_threshold: record.frost_threshold,
            sterility_risk_threshold: record.sterility_risk_threshold,
            max_temperature: record.max_temperature
          )
        end

        def thermal_requirement_entity_from_record(record)
          Domain::Crop::Entities::ThermalRequirementEntity.new(
            id: record.id,
            crop_stage_id: record.crop_stage_id,
            required_gdd: record.required_gdd
          )
        end

        def sunshine_requirement_entity_from_record(record)
          Domain::Crop::Entities::SunshineRequirementEntity.new(
            id: record.id,
            crop_stage_id: record.crop_stage_id,
            minimum_sunshine_hours: record.minimum_sunshine_hours,
            target_sunshine_hours: record.target_sunshine_hours
          )
        end

        def nutrient_requirement_entity_from_record(record)
          Domain::Crop::Entities::NutrientRequirementEntity.new(
            id: record.id,
            crop_stage_id: record.crop_stage_id,
            daily_uptake_n: record.daily_uptake_n,
            daily_uptake_p: record.daily_uptake_p,
            daily_uptake_k: record.daily_uptake_k,
            region: record.region
          )
        end
      end
    end
  end
end
