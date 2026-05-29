# frozen_string_literal: true

module Adapters
  module Pest
    module Mappers
      module PestShowDetailSnapshotMapper
        Dtos = Domain::Pest::Dtos

        module_function

        def from_model(pest)
          Dtos::PestShowDetailSnapshot.new(
            pest: pest_snapshot_from(pest),
            temperature_profile: temperature_profile_snapshot_from(pest.pest_temperature_profile),
            thermal_requirement: thermal_requirement_snapshot_from(pest.pest_thermal_requirement),
            control_methods: pest.pest_control_methods.map { |method| control_method_snapshot_from(method) },
            crops: pest.crops.map { |crop| crop_snapshot_from(crop) }
          )
        end

        def pest_snapshot_from(pest)
          Dtos::PestShowDetailPestSnapshot.new(
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

        def temperature_profile_snapshot_from(profile)
          return nil unless profile

          Domain::Pest::Dtos::PestTemperatureProfileSnapshot.new(
            base_temperature: profile.base_temperature,
            max_temperature: profile.max_temperature
          )
        end

        def thermal_requirement_snapshot_from(requirement)
          return nil unless requirement

          Domain::Pest::Dtos::PestThermalRequirementSnapshot.new(
            required_gdd: requirement.required_gdd,
            first_generation_gdd: requirement.first_generation_gdd
          )
        end

        def control_method_snapshot_from(method)
          Dtos::PestShowDetailControlMethodSnapshot.new(
            id: method.id,
            method_type: method.method_type,
            method_name: method.method_name,
            description: method.description,
            timing_hint: method.timing_hint
          )
        end

        def crop_snapshot_from(crop)
          Dtos::PestShowDetailCropSnapshot.new(
            id: crop.id,
            user_id: crop.user_id,
            name: crop.name,
            variety: crop.variety,
            is_reference: crop.is_reference,
            area_per_unit: crop.area_per_unit,
            revenue_per_area: crop.revenue_per_area,
            region: crop.region,
            created_at: crop.created_at,
            updated_at: crop.updated_at
          )
        end
      end
    end
  end
end
