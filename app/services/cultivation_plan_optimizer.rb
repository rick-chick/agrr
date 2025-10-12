# frozen_string_literal: true

class CultivationPlanOptimizer
  class WeatherDataNotFoundError < StandardError; end
  
  def initialize(cultivation_plan)
    @cultivation_plan = cultivation_plan
    @prediction_gateway = Agrr::PredictionGateway.new
    @optimization_gateway = Agrr::OptimizationGateway.new
  end
  
  def call
    @cultivation_plan.start_optimizing!
    
    weather_data = prepare_weather_data
    
    @cultivation_plan.field_cultivations.each do |field_cultivation|
      optimize_field_cultivation(field_cultivation, weather_data)
    end
    
    Rails.logger.info "✅ CultivationPlan ##{@cultivation_plan.id} optimization completed"
    true
  rescue StandardError => e
    Rails.logger.error "❌ CultivationPlan ##{@cultivation_plan.id} optimization failed: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    @cultivation_plan.fail!(e.message)
    false
  end
  
  private
  
  def prepare_weather_data
    farm = @cultivation_plan.farm
    
    # DBから天気データを取得
    weather_location = WeatherLocation.find_by(
      latitude: farm.latitude,
      longitude: farm.longitude
    )
    
    unless weather_location
      raise WeatherDataNotFoundError, 
            "Weather location not found for coordinates: #{farm.latitude}, #{farm.longitude}. " \
            "Please run weather data import batch first."
    end
    
    # 過去20年分の実績データをARIMAモデルのトレーニング用に取得
    training_start_date = Date.current - 20.years
    training_end_date = Date.current - 1.day
    training_data = weather_location.weather_data_for_period(training_start_date, training_end_date)
    
    if training_data.empty?
      raise WeatherDataNotFoundError,
            "No training weather data found for period #{training_start_date} to #{training_end_date}. " \
            "Please run weather data import batch first."
    end
    
    Rails.logger.info "✅ [AGRR] Training data loaded from DB: #{training_data.count} records (#{training_start_date} to #{training_end_date})"
    
    # 今年1年間の実績データを取得
    current_year_start = Date.new(Date.current.year, 1, 1)
    current_year_end = Date.current - 1.day
    current_year_data = weather_location.weather_data_for_period(current_year_start, current_year_end)
    
    if current_year_data.empty?
      raise WeatherDataNotFoundError,
            "No current year weather data found for period #{current_year_start} to #{current_year_end}. " \
            "Please run weather data import batch first."
    end
    
    Rails.logger.info "✅ [AGRR] Current year data loaded from DB: #{current_year_data.count} records (#{current_year_start} to #{current_year_end})"
    
    # トレーニングデータをAGRR形式に変換
    training_formatted = format_weather_data_for_agrr(weather_location, training_data)
    
    # 来年1年間（365日）の予測データ
    next_year_days = 365
    future = @prediction_gateway.predict(
      historical_data: training_formatted,
      days: next_year_days
    )
    
    Rails.logger.info "✅ [AGRR] Prediction completed for next year: #{next_year_days} days"
    
    # 今年の実データをAGRR形式に変換
    current_year_formatted = format_weather_data_for_agrr(weather_location, current_year_data)
    
    # 今年の実データ + 来年の予測データをマージ（合計2年分）
    merge_weather_data(current_year_formatted, future)
  end
  
  def format_weather_data_for_agrr(weather_location, weather_data)
    {
      'latitude' => weather_location.latitude,
      'longitude' => weather_location.longitude,
      'elevation' => weather_location.elevation || 0.0,
      'timezone' => weather_location.timezone,
      'data' => weather_data.map do |datum|
        {
          'time' => datum.date.to_s,
          'temperature_2m_max' => datum.temperature_max,
          'temperature_2m_min' => datum.temperature_min,
          'temperature_2m_mean' => datum.temperature_mean,
          'precipitation_sum' => datum.precipitation || 0.0,
          'sunshine_duration' => datum.sunshine_hours ? datum.sunshine_hours * 3600 : 0.0, # 時間→秒
          'wind_speed_10m_max' => datum.wind_speed || 0.0,
          'weather_code' => datum.weather_code || 0
        }
      end
    }
  end
  
  def merge_weather_data(historical, future)
    {
      latitude: historical['latitude'],
      longitude: historical['longitude'],
      data: (historical['data'] || []) + (future['data'] || [])
    }
  end
  
  def optimize_field_cultivation(field_cultivation, weather_data)
    field_cultivation.start_optimizing!
    
    result = @optimization_gateway.optimize(
      crop_name: field_cultivation.crop.name,
      variety: field_cultivation.crop.variety || 'general',
      weather_data: weather_data,
      field_area: field_cultivation.area,
      daily_fixed_cost: field_cultivation.field.daily_fixed_cost,
      evaluation_start: Date.current,
      evaluation_end: Date.current + 2.years
    )
    
    field_cultivation.complete_with_result!(result)
  rescue StandardError => e
    Rails.logger.error "❌ FieldCultivation ##{field_cultivation.id} optimization failed: #{e.message}"
    field_cultivation.fail_with_error!(e.message)
    raise
  end
end

