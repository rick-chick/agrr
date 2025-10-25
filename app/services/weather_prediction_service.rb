# frozen_string_literal: true

# 天気予測サービス
# CultivationPlanやFarmから独立して天気予測を実行する
class WeatherPredictionService
  class WeatherDataNotFoundError < StandardError; end
  
  def initialize(farm)
    @farm = farm
    @prediction_gateway = Agrr::PredictionGateway.new
  end
  
  # 天気予測を実行してCultivationPlanに保存
  # @param cultivation_plan [CultivationPlan] 予測データを保存する栽培計画
  # @param target_end_date [Date] 予測終了日（デフォルト: 翌年12月31日）
  # @return [Hash] 予測データとメタ情報
  def predict_for_cultivation_plan(cultivation_plan, target_end_date: nil)
    target_end_date ||= cultivation_plan&.planning_end_date
    
    Rails.logger.info "🔮 [WeatherPrediction] Starting prediction for CultivationPlan##{cultivation_plan.id}"
    Rails.logger.info "   Target end date: #{target_end_date}"
    
    # 天気データを準備
    weather_info = prepare_weather_data(target_end_date)
    
    # 予測データをCultivationPlanに保存
    cultivation_plan.update!(
      predicted_weather_data: weather_info[:data].merge(
        'generated_at' => Time.current.iso8601,
        'predicted_at' => Time.current.iso8601,
        'prediction_start_date' => weather_info[:prediction_start_date],
        'prediction_end_date' => target_end_date.to_s,
        'target_end_date' => target_end_date.to_s,
        'model' => 'lightgbm'
      )
    )
    
    Rails.logger.info "✅ [WeatherPrediction] Prediction data saved to CultivationPlan##{cultivation_plan.id}"
    
    weather_info
  end
  
  # 天気予測を実行してFarmに保存
  # @param target_end_date [Date] 予測終了日（デフォルト: 翌年12月31日）
  # @return [Hash] 予測データとメタ情報
  def predict_for_farm(target_end_date: nil)
    target_end_date ||= cultivation_plan&.planning_end_date
    
    Rails.logger.info "🔮 [WeatherPrediction] Starting prediction for Farm##{@farm.id}"
    Rails.logger.info "   Target end date: #{target_end_date}"
    
    # 天気データを準備
    weather_info = prepare_weather_data(target_end_date)
    
    # 予測データをFarmに保存
    @farm.update!(
      predicted_weather_data: weather_info[:data].merge(
        'generated_at' => Time.current.iso8601,
        'predicted_at' => Time.current.iso8601,
        'prediction_start_date' => weather_info[:prediction_start_date],
        'prediction_end_date' => target_end_date.to_s,
        'model' => 'lightgbm'
      )
    )
    
    Rails.logger.info "✅ [WeatherPrediction] Prediction data saved to Farm##{@farm.id}"
    
    weather_info
  end
  
  # 既存の予測データを取得（新規予測は実行しない）
  # @param target_end_date [Date] 必要な予測終了日
  # @param cultivation_plan [CultivationPlan] 栽培計画（オプション）
  # @return [Hash] 予測データとメタ情報
  def get_existing_prediction(target_end_date: nil, cultivation_plan: nil)
    target_end_date ||= cultivation_plan&.planning_end_date
    
    Rails.logger.info "🔍 [WeatherPrediction] Checking existing prediction for Farm##{@farm.id}"
    
    # 1. CultivationPlanの予測データをチェック（優先）
    if cultivation_plan && cultivation_plan.predicted_weather_data.present? && cultivation_plan.predicted_weather_data['data'].present?
      Rails.logger.info "✅ [WeatherPrediction] Using existing CultivationPlan prediction data"
      return {
        data: cultivation_plan.predicted_weather_data,
        target_end_date: target_end_date,
        prediction_start_date: cultivation_plan.predicted_weather_data['prediction_start_date'],
        prediction_days: cultivation_plan.predicted_weather_data['data'].count
      }
    end
    
    Rails.logger.info "❌ [WeatherPrediction] No existing prediction found for CultivationPlan##{cultivation_plan&.id}"
    nil
  end
  
  private
  
  def prepare_weather_data(target_end_date)
    # 天気データを取得
    weather_location = get_weather_location
    training_data = get_training_data(weather_location)
    current_year_data = get_current_year_data(weather_location)
    
    # トレーニングデータをAGRR形式に変換
    training_formatted = format_weather_data_for_agrr(weather_location, training_data)
    
    # 予測データを取得（キャッシュまたは新規予測）
    future = get_prediction_data(training_formatted, target_end_date)
    
    # 今年の実データをAGRR形式に変換
    current_year_formatted = format_weather_data_for_agrr(weather_location, current_year_data)
    
    # 実データと予測データをマージ
    merged_data = merge_weather_data(current_year_formatted, future)
    
    # 予測開始日を計算
    training_end_date = Date.current - 2.days
    prediction_start_date = (training_end_date + 1.day > Date.today) ? training_end_date + 1.day : Date.today
    
    Rails.logger.info "✅ [WeatherPrediction] Weather data prepared successfully"
    
    {
      data: merged_data,
      target_end_date: target_end_date,
      prediction_start_date: prediction_start_date.to_s,
      prediction_days: future['data'].count
    }
  end
  
  def get_weather_location
    weather_location = WeatherLocation.find_by(
      latitude: @farm.latitude,
      longitude: @farm.longitude
    )
    
    unless weather_location
      raise WeatherDataNotFoundError, 
            "気象データがありません。座標 #{@farm.latitude}, #{@farm.longitude} の気象データが見つかりません。 " \
            "管理者に気象データのインポートを依頼してください。"
    end
    
    weather_location
  end
  
  def get_training_data(weather_location)
    # 過去20年分の実績データをLightGBMモデルのトレーニング用に取得
    training_start_date = Date.current - 20.years
    training_end_date = Date.current - 2.days
    training_data = weather_location.weather_data_for_period(training_start_date, training_end_date)
    
    if training_data.empty?
      raise WeatherDataNotFoundError,
            "気象データがありません。期間 #{training_start_date} から #{training_end_date} の気象データが見つかりません。 " \
            "管理者に気象データのインポートを依頼してください。"
    end
    
    # 最低限必要なデータ量をチェック（15年分 = 約5475日）
    minimum_required_days = 5470
    if training_data.count < minimum_required_days
      raise WeatherDataNotFoundError,
            "気象データが不足しています。現在 #{training_data.count} 件のデータがありますが、最低 #{minimum_required_days} 日分（約15年）のデータが必要です。 " \
            "管理者に気象データのインポートを依頼してください（期間: #{training_start_date} から #{training_end_date}）。"
    end
    
    Rails.logger.info "✅ [WeatherPrediction] Training data loaded: #{training_data.count} records"
    training_data
  end
  
  def get_current_year_data(weather_location)
    # 今年1年間の実績データを取得
    current_year_start = Date.new(Date.current.year, 1, 1)
    current_year_end = Date.current - 2.days
    current_year_data = weather_location.weather_data_for_period(current_year_start, current_year_end)
    
    if current_year_data.empty?
      raise WeatherDataNotFoundError,
            "No current year weather data found for period #{current_year_start} to #{current_year_end}. " \
            "Please run weather data import batch first."
    end
    
    Rails.logger.info "✅ [WeatherPrediction] Current year data loaded: #{current_year_data.count} records"
    current_year_data
  end
  
  def get_prediction_data(training_formatted, target_end_date)
    # Farmの予測データをチェック
    if @farm.predicted_weather_data.present? && @farm.predicted_weather_data['data'].present?
      farm_prediction = @farm.predicted_weather_data
      farm_prediction_start = Date.parse(farm_prediction['prediction_start_date'])
      farm_prediction_end = Date.parse(farm_prediction['prediction_end_date'])
      
      # target_end_dateまでカバーしているか確認
      if farm_prediction_end >= target_end_date
        Rails.logger.info "♻️ [WeatherPrediction] Reusing Farm##{@farm.id} cached prediction data"
        
        # 必要な期間のデータを抽出
        filtered_data = farm_prediction['data'].select do |datum|
          datum_date = Date.parse(datum['date'])
          datum_date >= farm_prediction_start && datum_date <= target_end_date
        end
        
        future = {
          'data' => filtered_data.map do |datum|
            {
              'time' => datum['date'],
              'temperature_2m_max' => datum['temperature_max'],
              'temperature_2m_min' => datum['temperature_min'],
              'temperature_2m_mean' => datum['temperature_mean'],
              'precipitation_sum' => datum['precipitation'] || 0.0
            }
          end
        }
        
        Rails.logger.info "✅ [WeatherPrediction] Using #{filtered_data.count} days from cached prediction"
        return future
      end
    end
    
    # 新規予測を実行
    Rails.logger.info "🔮 [WeatherPrediction] Generating new prediction"
    training_end_date = Date.current - 2.days
    prediction_days = (target_end_date - training_end_date).to_i
    
    Rails.logger.info "🔮 [WeatherPrediction] Predicting weather from #{training_end_date + 1.day} until #{target_end_date} (#{prediction_days} days)"
    
    future = @prediction_gateway.predict(
      historical_data: training_formatted,
      days: prediction_days,
      model: 'lightgbm'
    )
    
    Rails.logger.info "✅ [WeatherPrediction] Prediction completed for next #{prediction_days} days"
    future
  end
  
  def format_weather_data_for_agrr(weather_location, weather_data)
    {
      'latitude' => weather_location.latitude.to_f,
      'longitude' => weather_location.longitude.to_f,
      'elevation' => (weather_location.elevation || 0.0).to_f,
      'timezone' => weather_location.timezone,
      'data' => weather_data.filter_map do |datum|
        # Skip records with missing temperature data
        next if datum.temperature_max.nil? || datum.temperature_min.nil?
        
        # Calculate mean from max/min if missing
        temp_mean = datum.temperature_mean
        if temp_mean.nil?
          temp_mean = (datum.temperature_max.to_f + datum.temperature_min.to_f) / 2.0
        else
          temp_mean = temp_mean.to_f
        end
        
        {
          'time' => datum.date.to_s,
          'temperature_2m_max' => datum.temperature_max.to_f,
          'temperature_2m_min' => datum.temperature_min.to_f,
          'temperature_2m_mean' => temp_mean,
          'precipitation_sum' => (datum.precipitation || 0.0).to_f,
          'sunshine_duration' => datum.sunshine_hours ? (datum.sunshine_hours.to_f * 3600.0) : 0.0, # 時間→秒
          'wind_speed_10m_max' => (datum.wind_speed || 0.0).to_f,
          'weather_code' => datum.weather_code || 0
        }
      end
    }
  end
  
  def merge_weather_data(historical, future)
    {
      'latitude' => historical['latitude'],
      'longitude' => historical['longitude'],
      'elevation' => historical['elevation'],
      'timezone' => historical['timezone'],
      'data' => historical['data'] + future['data']
    }
  end
end
