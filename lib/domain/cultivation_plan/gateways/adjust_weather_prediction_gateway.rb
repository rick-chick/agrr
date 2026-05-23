# frozen_string_literal: true

module Domain
  module CultivationPlan
    module Gateways
      # plan_allocation_adjust 用: WeatherPredictionInteractor 相当の予測サービスを生成する。
      class AdjustWeatherPredictionGateway
        # @return [Object] #get_existing_prediction, #predict_for_cultivation_plan を実装
        def prediction_service(weather_location:, farm:)
          raise NotImplementedError, "Subclasses must implement prediction_service"
        end
      end
    end
  end
end
