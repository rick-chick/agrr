# frozen_string_literal: true

module Domain
  module Farm
    module Dtos
      class FarmShowDetailFarmSnapshot
        attr_reader :id, :name, :latitude, :longitude, :region, :user_id,
                    :created_at, :updated_at, :is_reference, :weather_data_status,
                    :weather_data_fetched_years, :weather_data_total_years,
                    :weather_data_last_error, :last_broadcast_at

        def initialize(id:, name:, latitude:, longitude:, region:, user_id:,
                       created_at:, updated_at:, is_reference:, weather_data_status:,
                       weather_data_fetched_years:, weather_data_total_years:,
                       weather_data_last_error:, last_broadcast_at:)
          @id = id
          @name = name
          @latitude = latitude
          @longitude = longitude
          @region = region
          @user_id = user_id
          @created_at = created_at
          @updated_at = updated_at
          @is_reference = is_reference
          @weather_data_status = weather_data_status
          @weather_data_fetched_years = weather_data_fetched_years
          @weather_data_total_years = weather_data_total_years
          @weather_data_last_error = weather_data_last_error
          @last_broadcast_at = last_broadcast_at
          freeze
        end
      end

      class FarmShowDetailFieldSnapshot
        attr_reader :id, :name, :area, :daily_fixed_cost, :region, :farm_id,
                    :user_id, :created_at, :updated_at

        def initialize(id:, name:, area:, daily_fixed_cost:, region:, farm_id:,
                       user_id:, created_at:, updated_at:)
          @id = id
          @name = name
          @area = area
          @daily_fixed_cost = daily_fixed_cost
          @region = region
          @farm_id = farm_id
          @user_id = user_id
          @created_at = created_at
          @updated_at = updated_at
          freeze
        end
      end

      class FarmShowDetailSnapshot
        attr_reader :farm, :fields

        def initialize(farm:, fields:)
          @farm = farm
          @fields = fields
          freeze
        end
      end
    end
  end
end
