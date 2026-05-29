# frozen_string_literal: true

module Domain
  module Crop
    module Dtos
      class CropShowDetailStageSnapshot
        attr_reader :id, :crop_id, :name, :order, :created_at, :updated_at,
                    :temperature_requirement, :thermal_requirement,
                    :sunshine_requirement, :nutrient_requirement

        def initialize(id:, crop_id:, name:, order:, created_at:, updated_at:,
                       temperature_requirement:, thermal_requirement:,
                       sunshine_requirement:, nutrient_requirement:)
          @id = id
          @crop_id = crop_id
          @name = name
          @order = order
          @created_at = created_at
          @updated_at = updated_at
          @temperature_requirement = temperature_requirement
          @thermal_requirement = thermal_requirement
          @sunshine_requirement = sunshine_requirement
          @nutrient_requirement = nutrient_requirement
          freeze
        end
      end
    end
  end
end
