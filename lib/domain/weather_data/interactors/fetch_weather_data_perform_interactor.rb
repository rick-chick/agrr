# frozen_string_literal: true

module Domain
  module WeatherData
    module Interactors
      class FetchWeatherDataPerformInteractor
        include InputPorts::FetchWeatherDataPerformInputPort

        MAX_RETRY_ATTEMPTS = 5
        ALLOWED_MISSING_RATIO = 0.05
        SUFFICIENT_DATA_RATIO = 0.8

        def initialize(
          weather_data_gateway:,
          farm_gateway:,
          cultivation_plan_gateway:,
          agrr_weather_gateway:,
          presenter:
        )
          @weather_data_gateway = weather_data_gateway
          @farm_gateway = farm_gateway
          @cultivation_plan_gateway = cultivation_plan_gateway
          @agrr_weather_gateway = agrr_weather_gateway
          @presenter = presenter
        end

        def execute(input_dto:)
          latitude = input_dto[:latitude]
          longitude = input_dto[:longitude]
          start_date = input_dto[:start_date]
          end_date = input_dto[:end_date]
          farm_id = input_dto[:farm_id]
          cultivation_plan_id = input_dto[:cultivation_plan_id]
          channel_class = input_dto[:channel_class]
          executions = input_dto.fetch(:executions, 1)
          current_time = input_dto[:current_time]
          farm_info = farm_id ? "[Farm##{farm_id}]" : ""

          @presenter.info "🔍 [FetchWeatherDataJob] Received args: latitude=#{latitude}, longitude=#{longitude}, start_date=#{start_date}, end_date=#{end_date}, farm_id=#{farm_id}, cultivation_plan_id=#{cultivation_plan_id}, channel_class=#{channel_class}"

          # 日付検証
          if start_date.nil? || end_date.nil?
            error_msg = "Invalid date parameters: start_date=#{start_date.inspect}, end_date=#{end_date.inspect}"
            @presenter.error "❌ #{farm_info} #{error_msg}"
            raise ArgumentError, error_msg
          end

          period_str = start_date.year == end_date.year ? "#{start_date.year}" : "#{start_date.year}-#{end_date.year}"

          # フェーズ更新 (開始)
          if cultivation_plan_id && channel_class
            @cultivation_plan_gateway.update_phase(cultivation_plan_id, 'phase_fetching_weather', channel_class)
            @presenter.info "🌤️ [FetchWeatherDataJob] Started fetching weather data for plan ##{cultivation_plan_id}"
          end

          # 既存データチェック
          weather_location = @weather_data_gateway.find_weather_location_by_coordinates(latitude: latitude, longitude: longitude)
          if weather_location
            expected_days = (start_date..end_date).count
            existing_count = @weather_data_gateway.weather_data_count(
              weather_location_id: weather_location.id,
              start_date: start_date,
              end_date: end_date
            )
            threshold_days = (expected_days * SUFFICIENT_DATA_RATIO).ceil

            if existing_count >= threshold_days
              @presenter.info "⏭️  #{farm_info} Skipping #{period_str} - sufficient data exists (#{existing_count}/#{expected_days} days, #{((existing_count.to_f / expected_days) * 100).round(1)}%)"

              if farm_id
                @farm_gateway.increment_weather_data_progress(farm_id)
                progress = @farm_gateway.get_weather_data_progress(farm_id)
                fetched_years = @farm_gateway.get_weather_data_fetched_years(farm_id)
                total_years = @farm_gateway.get_weather_data_total_years(farm_id)
                @presenter.info "📊 #{farm_info} Progress: #{progress}% (#{fetched_years}/#{total_years} blocks)"
              end

              return
            end
          end

          @presenter.info "🌤️  #{farm_info} Fetching weather data for #{period_str} (#{latitude}, #{longitude})"

          # API負荷軽減のため短い待機時間を入れる
          sleep(0.5)

          # APIデータ取得
          weather_data = fetch_weather_from_agrr(latitude, longitude, start_date, end_date, farm_id)

          unless weather_data.is_a?(Hash)
            raise StandardError, 'Weather data response is invalid or missing'
          end

          data_points = weather_data['data']
          unless data_points.is_a?(Array)
            raise StandardError, 'Weather data response is invalid or missing'
          end

          expected_days = (start_date..end_date).count
          actual_days = data_points.size
          missing_days = [expected_days - actual_days, 0].max
          allowed_missing_days = (expected_days * ALLOWED_MISSING_RATIO).ceil

          if data_points.empty?
            raise StandardError, "Weather data missing for #{period_str} (0/#{expected_days} days)"
          elsif missing_days > allowed_missing_days
            raise StandardError, "Weather data missing #{missing_days} days exceeds allowed #{allowed_missing_days} days (#{(ALLOWED_MISSING_RATIO * 100).round(1)}%)"
          elsif missing_days.positive?
            @presenter.warn "⚠️  #{farm_info} Weather data incomplete for #{period_str}: #{actual_days}/#{expected_days} days (missing #{missing_days}, allowed #{allowed_missing_days})"
          end

          # WeatherLocation作成/取得
          location_data = weather_data['location']
          unless location_data.is_a?(Hash)
            raise StandardError, 'Weather data is missing location information'
          end
          weather_location = @weather_data_gateway.find_or_create_weather_location(
            latitude: location_data['latitude'],
            longitude: location_data['longitude'],
            elevation: location_data['elevation'],
            timezone: location_data['timezone']
          )

          # Farmリンク
          if farm_id
            @farm_gateway.update_weather_location_id(farm_id, weather_location.id)
            @presenter.info "🔗 [Farm##{farm_id}] Linked to WeatherLocation##{weather_location.id}"
          end

          # DTO作成 & upsert
          all_records = []
          data_points.each_with_index do |daily_data, index|
            date = Date.parse(daily_data['time'])
            record_attrs = {
              weather_location_id: weather_location.id,
              date: date,
              temperature_max: daily_data['temperature_2m_max'],
              temperature_min: daily_data['temperature_2m_min'],
              temperature_mean: daily_data['temperature_2m_mean'],
              precipitation: daily_data['precipitation_sum'],
              sunshine_hours: daily_data['sunshine_hours'],
              wind_speed: daily_data['wind_speed_10m'],
              weather_code: daily_data['weather_code'],
              updated_at: current_time
            }
            all_records << record_attrs

            if index == 0 || index == data_points.length - 1
              @presenter.debug "💾 [Weather Data ##{index + 1}] date=#{date}, temp=#{record_attrs[:temperature_min]}~#{record_attrs[:temperature_max]}°C"
            end
          end

          if all_records.any?
            dtos = all_records.map { |attrs| Domain::WeatherData::Dtos::WeatherDataDto.from_attrs(attrs) }
            @weather_data_gateway.upsert_weather_data!(
              weather_data_dtos: dtos,
              weather_location_id: weather_location.id
            )
          end

          data_count = all_records.size
          @presenter.info "💾 [Weather Data Summary] Total: #{data_count} records upserted in single batch"

          # Farm進捗更新
          if farm_id
            @farm_gateway.increment_weather_data_progress(farm_id)
            progress = @farm_gateway.get_weather_data_progress(farm_id)
            fetched_years = @farm_gateway.get_weather_data_fetched_years(farm_id)
            total_years = @farm_gateway.get_weather_data_total_years(farm_id)
            @presenter.info "📊 #{farm_info} Progress: #{progress}% (#{fetched_years}/#{total_years} blocks)"
          end

          @presenter.info "✅ #{farm_info} Saved #{data_count} weather records for #{period_str}"

          # フェーズ更新 (完了)
          if cultivation_plan_id && channel_class
            @cultivation_plan_gateway.update_phase(cultivation_plan_id, 'phase_weather_data_fetched', channel_class)
            @presenter.info "🌤️ [FetchWeatherDataJob] Weather data fetching completed for plan ##{cultivation_plan_id}"
          end
        end

        private

        def fetch_weather_from_agrr(latitude, longitude, start_date, end_date, farm_id)
          data_source = determine_data_source(farm_id, latitude: latitude, longitude: longitude)
          farm_info = farm_id ? "[Farm##{farm_id}]" : ""
          @presenter.info "🌍 #{farm_info} Using data source: #{data_source}"

          @agrr_weather_gateway.fetch_by_date_range(
            latitude: latitude,
            longitude: longitude,
            start_date: start_date,
            end_date: end_date,
            data_source: data_source
          )
        end

        def determine_data_source(farm_id, latitude:, longitude:)
          farm_entity = farm_id && @farm_gateway.find_by_id(farm_id) rescue nil

          if farm_entity
            return 'jma' if farm_entity.region == 'jp'
            lat = latitude
            lon = longitude
            return 'jma' if japan_location?(lat, lon)
            return 'nasa-power' if farm_entity.region.nil?
            return 'noaa'
          end

          lat = latitude
          lon = longitude
          return 'jma' if japan_location?(lat, lon)
          'noaa'
        end

        def japan_location?(latitude, longitude)
          return false if latitude.nil? || longitude.nil?
          latitude.between?(24.0, 46.0) && longitude.between?(130.0, 146.0)
        end

      end
    end
  end
end
