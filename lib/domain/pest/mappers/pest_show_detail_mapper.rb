# frozen_string_literal: true

module Domain
  module Pest
    module Mappers
      module PestShowDetailMapper
        module_function

        # @param snapshot [Dtos::PestShowDetailSnapshot]
        # @return [Domain::Pest::Dtos::PestDetailOutput]
        def from_snapshot(snapshot)
          pest_entity = pest_entity_from_snapshot(snapshot.pest)
          temperature_profile = temperature_profile_from_snapshot(snapshot.temperature_profile)
          thermal_requirement = thermal_requirement_from_snapshot(snapshot.thermal_requirement)
          control_methods = control_methods_from_snapshot(snapshot.control_methods)
          associated_crops = associated_crops_from_snapshot(snapshot.crops)

          Dtos::PestDetailOutput.new(
            pest: pest_entity,
            temperature_profile: temperature_profile,
            thermal_requirement: thermal_requirement,
            control_methods: control_methods,
            associated_crops: associated_crops
          )
        end

        def pest_entity_from_snapshot(pest_wire)
          Entities::PestEntity.new(
            id: pest_wire.id,
            user_id: pest_wire.user_id,
            name: pest_wire.name,
            name_scientific: pest_wire.name_scientific,
            family: pest_wire.family,
            order: pest_wire.order,
            description: pest_wire.description,
            occurrence_season: pest_wire.occurrence_season,
            region: pest_wire.region,
            is_reference: pest_wire.is_reference,
            created_at: pest_wire.created_at,
            updated_at: pest_wire.updated_at
          )
        end

        def temperature_profile_from_snapshot(profile_wire)
          return nil unless profile_wire

          Dtos::PestTemperatureProfileSnapshot.new(
            base_temperature: profile_wire.base_temperature,
            max_temperature: profile_wire.max_temperature
          )
        end

        def thermal_requirement_from_snapshot(requirement_wire)
          return nil unless requirement_wire

          Dtos::PestThermalRequirementSnapshot.new(
            required_gdd: requirement_wire.required_gdd,
            first_generation_gdd: requirement_wire.first_generation_gdd
          )
        end

        def control_methods_from_snapshot(method_wires)
          method_wires.sort_by(&:id).map do |method_wire|
            Dtos::PestControlMethodSnapshot.new(
              method_type: method_wire.method_type,
              method_name: method_wire.method_name,
              description: method_wire.description,
              timing_hint: method_wire.timing_hint
            )
          end
        end

        def associated_crops_from_snapshot(crop_wires)
          crop_wires.sort_by(&:name).map do |crop_wire|
            Domain::Crop::Entities::CropEntity.new(
              id: crop_wire.id,
              user_id: crop_wire.user_id,
              name: crop_wire.name,
              variety: crop_wire.variety,
              is_reference: crop_wire.is_reference,
              area_per_unit: crop_wire.area_per_unit,
              revenue_per_area: crop_wire.revenue_per_area,
              region: crop_wire.region,
              groups: [],
              crop_stages: [],
              created_at: crop_wire.created_at,
              updated_at: crop_wire.updated_at
            )
          end
        end
      end
    end
  end
end
