# frozen_string_literal: true

module Domain
  module Farm
    module Dtos
      class FarmCreateInputDto
        attr_reader :name, :region, :latitude, :longitude, :user_id, :is_reference

        def initialize(name:, region:, latitude:, longitude:, user_id: nil, is_reference: false)
          @name = name
          @region = region
          @latitude = latitude
          @longitude = longitude
          @user_id = user_id
          @is_reference = is_reference
        end

        def self.from_hash(hash)
          farm_params = hash[:farm] || hash
          new(
            name: farm_params[:name],
            region: farm_params[:region],
            latitude: farm_params[:latitude],
            longitude: farm_params[:longitude],
            user_id: farm_params[:user_id],
            is_reference: farm_params[:is_reference] || false
          )
        end
      end
    end
  end
end