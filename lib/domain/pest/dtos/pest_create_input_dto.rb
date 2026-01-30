# frozen_string_literal: true

module Domain
  module Pest
    module Dtos
      class PestCreateInputDto
        attr_reader :name, :name_scientific, :family, :order, :description, :occurrence_season, :region, :is_reference,
                    :pest_temperature_profile_attributes, :pest_thermal_requirement_attributes, :pest_control_methods_attributes, :crop_ids

        def initialize(name:, name_scientific: nil, family: nil, order: nil, description: nil, occurrence_season: nil, region: nil, is_reference: nil,
                       pest_temperature_profile_attributes: nil, pest_thermal_requirement_attributes: nil, pest_control_methods_attributes: nil, crop_ids: nil)
          @name = name
          @name_scientific = name_scientific
          @family = family
          @order = order
          @description = description
          @occurrence_season = occurrence_season
          @region = region
          @is_reference = is_reference
          @pest_temperature_profile_attributes = pest_temperature_profile_attributes
          @pest_thermal_requirement_attributes = pest_thermal_requirement_attributes
          @pest_control_methods_attributes = pest_control_methods_attributes
          @crop_ids = crop_ids || []
        end

        def self.from_hash(hash)
          pp = hash[:pest] || hash
          crop_ids = hash[:crop_ids]
          crop_ids = Array(crop_ids).map(&:to_s).reject(&:blank?) if crop_ids
          new(
            name: pp[:name],
            name_scientific: pp[:name_scientific],
            family: pp[:family],
            order: pp[:order],
            description: pp[:description],
            occurrence_season: pp[:occurrence_season],
            region: pp[:region],
            is_reference: pp[:is_reference],
            pest_temperature_profile_attributes: pp[:pest_temperature_profile_attributes],
            pest_thermal_requirement_attributes: pp[:pest_thermal_requirement_attributes],
            pest_control_methods_attributes: pp[:pest_control_methods_attributes],
            crop_ids: crop_ids || []
          )
        end
      end
    end
  end
end
