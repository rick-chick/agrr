# frozen_string_literal: true

module Domain
  module PublicPlan
    module Services
      # 参照農場向け: 既存予測の再利用または WeatherPredictionInteractor による予測（キャッシュ初期化メモに準拠）
      class EntrySchedulePredictionPayloadLoader
        Interactor = Domain::WeatherData::Interactors::WeatherPredictionInteractor

        def self.load_with_existing_service!(farm:, prediction_end_date_raw:, reference_date:, weather_prediction_service:)
          target_end = Domain::PublicPlan::Mappers::EntrySchedulePredictionEndDateMapper.parse(
            prediction_end_date_raw,
            reference_date: reference_date
          )

          begin
            existing = weather_prediction_service.get_existing_prediction(target_end_date: target_end)
            weather_data =
              if existing
                existing[:data]
              else
                info = weather_prediction_service.predict_for_farm(target_end_date: target_end)
                info.is_a?(Hash) ? info[:data] : nil
              end

            weather_data = unwrap_nested_weather(weather_data)

            unless weather_data.is_a?(Hash) && weather_data["data"].is_a?(Array) && weather_data["data"].present?
              raise Domain::PublicPlan::Exceptions::PredictionPayloadMissingError
            end

            weather_data
          rescue Interactor::WeatherDataNotFoundError, Interactor::InsufficientPredictionDataError => e
            raise Domain::PublicPlan::Exceptions::WeatherPredictionFailedError, e.message
          end
        end

        def self.unwrap_nested_weather(weather_data)
          if weather_data.is_a?(Hash) && weather_data["data"].is_a?(Hash) && weather_data["data"]["data"].is_a?(Array)
            weather_data["data"]
          else
            weather_data
          end
        end
        private_class_method :unwrap_nested_weather
      end
    end
  end
end
