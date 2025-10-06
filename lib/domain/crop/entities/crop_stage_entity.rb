# frozen_string_literal: true

module Domain
  module Crop
    module Entities
      class CropStageEntity
        attr_reader :id, :crop_id, :name, :order, :temperature, :sunshine, :thermal

        def initialize(attributes)
          @id = attributes[:id]
          @crop_id = attributes[:crop_id]
          @name = attributes[:name]
          @order = attributes[:order]
          @temperature = attributes[:temperature]
          @sunshine = attributes[:sunshine]
          @thermal = attributes[:thermal]

          validate!
        end

        private

        def validate!
          raise ArgumentError, "Name is required" if name.blank?
          raise ArgumentError, "Crop ID is required" if crop_id.blank?
          raise ArgumentError, "Order is required" if order.nil?
        end
      end
    end
  end
end


