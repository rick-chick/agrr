# frozen_string_literal: true

module Domain
  module PublicPlan
    module Services
      # EntrySchedulePredictedWeather / WeatherLoaderAdapter から共有される純処理（Presenter に依存しない）
      module EntrySchedulePredictionPayloadLoader
        module_function

        # @param farm [Farm] 気象ロケーション済みであること（呼び出し側が検証）
        # @param weather_prediction_service [#get_existing_prediction, #predict_for_farm]
        def load_with_existing_service!(farm:, prediction_end_date_raw:, reference_date:, weather_prediction_service:)
          target_end = parse_prediction_end_date(prediction_end_date_raw, reference_date: reference_date)

          cached = weather_prediction_service.get_existing_prediction(target_end_date: target_end)
          payload_hash = if cached && cached[:data].is_a?(Hash)
                           cached[:data]
                         else
                           weather_prediction_service.predict_for_farm(target_end_date: target_end)
                           farm.reload
                           farm.predicted_weather_data
                         end

          raise Domain::PublicPlan::Exceptions::PredictionPayloadMissingError if payload_hash.blank? || payload_hash["data"].blank?

          payload_hash
        rescue Domain::WeatherData::Interactors::WeatherPredictionInteractor::WeatherDataNotFoundError,
               Domain::WeatherData::Interactors::WeatherPredictionInteractor::InsufficientPredictionDataError => e
          raise Domain::PublicPlan::Exceptions::WeatherPredictionFailedError, e.message
        end

        # @param prediction_end_date_raw [String, nil]
        # @param reference_date [Date]
        # @return [Date]
        def parse_prediction_end_date(prediction_end_date_raw, reference_date:)
          return reference_date.end_of_year if prediction_end_date_raw.blank?

          Date.parse(prediction_end_date_raw.to_s)
        rescue ArgumentError
          reference_date.end_of_year
        end
      end
    end
  end
end
