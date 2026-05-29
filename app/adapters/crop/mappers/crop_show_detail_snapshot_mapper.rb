# frozen_string_literal: true

module Adapters
  module Crop
    module Mappers
      # ActiveRecord → Domain::Crop::Dtos::CropShowDetailSnapshot
      module CropShowDetailSnapshotMapper
        Dtos = Domain::Crop::Dtos

        module_function

        def from_model(crop)
          stage_snapshots = crop_stage_snapshots_from(crop)
          pest_snapshots = pest_snapshots_from(crop)
          Dtos::CropShowDetailSnapshot.new(
            id: crop.id,
            user_id: crop.user_id,
            name: crop.name,
            variety: crop.variety,
            is_reference: crop.is_reference,
            area_per_unit: crop.area_per_unit,
            revenue_per_area: crop.revenue_per_area,
            region: crop.region,
            groups: crop.groups || [],
            created_at: crop.created_at,
            updated_at: crop.updated_at,
            crop_stages: stage_snapshots,
            pests: pest_snapshots
          )
        end

        def crop_stage_snapshots_from(crop)
          assoc = crop.association(:crop_stages)
          stage_records =
            if assoc.loaded?
              crop.crop_stages.sort_by(&:order)
            else
              crop.crop_stages.order(:order).to_a
            end

          stage_records.map { |stage| crop_stage_snapshot_from(stage) }
        end

        def crop_stage_snapshot_from(stage)
          Dtos::CropShowDetailStageSnapshot.new(
            id: stage.id,
            crop_id: stage.crop_id,
            name: stage.name,
            order: stage.order,
            created_at: stage.created_at,
            updated_at: stage.updated_at,
            temperature_requirement: temperature_requirement_snapshot_from(stage.temperature_requirement),
            thermal_requirement: thermal_requirement_snapshot_from(stage.thermal_requirement),
            sunshine_requirement: sunshine_requirement_snapshot_from(stage.sunshine_requirement),
            nutrient_requirement: nutrient_requirement_snapshot_from(stage.nutrient_requirement)
          )
        end

        def temperature_requirement_snapshot_from(record)
          return nil unless record

          Dtos::CropShowDetailTemperatureRequirementSnapshot.new(
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

        def thermal_requirement_snapshot_from(record)
          return nil unless record

          Dtos::CropShowDetailThermalRequirementSnapshot.new(
            id: record.id,
            crop_stage_id: record.crop_stage_id,
            required_gdd: record.required_gdd
          )
        end

        def sunshine_requirement_snapshot_from(record)
          return nil unless record

          Dtos::CropShowDetailSunshineRequirementSnapshot.new(
            id: record.id,
            crop_stage_id: record.crop_stage_id,
            minimum_sunshine_hours: record.minimum_sunshine_hours,
            target_sunshine_hours: record.target_sunshine_hours
          )
        end

        def nutrient_requirement_snapshot_from(record)
          return nil unless record

          Dtos::CropShowDetailNutrientRequirementSnapshot.new(
            id: record.id,
            crop_stage_id: record.crop_stage_id,
            daily_uptake_n: record.daily_uptake_n,
            daily_uptake_p: record.daily_uptake_p,
            daily_uptake_k: record.daily_uptake_k,
            region: record.region
          )
        end

        def pest_snapshots_from(crop)
          assoc = crop.association(:pests)
          pest_records =
            if assoc.loaded?
              crop.pests.sort_by { |pest| -pest.created_at.to_i }
            else
              crop.pests.recent.to_a
            end

          pest_records.map { |pest| pest_snapshot_from(pest) }
        end

        def pest_snapshot_from(pest)
          Dtos::CropShowDetailPestSnapshot.new(
            id: pest.id,
            user_id: pest.user_id,
            name: pest.name,
            name_scientific: pest.name_scientific,
            family: pest.family,
            order: pest.order,
            description: pest.description,
            occurrence_season: pest.occurrence_season,
            region: pest.region,
            is_reference: pest.is_reference,
            created_at: pest.created_at,
            updated_at: pest.updated_at
          )
        end
      end
    end
  end
end
