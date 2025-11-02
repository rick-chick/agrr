# frozen_string_literal: true

module Domain
  module Pesticide
    module Entities
      class PesticideEntity
        attr_reader :id, :pesticide_id, :crop_id, :pest_id, :name, :active_ingredient, :description,
                    :is_reference, :created_at, :updated_at

        def initialize(attributes)
          @id = attributes[:id]
          @pesticide_id = attributes[:pesticide_id]
          @crop_id = attributes[:crop_id]
          @pest_id = attributes[:pest_id]
          @name = attributes[:name]
          @active_ingredient = attributes[:active_ingredient]
          @description = attributes[:description]
          @is_reference = attributes[:is_reference]
          @created_at = attributes[:created_at]
          @updated_at = attributes[:updated_at]

          validate!
        end

        def reference?
          !!is_reference
        end

        def display_name
          name.presence || "農薬 ##{id}"
        end

        private

        def validate!
          raise ArgumentError, "Pesticide ID is required" if pesticide_id.blank?
          raise ArgumentError, "Name is required" if name.blank?
          raise ArgumentError, "Crop ID is required" if crop_id.blank?
          raise ArgumentError, "Pest ID is required" if pest_id.blank?
        end
      end
    end
  end
end

