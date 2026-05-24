# frozen_string_literal: true

module Domain
  module Farm
    module Interactors
      class MarkFarmWeatherDataFailedInteractor
        def initialize(farm_gateway:)
          @farm_gateway = farm_gateway
        end

        def call(input_dto)
          attrs = Calculators::FarmWeatherProgressCalculator.failed_attrs(error_message: input_dto.error_message)
          @farm_gateway.update_weather_progress(input_dto.farm_id, attrs)
        end
      end
    end
  end
end
