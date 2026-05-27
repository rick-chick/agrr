# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Dtos
      # PlanSaveFarmGateway#find_reference_farm 戻り値。
      class PlanSaveReferenceFarmSnapshot
        attr_reader :id, :name, :latitude, :longitude, :region, :weather_location_id

        def initialize(id:, name:, latitude:, longitude:, region:, weather_location_id:)
          @id = id.to_i
          @name = name.nil? ? nil : name.to_s
          @latitude = latitude
          @longitude = longitude
          @region = region.nil? ? nil : region.to_s
          @weather_location_id = weather_location_id&.to_i
          freeze
        end
      end
    end
  end
end
