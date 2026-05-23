# frozen_string_literal: true

module Adapters
  module CultivationPlan
    module Gateways
      class AdjustWeatherPredictionActiveRecordGateway < Domain::CultivationPlan::Gateways::AdjustWeatherPredictionGateway
        def initialize(weather_prediction_interactor_factory:)
          @weather_prediction_interactor_factory = weather_prediction_interactor_factory
        end

        def prediction_service(weather_location:, farm:)
          @weather_prediction_interactor_factory.build(weather_location: weather_location, farm: farm)
        end
      end
    end
  end
end
