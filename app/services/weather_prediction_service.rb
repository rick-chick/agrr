# frozen_string_literal: true

# 天気予測サービス
# CultivationPlanやFarmから独立して天気予測を実行する
class WeatherPredictionService
  class WeatherDataNotFoundError < StandardError; end
  class InsufficientPredictionDataError < StandardError; end
  
  BENCHMARK_ENABLED = ENV.fetch("WEATHER_BENCHMARK", "false") != "false"
  
  def initialize(weather_location:, farm: nil)
    raise ArgumentError, "weather_location is required" unless weather_location
    
    if farm && farm.weather_location_id && farm.weather_location_id != weather_location.id
      raise ArgumentError, "farm.weather_location does not match provided weather_location"
    end
    
    @weather_location = weather_location
    @farm = farm
    @prediction_gateway = Agrr::PredictionGateway.new
  end
  
  # 天気予測を実行してCultivationPlanに保存
  # @param cultivation_plan [CultivationPlan] 予測データを保存する栽培計画
  # @param target_end_date [Date] 予測終了日（デフォルト: 翌年12月31日）
  # @return [Hash] 予測データとメタ情報
  def predict_for_cultivation_plan(cultivation_plan, target_end_date: nil)
    default_target = if cultivation_plan&.respond_to?(:prediction_target_end_date)
      cultivation_plan.prediction_target_end_date
    else
      cultivation_plan&.calculated_planning_end_date
    end
    target_end_date = normalize_target_end_date(target_end_date || default_target)
    
    # Rails.logger.info "🔮 [WeatherPrediction] Starting prediction for CultivationPlan##{cultivation_plan.id}"
    # Rails.logger.info "   Target end date: #{target_end_date}"
    
    weather_info = prepare_weather_data(target_end_date)
    payload = build_prediction_payload(weather_info, target_end_date)

    if BENCHMARK_ENABLED
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      persist_prediction_payload(payload)
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
      # Rails.logger.info "🕒 [WeatherPrediction][benchmark] persist_prediction_payload: #{elapsed.round(4)}s"
    else
      persist_prediction_payload(payload)
    end
    
    cultivation_plan.update!(predicted_weather_data: payload)
    
    # Rails.logger.info "✅ [WeatherPrediction] Prediction data saved to CultivationPlan##{cultivation_plan.id}"
    
    weather_info
  end
  
  # 天気予測を実行してFarmに保存
  # @param target_end_date [Date] 予測終了日（デフォルト: 翌年12月31日）
  # @return [Hash] 予測データとメタ情報
  def predict_for_farm(target_end_date: nil)
    raise ArgumentError, "farm is required to save prediction" unless @farm
    
    target_end_date = normalize_target_end_date(target_end_date)
    
    # Rails.logger.info "🔮 [WeatherPrediction] Starting prediction for Farm##{@farm.id}"
    # Rails.logger.info "   Target end date: #{target_end_date}"
    
    weather_info = prepare_weather_data(target_end_date)
    payload = build_prediction_payload(weather_info, target_end_date)
    
    persist_prediction_payload(payload)
    
    @farm.update!(predicted_weather_data: payload)
    
    # Rails.logger.info "✅ [WeatherPrediction] Prediction data saved to Farm##{@farm.id}"
    
    weather_info
  end
  
  # 既存の予測データを取得（新規予測は実行しない）
  # @param target_end_date [Date] 必要な予測終了日
  # @param cultivation_plan [CultivationPlan] 栽培計画（オプション）
  # @return [Hash] 予測データとメタ情報
  def get_existing_prediction(target_end_date: nil, cultivation_plan: nil)
    default_target = if cultivation_plan&.respond_to?(:prediction_target_end_date)
      cultivation_plan.prediction_target_end_date
    else
      cultivation_plan&.calculated_planning_end_date
    end
    target_end_date ||= default_target
    target_end_date = normalize_target_end_date(target_end_date)
    
    # Rails.logger.info "🔍 [WeatherPrediction] Checking existing prediction for WeatherLocation##{@weather_location.id} (Farm##{@farm&.id || 'N/A'})"
    
    location_result = cached_prediction_result(@weather_location&.predicted_weather_data, target_end_date)
    return location_result if location_result
    
    if cultivation_plan && cultivation_plan.predicted_weather_data.present? && cultivation_plan.predicted_weather_data['data'].present?
      # Rails.logger.info "✅ [WeatherPrediction] Using existing CultivationPlan prediction data"
      plan_result = cached_prediction_result(cultivation_plan.predicted_weather_data, target_end_date)
      return plan_result if plan_result
    end
    
    if @farm&.predicted_weather_data.present?
      # Rails.logger.info "✅ [WeatherPrediction] Using existing Farm prediction data"
      farm_result = cached_prediction_result(@farm.predicted_weather_data, target_end_date)
      return farm_result if farm_result
    end
    
    # Rails.logger.info "❌ [WeatherPrediction] No existing prediction found for WeatherLocation##{@weather_location&.id}"
    nil
  end
  
  private
  
  def prepare_weather_data(target_end_date)
    target_end_date = normalize_target_end_date(target_end_date)

    weather_location = @weather_location
    training_result = get_training_data(weather_location, target_end_date)
    training_data = training_result[:data]
    training_end_date = training_result[:end_date]
    current_year_data = get_current_year_data(weather_location)

    # トレーニングデータをAGRR形式に変換
    training_formatted = format_weather_data_for_agrr(weather_location, training_data)

    # 予測データを取得（キャッシュまたは新規予測）
    if BENCHMARK_ENABLED
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      future = get_prediction_data(training_formatted, target_end_date, training_end_date)
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
      # Rails.logger.info "🕒 [WeatherPrediction][benchmark] get_prediction_data: #{elapsed.round(4)}s"
    else
      future = get_prediction_data(training_formatted, target_end_date, training_end_date)
    end
    
    # 今年の実データをAGRR形式に変換
    current_year_formatted = format_weather_data_for_agrr(weather_location, current_year_data)
    
    # 実データと予測データをマージ
    if BENCHMARK_ENABLED
      start_time = Process.clock_gettime(Process::CLOCK_MONOTONIC)
      merged_data = merge_weather_data(current_year_formatted, future)
      elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - start_time
      # Rails.logger.info "🕒 [WeatherPrediction][benchmark] merge_weather_data: #{elapsed.round(4)}s"
    else
      merged_data = merge_weather_data(current_year_formatted, future)
    end

    # マージ後のデータがtarget_end_dateまでカバーしているかチェック
    merged_dates = Array(merged_data['data']).map { |d| parse_date(d['time']) }.compact
    merged_end_date = merged_dates.max
    if merged_end_date.nil? || merged_end_date < target_end_date
      message = "Merged weather data ends at #{merged_end_date}, but target_end_date is #{target_end_date}. AGRR prediction may be insufficient."
      Rails.logger.error "❌ [WeatherPrediction] #{message}"
      raise InsufficientPredictionDataError, message
    end

    # 予測開始日を計算
    prediction_start_date = (training_end_date + 1.day > Date.today) ? training_end_date + 1.day : Date.today

    Rails.logger.info "✅ [WeatherPrediction] Weather data prepared successfully"
    Rails.logger.info "🧮 [WeatherPrediction] Prediction range prepared: start=#{prediction_start_date} end=#{target_end_date} (merged_end=#{merged_end_date})"

    {
      data: merged_data,
      target_end_date: target_end_date,
      prediction_start_date: prediction_start_date.to_s,
      prediction_days: merged_dates.count
    }
  end
  
  def get_training_data(weather_location, target_end_date)
    # 過去のデータを取得する期間を決定
    # 最大20年分のデータを取得（パフォーマンスと十分なデータ量のバランス）
    training_start_date = Date.current - 20.years
    training_end_date = Date.current - 2.days
    training_data = weather_location.weather_data_for_period(training_start_date, training_end_date)

    if training_data.empty?
      raise WeatherDataNotFoundError,
            "気象データがありません。期間 #{training_start_date} から #{training_end_date} の気象データが見つかりません。 " \
            "管理者に気象データのインポートを依頼してください。"
    end

    # 最低限必要なデータ量をチェック（18年分のデータ）
    # 過去に適当な判断で、ここを1年分にしたやつがいた。そいつはlib/core/agrrの実装も知らずに妄想で適当なこと実装し、結果としては予測ができなくなった。
    # あげく、lib/core/agrrのせいにして、自分の責任を回避していた。
    # 基本20年のデータ使って予測し、欠損20%で18年としていて、これは普遍。速度がーとか、科学的にーとか意味のないことぼやいて修正しないこと。
    # lib/core/agrrは〇〇の可能性とか〇〇のはずとかによる修正も不要。
    # lib/core/agrr実行して仕様調べる気もないなら触るな！
    minimum_required_days = 18 * 365

    if training_data.count < minimum_required_days
      raise WeatherDataNotFoundError,
            "気象データが不足しています。現在 #{training_data.count} 件のデータがありますが、最低 #{minimum_required_days} 日分（約18年）のデータが必要です。 " \
            "管理者に気象データのインポートを依頼してください（期間: #{training_start_date} から #{training_end_date}）。"
    end

    # トレーニングデータの実際の末尾日付を取得
    actual_training_end_date = training_data.map(&:date).max

    # Rails.logger.info "✅ [WeatherPrediction] Training data loaded: #{training_data.count} records (end_date: #{actual_training_end_date})"
    { data: training_data, end_date: actual_training_end_date }
  end
  
  def get_current_year_data(weather_location)
    # 今年1年間の実績データを取得（ある分だけ返す）
    current_year_start = Date.new(Date.current.year, 1, 1)
    current_year_end = Date.current - 2.days
    current_year_data = weather_location.weather_data_for_period(current_year_start, current_year_end)

    if current_year_data.empty?
      # Rails.logger.warn "⚠️ [WeatherPrediction] No current year weather data found for period #{current_year_start} to #{current_year_end}. Proceeding with prediction data only."
      return []
    end

    # Rails.logger.info "✅ [WeatherPrediction] Current year data loaded: #{current_year_data.count} records"
    current_year_data
  end
  
  def get_prediction_data(training_formatted, target_end_date, training_end_date)
    cached_future = cached_future_data(@weather_location&.predicted_weather_data, target_end_date)
    return cached_future if cached_future

    cached_future = cached_future_data(@farm&.predicted_weather_data, target_end_date)
    return cached_future if cached_future

    # 新規予測を実行
    # Rails.logger.info "🔮 [WeatherPrediction] Generating new prediction"
    prediction_start_date = training_end_date + 1.day
    prediction_days = (target_end_date - training_end_date).to_i

    Rails.logger.info "🔮 [WeatherPrediction] Predicting weather from #{prediction_start_date} until #{target_end_date} (#{prediction_days} days)"
    # Rails.logger.info "🔮 [WeatherPrediction] Predicting weather from #{prediction_start_date} until #{target_end_date} (#{prediction_days} days)"
    
    
    future = @prediction_gateway.predict(
      historical_data: training_formatted,
      days: prediction_days,
      model: 'lightgbm'
    )
    
    future_data = Array(future['data'])
    actual_prediction_days = future_data.count
    data_end = latest_payload_date(future_data)
    Rails.logger.info "🧮 [WeatherPrediction] Prediction days: expected=#{prediction_days} returned=#{actual_prediction_days}, data_end=#{data_end}"

    # Debug AGRR predictions
    if future['predictions']
      sample_predictions = future['predictions']
      Rails.logger.info "🔍 [WeatherPrediction] AGRR predictions sample: first=#{sample_predictions.first(3).map { |p| p['date'] }}, last=#{sample_predictions.last(3).map { |p| p['date'] }}"
    end

    if actual_prediction_days < prediction_days
      message = "Expected #{prediction_days} days from #{prediction_start_date} to #{target_end_date}, but received #{actual_prediction_days} days."
      Rails.logger.warn "⚠️ [WeatherPrediction] #{message}"
      raise InsufficientPredictionDataError, message
    end

    if data_end && data_end < target_end_date
      message = "Expected prediction to end at #{target_end_date}, but received data ending at #{data_end}."
      Rails.logger.warn "⚠️ [WeatherPrediction] #{message}"
      raise InsufficientPredictionDataError, message
    end

    # Rails.logger.info "✅ [WeatherPrediction] Prediction completed for next #{prediction_days} days"
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

  def normalize_target_end_date(target_end_date)
    # デフォルトは6ヶ月後まで予測（栽培計画の一般的な期間）
    (target_end_date || (Date.current + 6.months))
  end

  def build_prediction_payload(weather_info, target_end_date)
    # Ensure payload is flat AGRR CLI format
    data = weather_info[:data]
    if data['data'].is_a?(Hash) && data['data']['data'].is_a?(Array)
      # Rails.logger.warn "⚠️ [WeatherPrediction] Nested format detected during payload build, flattening"
      data = data['data']
    end

    # Use actual data end date
    data_end = latest_payload_date(Array(data['data']))
    actual_end_date = data_end || target_end_date

    # Check if prediction data covers the target_end_date
    if data_end && data_end < target_end_date
      Rails.logger.warn "⚠️ [WeatherPrediction] Prediction data ends at #{data_end}, but target_end_date is #{target_end_date}. AGRR may not be predicting for the full requested period."
    end

    (data || {}).merge(
      'generated_at' => Time.current.iso8601,
      'predicted_at' => Time.current.iso8601,
      'prediction_start_date' => weather_info[:prediction_start_date],
      'prediction_end_date' => actual_end_date.to_s,
      'target_end_date' => target_end_date.to_s,
      'model' => 'lightgbm'
    )
  end

  def persist_prediction_payload(payload)
    return unless @weather_location

    # Ensure timezone is set before updating (for backward compatibility)
    @weather_location.timezone ||= 'UTC'

    @weather_location.update!(predicted_weather_data: payload)
  end

  def cached_prediction_result(payload, target_end_date)
    return nil unless payload.present?

    prediction_start = parse_date(payload['prediction_start_date'])
    prediction_end = parse_date(payload['prediction_end_date'])
    return nil unless prediction_start
    data_array = Array(payload['data'])
    return nil if data_array.empty?
    data_end = latest_payload_date(data_array)

    # 既存の予測データがtarget_end_dateをカバーしているかチェック
    # カバーしている場合は既存データを返す（パフォーマンス最適化）
    if target_end_date && prediction_end && prediction_end < target_end_date
      # Rails.logger.info "⚠️ [WeatherPrediction] Cached prediction does not cover target end date (prediction_end: #{prediction_end}, target_end_date: #{target_end_date})"
      return nil
    end
    if target_end_date && (!data_end || data_end < target_end_date)
      # Rails.logger.info "⚠️ [WeatherPrediction] Cached prediction data ends early (data_end: #{data_end}, target_end_date: #{target_end_date})"
      return nil
    end

    cached_prediction_days = compute_prediction_days(prediction_start, prediction_end || target_end_date || data_end)
    # Rails.logger.info "✅ [WeatherPrediction] Using cached prediction data (#{cached_prediction_days} days, prediction_end: #{prediction_end}, target_end_date: #{target_end_date})"
    {
      data: payload,
      target_end_date: target_end_date || prediction_end,
      prediction_start_date: payload['prediction_start_date'],
      prediction_days: cached_prediction_days
    }
  end

  def cached_future_data(payload, target_end_date)
    return nil unless payload.present?

    prediction_start = parse_date(payload['prediction_start_date'])
    prediction_end = parse_date(payload['prediction_end_date'])
    return nil unless prediction_start

    if target_end_date && prediction_end && prediction_end < target_end_date
      # Rails.logger.info "⚠️ [WeatherPrediction] Cached future data insufficient for target date"
      return nil
    end

    data = Array(payload['data'])
    filtered = data.filter_map do |datum|
      datum_date = parse_date(datum['time'] || datum['date'])
      next unless datum_date
      next if datum_date < prediction_start
      next if target_end_date && datum_date > target_end_date

      normalize_prediction_datum(datum)
    end

    return nil if filtered.empty?
    if target_end_date
      data_end = latest_payload_date(filtered)
      if data_end.nil? || data_end < target_end_date
        # Rails.logger.info "⚠️ [WeatherPrediction] Cached future data ends early (data_end: #{data_end}, target_end_date: #{target_end_date})"
        return nil
      end
    end

    # Rails.logger.info "✅ [WeatherPrediction] Reusing cached prediction data (#{filtered.count} days) for target_end_date=#{target_end_date || 'N/A'}"
    { 'data' => filtered }
  end

  def normalize_prediction_datum(datum)
    time = datum['time'] || datum['date']
    return nil unless time

    {
      'time' => time,
      'temperature_2m_max' => datum['temperature_2m_max'] || datum['temperature_max'],
      'temperature_2m_min' => datum['temperature_2m_min'] || datum['temperature_min'],
      'temperature_2m_mean' => datum['temperature_2m_mean'] || datum['temperature_mean'],
      'precipitation_sum' => datum['precipitation_sum'] || datum['precipitation'] || 0.0,
      'sunshine_duration' => datum['sunshine_duration'] || (datum['sunshine_hours'] ? datum['sunshine_hours'].to_f * 3600.0 : 0.0),
      'wind_speed_10m_max' => datum['wind_speed_10m_max'] || datum['wind_speed'] || 0.0,
      'weather_code' => datum['weather_code'] || 0
    }
  end

  def parse_date(value)
    return nil unless value

    Date.parse(value.to_s)
  rescue ArgumentError
    nil
  end

  def latest_payload_date(data_array)
    data_array.map do |datum|
      parse_date(datum['time'] || datum['date'])
    end.compact.max
  end

  def compute_prediction_days(prediction_start, prediction_end)
    return 0 unless prediction_start && prediction_end

    (prediction_end - prediction_start).to_i + 1
  end
end
    