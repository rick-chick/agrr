# frozen_string_literal: true

module Domain
  module WeatherData
    module Gateways
      class PredictionGateway
        def predict(historical_data:, days:, model: "lightgbm")
          raise NotImplementedError, "Subclasses must implement predict"
        end
      end
    end
  end
end
