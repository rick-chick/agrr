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

        def crop_entity_from_snapshot(snapshot)
          Entities::CropEntity.new(
            id: snapshot.id,
            user_id: snapshot.user_id,
            name: snapshot.name,
            variety: snapshot.variety,
            is_reference: snapshot.is_reference,
            area_per_unit: snapshot.area_per_unit,
            revenue_per_area: snapshot.revenue_per_area,
            region: snapshot.region,
            groups: snapshot.groups || [],
            crop_stages: snapshot.crop_stages.map { |stage_snapshot| crop_stage_entity_from_snapshot(stage_snapshot) },
            associated_pests: snapshot.pests.map { |pest_snapshot| pest_entity_from_snapshot(pest_snapshot) },
            created_at: snapshot.created_at,
            updated_at: snapshot.updated_at
          )
        end

        def crop_stage_entity_from_snapshot(stage_snapshot)
          Entities::CropStageEntity.new(
            id: stage_snapshot.id,
            crop_id: stage_snapshot.crop_id,
            name: stage_snapshot.name,
            order: stage_snapshot.order,
            temperature_requirement: temperature_requirement_entity_from_snapshot(stage_snapshot.temperature_requirement),
            thermal_requirement: thermal_requirement_entity_from_snapshot(stage_snapshot.thermal_requirement),
            sunshine_requirement: sunshine_requirement_entity_from_snapshot(stage_snapshot.sunshine_requirement),
            nutrient_requirement: nutrient_requirement_entity_from_snapshot(stage_snapshot.nutrient_requirement),
            created_at: stage_snapshot.created_at,
            updated_at: stage_snapshot.updated_at
          )
        end

        def temperature_requirement_entity_from_snapshot(snapshot)
          return nil unless snapshot

          Entities::TemperatureRequirementEntity.new(
            id: snapshot.id,
            crop_stage_id: snapshot.crop_stage_id,
            base_temperature: snapshot.base_temperature,
            optimal_min: snapshot.optimal_min,
            optimal_max: snapshot.optimal_max,
            low_stress_threshold: snapshot.low_stress_threshold,
            high_stress_threshold: snapshot.high_stress_threshold,
            frost_threshold: snapshot.frost_threshold,
            sterility_risk_threshold: snapshot.sterility_risk_threshold,
            max_temperature: snapshot.max_temperature
          )
        end

        def thermal_requirement_entity_from_snapshot(snapshot)
          return nil unless snapshot

          Entities::ThermalRequirementEntity.new(
            id: snapshot.id,
            crop_stage_id: snapshot.crop_stage_id,
            required_gdd: snapshot.required_gdd
          )
        end

        def sunshine_requirement_entity_from_snapshot(snapshot)
          return nil unless snapshot

          Entities::SunshineRequirementEntity.new(
            id: snapshot.id,
            crop_stage_id: snapshot.crop_stage_id,
            minimum_sunshine_hours: snapshot.minimum_sunshine_hours,
            target_sunshine_hours: snapshot.target_sunshine_hours
          )
        end

        def nutrient_requirement_entity_from_snapshot(snapshot)
          return nil unless snapshot

          Entities::NutrientRequirementEntity.new(
            id: snapshot.id,
            crop_stage_id: snapshot.crop_stage_id,
            daily_uptake_n: snapshot.daily_uptake_n,
            daily_uptake_p: snapshot.daily_uptake_p,
            daily_uptake_k: snapshot.daily_uptake_k,
            region: snapshot.region
          )
        end

        def pest_entity_from_snapshot(snapshot)
          Domain::Pest::Entities::PestEntity.new(
            id: snapshot.id,
            user_id: snapshot.user_id,
            name: snapshot.name,
            name_scientific: snapshot.name_scientific,
            family: snapshot.family,
            order: snapshot.order,
            description: snapshot.description,
            occurrence_season: snapshot.occurrence_season,
            region: snapshot.region,
            is_reference: snapshot.is_reference,
            created_at: snapshot.created_at,
            updated_at: snapshot.updated_at
          )
        end
      end
    end
  end
end
