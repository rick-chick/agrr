# frozen_string_literal: true

module Adapters
  module WeatherData
    module Gateways
      class AgrrPredictionGatewayAdapter < Domain::WeatherData::Gateways::PredictionGateway
        def initialize
          @implementation = ::Agrr::PredictionGateway.new
        end

        def predict(historical_data:, days:, model: "lightgbm")
          @implementation.predict(historical_data: historical_data, days: days, model: model)
        end
      end
    end
  end
end
