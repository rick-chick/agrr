# frozen_string_literal: true

module Domain
  module Pest
    module Mappers
      class PestMasterEditPayloadFromInputMapper
        def self.from_create_input(input_dto, user_id:)
          Domain::Pest::Dtos::PestMasterEditPayload.new(
            id: nil,
            new_record: true,
            name: input_dto.name,
            name_scientific: input_dto.name_scientific,
            family: input_dto.family,
            order: input_dto.order,
            description: input_dto.description,
            occurrence_season: input_dto.occurrence_season,
            is_reference: input_dto.is_reference || false,
            region: input_dto.region,
            user_id: user_id,
            associated_crop_ids: [],
            pest_temperature_profile_attributes: input_dto.pest_temperature_profile_attributes,
            pest_thermal_requirement_attributes: input_dto.pest_thermal_requirement_attributes,
            pest_control_methods_attributes: input_dto.pest_control_methods_attributes || {}
          )
        end

        def self.from_update_input(input_dto, user_id:)
          Domain::Pest::Dtos::PestMasterEditPayload.new(
            id: input_dto.pest_id,
            new_record: false,
            name: input_dto.name,
            name_scientific: input_dto.name_scientific,
            family: input_dto.family,
            order: input_dto.order,
            description: input_dto.description,
            occurrence_season: input_dto.occurrence_season,
            is_reference: input_dto.is_reference,
            region: input_dto.region,
            user_id: user_id,
            associated_crop_ids: [],
            pest_temperature_profile_attributes: input_dto.pest_temperature_profile_attributes,
            pest_thermal_requirement_attributes: input_dto.pest_thermal_requirement_attributes,
            pest_control_methods_attributes: input_dto.pest_control_methods_attributes || {}
          )
        end
      end
    end
  end
end
