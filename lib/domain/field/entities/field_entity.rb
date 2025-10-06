# frozen_string_literal: true

module Domain
  module Field
    module Entities
      class FieldEntity
        attr_reader :id, :farm_id, :user_id, :name, :latitude, :longitude, :description, :created_at, :updated_at

        def initialize(attributes)
          @id = attributes[:id]
          @farm_id = attributes[:farm_id]
          @user_id = attributes[:user_id]
          @name = attributes[:name]
          @latitude = attributes[:latitude]
          @longitude = attributes[:longitude]
          @description = attributes[:description]
          @created_at = attributes[:created_at]
          @updated_at = attributes[:updated_at]

          validate!
        end

        def coordinates
          [latitude, longitude]
        end

        def has_coordinates?
          latitude.present? && longitude.present?
        end

        def display_name
          name.presence || "圃場 ##{id}"
        end

        private

        def validate!
          raise ArgumentError, "Name is required" if name.blank?
          raise ArgumentError, "Farm ID is required" if farm_id.blank?
          raise ArgumentError, "User ID is required" if user_id.blank?
          
          if latitude
            lat_num = latitude.to_f
            raise ArgumentError, "Latitude must be between -90 and 90" if lat_num < -90 || lat_num > 90
          end
          
          if longitude
            lng_num = longitude.to_f
            raise ArgumentError, "Longitude must be between -180 and 180" if lng_num < -180 || lng_num > 180
          end
        end
      end
    end
  end
end
