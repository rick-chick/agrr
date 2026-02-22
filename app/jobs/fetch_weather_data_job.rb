# frozen_string_literal: true

require_relative 'concerns/job_arguments_provider'

class FetchWeatherDataJob < ApplicationJob
  include JobArgumentsProvider
  
  queue_as :weather_data_sequential
  
  MAX_RETRY_ATTEMPTS = 5
  ALLOWED_MISSING_RATIO = 0.05
  
  # インスタンス変数の定義
  attr_accessor :latitude, :longitude, :start_date, :end_date, :farm_id, :cultivation_plan_id, :channel_class
  
  # インスタンス変数をハッシュとして返す
  def job_arguments
    {
      latitude: latitude,
      longitude: longitude,
      start_date: start_date,
      end_date: end_date,
      farm_id: farm_id,
      cultivation_plan_id: cultivation_plan_id,
      channel_class: channel_class
    }
  end

  # APIエラーやネットワークエラーに対してリトライする
  # 指数バックオフ + ジッター（ランダム性）で最大5回までリトライ
  # 基本待機時間: 3秒、9秒、27秒、81秒、243秒 + ランダム(0-50%)
  retry_on StandardError, wait: ->(executions) { 
    base_delay = 3 * (3 ** executions)
    jitter = rand(0.0..0.5) * base_delay
    (base_delay + jitter).to_i
  }, attempts: MAX_RETRY_ATTEMPTS do |job, exception|
    # 最終リトライでも失敗した場合の処理
    farm_id = job.arguments.first[:farm_id]
    start_date = job.arguments.first[:start_date]
    end_date = job.arguments.first[:end_date]
    period_str = start_date.year == end_date.year ? "#{start_date.year}" : "#{start_date.year}-#{end_date.year}"
    
    Rails.logger.error "❌ [Farm##{farm_id}] Failed to fetch weather data for #{period_str} after #{job.executions} attempts"
    Rails.logger.error "   Final error: #{exception.message}"
    
    if farm_id
      farm = Farm.find_by(id: farm_id)
      error_msg = I18n.t('jobs.fetch_weather_data.retry_limit_exceeded', error: exception.message)
      farm&.mark_weather_data_failed!(error_msg)
    end
  end

  # データ検証エラーなど、リトライしても意味がないエラーは即座に破棄
  discard_on ActiveRecord::RecordInvalid do |job, exception|
    farm_id = job.arguments.first[:farm_id]
    start_date = job.arguments.first[:start_date]
    end_date = job.arguments.first[:end_date]
    period_str = start_date.year == end_date.year ? "#{start_date.year}" : "#{start_date.year}-#{end_date.year}"
    
    Rails.logger.error "❌ [Farm##{farm_id}] Invalid data for #{period_str}: #{exception.message}"
    
    if farm_id
      farm = Farm.find_by(id: farm_id)
      error_msg = I18n.t('jobs.fetch_weather_data.validation_error', error: exception.message)
      farm&.mark_weather_data_failed!(error_msg)
    end
  end

  # 指定された緯度経度と期間の気象データを取得してデータベースに保存
  def perform(latitude: nil, longitude: nil, start_date: nil, end_date: nil, farm_id: nil, cultivation_plan_id: nil, channel_class: nil)
    # dictの中身を確認してバリデーション
    Rails.logger.info "🔍 [FetchWeatherDataJob] Received args: latitude=#{latitude}, longitude=#{longitude}, start_date=#{start_date}, end_date=#{end_date}, farm_id=#{farm_id}, cultivation_plan_id=#{cultivation_plan_id}, channel_class=#{channel_class}"
    
    # 引数が渡された場合はそれを使用、そうでなければインスタンス変数から取得
    latitude ||= self.latitude
    longitude ||= self.longitude
    start_date ||= self.start_date
    end_date ||= self.end_date
    farm_id ||= self.farm_id
    cultivation_plan_id ||= self.cultivation_plan_id
    channel_class ||= self.channel_class
    farm_info = farm_id ? "[Farm##{farm_id}]" : ""
    
    # フェーズを更新（開始通知）
    if cultivation_plan_id && channel_class
      cultivation_plan = CultivationPlan.find(cultivation_plan_id)
      cultivation_plan.phase_fetching_weather!(channel_class)
      Rails.logger.info "🌤️ [FetchWeatherDataJob] Started fetching weather data for plan ##{cultivation_plan_id}"
    end
    
    # 日付の検証
    if start_date.nil? || end_date.nil?
      error_msg = "Invalid date parameters: start_date=#{start_date.inspect}, end_date=#{end_date.inspect}"
      Rails.logger.error "❌ #{farm_info} #{error_msg}"
      raise ArgumentError, error_msg
    end
    
    period_str = start_date.year == end_date.year ? "#{start_date.year}" : "#{start_date.year}-#{end_date.year}"
    retry_info = executions > 1 ? " (リトライ #{executions - 1}/#{MAX_RETRY_ATTEMPTS})" : ""
    
    # 既にデータが存在するかチェック
    weather_location = WeatherLocation.find_by(latitude: latitude, longitude: longitude)
    gateway = Adapters::WeatherData::Gateways::ActiveRecordWeatherDataGateway.new
    if weather_location
      expected_days = (start_date..end_date).count
      existing_count = gateway.weather_data_count(
        weather_location_id: weather_location.id,
        start_date: start_date,
        end_date: end_date
      )
      
      # 8割以上のデータがあれば十分とみなす（データ欠損を考慮）
      threshold_ratio = 0.8
      threshold_days = (expected_days * threshold_ratio).ceil
      
      if existing_count >= threshold_days
        Rails.logger.info "⏭️  #{farm_info} Skipping #{period_str} - sufficient data exists (#{existing_count}/#{expected_days} days, #{((existing_count.to_f / expected_days) * 100).round(1)}%)"
        
        # 進捗を更新
        if farm_id
          farm = Farm.find_by(id: farm_id)
          if farm
            farm.increment_weather_data_progress!
            progress = farm.weather_data_progress
            Rails.logger.info "📊 #{farm_info} Progress: #{progress}% (#{farm.weather_data_fetched_years}/#{farm.weather_data_total_years} blocks)"
          end
        end
        
        return
      end
    end
    
    Rails.logger.info "🌤️  #{farm_info} Fetching weather data for #{period_str}#{retry_info} (#{latitude}, #{longitude})"
    
    # API負荷軽減のため短い待機時間を入れる
    sleep(0.5)
    
    # agrrコマンドを実行して気象データを取得
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
    elsif missing_days.positive?
      if missing_days > allowed_missing_days
        raise StandardError, "Weather data missing #{missing_days} days exceeds allowed #{allowed_missing_days} days (#{(ALLOWED_MISSING_RATIO * 100).round(1)}%)"
      end
      Rails.logger.warn "⚠️  #{farm_info} Weather data incomplete for #{period_str}: #{actual_days}/#{expected_days} days (missing #{missing_days}, allowed #{allowed_missing_days})"
    end

    # WeatherLocationを作成または取得
    location_data = weather_data['location']
    unless location_data.is_a?(Hash)
      raise StandardError, 'Weather data is missing location information'
    end
    weather_location = WeatherLocation.find_or_create_by_coordinates(
      latitude: location_data['latitude'],
      longitude: location_data['longitude'],
      elevation: location_data['elevation'],
      timezone: location_data['timezone']
    )

    # Farmとweather_locationを関連付け（まだ関連付けられていない場合）
    if farm_id
      farm = Farm.find_by(id: farm_id)
      if farm && farm.weather_location_id.nil?
        farm.update_column(:weather_location_id, weather_location.id)
        Rails.logger.info "🔗 [Farm##{farm_id}] Linked to WeatherLocation##{weather_location.id}"
      end
    end

    # 気象データをバッチ保存（upsert_allで一括処理）
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
        updated_at: Time.current
      }
      
      all_records << record_attrs
      
      # 最初と最後のレコードの詳細をログ
      if index == 0 || index == data_points.length - 1
        Rails.logger.debug "💾 [Weather Data ##{index + 1}] date=#{date}, temp=#{record_attrs[:temperature_min]}~#{record_attrs[:temperature_max]}°C"
      end
    end
    
    if all_records.any?
      dtos = all_records.map { |attrs| Domain::WeatherData::Dtos::WeatherDataDto.from_attrs(attrs) }
      gateway.upsert_weather_data!(
        weather_data_dtos: dtos,
        weather_location_id: weather_location.id
      )
    end

    data_count = all_records.size
    Rails.logger.info "💾 [Weather Data Summary] Total: #{data_count} records upserted in single batch"

    # Farmのステータスを更新
    if farm_id
      farm = Farm.find_by(id: farm_id)
      if farm
        farm.increment_weather_data_progress!
        progress = farm.weather_data_progress
        Rails.logger.info "📊 #{farm_info} Progress: #{progress}% (#{farm.weather_data_fetched_years}/#{farm.weather_data_total_years} blocks)"
      end
    end

    Rails.logger.info "✅ #{farm_info} Saved #{data_count} weather records for #{period_str}"
    
    # 完了通知
    if cultivation_plan_id && channel_class
      cultivation_plan = CultivationPlan.find(cultivation_plan_id)
      cultivation_plan.phase_weather_data_fetched!(channel_class)
      Rails.logger.info "🌤️ [FetchWeatherDataJob] Weather data fetching completed for plan ##{cultivation_plan_id}"
    end
  rescue => e
    # エラーログを出力（リトライの場合は警告レベル、それ以外はエラーレベル）
    log_level = executions < MAX_RETRY_ATTEMPTS ? :warn : :error
    Rails.logger.public_send(log_level, "⚠️  #{farm_info} Failed to fetch weather data for #{period_str}: #{e.message}")
    Rails.logger.public_send(log_level, "   Backtrace: #{e.backtrace.first(3).join("\n   ")}")
    
    # エラー時の通知（最終リトライ失敗時のみ）
    if executions >= MAX_RETRY_ATTEMPTS && cultivation_plan_id && channel_class
      cultivation_plan = CultivationPlan.find(cultivation_plan_id)
      cultivation_plan.phase_failed!('fetching_weather', channel_class)
      Rails.logger.info "🌤️ [FetchWeatherDataJob] Weather data fetching failed for plan ##{cultivation_plan_id}"
    end
    
    # 例外を再raiseして、retry_onに処理を委ねる
    # retry_onが最終的にリトライ上限に達した場合のみmark_weather_data_failed!が呼ばれる
    raise
  end

  private

  def fetch_weather_from_agrr(latitude, longitude, start_date, end_date, farm_id)
    data_source = determine_data_source(
      farm_id,
      latitude: latitude,
      longitude: longitude
    )
    farm_info = farm_id ? "[Farm##{farm_id}]" : ""
    Rails.logger.info "🌍 #{farm_info} Using data source: #{data_source}"
    
    weather_gateway = Agrr::WeatherGateway.new
    weather_gateway.fetch_by_date_range(
      latitude: latitude,
      longitude: longitude,
      start_date: start_date,
      end_date: end_date,
      data_source: data_source
    )
  end

  def determine_data_source(farm_id, latitude: nil, longitude: nil)
    farm = farm_id && Farm.find_by(id: farm_id)
    
    if farm
      return 'jma' if farm.region == 'jp'
      return 'jma' if japan_location?(farm.latitude, farm.longitude)
      return 'nasa-power' if farm.region.nil?
      return 'noaa'
    end

    lat = latitude || self.latitude
    lon = longitude || self.longitude

    return 'jma' if japan_location?(lat, lon)
    'noaa'
  end

  def japan_location?(latitude, longitude)
    return false if latitude.nil? || longitude.nil?
    latitude.between?(24.0, 46.0) && longitude.between?(127.0, 146.0)
  end

end

