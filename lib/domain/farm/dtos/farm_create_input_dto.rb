# frozen_string_literal: true

module Domain
  module Farm
    module Dtos
      class FarmCreateInputDto
        attr_reader :name, :region, :latitude, :longitude

        def initialize(name:, region:, latitude:, longitude:)
          @name = name
          @region = region
          @latitude = latitude
          @longitude = longitude
        end

        def self.from_hash(hash)
          farm_params = hash[:farm] || hash
          new(
            name: farm_params[:name],
            region: farm_params[:region],
            latitude: farm_params[:latitude],
            longitude: farm_params[:longitude]
          )
        end
      end
    end
  end
end