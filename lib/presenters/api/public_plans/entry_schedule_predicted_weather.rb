# frozen_string_literal: true

module Presenters
  module Api
    module PublicPlans
      # エントリスケジュール API 向け: crops 一覧の controller からのみ利用（Domain::PublicPlan::Services へ委譲）
      module EntrySchedulePredictedWeather
        class << self
          def load_or_predict!(farm:, prediction_end_date_raw:, reference_date:)
            raise Domain::PublicPlan::Exceptions::WeatherLocationMissingError if farm.weather_location.blank?

            weather_prediction_service = yield(farm)

            Domain::PublicPlan::Services::EntrySchedulePredictionPayloadLoader.load_with_existing_service!(
              farm: farm,
              prediction_end_date_raw: prediction_end_date_raw,
              reference_date: reference_date,
              weather_prediction_service: weather_prediction_service
            )
          end

          # @param prediction_end_date_raw [String, nil]
          # @param reference_date [Date]
          # @return [Date]
          def parse_prediction_end_date(prediction_end_date_raw, reference_date:)
            Domain::PublicPlan::Services::EntrySchedulePredictionPayloadLoader.parse_prediction_end_date(
              prediction_end_date_raw,
              reference_date: reference_date
            )
          end
        end
      end
    end
  end
end
