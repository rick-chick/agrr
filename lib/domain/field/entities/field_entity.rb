# frozen_string_literal: true

module Domain
  module Field
    module Entities
      class FieldEntity
        attr_reader :id, :farm_id, :user_id, :name, :description, :latitude, :longitude, :created_at, :updated_at

        def initialize(attributes)
          @id = attributes[:id]
          @farm_id = attributes[:farm_id]
          @user_id = attributes[:user_id]
          @name = attributes[:name]
          @description = attributes[:description]
          @latitude = attributes[:latitude]
          @longitude = attributes[:longitude]
          @created_at = attributes[:created_at]
          @updated_at = attributes[:updated_at]

          validate!
        end

        def display_name
          name.presence || "##{id}"
        end

        def coordinates
          [latitude, longitude]
        end

        def has_coordinates?
          latitude.present? && longitude.present?
        end

        private

        def validate!
          raise ArgumentError, "Name is required" if name.blank?
          raise ArgumentError, "Farm ID is required" if farm_id.blank?
          raise ArgumentError, "User ID is required" if user_id.blank?
        end
      end
    end
  end
end
