# frozen_string_literal: true

module Adapters
  module Pest
    module Mappers
      class PestMasterEditPayloadMapper
        def self.from_record(pest)
          tp = pest.pest_temperature_profile
          tp_attrs =
            if tp
              {
                id: tp.id,
                base_temperature: tp.base_temperature,
                max_temperature: tp.max_temperature,
                _destroy: false
              }
            else
              {
                id: nil,
                base_temperature: nil,
                max_temperature: nil,
                _destroy: false
              }
            end

          tr = pest.pest_thermal_requirement
          tr_attrs =
            if tr
              {
                id: tr.id,
                required_gdd: tr.required_gdd,
                first_generation_gdd: tr.first_generation_gdd,
                _destroy: false
              }
            else
              {
                id: nil,
                required_gdd: nil,
                first_generation_gdd: nil,
                _destroy: false
              }
            end

          cm_hash = {}
          pest.pest_control_methods.sort_by(&:id).each_with_index do |m, i|
            cm_hash[i.to_s] = {
              id: m.id,
              method_type: m.method_type,
              method_name: m.method_name,
              description: m.description,
              timing_hint: m.timing_hint,
              _destroy: false
            }
          end

          Domain::Pest::Dtos::PestMasterEditPayload.new(
            id: pest.id,
            new_record: pest.new_record?,
            error_messages: pest.errors.full_messages,
            created_at: pest.created_at,
            updated_at: pest.updated_at,
            name: pest.name,
            name_scientific: pest.name_scientific,
            family: pest.family,
            order: pest.order,
            description: pest.description,
            occurrence_season: pest.occurrence_season,
            is_reference: pest.is_reference,
            region: pest.region,
            user_id: pest.user_id,
            associated_crop_ids: pest.persisted? ? pest.crop_ids : [],
            pest_temperature_profile_attributes: tp_attrs,
            pest_thermal_requirement_attributes: tr_attrs,
            pest_control_methods_attributes: cm_hash
          )
        end
      end
    end
  end
end
