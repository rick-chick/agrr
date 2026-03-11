# frozen_string_literal: true

require "google/cloud/storage"

module Adapters
  module WeatherData
    module Gateways
      class GcsWeatherDataGateway
        include Domain::WeatherData::Gateways::WeatherDataGateway

        PREFIX = "weather_data"
        BUCKET_ENV = "GCS_WEATHER_DATA_BUCKET"

        def initialize(bucket_name: nil, bucket: nil)
          @injected_bucket = bucket
          @bucket_name = bucket_name || ENV[BUCKET_ENV] || ENV["GCS_BUCKET"] unless @injected_bucket
          raise("GCS_WEATHER_DATA_BUCKET or GCS_BUCKET must be set for GCS weather data storage") if !@injected_bucket && !@bucket_name
        end

        def weather_data_for_period(weather_location_id:, start_date: nil, end_date: nil)
          dtos = []
          return dtos unless start_date || end_date

          years = years_for_range(start_date, end_date)
          years.each do |year|
            data = read_year_file(weather_location_id, year)
            data.each do |date_str, attrs|
              date = Date.parse(date_str) rescue nil
              next unless date
              next if start_date && date < start_date
              next if end_date && date > end_date
              dtos << hash_to_dto(date, attrs)
            end
          end
          dtos.sort_by(&:date)
        end

        def normalize_weather_data(raw_data:)
          AgrrService.normalize_weather_data(raw_data)
        end

        def extract_weather_data_by_period(raw_weather_payload:, start_date:, end_date:)
          return [] unless raw_weather_payload["data"]

          raw_weather_payload["data"].filter_map do |datum|
            next unless datum["time"]
            datum_date = (Date.parse(datum["time"]) rescue nil)
            next unless datum_date&.between?(start_date, end_date)

            temp_mean = datum["temperature_2m_mean"]
            temp_mean ||= (datum["temperature_2m_max"] + datum["temperature_2m_min"]) / 2.0 if datum["temperature_2m_max"] && datum["temperature_2m_min"]

            Domain::WeatherData::Dtos::WeatherDataDto.new(
              date: datum_date,
              temperature_max: datum["temperature_2m_max"],
              temperature_min: datum["temperature_2m_min"],
              temperature_mean: temp_mean,
              precipitation: datum["precipitation_sum"],
              sunshine_hours: datum["sunshine_duration"] ? datum["sunshine_duration"].to_f / 3600.0 : nil,
              wind_speed: datum["wind_speed_10m_max"],
              weather_code: datum["weather_code"]
            )
          end
        end

        def format_for_agrr(weather_data_dtos:, weather_location:)
          {
            "latitude" => weather_location.latitude.to_f,
            "longitude" => weather_location.longitude.to_f,
            "elevation" => (weather_location.elevation || 0.0).to_f,
            "timezone" => weather_location.timezone,
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

        def weather_data_count(weather_location_id:, start_date: nil, end_date: nil)
          weather_data_for_period(
            weather_location_id: weather_location_id,
            start_date: start_date,
            end_date: end_date
          ).size
        end

        def historical_data_count(weather_location_id:, start_date:, end_date:)
          weather_data_for_period(
            weather_location_id: weather_location_id,
            start_date: start_date,
            end_date: end_date
          ).count { |d| d.temperature_max.present? && d.temperature_min.present? }
        end

        def upsert_weather_data!(weather_data_dtos:, weather_location_id:)
          return if weather_data_dtos.empty?

          by_year = weather_data_dtos.group_by { |d| d.date.year }
          by_year.each do |year, dtos|
            existing = read_year_file(weather_location_id, year)
            dtos.each do |dto|
              existing[dto.date.to_s] = dto_to_hash(dto)
            end
            write_year_file(weather_location_id, year, existing)
          end
        end

        def total_weather_data_count
          count = 0
          ::WeatherLocation.find_each do |loc|
            list_year_files(loc.id).each do |blob|
              content = blob.download
              raw = content.respond_to?(:read) ? content.read : content.to_s
              data = parse_json(raw)
              count += data.size if data.is_a?(Hash)
            end
          end
          count
        end

        def earliest_date(weather_location_id:)
          min_date = nil
          list_year_files(weather_location_id).each do |blob|
            content = blob.download
            raw = content.respond_to?(:read) ? content.read : content.to_s
            data = parse_json(raw)
            next unless data.is_a?(Hash)
            data.each_key do |date_str|
              date = (Date.parse(date_str) rescue nil)
              min_date = date if date && (min_date.nil? || date < min_date)
            end
          end
          min_date
        end

        def latest_date(weather_location_id:)
          max_date = nil
          list_year_files(weather_location_id).each do |blob|
            content = blob.download
            raw = content.respond_to?(:read) ? content.read : content.to_s
            data = parse_json(raw)
            next unless data.is_a?(Hash)
            data.each_key do |date_str|
              date = (Date.parse(date_str) rescue nil)
              max_date = date if date && (max_date.nil? || date > max_date)
            end
          end
          max_date
        end

        def find_weather_location_by_coordinates(latitude:, longitude:)
          ::WeatherLocation.find_by(latitude: latitude, longitude: longitude)
        end

        def find_or_create_weather_location(latitude:, longitude:, elevation: nil, timezone: nil)
          ::WeatherLocation.find_or_create_by(
            latitude: latitude,
            longitude: longitude
          ) do |location|
            location.elevation = elevation
            location.timezone = timezone
          end
        end

        private

        def storage
          @storage ||= Google::Cloud::Storage.new
        end

        def bucket
          @bucket ||= @injected_bucket || storage.bucket(@bucket_name)
        end

        def object_path(weather_location_id, year)
          "#{PREFIX}/#{weather_location_id}/#{year}.json"
        end

        def read_year_file(weather_location_id, year)
          blob = bucket.file(object_path(weather_location_id, year))
          return {} unless blob
          content = blob.download
          raw = content.respond_to?(:read) ? content.read : content.to_s
          parse_json(raw) || {}
        rescue Google::Cloud::NotFoundError
          {}
        end

        def write_year_file(weather_location_id, year, data)
          json_str = JSON.generate(data)
          bucket.create_file(
            StringIO.new(json_str),
            object_path(weather_location_id, year),
            content_type: "application/json"
          )
        end

        def list_year_files(weather_location_id)
          prefix = "#{PREFIX}/#{weather_location_id}/"
          bucket.files(prefix: prefix)
        end

        def years_for_range(start_date, end_date)
          return [] unless start_date || end_date
          s = start_date ? start_date.year : (end_date ? end_date.year : Date.current.year)
          e = end_date ? end_date.year : (start_date ? start_date.year : Date.current.year)
          (s..e).to_a
        end

        def hash_to_dto(date, attrs)
          Domain::WeatherData::Dtos::WeatherDataDto.new(
            date: date,
            temperature_max: attrs["temperature_max"],
            temperature_min: attrs["temperature_min"],
            temperature_mean: attrs["temperature_mean"],
            precipitation: attrs["precipitation"],
            sunshine_hours: attrs["sunshine_hours"],
            wind_speed: attrs["wind_speed"],
            weather_code: attrs["weather_code"]
          )
        end

        def dto_to_hash(dto)
          {
            "temperature_max" => dto.temperature_max,
            "temperature_min" => dto.temperature_min,
            "temperature_mean" => dto.temperature_mean,
            "precipitation" => dto.precipitation,
            "sunshine_hours" => dto.sunshine_hours,
            "wind_speed" => dto.wind_speed,
            "weather_code" => dto.weather_code
          }
        end

        def parse_json(str)
          JSON.parse(str) if str.present?
        rescue JSON::ParserError
          {}
        end
      end
    end
  end
end
