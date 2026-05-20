# frozen_string_literal: true

module Adapters
  module Pest
    module Mappers
      class PestMapper
        def self.pest_entity_from_record(record)
          Domain::Pest::Entities::PestEntity.new(
            id: record.id,
            user_id: record.user_id,
            name: record.name,
            name_scientific: record.name_scientific,
            family: record.family,
            order: record.order,
            description: record.description,
            occurrence_season: record.occurrence_season,
            region: record.region,
            is_reference: record.is_reference,
            created_at: record.created_at,
            updated_at: record.updated_at
          )
        rescue ArgumentError => e
          raise Domain::Shared::Exceptions::RecordInvalid, e.message
        end

        def self.detail_output_dto_from_record(record)
          tp = if record.pest_temperature_profile
                 p = record.pest_temperature_profile
                 Domain::Pest::Dtos::PestTemperatureProfileSnapshot.new(
                   base_temperature: p.base_temperature,
                   max_temperature: p.max_temperature
                 )
               end

          tr = if record.pest_thermal_requirement
                 r = record.pest_thermal_requirement
                 Domain::Pest::Dtos::PestThermalRequirementSnapshot.new(
                   required_gdd: r.required_gdd,
                   first_generation_gdd: r.first_generation_gdd
                 )
               end

          cms = record.pest_control_methods.sort_by(&:id).map do |m|
            Domain::Pest::Dtos::PestControlMethodSnapshot.new(
              method_type: m.method_type,
              method_name: m.method_name,
              description: m.description,
              timing_hint: m.timing_hint
            )
          end

          crops = record.crops.recent.map do |c|
            Domain::Crop::Entities::CropEntity.new(
              id: c.id,
              user_id: c.user_id,
              name: c.name,
              variety: c.variety,
              is_reference: c.is_reference,
              area_per_unit: c.area_per_unit,
              revenue_per_area: c.revenue_per_area,
              region: c.region,
              groups: [],
              crop_stages: [],
              created_at: c.created_at,
              updated_at: c.updated_at
            )
          end

          Domain::Pest::Dtos::PestDetailOutput.new(
            pest: pest_entity_from_record(record),
            temperature_profile: tp,
            thermal_requirement: tr,
            control_methods: cms,
            associated_crops: crops
          )
        end
      end
    end
  end
end
