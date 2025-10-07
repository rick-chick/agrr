# frozen_string_literal: true

require 'open3'
require 'json'

class FetchWeatherDataJob < ApplicationJob
  queue_as :default

  # 指定された緯度経度と期間の気象データを取得してデータベースに保存
  def perform(latitude:, longitude:, start_date:, end_date:)
    # agrrコマンドを実行して気象データを取得
    weather_data = fetch_weather_from_agrr(latitude, longitude, start_date, end_date)
    
    return unless weather_data['success']

    # WeatherLocationを作成または取得
    location_data = weather_data['data']['location']
    weather_location = WeatherLocation.find_or_create_by_coordinates(
      latitude: location_data['latitude'],
      longitude: location_data['longitude'],
      elevation: location_data['elevation'],
      timezone: location_data['timezone']
    )

    # 気象データを保存
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
    end

    Rails.logger.info "Fetched weather data for #{weather_location.coordinates_string} from #{start_date} to #{end_date}"
  rescue => e
    Rails.logger.error "Failed to fetch weather data: #{e.message}"
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

