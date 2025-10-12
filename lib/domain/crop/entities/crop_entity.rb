# frozen_string_literal: true

module Domain
  module Crop
    module Entities
      class CropEntity
        attr_reader :id, :user_id, :name, :variety, :is_reference, :area_per_unit, :revenue_per_area, :agrr_crop_id, :created_at, :updated_at

        def initialize(attributes)
          @id = attributes[:id]
          @user_id = attributes[:user_id]
          @name = attributes[:name]
          @variety = attributes[:variety]
          @is_reference = attributes[:is_reference]
          @area_per_unit = attributes[:area_per_unit]
          @revenue_per_area = attributes[:revenue_per_area]
          @agrr_crop_id = attributes[:agrr_crop_id]
          @created_at = attributes[:created_at]
          @updated_at = attributes[:updated_at]

          validate!
        end

        def reference?
          !!is_reference
        end

        def display_name
          [name, variety].compact.join(" ")
        end

        private

        def validate!
          raise ArgumentError, "Name is required" if name.blank?
        end
      end
    end
  end
end


