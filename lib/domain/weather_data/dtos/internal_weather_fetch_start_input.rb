# frozen_string_literal: true

module Domain
  module WeatherData
    module Dtos
      class InternalWeatherFetchStartInput
        attr_reader :farm_id

        def initialize(farm_id:)
          @farm_id = farm_id
        end
      end
    end
  end
end
