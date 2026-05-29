# frozen_string_literal: true

module Domain
  module Crop
    module Mappers
      module CropShowDetailMapper
        module_function

        # @param snapshot [Dtos::CropShowDetailSnapshot]
        # @return [Domain::Crop::Dtos::CropDetailOutput]
        def from_snapshot(snapshot)
          crop_entity = crop_entity_from_snapshot(snapshot)
          Dtos::CropDetailOutput.new(crop: crop_entity)
        end

        def crop_entity_from_snapshot(wire)
          Entities::CropEntity.new(
            id: wire.id,
            user_id: wire.user_id,
            name: wire.name,
            variety: wire.variety,
            is_reference: wire.is_reference,
            area_per_unit: wire.area_per_unit,
            revenue_per_area: wire.revenue_per_area,
            region: wire.region,
            groups: wire.groups || [],
            crop_stages: wire.crop_stages.map { |stage_wire| crop_stage_entity_from_snapshot(stage_wire) },
            associated_pests: wire.pests.map { |pest_wire| pest_entity_from_snapshot(pest_wire) },
            created_at: wire.created_at,
            updated_at: wire.updated_at
          )
        end

        def crop_stage_entity_from_snapshot(stage_wire)
          Entities::CropStageEntity.new(
            id: stage_wire.id,
            crop_id: stage_wire.crop_id,
            name: stage_wire.name,
            order: stage_wire.order,
            temperature_requirement: temperature_requirement_entity_from_snapshot(stage_wire.temperature_requirement),
            thermal_requirement: thermal_requirement_entity_from_snapshot(stage_wire.thermal_requirement),
            sunshine_requirement: sunshine_requirement_entity_from_snapshot(stage_wire.sunshine_requirement),
            nutrient_requirement: nutrient_requirement_entity_from_snapshot(stage_wire.nutrient_requirement),
            created_at: stage_wire.created_at,
            updated_at: stage_wire.updated_at
          )
        end

        def temperature_requirement_entity_from_snapshot(wire)
          return nil unless wire

          Entities::TemperatureRequirementEntity.new(
            id: wire.id,
            crop_stage_id: wire.crop_stage_id,
            base_temperature: wire.base_temperature,
            optimal_min: wire.optimal_min,
            optimal_max: wire.optimal_max,
            low_stress_threshold: wire.low_stress_threshold,
            high_stress_threshold: wire.high_stress_threshold,
            frost_threshold: wire.frost_threshold,
            sterility_risk_threshold: wire.sterility_risk_threshold,
            max_temperature: wire.max_temperature
          )
        end

        def thermal_requirement_entity_from_snapshot(wire)
          return nil unless wire

          Entities::ThermalRequirementEntity.new(
            id: wire.id,
            crop_stage_id: wire.crop_stage_id,
            required_gdd: wire.required_gdd
          )
        end

        def sunshine_requirement_entity_from_snapshot(wire)
          return nil unless wire

          Entities::SunshineRequirementEntity.new(
            id: wire.id,
            crop_stage_id: wire.crop_stage_id,
            minimum_sunshine_hours: wire.minimum_sunshine_hours,
            target_sunshine_hours: wire.target_sunshine_hours
          )
        end

        def nutrient_requirement_entity_from_snapshot(wire)
          return nil unless wire

          Entities::NutrientRequirementEntity.new(
            id: wire.id,
            crop_stage_id: wire.crop_stage_id,
            daily_uptake_n: wire.daily_uptake_n,
            daily_uptake_p: wire.daily_uptake_p,
            daily_uptake_k: wire.daily_uptake_k,
            region: wire.region
          )
        end

        def pest_entity_from_snapshot(wire)
          Domain::Pest::Entities::PestEntity.new(
            id: wire.id,
            user_id: wire.user_id,
            name: wire.name,
            name_scientific: wire.name_scientific,
            family: wire.family,
            order: wire.order,
            description: wire.description,
            occurrence_season: wire.occurrence_season,
            region: wire.region,
            is_reference: wire.is_reference,
            created_at: wire.created_at,
            updated_at: wire.updated_at
          )
        end
      end
    end
  end
end
