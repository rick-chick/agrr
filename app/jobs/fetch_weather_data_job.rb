# frozen_string_literal: true

require 'open3'
require 'json'

class FetchWeatherDataJob < ApplicationJob
  queue_as :weather_data_sequential
  
  MAX_RETRY_ATTEMPTS = 5

  # APIエラーやネットワークエラーに対してリトライする
  # 指数バックオフで最大5回までリトライ（待機時間: 3秒、9秒、27秒、81秒、243秒）
  retry_on StandardError, wait: ->(executions) { 3 * (3 ** executions) }, attempts: MAX_RETRY_ATTEMPTS do |job, exception|
    # 最終リトライでも失敗した場合の処理
    farm_id = job.arguments.first[:farm_id]
    year = job.arguments.first[:start_date].year
    
    Rails.logger.error "❌ [Farm##{farm_id}] Failed to fetch weather data for #{year} after #{job.executions} attempts"
    Rails.logger.error "   Final error: #{exception.message}"
    
    if farm_id
      farm = Farm.find_by(id: farm_id)
      farm&.mark_weather_data_failed!("リトライ上限に達しました: #{exception.message}")
    end
  end

  # データ検証エラーなど、リトライしても意味がないエラーは即座に破棄
  discard_on ActiveRecord::RecordInvalid do |job, exception|
    farm_id = job.arguments.first[:farm_id]
    year = job.arguments.first[:start_date].year
    
    Rails.logger.error "❌ [Farm##{farm_id}] Invalid data for #{year}: #{exception.message}"
    
    if farm_id
      farm = Farm.find_by(id: farm_id)
      farm&.mark_weather_data_failed!("データ検証エラー: #{exception.message}")
    end
  end

  # 指定された緯度経度と期間の気象データを取得してデータベースに保存
  def perform(latitude:, longitude:, start_date:, end_date:, farm_id: nil)
    farm_info = farm_id ? "[Farm##{farm_id}]" : ""
    year = start_date.year
    retry_info = executions > 1 ? " (リトライ #{executions - 1}/#{MAX_RETRY_ATTEMPTS})" : ""
    
    # 既にデータが存在するかチェック
    weather_location = WeatherLocation.find_by(latitude: latitude, longitude: longitude)
    if weather_location
      expected_days = (start_date..end_date).count
      existing_count = WeatherDatum.where(
        weather_location: weather_location,
        date: start_date..end_date
      ).count
      
      if existing_count == expected_days
        Rails.logger.info "⏭️  #{farm_info} Skipping #{year} - data already exists (#{existing_count}/#{expected_days} days)"
        
        # 進捗を更新
        if farm_id
          farm = Farm.find_by(id: farm_id)
          if farm
            farm.increment_weather_data_progress!
            progress = farm.weather_data_progress
            Rails.logger.info "📊 #{farm_info} Progress: #{progress}% (#{farm.weather_data_fetched_years}/#{farm.weather_data_total_years} years)"
          end
        end
        
        return
      end
    end
    
    Rails.logger.info "🌤️  #{farm_info} Fetching weather data for #{year}#{retry_info} (#{latitude}, #{longitude})"
    
    # agrrコマンドを実行して気象データを取得
    weather_data = fetch_weather_from_agrr(latitude, longitude, start_date, end_date)
    
    unless weather_data['success']
      error_message = weather_data['error'] || 'Unknown error from weather API'
      raise StandardError, "Weather API returned unsuccessful response: #{error_message}"
    end

    # WeatherLocationを作成または取得
    location_data = weather_data['data']['location']
    weather_location = WeatherLocation.find_or_create_by_coordinates(
      latitude: location_data['latitude'],
      longitude: location_data['longitude'],
      elevation: location_data['elevation'],
      timezone: location_data['timezone']
    )

    # 気象データを保存
    data_count = 0
    weather_data['data']['data'].each do |daily_data|
      date = Date.parse(daily_data['time'])
      
      record = WeatherDatum.find_or_initialize_by(
        weather_location: weather_location,
        date: date
      )
      
      record.temperature_max = daily_data['temperature_2m_max']
      record.temperature_min = daily_data['temperature_2m_min']
      record.temperature_mean = daily_data['temperature_2m_mean']
      record.precipitation = daily_data['precipitation_sum']
      record.sunshine_hours = daily_data['sunshine_hours']
      record.wind_speed = daily_data['wind_speed_10m']
      record.weather_code = daily_data['weather_code']
      record.save!
      data_count += 1
    end

    # Farmのステータスを更新
    if farm_id
      farm = Farm.find_by(id: farm_id)
      if farm
        farm.increment_weather_data_progress!
        progress = farm.weather_data_progress
        Rails.logger.info "📊 #{farm_info} Progress: #{progress}% (#{farm.weather_data_fetched_years}/#{farm.weather_data_total_years} years)"
      end
    end

    Rails.logger.info "✅ #{farm_info} Saved #{data_count} weather records for #{year}"
  rescue => e
    # エラーログを出力（リトライの場合は警告レベル、それ以外はエラーレベル）
    log_level = executions < MAX_RETRY_ATTEMPTS ? :warn : :error
    Rails.logger.public_send(log_level, "⚠️  #{farm_info} Failed to fetch weather data for #{year}: #{e.message}")
    Rails.logger.public_send(log_level, "   Backtrace: #{e.backtrace.first(3).join("\n   ")}")
    
    # 例外を再raiseして、retry_onに処理を委ねる
    # retry_onが最終的にリトライ上限に達した場合のみmark_weather_data_failed!が呼ばれる
    raise
  end

  private

  def fetch_weather_from_agrr(latitude, longitude, start_date, end_date)
    agrr_path = Rails.root.join('lib', 'core', 'agrr').to_s
    command = [
      agrr_path,
      'weather',
      '--location', "#{latitude},#{longitude}",
      '--start-date', start_date.to_s,
      '--end-date', end_date.to_s,
      '--json'
    ]

    stdout, stderr, status = Open3.capture3(*command)

    unless status.success?
      raise "Failed to fetch weather data from agrr: #{stderr}"
    end

    JSON.parse(stdout)
  end

end

