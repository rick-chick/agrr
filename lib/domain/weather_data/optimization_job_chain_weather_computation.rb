# frozen_string_literal: true

module Domain
  module WeatherData
    # ジョブチェーン組み立て用の天気取得期間・予測日数（Policy 呼び出しはドメイン側に集約）。
    module OptimizationJobChainWeatherComputation
      class << self
        def weather_window(latest_weather_date:, clock:)
          Domain::WeatherData::Policies::WeatherDataFetchWindowPolicy.fetch_range(
            latest_weather_date: latest_weather_date,
            clock: clock
          )
        end

        def predict_days_to_next_year_end(end_date:, clock:)
          Domain::WeatherData::Policies::WeatherPredictionHorizonPolicy.predict_days_to_next_year_end(
            end_date: end_date,
            clock: clock
          )
        end
      end
    end
  end
end
