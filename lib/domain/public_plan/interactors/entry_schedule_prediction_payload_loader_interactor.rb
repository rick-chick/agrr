# frozen_string_literal: true

module Domain
  module PublicPlan
    module Interactors
      # 参照農場向け: 既存予測の再利用または WeatherPredictionInteractor による予測（キャッシュ初期化メモに準拠）
      class EntrySchedulePredictionPayloadLoaderInteractor
        def initialize(weather_prediction_interactor_factory:, date_mapper: Domain::PublicPlan::Mappers::EntrySchedulePredictionEndDateMapper)
          @weather_prediction_interactor_factory = weather_prediction_interactor_factory
          @date_mapper = date_mapper
        end

        # @param farm [Farm] 参照農場（気象ロケーション検証済み）
        # @param prediction_end_date_raw [String, nil] 予測終了日の生文字列
        # @param reference_date [Date] 参照日
        # @return [Hash] AGRR フォーマットの気象予測ペイロード
        def call(farm:, prediction_end_date_raw:, reference_date:)
          target_end = @date_mapper.parse(prediction_end_date_raw, reference_date: reference_date)

          interactor = @weather_prediction_interactor_factory.call(farm)

          begin
            existing = interactor.get_existing_prediction(target_end_date: target_end)
            weather_data =
              if existing
                existing[:data]
              else
                info = interactor.predict_for_farm(target_end_date: target_end)
                info.is_a?(Hash) ? info[:data] : nil
              end

            weather_data = unwrap_nested_weather(weather_data)

            unless weather_data.is_a?(Hash) && weather_data["data"].is_a?(Array) && weather_data["data"].present?
              raise Domain::PublicPlan::Exceptions::PredictionPayloadMissingError
            end

            weather_data
          rescue Domain::WeatherData::Interactors::WeatherPredictionInteractor::WeatherDataNotFoundError,
                 Domain::WeatherData::Interactors::WeatherPredictionInteractor::InsufficientPredictionDataError => e
            raise Domain::PublicPlan::Exceptions::WeatherPredictionFailedError, e.message
          end
        end

        private

        def unwrap_nested_weather(weather_data)
          if weather_data.is_a?(Hash) && weather_data["data"].is_a?(Hash) && weather_data["data"]["data"].is_a?(Array)
            weather_data["data"]
          else
            weather_data
          end
        end
      end
    end
  end
end
