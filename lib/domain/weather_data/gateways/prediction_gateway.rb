# frozen_string_literal: true

module Domain
  module WeatherData
    module Gateways
      class PredictionGateway
        class << self
          def default
            @default ||= Adapters::WeatherData::Gateways::AgrrPredictionGatewayAdapter.new
          end

          attr_writer :default

          def default_reset!
            @default = nil
          end
        end

        def predict(historical_data:, days:, model: "lightgbm")
          raise NotImplementedError, "Subclasses must implement predict"
        end
      end
    end
  end
end
