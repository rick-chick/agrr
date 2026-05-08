# frozen_string_literal: true

module Domain
  module WeatherData
    module Services
      # 気象ペイロードの正規化と WeatherDataDto から agrr 入力用 Hash を組み立てる（Rails に依存しない）
      module OpenMeteoWeatherPayload
        module_function

        def blankish?(data)
          return true if data.nil?
          return true if data.is_a?(String) && data.strip.empty?
          data.respond_to?(:empty?) && data.empty?
        end

        def legacy_nested_open_meteo_payload?(data)
          data.is_a?(Hash) && data["data"].is_a?(Hash) && data["data"]["data"].is_a?(Array)
        end

        # 旧ネスト形式なら内側の Hash を返す。空入力は nil。
        def normalize_raw_payload(data)
          return nil if blankish?(data)
          return data["data"] if legacy_nested_open_meteo_payload?(data)

          data
        end

        def format_for_agrr(weather_data_dtos:, latitude:, longitude:, elevation:, timezone:)
          {
            "latitude" => latitude.to_f,
            "longitude" => longitude.to_f,
            "elevation" => (elevation || 0.0).to_f,
            "timezone" => timezone,
            "data" => weather_data_dtos.map do |dto|
              {
                "time" => dto.date.to_s,
                "temperature_2m_max" => dto.temperature_max,
                "temperature_2m_min" => dto.temperature_min,
                "temperature_2m_mean" => dto.temperature_mean,
                "precipitation_sum" => dto.precipitation,
                "sunshine_duration" => dto.sunshine_hours ? dto.sunshine_hours.to_f * 3600.0 : 0.0,
                "wind_speed_10m_max" => dto.wind_speed,
                "weather_code" => dto.weather_code
              }
            end.compact
          }
        end
      end
    end
  end
end
