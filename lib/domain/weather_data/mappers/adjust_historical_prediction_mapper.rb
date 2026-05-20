# frozen_string_literal: true

module Domain
  module WeatherData
    module Mappers
      # adjust フローで、観測（historical）行を AGRR 形式にし、予測シリーズと接続する純粋ロジック。
      # 永続化・HTTP・ActiveRecord はエッジで行い、ここへはプレーンなハッシュのみ渡す。
      module AdjustHistoricalPredictionMapper
        # internal helper
        def row_value(row, key)
          row[key] || row[key.to_s]
        end
        module_function :row_value

        # internal helper
        def sunshine_duration_seconds(row)
          hours = row_value(row, :sunshine_hours)
          hours ? (hours.to_f * 3600.0) : 0.0
        end
        module_function :sunshine_duration_seconds

        # @param rows [Array<Hash>] date / temperature_max / temperature_min ほかオプション（precipitation 等）
        # @return [Hash] AGRR 互換トップレベル（latitude, longitude, elevation, timezone, data）
        def build_historical_agrr_series(latitude:, longitude:, elevation:, timezone:, rows:)
          data = Array(rows).filter_map do |row|
            tmax = row_value(row, :temperature_max)
            tmin = row_value(row, :temperature_min)
            next if tmax.nil? || tmin.nil?

            temp_mean = row_value(row, :temperature_mean)
            temp_mean = if temp_mean.nil?
                           (tmax.to_f + tmin.to_f) / 2.0
                         else
                           temp_mean.to_f
                         end

            day = row_value(row, :date)

            {
              "time" => day.to_s,
              "temperature_2m_max" => tmax.to_f,
              "temperature_2m_min" => tmin.to_f,
              "temperature_2m_mean" => temp_mean,
              "precipitation_sum" => (row_value(row, :precipitation) || 0.0).to_f,
              "sunshine_duration" => sunshine_duration_seconds(row),
              "wind_speed_10m_max" => (row_value(row, :wind_speed) || 0.0).to_f,
              "weather_code" => row_value(row, :weather_code) || 0
            }
          end

          {
            "latitude" => latitude.to_f,
            "longitude" => longitude.to_f,
            "elevation" => elevation.to_f,
            "timezone" => timezone,
            "data" => data
          }
        end
        module_function :build_historical_agrr_series

        # @param historical_series [Hash] {.build_historical_agrr_series} の戻り
        # @param prediction_data [Hash] "data" => Array の予測ブロック
        def merge_historical_series_with_prediction(historical_series, prediction_data)
          pred = prediction_data["data"] || prediction_data[:data] || []
          {
            "latitude" => historical_series["latitude"],
            "longitude" => historical_series["longitude"],
            "elevation" => historical_series["elevation"],
            "timezone" => historical_series["timezone"],
            "data" => Array(historical_series["data"]) + Array(pred)
          }
        end
        module_function :merge_historical_series_with_prediction
      end
    end
  end
end
