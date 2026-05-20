# frozen_string_literal: true

module Domain
  module Crop
    module Entities
      class CropStageEntity
        attr_reader :id, :crop_id, :name, :order, :temperature_requirement, :thermal_requirement, :sunshine_requirement, :nutrient_requirement, :created_at, :updated_at

        def initialize(attributes)
          @id = attributes[:id]
          @crop_id = attributes[:crop_id]
          @name = attributes[:name]
          @order = attributes[:order]
          @temperature_requirement = attributes[:temperature_requirement]
          @thermal_requirement = attributes[:thermal_requirement]
          @sunshine_requirement = attributes[:sunshine_requirement]
          @nutrient_requirement = attributes[:nutrient_requirement]
          @created_at = attributes[:created_at]
          @updated_at = attributes[:updated_at]

          validate!
        end

        private

        def validate!
          raise ArgumentError, "Name is required" if Domain::Shared.blank?(name)
          raise ArgumentError, "Crop ID is required" if Domain::Shared.blank?(crop_id)
          raise ArgumentError, "Order is required" if order.nil?
        end
      end
    end
  end
end
