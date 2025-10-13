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
    @current_phase = nil
    
    begin
      weather_info = prepare_weather_data
      
      # 最適化フェーズ
      @current_phase = 'optimizing'
      @cultivation_plan.phase_optimizing!
      
      field_cultivations = @cultivation_plan.field_cultivations.to_a
      field_cultivations.each do |field_cultivation|
        optimize_field_cultivation(field_cultivation, weather_info[:data], weather_info[:available_days])
      end
      
      @cultivation_plan.phase_completed!
      @cultivation_plan.complete!
      Rails.logger.info "✅ CultivationPlan ##{@cultivation_plan.id} optimization completed"
      true
    rescue StandardError => e
      Rails.logger.error "❌ CultivationPlan ##{@cultivation_plan.id} optimization failed at phase: #{@current_phase || 'unknown'}"
      Rails.logger.error "Error: #{e.message}"
      Rails.logger.error e.backtrace.join("\n")
      
      # フェーズに応じたエラーメッセージを設定
      @cultivation_plan.phase_failed!(@current_phase || 'unknown')
      @cultivation_plan.fail!(e.message)
      false
    end
  end
  
  private
  
  def prepare_weather_data
    # フェーズ: 気象データ取得
    @current_phase = 'fetching_weather'
    @cultivation_plan.phase_fetching_weather!
    
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
    
    # 最低限必要なデータ量をチェック（1年分 = 365日）
    minimum_required_days = 365
    if training_data.count < minimum_required_days
      raise WeatherDataNotFoundError,
            "Insufficient training weather data: #{training_data.count} records found, but at least #{minimum_required_days} days required. " \
            "Please run weather data import batch to fetch historical data (#{training_start_date} to #{training_end_date})."
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
    
    # フェーズ: 気象データ予測
    @current_phase = 'predicting_weather'
    @cultivation_plan.phase_predicting_weather!
    
    # 次の年の12月31日までの予測データ
    next_year = Date.current.year + 1
    target_end_date = Date.new(next_year, 12, 31)
    prediction_days = (target_end_date - Date.current).to_i
    
    Rails.logger.info "🔮 [AGRR] Predicting weather until #{target_end_date} (#{prediction_days} days)"
    
    future = @prediction_gateway.predict(
      historical_data: training_formatted,
      days: prediction_days
    )
    
    Rails.logger.info "✅ [AGRR] Prediction completed for next #{prediction_days} days (until #{target_end_date})"
    
    # 今年の実データをAGRR形式に変換
    current_year_formatted = format_weather_data_for_agrr(weather_location, current_year_data)
    
    # 今年の実データ + 来年の予測データをマージ
    merged_data = merge_weather_data(current_year_formatted, future)
    
    # 気象データの実際の範囲を計算
    # 今年の実データ + 次の年の12月31日までの予測データ
    total_weather_days = current_year_data.count + prediction_days
    
    Rails.logger.info "✅ [AGRR] Total weather data available: #{total_weather_days} days (current year: #{current_year_data.count} + prediction until #{target_end_date}: #{prediction_days})"
    
    # 気象データ範囲を返す
    {
      data: merged_data,
      available_days: total_weather_days
    }
  end
  
  def format_weather_data_for_agrr(weather_location, weather_data)
    {
      'latitude' => weather_location.latitude,
      'longitude' => weather_location.longitude,
      'elevation' => weather_location.elevation || 0.0,
      'timezone' => weather_location.timezone,
      'data' => weather_data.filter_map do |datum|
        # Skip records with missing temperature data
        next if datum.temperature_max.nil? || datum.temperature_min.nil?
        
        # Calculate mean from max/min if missing
        temp_mean = datum.temperature_mean
        if temp_mean.nil?
          temp_mean = (datum.temperature_max + datum.temperature_min) / 2.0
        end
        
        {
          'time' => datum.date.to_s,
          'temperature_2m_max' => datum.temperature_max,
          'temperature_2m_min' => datum.temperature_min,
          'temperature_2m_mean' => temp_mean,
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
  
  def optimize_field_cultivation(field_cultivation, weather_data, available_days)
    field_cultivation.start_optimizing!
    
    crop_info = field_cultivation.crop_info
    field_info = field_cultivation.field_info
    
    # 利用可能な気象データの範囲で評価期間を設定
    evaluation_end = Date.current + available_days.days
    
    Rails.logger.info "🗓️  [AGRR] Evaluation period: #{Date.current} to #{evaluation_end} (#{available_days} days)"
    
    # CultivationPlanCropからCropモデルを検索
    # 名前と品種が一致する参照作物を優先的に検索
    crop = Crop.find_by(
      name: crop_info[:name],
      variety: crop_info[:variety],
      is_reference: true
    )
    
    # 参照作物が見つからない場合、ユーザーの作物も検索
    crop ||= Crop.find_by(
      name: crop_info[:name],
      variety: crop_info[:variety],
      user_id: @cultivation_plan.user_id
    )
    
    # Cropモデルが見つからない場合はエラー
    unless crop
      error_message = "Crop not found: name='#{crop_info[:name]}', variety='#{crop_info[:variety]}'. " \
                      "Please register the crop with detailed growth stages in the Crop management page before optimization."
      Rails.logger.error "❌ [AGRR] #{error_message}"
      raise StandardError, error_message
    end
    
    Rails.logger.info "📚 [AGRR] Using Crop model (id: #{crop.id}, reference: #{crop.is_reference})"
    
    result = @optimization_gateway.optimize(
      crop_name: crop_info[:name],
      variety: crop_info[:variety] || 'general',
      weather_data: weather_data,
      field_area: field_cultivation.area,
      daily_fixed_cost: field_info[:daily_fixed_cost],
      evaluation_start: Date.current,
      evaluation_end: evaluation_end,
      crop: crop  # Cropモデルを渡す（必須）
    )
    
    field_cultivation.complete_with_result!(result)
  rescue StandardError => e
    Rails.logger.error "❌ FieldCultivation ##{field_cultivation.id} optimization failed: #{e.message}"
    field_cultivation.fail_with_error!(e.message)
    raise
  end
end

