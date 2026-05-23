# frozen_string_literal: true

module Domain
  module Pest
    module Dtos
      # マスタ害虫の編集・検証失敗の再試行に渡す属性値の束（ORM を境界に渡さない）。
      class PestMasterEditPayload
        attr_reader :id,
                    :new_record,
                    :error_messages,
                    :created_at,
                    :updated_at,
                    :name,
                    :name_scientific,
                    :family,
                    :order,
                    :description,
                    :occurrence_season,
                    :is_reference,
                    :region,
                    :user_id,
                    :associated_crop_ids,
                    :pest_temperature_profile_attributes,
                    :pest_thermal_requirement_attributes,
                    :pest_control_methods_attributes

        def initialize(
          id:,
          new_record:,
          error_messages: [],
          created_at: nil,
          updated_at: nil,
          name: nil,
          name_scientific: nil,
          family: nil,
          order: nil,
          description: nil,
          occurrence_season: nil,
          is_reference: false,
          region: nil,
          user_id: nil,
          associated_crop_ids: [],
          pest_temperature_profile_attributes: nil,
          pest_thermal_requirement_attributes: nil,
          pest_control_methods_attributes: {}
        )
          @id = id
          @new_record = new_record
          @error_messages = Array(error_messages)
          @created_at = created_at
          @updated_at = updated_at
          @name = name
          @name_scientific = name_scientific
          @family = family
          @order = order
          @description = description
          @occurrence_season = occurrence_season
          @is_reference = is_reference
          @region = region
          @user_id = user_id
          @associated_crop_ids = Array(associated_crop_ids).map(&:to_i)
          @pest_temperature_profile_attributes =
            pest_temperature_profile_attributes.nil? ? nil : Domain::Shared.symbolize_keys(pest_temperature_profile_attributes.to_hash)
          @pest_thermal_requirement_attributes =
            pest_thermal_requirement_attributes.nil? ? nil : Domain::Shared.symbolize_keys(pest_thermal_requirement_attributes.to_hash)
          @pest_control_methods_attributes = normalize_control_methods(pest_control_methods_attributes)
        end

        def new_record?
          @new_record
        end

        def persisted?
          !@new_record && Domain::Shared.present?(@id)
        end

        def is_reference?
          Domain::Shared::TypeConverters::BooleanConverter.cast(is_reference)
        end

        def self.for_blank_new
          new(
            id: nil,
            new_record: true,
            error_messages: [],
            name: nil,
            name_scientific: nil,
            family: nil,
            order: nil,
            description: nil,
            occurrence_season: nil,
            is_reference: false,
            region: nil,
            user_id: nil,
            associated_crop_ids: [],
            pest_temperature_profile_attributes: {
              id: nil,
              base_temperature: nil,
              max_temperature: nil,
              _destroy: false
            },
            pest_thermal_requirement_attributes: {
              id: nil,
              required_gdd: nil,
              first_generation_gdd: nil,
              _destroy: false
            },
            pest_control_methods_attributes: {
              "0" => {
                id: nil,
                method_type: nil,
                method_name: nil,
                description: nil,
                timing_hint: nil,
                _destroy: false
              }
            }
          )
        end

        private

        def normalize_control_methods(h)
          return {} if Domain::Shared.blank?(h)

          h.each_with_object({}) do |(k, v), acc|
            acc[k.to_s] = v.is_a?(Hash) ? Domain::Shared.symbolize_keys(v.to_hash) : {}
          end
        end
      end
    end
  end
end
