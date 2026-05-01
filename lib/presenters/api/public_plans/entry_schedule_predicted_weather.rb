# frozen_string_literal: true

module Presenters
  module Api
    module PublicPlans
      # エントリスケジュール API 向け: キャッシュ済み予測テキストの再利用または WeatherPredictionInteractor による予測実行。
      # EntryScheduleController と EntryScheduleShowPayload でロジックを共有する（DRY）。
      module EntrySchedulePredictedWeather
        class << self
          # 気象ロケーション確認後にのみブロックで WeatherPredictionInteractor を生成すること（+weather_location+ が
          # nil のときに CompositionRoot が先に評価されないよう遅延する）。
          #
          # @param farm [Farm]
          # @param prediction_end_date_raw [String, nil]
          # @param reference_date [Date]
          # @yield [farm] 気象確認済みの +farm+ で #get_existing_prediction / #predict_for_farm を持つサービスを返す
          # @return [Hash] predicted_weather_data 形式（トップレベルに data 配列）
          def load_or_predict!(farm:, prediction_end_date_raw:, reference_date:)
            raise EntryScheduleShowPayload::WeatherLocationMissingError if farm.weather_location.blank?

            weather_prediction_service = yield(farm)

            target_end = parse_prediction_end_date(prediction_end_date_raw, reference_date: reference_date)

            cached = weather_prediction_service.get_existing_prediction(target_end_date: target_end)
            payload_hash = if cached && cached[:data].is_a?(Hash)
                             cached[:data]
                           else
                             weather_prediction_service.predict_for_farm(target_end_date: target_end)
                             farm.reload
                             farm.predicted_weather_data
                           end

            raise EntryScheduleShowPayload::PredictionPayloadMissingError if payload_hash.blank? || payload_hash["data"].blank?

            payload_hash
          rescue Domain::WeatherData::Interactors::WeatherPredictionInteractor::WeatherDataNotFoundError,
                 Domain::WeatherData::Interactors::WeatherPredictionInteractor::InsufficientPredictionDataError => e
            raise EntryScheduleShowPayload::WeatherPredictionFailedError, e.message
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
end
