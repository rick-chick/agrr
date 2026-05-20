# frozen_string_literal: true

module Adapters
  module PublicPlans
    # 公開エントリスケジュール用: キャッシュ済み予測の再利用または WeatherPredictionInteractor 実行（Domain 境界向け）
    class EntryScheduleWeatherLoaderAdapter
      # @param prediction_service_factory [#call(farm)] farm は気象ロケーション検証済みで渡すこと
      def initialize(prediction_service_factory:)
        @prediction_service_factory = prediction_service_factory
      end

      def load_prediction_payload!(farm:, prediction_end_date_raw:, reference_date:)
        raise Domain::PublicPlan::Exceptions::WeatherLocationMissingError if farm.weather_location.blank?

        service = @prediction_service_factory.call(farm)
        Domain::PublicPlan::Services::EntrySchedulePredictionPayloadLoader.load_with_existing_service!(
          farm: farm,
          prediction_end_date_raw: prediction_end_date_raw,
          reference_date: reference_date,
          weather_prediction_service: service
        )
      end
    end
  end
end
