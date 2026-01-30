# frozen_string_literal: true

module Domain
  module Farm
    module Dtos
      class FarmUpdateInputDto
        attr_reader :farm_id, :name, :region, :latitude, :longitude

        def initialize(farm_id:, name: nil, region: nil, latitude: nil, longitude: nil)
          @farm_id = farm_id
          @name = name
          @region = region
          @latitude = latitude
          @longitude = longitude
        end

        def self.from_hash(hash, farm_id)
          farm_params = hash[:farm] || hash
          new(
            farm_id: farm_id,
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