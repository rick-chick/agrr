# frozen_string_literal: true

module Agrr
  class WeatherGateway < BaseGatewayV2
    def fetch(latitude:, longitude:, days:)
      Rails.logger.info "🌤️  [AGRR] Fetching weather: lat=#{latitude}, lon=#{longitude}, days=#{days}"

      result = execute_command(
        "dummy_path", # Not used in V2
        "weather",
        "--location", "#{latitude},#{longitude}",
        "--days", days.to_s,
        "--data-source", "noaa",
        "--json"
      )

      Rails.logger.info "✅ [AGRR] Weather data fetched: #{result['data']&.count || 0} records"
      result
    end

    def fetch_by_date_range(latitude:, longitude:, start_date:, end_date:, data_source: "noaa")
      Rails.logger.info "🌤️  [AGRR] Fetching weather: lat=#{latitude}, lon=#{longitude}, start=#{start_date}, end=#{end_date}"

      # 環境変数で上書き可能
      effective_data_source = ENV.fetch("WEATHER_DATA_SOURCE", data_source)

      result = execute_command(
        "dummy_path", # Not used in V2
        "weather",
        "--location", "#{latitude},#{longitude}",
        "--start-date", start_date.to_s,
        "--end-date", end_date.to_s,
        "--data-source", effective_data_source,
        "--json"
      )

      Rails.logger.info "✅ [AGRR] Weather data fetched: #{result['data']&.count || 0} records"
      result
    end
  end
end
