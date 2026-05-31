# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Gateways
      class AdjustWeatherPredictionActiveRecordGateway < Domain::CultivationPlan::Gateways::AdjustWeatherPredictionGateway
        def initialize(prediction_service_factory:)
          @prediction_service_factory = prediction_service_factory
        end

        def prediction_service(weather_location:, farm:)
          @prediction_service_factory.call(weather_location: weather_location, farm: farm)
        end
      end
    end
  end
end
