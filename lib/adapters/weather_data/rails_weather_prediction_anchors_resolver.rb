# frozen_string_literal: true

module Adapters
  module WeatherData
    # +Zone+ 上で ActiveSupport の期間計算を行い、旧 Date.current ± years/days と整合させる。
    class RailsWeatherPredictionAnchorsResolver
      include Domain::WeatherData::Ports::WeatherPredictionAnchorsPort

      def initialize(zone:)
        raise ArgumentError, "zone is required" if zone.nil?

        @zone = zone
      end

      # @param reference_calendar_day [Date]
      # @return [Domain::WeatherData::Dtos::WeatherPredictionAnchorsDto]
      def anchors_for(reference_calendar_day)
        d = reference_calendar_day
        midnight = @zone.local(d.year, d.month, d.day)

        Domain::WeatherData::Dtos::WeatherPredictionAnchorsDto.new(
          training_start_date: (midnight - 20.years).to_date,
          training_end_date: (midnight - 2.days).to_date,
          current_year_history_start_date: Date.new(d.year, 1, 1),
          current_year_history_end_date: (midnight - 2.days).to_date,
          default_target_end_date: (midnight + 6.months).to_date
        )
      end
    end
  end
end
