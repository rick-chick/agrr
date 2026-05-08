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

        def format_for_agrr(weather_data_dtos:, weather_location:)
          wl = weather_location
          Domain::WeatherData::Services::OpenMeteoWeatherPayload.format_for_agrr(
            weather_data_dtos: weather_data_dtos,
            latitude: wl.latitude,
            longitude: wl.longitude,
            elevation: wl.elevation,
            timezone: wl.timezone
          )
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
          loc = ::WeatherLocation.find_by(latitude: latitude, longitude: longitude)
          Adapters::WeatherData::Mappers::WeatherLocationMapper.weather_location_dto_from_record(loc)
        end

        def find_or_create_weather_location(latitude:, longitude:, elevation: nil, timezone: nil)
          loc = ::WeatherLocation.find_or_create_by(
            latitude: latitude,
            longitude: longitude
          ) do |location|
            location.elevation = elevation
            location.timezone = timezone
          end
          Adapters::WeatherData::Mappers::WeatherLocationMapper.weather_location_dto_from_record(loc)
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
